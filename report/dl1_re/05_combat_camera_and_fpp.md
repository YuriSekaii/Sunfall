# Dying Light 1 Combat, Charge, Stomp, Grab, Camera & FPP RE Spec

> Strictly derived from `gamedll_x64_rwdi.dll` disassembly (`combat.asm`, `grab_stomp.asm`, `camera_fpp.asm`, `hook_slide_damp.asm`, `melee_edge_tick.asm`, and `PlayerParams` `0x00c59920`). All RVAs, `.rdata` strings, IEEE-754 literals, and `PlayerParams` IDs were directly observed; external `.scr` script defaults are marked `[STATIC LIMIT]`.

---

## 1. `WeaponMeleeController` (`0x1732b40`) — Swings, Kicks, Dropkick, Tackle & Ground Pound

### 1.1 Primary Virtual Slots & Tick Chain
* `slot[16]=0x00db23a0 -> 0x00dc3ce0` (`130 bytes`): sequences per-frame melee tick (`0x00dbe400 -> 0x00dc1ae0 -> 0x00db4510 -> 0x00dc7170`).
* `slot[18]=0x00db18c0`: enter/init helper; clears active flags on `[PlayerDI + 0xb98]`, registers `"Melee_Shockwave"`, `"Melee_GroundPoundLvl1"`, `"Melee_GroundPoundLvl2"`, `"Melee_FuryRam"`, and stores an angle pair from the active weapon (`vslot[222]`/`[223]`), falling back to **`60.0f`** and **`-45.0f`** when no weapon is present (`0x00db1c6d`, `0x00db1cbd`).
* `slot[22]=0x00db3db0`: secondary melee update (`0.7f`, `1.0f`, calls `0x00dc70c0`, `0x00dc6c80`).
* `slot[25]=0x00dc8000`: debug dump appending `", HIT !!!!"` when `[r12 + 0x278] != -1`.

### 1.2 Melee Swing Sequences (`0x00db7d60`)
Constructs combo / directional animation & strike keys:
* Standard: `"melee_attack_"`, `"rl_"`, `"lr_"`, `"ud_"`, `"d_ch_"`, `"l_lr_"`, `"Fury_"`
* Charged: `"ch_rl_"`, `"ch_lr_"`, `"l_ch_rl_"`, `"l_ch_lr_"`
* Akimbo / unarmed: `"melee_attack_akimbo_"`, `"empty"`
* Hook aim hookup (`0x00db7435`): `"Melee_RopeThrow_Aim"`, `"melee_throw_aim"`.

### 1.3 Kicks, Dropkick, Slide-Kick & Tackle (`0x00cf97f0`, `0x00cfbf50`, `0x00cfc900`, `0x00cfe531`)
* **13-State Kick / Slide / Tackle Switch (`0x00cf97f0`, `0x00cfbf50`)**:
  `"None"`, `"Firearm_Melee"`, `"Kick"` (`"Melee_Leg"` vs `"Melee_Attack"` in `0x00cfc900`), `"KickMedium"` / `"KickMedium_Empty"`, `"KickLow"`, **`"KickAir"`** *(Dropkick)*, `"KickWrestling"`, `"KickWrestlingStandUp"`, `"KickWrestlingStandUpFast"`, `"SlideBegin"`, `"SlideLoop"` / `"SlideLoopRight"` (`0x00cfc4fd` yaw delta > **`5.0f`**), `"SlideKick"`, `"SlideEnd"`, `"Tackle"`.
* **Melee / Leg Sweep Hitbox Resolver (`0x00cfe531`)**:
  * Evaluates `±60.0°` arc rays (`0x00cfe5ab`, `0x00cfe5d6`), builds hit packet with **`500.0f`**, **`80.0f`**, **`10.0f`**, and iterates candidate targets (`"hit elem"`, `"hit point"`) using step floats **`0.05f`** (`0x00cfe726`) and **`0.03f`** (`0x00cfe731`).
* **Fists / Aim Target / Tackle Probe (`0x00dc497d`)**:
  Populates `"_m_AimTargetPos_"`, `"_m_TacklePos_"`, and `"_PlayerFistsRange_"` using constants **`1.5f`**, **`0.3f`**, **`20.0f`**, **`10.0f`**, and **`1000.0f`**.

### 1.4 Ground Pound (`0x00db3fbf`, `0x00dc5a6a`)
* **Height Gate (`0x00db3fbf .. 0x00db40fa`)**: checks `[PlayerDI + 0x1380] + 0x20` stamina threshold, verifies airborne state (`0x00dc1bd0 == 0xf`), and queries **`GroundPoundMinHeight` (`0x225` @ `0x00db40e3`, `0x00dbb1df`)**.
* **AoE Script Params (`0x00dc5a6a`)**: publishes `"ground_pound_center"`, `"ground_pound_radius"`, `"ground_pound_minradius"` alongside `Melee_GroundPoundLvl1` / `Melee_GroundPoundLvl2` (`0x00db1ac5`, `0x00db1b38`).

*(Related `PlayerParams` IDs in `0x00c59920`: `KickStaminaUsage` `0x337`, `AirKickStaminaUsage` `0x338`, `WrestlingKickStaminaUsage` `0x339`, `GroundPoundStaminaUsage` `0x345`, `GroundPoundCooldown` `0x224`, `GroundPoundRangeMul` `0x222`, `GroundPoundDamageMul` `0x223`, `MeeleSwingSpeedMul` `0x242`, `BestTargetMeleeRange` `0x2b8`, `RangeMeleeMul` `0x2b4`. `[STATIC LIMIT]`: Exact `.scr` parameter values are outside the DLL.)*

---

## 2. `ChargeController` (`0x172a910`) & `StompFinisherController` (`0x17310c8`)

### 2.1 `ChargeController` (Bull-Rush / Charge Ability)
* `slot[16]=0x00cf6990`, `slot[18]=0x00cf6670`, `slot[19]=0x00cf66c0`, helpers `0x00cf6b60`, `0x00cf6f1a`.
* Animation/event keys (`0x00cf6b60`): `"Abilites_Charge_Begin"`, `"Abilites_Charge_Hit"`, `"Abilites_Charge_End"`.
* Impact helper `0x00cf6f1a`: uses `0.25f`, `-1.0f`, `2.0f`. (No `PlayerParams` read was observed inside `ChargeController`; `FighterXPSkillCharge` `0x19a` is only a registered ID.)

### 2.2 `StompFinisherController`
* `slot[16]=0x00d8ace0`, `slot[18]=0x00d8a990`, `slot[22]=0x00d8c930`, `slot[25]=0x00d8cf40`, core state step `0x00d8ad64` (`4,007 bytes`).
* **State Machine (`0x00d8ae22`)**: 6-case jump table (`0x00d8bd6c`) advancing timed finisher phases against `[rdi + 0x78]` schedule entries.
* **Observed Physics / Trace & XP Constants (`0x00d8ad64`)**: **`40.0f`**, **`45.0f`**, **`1000.0f`**, **`0.5f`**, **`5.0f`**, calling trace/hit `0x00ba9c20`, awarding `"Momentum"` / XP `FighterXPSkillFootballKick` (`0x19f` @ `0x00d8b043`, `0x00d8b532`, `0x00d8b7d5`, `0x00d8bb4c`), plus `StompLevel` (`0x0c1`), `StompStaminaUsage` (`0x33f`), `StompBlocksStaminaRecovery` (`0x3f5`).

---

## 3. `GrabController` (`0x172bfd0`) — Enemy Grabs & Struggle Breakouts

* `slot[16]=0x00d21a70`, `slot[18]=0x00d22930` (`"AwayFromAIHelper"`, `"fake_zombie_helper"`), `slot[25]=0x00d29b50`.
* **14-State Grab Enum (`0x00d29b50`)**:
  `"None"`, `"Grab"`, `"Clench"`, `"LegGrab"`, `"JumpAttack"`, `"Scalping"`, `"FinisherBack"`, `"NageWazaBack"`, `"NageWazaFront"`, `"NageWazaLeft"`, `"NageWazaRight"`, `"GrabLeft"`, `"VolatileGrab"`, `"GrabWeak"`.
* `PlayerParams` IDs (`0x00c59920`): `EnemyGrabFightTapVal` (`0x14b`), `DefaultGrabFightTapMul` (`0x14c`), `FastGrabBreakLevel` (`0x356`), `FastGrabBreakCooldown` (`0x357`), `ZombieGrabStaminaUsage` (`0x33d`), `ZombieLegGrabStaminaUsage` (`0x33e`). `[STATIC LIMIT]`: Exact tap counts/thresholds load from `.scr` scripts.

---

## 4. `LookController` (`0x172da70`), `CameraFPPDI` (`0x147f680`) & `PlayerFppVis` (`0x17044a0`)

### 4.1 `LookController`
* Primary slots: `slot[0]=0x00d40b00`, `slot[16]=0x00d40ce0`, `slot[18]=0x00d41ca0`; `VT[0x18]`: `slot[2]=0x00d46030`, `slot[10]=0x00d45140`, `slot[11]=0x00d454f0`.
* **Slew / Damped Look Blend (`0x00d43a14`, `3,637 bytes`)**:
  * Combines base `[PlayerDI + 0x1174/+0x1178]` with active subcontroller offsets `[PlayerDI + 0xc18] + 0x58/+0x5c` (`0x00da7010`) and `[PlayerDI + 0xc30] + 0x94/+0x98` (`0x00d9e690`).
  * Uses two blend branches, each computing `g = f(x·π)` through CRT thunk `0x134eb3e` (single-arg double; likely `cos`, not resolved statically):
    * Branch A (`[PlayerDI + 0x2300]`): weight `(0.25 - g*0.25) * min(60.0f / [PlayerDI + 0x2310], 1.0f)`
    * Branch B (`[PlayerDI + 0x22d0]`): weight `(0.3 - g*0.3) * min(40.0f / [PlayerDI + 0x22e0], 1.0f)`
  * Also uses `0.7f`, `0.5f`, `5.0f`, `2.0f`, `0.1f`, `0.07f`, `2.32558f`, plus `PlayerParams` `LookSpeedSprintMod` (`0x264` @ `0x00d41082`), `TackleLookMaxSpeed` (`0x278` @ `0x00d421eb`), `LookRollFactor` (`0x262`), mouse/pad speed & accel (`0x24a..0x261`).

### 4.2 `CameraFPPDI` & `EyeCamera` Bone Driver (`0x00d0510c`, `0x00d06050`, `0x00d06560`)
* `CameraFPPDI::VT[0]` slots (`0x00343140`, `0x00341ba0`); `[STATIC LIMIT]`: higher-level camera/FOV blending delegates across `VT[0x10]` (`0x147eef0`, `241` slots) and `PlayerParams` (`CameraDefaultFOV` `0x30b`, `FovSprintModif` `0x331`, `FovAmortizerModif` `0x332`, `OnHitCameraShakeFactor` `0x066`, `HeadBobFactor` `0x36a`), whose numeric defaults live in `.scr` files.
* **`EyeCamera` Driven Pitch/Yaw/Roll (`0x00d0510c`, `0x00d06050`, `0x00d06560`)**:
  * Queries `"EyeCamera"` bone transform (`0x00d060df`) and normalizes the offset vector. Yaw = `0x134eb32(x, z) * 57.2958` (2-arg CRT thunk, likely `atan2`, at `0x00d06279`). Vertical angle = `±90.0°` when the horizontal length is exactly `0` (`0x00d0629f`, `0x00d062aa`), else `0x134eb38(y / len) * 57.2958` (`0x00d062c7`).
  * Scales by `0.25f` (`0x00d061c2`), `114.592f` (`0x00d062e6`), `0.00872665f` (`0x00d062fa`), `0.888889f` (`0x00d06356`), `0.5f`, then calls `0x00d06560` (literals `1.25f`, `0.5f`, `5.0f`, `0.02f`, `2.5f`, `3.0f`, `0.1f`, `2.0f`).

### 4.3 `PlayerFppVis` (`0x17044a0`, `0x00bfd2a0`, `0x00c023e0`, `0x00c129a0`, `0x00c14680`)
* **Rig / Bone Hierarchy Bound in `0x00bfd2a0` & `0x00c023e0`**:
  `"Spine"`, `"Spine1"`, `"Spine2"`, `"Spine3"`, `"HSpine1"`, `"EyeCamera"` (`"eyecamera"` at `0x00c023e0`), `"RefCamera"`, `"Clavicle"`, `"Upperarm"`, `"Forearm"`, `"Hand"`, `"HandHolder"`, `"Foretwist"`, `"Foretwist1"`.
* **Weapon Stance & Recoil Animation Dispatch (`0x00c129a0`, `0x00c14680`, `0x00c133b0`)**:
  * Manages `"Holder"`, `"Stand"`, `"Aim_Stand"`, `"Shot"`, `"Aim_Shot"`, `"ShotRecoil"`, `"Aim_ShotRecoil"`.
  * Uses recoil/blend timings `0.1f`, `0.25f`, `20.0f`, `0.05f` (`0x00c14680`) and reads `JumpSoundProb` (`0x02a` @ `0x00c13500`).
