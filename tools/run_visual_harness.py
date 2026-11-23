"""Run Sunfall live Vulkan visual capture harness and build high-frequency 30 FPS contact sheets + MP4 clips."""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path(r"D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = Path(r"D:\Program File\ffmpeg\ffmpeg-master-latest-win64-gpl\ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe")
BASE_OUT = ROOT / "assets_ref" / "visual_debug"


def make_contact_sheets(out_dir: Path, meta: list[dict]) -> list[Path]:
    by_scen: dict[str, list[dict]] = defaultdict(list)
    for item in meta:
        by_scen[item["scenario"]].append(item)

    sheets: list[Path] = []
    for scen, items in sorted(by_scen.items()):
        items.sort(key=lambda x: x["idx"])
        cols = 4 if len(items) >= 8 else 2
        tile_w, tile_h = (480, 270) if cols == 4 else (640, 360)
        bar_h = 30 if cols == 4 else 34
        rows = math.ceil(len(items) / cols)
        sheet = Image.new("RGB", (cols * tile_w, rows * (tile_h + bar_h)), (18, 20, 24))
        draw = ImageDraw.Draw(sheet)

        for i, item in enumerate(items):
            r = i // cols
            c = i % cols
            x0 = c * tile_w
            y0 = r * (tile_h + bar_h)
            img_path = out_dir / item["file"]
            if img_path.exists():
                tile = Image.open(img_path).convert("RGB").resize((tile_w, tile_h), Image.Resampling.LANCZOS)
                sheet.paste(tile, (x0, y0 + bar_h))

            extra = f" Z:{item['zombie_hp']}" if "zombie_hp" in item else ""
            if item.get("downed"):
                extra += " DN"
            caption = (
                f"[{item['idx']}] {item['label']} | {item['move_state']} "
                f"v={item['speed']} {item['fpp_anim']} p={item['pitch_deg']}°{extra}"
            )
            draw.rectangle([x0, y0, x0 + tile_w - 1, y0 + bar_h - 1], fill=(28, 32, 38))
            draw.text((x0 + 6, y0 + 8), caption[:74 if cols == 4 else 95], fill=(235, 240, 248))

        sheet_path = out_dir / f"sheet_{scen}.png"
        sheet.save(sheet_path, optimize=True)
        sheets.append(sheet_path)
    return sheets


def build_mp4_clips(out_dir: Path, meta: list[dict]) -> list[Path]:
    if not FFMPEG.exists() or not meta:
        return []
    by_scen: dict[str, list[dict]] = defaultdict(list)
    for item in meta:
        by_scen[item["scenario"]].append(item)

    clips: list[Path] = []
    for scen, items in sorted(by_scen.items()):
        if len(items) < 6:
            continue
        items.sort(key=lambda x: x["idx"])
        list_file = out_dir / f"concat_{scen}.txt"
        lines = [f"file '{(out_dir / it['file']).as_posix()}'\nduration 0.066" for it in items]
        lines.append(f"file '{(out_dir / items[-1]['file']).as_posix()}'")
        list_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        mp4_path = out_dir / f"clip_{scen}.mp4"
        cmd = [
            str(FFMPEG), "-y", "-f", "concat", "-safe", "0", "-i", str(list_file),
            "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-crf", "22", str(mp4_path),
        ]
        if subprocess.run(cmd, capture_output=True, text=True).returncode == 0:
            clips.append(mp4_path)

    # Also build combined 30 FPS overview reel
    reel_list = out_dir / "frames_concat.txt"
    rlines = [f"file '{(out_dir / it['file']).as_posix()}'\nduration 0.12" for it in meta]
    rlines.append(f"file '{(out_dir / meta[-1]['file']).as_posix()}'")
    reel_list.write_text("\n".join(rlines) + "\n", encoding="utf-8")
    reel_path = out_dir / "reel_30fps.mp4"
    cmd = [
        str(FFMPEG), "-y", "-f", "concat", "-safe", "0", "-i", str(reel_list),
        "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-crf", "22", str(reel_path),
    ]
    if subprocess.run(cmd, capture_output=True, text=True).returncode == 0:
        clips.append(reel_path)
    return clips


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", default="iter_1")
    args = parser.parse_args()

    out_dir = BASE_OUT / args.tag
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.png"):
        old.unlink()

    cmd = [
        str(GODOT),
        "--path", str(ROOT),
        "--windowed",
        "--resolution", "1280x720",
        "--position", "40,40",
        "--",
        f"--visual-capture={out_dir.as_posix()}",
    ]
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    print(res.stdout)
    if res.stderr:
        print(res.stderr, file=sys.stderr)
    if res.returncode != 0:
        print(f"ERROR: Godot exited with {res.returncode}")
        return res.returncode

    meta_path = out_dir / "capture_meta.json"
    if not meta_path.exists():
        print("ERROR: capture_meta.json was not written!")
        return 1
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    sheets = make_contact_sheets(out_dir, meta)
    clips = build_mp4_clips(out_dir, meta)
    print(f"Sheets created: {len(sheets)} | Clips created: {len(clips)}")
    for s in sheets:
        print(" ", s)
    for c in clips:
        print(" ", c)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
