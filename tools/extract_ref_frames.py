"""Extract labeled 2 FPS overview & 10 FPS action-burst contact sheets from Dying Light 1 reference clip."""
from __future__ import annotations

import argparse
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
FFMPEG = Path(r"D:\Program File\ffmpeg\ffmpeg-master-latest-win64-gpl\ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe")
REF_DIR = ROOT / "assets_ref" / "visual_debug" / "dl1_ref"
VIDEO_PATH = REF_DIR / "dl1_action.mp4"


def stitch_sheet(frames: list[Path], out_path: Path, cols: int, fps: float, start_offset_sec: float, src_base_sec: float = 47 * 60 + 24) -> None:
    if not frames:
        return
    tile_w, tile_h, bar_h = 480, 270, 28
    rows = math.ceil(len(frames) / cols)
    sheet = Image.new("RGB", (cols * tile_w, rows * (tile_h + bar_h)), (18, 20, 24))
    draw = ImageDraw.Draw(sheet)
    for i, fp in enumerate(frames):
        r, c = i // cols, i % cols
        x0, y0 = c * tile_w, r * (tile_h + bar_h)
        tile = Image.open(fp).convert("RGB").resize((tile_w, tile_h), Image.Resampling.LANCZOS)
        sheet.paste(tile, (x0, y0 + bar_h))
        t_clip = start_offset_sec + (i / fps)
        t_src = src_base_sec + t_clip
        mm, ss = int(t_src // 60), t_src % 60.0
        draw.rectangle([x0, y0, x0 + tile_w - 1, y0 + bar_h - 1], fill=(28, 32, 38))
        draw.text((x0 + 8, y0 + 7), f"[{i+1:02d}] +{t_clip:05.2f}s (DL1 {mm}:{ss:05.2f})", fill=(235, 240, 248))
    sheet.save(out_path, optimize=True)


def extract_overview() -> None:
    ov_dir = REF_DIR / "overview_frames"
    ov_dir.mkdir(parents=True, exist_ok=True)
    for old in ov_dir.glob("*.png"):
        old.unlink()
    subprocess.run(
        [str(FFMPEG), "-y", "-i", str(VIDEO_PATH), "-vf", "fps=2,scale=640:-1", str(ov_dir / "ov_%03d.png")],
        check=True, capture_output=True, text=True,
    )
    frames = sorted(ov_dir.glob("ov_*.png"))
    per_sheet = 16
    for si in range(0, len(frames), per_sheet):
        chunk = frames[si : si + per_sheet]
        out_p = REF_DIR / f"dl1_overview_{(si // per_sheet) + 1:02d}.png"
        stitch_sheet(chunk, out_p, cols=4, fps=2.0, start_offset_sec=si / 2.0)
        print("Wrote", out_p)


def extract_burst(start_sec: float, dur_sec: float, name: str) -> None:
    b_dir = REF_DIR / f"burst_{name}"
    b_dir.mkdir(parents=True, exist_ok=True)
    for old in b_dir.glob("*.png"):
        old.unlink()
    subprocess.run(
        [str(FFMPEG), "-y", "-ss", str(start_sec), "-t", str(dur_sec), "-i", str(VIDEO_PATH), "-vf", "fps=10,scale=640:-1", str(b_dir / "b_%03d.png")],
        check=True, capture_output=True, text=True,
    )
    frames = sorted(b_dir.glob("b_*.png"))
    for si in range(0, len(frames), 12):
        chunk = frames[si : si + 12]
        suffix = f"_{(si // 12) + 1:02d}" if len(frames) > 12 else ""
        out_p = REF_DIR / f"dl1_burst_{name}{suffix}.png"
        stitch_sheet(chunk, out_p, cols=4, fps=10.0, start_offset_sec=start_sec + si / 10.0)
        print("Wrote", out_p)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--overview", action="store_true")
    parser.add_argument("--burst", nargs=3, metavar=("START_SEC", "DUR_SEC", "NAME"))
    args = parser.parse_args()
    if not VIDEO_PATH.exists():
        raise FileNotFoundError(f"Missing {VIDEO_PATH}")
    if args.overview or not args.burst:
        extract_overview()
    if args.burst:
        extract_burst(float(args.burst[0]), float(args.burst[1]), args.burst[2])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
