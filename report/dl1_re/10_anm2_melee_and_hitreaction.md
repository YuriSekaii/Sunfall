# Dying Light 1 `ANM2` v42 Format, `r_handholder` Grip, 4-Phase Melee Rebound & `HitReactionModule`

> Strictly reverse-engineered from `engine_x64_rwdi.dll`, `gamedll_x64_rwdi.dll`, `DW/Data0.pak`, `DW/Data/common_meshes_PC.rpack`, and `DW/Data/common_anims_PC.rpack`.

---

## 1. `ANM2` v42 Binary Format (`engine_x64_rwdi.dll` `0xef510`, `0xe35d0`, `0xe2640`, `0xe28e0`, `0xe401a`, `0xe3b5f`)

### 1.1 File Header & 64 KB Segment Layout
* **Header (`0x20` bytes)**:
  * `0x00`: `char[4]` `"ANM2"`
  * `0x04`: `u16 version = 42`
  * `0x06`: `u16 flags = 1` (standard compressed skeletal clip)
  * `0x08`: `u16 total_frames`
  * `0x0A`: `u16 num_bones`
  * `0x0C`: `u16 num_segs` (each segment occupies `0x10000` bytes starting at `hdr_off + seg_i * 0x10000`)
  * `0x0E`: `u16 hdr_off`
  * `0x10`: `u32 payload_size`
* **Bone Hash Table (`0x20 .. 0x20 + num_bones * 4`)**:
  * `u32[num_bones]` hashes computed with Chrome Engine's exact lowercase polynomial hash (`h * 41 + c`):
    * `dl_bone_hash(name)`: `h = 0; for c in name.lower().encode('ascii'): h = (h * 41 + c) & 0xFFFFFFFF`
    * Verified values: `bip01 = 0x10f2dc54`, `hspine = 0xe204eae7`, `spine1 = 0x2d726748`, `r_handholder = 0x0d672d62`, `attackhelper = 0x9aab60f0`, `handhelper = 0x5a736f73`.
* **Segment Frame Counts (`0x20 + num_bones * 4`)**: `u16[num_segs]` (`sf`). Each segment has `nchunks = (sf + 14) // 15` 15-frame chunks.

### 1.2 Segment Chunk 0 (Metadata, QuantBlocks & Channel Flags)
At `seg_off = hdr_off + seg_i * 0x10000`:
* `chunk_offs = u16[nchunks + 2]` (16-byte unit offsets relative to `seg_off`).
* `c0 = seg_off + chunk_offs[0] * 16`:
  * `<5H`: `num_const, num_anim, total_tracks (= num_bones * 9), quant_bytes, raw_flag`
  * `q_off = (c0 + 0x19) & ~0xF` (`quant_bytes // 64` `QuantBlock8` structs: `float bias[8]` + `float scale[8]`)
  * `c_off = (q_off + quant_bytes + 0xF) & ~0xF` (`float[num_const]` constant channel values)
  * `f_off = c_off + num_const * 4` (`uint8[num_bones]` per-bone channel flags)
* **Per-Bone Channel Flags (`0xe35d0`)**:
  * Bits `0..5`: `rx, ry, rz, px, py, pz`; Bit `6`: `sx, sy, sz` (all 3 scale channels share bit 6).
  * **Bit `== 1` -> CONSTANT** (read from `const_floats`); **Bit `== 0` -> ANIMATED** (read from `QuantBlock8` + SIMD chunk).

### 1.3 8-Lane Bit-Unpacker (`0xe2640`), 2nd-Order DPCM (`0xe28e0`) & Quaternion Reconstruction (`0xe3b5f`)
* Each 15-frame chunk (`ch_start = seg_off + chunk_offs[1 + ch_i] * 16`) encodes `ngroups = (num_anim + 7) // 8` groups of 8 tracks across 16 sample slots (`0..15`):
  * First 16 bytes (`<8H`): 16 × 4-bit widths (`hi` nibbles = slots `0..7`, `lo` nibbles = slots `8..15`; nibble `15` means `16` bits).
  * Packed signed bit-lanes follow (`bit_cursor = 8`, 8 lanes of width `d` bits per frame slot).
* **2nd-Order DPCM (`0xe28e0`)**:
  * `v[1] = wrap16(v[0] + d[1])`
  * `v[f] = wrap16(clamp16(2 * v[f-1] - v[f-2]) + d[f])` (`packssdw` saturation before `paddw` wrap).
* **Dequantization (`0xe401a`)**: `val = int16_sample * q_scale[ti] + q_bias[ti]`.
* **Inverse-Stereographic Quaternion (`0xe3b5f`, `0xe3c41`)**:
  * Given 3 rotation channels `(vx, vy, vz)` and `s2 = vx² + vy² + vz²`, `inv = 1 / (1 + s2)`:
    * Chrome Engine (row-vector): `(2*vx*inv, 2*vy*inv, 2*vz*inv, -(1 - s2)*inv)`
    * glTF 2.0 / Godot (column-vector): **`(2*vx*inv, 2*vy*inv, 2*vz*inv, +(1 - s2)*inv)`** (verified against `bip01` bind matrix `[[0,0,-1],[0,1,0],[1,0,0]]`).

---

## 2. `player_dieselpunk_fpp` Skeleton & `2FZn` Per-Draw Bone Palettes (`common_meshes_PC.rpack`)

* **90-Node Table (`part 0x10`, `node_cnt = u32[0x64]`, base `0xA0`, stride `0xD0`)**:
  * `+0x00`: local `3×4` matrix (`12f`)
  * `+0x30`: inverse-bind `3×4` matrix (`12f`; `max |W[i] * invBind[i] - I| = 0.000001` across all 81 skeleton bones)
  * `+0x78`: `u64` 1-based offset to null-terminated ASCII bone name
  * `+0xC6`: `i16` parent node index (`-1` for `bip01`)
* **`2FZn` Sub-Draw Bone Palettes**:
  * Vertex `b16..19` indices are **local indices into each sub-draw's `u16` bone palette** (e.g., `2FZn[0]` hands has `nsub=3` draw calls with `42`, `3`, and `3` palette entries; `2FZn[1]` legs has `13` entries), NOT direct global `0..80` indices.

---

## 3. `r_handholder` Weapon Mount, 4-Phase Melee Rebound (`m_fpp_stick.scr`) & `HitReactionModule`

* **Weapon Grip (`gamedll_x64_rwdi.dll` `0xbfd74f`, `0xd05fd0`, `0xdcae2f`)**:
  * Weapons attach to **`r_handholder`** (child of `r_hand`, local offset `(+0.100, 0.000, -0.025)` in DL1 coords).
* **4-Phase Melee State Machine (`m_fpp_stick.scr`)**:
  1. `FPP_Stick_Melee_Attack_RL_Begin` (`M_FPP_Stick_Swings.anm2`, `0..11 @ 110fps`, `0.100s`, blend `0.10s`)
  2. `FPP_Stick_Melee_Attack_RL_Empty` (`M_FPP_Stick_Swings_Long.anm2`, `66..84 @ 30fps`, `0.600s`, blend `0.10s`, `START_GIVE_DAMAGE @ 2.8f`, `END_GIVE_DAMAGE @ 10f`) / `LR_Empty` (`43..58 @ 30fps`, `0.500s`)
  3. **On Impact**: `FPP_Stick_Melee_Attack_RL_Hit_Middle` (`M_FPP_Stick_HitShort.anm2`, `36..52 @ 30fps`, blend `0.03s`, `END_GIVE_DAMAGE @ 2f`, `END_ANIMATION @ 13f`) / `LR_Hit_Middle` (`0..16 @ 30fps`, blend `0.05s`) + `HitPauseTimeMul` freeze.
  4. **On Miss**: `FPP_Stick_Melee_Attack_RL_Empty_Rest` (`M_FPP_Stick_Swings.anm2`, `175..217 @ 20fps`, blend `0.10s`, `END_ANIMATION @ 20f`) / `LR_Empty_Rest` (`220..262 @ 20fps`).
* **Zombie Hit Reactions (`HitReactionModule`, `m_zombie_common.scr`, `zombie_data_params.scr`)**:
  * Directional/part/severity clips with `0.09s` blend: `m_zombie_hitreaction_blunt_light_torso_left_01` / `right_01`, `m_zombie_hitreaction_blunt_medium_head_left_01` / `right_01`, `m_zombie_hitreaction_blunt_heavy_torso_left_01` / `right_01`.

---

## 4. Saved Handoff / Next-Session Visual Polish

Observed in live Vulkan captures (`assets_ref/visual_debug/playtest/playtest_melee_slowmo.mp4`, `playtest_kick_physics_slowmo.mp4`, `playtest_parkour_30fps.mp4`):
1. **Left forearm stretch during melee swings (`playtest_melee_slowmo.mp4` 00:05–00:14)**: Inspect `l_foretwist`/`l_foretwist1`/`l_hand` local translation and quaternion tracks in `tools/extract_dl_anm2_glb.py` (compare `m_fpp_stick_swings_long.anm2` against `player_dieselpunk_fpp` bind pose).
2. **Zombie facing & glTF UV V-flip (`playtest_melee_slowmo.mp4` 00:04–00:14)**: Zombie faced away with `_dl_rig.rotation.y = PI` (verify zombie forward axis vs `-Z`) and `TEXCOORD_0` needs `v` vs `1.0 - v` check (plus verify `dl_weapon_pipe` angle in `r_handholder`).
3. **REA (`D:\Program File\rea`) runtime note**: Requires Node.js `22.x (>=22.23.4)`, `24.x (>=24.22.1)`, or `>=26.12.1` (machine currently has `24.14.0`).
