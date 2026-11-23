"""Audit Dying Light 1 mesh vertex structs (bone weights/indices), DDS texture parts, and ANM2 v42 headers."""
from __future__ import annotations

import struct
from pathlib import Path

from extract_dl_assets import DL_DATA, RPackReader, extract_2fzn_records

OUT_JSON = Path(__file__).resolve().parent.parent / "assets_ref" / "dl_re_raw" / "mesh_anim_audit.txt"


def audit_mesh(rp: RPackReader, name: str) -> list[str]:
    lines = [f"=== MESH {name} ==="]
    parts = rp.read_entry(name)
    for k, v in sorted(parts.items()):
        lines.append(f"  part 0x{k:02x}: {len(v)} bytes")
    b10 = parts[0x10]
    recs = extract_2fzn_records(b10)
    lines.append(f"  2FZn records: {len(recs)}")
    for idx, r in enumerate(recs[:6]):
        lines.append(f"    rec[{idx}]: vb_off={r[0]} vcnt={r[1]} ib_off={r[2]} icnt={r[3]}")

    # Inspect 40-byte vertex struct of first record
    vb = parts[0xF0]
    if recs:
        vb_off, vcnt, _, _ = recs[0]
        lines.append("  First 5 vertices (40B stride):")
        for vi in range(min(5, vcnt)):
            o = vb_off + vi * 40
            x, y, z = struct.unpack("<3f", vb[o : o + 12])
            b12_20 = vb[o + 12 : o + 20]
            nrm = vb[o + 20 : o + 24]
            uv = struct.unpack("<2e", vb[o + 24 : o + 28])
            b28_40 = vb[o + 28 : o + 40]
            lines.append(
                f"    v{vi}: pos=({x:.3f},{y:.3f},{z:.3f}) b12..19={b12_20.hex()} "
                f"nrm={nrm.hex()} uv=({uv[0]:.3f},{uv[1]:.3f}) b28..39={b28_40.hex()}"
            )

    # Search b10 for ASCII bone-like strings
    ascii_strings = []
    cur = bytearray()
    for ch in b10:
        if 32 <= ch < 127:
            cur.append(ch)
        else:
            if len(cur) >= 3:
                ascii_strings.append(cur.decode("ascii"))
            cur.clear()
    lines.append(f"  0x10 ASCII strings ({len(ascii_strings)}): {ascii_strings[:40]}")
    return lines


def audit_tex(rp: RPackReader, name: str) -> list[str]:
    parts = rp.read_entry(name)
    hdr = parts[0x20]
    w, h, d, mips, flags, fmt = struct.unpack("<HHHHII", hdr[:16])
    sizes = {f"0x{k:02x}": len(v) for k, v in sorted(parts.items())}
    return [f"TEX {name}: {w}x{h} mips={mips} fmt=0x{fmt:x} flags=0x{flags:x} parts={sizes}"]


def audit_anm2(rp: RPackReader, name: str) -> list[str]:
    lines = [f"=== ANM2 {name} ==="]
    parts = rp.read_entry(name)
    for k, v in sorted(parts.items()):
        lines.append(f"  part 0x{k:02x}: {len(v)} bytes | head={v[:32].hex()}")
        if v[:4] == b"ANM2":
            ver, flags, frames, bones, hdr_off = struct.unpack("<IIHH I", v[4:20])
            lines.append(f"    ANM2 ver={ver} flags={flags} frames={frames} bones={bones} hdr_off={hdr_off}")
            # Dump ints from offset 20..120
            ints = struct.unpack("<16I", v[20:84])
            lines.append(f"    hdr ints[20..84]: {[hex(x) for x in ints]}")
            # ASCII bone names if present
            strs = []
            cur = bytearray()
            for ch in v[64:min(len(v), 4096)]:
                if 32 <= ch < 127:
                    cur.append(ch)
                else:
                    if len(cur) >= 3:
                        strs.append(cur.decode("ascii"))
                    cur.clear()
            lines.append(f"    strings: {strs[:30]}")
    return lines


def main() -> int:
    out: list[str] = []
    meshes = RPackReader(DL_DATA / "common_meshes_PC.rpack")
    for m in ["player_dieselpunk_fpp", "zombie_man_a", "zombie_voleteile", "zombie_goon"]:
        out.extend(audit_mesh(meshes, m))
    meshes.close()

    tex0 = RPackReader(DL_DATA / "common_textures_0_pc.rpack")
    for t in ["diesel_punk_hands_dif", "diesel_punk_torso_dif", "diesel_punk_legs_dif", "goon_body_dif", "infected_torso_a_jeans_dif"]:
        out.extend(audit_tex(tex0, t))
    tex0.close()

    anims = RPackReader(DL_DATA / "common_anims_PC.rpack")
    fpp_keys = [k for k in anims.entries.keys() if "fpp_stick_melee_attack_rl_empty" in k or "fpp_unarmed_sprintforward" in k or "fpp_kick_forward" in k]
    out.append(f"Matching FPP anim keys: {fpp_keys[:10]}")
    for ak in fpp_keys[:3]:
        out.extend(audit_anm2(anims, ak))
    anims.close()

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text("\n".join(out), encoding="utf-8")
    print("\n".join(out[:80]))
    print(f"... wrote {len(out)} lines to {OUT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
