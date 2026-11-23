"""Extract and summarize Dying Light 1 Data0.pak / Data2.pak / RP6L data into assets_ref/dl_re_raw/dl1_data.json."""
from __future__ import annotations

import json
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DL_ROOT = Path(r"D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com\DW")
OUT_JSON = ROOT / "assets_ref" / "dl_re_raw" / "dl1_data.json"

SUBSYSTEM_RULES: list[tuple[str, tuple[str, ...]]] = [
    ("Grapple", ("rope", "grapple", "hook")),
    ("WallRun", ("wallrun", "walljump", "wall_run", "wall_jump")),
    ("Climb/Hang", ("climb", "hang", "shimmy", "ledge", "jumpin180", "jumpfromhang", "sidejump", "edge")),
    ("Parkour/NM", ("naturalmovement", "vault", "nm_", "jumpon", "jumpover", "parkour", "stepheight", "stair", "exhausted")),
    ("Slide", ("slide",)),
    ("Dodge", ("dodge",)),
    ("Tackle", ("tackle", "ram")),
    ("Fall/Amortizer", ("fall", "amortizer", "damping", "landing", "ragdoll", "maxsafefall")),
    ("Dual Stamina/Fitness", ("fitness", "stamina", "fatigue", "exhaust")),
    ("Jump", ("jump", "gravity", "aircontrol", "coyote")),
    ("Locomotion", ("speed", "walk", "sprint", "run", "crouch", "duck", "strafe", "back", "move", "accel", "decel", "slope", "angle")),
    ("Grab", ("grab", "bite", "struggle", "finisher")),
    ("Melee/Charge/Kick/Dropkick/Stomp/GroundPound", ("melee", "charge", "kick", "dropkick", "stomp", "groundpound", "pound", "wrestling", "swing", "hit", "damage", "force", "weapon", "naga")),
    ("Camera/FOV/Bob", ("fov", "cam", "bob", "shake", "look", "eye", "roll", "sway", "tilt")),
    ("Sonar", ("sense", "sonar", "survivor_sense", "highlight", "radar")),
]


def classify_prop(name: str) -> str:
    nl = name.lower()
    for subsys, kws in SUBSYSTEM_RULES:
        if any(k in nl for k in kws):
            return subsys
    return "Other"


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def eval_num(expr: str) -> float | str:
    s = expr.strip()
    if re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?(?:\s*\*\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+))?", s):
        if "*" in s:
            a, b = s.split("*", 1)
            return round(float(a) * float(b), 6)
        val = float(s)
        return int(val) if val.is_integer() and "." not in s else val
    return s.strip('"')


class PakReader:
    """Read entries with Data2.pak overriding Data0.pak (Chrome Engine priority)."""

    def __init__(self, dw_root: Path) -> None:
        self.z0 = zipfile.ZipFile(dw_root / "Data0.pak", "r")
        p2 = dw_root / "Data2.pak"
        self.z2 = zipfile.ZipFile(p2, "r") if p2.exists() else None
        self.n0 = set(self.z0.namelist())
        self.n2 = set(self.z2.namelist()) if self.z2 else set()

    def exists(self, path: str) -> bool:
        return path in self.n2 or path in self.n0

    def read_text(self, path: str) -> tuple[str, str]:
        if path in self.n2:
            return f"Data2.pak/{path}", self.z2.read(path).decode("utf-8", "replace")
        return f"Data0.pak/{path}", self.z0.read(path).decode("utf-8", "replace")

    def list_matching(self, prefix: str, suffix: str) -> list[str]:
        all_names = sorted(self.n0 | self.n2)
        return [n for n in all_names if n.lower().startswith(prefix) and n.lower().endswith(suffix)]

    def close(self) -> None:
        self.z0.close()
        if self.z2:
            self.z2.close()


def parse_xml_fragment(raw: str) -> ET.Element:
    body = re.sub(r"<\?xml[^>]*\?>", "", raw, flags=re.I)
    return ET.fromstring(f"<root>{body}</root>")


def parse_default_levels(pak: PakReader) -> dict:
    src, raw = pak.read_text("data/skills/default_levels.xml")
    root = parse_xml_fragment(raw)
    base_by_subsys: dict[str, dict[str, str]] = defaultdict(dict)
    base_props_count = 0
    level_blocks: list[dict] = []

    for lvl in root.findall(".//level"):
        lid = lvl.attrib.get("id", "")
        ltype = lvl.attrib.get("type", "Base")
        props = {p.attrib["n"]: p.attrib.get("v", "") for p in lvl.findall("prop") if "n" in p.attrib}
        level_blocks.append({"id": lid, "type": ltype, "prop_count": len(props), "props": props})
        if lid == "1" and ltype == "Base":
            for k, v in props.items():
                base_by_subsys[classify_prop(k)][k] = v
                base_props_count += 1

    # Also collect any props that appear ONLY in non-Base or higher-level blocks
    all_seen = {k for d in base_by_subsys.values() for k in d}
    extra_props: dict[str, dict[str, list]] = defaultdict(dict)
    for blk in level_blocks:
        if blk["id"] == "1" and blk["type"] == "Base":
            continue
        for k, v in blk["props"].items():
            if k not in all_seen:
                extra_props[classify_prop(k)].setdefault(k, []).append({"level": blk["id"], "type": blk["type"], "v": v})

    return {
        "source": src,
        "level_blocks_count": len(level_blocks),
        "base_level1_prop_count": base_props_count,
        "base_level1_by_subsystem": dict(base_by_subsys),
        "extra_non_base_props": dict(extra_props),
        "scaling_summary": [
            {"id": b["id"], "type": b["type"], "prop_count": b["prop_count"]}
            for b in level_blocks
            if b["prop_count"] > 0 and b["id"] in ("1", "2", "10", "24", "25", "60")
        ],
    }


def parse_skills_xml(pak: PakReader, rel_path: str) -> dict:
    src, raw = pak.read_text(rel_path)
    root = parse_xml_fragment(raw)
    skills = []
    for sk in root.findall(".//skill"):
        effects = [dict(e.attrib) for e in sk.findall("effect")]
        reqs = [dict(r.attrib) for r in sk.findall("level_req")] + [dict(r.attrib) for r in sk.findall("skill_req")]
        diff = [dict(d.attrib) for d in sk.findall("difficulty_req")]
        skills.append(
            {
                "id": sk.attrib.get("id", ""),
                "cat": sk.attrib.get("cat", ""),
                "tier": sk.attrib.get("tier", ""),
                "max_level": sk.attrib.get("max_level", ""),
                "auto_install": sk.attrib.get("auto_install", ""),
                "reqs": reqs,
                "difficulty_req": diff,
                "effects": effects,
            }
        )
    return {"source": src, "count": len(skills), "skills": skills}


def parse_buffs_xml(pak: PakReader) -> dict:
    src, raw = pak.read_text("data/skills/buffs.xml")
    root = parse_xml_fragment(raw)
    buffs = []
    for b in root.findall(".//buff"):
        props = [dict(p.attrib) for p in b.findall("property")]
        effects = [dict(e.attrib) for e in b.findall("effect")]
        timelines = [
            {"var": tl.attrib.get("var", ""), "keys": [dict(k.attrib) for k in tl.findall("key")]}
            for tl in b.findall("varlist_timeline")
        ]
        buffs.append(
            {
                "id": b.attrib.get("id", ""),
                "duration": b.attrib.get("duration", ""),
                "max_stacks": b.attrib.get("max_stacks", ""),
                "properties": props,
                "effects": effects,
                "timelines": timelines,
            }
        )
    return {"source": src, "count": len(buffs), "buffs": buffs}


def parse_scr_blocks(text: str) -> list[dict]:
    """Generic Chrome Engine .scr/.phx block & call parser."""
    cleaned = strip_comments(text)
    calls = []
    # Match Name(args) optionally followed by { ... }
    stack: list[dict] = [{"name": "_root", "args": [], "children": []}]
    token_re = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(([^()]*)\)|(\{)|(\})')
    pos = 0
    pending_node: dict | None = None
    for m in token_re.finditer(cleaned):
        if m.group(1):
            raw_args = [eval_num(a) for a in m.group(2).split(",")] if m.group(2).strip() else []
            node = {"name": m.group(1), "args": raw_args, "children": []}
            stack[-1]["children"].append(node)
            pending_node = node
        elif m.group(3):  # '{'
            stack.append(pending_node if pending_node is not None else {"name": "_anon", "args": [], "children": []})
            pending_node = None
        elif m.group(4):  # '}'
            if len(stack) > 1:
                stack.pop()
            pending_node = None
    return stack[0]["children"]


def parse_anim_script(pak: PakReader, rel_path: str) -> dict:
    src, raw = pak.read_text(rel_path)
    cleaned = strip_comments(raw)
    includes = re.findall(r'!include\("([^"]+)"\)', cleaned)

    # Parse SeqTrack(...) and SeqTrackAlias(...) and nested Event(...) blocks
    tracks = []
    aliases = []

    alias_re = re.compile(r'SeqTrackAlias\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')
    for m in alias_re.finditer(cleaned):
        aliases.append({"alias": m.group(1), "target": m.group(2)})

    seq_re = re.compile(r'SeqTrack\s*\(\s*([^)]+)\)', re.S)
    ev_re = re.compile(r'Event\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)')

    matches = list(seq_re.finditer(cleaned))
    for i, m in enumerate(matches):
        args_raw = [a.strip() for a in m.group(1).split(",")]
        name = args_raw[0].strip('"')
        anm2 = args_raw[1].strip('"') if len(args_raw) > 1 else ""
        start_f = eval_num(args_raw[2]) if len(args_raw) > 2 else 0
        end_f = eval_num(args_raw[3]) if len(args_raw) > 3 else 0
        fps = eval_num(args_raw[4]) if len(args_raw) > 4 else 30
        play_mode = eval_num(args_raw[5]) if len(args_raw) > 5 else 1
        blend = eval_num(args_raw[6]) if len(args_raw) > 6 else 0.0

        dur = None
        if isinstance(start_f, (int, float)) and isinstance(end_f, (int, float)) and isinstance(fps, (int, float)) and fps > 0:
            dur = round((end_f - start_f) / float(fps), 4)

        # Look for an immediately following { ... } block before next SeqTrack
        next_start = matches[i + 1].start() if i + 1 < len(matches) else len(cleaned)
        between = cleaned[m.end() : next_start].lstrip()
        events = []
        if between.startswith("{"):
            depth = 0
            end_brace = -1
            for ci, ch in enumerate(between):
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end_brace = ci
                        break
            if end_brace != -1:
                body = between[1:end_brace]
                for em in ev_re.finditer(body):
                    ev_frame = eval_num(em.group(1))
                    ev_type = em.group(2).strip().strip('"')
                    ev_param = eval_num(em.group(3))
                    # Check if a PlaySound/sub-call follows inside { ... }
                    sub_calls = []
                    rest = body[em.end() :].lstrip()
                    if rest.startswith("{"):
                        d2 = 0
                        eb2 = -1
                        for ci2, ch2 in enumerate(rest):
                            if ch2 == "{":
                                d2 += 1
                            elif ch2 == "}":
                                d2 -= 1
                                if d2 == 0:
                                    eb2 = ci2
                                    break
                        if eb2 != -1:
                            for sm in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)', rest[1:eb2]):
                                sub_calls.append(f"{sm.group(1)}({sm.group(2).strip()})")
                    ev_entry = {"frame": ev_frame, "type": ev_type, "param": ev_param}
                    if sub_calls:
                        ev_entry["calls"] = sub_calls
                    events.append(ev_entry)

        tracks.append(
            {
                "name": name,
                "anm2": anm2,
                "start": start_f,
                "end": end_f,
                "fps": fps,
                "duration_s": dur,
                "mode": play_mode,
                "blend_s": blend,
                "events": events,
            }
        )

    return {"source": src, "includes": includes, "track_count": len(tracks), "alias_count": len(aliases), "tracks": tracks, "aliases": aliases}


def parse_melee_weapons(pak: PakReader) -> dict:
    files = ["data/scripts/inventory/inventory_gen.scr", "data/scripts/inventory/inventory.scr"]
    weapons: list[dict] = []
    want_fields = {
        "ItemType", "Damage", "Force", "CriticalProb", "CriticalDamage", "DamageRange",
        "StaminaUsage", "Condition", "CriticalCondition", "DamageType", "WeaponBuildType",
        "Mesh", "Skin", "AnimPrefix", "SwingSpeed", "Price", "Color",
    }
    for rel in files:
        src, raw = pak.read_text(rel)
        cleaned = strip_comments(raw)
        # Scan Item("Name", CategoryType_Melee) { ... }
        item_re = re.compile(r'Item\s*\(\s*"([^"]+)"\s*,\s*(CategoryType_Melee)\s*\)\s*\{', re.S)
        for m in item_re.finditer(cleaned):
            iname = m.group(1)
            il = iname.lower()
            if not any(k in il for k in ("pipe", "machete", "axe", "hammer", "club", "knife", "bat")):
                continue
            depth = 1
            pos = m.end()
            while pos < len(cleaned) and depth > 0:
                if cleaned[pos] == "{":
                    depth += 1
                elif cleaned[pos] == "}":
                    depth -= 1
                pos += 1
            body = cleaned[m.end() : pos - 1]
            props: dict = {}
            for fm in re.finditer(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(([^()]*)\)', body):
                fn = fm.group(1)
                if fn in want_fields:
                    props[fn] = eval_num(fm.group(2))
            if props:
                weapons.append({"id": iname, "source": src, "props": props})
    return {"count": len(weapons), "weapons": weapons}


def inspect_rpacks() -> dict:
    data_dir = DL_ROOT / "Data"
    out: dict = {}

    # 1. common_meshes_PC.rpack -> FPP meshes
    mesh_path = data_dir / "common_meshes_PC.rpack"
    with mesh_path.open("rb") as fp:
        magic, ver, comp, parts_cnt, sec_cnt, files_cnt, names_size, names_cnt, _ = struct.unpack("<4s8I", fp.read(36))
        secs = [struct.unpack("<5I", fp.read(20)) for _ in range(sec_cnt)]
        parts = [struct.unpack("<BBHIQ", fp.read(16)) for _ in range(parts_cnt)]
        files = [struct.unpack("<BBHII", fp.read(12)) for _ in range(files_cnt)]
        name_offs = struct.unpack(f"<{files_cnt}I", fp.read(files_cnt * 4))
        names_raw = fp.read(names_size)

        fpp_meshes = []
        for p_cnt, _, ftype, fidx, fp_idx in files:
            off = name_offs[fidx]
            end = names_raw.find(b"\x00", off)
            nm = names_raw[off : end if end != -1 else len(names_raw)].decode("latin1", errors="replace")
            if ftype == 0x110 and "fpp" in nm.lower():
                p_list = parts[fp_idx : fp_idx + p_cnt]
                part_map = {}
                for p in p_list:
                    s_idx, _, _, p_off, p_size = p
                    flags, s_off, s_unp, s_pak, _ = secs[s_idx]
                    part_map[hex(flags & 0xFF)] = p_size
                entry_info = {"name": nm, "part_sizes": part_map}
                if nm == "player_dieselpunk_fpp":
                    # Read 0x10 section for submesh & material details
                    for p in p_list:
                        s_idx, _, _, p_off, p_size = p
                        flags, s_off, s_unp, s_pak, _ = secs[s_idx]
                        if (flags & 0xFF) == 0x10:
                            fp.seek(s_off)
                            buf = zlib.decompress(fp.read(s_pak))
                            b10 = buf[p_off : p_off + p_size]
                            sub_2fzn = []
                            pos = 0
                            while True:
                                h = b10.find(b"2FZn", pos)
                                if h == -1:
                                    break
                                pos = h + 4
                                if h + 76 <= len(b10) and b10[h + 40 : h + 52] == b"\xff" * 12:
                                    vb_off = struct.unpack("<I", b10[h + 36 : h + 40])[0]
                                    vcnt, ib_off, nsub = struct.unpack("<3I", b10[h + 52 : h + 64])
                                    icnts = struct.unpack(f"<{nsub}I", b10[h + 68 : h + 68 + 4 * nsub]) if nsub <= 16 else ()
                                    sub_2fzn.append({"vb_off": vb_off, "verts": vcnt, "ib_off": ib_off, "nsub": nsub, "indices": sum(icnts)})
                            mats = [s.decode("ascii", "ignore") for s in b10.split(b"\x00") if b".mat" in s.lower()]
                            entry_info["submeshes_2fzn"] = sub_2fzn
                            entry_info["materials"] = mats
                fpp_meshes.append(entry_info)
        out["common_meshes_PC"] = {
            "path": str(mesh_path),
            "files_count": files_cnt,
            "fpp_meshes": fpp_meshes,
        }

    # 2. common_anims_PC.rpack -> RP6L + ANM2 header inspection
    anim_path = data_dir / "common_anims_PC.rpack"
    with anim_path.open("rb") as fp:
        magic, ver, comp, parts_cnt, sec_cnt, files_cnt, names_size, names_cnt, _ = struct.unpack("<4s8I", fp.read(36))
        secs = [struct.unpack("<5I", fp.read(20)) for _ in range(sec_cnt)]
        parts = [struct.unpack("<BBHIQ", fp.read(16)) for _ in range(parts_cnt)]
        files = [struct.unpack("<BBHII", fp.read(12)) for _ in range(files_cnt)]
        name_offs = struct.unpack(f"<{files_cnt}I", fp.read(files_cnt * 4))
        names_raw = fp.read(names_size)

        anim_names = []
        fpp_names = []
        stick_names = []
        nm_names = []
        for p_cnt, _, ftype, fidx, fp_idx in files:
            off = name_offs[fidx]
            end = names_raw.find(b"\x00", off)
            nm = names_raw[off : end if end != -1 else len(names_raw)].decode("latin1", errors="replace")
            if ftype == 0x140:
                anim_names.append(nm)
                nl = nm.lower()
                if "fpp" in nl:
                    fpp_names.append(nm)
                if "fpp_stick" in nl:
                    stick_names.append(nm)
                if "fpp_" in nl and any(k in nl for k in ("climb", "jump", "hang", "vault", "slide", "ledge", "wall")):
                    nm_names.append(nm)

        # Inflate first 64KB of sec[0] to verify ANM2 magic & header
        fp.seek(secs[0][1])
        head_bytes = zlib.decompressobj().decompress(fp.read(65536), 65536)
        sample_anm2 = None
        for p_cnt, _, ftype, fidx, fp_idx in files:
            if ftype == 0x140:
                p = parts[fp_idx]
                if p[3] + p[4] <= len(head_bytes):
                    off = name_offs[fidx]
                    end = names_raw.find(b"\x00", off)
                    nm = names_raw[off : end if end != -1 else len(names_raw)].decode("latin1")
                    chunk = head_bytes[p[3] : p[3] + 32]
                    mg, a_ver, a_flg, nframes, nbones, unk1, hdr_sz, payload_sz = struct.unpack("<4sHHHHHHI", chunk[:20])
                    sample_anm2 = {
                        "name": nm,
                        "magic": mg.decode("ascii", "replace"),
                        "version": a_ver,
                        "flags": a_flg,
                        "frames": nframes,
                        "bones": nbones,
                        "header_offset": hdr_sz,
                        "payload_size": payload_sz,
                        "part_size": p[4],
                    }
                    break

        out["common_anims_PC"] = {
            "path": str(anim_path),
            "magic": magic.decode("ascii"),
            "version": ver,
            "compressed": bool(comp),
            "total_files": files_cnt,
            "total_anm2_0x140": len(anim_names),
            "fpp_anm2_count": len(fpp_names),
            "fpp_stick_count": len(stick_names),
            "fpp_parkour_count": len(nm_names),
            "fpp_parkour_samples": nm_names[:25],
            "sections": [{"flags": hex(s[0]), "offset": s[1], "unpacked": s[2], "packed": s[3]} for s in secs],
            "sample_anm2_header": sample_anm2,
        }
    return out


def main() -> int:
    if not DL_ROOT.exists():
        print(f"ERROR: Dying Light root not found: {DL_ROOT}", file=sys.stderr)
        return 1

    pak = PakReader(DL_ROOT)

    anim_targets = [
        "data/characters/animations/animscripts/m_fpp_nm.scr",
        "data/characters/animations/animscripts/m_fpp_nm_ballance.scr",
        "data/characters/animations/animscripts/m_fpp_nm_climb.scr",
        "data/characters/animations/animscripts/m_fpp_nm_hang.scr",
        "data/characters/animations/animscripts/m_fpp_nm_jump.scr",
        "data/characters/animations/animscripts/m_fpp_nm_land.scr",
        "data/characters/animations/animscripts/m_fpp_nm_zipline.scr",
        "data/characters/animations/animscripts/m_fpp_legs.scr",
        "data/characters/animations/animscripts/m_fpp_stick.scr",
        "data/characters/animations/animscripts/m_fpp_stick2.scr",
        "data/characters/animations/animscripts/m_fpp_stick2close.scr",
        "data/characters/animations/animscripts/m_fpp_stick2heavy.scr",
        "data/characters/animations/animscripts/m_fpp_grab.scr",
        "data/characters/animations/animscripts/m_fpp_unarmed.scr",
        "data/characters/animations/animscripts/m_fpp_knockdown.scr",
        "data/characters/animations/animscripts/m_fpp_hitreactions.scr",
    ]

    ode_targets = [
        "data/odephysics/odeworld.phx",
        "data/odephysics/generic/odephysicswalkfly.phx",
        "data/odephysics/walkfly/walk_player.phx",
        "data/odephysics/ragdollbehaviors/ragdollbehaviors.phx",
    ]

    cfg_targets = [
        "data/scripts/difficultyparams.scr",
        "data/scripts/playeraimlookparamsfpp.scr",
        "data/vis/playerfppbodyvis.scr",
        "data/scripts/varlist_screen_shake.scr",
        "data/characters/animations/animscripts/playerblendparams.scr",
    ]

    data = {
        "default_levels": parse_default_levels(pak),
        "common_skills": parse_skills_xml(pak, "data/skills/common_skills.xml"),
        "stamina_skills": parse_skills_xml(pak, "data/skills/stamina_skills.xml"),
        "buffs": parse_buffs_xml(pak),
        "ode_physics": {p: {"source": pak.read_text(p)[0], "blocks": parse_scr_blocks(pak.read_text(p)[1])} for p in ode_targets},
        "configs": {p: {"source": pak.read_text(p)[0], "blocks": parse_scr_blocks(pak.read_text(p)[1])} for p in cfg_targets},
        "anim_scripts": {p: parse_anim_script(pak, p) for p in anim_targets if pak.exists(p)},
        "melee_weapons": parse_melee_weapons(pak),
        "rpacks": inspect_rpacks(),
    }
    pak.close()

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(data, indent=2), encoding="utf-8")

    print(
        f"WROTE {OUT_JSON} ({OUT_JSON.stat().st_size // 1024} KB) | "
        f"base_props={data['default_levels']['base_level1_prop_count']} | "
        f"anim_scripts={len(data['anim_scripts'])} | "
        f"tracks={sum(v['track_count'] for v in data['anim_scripts'].values())} | "
        f"weapons={data['melee_weapons']['count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
