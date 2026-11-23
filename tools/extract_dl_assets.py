"""Extract Dying Light 1 AAA models (.obj/.mtl) and textures (.png) from Chrome Engine 6 RP6L archives."""
from __future__ import annotations

import io
import json
import math
import struct
import sys
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DL_DATA = Path(r"D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com\DW\Data")
OUT = ROOT / "assets_ref" / "dl_models"
MANIFEST_PATH = ROOT / "assets_ref" / "dl_manifest.json"

MODELS = [
    {
        "key": "dl_weapon_pipe",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "wn_pipe_a",
        "stride": 32,
        "uv_off": 16,
        "nrm_off": 12,
        "parts": [(0, "pipe", "weapons_PC.rpack", "wn_pipe_a")],
    },
    {
        "key": "dl_weapon_machete",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "wn_machete_b",
        "stride": 32,
        "uv_off": 16,
        "nrm_off": 12,
        "parts": [(0, "machete", "weapons_PC.rpack", "wn_machete_b")],
    },
    {
        "key": "dl_weapon_axe",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "wn_axe_a",
        "stride": 32,
        "uv_off": 16,
        "nrm_off": 12,
        "parts": [(0, "axe", "weapons_PC.rpack", "wn_axe_a")],
    },
    {
        "key": "dl_zombie_volatile",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "zombie_voleteile",
        "stride": 40,
        "uv_off": 24,
        "nrm_off": 20,
        "parts": [
            (19, "body", "common_textures_2_pc.rpack", "voleteile_dif"),
            (20, "head", "common_textures_2_pc.rpack", "volatile_head_clr"),
        ],
    },
    {
        "key": "dl_zombie_goon",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "zombie_goon",
        "stride": 40,
        "uv_off": 24,
        "nrm_off": 20,
        "parts": [
            (3, "body", "common_textures_0_pc.rpack", "goon_body_dif"),
            (4, "head", "common_textures_0_pc.rpack", "goon_head_dif"),
            (7, "shirt", "common_textures_0_pc.rpack", "goon_shirt_dif"),
            (8, "trousers", "common_textures_0_pc.rpack", "goon_trousers_dif"),
        ],
    },
    {
        "key": "dl_zombie_biter",
        "mesh_rpack": "common_meshes_PC.rpack",
        "mesh_name": "zombie_man_a",
        "stride": 40,
        "uv_off": 24,
        "nrm_off": 20,
        "parts": [
            (74, "body", "common_textures_2_pc.rpack", "zombie_man_arm_a_clr"),
            (73, "torso", "common_textures_0_pc.rpack", "infected_torso_a_jeans_dif"),
            (29, "neck", "common_textures_2_pc.rpack", "zombie_man_a_neck_a_white_clr"),
            (31, "head", "common_textures_2_pc.rpack", "zombie_man_a_head_a_white_clr"),
        ],
    },
]


class RPackReader:
    """Lazy RP6L reader caching section decompression only when needed."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.fp = path.open("rb")
        magic, ver, comp, parts_cnt, sec_cnt, files_cnt, names_size, names_cnt, _ = struct.unpack(
            "<4s8I", self.fp.read(36)
        )
        if magic != b"RP6L":
            raise RuntimeError(f"Unexpected magic {magic!r} in {path}")
        self.comp = comp
        self.secs = [struct.unpack("<5I", self.fp.read(20)) for _ in range(sec_cnt)]
        self.parts = [struct.unpack("<BBHIQ", self.fp.read(16)) for _ in range(parts_cnt)]
        files = [struct.unpack("<BBHII", self.fp.read(12)) for _ in range(files_cnt)]
        name_offs = struct.unpack(f"<{files_cnt}I", self.fp.read(files_cnt * 4))
        names_raw = self.fp.read(names_size)
        self.entries: dict[str, tuple[int, list]] = {}
        for p_cnt, _, ftype, fidx, fp_idx in files:
            off = name_offs[fidx]
            end = names_raw.find(b"\x00", off)
            nm = names_raw[off : end if end != -1 else len(names_raw)].decode("latin1", errors="replace")
            self.entries[nm] = (ftype, self.parts[fp_idx : fp_idx + p_cnt])
        self._sec_cache: dict[int, bytes] = {}

    def read_entry(self, name: str) -> dict[int, bytes]:
        if name not in self.entries:
            raise KeyError(f"{name!r} not found in {self.path.name}")
        _, part_list = self.entries[name]
        out: dict[int, bytes] = {}
        for s_idx, _, _, p_off, p_size in part_list:
            flags, s_off, s_unp, s_pak, _ = self.secs[s_idx]
            if self.comp and s_pak > 0:
                if s_idx not in self._sec_cache:
                    self.fp.seek(s_off)
                    self._sec_cache[s_idx] = zlib.decompress(self.fp.read(s_pak))
                data = self._sec_cache[s_idx][p_off : p_off + p_size]
            else:
                self.fp.seek(s_off + p_off)
                data = self.fp.read(p_size)
            out[flags & 0xFF] = data
        return out

    def close(self) -> None:
        self.fp.close()


_rpack_cache: dict[str, RPackReader] = {}


def get_rpack(name: str) -> RPackReader:
    if name not in _rpack_cache:
        _rpack_cache[name] = RPackReader(DL_DATA / name)
    return _rpack_cache[name]


def decode_dds_to_png(tex_parts: dict[int, bytes], dest: Path, max_dim: int = 1024) -> tuple[int, int]:
    hdr20 = tex_parts[0x20]
    w, h, _, _, _, fmt_code = struct.unpack("<HHHHII", hdr20[:16])
    fourcc_map = {0x11: b"DXT1", 0x12: b"DXT3", 0x13: b"DXT5"}
    if fmt_code not in fourcc_map:
        raise RuntimeError(f"Unsupported DDS format code 0x{fmt_code:x} for {dest.name}")
    blk = 8 if fmt_code == 0x11 else 16
    mip0_sz = max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * blk
    dds_hdr = bytearray(128)
    dds_hdr[0:4] = b"DDS "
    struct.pack_into("<7I", dds_hdr, 4, 124, 0x1007, h, w, mip0_sz, 0, 1)
    struct.pack_into("<2I4s5I", dds_hdr, 76, 32, 0x4, fourcc_map[fmt_code], 0, 0, 0, 0, 0)
    struct.pack_into("<I", dds_hdr, 108, 0x1000)

    img = Image.open(io.BytesIO(bytes(dds_hdr) + tex_parts[0x21][:mip0_sz])).convert("RGB")
    if max(img.size) > max_dim:
        img = img.copy()
        img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest, format="PNG", optimize=True)
    return img.size


def extract_2fzn_records(b10: bytes) -> list[tuple[int, int, int, int]]:
    """Return list of (vb_off, vcnt, ib_off, icnt) for each 2FZn mesh sub-record."""
    recs: list[tuple[int, int, int, int]] = []
    pos = 0
    while True:
        h = b10.find(b"2FZn", pos)
        if h == -1:
            break
        pos = h + 4
        if h + 76 <= len(b10) and b10[h + 40 : h + 52] == b"\xff" * 12:
            vb_off = struct.unpack("<I", b10[h + 36 : h + 40])[0]
            vcnt, ib_off, nsub = struct.unpack("<3I", b10[h + 52 : h + 64])
            if 1 <= nsub <= 16 and h + 68 + 4 * nsub <= len(b10):
                icnts = struct.unpack(f"<{nsub}I", b10[h + 68 : h + 68 + 4 * nsub])
                recs.append((vb_off, vcnt, ib_off, sum(icnts)))
    return recs


def unpack_norm(raw4: bytes) -> tuple[float, float, float]:
    nx = (raw4[0] - 127.5) / 127.5
    ny = (raw4[1] - 127.5) / 127.5
    nz = (raw4[2] - 127.5) / 127.5
    mag = math.sqrt(nx * nx + ny * ny + nz * nz)
    if mag < 1e-5:
        return (0.0, 1.0, 0.0)
    return (nx / mag, ny / mag, nz / mag)


def res_path(p: Path) -> str:
    return "res://" + p.relative_to(ROOT).as_posix()


def main() -> int:
    if not DL_DATA.exists():
        print(f"ERROR: Dying Light Data dir missing: {DL_DATA}", file=sys.stderr)
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    manifest: dict = {"models": {}}

    for spec in MODELS:
        key = spec["key"]
        model_dir = OUT / key
        model_dir.mkdir(parents=True, exist_ok=True)

        mesh_parts = get_rpack(spec["mesh_rpack"]).read_entry(spec["mesh_name"])
        recs = extract_2fzn_records(mesh_parts[0x10])
        vb, ib = mesh_parts[0xF0], mesh_parts[0xF1]
        stride, uv_off, nrm_off = spec["stride"], spec["uv_off"], spec["nrm_off"]

        obj_lines = [f"mtllib {key}.mtl"]
        mtl_lines = []
        xs: list[float] = []
        ys: list[float] = []
        zs: list[float] = []
        v_base = 0
        total_tris = 0
        mat_paths: dict[str, str] = {}

        for rec_idx, mat_name, tex_rpack, tex_name in spec["parts"]:
            vb_off, vcnt, ib_off, icnt = recs[rec_idx]
            assert icnt % 3 == 0, f"{key} part {rec_idx} icnt {icnt} not /3"

            tex_dest = model_dir / f"{key}_{mat_name}.png"
            decode_dds_to_png(get_rpack(tex_rpack).read_entry(tex_name), tex_dest, max_dim=1024)
            mat_paths[mat_name] = res_path(tex_dest)
            mtl_lines.extend([f"newmtl {mat_name}", "Kd 1.0 1.0 1.0", f"map_Kd {tex_dest.name}", ""])

            obj_lines.append(f"g {key}_{mat_name}")
            obj_lines.append(f"usemtl {mat_name}")

            for v in range(vcnt):
                o = vb_off + v * stride
                x, y, z = struct.unpack("<3f", vb[o : o + 12])
                u, tv = struct.unpack("<2e", vb[o + uv_off : o + uv_off + 4])
                nx, ny, nz = unpack_norm(vb[o + nrm_off : o + nrm_off + 4])
                if not (math.isfinite(x) and math.isfinite(y) and math.isfinite(z)):
                    raise RuntimeError(f"Non-finite vertex in {key}")
                if not (math.isfinite(u) and math.isfinite(tv)):
                    u, tv = 0.0, 0.0
                xs.append(x)
                ys.append(y)
                zs.append(z)
                obj_lines.append(f"v {x:.6f} {y:.6f} {z:.6f}")
                obj_lines.append(f"vt {u:.6f} {1.0 - tv:.6f}")
                obj_lines.append(f"vn {nx:.5f} {ny:.5f} {nz:.5f}")

            idxs = struct.unpack(f"<{icnt}H", ib[ib_off : ib_off + icnt * 2])
            if max(idxs) >= vcnt:
                raise RuntimeError(f"Index out of range in {key} part {rec_idx}: {max(idxs)} >= {vcnt}")
            for t in range(0, icnt, 3):
                i0, i1, i2 = idxs[t] + 1 + v_base, idxs[t + 1] + 1 + v_base, idxs[t + 2] + 1 + v_base
                obj_lines.append(f"f {i0}/{i0}/{i0} {i1}/{i1}/{i1} {i2}/{i2}/{i2}")
            v_base += vcnt
            total_tris += icnt // 3

        obj_path = model_dir / f"{key}.obj"
        mtl_path = model_dir / f"{key}.mtl"
        obj_path.write_text("\n".join(obj_lines) + "\n", encoding="utf-8")
        mtl_path.write_text("\n".join(mtl_lines), encoding="utf-8")

        vmin = [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)]
        vmax = [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)]
        size = [round(vmax[i] - vmin[i], 4) for i in range(3)]
        center = [round((vmin[i] + vmax[i]) * 0.5, 4) for i in range(3)]
        bounds = {"min": vmin, "max": vmax, "size": size, "center": center, "verts": len(xs), "tris": total_tris}

        manifest["models"][key] = {
            "mesh": res_path(obj_path),
            "mtl": res_path(mtl_path),
            "texture": next(iter(mat_paths.values())),
            "materials": mat_paths,
            "bounds": bounds,
        }
        print(f"OK {key}: verts={len(xs)} tris={total_tris} size={size} mats={list(mat_paths.keys())}")

    for r in _rpack_cache.values():
        r.close()

    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    total_mb = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file()) / (1024 * 1024)
    print(f"DONE: {MANIFEST_PATH} | total={total_mb:.2f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
