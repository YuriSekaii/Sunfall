"""Extract compact 7D2D prototype reference assets into assets_ref/ and write manifest.json."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image
import UnityPy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets_ref"
SRC_DATA = Path(r"D:\Program File\7.Days.To.Die.v3.3.0\7.Days.To.Die.v3.3.0\game\Data")
SRC_ADDR = SRC_DATA / "Addressables" / "Standalone"

MODELS = [
    {
        "key": "zombie_lab",
        "dir": "models/zombie_lab",
        "bundle": r"zombies_assets_entities\zombies\lab.bundle",
        "meshes": [("LOD0", (0.0, 0.0, 0.0), True)],
        "texture": "HD_lab",
    },
    {
        "key": "zombie_hazmat",
        "dir": "models/zombie_hazmat",
        "bundle": r"zombies_assets_entities\zombies\hazmat.bundle",
        "meshes": [("HD_HazmatZ_LOD0", (0.0, 0.0, 0.0), False)],
        "texture": "HD_HazmatZ",
    },
    {
        "key": "zombie_mutated",
        "dir": "models/zombie_mutated",
        "bundle": r"zombies_assets_entities\zombies\mutated.bundle",
        "meshes": [("LOD0", (0.0, 0.0, 0.0), False)],
        "texture": "HD_RadZ",
    },
    {
        "key": "plane",
        "dir": "models/plane",
        "bundle": r"automatic_assets_entities\supplyplane.bundle",
        "meshes": [("Curtiss_Fuselage", (0.0, 0.0, 0.0), False)],
        "texture": "Curtiss",
    },
    {
        "key": "crate",
        "dir": "models/crate",
        "bundle": r"automatic_assets_entities\supplycrate.bundle",
        "meshes": [("Box001", (0.0, 0.0, 0.0), True)],
        "texture": "supply_crate_general",
    },
    {
        "key": "barricade",
        "dir": "models/barricade",
        "bundle": r"automatic_assets_entities\sandbags.bundle",
        "meshes": [("UCX_straight_01_1", (0.0, 0.0, 0.0), False)],
        "texture": "sandbags",
    },
    {
        "key": "turret",
        "dir": "models/turret",
        "bundle": r"automatic_assets_entities\traps.bundle",
        "meshes": [
            ("autoTurretSMG_Base_LOD0", (0.0, 0.0, 0.0), False),
            ("autoTurretSMG_Rotate_LOD0", (0.0, 0.68, 0.0), False),
            ("autoTurretSMG_Pitch_LOD0", (0.0, 0.76, 0.0), False),
        ],
        "texture": "autoTurret",
    },
    {
        "key": "weapon_pipe",
        "dir": "models/weapons",
        "bundle": r"automatic_assets_other\items.bundle",
        "meshes": [("pipeBaton_LOD0", (0.0, 0.0, 0.0), False)],
        "texture": "pipeBaton_d",
    },
    {
        "key": "weapon_machete",
        "dir": "models/weapons",
        "bundle": r"automatic_assets_other\items.bundle",
        "meshes": [("machete_LOD0", (0.0, 0.0, 0.0), False)],
        "texture": "machete_d",
    },
    {
        "key": "weapon_axe",
        "dir": "models/weapons",
        "bundle": r"automatic_assets_other\items.bundle",
        "meshes": [("steelAxe_1", (0.0, 0.0, 0.0), False)],
        "texture": "steelAxe_d",
    },
    {
        "key": "weapon_hammer",
        "dir": "models/weapons",
        "bundle": r"automatic_assets_other\items.bundle",
        "meshes": [("hammer_LOD0", (0.0, 0.0, 0.0), False)],
        "texture": "hammer_d",
    },
]

TEXTURES = {
    "grass": (r"terraintextures_assets_all.bundle", "forest_ground"),
    "dirt": (r"terraintextures_assets_all.bundle", "dirt"),
    "rock": (r"terraintextures_assets_all.bundle", "stone"),
    "concrete": (r"terraintextures_assets_all.bundle", "concrete"),
    "wood": (r"automatic_assets_other\items.bundle", "detailWood"),
    "metal": (r"automatic_assets_other\items.bundle", "scrap_metal"),
}

AUDIO = {
    "melee_swing": (r"automatic_assets_sounds\weapons.bundle", ["club_swinglight1", "axe_swinglight"]),
    "melee_hit": (r"automatic_assets_sounds\impactsurface.bundle", ["metalhitorganic1", "bullethitorganic1"]),
    "zombie_groan": (r"automatic_assets_sounds\enemies.bundle", ["zombie_hazmat_alert_01", "zombie_alert_01"]),
    "zombie_attack": (r"automatic_assets_sounds\enemies.bundle", ["zombie_hazmat_attack_01", "zombie_attack_01"]),
    "footstep": (r"automatic_assets_sounds\step.bundle", ["stepdirt1", "stepgrass1"]),
    "turret_shot": (r"automatic_assets_sounds\weapons.bundle", ["junkturret_fire1", "ak47_fire1"]),
    "ambient_night": (r"automatic_assets_sounds\ambient_loops.bundle", ["a_crickets_forest_lp1", "a_windmedium_lp"]),
}

ICONS = {
    "wood": "resourceWood.png",
    "metal": "resourceScrapIron.png",
    "gunpowder": "resourceGunPowder.png",
    "food": "foodCanBeef.png",
    "water": "drinkJarPureMineralWater.png",
    "medkit": "medicalFirstAidKit.png",
    "pipe": "meleeWpnBatonT0PipeBaton.png",
    "machete": "meleeWpnBladeT3Machete.png",
    "axe": "meleeToolAxeT2SteelAxe.png",
    "wall": "woodBarricadeCTRPlate.png",
    "turret": "autoTurret.png",
}

_bundle_cache: dict[str, dict] = {}


def load_bundle(rel_path: str) -> dict:
    if rel_path in _bundle_cache:
        return _bundle_cache[rel_path]
    env = UnityPy.load(str(SRC_ADDR / rel_path))
    index = {"Mesh": {}, "Texture2D": {}, "AudioClip": {}}
    for obj in env.objects:
        kind = obj.type.name
        if kind in index:
            data = obj.read()
            if data.m_Name and data.m_Name not in index[kind]:
                index[kind][data.m_Name] = data
    _bundle_cache[rel_path] = index
    return index


def transform_and_merge_obj(parts: list[tuple[str, tuple[float, float, float], bool]]) -> tuple[str, dict]:
    """Merge OBJ text parts with optional Z-up->Y-up rotation and translation, returning (obj_text, bounds)."""
    out_lines: list[str] = []
    v_off = vt_off = vn_off = 0
    xs: list[float] = []
    ys: list[float] = []
    zs: list[float] = []

    for obj_txt, (dx, dy, dz), rot_x_neg90 in parts:
        v_cnt = vt_cnt = vn_cnt = 0
        for line in obj_txt.splitlines():
            if line.startswith("v "):
                _, sx, sy, sz = line.split()[:4]
                x, y, z = float(sx), float(sy), float(sz)
                if rot_x_neg90:
                    y, z = z, -y
                x, y, z = x + dx, y + dy, z + dz
                xs.append(x)
                ys.append(y)
                zs.append(z)
                out_lines.append(f"v {x:.6f} {y:.6f} {z:.6f}")
                v_cnt += 1
            elif line.startswith("vn "):
                _, sx, sy, sz = line.split()[:4]
                x, y, z = float(sx), float(sy), float(sz)
                if rot_x_neg90:
                    y, z = z, -y
                out_lines.append(f"vn {x:.6f} {y:.6f} {z:.6f}")
                vn_cnt += 1
            elif line.startswith("vt "):
                out_lines.append(line)
                vt_cnt += 1
            elif line.startswith("f "):
                tokens = line.split()[1:]
                reindexed = []
                for tok in tokens:
                    segs = tok.split("/")
                    vi = str(int(segs[0]) + v_off)
                    vti = str(int(segs[1]) + vt_off) if len(segs) > 1 and segs[1] else ""
                    vni = str(int(segs[2]) + vn_off) if len(segs) > 2 and segs[2] else ""
                    reindexed.append(f"{vi}/{vti}/{vni}" if len(segs) == 3 else f"{vi}/{vti}" if len(segs) == 2 else vi)
                out_lines.append("f " + " ".join(reindexed))
            elif line.startswith(("g ", "o ")):
                out_lines.append(line)
        v_off += v_cnt
        vt_off += vt_cnt
        vn_off += vn_cnt

    vmin = [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)]
    vmax = [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)]
    size = [round(vmax[i] - vmin[i], 4) for i in range(3)]
    center = [round((vmin[i] + vmax[i]) * 0.5, 4) for i in range(3)]
    bounds = {"min": vmin, "max": vmax, "size": size, "center": center, "verts": len(xs)}
    return "\n".join(out_lines) + "\n", bounds


def save_resized_png(img: Image.Image, dest: Path, max_dim: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if max(img.size) > max_dim:
        img = img.copy()
        img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    img.save(dest, format="PNG", optimize=True)


def res_path(p: Path) -> str:
    return "res://" + p.relative_to(ROOT).as_posix()


def main() -> int:
    if not SRC_ADDR.exists():
        print(f"ERROR: 7D2D source not found at {SRC_ADDR}", file=sys.stderr)
        return 1

    manifest: dict = {"models": {}, "textures": {}, "audio": {}, "icons": {}}
    fallbacks: list[str] = []

    # 1. Models + albedo textures (max 1024px)
    for spec in MODELS:
        b = load_bundle(spec["bundle"])
        parts = []
        for mesh_name, offset, rot in spec["meshes"]:
            mesh_obj = b["Mesh"].get(mesh_name)
            if mesh_obj is None:
                raise RuntimeError(f"Missing mesh {mesh_name} in {spec['bundle']}")
            parts.append((mesh_obj.export(), offset, rot))

        obj_text, bounds = transform_and_merge_obj(parts)
        model_dir = OUT / spec["dir"]
        model_dir.mkdir(parents=True, exist_ok=True)
        obj_file = model_dir / f"{spec['key']}.obj"
        obj_file.write_text(obj_text, encoding="utf-8")

        tex_obj = b["Texture2D"].get(spec["texture"])
        tex_entry = None
        if tex_obj is not None:
            tex_file = model_dir / f"{spec['key']}.png"
            save_resized_png(tex_obj.image, tex_file, 1024)
            tex_entry = res_path(tex_file)
        else:
            fallbacks.append(f"model texture missing for {spec['key']}: {spec['texture']}")

        manifest["models"][spec["key"]] = {
            "mesh": res_path(obj_file),
            "texture": tex_entry,
            "bounds": bounds,
        }
        print(f"Model {spec['key']}: verts={bounds['verts']} size={bounds['size']}")

    # 2. Environment PBR textures (512px)
    tex_dir = OUT / "textures"
    for key, (bundle_rel, tex_name) in TEXTURES.items():
        b = load_bundle(bundle_rel)
        tex_obj = b["Texture2D"].get(tex_name)
        if tex_obj is None:
            fallbacks.append(f"texture missing: {key} ({tex_name})")
            continue
        dest = tex_dir / f"{key}.png"
        save_resized_png(tex_obj.image, dest, 512)
        manifest["textures"][key] = res_path(dest)
        print(f"Texture {key}: {tex_name} -> {dest.name}")

    # 3. Audio clips (.wav) + trimmed music (.ogg)
    audio_dir = OUT / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    for key, (bundle_rel, candidates) in AUDIO.items():
        b = load_bundle(bundle_rel)
        clip = next((b["AudioClip"][c] for c in candidates if c in b["AudioClip"]), None)
        if clip is None:
            fallbacks.append(f"audio missing: {key} ({candidates})")
            continue
        samples = clip.samples
        if not samples:
            fallbacks.append(f"audio empty samples: {key}")
            continue
        _, data = next(iter(samples.items()))
        dest = audio_dir / f"{key}.wav"
        dest.write_bytes(data)
        manifest["audio"][key] = res_path(dest)
        print(f"Audio {key}: {clip.m_Name} ({len(data)//1024} KB)")

    music_src = SRC_DATA / "Music" / "000aSusPri.wav"
    music_dest = audio_dir / "music_night.ogg"
    if music_src.exists():
        res = subprocess.run(
            ["ffmpeg", "-y", "-i", str(music_src), "-t", "30", "-c:a", "libvorbis", "-q:a", "3", str(music_dest)],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0 and music_dest.exists():
            manifest["audio"]["music_night"] = res_path(music_dest)
            print(f"Audio music_night: {music_dest.stat().st_size // 1024} KB")
        else:
            fallbacks.append(f"music ffmpeg failed: {res.stderr[-200:]}")
    else:
        fallbacks.append("music source 000aSusPri.wav missing")

    # 4. HUD Icons
    icon_dir = OUT / "icons"
    icon_dir.mkdir(parents=True, exist_ok=True)
    for key, src_name in ICONS.items():
        src = SRC_DATA / "ItemIcons" / src_name
        if not src.exists():
            fallbacks.append(f"icon missing: {key} ({src_name})")
            continue
        dest = icon_dir / f"{key}.png"
        shutil.copy2(src, dest)
        manifest["icons"][key] = res_path(dest)

    # 5. Write manifest.json
    manifest_path = OUT / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    total_bytes = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"DONE: {manifest_path} | total={total_bytes / (1024 * 1024):.2f} MB | fallbacks={len(fallbacks)}")
    if fallbacks:
        for fb in fallbacks:
            print("  FALLBACK:", fb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
