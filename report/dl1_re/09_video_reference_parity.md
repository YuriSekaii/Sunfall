# Dying Light 1 Video Reference Parity Analysis (`47:24–48:05`)

> Frame-by-frame visual & timing audit of real Dying Light 1 PC gameplay (`47:24–48:05` of `mCnkZ-GYTo8`, extracted into `.gitignore`d `assets_ref/visual_debug/dl1_ref/` via [`tools/extract_ref_frames.py`](../../tools/extract_ref_frames.py)) compared directly against Sunfall `iter_5` and `DW/Data0.pak`.

---

## 1. Armed Idle & Approach Framing (`dl1_overview_01`, `dl1_burst_melee_combo_01` [01–05])
* **Observed in Real DL1**:
  * Center `75%` of the viewport is completely unobstructed.
  * Only the upper `~35–45%` of the melee weapon shaft/blade is visible in the **bottom-right quadrant**, angled diagonally up-left.
  * The **right fist sits at/below the bottom edge** of the screen (`y ~ 0.95..1.05` normalized), and the **left hand is completely below the viewport** during armed idle/walk.
* **Gap in Sunfall `iter_5`**:
  * Right wrist/hand sat slightly too high (`wr_r z=1.31`), and left hand (`wr_l z=1.24`) floated visibly in the lower-left during idle/walk.

## 2. Melee Slash & Counterbalance (`dl1_burst_melee_combo_01` [06–12], `dl1_burst_melee_sprint_01` [06–11])
* **Observed in Real DL1 (`100 ms` steps)**:
  * `+0.0s..+0.2s`: Weapon sweeps rapidly across the lower-center crosshair (`RL` / `LR`) while the **left forearm/hand (with watch)** swings into the lower-left foreground as natural counterbalance.
  * `+0.3s`: Peak contact triggers a dense crimson blood spray (`15–20` varied droplets + mist) from the zombie's upper chest/head, crisp directional head/torso recoil, and **zero** full-body neon-red flash.
  * `+0.4s..+0.7s`: Smooth follow-through and return to low bottom-right guard.
* **Gap in Sunfall `iter_5`**:
  * Left arm stayed mostly passive during swings; blood spray (`10` small boxes) was sparse compared to DL1's dense directional splatter.

## 3. Parkour Mantle / Roof Climb (`dl1_burst_parkour_climb_02` [06–12])
* **Observed in Real DL1 (`100 ms` steps)**:
  * `+0.0s..+0.2s`: Weapon lowers out of frame as player approaches roof lip.
  * `+0.3s..+0.6s`: Both gloved hands plant forward onto the roof surface in the center-lower viewport (`[07–10]`), camera pitches gently toward the ledge lip, then pulls up smoothly without a hard teleport snap.

---

## 4. Concrete Tuning Targets for `iter_6`
1. **Lower FPP Idle Stance (`tools/rig_and_animate_dl.py`)**: Lower `arm_pose_fpp["R"]` (`el_r`, `wr_r`, `fg_r`) by `~0.08m` and `arm_pose_fpp["L"]` (`el_l`, `wr_l`, `fg_l`) by `~0.14m` so idle/walk keeps the left hand below viewport and only the upper pipe/machete/axe enters the bottom-right corner — matching `47:24`.
2. **Active Left-Hand Swing Counterbalance (`tools/rig_and_animate_dl.py`)**: Raise `UpperArm.L` / `Forearm.L` into the lower-left foreground during `swing_right`, `swing_left`, and `heavy_swing` just like `47:48.5–47:49.5`.
3. **Dense Directional Blood Splatter & Recoil (`scripts/player.gd`)**: Increase impact blood burst (`16` varied crimson droplets + mist) biased along the swing/kick direction, with `0.055s` light / `0.085s` heavy hit-stop.
4. **Clean Comparison HUD (`tests/live_visual_harness.gd`)**: Support hiding the oversized `F3` telemetry box during `--visual-capture` (all telemetry still prints in the contact sheet header bar) so visual comparisons against Dying Light 1 are unobstructed.
