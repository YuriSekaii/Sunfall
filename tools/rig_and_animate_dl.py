"""Rig and animate Dying Light models + FPP survivor body in Blender 5.3.0 -> assets_ref/dl_rigged/."""
from __future__ import annotations

import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector
import numpy as np

ROOT = Path(r"c:\Users\Admin\Desktop\Code\SelfMadeProduct\Game\Sunfall")
DL_MODELS = ROOT / "assets_ref" / "dl_models"
OUT_DIR = ROOT / "assets_ref" / "dl_rigged"

ZOMBIE_SPECS = [
    {"key": "dl_zombie_biter", "obj": DL_MODELS / "dl_zombie_biter" / "dl_zombie_biter.obj"},
    {"key": "dl_zombie_volatile", "obj": DL_MODELS / "dl_zombie_volatile" / "dl_zombie_volatile.obj"},
    {"key": "dl_zombie_goon", "obj": DL_MODELS / "dl_zombie_goon" / "dl_zombie_goon.obj"},
]

WEAPON_SPECS = [
    {"key": "dl_weapon_pipe", "obj": DL_MODELS / "dl_weapon_pipe" / "dl_weapon_pipe.obj", "grip_z": 0.04},
    {"key": "dl_weapon_machete", "obj": DL_MODELS / "dl_weapon_machete" / "dl_weapon_machete.obj", "grip_z": 0.00},
    {"key": "dl_weapon_axe", "obj": DL_MODELS / "dl_weapon_axe" / "dl_weapon_axe.obj", "grip_z": 0.06},
]


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def deg_mat(rx: float, ry: float, rz: float) -> Matrix:
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()


def set_bone_world_rot(pb: bpy.types.PoseBone, rx: float, ry: float, rz: float) -> None:
    """Apply armature-space (rx, ry, rz) degrees cleanly regardless of bone rest roll."""
    r_arm = deg_mat(rx, ry, rz)
    b_rest = pb.bone.matrix_local.to_3x3()
    m_local = b_rest.transposed() @ r_arm @ b_rest
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = m_local.to_euler("XYZ")


def import_obj_facing_pos_y(obj_path: Path) -> bpy.types.Object:
    bpy.ops.wm.obj_import(filepath=str(obj_path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
    obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    # Apply OBJ importer's +90 X rotation, then rotate 180 Z so character faces +Y in Blender (-Z in Godot)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.rotation_euler = (0.0, 0.0, math.pi)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def build_humanoid_armature(
    name: str, bone_defs: list[tuple[str, tuple[float, float, float], tuple[float, float, float], str | None]]
) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new(name + "_Armature")
    arm_obj = bpy.data.objects.new(name + "_Armature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    edit_bones = {}
    for bname, head, tail, parent in bone_defs:
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        if bname == "WeaponSocket":
            eb.align_roll(Vector((0.0, -1.0, 0.0)))
        if parent and parent in edit_bones:
            eb.parent = edit_bones[parent]
        edit_bones[bname] = eb

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def zombie_bone_defs(obj: bpy.types.Object) -> list[tuple[str, tuple[float, float, float], tuple[float, float, float], str | None]]:
    co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float32)
    zmin = float(co[:, 2].min())
    zmax = float(co[:, 2].max())
    h = zmax - zmin

    # Sample actual arm positions in A-pose so bones align right inside mesh arms
    def mean_arm_z(x_lo: float, x_hi: float, default_z: float) -> float:
        mask = (np.abs(co[:, 0]) >= x_lo) & (np.abs(co[:, 0]) <= x_hi) & (co[:, 2] > zmin + 0.4 * h)
        return float(co[mask, 2].mean()) if np.any(mask) else default_z

    sh_x = 0.17
    el_x = 0.34
    wr_x = 0.43
    hd_x = min(0.50, float(np.abs(co[:, 0]).max()) - 0.01)

    sh_z = mean_arm_z(0.14, 0.22, zmin + 0.80 * h)
    el_z = mean_arm_z(0.30, 0.38, zmin + 0.68 * h)
    wr_z = mean_arm_z(0.40, 0.45, zmin + 0.58 * h)
    hd_z = mean_arm_z(0.45, 0.55, zmin + 0.52 * h)

    return [
        ("Hips", (0.0, 0.0, zmin + 0.52 * h), (0.0, 0.0, zmin + 0.61 * h), None),
        ("Spine", (0.0, 0.0, zmin + 0.61 * h), (0.0, 0.0, zmin + 0.73 * h), "Hips"),
        ("Chest", (0.0, 0.0, zmin + 0.73 * h), (0.0, 0.0, zmin + 0.84 * h), "Spine"),
        ("Neck", (0.0, 0.0, zmin + 0.84 * h), (0.0, 0.01, zmin + 0.89 * h), "Chest"),
        ("Head", (0.0, 0.01, zmin + 0.89 * h), (0.0, 0.02, zmax), "Neck"),
        ("Clavicle.L", (-0.05, 0.0, sh_z + 0.02), (-sh_x, 0.0, sh_z), "Chest"),
        ("UpperArm.L", (-sh_x, 0.0, sh_z), (-el_x, 0.0, el_z), "Clavicle.L"),
        ("Forearm.L", (-el_x, 0.0, el_z), (-wr_x, 0.02, wr_z), "UpperArm.L"),
        ("Hand.L", (-wr_x, 0.02, wr_z), (-hd_x, 0.03, hd_z), "Forearm.L"),
        ("Clavicle.R", (0.05, 0.0, sh_z + 0.02), (sh_x, 0.0, sh_z), "Chest"),
        ("UpperArm.R", (sh_x, 0.0, sh_z), (el_x, 0.0, el_z), "Clavicle.R"),
        ("Forearm.R", (el_x, 0.0, el_z), (wr_x, 0.02, wr_z), "UpperArm.R"),
        ("Hand.R", (wr_x, 0.02, wr_z), (hd_x, 0.03, hd_z), "Forearm.R"),
        ("Thigh.L", (-0.10, 0.0, zmin + 0.51 * h), (-0.10, 0.01, zmin + 0.28 * h), "Hips"),
        ("Shin.L", (-0.10, 0.01, zmin + 0.28 * h), (-0.10, -0.01, zmin + 0.05 * h), "Thigh.L"),
        ("Foot.L", (-0.10, -0.01, zmin + 0.05 * h), (-0.10, 0.14, zmin + 0.01), "Shin.L"),
        ("Thigh.R", (0.10, 0.0, zmin + 0.51 * h), (0.10, 0.01, zmin + 0.28 * h), "Hips"),
        ("Shin.R", (0.10, 0.01, zmin + 0.28 * h), (0.10, -0.01, zmin + 0.05 * h), "Thigh.R"),
        ("Foot.R", (0.10, -0.01, zmin + 0.05 * h), (0.10, 0.14, zmin + 0.01), "Shin.R"),
    ]


def segment_distance_skin(mesh_obj: bpy.types.Object, arm_obj: bpy.types.Object, exclude_bones: set[str] | None = None) -> None:
    """Assign smooth deterministic bone weights in numpy so 100% of vertices deform cleanly."""
    exclude = exclude_bones or set()
    bones = [b for b in arm_obj.data.bones if b.name not in exclude]
    heads = np.array([b.head_local[:] for b in bones], dtype=np.float32)  # (B, 3)
    tails = np.array([b.tail_local[:] for b in bones], dtype=np.float32)  # (B, 3)
    seg = tails - heads
    seg_len2 = np.maximum(np.sum(seg * seg, axis=1), 1e-8)

    verts = np.array([v.co[:] for v in mesh_obj.data.vertices], dtype=np.float32)  # (V, 3)
    # Closest point distance from each vertex to each bone segment
    diff = verts[:, None, :] - heads[None, :, :]  # (V, B, 3)
    t = np.clip(np.sum(diff * seg[None, :, :], axis=2) / seg_len2[None, :], 0.0, 1.0)
    proj = heads[None, :, :] + t[:, :, None] * seg[None, :, :]
    dist2 = np.sum((verts[:, None, :] - proj) ** 2, axis=2)  # (V, B)

    # Prevent left/right cross-bleeding across midline
    bone_x = 0.5 * (heads[:, 0] + tails[:, 0])
    is_left_bone = bone_x < -0.04
    is_right_bone = bone_x > 0.04
    vx = verts[:, 0:1]
    dist2[:, is_left_bone] += np.where(vx > 0.02, 4.0, 0.0)
    dist2[:, is_right_bone] += np.where(vx < -0.02, 4.0, 0.0)

    # Tighter sigma on limbs, slightly broader on torso
    sigmas = np.array(
        [0.11 if b.name in ("Hips", "Spine", "Chest") else 0.065 for b in bones], dtype=np.float32
    )
    weights = np.exp(-dist2 / (sigmas[None, :] ** 2))

    # Keep top 4 bones per vertex and normalize
    top_idx = np.argpartition(-weights, kth=min(4, len(bones) - 1), axis=1)[:, :4]
    top_w = np.take_along_axis(weights, top_idx, axis=1)
    top_sum = np.sum(top_w, axis=1, keepdims=True)
    # Fallback to nearest bone if all exp weights underflowed
    zero_mask = (top_sum[:, 0] < 1e-7)
    if np.any(zero_mask):
        nearest = np.argmin(dist2[zero_mask], axis=1)
        top_idx[zero_mask, :] = 0
        top_w[zero_mask, :] = 0.0
        top_idx[zero_mask, 0] = nearest
        top_w[zero_mask, 0] = 1.0
        top_sum = np.sum(top_w, axis=1, keepdims=True)
    top_w /= top_sum

    mesh_obj.vertex_groups.clear()
    vgroups = [mesh_obj.vertex_groups.new(name=b.name) for b in bones]
    for vi in range(len(verts)):
        for k in range(4):
            w = float(top_w[vi, k])
            if w > 1e-4:
                vgroups[int(top_idx[vi, k])].add([vi], w, "REPLACE")


def bind_mesh_to_armature(mesh_obj: bpy.types.Object, arm_obj: bpy.types.Object, exclude_bones: set[str] | None = None) -> str:
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj

    auto_ok = False
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        # Verify every vertex has non-zero weight and exclude WeaponSocket if present
        if exclude_bones:
            for gname in exclude_bones:
                vg = mesh_obj.vertex_groups.get(gname)
                if vg:
                    mesh_obj.vertex_groups.remove(vg)
        unbound = sum(1 for v in mesh_obj.data.vertices if sum(g.weight for g in v.groups) < 0.1)
        auto_ok = (unbound == 0)
    except Exception:
        auto_ok = False

    if not auto_ok:
        # Ensure parent + Armature modifier, then assign deterministic smooth weights
        mesh_obj.parent = arm_obj
        has_mod = any(m.type == "ARMATURE" and m.object == arm_obj for m in mesh_obj.modifiers)
        if not has_mod:
            mod = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
            mod.object = arm_obj
        segment_distance_skin(mesh_obj, arm_obj, exclude_bones)
        return "segment_numpy"
    return "armature_auto"


def bake_nla_action(
    arm_obj: bpy.types.Object,
    name: str,
    keyframes: list[tuple[int, dict[str, tuple[float, float, float]], tuple[float, float, float] | None]],
) -> None:
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    act = bpy.data.actions.new(name=name)
    arm_obj.animation_data.action = act

    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="POSE")

    for frame, bone_rots, hips_loc in keyframes:
        bpy.context.scene.frame_set(frame)
        for pb in arm_obj.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0.0, 0.0, 0.0)
            pb.location = (0.0, 0.0, 0.0)
        if hips_loc is not None and "Hips" in arm_obj.pose.bones:
            arm_obj.pose.bones["Hips"].location = Vector(hips_loc)
            arm_obj.pose.bones["Hips"].keyframe_insert(data_path="location", frame=frame)
        for bname, (rx, ry, rz) in bone_rots.items():
            if bname in arm_obj.pose.bones:
                pb = arm_obj.pose.bones[bname]
                set_bone_world_rot(pb, rx, ry, rz)
                pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        # Ensure Hips always has a rotation keyframe on frame 1 so track initializes cleanly
        if "Hips" in arm_obj.pose.bones and "Hips" not in bone_rots:
            arm_obj.pose.bones["Hips"].keyframe_insert(data_path="rotation_euler", frame=frame)

    bpy.ops.object.mode_set(mode="OBJECT")

    trk = arm_obj.animation_data.nla_tracks.new()
    trk.name = name
    end_frame = max(k[0] for k in keyframes)
    strip = trk.strips.new(name, 1, act)
    strip.action_frame_start = 1
    strip.action_frame_end = end_frame
    arm_obj.animation_data.action = None


def zombie_animations() -> dict[str, list]:
    # Blender right-hand rule around +X (right):
    #   +Z bones (Hips/Spine/Chest/Neck/Head): -rx leans FORWARD (+Y), +rx leans BACK (-Y)
    #   -Z bones (UpperArm/Forearm/Thigh/Shin): +rx swings FORWARD (+Y), -rx swings BACK (-Y)
    return {
        "idle_sunlight": [
            (1, {"Spine": (-16, 0, 0), "Chest": (-14, 0, -4), "Neck": (-10, 0, 0), "Head": (-14, 6, 4),
                 "UpperArm.L": (18, 0, 10), "Forearm.L": (28, 0, 0), "UpperArm.R": (18, 0, -10), "Forearm.R": (28, 0, 0),
                 "Thigh.L": (6, 0, 0), "Shin.L": (-10, 0, 0), "Thigh.R": (6, 0, 0), "Shin.R": (-10, 0, 0)}, (0, 0, -0.02)),
            (20, {"Spine": (-20, 0, 4), "Chest": (-18, 3, 4), "Neck": (-12, 0, 0), "Head": (-18, -8, -5),
                  "UpperArm.L": (24, 0, 8), "Forearm.L": (34, 0, 0), "UpperArm.R": (20, 0, -8), "Forearm.R": (30, 0, 0),
                  "Thigh.L": (8, 0, 0), "Shin.L": (-12, 0, 0), "Thigh.R": (8, 0, 0), "Shin.R": (-12, 0, 0)}, (0, 0, -0.03)),
            (40, {"Spine": (-16, 0, 0), "Chest": (-14, 0, -4), "Neck": (-10, 0, 0), "Head": (-14, 6, 4),
                  "UpperArm.L": (18, 0, 10), "Forearm.L": (28, 0, 0), "UpperArm.R": (18, 0, -10), "Forearm.R": (28, 0, 0),
                  "Thigh.L": (6, 0, 0), "Shin.L": (-10, 0, 0), "Thigh.R": (6, 0, 0), "Shin.R": (-10, 0, 0)}, (0, 0, -0.02)),
        ],
        "shamble": [
            (1, {"Spine": (-18, 4, -6), "Chest": (-14, 5, -6), "Head": (12, 6, 5),
                 "UpperArm.L": (62, 0, 16), "Forearm.L": (24, 0, 0), "UpperArm.R": (46, 0, -16), "Forearm.R": (32, 0, 0),
                 "Thigh.L": (26, 0, 0), "Shin.L": (-34, 0, 0), "Thigh.R": (-18, 0, 0), "Shin.R": (-10, 0, 0)}, (0, 0, -0.04)),
            (18, {"Spine": (-22, -5, 6), "Chest": (-16, -6, 6), "Head": (10, -8, -6),
                  "UpperArm.L": (48, 0, 18), "Forearm.L": (30, 0, 0), "UpperArm.R": (64, 0, -14), "Forearm.R": (22, 0, 0),
                  "Thigh.L": (-18, 0, 0), "Shin.L": (-12, 0, 0), "Thigh.R": (28, 0, 0), "Shin.R": (-36, 0, 0)}, (0, 0, -0.06)),
            (36, {"Spine": (-18, 4, -6), "Chest": (-14, 5, -6), "Head": (12, 6, 5),
                  "UpperArm.L": (62, 0, 16), "Forearm.L": (24, 0, 0), "UpperArm.R": (46, 0, -16), "Forearm.R": (32, 0, 0),
                  "Thigh.L": (26, 0, 0), "Shin.L": (-34, 0, 0), "Thigh.R": (-18, 0, 0), "Shin.R": (-10, 0, 0)}, (0, 0, -0.04)),
        ],
        "chase_run": [
            (1, {"Spine": (-22, 0, -10), "Chest": (-18, 0, -10), "Head": (24, 0, 6),
                 "UpperArm.L": (78, 0, 18), "Forearm.L": (38, 0, 0), "UpperArm.R": (16, 0, -18), "Forearm.R": (62, 0, 0),
                 "Thigh.L": (48, 0, 0), "Shin.L": (-60, 0, 0), "Thigh.R": (-36, 0, 0), "Shin.R": (-22, 0, 0)}, (0, 0, -0.09)),
            (10, {"Spine": (-24, 0, 10), "Chest": (-18, 0, 10), "Head": (26, 0, -6),
                  "UpperArm.L": (16, 0, 18), "Forearm.L": (62, 0, 0), "UpperArm.R": (80, 0, -18), "Forearm.R": (36, 0, 0),
                  "Thigh.L": (-36, 0, 0), "Shin.L": (-22, 0, 0), "Thigh.R": (48, 0, 0), "Shin.R": (-60, 0, 0)}, (0, 0, -0.05)),
            (20, {"Spine": (-22, 0, -10), "Chest": (-18, 0, -10), "Head": (24, 0, 6),
                  "UpperArm.L": (78, 0, 18), "Forearm.L": (38, 0, 0), "UpperArm.R": (16, 0, -18), "Forearm.R": (62, 0, 0),
                  "Thigh.L": (48, 0, 0), "Shin.L": (-60, 0, 0), "Thigh.R": (-36, 0, 0), "Shin.R": (-22, 0, 0)}, (0, 0, -0.09)),
        ],
        "attack_swipe": [
            (1, {"Spine": (-12, 0, 20), "Chest": (-12, 0, 22), "UpperArm.R": (105, 0, -35), "Forearm.R": (30, 0, 0),
                 "UpperArm.L": (40, 0, 22), "Forearm.L": (40, 0, 0)}, (0, 0, -0.03)),
            (10, {"Spine": (-26, 0, -26), "Chest": (-22, 0, -28), "Head": (14, 0, 14),
                  "UpperArm.R": (88, 0, 28), "Forearm.R": (18, 0, 0), "UpperArm.L": (68, 0, 18), "Forearm.L": (25, 0, 0),
                  "Thigh.L": (22, 0, 0), "Shin.L": (-28, 0, 0)}, (0, 0, -0.06)),
            (24, {"Spine": (-18, 0, 0), "Chest": (-14, 0, 0), "UpperArm.R": (48, 0, -18), "Forearm.R": (32, 0, 0),
                  "UpperArm.L": (48, 0, 18), "Forearm.L": (32, 0, 0)}, (0, 0, -0.03)),
        ],
        "stagger": [
            (1, {"Spine": (-14, 0, 0), "UpperArm.L": (40, 0, 18), "UpperArm.R": (40, 0, -18)}, (0, 0, -0.02)),
            (7, {"Spine": (24, 6, -12), "Chest": (18, 6, -10), "Head": (26, 0, 10),
                 "UpperArm.L": (60, 0, 50), "Forearm.L": (20, 0, 0), "UpperArm.R": (55, 0, -50), "Forearm.R": (20, 0, 0),
                 "Thigh.L": (20, 0, 0), "Shin.L": (-28, 0, 0), "Thigh.R": (-10, 0, 0)}, (0, -0.08, -0.05)),
            (22, {"Spine": (-16, 0, 0), "Chest": (-12, 0, 0), "UpperArm.L": (35, 0, 16), "UpperArm.R": (35, 0, -16)}, (0, 0, -0.02)),
        ],
        "knockdown": [
            (1, {"Hips": (0, 0, 0), "Spine": (12, 0, 0), "UpperArm.L": (30, 0, 35), "UpperArm.R": (30, 0, -35)}, (0, 0, 0)),
            (14, {"Hips": (48, 0, 0), "Spine": (15, 0, 0), "Thigh.L": (45, 0, 0), "Shin.L": (-30, 0, 0),
                  "Thigh.R": (52, 0, 0), "Shin.R": (-25, 0, 0), "UpperArm.L": (60, 0, 50), "UpperArm.R": (60, 0, -50)}, (0, -0.25, -0.42)),
            (30, {"Hips": (84, 0, 0), "Spine": (8, 0, 0), "Head": (-18, 0, 0),
                  "Thigh.L": (14, 0, -8), "Shin.L": (-18, 0, 0), "Thigh.R": (18, 0, 10), "Shin.R": (-24, 0, 0),
                  "UpperArm.L": (15, 0, 60), "UpperArm.R": (15, 0, -60)}, (0, -0.52, -0.78)),
        ],
        "death": [
            (1, {"Hips": (0, 0, 0), "Spine": (-18, 0, 0)}, (0, 0, 0)),
            (12, {"Hips": (-42, 6, 0), "Spine": (-15, 0, 0), "Thigh.L": (25, 0, 0), "Shin.L": (-45, 0, 0),
                  "Thigh.R": (20, 0, 0), "Shin.R": (-40, 0, 0), "UpperArm.L": (40, 0, 35), "UpperArm.R": (40, 0, -35)}, (0, 0.18, -0.40)),
            (28, {"Hips": (-85, 8, 0), "Spine": (-6, 0, 0), "Head": (12, 10, 0),
                  "Thigh.L": (8, 0, -8), "Shin.L": (-12, 0, 0), "Thigh.R": (10, 0, 8), "Shin.R": (-10, 0, 0),
                  "UpperArm.L": (25, 0, 52), "Forearm.L": (15, 0, 0), "UpperArm.R": (22, 0, -52), "Forearm.R": (15, 0, 0)}, (0, 0.35, -0.82)),
        ],
    }


def make_mat(name: str, color: tuple[float, float, float], roughness: float = 0.78) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_limb_capsule(
    bm_objs: list[bpy.types.Object],
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    r0: float,
    mat: bpy.types.Material,
    r1: float | None = None,
) -> None:
    v0, v1 = Vector(p0), Vector(p1)
    diff = v1 - v0
    length = diff.length
    mid = (v0 + v1) * 0.5
    rad2 = r0 if r1 is None else r1
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=r0, radius2=rad2, depth=length, location=mid)
    ob = bpy.context.active_object
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = diff.normalized().to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mat)
    bm_objs.append(ob)


def add_rounded_box(
    bm_objs: list[bpy.types.Object],
    loc: tuple[float, float, float],
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.scale = scale
    ob.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mat)
    bm_objs.append(ob)


def build_fpp_player() -> tuple[bpy.types.Object, bpy.types.Object]:
    """Generate clean textured FPP survivor body (no head/neck; grounded FPP arm/weapon framing + legs/boots)."""
    mat_jacket = make_mat("SurvivorJacket", (0.21, 0.24, 0.19), 0.84)
    mat_cuff = make_mat("SurvivorCuff", (0.15, 0.16, 0.14), 0.86)
    mat_skin = make_mat("SurvivorSkin", (0.64, 0.46, 0.36), 0.68)
    mat_glove = make_mat("SurvivorGlove", (0.12, 0.12, 0.13), 0.72)
    mat_jeans = make_mat("SurvivorJeans", (0.14, 0.17, 0.23), 0.88)
    mat_boot = make_mat("SurvivorBoot", (0.11, 0.08, 0.06), 0.70)

    parts: list[bpy.types.Object] = []

    # Torso shifted slightly back (-0.07 Y) so camera at (0, 0, 1.56) sees legs/chest cleanly without clipping
    add_limb_capsule(parts, (0.0, -0.07, 0.88), (0.0, -0.07, 1.12), 0.142, mat_jacket, 0.150)
    add_limb_capsule(parts, (0.0, -0.07, 1.10), (0.0, -0.07, 1.39), 0.155, mat_jacket, 0.165)
    add_rounded_box(parts, (0.0, -0.07, 0.91), (0.30, 0.24, 0.06), mat_boot)  # tactical belt

    # Legs + articulated Boots (Z=0.0..0.90)
    for side_x in (-0.105, 0.105):
        add_limb_capsule(parts, (side_x, -0.06, 0.90), (side_x, -0.02, 0.48), 0.085, mat_jeans, 0.068)
        add_limb_capsule(parts, (side_x, -0.02, 0.48), (side_x, -0.04, 0.10), 0.068, mat_jeans, 0.055)
        add_limb_capsule(parts, (side_x, -0.04, 0.16), (side_x, -0.03, 0.04), 0.060, mat_boot, 0.058)
        add_rounded_box(parts, (side_x, 0.04, 0.05), (0.105, 0.22, 0.09), mat_boot)

    # Arms framed naturally inside Camera3D FOV 72deg at (0, 0, 1.56):
    # Hand.R at (+0.21, +0.44, 1.36) -> Godot (+0.21 right, -0.20 down, -0.44 forward)
    # Hand.L at (-0.23, +0.42, 1.34) -> Godot (-0.23 left, -0.22 down, -0.42 forward)
    arm_pose = {
        "L": ((-0.18, -0.06, 1.36), (-0.27, 0.16, 1.15), (-0.23, 0.42, 1.34), (-0.20, 0.51, 1.37)),
        "R": ((0.18, -0.06, 1.36), (0.26, 0.17, 1.15), (0.21, 0.44, 1.36), (0.19, 0.53, 1.39)),
    }
    for side, (sh, el, wr, fg) in arm_pose.items():
        add_limb_capsule(parts, sh, el, 0.058, mat_jacket, 0.048)
        add_limb_capsule(parts, el, wr, 0.045, mat_skin, 0.034)
        # Rolled sleeve cuff near elbow + wrist wrap
        cuff_p0 = tuple(el[i] + (wr[i] - el[i]) * 0.12 for i in range(3))
        add_limb_capsule(parts, el, cuff_p0, 0.050, mat_cuff, 0.048)
        # Gloved palm + thumb + curled finger grip
        palm_loc = tuple((wr[i] + fg[i]) * 0.5 for i in range(3))
        add_rounded_box(parts, palm_loc, (0.058, 0.095, 0.068), mat_glove)
        sgn = -1.0 if side == "L" else 1.0
        add_rounded_box(parts, (palm_loc[0] - sgn * 0.032, palm_loc[1] + 0.015, palm_loc[2] + 0.024), (0.026, 0.055, 0.026), mat_glove)
        add_rounded_box(parts, (fg[0], fg[1] + 0.01, fg[2] - 0.01), (0.052, 0.036, 0.048), mat_skin)

    # Join all parts into one clean FPP mesh
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh_obj = bpy.context.active_object
    mesh_obj.name = "dl_player_fpp_mesh"

    sh_l, el_l, wr_l, fg_l = arm_pose["L"]
    sh_r, el_r, wr_r, fg_r = arm_pose["R"]
    ws_head = (wr_r[0] - 0.01, (wr_r[1] + fg_r[1]) * 0.5 + 0.01, (wr_r[2] + fg_r[2]) * 0.5)
    ws_tail = (ws_head[0] - 0.025, ws_head[1] + 0.065, ws_head[2] + 0.165)

    bones = [
        ("Hips", (0.0, -0.07, 0.88), (0.0, -0.07, 1.02), None),
        ("Spine", (0.0, -0.07, 1.02), (0.0, -0.07, 1.20), "Hips"),
        ("Chest", (0.0, -0.07, 1.20), (0.0, -0.07, 1.39), "Spine"),
        ("Neck", (0.0, -0.07, 1.39), (0.0, -0.07, 1.46), "Chest"),
        ("Head", (0.0, -0.07, 1.46), (0.0, -0.07, 1.56), "Neck"),
        ("Clavicle.L", (-0.05, -0.06, 1.37), sh_l, "Chest"),
        ("UpperArm.L", sh_l, el_l, "Clavicle.L"),
        ("Forearm.L", el_l, wr_l, "UpperArm.L"),
        ("Hand.L", wr_l, fg_l, "Forearm.L"),
        ("Clavicle.R", (0.05, -0.06, 1.37), sh_r, "Chest"),
        ("UpperArm.R", sh_r, el_r, "Clavicle.R"),
        ("Forearm.R", el_r, wr_r, "UpperArm.R"),
        ("Hand.R", wr_r, fg_r, "Forearm.R"),
        ("WeaponSocket", ws_head, ws_tail, "Hand.R"),
        ("Thigh.L", (-0.105, -0.06, 0.88), (-0.105, -0.02, 0.48), "Hips"),
        ("Shin.L", (-0.105, -0.02, 0.48), (-0.105, -0.04, 0.10), "Thigh.L"),
        ("Foot.L", (-0.105, -0.04, 0.10), (-0.105, 0.11, 0.02), "Shin.L"),
        ("Thigh.R", (0.105, -0.06, 0.88), (0.105, -0.02, 0.48), "Hips"),
        ("Shin.R", (0.105, -0.02, 0.48), (0.105, -0.04, 0.10), "Thigh.R"),
        ("Foot.R", (0.105, -0.04, 0.10), (0.105, 0.11, 0.02), "Shin.R"),
    ]
    arm_obj = build_humanoid_armature("dl_player_fpp", bones)
    skin_method = bind_mesh_to_armature(mesh_obj, arm_obj, exclude_bones={"WeaponSocket"})
    print(f"FPP player skinned via {skin_method}, verts={len(mesh_obj.data.vertices)}")

    anims = {
        "idle": [
            (1, {"UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0), "UpperArm.L": (0, 0, 0)}, (0, 0, 0)),
            (24, {"UpperArm.R": (2, 0, 0), "Forearm.R": (3, 0, 0), "UpperArm.L": (2, 0, 0)}, (0, 0, -0.008)),
            (48, {"UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0), "UpperArm.L": (0, 0, 0)}, (0, 0, 0)),
        ],
        "walk": [
            (1, {"UpperArm.R": (5, 0, -2), "UpperArm.L": (-8, 0, 0), "Thigh.L": (22, 0, 0), "Shin.L": (-26, 0, 0), "Thigh.R": (-16, 0, 0)}, (0, 0, -0.02)),
            (14, {"UpperArm.R": (-6, 0, 2), "UpperArm.L": (10, 0, 0), "Thigh.L": (-16, 0, 0), "Thigh.R": (22, 0, 0), "Shin.R": (-26, 0, 0)}, (0, 0, 0.01)),
            (28, {"UpperArm.R": (5, 0, -2), "UpperArm.L": (-8, 0, 0), "Thigh.L": (22, 0, 0), "Shin.L": (-26, 0, 0), "Thigh.R": (-16, 0, 0)}, (0, 0, -0.02)),
        ],
        "sprint": [
            (1, {"Chest": (-10, 0, 0), "UpperArm.R": (22, 0, 12), "Forearm.R": (25, 0, 0), "UpperArm.L": (-22, 0, -10),
                 "Thigh.L": (42, 0, 0), "Shin.L": (-55, 0, 0), "Thigh.R": (-30, 0, 0)}, (0, 0, -0.04)),
            (9, {"Chest": (-10, 0, 0), "UpperArm.R": (-18, 0, -10), "Forearm.R": (18, 0, 0), "UpperArm.L": (24, 0, 10),
                 "Thigh.L": (-30, 0, 0), "Thigh.R": (42, 0, 0), "Shin.R": (-55, 0, 0)}, (0, 0, 0.02)),
            (18, {"Chest": (-10, 0, 0), "UpperArm.R": (22, 0, 12), "Forearm.R": (25, 0, 0), "UpperArm.L": (-22, 0, -10),
                  "Thigh.L": (42, 0, 0), "Shin.L": (-55, 0, 0), "Thigh.R": (-30, 0, 0)}, (0, 0, -0.04)),
        ],
        "swing_right": [
            (1, {"UpperArm.R": (25, -20, -28), "Forearm.R": (20, 0, 0), "Chest": (0, 0, -14)}, (0, 0, 0)),
            (6, {"UpperArm.R": (48, 32, 48), "Forearm.R": (-20, 18, 22), "Hand.R": (18, 0, 18), "Chest": (-8, 0, 18)}, (0, 0.02, 0)),
            (18, {"UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0), "Chest": (0, 0, 0)}, (0, 0, 0)),
        ],
        "swing_left": [
            (1, {"UpperArm.R": (25, 25, 38), "Forearm.R": (22, 0, 15), "Chest": (0, 0, 14)}, (0, 0, 0)),
            (6, {"UpperArm.R": (40, -32, -42), "Forearm.R": (-20, -16, -20), "Hand.R": (18, 0, -18), "Chest": (-8, 0, -16)}, (0, 0.02, 0)),
            (18, {"UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0), "Chest": (0, 0, 0)}, (0, 0, 0)),
        ],
        "heavy_charge": [
            (1, {"UpperArm.R": (0, 0, 0)}, (0, 0, 0)),
            (12, {"UpperArm.R": (48, -28, -42), "Forearm.R": (35, 0, 0), "Chest": (10, 0, -22), "UpperArm.L": (18, 0, 14)}, (0, -0.03, 0)),
        ],
        "heavy_swing": [
            (1, {"UpperArm.R": (48, -28, -42), "Forearm.R": (35, 0, 0), "Chest": (10, 0, -22)}, (0, -0.03, 0)),
            (6, {"UpperArm.R": (38, 42, 62), "Forearm.R": (-28, 24, 28), "Hand.R": (24, 0, 22), "Chest": (-14, 0, 26)}, (0, 0.05, 0)),
            (20, {"UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0), "Chest": (0, 0, 0)}, (0, 0, 0)),
        ],
        "kick": [
            (1, {"Thigh.R": (18, 0, 0), "Shin.R": (-28, 0, 0), "UpperArm.R": (-8, 0, -8)}, (0, 0, 0)),
            (8, {"Thigh.R": (88, 0, 0), "Shin.R": (-12, 0, 0), "Foot.R": (-22, 0, 0), "Spine": (12, 0, 0), "UpperArm.L": (16, 0, 16), "UpperArm.R": (-10, 0, -12)}, (0, -0.04, 0)),
            (19, {"Thigh.R": (0, 0, 0), "Shin.R": (0, 0, 0), "Spine": (0, 0, 0)}, (0, 0, 0)),
        ],
        "dropkick": [
            (1, {"Thigh.L": (35, 0, 0), "Shin.L": (-55, 0, 0), "Thigh.R": (35, 0, 0), "Shin.R": (-55, 0, 0), "Spine": (18, 0, 0)}, (0, 0, 0)),
            (8, {"Thigh.L": (92, 0, -6), "Shin.L": (-8, 0, 0), "Thigh.R": (92, 0, 6), "Shin.R": (-8, 0, 0),
                 "Spine": (32, 0, 0), "UpperArm.L": (25, 0, 35), "UpperArm.R": (20, 0, -35)}, (0, -0.10, -0.08)),
            (22, {"Thigh.L": (0, 0, 0), "Shin.L": (0, 0, 0), "Thigh.R": (0, 0, 0), "Shin.R": (0, 0, 0), "Spine": (0, 0, 0)}, (0, 0, 0)),
        ],
        "climb_ledge": [
            (1, {"UpperArm.L": (85, 0, 10), "Forearm.L": (-25, 0, 0), "UpperArm.R": (85, 0, -10), "Forearm.R": (-25, 0, 0)}, (0, 0, 0)),
            (10, {"UpperArm.L": (25, 0, 15), "Forearm.L": (40, 0, 0), "UpperArm.R": (25, 0, -15), "Forearm.R": (40, 0, 0), "Chest": (-14, 0, 0)}, (0, 0.05, 0.12)),
            (20, {"UpperArm.L": (0, 0, 0), "Forearm.L": (0, 0, 0), "UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0)}, (0, 0, 0)),
        ],
        "vault": [
            (1, {"UpperArm.L": (55, 0, 8), "Forearm.L": (-10, 0, 0), "UpperArm.R": (-10, 0, -12)}, (0, 0, 0)),
            (8, {"UpperArm.L": (15, 0, 12), "Thigh.L": (60, 0, 0), "Shin.L": (-80, 0, 0), "Thigh.R": (55, 0, 0), "Shin.R": (-75, 0, 0)}, (0, 0.04, 0.06)),
            (16, {"UpperArm.L": (0, 0, 0), "Thigh.L": (0, 0, 0), "Shin.L": (0, 0, 0)}, (0, 0, 0)),
        ],
        "slide": [
            (1, {"Hips": (25, 0, 0), "Thigh.R": (75, 0, 0), "Shin.R": (-10, 0, 0), "Thigh.L": (45, 0, 0), "Shin.L": (-85, 0, 0),
                 "UpperArm.L": (28, 0, 20), "UpperArm.R": (-10, 0, -15)}, (0, -0.10, -0.52)),
            (18, {"Hips": (25, 0, 0), "Thigh.R": (75, 0, 0), "Shin.R": (-10, 0, 0), "Thigh.L": (45, 0, 0), "Shin.L": (-85, 0, 0)}, (0, -0.10, -0.52)),
        ],
        "dodge_left": [
            (1, {"Spine": (0, -14, 0), "UpperArm.L": (20, 0, 22), "UpperArm.R": (10, 0, 12)}, (-0.08, 0, -0.04)),
            (10, {"Spine": (0, 0, 0), "UpperArm.L": (0, 0, 0), "UpperArm.R": (0, 0, 0)}, (0, 0, 0)),
        ],
        "dodge_right": [
            (1, {"Spine": (0, 14, 0), "UpperArm.L": (10, 0, -12), "UpperArm.R": (20, 0, -22)}, (0.08, 0, -0.04)),
            (10, {"Spine": (0, 0, 0), "UpperArm.L": (0, 0, 0), "UpperArm.R": (0, 0, 0)}, (0, 0, 0)),
        ],
        "wall_run_left": [
            (1, {"Chest": (-8, 12, 0), "UpperArm.L": (55, 0, 25), "UpperArm.R": (-15, 0, -15), "Thigh.L": (38, 0, 0), "Shin.L": (-52, 0, 0), "Thigh.R": (-25, 0, 0)}, (0, 0, 0)),
            (10, {"Chest": (-8, 12, 0), "UpperArm.L": (45, 0, 22), "UpperArm.R": (22, 0, -12), "Thigh.L": (-25, 0, 0), "Thigh.R": (38, 0, 0), "Shin.R": (-52, 0, 0)}, (0, 0, 0.03)),
            (18, {"Chest": (-8, 12, 0), "UpperArm.L": (55, 0, 25), "UpperArm.R": (-15, 0, -15), "Thigh.L": (38, 0, 0), "Shin.L": (-52, 0, 0), "Thigh.R": (-25, 0, 0)}, (0, 0, 0)),
        ],
        "wall_run_right": [
            (1, {"Chest": (-8, -12, 0), "UpperArm.R": (55, 0, -25), "UpperArm.L": (-15, 0, 15), "Thigh.R": (38, 0, 0), "Shin.R": (-52, 0, 0), "Thigh.L": (-25, 0, 0)}, (0, 0, 0)),
            (10, {"Chest": (-8, -12, 0), "UpperArm.R": (45, 0, -22), "UpperArm.L": (22, 0, 12), "Thigh.R": (-25, 0, 0), "Thigh.L": (38, 0, 0), "Shin.L": (-52, 0, 0)}, (0, 0, 0.03)),
            (18, {"Chest": (-8, -12, 0), "UpperArm.R": (55, 0, -25), "UpperArm.L": (-15, 0, 15), "Thigh.R": (38, 0, 0), "Shin.R": (-52, 0, 0), "Thigh.L": (-25, 0, 0)}, (0, 0, 0)),
        ],
        # --- New 12 Dying Light 1 FPP animations ---
        "ledge_hang": [
            (1, {"UpperArm.L": (98, 0, 14), "Forearm.L": (-16, 0, 0), "UpperArm.R": (98, 0, -14), "Forearm.R": (-16, 0, 0),
                 "Spine": (6, 0, 0), "Thigh.L": (18, 0, 0), "Shin.L": (-26, 0, 0), "Thigh.R": (12, 0, 0), "Shin.R": (-18, 0, 0)}, (0, -0.04, -0.05)),
            (20, {"UpperArm.L": (95, 0, 14), "Forearm.L": (-20, 0, 0), "UpperArm.R": (95, 0, -14), "Forearm.R": (-20, 0, 0),
                  "Spine": (8, 0, 0), "Thigh.L": (22, 0, 0), "Shin.L": (-30, 0, 0), "Thigh.R": (14, 0, 0), "Shin.R": (-20, 0, 0)}, (0, -0.04, -0.07)),
            (40, {"UpperArm.L": (98, 0, 14), "Forearm.L": (-16, 0, 0), "UpperArm.R": (98, 0, -14), "Forearm.R": (-16, 0, 0),
                  "Spine": (6, 0, 0), "Thigh.L": (18, 0, 0), "Shin.L": (-26, 0, 0), "Thigh.R": (12, 0, 0), "Shin.R": (-18, 0, 0)}, (0, -0.04, -0.05)),
        ],
        "shimmy_left": [
            (1, {"UpperArm.L": (98, 0, 26), "Forearm.L": (-12, 0, 0), "UpperArm.R": (92, 0, -8), "Forearm.R": (-22, 0, 0),
                 "Chest": (0, -8, 10), "Thigh.L": (24, 0, -6), "Shin.L": (-30, 0, 0)}, (-0.06, -0.04, -0.04)),
            (12, {"UpperArm.L": (92, 0, 10), "Forearm.L": (-24, 0, 0), "UpperArm.R": (100, 0, -20), "Forearm.R": (-14, 0, 0),
                  "Chest": (0, 6, -8), "Thigh.R": (22, 0, 6), "Shin.R": (-28, 0, 0)}, (0.04, -0.04, -0.06)),
            (24, {"UpperArm.L": (98, 0, 26), "Forearm.L": (-12, 0, 0), "UpperArm.R": (92, 0, -8), "Forearm.R": (-22, 0, 0),
                  "Chest": (0, -8, 10), "Thigh.L": (24, 0, -6), "Shin.L": (-30, 0, 0)}, (-0.06, -0.04, -0.04)),
        ],
        "shimmy_right": [
            (1, {"UpperArm.R": (98, 0, -26), "Forearm.R": (-12, 0, 0), "UpperArm.L": (92, 0, 8), "Forearm.L": (-22, 0, 0),
                 "Chest": (0, 8, -10), "Thigh.R": (24, 0, 6), "Shin.R": (-30, 0, 0)}, (0.06, -0.04, -0.04)),
            (12, {"UpperArm.R": (92, 0, -10), "Forearm.R": (-24, 0, 0), "UpperArm.L": (100, 0, 20), "Forearm.L": (-14, 0, 0),
                  "Chest": (0, -6, 8), "Thigh.L": (22, 0, -6), "Shin.L": (-28, 0, 0)}, (-0.04, -0.04, -0.06)),
            (24, {"UpperArm.R": (98, 0, -26), "Forearm.R": (-12, 0, 0), "UpperArm.L": (92, 0, 8), "Forearm.L": (-22, 0, 0),
                  "Chest": (0, 8, -10), "Thigh.R": (24, 0, 6), "Shin.R": (-30, 0, 0)}, (0.06, -0.04, -0.04)),
        ],
        "wall_run_up": [
            (1, {"Chest": (10, 0, 0), "UpperArm.L": (88, 0, 12), "Forearm.L": (-18, 0, 0), "UpperArm.R": (42, 0, -12),
                 "Thigh.L": (64, 0, 0), "Shin.L": (-80, 0, 0), "Thigh.R": (-12, 0, 0)}, (0, 0, 0.02)),
            (8, {"Chest": (10, 0, 0), "UpperArm.L": (42, 0, 12), "UpperArm.R": (88, 0, -12), "Forearm.R": (-18, 0, 0),
                 "Thigh.L": (-12, 0, 0), "Thigh.R": (64, 0, 0), "Shin.R": (-80, 0, 0)}, (0, 0, 0.05)),
            (16, {"Chest": (10, 0, 0), "UpperArm.L": (88, 0, 12), "Forearm.L": (-18, 0, 0), "UpperArm.R": (42, 0, -12),
                  "Thigh.L": (64, 0, 0), "Shin.L": (-80, 0, 0), "Thigh.R": (-12, 0, 0)}, (0, 0, 0.02)),
        ],
        "landing_roll": [
            (1, {"Spine": (-38, 0, 0), "Chest": (-28, 0, 0), "Thigh.L": (72, 0, 0), "Shin.L": (-98, 0, 0), "Thigh.R": (72, 0, 0), "Shin.R": (-98, 0, 0),
                 "UpperArm.L": (55, 0, -15), "UpperArm.R": (55, 0, 15)}, (0, 0.06, -0.35)),
            (10, {"Hips": (-78, 0, 0), "Spine": (-30, 0, 0), "Thigh.L": (92, 0, 0), "Shin.L": (-115, 0, 0), "Thigh.R": (92, 0, 0), "Shin.R": (-115, 0, 0),
                  "UpperArm.L": (35, 0, -25), "UpperArm.R": (35, 0, 25)}, (0, 0.14, -0.58)),
            (22, {"Hips": (0, 0, 0), "Spine": (-10, 0, 0), "Thigh.L": (25, 0, 0), "Shin.L": (-35, 0, 0), "Thigh.R": (15, 0, 0), "Shin.R": (-20, 0, 0)}, (0, 0, -0.10)),
        ],
        "tackle": [
            (1, {"Chest": (-22, 0, -16), "Spine": (-16, 0, 0), "UpperArm.L": (48, 0, -24), "Forearm.L": (30, 0, 0),
                 "UpperArm.R": (42, 0, 26), "Forearm.R": (30, 0, 0), "Thigh.L": (36, 0, 0), "Shin.L": (-48, 0, 0), "Thigh.R": (-24, 0, 0)}, (0, 0.08, -0.08)),
            (14, {"Chest": (-26, 0, -18), "Spine": (-18, 0, 0), "UpperArm.L": (52, 0, -26), "Forearm.L": (34, 0, 0),
                  "UpperArm.R": (46, 0, 28), "Forearm.R": (34, 0, 0), "Thigh.L": (-20, 0, 0), "Thigh.R": (38, 0, 0), "Shin.R": (-50, 0, 0)}, (0, 0.10, -0.10)),
            (22, {"Chest": (0, 0, 0), "Spine": (0, 0, 0), "UpperArm.L": (0, 0, 0), "UpperArm.R": (0, 0, 0)}, (0, 0, 0)),
        ],
        "grapple": [
            (1, {"UpperArm.L": (76, 0, 6), "Forearm.L": (-8, 0, 0), "Hand.L": (12, 0, 0), "Chest": (-6, 0, 12), "UpperArm.R": (-12, 0, -10)}, (0, 0, 0)),
            (10, {"UpperArm.L": (84, 0, 4), "Forearm.L": (18, 0, 0), "Chest": (14, 0, 10), "UpperArm.R": (-16, 0, -14), "Thigh.L": (32, 0, 0), "Shin.L": (-45, 0, 0)}, (0, 0.06, 0.04)),
            (22, {"UpperArm.L": (45, 0, 8), "Forearm.L": (24, 0, 0), "Chest": (4, 0, 4), "UpperArm.R": (0, 0, 0)}, (0, 0, 0)),
        ],
        "ground_pound": [
            (1, {"Spine": (14, 0, 0), "Chest": (12, 0, 0), "UpperArm.R": (108, 0, 18), "Forearm.R": (22, 0, 0),
                 "UpperArm.L": (102, 0, -22), "Forearm.L": (22, 0, 0), "Thigh.L": (38, 0, 0), "Shin.L": (-65, 0, 0), "Thigh.R": (38, 0, 0), "Shin.R": (-65, 0, 0)}, (0, 0, 0.04)),
            (10, {"Spine": (-26, 0, 0), "Chest": (-22, 0, 0), "UpperArm.R": (28, 0, 22), "Forearm.R": (-18, 0, 0),
                  "UpperArm.L": (32, 0, -22), "Forearm.L": (-18, 0, 0), "Thigh.L": (64, 0, 0), "Shin.L": (-90, 0, 0), "Thigh.R": (58, 0, 0), "Shin.R": (-85, 0, 0)}, (0, 0.04, -0.36)),
            (22, {"Spine": (0, 0, 0), "Chest": (0, 0, 0), "UpperArm.R": (0, 0, 0), "UpperArm.L": (0, 0, 0)}, (0, 0, 0)),
        ],
        "stomp": [
            (1, {"Thigh.R": (72, 0, 0), "Shin.R": (-78, 0, 0), "Foot.R": (-12, 0, 0), "Spine": (10, 0, 0), "UpperArm.L": (14, 0, 14), "UpperArm.R": (-10, 0, -10)}, (0, 0, 0.02)),
            (9, {"Thigh.R": (24, 0, 0), "Shin.R": (-14, 0, 0), "Foot.R": (16, 0, 0), "Spine": (-16, 0, 0), "UpperArm.L": (-12, 0, 18), "UpperArm.R": (12, 0, -18)}, (0, 0.04, -0.12)),
            (19, {"Thigh.R": (0, 0, 0), "Shin.R": (0, 0, 0), "Spine": (0, 0, 0)}, (0, 0, 0)),
        ],
        "grab_struggle": [
            (1, {"Chest": (8, -12, 16), "UpperArm.L": (68, 0, 12), "Forearm.L": (16, 0, 0), "UpperArm.R": (32, 0, -24), "Forearm.R": (26, 0, 0)}, (0, -0.03, 0)),
            (8, {"Chest": (10, 14, -18), "UpperArm.L": (54, 0, -8), "Forearm.L": (28, 0, 0), "UpperArm.R": (66, 0, -10), "Forearm.R": (14, 0, 0)}, (0, -0.02, 0)),
            (16, {"Chest": (8, -12, 16), "UpperArm.L": (68, 0, 12), "Forearm.L": (16, 0, 0), "UpperArm.R": (32, 0, -24), "Forearm.R": (26, 0, 0)}, (0, -0.03, 0)),
        ],
        "exhausted_swing": [
            (1, {"Chest": (-12, 0, -8), "UpperArm.R": (18, -12, -16), "Forearm.R": (14, 0, 0), "UpperArm.L": (8, 0, 8)}, (0, 0, -0.04)),
            (12, {"Chest": (-18, 0, 12), "UpperArm.R": (32, 18, 28), "Forearm.R": (-12, 10, 12), "Hand.R": (12, 0, 10), "UpperArm.L": (10, 0, 10)}, (0, 0.01, -0.06)),
            (28, {"Chest": (-10, 0, 0), "UpperArm.R": (0, 0, 0), "Forearm.R": (0, 0, 0)}, (0, 0, -0.02)),
        ],
        "crouch_idle": [
            (1, {"Spine": (-12, 0, 0), "Chest": (-8, 0, 0), "Thigh.L": (66, 0, -4), "Shin.L": (-92, 0, 0), "Thigh.R": (62, 0, 4), "Shin.R": (-88, 0, 0),
                 "UpperArm.L": (10, 0, 6), "UpperArm.R": (8, 0, -6)}, (0, -0.02, -0.42)),
            (24, {"Spine": (-15, 0, 0), "Chest": (-10, 0, 0), "Thigh.L": (68, 0, -4), "Shin.L": (-95, 0, 0), "Thigh.R": (64, 0, 4), "Shin.R": (-91, 0, 0),
                  "UpperArm.L": (12, 0, 6), "UpperArm.R": (10, 0, -6)}, (0, -0.02, -0.44)),
            (48, {"Spine": (-12, 0, 0), "Chest": (-8, 0, 0), "Thigh.L": (66, 0, -4), "Shin.L": (-92, 0, 0), "Thigh.R": (62, 0, 4), "Shin.R": (-88, 0, 0),
                  "UpperArm.L": (10, 0, 6), "UpperArm.R": (8, 0, -6)}, (0, -0.02, -0.42)),
        ],
    }
    for aname, kfs in anims.items():
        bake_nla_action(arm_obj, aname, kfs)
    return arm_obj, mesh_obj


def export_glb(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(dest),
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_nla_strips=True,
        export_apply=False,
    )


def render_preview_check(manifest: dict) -> None:
    """Render 800x450 diagnostic preview showing posed Volatile, Biter, and FPP arms gripping Machete."""
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 450

    world = bpy.data.worlds.new("PreviewWorld")
    world.color = (0.24, 0.27, 0.31)
    scene.world = world

    # Sun + front-side key/fill lights (camera is at -Y looking toward +Y)
    sdata = bpy.data.lights.new("Sun", type="SUN")
    sdata.energy = 3.2
    sobj = bpy.data.objects.new("Sun", sdata)
    sobj.rotation_euler = (math.radians(48.0), math.radians(15.0), math.radians(-25.0))
    bpy.context.collection.objects.link(sobj)

    for loc, energy, color in [
        ((1.8, -3.5, 2.4), 380.0, (1.0, 0.96, 0.90)),
        ((-2.4, -3.2, 1.8), 260.0, (0.78, 0.88, 1.0)),
    ]:
        ldata = bpy.data.lights.new("Light", type="POINT")
        ldata.energy = energy
        ldata.color = color
        lobj = bpy.data.objects.new("Light", ldata)
        lobj.location = loc
        bpy.context.collection.objects.link(lobj)

    bpy.ops.mesh.primitive_plane_add(size=10.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.active_object
    floor.data.materials.append(make_mat("Floor", (0.18, 0.19, 0.21), 0.9))

    # 1. Volatile in chase_run pose at x = -1.65 (facing camera-right 3/4)
    bpy.ops.import_scene.gltf(filepath=str(OUT_DIR / "dl_zombie_volatile.glb"))
    vol_arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][-1]
    vol_arm.location = (-1.65, 0.0, 0.0)
    vol_arm.rotation_mode = "XYZ"
    vol_arm.rotation_euler = (0.0, 0.0, math.radians(155.0))
    vol_arm.animation_data.action = vol_arm.animation_data.nla_tracks["chase_run"].strips[0].action

    # 2. Biter in shamble pose at x = -0.55
    bpy.ops.import_scene.gltf(filepath=str(OUT_DIR / "dl_zombie_biter.glb"))
    bit_arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][-1]
    bit_arm.location = (-0.55, 0.0, 0.0)
    bit_arm.rotation_mode = "XYZ"
    bit_arm.rotation_euler = (0.0, 0.0, math.radians(170.0))
    bit_arm.animation_data.action = bit_arm.animation_data.nla_tracks["shamble"].strips[0].action

    # 3. Goon in attack_swipe pose at x = +0.55
    bpy.ops.import_scene.gltf(filepath=str(OUT_DIR / "dl_zombie_goon.glb"))
    goon_arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][-1]
    goon_arm.location = (0.55, 0.0, 0.0)
    goon_arm.rotation_mode = "XYZ"
    goon_arm.rotation_euler = (0.0, 0.0, math.radians(-165.0))
    goon_arm.animation_data.action = goon_arm.animation_data.nla_tracks["attack_swipe"].strips[0].action

    # 4. FPP player arms gripping dl_weapon_machete at x = +1.65 (facing camera-left 3/4)
    bpy.ops.import_scene.gltf(filepath=str(OUT_DIR / "dl_player_fpp.glb"))
    fpp_arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][-1]
    fpp_arm.location = (1.65, 0.0, 0.0)
    fpp_arm.rotation_mode = "XYZ"
    fpp_arm.rotation_euler = (0.0, 0.0, math.radians(-145.0))
    fpp_arm.animation_data.action = fpp_arm.animation_data.nla_tracks["idle"].strips[0].action

    bpy.ops.import_scene.gltf(filepath=str(OUT_DIR / "dl_weapon_machete.glb"))
    wpn_obj = [o for o in bpy.context.scene.objects if o.type == "MESH" and "machete" in o.name.lower()][-1]
    bpy.context.view_layer.objects.active = wpn_obj
    bpy.ops.object.select_all(action="DESELECT")
    wpn_obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bpy.context.view_layer.update()
    # Place weapon at WeaponSocket head, matching Godot BoneAttachment3D (+Y along bone, -Z forward)
    pose_ws = fpp_arm.pose.bones["WeaponSocket"]
    ws_world = fpp_arm.matrix_world @ pose_ws.matrix
    # Rotate weapon +Z (shaft) -> bone +Y, and weapon +Y (edge) -> bone -Z (= -90 deg X in bone space)
    wpn_obj.matrix_world = ws_world @ Matrix.Rotation(math.radians(-90.0), 4, "X")

    scene.frame_set(8)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = 35.0
    cam_obj = bpy.data.objects.new("Cam", cam_data)
    cam_obj.location = (0.0, -4.6, 1.32)
    direction = Vector((0.0, 0.0, 0.95)) - cam_obj.location
    cam_obj.rotation_mode = "QUATERNION"
    cam_obj.rotation_quaternion = direction.to_track_quat("-Z", "Y")
    bpy.context.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    preview_path = OUT_DIR / "preview_check.png"
    scene.render.filepath = str(preview_path)
    bpy.ops.render.render(write_still=True)
    print(f"PREVIEW RENDERED: {preview_path}")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0

    manifest: dict = {"zombies": {}, "weapons": {}, "player_fpp": {}}

    # 1. Zombies
    z_anims = zombie_animations()
    for spec in ZOMBIE_SPECS:
        clear_scene()
        mesh_obj = import_obj_facing_pos_y(spec["obj"])
        bones = zombie_bone_defs(mesh_obj)
        arm_obj = build_humanoid_armature(spec["key"], bones)
        method = bind_mesh_to_armature(mesh_obj, arm_obj)
        for aname, kfs in z_anims.items():
            bake_nla_action(arm_obj, aname, kfs)
        dest = OUT_DIR / f"{spec['key']}.glb"
        export_glb(dest)
        manifest["zombies"][spec["key"]] = {
            "glb": f"res://assets_ref/dl_rigged/{spec['key']}.glb",
            "animations": list(z_anims.keys()),
            "skinning": method,
            "forward": "-Z",
            "bones": len(bones),
        }
        print(f"Exported {dest.name}: {dest.stat().st_size // 1024} KB ({method})")

    # 2. FPP Player
    clear_scene()
    arm_fpp, mesh_fpp = build_fpp_player()
    fpp_dest = OUT_DIR / "dl_player_fpp.glb"
    export_glb(fpp_dest)
    fpp_anims = [t.name for t in arm_fpp.animation_data.nla_tracks]
    manifest["player_fpp"] = {
        "glb": "res://assets_ref/dl_rigged/dl_player_fpp.glb",
        "weapon_socket_bone": "WeaponSocket",
        "animations": fpp_anims,
        "forward": "-Z",
        "bones": len(arm_fpp.data.bones),
    }
    print(f"Exported {fpp_dest.name}: {fpp_dest.stat().st_size // 1024} KB (anims={len(fpp_anims)})")

    # 3. Weapons normalized with grip at (0,0,0), shaft +Z (Blender) / +Y (Godot), edge +Y (Blender) / -Z (Godot)
    for spec in WEAPON_SPECS:
        clear_scene()
        w_obj = import_obj_facing_pos_y(spec["obj"])
        co = np.array([v.co[:] for v in w_obj.data.vertices], dtype=np.float32)
        cx = float(0.5 * (co[:, 0].min() + co[:, 0].max()))
        cy = float(0.5 * (co[:, 1].min() + co[:, 1].max()))
        w_obj.location = (-cx, -cy, -spec["grip_z"])
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        dest = OUT_DIR / f"{spec['key']}.glb"
        export_glb(dest)
        manifest["weapons"][spec["key"]] = {
            "glb": f"res://assets_ref/dl_rigged/{spec['key']}.glb",
            "grip_origin": [0.0, 0.0, 0.0],
            "axis": "+Y",
            "edge_forward": "-Z",
        }
        print(f"Exported {dest.name}: {dest.stat().st_size // 1024} KB")

    # 4. Preview render
    render_preview_check(manifest)

    # 5. Manifest
    manifest_path = OUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"WROTE {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
