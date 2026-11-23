"""Read Dying Light 1 actual game files in DW/Data0.pak for camera look, FPP body vis, blend timings, and hit FX."""
from __future__ import annotations

import re
import zipfile
from pathlib import Path

DATA0 = Path(r"D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com\DW\Data0.pak")
OUT_REPORT = Path(__file__).resolve().parent.parent / "report" / "dl1_re" / "08_fluidity_camera_and_vis.md"


def parse_look_blocks(text: str) -> list[dict]:
    blocks = []
    for m in re.finditer(r'(LookParams|AimParams)\("([^"]+)"\)\s*\{([^}]*)\}', text, re.S):
        kind, name, body = m.group(1), m.group(2), m.group(3)
        props: dict[str, str] = {}
        for pm in re.finditer(r'([A-Za-z0-9_]+)\(([^)]*)\)', body):
            props[pm.group(1)] = pm.group(2).strip()
        blocks.append({"kind": kind, "name": name, "props": props})
    return blocks


def parse_blend_and_events(text: str) -> list[dict]:
    tracks = []
    for m in re.finditer(r'SeqTrack\("([^"]+)",\s*"([^"]+)",\s*([0-9.\-]+),\s*([0-9.\-]+),\s*([0-9.\-]+),\s*([0-9.\-]+)(.*?)\)\s*(\{[^}]*\})?', text, re.S):
        name, anm, f0, f1, fps, blend = m.group(1), m.group(2), float(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6))
        body = m.group(8) or ""
        evts = []
        for em in re.finditer(r'Event\(([^)]+)\)', body):
            evts.append(em.group(1).strip())
        tracks.append({
            "name": name,
            "dur": round((f1 - f0) / max(1.0, fps), 3),
            "fps": fps,
            "blend": blend,
            "events": [e for e in evts if any(k in e for k in ("CAN_WALK", "ENABLE_DUCK", "CLIMBING_LENGTH", "JUMP_PUSH_OFF", "END_ANIMATION", "EVENT_"))],
        })
    return tracks


def main() -> int:
    with zipfile.ZipFile(DATA0) as zf:
        aim_txt = zf.read("data/scripts/playeraimlookparamsfpp.scr").decode("latin1", errors="replace")
        vis_fpp = zf.read("data/vis/playerfppbodyvis.scr").decode("latin1", errors="replace")
        blur_txt = zf.read("data/scripts/varlist_blur_camera_motion.scr").decode("latin1", errors="replace")
        shake_txt = zf.read("data/scripts/varlist_screen_shake.scr").decode("latin1", errors="replace")
        z_body_fx = zf.read("data/scripts/customcollisionsfx/zombie_body.scr").decode("latin1", errors="replace")
        z_head_fx = zf.read("data/scripts/customcollisionsfx/zombie_head.scr").decode("latin1", errors="replace")

        anim_files = [
            "data/characters/animations/animscripts/m_fpp_nm_climb.scr",
            "data/characters/animations/animscripts/m_fpp_nm_jump.scr",
            "data/characters/animations/animscripts/m_fpp_nm_land.scr",
            "data/characters/animations/animscripts/m_fpp_legs.scr",
            "data/characters/animations/animscripts/m_fpp_stick.scr",
            "data/characters/animations/animscripts/m_fpp_unarmed.scr",
        ]
        anim_data = {fn.split("/")[-1]: parse_blend_and_events(zf.read(fn).decode("latin1", errors="replace")) for fn in anim_files}

    look_blocks = parse_look_blocks(aim_txt)

    md = [
        "# Dying Light 1 Movement Fluidity, Camera Pitch Distribution & Blending Spec",
        "",
        "> Directly extracted from `DW/Data0.pak` via [`tools/re_dl_fluidity.py`](../../tools/re_dl_fluidity.py).",
        "",
        "---",
        "",
        "## 1. FPP Camera & Spine Pitch Distribution (`data/scripts/playeraimlookparamsfpp.scr`)",
        "",
        f"Parsed **{len(look_blocks)}** `LookParams` / `AimParams` state blocks:",
        "",
        "| State | Kind | Horz `[min, max]` | Vert `[min, max]` | Up Dist / Param | Down Dist / Param | Blend Time |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for b in look_blocks:
        p = b["props"]
        h = f"[{p.get('min_horz_angle', p.get('alias', '-'))}, {p.get('max_horz_angle', '-')}]"
        v = f"[{p.get('min_vert_angle', '-')}, {p.get('max_vert_angle', '-')}]"
        up = f"{p.get('distribution_vert_up_commited', '-')} / {p.get('distribution_vert_up_commited_param', '-')}"
        dn = f"{p.get('distribution_vert_down_commited', '-')} / {p.get('distribution_vert_down_commited_param', '-')}"
        bt = p.get("distribution_change_time", p.get("enable_change_time", "-"))
        md.append(f"| `{b['name']}` | `{b['kind']}` | `{h}` | `{v}` | `{up}` | `{dn}` | `{bt}s` |")

    md.extend([
        "",
        "**Why Dying Light never clips the chest when looking down (`-89°`), yet raises arms when looking up (`+70°`):**",
        "- `distribution_vert_up_commited(1.0)` with `param(1.0)` commits `100%` of upward pitch to the spine/upper-body look chain (`_PATH_LOOK_AT`).",
        "- `distribution_vert_down_commited(0.5)` with `param(1.2)` commits only `50%` (non-linear `1.2` power) downward, keeping the chest out of the camera near plane while revealing legs/feet.",
        "",
        "---",
        "",
        "## 2. FPP Body Look & Aim Bone Chains (`data/vis/playerfppbodyvis.scr`)",
        "",
        "```text",
    ])
    for m in re.finditer(r'RotationController\([^)]+\)\s*\{[^}]*\}', vis_fpp, re.S):
        md.append(m.group(0).strip())
        md.append("")
    md.extend([
        "```",
        "",
        "---",
        "",
        "## 3. Parkour / Melee Blend Times & Early-Exit Chaining (`m_fpp_*.scr`)",
        "",
        "Dying Light's signature fluidity comes from **0.00s–0.10s blend-ins** on vaults/climbs/landings paired with early `CAN_WALK` / `ENABLE_DUCK` / `JUMP_PUSH_OFF` release events before the animation reaches its end frame:",
        "",
        "| Script | Track | Dur | Blend | Early Release / Chain Events |",
        "|---|---|---:|---:|---|",
    ])
    interesting = (
        "RoofJump2_FromBottomNoHang", "RoofJump_FromTop", "Jump_Begin", "JumpOverLow", "JumpOnLowStand",
        "WallRunLeft", "WallRunFront", "DodgeLeft", "CrouchDamperRoll", "CrouchDamper", "Land",
        "Kick", "SlideBegin", "SlideLoop", "SlideEnd", "Melee_Attack_RL_Empty", "Melee_Attack_LR_Empty",
        "Tackle", "SprintForward", "WalkForward",
    )
    for fname, tracks in anim_data.items():
        for tr in tracks:
            if any(k in tr["name"] for k in interesting):
                ev_str = "; ".join(tr["events"][:4]) if tr["events"] else "—"
                md.append(f"| `{fname}` | `{tr['name']}` | `{tr['dur']}s` | `{tr['blend']}s` | `{ev_str}` |")

    md.extend([
        "",
        "---",
        "",
        "## 4. Camera Motion Blur, Screen Shake & Zombie Hit FX (`Data0.pak`)",
        "",
        "### `varlist_blur_camera_motion.scr` & `varlist_screen_shake.scr`",
        "```text",
        "\n".join(blur_txt.strip().splitlines()[:25]),
        "---",
        "\n".join(shake_txt.strip().splitlines()[:25]),
        "```",
        "",
        "### `customcollisionsfx/zombie_body.scr` & `zombie_head.scr` (excerpt)",
        "```text",
        "\n".join(z_body_fx.strip().splitlines()[:18]),
        "---",
        "\n".join(z_head_fx.strip().splitlines()[:18]),
        "```",
    ])

    OUT_REPORT.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_REPORT} ({len(look_blocks)} look blocks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
