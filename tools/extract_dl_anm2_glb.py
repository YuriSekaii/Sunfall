"""Direct Dying Light 1 Skinned Mesh + Real ANM2 v42 -> GLB Exporter.

Extracts original Dying Light 1 skeletons, 2FZn per-draw bone palettes,
artist vertex weights, DDS->PNG textures, and motion-captured ANM2 v42
animations directly from DW/Data/*.rpack into self-contained .glb files.
Zero synthetic keyframes or procedural skin weights.
"""
from __future__ import annotations

import io
import json
import math
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_dl_assets import DL_DATA, MODELS, RPackReader, get_rpack, unpack_norm

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets_ref" / "dl_rigged"


def dl_bone_hash(name: str) -> int:
    """Chrome Engine bone hash: h = h * 41 + ord(c) on lowercase ASCII."""
    h = 0
    for c in name.lower().encode("ascii"):
        h = (h * 41 + c) & 0xFFFFFFFF
    return h


def _mat4_mul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _m34_to_4x4(f12: tuple[float, ...]) -> list[list[float]]:
    return [
        [f12[0], f12[1], f12[2], f12[3]],
        [f12[4], f12[5], f12[6], f12[7]],
        [f12[8], f12[9], f12[10], f12[11]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _mat4_to_col_major(m: list[list[float]]) -> list[float]:
    return [m[r][c] for c in range(4) for r in range(4)]


def _rot_mat_to_quat_xyzw(m: list[list[float]]) -> tuple[float, float, float, float]:
    """Convert 3x3 rotation part of 4x4 row-major matrix to unit quaternion (x, y, z, w)."""
    m00, m01, m02 = m[0][0], m[0][1], m[0][2]
    m10, m11, m12 = m[1][0], m[1][1], m[1][2]
    m20, m21, m22 = m[2][0], m[2][1], m[2][2]
    tr = m00 + m11 + m22
    if tr > 0.0:
        s = math.sqrt(tr + 1.0) * 2.0
        w = 0.25 * s
        x = (m21 - m12) / s
        y = (m02 - m20) / s
        z = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(max(1e-12, 1.0 + m00 - m11 - m22)) * 2.0
        w = (m21 - m12) / s
        x = 0.25 * s
        y = (m01 + m10) / s
        z = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(max(1e-12, 1.0 + m11 - m00 - m22)) * 2.0
        w = (m02 - m20) / s
        x = (m01 + m10) / s
        y = 0.25 * s
        z = (m12 + m21) / s
    else:
        s = math.sqrt(max(1e-12, 1.0 + m22 - m00 - m11)) * 2.0
        w = (m10 - m01) / s
        x = (m02 + m20) / s
        y = (m12 + m21) / s
        z = 0.25 * s
    mag = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    return (x / mag, y / mag, z / mag, w / mag)


def _quat_to_mat4(q: tuple[float, float, float, float], t: tuple[float, float, float]) -> list[list[float]]:
    x, y, z, w = q
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    return [
        [1.0 - 2.0 * (yy + zz), 2.0 * (xy - wz), 2.0 * (xz + wy), t[0]],
        [2.0 * (xy + wz), 1.0 - 2.0 * (xx + zz), 2.0 * (yz - wx), t[1]],
        [2.0 * (xz - wy), 2.0 * (yz + wx), 1.0 - 2.0 * (xx + yy), t[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def _unpack_8tracks_chunk(buf: bytes, pos: int, max_frame_idx: int) -> tuple[list[list[int]], int]:
    """Exact replica of engine_x64_rwdi.dll 0xe2640 + 0xe28e0."""
    hdr = struct.unpack_from("<8H", buf, pos)
    widths = [(16 if ((w >> 12) & 0xF) == 15 else ((w >> 12) & 0xF)) for w in hdr]
    widths += [(16 if ((w >> 8) & 0xF) == 15 else ((w >> 8) & 0xF)) for w in hdr]
    group_bytes = (sum(widths) + 0x17) & ~0xF

    bit_cursor = 8
    out = [[0] * 8 for _ in range(16)]
    for f in range(max_frame_idx + 1):
        d = widths[f]
        shift_rem = 16 - d
        r9 = bit_cursor >> 4
        bit_cursor += d
        r8 = bit_cursor & 0xF
        a_rshift = 16 - r8
        w_hi = struct.unpack_from("<8H", buf, pos + ((bit_cursor - 1) & ~0xF))
        w_lo = struct.unpack_from("<8H", buf, pos + r9 * 16)
        mask = (0xFFFF >> shift_rem) if shift_rem < 16 else 0
        for lane in range(8):
            hi_part = (w_hi[lane] >> a_rshift) if a_rshift < 16 else 0
            lo_part = (w_lo[lane] << r8) & 0xFFFF
            val = (hi_part | lo_part) & mask
            if d > 0 and (val & (1 << (d - 1))):
                val -= 1 << d
            out[f][lane] = val

    if max_frame_idx >= 1:
        for lane in range(8):
            s = (out[0][lane] + out[1][lane]) & 0xFFFF
            out[1][lane] = s - 0x10000 if s >= 0x8000 else s
    for f in range(2, max_frame_idx + 1):
        for lane in range(8):
            pred = 2 * out[f - 1][lane] - out[f - 2][lane]
            if pred > 32767:
                pred = 32767
            elif pred < -32768:
                pred = -32768
            s = (pred + out[f][lane]) & 0xFFFF
            out[f][lane] = s - 0x10000 if s >= 0x8000 else s
    return out, pos + group_bytes


def decode_anm2_v42(buf: bytes) -> tuple[list[int], list[dict[int, tuple]]]:
    """Decode all frames of an ANM2 v42 flags==1 blob -> (bone_hashes, frames)."""
    magic, ver, flags, _total_frames, num_bones, num_segs, hdr_off, _pay_sz = struct.unpack_from("<4sHHHHHHI", buf, 0)
    if magic != b"ANM2" or ver != 42 or flags != 1:
        raise RuntimeError(f"Unsupported ANM2 format: magic={magic} ver={ver} flags={flags}")
    hashes = list(struct.unpack_from(f"<{num_bones}I", buf, 0x20))
    seg_frames = list(struct.unpack_from(f"<{num_segs}H", buf, 0x20 + num_bones * 4))

    all_frames: list[dict[int, tuple]] = []
    for seg_i in range(num_segs):
        seg_off = hdr_off + seg_i * 0x10000
        sf = seg_frames[seg_i]
        nchunks = (sf + 14) // 15
        chunk_offs = struct.unpack_from(f"<{nchunks + 2}H", buf, seg_off)
        c0 = seg_off + chunk_offs[0] * 16
        num_const, num_anim, _total_tracks, quant_bytes, _raw_flag = struct.unpack_from("<5H", buf, c0)
        q_off = (c0 + 0x19) & ~0xF
        c_off = (q_off + quant_bytes + 0xF) & ~0xF
        f_off = c_off + num_const * 4
        const_floats = struct.unpack_from(f"<{num_const}f", buf, c_off)
        bone_flags = buf[f_off : f_off + num_bones]

        q_bias: list[float] = []
        q_scale: list[float] = []
        for qb in range(quant_bytes // 64):
            bo = q_off + qb * 64
            q_bias.extend(struct.unpack_from("<8f", buf, bo))
            q_scale.extend(struct.unpack_from("<8f", buf, bo + 32))

        ngroups = (num_anim + 7) // 8
        bone_ch: list[list[tuple[bool, int]]] = []
        ci, ai = 0, 0
        for b in range(num_bones):
            bf = bone_flags[b]
            chs: list[tuple[bool, int]] = []
            for bit in (1, 2, 4, 8, 16, 32):
                if bf & bit:
                    chs.append((True, ci))
                    ci += 1
                else:
                    chs.append((False, ai))
                    ai += 1
            for _ in range(3):
                if bf & 64:
                    chs.append((True, ci))
                    ci += 1
                else:
                    chs.append((False, ai))
                    ai += 1
            bone_ch.append(chs)

        for ch_i in range(nchunks):
            ch_start = seg_off + chunk_offs[1 + ch_i] * 16
            f_begin = ch_i * 15
            f_count = min(15, sf - f_begin)
            if ch_i == nchunks - 1 and seg_i == num_segs - 1:
                max_f = min(15, sf - f_begin)
                emit_frames = range(0, max_f + 1)
            else:
                max_f = 14
                emit_frames = range(0, f_count)

            anim_vals = [[0.0] * (ngroups * 8) for _ in range(16)]
            p = ch_start
            for g in range(ngroups):
                blk, p = _unpack_8tracks_chunk(buf, p, max_f)
                for f in range(max_f + 1):
                    for lane in range(8):
                        ti = g * 8 + lane
                        anim_vals[f][ti] = blk[f][lane] * q_scale[ti] + q_bias[ti]

            for f in emit_frames:
                frame_dict: dict[int, tuple] = {}
                for b in range(num_bones):
                    vals = [const_floats[idx] if is_c else anim_vals[f][idx] for (is_c, idx) in bone_ch[b]]
                    vx, vy, vz = vals[0], vals[1], vals[2]
                    s2 = vx * vx + vy * vy + vz * vz
                    inv = 1.0 / (1.0 + s2)
                    # glTF column-vector quaternion: w = +(1 - s2) / (1 + s2)
                    q = (2.0 * vx * inv, 2.0 * vy * inv, 2.0 * vz * inv, (1.0 - s2) * inv)
                    frame_dict[hashes[b]] = (q, (vals[3], vals[4], vals[5]), (vals[6], vals[7], vals[8]))
                all_frames.append(frame_dict)
    return hashes, all_frames


def decode_dds_png_bytes(tex_parts: dict[int, bytes], max_dim: int = 1024) -> bytes:
    hdr20 = tex_parts[0x20]
    w, h, _, _, _, fmt_code = struct.unpack("<HHHHII", hdr20[:16])
    fourcc_map = {0x11: b"DXT1", 0x12: b"DXT3", 0x13: b"DXT5"}
    blk = 8 if fmt_code == 0x11 else 16
    mip0_sz = max(1, (w + 3) // 4) * max(1, (h + 3) // 4) * blk
    dds_hdr = bytearray(128)
    dds_hdr[0:4] = b"DDS "
    struct.pack_into("<7I", dds_hdr, 4, 124, 0x1007, h, w, mip0_sz, 0, 1)
    struct.pack_into("<2I4s5I", dds_hdr, 76, 32, 0x4, fourcc_map[fmt_code], 0, 0, 0, 0, 0)
    struct.pack_into("<I", dds_hdr, 108, 0x1000)
    raw_pixels = tex_parts.get(0x21) or tex_parts[0x22]
    img = Image.open(io.BytesIO(bytes(dds_hdr) + raw_pixels[:mip0_sz])).convert("RGB")
    if max(img.size) > max_dim:
        img = img.copy()
        img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
    bio = io.BytesIO()
    img.save(bio, format="PNG", optimize=True)
    return bio.getvalue()


def parse_dl_skeleton_and_2fzn(b10: bytes, check_bones: int):
    node_cnt = struct.unpack_from("<I", b10, 0x64)[0]
    nodes = []
    for i in range(node_cnt):
        base = 0xA0 + i * 0xD0
        loc = _m34_to_4x4(struct.unpack_from("<12f", b10, base))
        invb = _m34_to_4x4(struct.unpack_from("<12f", b10, base + 0x30))
        name_off = struct.unpack_from("<Q", b10, base + 0x78)[0]
        nm_end = b10.find(b"\x00", name_off - 1)
        nm = b10[name_off - 1 : nm_end].decode("ascii", "ignore")
        par = struct.unpack_from("<h", b10, base + 0xC6)[0]
        nodes.append({"name": nm, "parent": par, "loc": loc, "invb": invb, "children": []})

    for i, n in enumerate(nodes):
        if 0 <= n["parent"] < node_cnt:
            nodes[n["parent"]]["children"].append(i)

    # Verify W * invBind == I for core skeleton bones (handles non-topological parent order)
    W: list[list[list[float]] | None] = [None] * node_cnt
    def get_world(idx: int) -> list[list[float]]:
        if W[idx] is None:
            n = nodes[idx]
            par = n["parent"]
            W[idx] = n["loc"] if (par < 0 or par >= node_cnt) else _mat4_mul(get_world(par), n["loc"])
        return W[idx]  # type: ignore[return-value]

    max_err = 0.0
    for i, n in enumerate(nodes):
        wi = get_world(i)
        if i < check_bones:
            P = _mat4_mul(wi, n["invb"])
            max_err = max(max_err, max(abs(P[r][c] - (1.0 if r == c else 0.0)) for r in range(4) for c in range(4)))
    assert max_err < 1e-3, f"Skeleton bind check failed: max_err={max_err}"

    # Parse 2FZn records with per-draw bone palettes
    recs = []
    pos = 0
    while True:
        h = b10.find(b"2FZn", pos)
        if h == -1:
            break
        pos = h + 4
        if h + 76 <= len(b10) and b10[h + 40 : h + 52] == b"\xff" * 12:
            vb_off = struct.unpack_from("<I", b10, h + 36)[0]
            vcnt, ib_off, nsub = struct.unpack_from("<3I", b10, h + 52)
            if 1 <= nsub <= 16 and h + 68 + 4 * nsub <= len(b10):
                icnts = struct.unpack_from(f"<{nsub}I", b10, h + 68)
                pal_tbl = h + 68 + 8 * nsub
                palettes = []
                for si in range(nsub):
                    po, pc = struct.unpack_from("<QQ", b10, pal_tbl + si * 16)
                    if 0 < pc <= node_cnt and 0 < po - 1 < len(b10) and po - 1 + pc * 2 <= len(b10):
                        pal = list(struct.unpack_from(f"<{pc}H", b10, po - 1))
                    else:
                        pal = list(range(node_cnt))
                    palettes.append(pal)
                recs.append((vb_off, vcnt, ib_off, icnts, palettes))
    return nodes, W, max_err, recs


def build_skinned_glb(
    out_path: Path,
    mesh_name: str,
    check_bones: int,
    parts_spec: list[tuple],
    clips_spec: list[tuple[str, str, int, int, float, bool]],
    anim_cache: dict[str, tuple[list[int], list[dict[int, tuple]]]],
) -> None:
    rp_m = get_rpack("common_meshes_PC.rpack")
    mparts = rp_m.read_entry(mesh_name)
    b10, vb, ib = mparts[0x10], mparts[0xF0], mparts[0xF1]
    nodes, W, max_err, recs = parse_dl_skeleton_and_2fzn(b10, check_bones)

    bin_buf = bytearray()
    buffer_views: list[dict] = []
    accessors: list[dict] = []
    images: list[dict] = []
    textures: list[dict] = []
    materials: list[dict] = []

    def add_bv(data: bytes, target: int | None = None) -> int:
        while len(bin_buf) % 4 != 0:
            bin_buf.append(0)
        off = len(bin_buf)
        bin_buf.extend(data)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target is not None:
            bv["target"] = target
        idx = len(buffer_views)
        buffer_views.append(bv)
        return idx

    def add_acc(bv_idx: int, comp_type: int, count: int, acc_type: str, vmin=None, vmax=None) -> int:
        acc = {"bufferView": bv_idx, "componentType": comp_type, "count": count, "type": acc_type}
        if vmin is not None:
            acc["min"] = vmin
        if vmax is not None:
            acc["max"] = vmax
        idx = len(accessors)
        accessors.append(acc)
        return idx

    # Textures & materials
    mat_map: dict[str, int] = {}
    for mat_key, tex_rpack, tex_name in parts_spec_materials(parts_spec):
        png_bytes = decode_dds_png_bytes(get_rpack(tex_rpack).read_entry(tex_name), max_dim=1024)
        bv_i = add_bv(png_bytes)
        img_i = len(images)
        images.append({"bufferView": bv_i, "mimeType": "image/png"})
        tex_i = len(textures)
        textures.append({"source": img_i})
        mat_i = len(materials)
        materials.append({
            "name": mat_key,
            "pbrMetallicRoughness": {"baseColorTexture": {"index": tex_i}, "metallicFactor": 0.0, "roughnessFactor": 0.82},
        })
        mat_map[mat_key] = mat_i

    # Build mesh primitives per sub-draw with exact bone palette remapping
    primitives = []
    for rec_idx, default_mat, sub_mats in parts_spec:
        vb_off, vcnt, ib_off, icnts, palettes = recs[rec_idx]
        idx_cursor = 0
        for sub_i, icnt in enumerate(icnts):
            mat_key = sub_mats.get(sub_i, default_mat)
            pal = palettes[sub_i]
            raw_idxs = struct.unpack_from(f"<{icnt}H", ib, ib_off + idx_cursor * 2)
            idx_cursor += icnt
            if not raw_idxs:
                continue
            used = sorted(set(raw_idxs))
            remap = {old_vi: new_vi for new_vi, old_vi in enumerate(used)}

            pos_b = bytearray()
            nrm_b = bytearray()
            uv_b = bytearray()
            jnt_b = bytearray()
            wgt_b = bytearray()
            pmin = [1e9, 1e9, 1e9]
            pmax = [-1e9, -1e9, -1e9]

            for old_vi in used:
                o = vb_off + old_vi * 40
                x, y, z = struct.unpack_from("<3f", vb, o)
                w4 = vb[o + 12 : o + 16]
                bi4 = vb[o + 16 : o + 20]
                nx, ny, nz = unpack_norm(vb[o + 20 : o + 24])
                u, v = struct.unpack_from("<2e", vb, o + 24)
                if not (math.isfinite(u) and math.isfinite(v)):
                    u, v = 0.0, 0.0
                pmin = [min(pmin[0], x), min(pmin[1], y), min(pmin[2], z)]
                pmax = [max(pmax[0], x), max(pmax[1], y), max(pmax[2], z)]

                pos_b.extend(struct.pack("<3f", x, y, z))
                nrm_b.extend(struct.pack("<3f", nx, ny, nz))
                uv_b.extend(struct.pack("<2f", float(u), float(v)))

                gj = []
                gw = []
                for k in range(4):
                    if w4[k] > 0:
                        loc_b = bi4[k]
                        g_b = pal[loc_b] if loc_b < len(pal) else 0
                        gj.append(g_b)
                        gw.append(float(w4[k]))
                    else:
                        gj.append(0)
                        gw.append(0.0)
                wsum = sum(gw) or 1.0
                gw = [w / wsum for w in gw]
                jnt_b.extend(struct.pack("<4H", *gj))
                wgt_b.extend(struct.pack("<4f", *gw))

            new_idxs = [remap[vi] for vi in raw_idxs]
            if len(used) <= 65535:
                idx_b = struct.pack(f"<{len(new_idxs)}H", *new_idxs)
                idx_ctype = 5123
            else:
                idx_b = struct.pack(f"<{len(new_idxs)}I", *new_idxs)
                idx_ctype = 5125

            primitives.append({
                "attributes": {
                    "POSITION": add_acc(add_bv(bytes(pos_b), 34962), 5126, len(used), "VEC3", pmin, pmax),
                    "NORMAL": add_acc(add_bv(bytes(nrm_b), 34962), 5126, len(used), "VEC3"),
                    "TEXCOORD_0": add_acc(add_bv(bytes(uv_b), 34962), 5126, len(used), "VEC2"),
                    "JOINTS_0": add_acc(add_bv(bytes(jnt_b), 34962), 5123, len(used), "VEC4"),
                    "WEIGHTS_0": add_acc(add_bv(bytes(wgt_b), 34962), 5126, len(used), "VEC4"),
                },
                "indices": add_acc(add_bv(idx_b, 34963), idx_ctype, len(new_idxs), "SCALAR"),
                "material": mat_map[mat_key],
            })

    # Build glTF nodes: node 0..N-1 = skeleton joints, node N = MeshNode, node N+1 = Armature root
    gltf_nodes = []
    hash_to_node: dict[int, int] = {}
    root_joints = []
    for i, n in enumerate(nodes):
        q = _rot_mat_to_quat_xyzw(n["loc"])
        t = (n["loc"][0][3], n["loc"][1][3], n["loc"][2][3])
        gnode = {
            "name": n["name"],
            "translation": [round(t[0], 6), round(t[1], 6), round(t[2], 6)],
            "rotation": [round(q[0], 6), round(q[1], 6), round(q[2], 6), round(q[3], 6)],
        }
        if n["children"]:
            gnode["children"] = n["children"]
        if n["parent"] < 0:
            root_joints.append(i)
        gltf_nodes.append(gnode)
        hash_to_node[dl_bone_hash(n["name"])] = i

    invb_bytes = bytearray()
    for n in nodes:
        invb_bytes.extend(struct.pack("<16f", *_mat4_to_col_major(n["invb"])))
    invb_acc = add_acc(add_bv(bytes(invb_bytes)), 5126, len(nodes), "MAT4")

    mesh_node_idx = len(gltf_nodes)
    gltf_nodes.append({"name": f"{mesh_name}_Mesh", "mesh": 0, "skin": 0})
    armature_node_idx = len(gltf_nodes)
    gltf_nodes.append({"name": "Armature", "children": root_joints + [mesh_node_idx]})

    # Encode real ANM2 v42 animations
    rp_a = get_rpack("common_anims_PC.rpack")
    animations = []
    for clip_name, anm_entry, f_start, f_end, fps, _loop in clips_spec:
        if anm_entry not in rp_a.entries:
            print(f"  WARN: missing ANM2 {anm_entry} for {clip_name}")
            continue
        if anm_entry not in anim_cache:
            anim_cache[anm_entry] = decode_anm2_v42(rp_a.read_entry(anm_entry)[0x40])
        _hashes, frames = anim_cache[anm_entry]
        f0 = max(0, min(f_start, len(frames) - 1))
        f1 = max(f0, min(f_end, len(frames) - 1))
        nframes = f1 - f0 + 1
        times = [float(i) / fps for i in range(nframes)]
        t_acc = add_acc(add_bv(struct.pack(f"<{nframes}f", *times)), 5126, nframes, "SCALAR", [times[0]], [times[-1]])

        samplers = []
        channels = []
        for bh, node_idx in hash_to_node.items():
            if bh not in frames[f0]:
                continue
            qs = []
            ps = []
            prev_q = None
            for fi in range(f0, f1 + 1):
                q, pos_v, _scl = frames[fi][bh]
                if prev_q is not None and sum(q[k] * prev_q[k] for k in range(4)) < 0.0:
                    q = (-q[0], -q[1], -q[2], -q[3])
                prev_q = q
                qs.extend(q)
                ps.extend(pos_v)

            r_acc = add_acc(add_bv(struct.pack(f"<{nframes * 4}f", *qs)), 5126, nframes, "VEC4")
            p_acc = add_acc(add_bv(struct.pack(f"<{nframes * 3}f", *ps)), 5126, nframes, "VEC3")

            rs_i = len(samplers)
            samplers.append({"input": t_acc, "interpolation": "LINEAR", "output": r_acc})
            channels.append({"sampler": rs_i, "target": {"node": node_idx, "path": "rotation"}})

            ps_i = len(samplers)
            samplers.append({"input": t_acc, "interpolation": "LINEAR", "output": p_acc})
            channels.append({"sampler": ps_i, "target": {"node": node_idx, "path": "translation"}})

        animations.append({"name": clip_name, "samplers": samplers, "channels": channels})

    while len(bin_buf) % 4 != 0:
        bin_buf.append(0)

    gltf_doc = {
        "asset": {"version": "2.0", "generator": "Sunfall-DL1-ANM2-Exporter"},
        "scene": 0,
        "scenes": [{"nodes": [armature_node_idx]}],
        "nodes": gltf_nodes,
        "meshes": [{"name": mesh_name, "primitives": primitives}],
        "skins": [{"inverseBindMatrices": invb_acc, "joints": list(range(len(nodes))), "skeleton": root_joints[0]}],
        "materials": materials,
        "textures": textures,
        "images": images,
        "animations": animations,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(bin_buf)}],
    }
    json_bytes = json.dumps(gltf_doc, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "

    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_buf)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "wb") as fp:
        fp.write(struct.pack("<III", 0x46546C67, 2, total_len))
        fp.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
        fp.write(json_bytes)
        fp.write(struct.pack("<II", len(bin_buf), 0x004E4942))
        fp.write(bin_buf)

    print(f"Exported {out_path.name}: {len(nodes)} bones, {len(primitives)} prims, {len(animations)} real ANM2 clips, max_W_err={max_err:.6f} ({out_path.stat().st_size // 1024} KB)")


def parts_spec_materials(parts_spec: list[tuple]) -> list[tuple[str, str, str]]:
    seen: dict[str, tuple[str, str, str]] = {}
    for _rec, dmat, smats in parts_spec:
        seen[dmat[0]] = dmat
        for m in smats.values():
            seen[m[0]] = m
    return list(seen.values())


def main() -> int:
    if not DL_DATA.exists():
        print(f"ERROR: Dying Light Data dir missing: {DL_DATA}", file=sys.stderr)
        return 1

    anim_cache: dict[str, tuple[list[int], list[dict[int, tuple]]]] = {}

    # 1. FPP Player: exact Data0.pak m_fpp_*.scr timings + real ANM2 clips
    fpp_parts = [
        (0, ("hands", "common_textures_0_pc.rpack", "diesel_punk_hands_dif"), {
            1: ("watch_num", "common_textures_0_pc.rpack", "diesel_punk_hands_dif"),
            2: ("watch_sym", "common_textures_0_pc.rpack", "diesel_punk_hands_dif"),
        }),
        (1, ("legs", "common_textures_0_pc.rpack", "diesel_punk_legs_dif"), {}),
        (2, ("torso", "common_textures_0_pc.rpack", "diesel_punk_torso_dif"), {}),
    ]
    fpp_clips = [
        ("idle", "m_fpp_stick_vigilant_lvl0", 0, 260, 30.0, True),
        ("stand_rest", "m_fpp_stick_stand_dw", 0, 10, 30.0, False),
        ("walk", "m_tpp_player_unarmed_02_walk_f", 0, 53, 60.0, True),
        ("sprint", "m_fpp_stick_nm_sprint02", 0, 31, 30.0, True),
        ("crouch_idle", "m_fpp_unarmed_crouchdamper", 0, 24, 30.0, False),
        ("swing_rl_begin", "m_fpp_stick_swings", 0, 11, 110.0, False),
        ("swing_right", "m_fpp_stick_swings_long", 66, 84, 30.0, False),
        ("swing_rl_rest", "m_fpp_stick_swings", 175, 217, 20.0, False),
        ("swing_rl_hit_middle", "m_fpp_stick_hitshort", 36, 52, 30.0, False),
        ("swing_left", "m_fpp_stick_swings_long", 43, 58, 30.0, False),
        ("swing_lr_rest", "m_fpp_stick_swings", 220, 262, 20.0, False),
        ("swing_lr_hit_middle", "m_fpp_stick_hitshort", 0, 16, 30.0, False),
        ("heavy_charge", "m_fpp_stick_stronghit_rl_lr_dw", 0, 54, 30.0, False),
        ("heavy_swing", "m_fpp_stick_stronghit_rl_lr_dw", 55, 110, 33.0, False),
        ("exhausted_swing", "m_fpp_stick_lowstamina", 0, 47, 30.0, False),
        ("kick", "m_fpp_kick_forward", 0, 25, 40.0, False),
        ("dropkick", "m_fpp_unarmed_wrestlingkick_01", 10, 34, 30.0, False),
        ("stomp", "m_fpp_unarmed_laczekkick", 0, 36, 30.0, False),
        ("slide", "m_fpp_unarmed_slide_slow", 15, 27, 30.0, True),
        ("vault", "fpp_unarmed_jumponlowstand_1", 0, 15, 30.0, False),
        ("climb_ledge", "m_fpp_unarmed_nm_roofjump_frombottom_fast", 10, 39, 40.0, False),
        ("ledge_hang", "m_fpp_unarmed_nm_roofjump_frombottom_pose", 0, 10, 10.0, True),
        ("shimmy_left", "m_fpp_unarmed_shimmy_left_steadycam", 0, 22, 35.0, True),
        ("shimmy_right", "m_fpp_unarmed_shimmy_right_steadycam", 0, 22, 35.0, True),
        ("wall_run_left", "m_fpp_unarmed_wallrunl90", 33, 45, 30.0, True),
        ("wall_run_right", "m_fpp_unarmed_wallrunr90", 33, 45, 30.0, True),
        ("wall_run_up", "m_fpp_unarmed_wallrunfront_up", 0, 26, 30.0, False),
        ("dodge_left", "m_fpp_alt_dodgeleft_01", 0, 30, 40.0, False),
        ("dodge_right", "m_fpp_alt_dodgeright_01", 0, 30, 45.0, False),
        ("landing_roll", "m_fpp_unarmed_jumproll", 0, 30, 30.0, False),
        ("jump_air", "m_fpp_unarmed_jump_inplace", 20, 60, 30.0, True),
        ("tackle", "m_fpp_unarmed_tackle", 0, 28, 25.0, False),
        ("grapple", "m_fpp_universalthrow_dw", 132, 157, 30.0, False),
        ("ground_pound", "m_fpp_stick2heavy_groudpound", 60, 116, 30.0, False),
        ("grab_struggle", "m_fpp_volatile_grab_attack_sequence_02", 30, 180, 30.0, True),
    ]
    # Reformat parts_spec into internal helper shape
    def norm_parts(raw_parts):
        out = []
        for rec_i, dmat, smats in raw_parts:
            out.append((rec_i, dmat[0], {k: v[0] for k, v in smats.items()}))
        return out

    # Override parts_spec_materials to use raw_parts directly
    global parts_spec_materials
    def parts_spec_materials_impl(ps):
        seen = {}
        for _r, dmat, smats in ps:
            seen[dmat[0]] = dmat
            for v in smats.values():
                seen[v[0]] = v
        return list(seen.values())

    # Monkey-clean call using raw_parts in build_skinned_glb_clean
    def export_one(out_name, mesh_name, check_bones, raw_parts, clips):
        nonlocal anim_cache
        # Temporarily bind parts_spec_materials
        seen = {}
        for _r, dmat, smats in raw_parts:
            seen[dmat[0]] = dmat
            for v in smats.values():
                seen[v[0]] = v
        parts_spec_materials_list = list(seen.values())
        # Build with clean tuple
        rp_m = get_rpack("common_meshes_PC.rpack")
        mparts = rp_m.read_entry(mesh_name)
        b10, vb, ib = mparts[0x10], mparts[0xF0], mparts[0xF1]
        nodes, W, max_err, recs = parse_dl_skeleton_and_2fzn(b10, check_bones)

        # Print stand_rest eyecamera and r_handholder check for FPP
        if mesh_name == "player_dieselpunk_fpp":
            _, st_frames = decode_anm2_v42(get_rpack("common_anims_PC.rpack").read_entry("m_fpp_stick_stand_dw")[0x40])
            f0 = st_frames[0]
            # Evaluate world matrices in stand_rest
            SW = [None] * len(nodes)
            for i, n in enumerate(nodes):
                bh = dl_bone_hash(n["name"])
                if bh in f0:
                    q, t, _ = f0[bh]
                    lm = _quat_to_mat4(q, t)
                else:
                    lm = n["loc"]
                SW[i] = lm if n["parent"] < 0 else _mat4_mul(SW[n["parent"]], lm)
            for bn in ["eyecamera", "r_hand", "r_handholder"]:
                bi = [x["name"] for x in nodes].index(bn)
                m = SW[bi]
                print(f"  stand_rest {bn:14s}: pos=({m[0][3]:+.3f},{m[1][3]:+.3f},{m[2][3]:+.3f}) +X=({m[0][0]:+.2f},{m[1][0]:+.2f},{m[2][0]:+.2f}) +Y=({m[0][1]:+.2f},{m[1][1]:+.2f},{m[2][1]:+.2f}) +Z=({m[0][2]:+.2f},{m[1][2]:+.2f},{m[2][2]:+.2f})")

        # Delegate to build_skinned_glb with normalized parts
        norm = [(r, dm, sm) for r, dm, sm in raw_parts]
        # Store raw material lookup via closure
        global _ACTIVE_MATS
        _ACTIVE_MATS = parts_spec_materials_list
        build_skinned_glb(OUT_DIR / out_name, mesh_name, check_bones, norm_parts(raw_parts), clips, anim_cache)

    parts_spec_materials = lambda _ps: _ACTIVE_MATS  # noqa: E731

    export_one("dl_player_fpp.glb", "player_dieselpunk_fpp", 81, fpp_parts, fpp_clips)

    zombie_clips = [
        ("idle_sunlight", "m_zombie_a_idle_v01", 0, 120, 30.0, True),
        ("shamble", "m_zombie_a_walk_v01", 0, 60, 30.0, True),
        ("chase_run", "m_zombie_attack_circle_left_01", 0, 67, 31.0, True),
        ("attack_swipe", "m_zombie_a_attack_rhand_v01", 0, 60, 30.0, False),
        ("knockdown", "m_zombie_hitreaction_blunt_heavy_torso_right_01", 1, 123, 30.0, False),
        ("stagger", "m_zombie_hitreaction_blunt_light_torso_right_01", 1, 61, 30.0, False),
        ("hit_light_left", "m_zombie_hitreaction_blunt_light_torso_left_01", 1, 74, 30.0, False),
        ("hit_light_right", "m_zombie_hitreaction_blunt_light_torso_right_01", 1, 61, 30.0, False),
        ("hit_med_head_left", "m_zombie_hitreaction_blunt_medium_head_left_01", 2, 65, 30.0, False),
        ("hit_med_head_right", "m_zombie_hitreaction_blunt_medium_head_right_01", 2, 65, 30.0, False),
        ("hit_heavy_left", "m_zombie_hitreaction_blunt_heavy_torso_left_01", 1, 136, 30.0, False),
        ("hit_heavy_right", "m_zombie_hitreaction_blunt_heavy_torso_right_01", 1, 123, 30.0, False),
        ("death", "m_zombie_death_decapitation_01", 7, 120, 35.0, False),
    ]

    biter_parts = [
        (74, ("body", "common_textures_2_pc.rpack", "zombie_man_arm_a_clr"), {}),
        (73, ("torso", "common_textures_0_pc.rpack", "infected_torso_a_jeans_dif"), {}),
        (29, ("neck", "common_textures_2_pc.rpack", "zombie_man_a_neck_a_white_clr"), {}),
        (31, ("head", "common_textures_2_pc.rpack", "zombie_man_a_head_a_white_clr"), {}),
    ]
    export_one("dl_zombie_biter.glb", "zombie_man_a", 65, biter_parts, zombie_clips)

    volatile_parts = [
        (19, ("body", "common_textures_2_pc.rpack", "voleteile_dif"), {}),
        (20, ("head", "common_textures_2_pc.rpack", "volatile_head_clr"), {}),
    ]
    export_one("dl_zombie_volatile.glb", "zombie_voleteile", 65, volatile_parts, zombie_clips)

    goon_parts = [
        (3, ("body", "common_textures_0_pc.rpack", "goon_body_dif"), {}),
        (4, ("head", "common_textures_0_pc.rpack", "goon_head_dif"), {}),
        (7, ("shirt", "common_textures_0_pc.rpack", "goon_shirt_dif"), {}),
        (8, ("trousers", "common_textures_0_pc.rpack", "goon_trousers_dif"), {}),
    ]
    export_one("dl_zombie_goon.glb", "zombie_goon", 0, goon_parts, zombie_clips)
    return 0


_ACTIVE_MATS: list[tuple[str, str, str]] = []

if __name__ == "__main__":
    raise SystemExit(main())
