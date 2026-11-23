#!/usr/bin/env python3
"""Static MSVC x64 RTTI, .pdata, Capstone call-graph, and constant extractor for gamedll_x64_rwdi.dll."""

from __future__ import annotations

import argparse
import bisect
import json
import math
import os
import re
import struct
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any

import capstone
import pefile

DEFAULT_DLL = (
    r"D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3"
    r"\Dying.Light.v1.54.0_LinkNeverDie.Com\gamedll_x64_rwdi.dll"
)
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = REPO_ROOT / "assets_ref" / "dl_re_raw" / "dl1_binary_map.json"
OUT_DISASM = REPO_ROOT / "assets_ref" / "dl_re_raw" / "disasm"

CORE_CLASSES = [
    "PlayerDI",
    "MoveController",
    "NaturalMovementController",
    "EdgeGrabController",
    "LandingController",
    "LookController",
    "CameraFPPDI",
    "PlayerFppVis",
    "WeaponMeleeController",
    "ChargeController",
    "StompFinisherController",
    "GrabController",
    "RopeLocomotionController",
    "PlayerFitnessModule",
    "PlayerStaminaModule",
    "DodgeModule",
    "PlayerFallAmortizer",
    "PlayerFallHelperModule",
]

PLAYER_CTRL_RANGE = (0x00CDB000, 0x00DF5000)

FLOAT_LOAD_MNEMONICS = {
    "movss", "addss", "subss", "mulss", "divss", "comiss", "ucomiss",
    "minss", "maxss", "sqrtss", "vmovss", "vaddss", "vsubss", "vmulss",
    "vdivss", "vcomiss", "vucomiss", "vminss", "vmaxss",
}
DOUBLE_LOAD_MNEMONICS = {
    "movsd", "addsd", "subsd", "mulsd", "divsd", "comisd", "ucomisd",
    "minsd", "maxsd", "vmovsd", "vaddsd", "vsubsd", "vmulsd", "vdivsd",
}
VEC128_LOAD_MNEMONICS = {
    "movaps", "movups", "movdqa", "movdqu", "andps", "xorps", "orps",
    "mulps", "addps", "subps", "vmovaps", "vmovups",
}


class BinaryAnalyzer:
    """PE + MSVC x64 RTTI + .pdata + Capstone analyzer."""

    def __init__(self, dll_path: str) -> None:
        self.dll_path = dll_path
        self.raw = Path(dll_path).read_bytes()
        self.pe = pefile.PE(data=self.raw, fast_load=True)
        self.pe.parse_data_directories(
            directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_EXCEPTION"]]
        )
        self.image_base: int = self.pe.OPTIONAL_HEADER.ImageBase
        self.sections: list[tuple[str, int, int, int, int]] = []
        for s in self.pe.sections:
            name = s.Name.decode("ascii", errors="ignore").rstrip("\x00")
            va = s.VirtualAddress
            vsize = s.Misc_VirtualSize
            raw_ptr = s.PointerToRawData
            raw_size = s.SizeOfRawData
            self.sections.append((name, va, vsize, raw_ptr, raw_size))

        self.text_sec = self._get_sec(".text")
        self.rdata_sec = self._get_sec(".rdata")
        self.data_sec = self._get_sec(".data")

        # .pdata sorted ranges
        self.funcs: list[tuple[int, int, int]] = []
        for entry in self.pe.DIRECTORY_ENTRY_EXCEPTION:
            st = entry.struct
            self.funcs.append((st.BeginAddress, st.EndAddress, st.UnwindData))
        self.funcs.sort(key=lambda x: x[0])
        self.func_begins = [f[0] for f in self.funcs]
        self.func_by_begin: dict[int, tuple[int, int, int]] = {f[0]: f for f in self.funcs}

        self.md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
        self.md.detail = False  # fast default; parse operands textually + imm/rip directly

        self.rtti_classes: dict[str, dict[str, Any]] = {}
        self.vtable_by_rva: dict[int, dict[str, Any]] = {}
        self.slot_owners: dict[int, list[str]] = defaultdict(list)

    def _get_sec(self, target: str) -> tuple[str, int, int, int, int]:
        for s in self.sections:
            if s[0] == target:
                return s
        raise RuntimeError(f"Missing section {target}")

    def rva_to_off(self, rva: int) -> int | None:
        for _, va, vsize, raw_ptr, raw_size in self.sections:
            if va <= rva < va + min(vsize, raw_size):
                return raw_ptr + (rva - va)
        return None

    def read_bytes(self, rva: int, size: int) -> bytes | None:
        off = self.rva_to_off(rva)
        if off is None or off + size > len(self.raw):
            return None
        return self.raw[off : off + size]

    def read_u32(self, rva: int) -> int | None:
        b = self.read_bytes(rva, 4)
        return struct.unpack("<I", b)[0] if b else None

    def read_i32(self, rva: int) -> int | None:
        b = self.read_bytes(rva, 4)
        return struct.unpack("<i", b)[0] if b else None

    def read_u64(self, rva: int) -> int | None:
        b = self.read_bytes(rva, 8)
        return struct.unpack("<Q", b)[0] if b else None

    def read_cstring(self, rva: int, max_len: int = 160) -> str | None:
        off = self.rva_to_off(rva)
        if off is None:
            return None
        end = self.raw.find(b"\x00", off, min(len(self.raw), off + max_len))
        if end <= off:
            return None
        chunk = self.raw[off:end]
        if len(chunk) < 3:
            return None
        if all(32 <= c < 127 or c in (9, 10, 13) for c in chunk):
            return chunk.decode("ascii")
        return None

    def read_wstring(self, rva: int, max_chars: int = 120) -> str | None:
        off = self.rva_to_off(rva)
        if off is None or off + 6 > len(self.raw):
            return None
        chars: list[int] = []
        for i in range(max_chars):
            if off + i * 2 + 2 > len(self.raw):
                return None
            code = struct.unpack_from("<H", self.raw, off + i * 2)[0]
            if code == 0:
                break
            if not (32 <= code < 127):
                return None
            chars.append(code)
        if len(chars) >= 3:
            return "".join(chr(c) for c in chars)
        return None

    def in_text(self, rva: int) -> bool:
        _, va, vsize, _, _ = self.text_sec
        return va <= rva < va + vsize

    def in_rdata(self, rva: int) -> bool:
        _, va, vsize, _, _ = self.rdata_sec
        return va <= rva < va + vsize

    def find_func(self, rva: int) -> tuple[int, int, int] | None:
        idx = bisect.bisect_right(self.func_begins, rva) - 1
        if idx >= 0:
            b, e, u = self.funcs[idx]
            if b <= rva < e:
                return (b, e, u)
        return None

    @staticmethod
    def demangle_msvc_td(raw_name: str) -> str:
        # ".?AVMoveController@@" -> "MoveController"
        # ".?AV?$TMove@VPlayer@@@..." -> readable form
        s = raw_name
        if s.startswith(".?AV") or s.startswith(".?AU"):
            s = s[4:]
        if s.endswith("@@"):
            s = s[:-2]
        parts = [p for p in s.split("@") if p]
        if len(parts) > 1:
            return "::".join(reversed(parts))
        return s

    def scan_rtti(self) -> None:
        """Scan .data TypeDescriptors -> .rdata CompleteObjectLocators -> VTables."""
        _, d_va, _, d_raw, d_rsize = self.data_sec
        data_blob = self.raw[d_raw : d_raw + d_rsize]

        # Find all TypeDescriptors in .data by searching for b".?AV" and b".?AU"
        td_by_rva: dict[int, str] = {}
        for prefix in (b".?AV", b".?AU"):
            pos = 0
            while True:
                idx = data_blob.find(prefix, pos)
                if idx == -1:
                    break
                pos = idx + 4
                if idx < 16:
                    continue
                end = data_blob.find(b"\x00", idx, idx + 256)
                if end == -1:
                    continue
                raw_name = data_blob[idx:end].decode("ascii", errors="ignore")
                td_rva = d_va + (idx - 16)
                td_by_rva[td_rva] = self.demangle_msvc_td(raw_name)

        _, r_va, _, r_raw, r_rsize = self.rdata_sec
        rdata_blob = self.raw[r_raw : r_raw + r_rsize]

        # Build reverse map of qword values (ImageBase + rva) -> rdata offset of pointer
        # Scan .rdata at 4-byte alignment for CompleteObjectLocator (signature == 1)
        col_by_rva: dict[int, dict[str, Any]] = {}
        for off in range(0, len(rdata_blob) - 24, 4):
            sig, offset, cd_off, p_td, p_chd, p_self = struct.unpack_from("<IIIIII", rdata_blob, off)
            if sig != 1:
                continue
            col_rva = r_va + off
            if p_self != col_rva:
                continue
            if p_td not in td_by_rva:
                continue
            if not self.in_rdata(p_chd):
                continue
            bases = self._parse_chd_bases(p_chd, td_by_rva)
            col_by_rva[col_rva] = {
                "col_rva": col_rva,
                "class_name": td_by_rva[p_td],
                "offset": offset,
                "cd_offset": cd_off,
                "td_rva": p_td,
                "chd_rva": p_chd,
                "bases": bases,
            }

        # Scan .rdata at 8-byte alignment for meta pointers to CompleteObjectLocator
        ib = self.image_base
        for off in range(0, len(rdata_blob) - 16, 8):
            q = struct.unpack_from("<Q", rdata_blob, off)[0]
            col_rva = q - ib
            if col_rva not in col_by_rva:
                continue
            col = col_by_rva[col_rva]
            vt_rva = r_va + off + 8
            slots: list[dict[str, Any]] = []
            s_off = off + 8
            slot_idx = 0
            while s_off + 8 <= len(rdata_blob):
                fn_va = struct.unpack_from("<Q", rdata_blob, s_off)[0]
                fn_rva = fn_va - ib
                if not self.in_text(fn_rva):
                    break
                finfo = self.find_func(fn_rva)
                # Guard against running into the next vtable's COL pointer
                if s_off + 8 < len(rdata_blob) and (fn_va - ib) in col_by_rva:
                    break
                slots.append({
                    "slot": slot_idx,
                    "func_rva": fn_rva,
                    "pdata_begin": finfo[0] if finfo else None,
                    "pdata_end": finfo[1] if finfo else None,
                    "size": (finfo[1] - finfo[0]) if finfo else None,
                })
                cname = col["class_name"]
                owner_tag = f"{cname}[offset=0x{col['offset']:x}]::slot[{slot_idx}]"
                if finfo:
                    self.slot_owners[finfo[0]].append(owner_tag)
                else:
                    self.slot_owners[fn_rva].append(owner_tag)
                slot_idx += 1
                s_off += 8

            vt_entry = {
                "vtable_rva": vt_rva,
                "col_rva": col_rva,
                "offset": col["offset"],
                "slot_count": len(slots),
                "slots": slots,
            }
            self.vtable_by_rva[vt_rva] = {**col, **vt_entry}
            cname = col["class_name"]
            c_rec = self.rtti_classes.setdefault(
                cname,
                {
                    "class_name": cname,
                    "bases": col["bases"],
                    "vtables": [],
                },
            )
            c_rec["vtables"].append(vt_entry)

    def _parse_chd_bases(self, chd_rva: int, td_by_rva: dict[int, str]) -> list[str]:
        b = self.read_bytes(chd_rva, 16)
        if not b:
            return []
        _, _, num_bases, p_bca = struct.unpack("<IIII", b)
        if num_bases == 0 or num_bases > 64 or not self.in_rdata(p_bca):
            return []
        bca = self.read_bytes(p_bca, num_bases * 4)
        if not bca:
            return []
        bases: list[str] = []
        for i in range(num_bases):
            bc_rva = struct.unpack_from("<I", bca, i * 4)[0]
            td_rva = self.read_u32(bc_rva)
            if td_rva and td_rva in td_by_rva:
                bases.append(td_by_rva[td_rva])
        return bases

    def is_target_class(self, cname: str, bases: list[str]) -> bool:
        if cname in CORE_CLASSES:
            return True
        if "PlayerController" in bases or "MoveController" in bases:
            return True
        keywords = (
            "PlayerController",
            "PlayerDI",
            "PlayerFpp",
            "CameraFPP",
            "NaturalMovement",
            "EdgeGrab",
            "LandingController",
            "LookController",
            "WeaponMelee",
            "ChargeController",
            "StompFinisher",
            "GrabController",
            "RopeLocomotion",
            "PlayerFitness",
            "PlayerStamina",
            "DodgeModule",
            "PlayerFallAmortizer",
            "PlayerFallHelper",
        )
        return any(k in cname for k in keywords)

    def scan_all_text_rdata_xrefs(self) -> dict[str, list[dict[str, Any]]]:
        """Fast byte scan across all .text for RIP-relative accesses to key .rdata strings."""
        _, t_va, _, t_raw, t_rsize = self.text_sec
        text_blob = self.raw[t_raw : t_raw + t_rsize]
        _, r_va, r_vsize, _, _ = self.rdata_sec
        r_end = r_va + r_vsize

        # Match LEA / MOV r64, [rip + disp32] (48/4c 8d/8b ModRM_05 disp32)
        # ModRM with mod=00, rm=101 -> (modrm & 0xC7) == 0x05
        pattern = re.compile(rb"[\x48\x4c][\x8d\x8b][\x05\x0d\x15\x1d\x25\x2d\x35\x3d]")
        str_xrefs: dict[str, list[dict[str, Any]]] = defaultdict(list)
        for m in pattern.finditer(text_blob):
            pos = m.start()
            if pos + 7 > len(text_blob):
                continue
            disp = struct.unpack_from("<i", text_blob, pos + 3)[0]
            insn_rva = t_va + pos
            target_rva = insn_rva + 7 + disp
            if not (r_va <= target_rva < r_end):
                continue
            s = self.read_cstring(target_rva, 128)
            if not s:
                s = self.read_wstring(target_rva, 96)
            if not s:
                continue
            # Filter to relevant identifiers / player strings so output stays crisp
            if self._is_interesting_string(s):
                finfo = self.find_func(insn_rva)
                str_xrefs[s].append({
                    "insn_rva": hex(insn_rva),
                    "func_rva": hex(finfo[0]) if finfo else None,
                    "func_end": hex(finfo[1]) if finfo else None,
                    "owners": self.slot_owners.get(finfo[0], []) if finfo else [],
                })
        return dict(str_xrefs)

    @staticmethod
    def _is_interesting_string(s: str) -> bool:
        tokens = (
            "Melee", "duck", "capsule", "Jump", "Edge", "Grab", "Hang", "Shimmy",
            "WallRun", "WallJump", "Climb", "Slide", "Dodge", "Tackle", "Stomp",
            "Fall", "Amortizer", "Landing", "Roll", "Rope", "Grappl", "Fitness",
            "Stamina", "Exhaust", "Sprint", "Walk", "Crouch", "Strafe", "Lookback",
            "EyeCamera", "Spine", "Camera", "Fpp", "FPP", "FOV", "fov", "Bob",
            "Kick", "Dropkick", "GroundPound", "Charge", "Hit", "Anim", "Seq",
            "NM_", "Parkour", "Vault", "Mantle", "Player", "Swinging", "Recoil",
            "Sway", "Speed", "Slope", "Gravity", "Air", "Control",
        )
        return any(t in s for t in tokens)

    def analyze_function(self, begin_rva: int, end_rva: int) -> dict[str, Any]:
        """Disassemble one .pdata function and extract strings, float/double/imm literals, calls, and vcalls."""
        size = end_rva - begin_rva
        code = self.read_bytes(begin_rva, size)
        if not code:
            return {"rva": hex(begin_rva), "error": "unreadable"}

        strings: list[tuple[int, str]] = []
        floats: list[tuple[int, float, int]] = []
        doubles: list[tuple[int, float, int]] = []
        imm_floats: list[tuple[int, float, int]] = []
        direct_calls: list[int] = []
        vtable_offsets: list[tuple[int, str]] = []

        seen_str: set[str] = set()
        seen_flt: set[tuple[float, int]] = set()

        rip_re = re.compile(r"\[rip ([+-]) (0x[0-9a-f]+|[0-9]+)\]")
        vcall_re = re.compile(r"\[([a-z0-9]+) \+ (0x[0-9a-f]+|[0-9]+)\]")

        for insn in self.md.disasm(code, begin_rva):
            mn = insn.mnemonic
            op = insn.op_str

            # Direct calls & jmp-tail-calls outside self
            if mn in ("call", "jmp"):
                if op.startswith("0x"):
                    tgt = int(op, 16)
                    if self.in_text(tgt) and not (begin_rva <= tgt < end_rva):
                        f = self.find_func(tgt)
                        direct_calls.append(f[0] if f else tgt)
                elif "qword ptr [" in op:
                    vm = vcall_re.search(op)
                    if vm and vm.group(1) != "rsp" and vm.group(1) != "rbp":
                        off_val = int(vm.group(2), 0)
                        vtable_offsets.append((insn.address, f"{mn} [{vm.group(1)} + 0x{off_val:x}] (slot {off_val // 8})"))

            # Immediate 32-bit float bit-patterns moved to GPRs
            if mn == "mov" and ", 0x" in op:
                rhs = op.split(",")[-1].strip()
                if rhs.startswith("0x"):
                    try:
                        iv = int(rhs, 16)
                        if 0x3A83126F <= (iv & 0x7FFFFFFF) <= 0x461C4000:
                            fv = struct.unpack("<f", struct.pack("<I", iv & 0xFFFFFFFF))[0]
                            if math.isfinite(fv) and 0.001 <= abs(fv) <= 10000.0:
                                imm_floats.append((insn.address, round(fv, 6), iv & 0xFFFFFFFF))
                    except ValueError:
                        pass

            # RIP-relative memory accesses
            rm = rip_re.search(op)
            if rm:
                sign = 1 if rm.group(1) == "+" else -1
                disp = int(rm.group(2), 0)
                target = insn.address + insn.size + sign * disp
                if self.in_rdata(target):
                    if mn in ("lea", "mov") and "xmm" not in op:
                        s = self.read_cstring(target, 140) or self.read_wstring(target, 96)
                        if s and s not in seen_str:
                            seen_str.add(s)
                            strings.append((target, s))
                    elif mn in FLOAT_LOAD_MNEMONICS:
                        raw4 = self.read_u32(target)
                        if raw4 is not None:
                            fv = struct.unpack("<f", struct.pack("<I", raw4))[0]
                            if math.isfinite(fv):
                                key = (round(fv, 6), raw4)
                                if key not in seen_flt:
                                    seen_flt.add(key)
                                    floats.append((target, round(fv, 6), raw4))
                    elif mn in DOUBLE_LOAD_MNEMONICS:
                        raw8 = self.read_u64(target)
                        if raw8 is not None:
                            dv = struct.unpack("<d", struct.pack("<Q", raw8))[0]
                            if math.isfinite(dv):
                                doubles.append((target, round(dv, 6), raw8))
                    elif mn in VEC128_LOAD_MNEMONICS:
                        b16 = self.read_bytes(target, 16)
                        if b16:
                            vals = struct.unpack("<4f", b16)
                            if all(math.isfinite(v) and abs(v) < 1e6 for v in vals):
                                for idx, v in enumerate(vals):
                                    if abs(v) > 1e-6:
                                        r4 = struct.unpack("<I", struct.pack("<f", v))[0]
                                        key = (round(v, 6), r4)
                                        if key not in seen_flt:
                                            seen_flt.add(key)
                                            floats.append((target + idx * 4, round(v, 6), r4))

        # Deduplicate direct calls preserving order
        uniq_calls: list[int] = []
        seen_c: set[int] = set()
        for c in direct_calls:
            if c not in seen_c:
                seen_c.add(c)
                uniq_calls.append(c)

        return {
            "rva": hex(begin_rva),
            "end": hex(end_rva),
            "size": size,
            "owners": self.slot_owners.get(begin_rva, []),
            "strings": [{"rva": hex(r), "text": s} for r, s in strings],
            "floats": [{"rva": hex(r), "val": v, "bits": hex(b)} for r, v, b in floats],
            "doubles": [{"rva": hex(r), "val": v, "bits": hex(b)} for r, v, b in doubles],
            "imm_floats": [{"insn": hex(i), "val": v, "bits": hex(b)} for i, v, b in imm_floats],
            "callees": [hex(c) for c in uniq_calls],
            "vcalls": [{"insn": hex(i), "op": o} for i, o in vtable_offsets[:40]],
        }

    def format_annotated_disasm(self, begin_rva: int, end_rva: int | None = None, func_meta: dict[int, dict[str, Any]] | None = None) -> str:
        """Render annotated x64 disassembly with inline strings, floats, and call labels."""
        if end_rva is None:
            f = self.find_func(begin_rva)
            if not f:
                return f"; RVA {hex(begin_rva)} not in .pdata\n"
            begin_rva, end_rva, _ = f
        code = self.read_bytes(begin_rva, end_rva - begin_rva)
        if not code:
            return f"; Unreadable {hex(begin_rva)}..{hex(end_rva)}\n"

        rip_re = re.compile(r"\[rip ([+-]) (0x[0-9a-f]+|[0-9]+)\]")
        vcall_re = re.compile(r"\[([a-z0-9]+) \+ (0x[0-9a-f]+|[0-9]+)\]")

        owners = self.slot_owners.get(begin_rva, [])
        lines = [
            f"; Function {hex(begin_rva)} .. {hex(end_rva)} (size={end_rva - begin_rva} bytes)",
            f"; Owners: {', '.join(owners) if owners else 'internal/helper'}",
            "",
        ]
        for insn in self.md.disasm(code, begin_rva):
            notes: list[str] = []
            mn = insn.mnemonic
            op = insn.op_str

            if mn in ("call", "jmp") and op.startswith("0x"):
                tgt = int(op, 16)
                if not (begin_rva <= tgt < end_rva):
                    f = self.find_func(tgt)
                    trva = f[0] if f else tgt
                    own = self.slot_owners.get(trva, [])
                    label = f"fn_{hex(trva)}"
                    if own:
                        label = own[0]
                    elif func_meta and trva in func_meta:
                        strs = [x["text"] for x in func_meta[trva].get("strings", [])[:2]]
                        if strs:
                            label += f" str={strs}"
                    notes.append(f"-> {label}")
            elif mn in ("call", "jmp") and "qword ptr [" in op:
                vm = vcall_re.search(op)
                if vm and vm.group(1) not in ("rsp", "rbp"):
                    off_val = int(vm.group(2), 0)
                    notes.append(f"vslot={off_val // 8} (+0x{off_val:x})")

            if mn == "mov" and ", 0x" in op:
                rhs = op.split(",")[-1].strip()
                if rhs.startswith("0x"):
                    try:
                        iv = int(rhs, 16)
                        if 0x3A83126F <= (iv & 0x7FFFFFFF) <= 0x461C4000:
                            fv = struct.unpack("<f", struct.pack("<I", iv & 0xFFFFFFFF))[0]
                            if math.isfinite(fv) and 0.001 <= abs(fv) <= 10000.0:
                                notes.append(f"imm_f32={fv:.6g}")
                    except ValueError:
                        pass

            rm = rip_re.search(op)
            if rm:
                sign = 1 if rm.group(1) == "+" else -1
                disp = int(rm.group(2), 0)
                target = insn.address + insn.size + sign * disp
                if self.in_rdata(target):
                    if mn in FLOAT_LOAD_MNEMONICS:
                        raw4 = self.read_u32(target)
                        if raw4 is not None:
                            fv = struct.unpack("<f", struct.pack("<I", raw4))[0]
                            if math.isfinite(fv):
                                notes.append(f"f32={fv:.6g} ({hex(raw4)})")
                    elif mn in DOUBLE_LOAD_MNEMONICS:
                        raw8 = self.read_u64(target)
                        if raw8 is not None:
                            dv = struct.unpack("<d", struct.pack("<Q", raw8))[0]
                            if math.isfinite(dv):
                                notes.append(f"f64={dv:.6g} ({hex(raw8)})")
                    elif mn in VEC128_LOAD_MNEMONICS:
                        b16 = self.read_bytes(target, 16)
                        if b16:
                            vals = struct.unpack("<4f", b16)
                            if all(math.isfinite(v) and abs(v) < 1e6 for v in vals):
                                notes.append("vec4=(" + ", ".join(f"{v:.4g}" for v in vals) + ")")
                    else:
                        s = self.read_cstring(target, 140) or self.read_wstring(target, 96)
                        if s:
                            notes.append(f'str="{s}"')
                        else:
                            raw4 = self.read_u32(target)
                            if raw4 is not None:
                                fv = struct.unpack("<f", struct.pack("<I", raw4))[0]
                                if math.isfinite(fv) and 1e-4 <= abs(fv) <= 1e5:
                                    notes.append(f"[rdata {hex(target)} maybe_f32={fv:.6g}]")

            comment = (" ; " + " | ".join(notes)) if notes else ""
            lines.append(f"0x{insn.address:08x}: {mn:10s} {op:46s}{comment}")
        return "\n".join(lines) + "\n"

    def run_full_scan(self) -> dict[str, Any]:
        t0 = time.time()
        print("[1/4] Scanning MSVC x64 RTTI & VTables...")
        self.scan_rtti()
        print(f"      Total RTTI classes: {len(self.rtti_classes)}, VTables: {len(self.vtable_by_rva)}")

        target_classes = {
            cname: cdata
            for cname, cdata in self.rtti_classes.items()
            if self.is_target_class(cname, cdata["bases"])
        }
        print(f"      Matched target classes: {len(target_classes)}")

        print("[2/4] Scanning .text for key .rdata string xrefs...")
        str_xrefs = self.scan_all_text_rdata_xrefs()
        print(f"      Key distinct strings referenced in .text: {len(str_xrefs)}")

        # Collect functions to disassemble:
        # 1) All .pdata functions in 0xcdb000..0xdf5000
        # 2) All VTable slot functions for target_classes
        # 3) All functions holding key string xrefs
        # 4) 1-hop callees of (2) and (3) + 2-hop non-tiny callees of (2)
        seed_rvas: set[int] = set()
        for b, e, _ in self.funcs:
            if PLAYER_CTRL_RANGE[0] <= b < PLAYER_CTRL_RANGE[1]:
                seed_rvas.add(b)
        vtable_seed_rvas: set[int] = set()
        for cdata in target_classes.values():
            for vt in cdata["vtables"]:
                for sl in vt["slots"]:
                    fb = sl["pdata_begin"] or sl["func_rva"]
                    seed_rvas.add(fb)
                    vtable_seed_rvas.add(fb)
        for entries in str_xrefs.values():
            for ent in entries:
                if ent["func_rva"]:
                    seed_rvas.add(int(ent["func_rva"], 16))

        print(f"[3/4] Analyzing {len(seed_rvas)} seed functions + 1-hop callees...")
        func_map: dict[int, dict[str, Any]] = {}
        queue = sorted(seed_rvas)
        visited: set[int] = set()
        hop1_to_scan: set[int] = set()

        for rva in queue:
            if rva in visited:
                continue
            visited.add(rva)
            finfo = self.find_func(rva)
            if not finfo:
                continue
            res = self.analyze_function(finfo[0], finfo[1])
            func_map[finfo[0]] = res
            if finfo[0] in vtable_seed_rvas or (PLAYER_CTRL_RANGE[0] <= finfo[0] < PLAYER_CTRL_RANGE[1]):
                for c_hex in res.get("callees", []):
                    crva = int(c_hex, 16)
                    if crva not in visited:
                        hop1_to_scan.add(crva)

        for rva in sorted(hop1_to_scan):
            if rva in visited:
                continue
            visited.add(rva)
            finfo = self.find_func(rva)
            if not finfo:
                continue
            func_map[finfo[0]] = self.analyze_function(finfo[0], finfo[1])

        # Build reverse caller edges inside our analyzed set
        callers_map: dict[str, list[str]] = defaultdict(list)
        for frva, fdata in func_map.items():
            fhex = hex(frva)
            for chex in fdata.get("callees", []):
                callers_map[chex].append(fhex)
        for frva, fdata in func_map.items():
            fdata["callers"] = callers_map.get(hex(frva), [])

        print(f"[4/4] Writing JSON ({len(func_map)} functions) and exporting key disasms...")
        OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
        OUT_DISASM.mkdir(parents=True, exist_ok=True)

        core_summary: dict[str, Any] = {}
        for cname in CORE_CLASSES:
            matches = {k: v for k, v in target_classes.items() if k == cname or k.endswith("::" + cname)}
            core_summary[cname] = matches

        payload = {
            "dll": self.dll_path,
            "image_base": hex(self.image_base),
            "player_controller_range": [hex(PLAYER_CTRL_RANGE[0]), hex(PLAYER_CTRL_RANGE[1])],
            "sections": [
                {"name": n, "va": hex(va), "vsize": hex(vs), "raw_ptr": hex(rp), "raw_size": hex(rs)}
                for n, va, vs, rp, rs in self.sections
            ],
            "rtti_total_classes": len(self.rtti_classes),
            "core_classes": core_summary,
            "target_classes": target_classes,
            "string_xrefs": str_xrefs,
            "functions": {hex(k): v for k, v in sorted(func_map.items())},
        }
        OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")

        # Export annotated disasm for nontrivial slots of our 18 core classes
        exported = 0
        for cname in CORE_CLASSES:
            cdir = OUT_DISASM / cname
            cdir.mkdir(parents=True, exist_ok=True)
            cdata = target_classes.get(cname)
            if not cdata:
                continue
            for vt in cdata["vtables"]:
                for sl in vt["slots"]:
                    fb = sl["pdata_begin"] or sl["func_rva"]
                    sz = sl["size"] or 0
                    if sz < 48:
                        continue
                    asm = self.format_annotated_disasm(fb, sl["pdata_end"], func_map)
                    (cdir / f"slot_{sl['slot']:02d}_0x{fb:08x}.asm").write_text(asm, encoding="utf-8")
                    exported += 1

        elapsed = time.time() - t0
        print(f"Done in {elapsed:.2f}s -> {OUT_JSON} ({exported} core disasms -> {OUT_DISASM})")
        return payload


def main() -> int:
    ap = argparse.ArgumentParser(description="Reverse-engineer Dying Light 1 gamedll_x64_rwdi.dll")
    ap.add_argument("--dll", default=DEFAULT_DLL, help="Path to gamedll_x64_rwdi.dll")
    ap.add_argument("--scan", action="store_true", help="Run full RTTI + .pdata + xref scan -> dl1_binary_map.json")
    ap.add_argument("--disasm", nargs="+", help="Disassemble one or more RVAs (hex, e.g. 0xce1234)")
    ap.add_argument("--out", help="Optional output path when using --disasm")
    ap.add_argument("--find-str", help="Search dl1_binary_map.json string_xrefs by substring")
    ap.add_argument("--class-info", help="Print RTTI VTable slots + strings/floats from dl1_binary_map.json")
    args = ap.parse_args()

    if args.scan:
        ana = BinaryAnalyzer(args.dll)
        ana.run_full_scan()
        return 0

    if args.disasm:
        ana = BinaryAnalyzer(args.dll)
        ana.scan_rtti()
        func_meta: dict[int, dict[str, Any]] = {}
        if OUT_JSON.exists():
            cached = json.loads(OUT_JSON.read_text(encoding="utf-8"))
            func_meta = {int(k, 16): v for k, v in cached.get("functions", {}).items()}
        chunks: list[str] = []
        for r_str in args.disasm:
            rva = int(r_str, 16)
            chunks.append(ana.format_annotated_disasm(rva, None, func_meta))
        txt = ("\n" + "=" * 78 + "\n").join(chunks)
        if args.out:
            Path(args.out).parent.mkdir(parents=True, exist_ok=True)
            Path(args.out).write_text(txt, encoding="utf-8")
            print(f"Wrote {args.out}")
        else:
            print(txt)
        return 0

    if args.find_str:
        if not OUT_JSON.exists():
            print("Run --scan first", file=sys.stderr)
            return 1
        data = json.loads(OUT_JSON.read_text(encoding="utf-8"))
        q = args.find_str.lower()
        for s, xrefs in sorted(data["string_xrefs"].items()):
            if q in s.lower():
                print(f'"{s}" -> {len(xrefs)} refs:')
                for x in xrefs[:10]:
                    print(f"   fn={x['func_rva']} insn={x['insn_rva']} owners={x['owners']}")
        return 0

    if args.class_info:
        if not OUT_JSON.exists():
            print("Run --scan first", file=sys.stderr)
            return 1
        data = json.loads(OUT_JSON.read_text(encoding="utf-8"))
        q = args.class_info.lower()
        for cname, cdata in sorted(data["target_classes"].items()):
            if q not in cname.lower():
                continue
            print(f"\n=== {cname} | bases={cdata['bases']} ===")
            for vt in cdata["vtables"]:
                print(f"  VTable {hex(vt['vtable_rva'])} offset=0x{vt['offset']:x} slots={vt['slot_count']}")
                for sl in vt["slots"]:
                    fb = sl["pdata_begin"] or sl["func_rva"]
                    fmeta = data["functions"].get(hex(fb), {})
                    strs = [x["text"] for x in fmeta.get("strings", [])[:4]]
                    flts = [x["val"] for x in fmeta.get("floats", [])[:6]]
                    if (sl["size"] or 0) >= 32 or strs or flts:
                        print(f"    [{sl['slot']:02d}] {hex(fb)} sz={sl['size']} strs={strs} flts={flts}")
        return 0

    ap.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
