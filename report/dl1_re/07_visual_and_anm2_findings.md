# Dying Light 1 Visual, Mesh Skinning, Texture & `ANM2` v42 Audit

> Findings from the live Vulkan 1.4 Forward+ visual capture (`assets_ref/visual_debug/baseline/sheet_01..07.png`) and binary inspection via [`tools/inspect_dl_mesh_anim.py`](../../tools/inspect_dl_mesh_anim.py) on `DW/Data/common_meshes_PC.rpack`, `common_textures_0_pc.rpack`, and `common_anims_PC.rpack`.

---

## 1. Live Vulkan Baseline Visual & Feel Defects (`baseline` Capture)

Inspecting all 7 rendered contact sheets (`29` frames @ `1280×720`) exposed **6 concrete visual/gameplay bugs** that headless tests did not catch:

1. **No FPP Upper-Body / Camera Pitch Coupling (`sheet_01` [2][3][4])**:
   - `_fpp_rig` is parented to `Player` and never pitches with `_pitch`.
   - Looking up (`+40°`) drops hands and weapon below the bottom of the screen.
   - Looking down (`-65°` / `-88°`) places the camera inside `_fpp_rig`'s stationary upper torso/chest, blocking the viewport instead of showing legs/feet.
2. **Slide & Crouch Camera Clipping (`sheet_04` [1][2])**:
   - Dropping `_head.position.y` to `CROUCH_EYE_Y = 0.90` puts the camera inside `_fpp_rig`'s torso/jacket, filling 100% of the screen with backface/clothing geometry during crouch & slide.
3. **Passive Left Hand & Upright Weapon Grip (`sheet_01` [1], `sheet_07` [1][3])**:
   - Left hand hangs flat palm-down in mid-air; right hand holds the Rusty Pipe nearly vertical (`WeaponSocket` pitch/roll) with fingers not curled around the handle.
4. **Subtle / Low-Arc Melee Swings & Neon-Red Hit Flash (`sheet_05` [1][2][3], `sheet_07` [2])**:
   - `swing_right` / `swing_left` arm arcs stay too low in the bottom-right corner and barely cross the crosshair.
   - Hit feedback turns the entire zombie `100%` solid neon red instead of a subtle wound/blood flash + directional stagger.
5. **Vault Detection Missed in Sprint+Jump (`sheet_03` [2][3])**:
   - Sprinting into a `1.2m` obstacle and pressing `Space` entered `AIRBORNE` (`anim=idle`) instead of `LOW_VAULT` (`vault`), jumping over without a vault hand-plant/camera dip.
6. **Grab Camera Clipping & Ambient Interference (`sheet_05` [4][5], `sheet_06` [2][3])**:
   - During zombie grab, the zombie capsule stays too close (`< 0.6m`), clipping the zombie's head/shoulders directly through the camera near plane.

---

## 2. Binary Mesh & Texture Audit (`common_meshes_PC.rpack`, `common_textures_0_pc.rpack`)

### 2.1 `40`-Byte Skinned Vertex Struct (`player_dieselpunk_fpp`, `zombie_man_a`, `zombie_voleteile`, `zombie_goon`)
Inspected `vb` (`part 0xF0`) directly:

| Offset | Size | Type | Meaning |
|---:|---:|---|---|
| `0x00` | `12` | `<3f` | Vertex position `(x, y, z)` |
| `0x0C` | `4` | `4 × uint8` | Bone weights (`sum == 255`, e.g. `d8 1c 0b 00`) |
| `0x10` | `4` | `4 × uint8` | Bone palette indices (e.g. `14 29 15 17`) |
| `0x14` | `4` | `4 × uint8` | Packed normal (`(b - 127.5) / 127.5`) |
| `0x18` | `4` | `<2e` | Half-float UV `(u, v)` |
| `0x1C` | `12` | `4 + 4 + 4` | Packed tangent / binormal / extra (`0000003c ...` on FPP) |

*Note*: `zombie_man_a` `rec[0]` is a non-rendered/shadow/LOD submesh (`uv=(0,0)`), while the rendered parts extracted in [`tools/extract_dl_assets.py`](../../tools/extract_dl_assets.py) (`rec[29], [31], [73], [74]`) all carry valid UVs and `4`-bone skin weights.

### 2.2 Texture Parts (`common_textures_0_pc.rpack`)
* `diesel_punk_hands_dif`, `diesel_punk_torso_dif`, `diesel_punk_legs_dif`, `infected_torso_a_jeans_dif`: `2048×2048`, `fmt=0x13` (`DXT5`), `part 0x20` (`151 B` header), `part 0x21` (`5,592,432 B` full mip chain), `part 0x22` (`5,488 B` tail mip).
* `goon_body_dif`: `2048×2048`, `fmt=0x11` (`DXT1`), `part 0x21` (`2,796,216 B`).
* [`decode_dds_to_png`](../../tools/extract_dl_assets.py) correctly reads `part 0x21` mip0 (`w×h` DXT1/DXT5).

---

## 3. `ANM2` v42 Binary Header Audit (`common_anims_PC.rpack`)

Inspected `m_fpp_kick_forward`, `m_fpp_kick_forward_04b`, `m_fpp_kick_forward_04c` (`part 0x40`):
* `0x00`: Magic `"ANM2"`
* `0x04`: `u16 version = 42` (`0x002a`)
* `0x06`: `u16 flags = 1`
* `0x08`: `u16 frames = 26` (matches `m_fpp_legs.scr` `0..25 @ 40fps = 0.625s`)
* `0x0A`: `u16 bones = 80` (`0x0050`)
* `0x0C`: `u16 sub_ver = 1`
* `0x0E`: `u16 hdr_off = 368` (`0x0170`)
* `0x10`: `u32 payload_size = 10288` (`0x2830`)
* `0x20+`: Bone name CRC/hashes followed by compressed quaternion/translation keyframe bitstream (requires dedicated engine loader RE in `engine_x64_rwdi.dll` if native Techland mocap curves are later decoded).
