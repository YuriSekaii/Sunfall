# Dying Light 1 Movement, Dodge, Crouch, Slide, Fitness & Stamina RE Spec

> Strictly derived from `gamedll_x64_rwdi.dll` disassembly (`assets_ref/dl_re_raw/disasm/move_part1.asm`, `move_part2.asm`, `move_part3.asm`, `melee_edge_tick.asm`, `hook_slide_damp.asm`) and `PlayerParams` jump table (`0x00c59920`). Every RVA, IEEE-754 literal, branch condition, and `PlayerParams` ID was directly observed; external script defaults live in `.scr` data files (`[STATIC LIMIT]`).

---

## 1. Architectural Findings (Important Correction vs Class Names)

1. **`DodgeModule` (`0x144cea8`) is AI Zombie Dodge, NOT Player Dodge.**
   RTTI base chain: `DodgeModule -> AIModule -> GameObject`. It governs enemy dodge probability (`m_DodgeProbability`).
   **Player Dodge** is implemented inside `MoveController` (`0x00d470b0`, `0x00d4e7e0`, `0x00d50760`, `0x00d52188`, `0x00d4fedb`).
2. **Stamina vs. Fitness Separation:**
   Dying Light splits physical exertion into two separate modules on `PlayerDI`:
   * **Fitness** (`PlayerFitnessModule` at `[PlayerDI + 0x1348]`): governs **sprinting, climbing, and traversal exhaustion** (`InfiniteFitness` `0x3c9`).
   * **Stamina** (`PlayerStaminaModule` at `[PlayerDI + 0x1390]`): governs **melee swings, charged attacks, kicks, tackles, slides, vaults, dodges, and stomps** (`InfiniteStamina` `0x3ca`).
3. **Slide & Tackle Live Across `MoveController` + `DefensiveController`:**
   `DefensiveController` (`[PlayerDI + 0xc98]`, `slot[18]` at `0x00cf9fb0`) and animation/state resolver `0x00cf97f0` / `0x00cfbf50` handle `"SlideBegin"`, `"SlideLoop"`, `"SlideLoopRight"`, `"SlideKick"`, `"SlideEnd"`, `"Tackle"`, `"Kick"`, `"KickMedium"`, `"KickLow"`, `"KickAir"`, and `"KickWrestling*"`.

---

## 2. `MoveController` (`0x172e068`) — Locomotion, Sprint, Air & Slope Math

### 2.1 Primary Slots & Helpers
* `slot[16]` (`0x00d485b0`): per-frame movement tick (reads hold duration against `MaxJumpHoldTimeSeconds` `0x2a4` at `0x00d487b0`, checks slide/defensive state `[PlayerDI + 0xc98] -> +0x38 == 6` at `0x00d48a9b`).
* `slot[18]` (`0x00d4a330`): enter/setup helper; binds `"Melee_CrowdBump"` (`0x00d4a330`), calls `0x00d58620`, `0x00d52c20`, and player dodge selector `0x00d50760`.
* `VT[0x18]::slot[3]` (`0x00d4d3b0`): nearby call sites read `MoveSprintSpeed` (`0x271` at `0x00d4d4f6` & `0x00d4d5ae`) and `MoveOverSpeedMaxSpeed` (`0x272` at `0x00d4d558`) (function extent of `0x00d4d3b0` not confirmed to cover them).
* Acceleration/deceleration call sites: `AimAcceleration` (`0x2ab` @ `0x00d4c917`, inside `0x00d4c820`), `MoveAcceleration` (`0x2a6` @ `0x00d4cabd`), `MoveOverSpeedWalkDeceleration` (`0x274` @ `0x00d4cbbd`, inside `0x00d4caf0`), `MoveDeceleration` (`0x2a8` @ `0x00d4cd39`).
* `0x00d4979c`: core directional speed/stance synthesizer.
* `0x00d4e7e0`: jump/air/dodge impulse & stun/long-jump resolver.
* `0x00d50c90`: slope slide-down calculator.

### 2.2 Directional Speed & Stance Branching (`0x00d4979c`)
* **Forward vs Strafe/Back selection**: compares `abs(move_x) >= move_z` to branch between strafe speed tables and forward/backward speed tables.
* **Parameter IDs queried via `0x00c594d0`**:
  * Standing walk/run: `MoveForwardMinSpeed` (`0x26e` @ `0x00d49c3a`), `MoveBackwardMinSpeed` (`0x26c` @ `0x00d49f64`), `MoveBackwardMaxSpeed` (`0x26b` @ `0x00d49fde`), `MoveStrafeMinSpeed` (`0x270` @ `0x00d499ef`), `MoveStrafeMaxSpeed` (`0x26f` @ `0x00d49a69`), `MoveForwardMaxSpeed` (`0x26d`), `MoveSprintSpeed` (`0x271`).
  * Aiming (`[PlayerDI + 0xc18]`): `AimForwardMinSpeed` (`0x287` @ `0x00d49b42`), `AimBackwardMinSpeed` (`0x285` @ `0x00d49ea4`), `AimStrafeMinSpeed` (`0x289` @ `0x00d49905`).
  * Charge-backpedal: `ChargeMoveBackwardMinSpeed` (`0x26a` @ `0x00d49d7a`).
  * Carrying objects: `MoveWhenCarryMaxSpeedFactor` (`0x275` @ `0x00d4a06e`), `MoveWhenCarryMinSpeedFactor` (`0x276` @ `0x00d4a0b9`).
  * Shield raised: `ShieldMaxSpeedFactor` (`0x208` @ `0x00d4a167`), `ShieldMinSpeedFactor` (`0x209` @ `0x00d4a1b2`).
* **Sprint Fitness Gate** (`[PlayerDI + 0x1348]`):
  Sprint speed boost applies only when:
  1. Exhaustion flag `[fitness + 0x20] == 0`, AND
  2. Current fitness `*(float*)(fitness + 0x10) > 0.06f`.
* `[STATIC LIMIT]`: Exact numeric speed/acceleration values (m/s and m/s^2) in `PlayerParams` slots come from external `.scr` variable tables, not literals in `gamedll_x64_rwdi.dll`. Note also that active debuffs on `[PlayerDI + 0x2a88]` multiply IDs `[0x269 .. 0x292]` by `0.8f` inside `0x00c594d0`.

### 2.3 Jump & Air Control (`0x00d4e7e0`, `0x00d4a7d6`)
* **Air steering**: scaled by `LogicJumpAirControllFactor` (`0x0ca` @ `0x00d4e21c`) and strafe penalty without fitness `StrafeJumpingNoFitnessFactor` (`0x1e6` @ `0x00d4e090`).
* **Long Jump / Jump Extender multipliers**:
  * `LongJumpSpeedMul` (`0x050` @ `0x00d4eaef`)
  * `LongJumpHeightMul` (`0x051` @ `0x00d4eb7e`)
  * `JumpExtenderHeightMul` (`0x04f` @ `0x00d4ebd8`)
* **Jump-Over-Enemy Stun**: evaluates `JumpOverZombieStunChance` (`0x219` @ `0x00d4e512`).
* **Crouch Fall Damping window (`0x00d4a7d6`)**: reads `CrouchDampingWindowTime` (`0x021` @ `0x00d4a964`) when crouch/roll input triggers near landing (`0x00d4a7eb..0x00d4a976`).

### 2.4 Slope Slide-Down (`0x00d50c90` @ `0x00d50d91`)
Directly observed IEEE-754 float constants compute slide-down factor from slope angle (`slope_deg`):
* If `slope <= 0.0f` -> returns **`0.01f`**.
* If `slope >= 45.0f` -> returns **`0.8f`**.
* Otherwise linear ramp: **`slope * 0.0175556f + 0.01f`** (where `0.8 - 0.01 = 0.79`, and `0.79 / 45.0 = 0.01755555...`).

---

## 3. Player Dodge (`MoveController` `0x00d4fedb`, `0x00d50760`, `0x00d52188`)

| Property / Constant | Observed Evidence (RVA / Literal) | Notes |
|---|---|---|
| Impulse magnitude | **`6.0f`** (`0x00d522cd`, `0x00d522db`) + `DodgeSpeed` (`0x1e4` @ `0x00d4e118`) | Horizontal burst velocity; scaled by `DodgeJumpHeight` (`0x1e3` @ `0x00d4ffd6`) on dodge-jump |
| Min interval / cooldown | **`0.15f`** (`0x00d52204`) + param `DodgeJumpCooldown` (`0x1e5`) | Prevents dodge spam below `150 ms` |
| Lockout / blend windows | **`0.5f`** look/move lock (`0x00d4edbd`), **`0.2f`** literal (`0x00d50760`), **`0.1f`** & **`-35.0f`** literals (`0x00d4fedb`) | Direction variants resolved via `[PlayerDI + 0x11ec]` yaw |
| Anim state prefix & keys | `"FPP_Unarmed_"`, `"TPP_Unarmed_"`, `"DodgeBack"`, `"DodgeRight"` (`0x00d50760`) | Left/Right/Back dodge animations |
| XP hook | `RunnerXPDodgedAttack` (`0x192` @ `0x00d52eed` via `0x00bb7220`) | Awards `"Momentum"` / Runner XP when dodging enemy attacks |

---

## 4. Crouch Clearance & `PlayerDuckModule` (`0x00cde22e`, `0x00cde585`)

Mounted at `[PlayerDI + 0x13c8]`. Directly observed physics capsule sweep parameters:
* **Swept capsule geometry**: radius **`0.3 m`**, height/extent **`2 * 0.75 m = 1.50 m`** (`duck_capsule_down`, `duck_capsule_up`, `duck_capsule_line`).
* **Physics collision mask**: **`0xffc24307`**.
* **Stance lock coupling**: checks `[PlayerDI + 0xc60]` (`0x00cde298`, `0x00ce0e69`) to block uncrouching when overhead `duck_capsule_up` hits world geometry.

---

## 5. Slide & Tackle (`DefensiveController` & `0x00cf97f0`, `0x00cfbf50`)

* `DefensiveController::slot[18]` (`0x00cf9fb0`) & `MoveController` checks `[PlayerDI + 0xc98] -> +0x38 == 6` (`0x00d48a9b`).
* State-to-animation/controller string dispatch (`0x00cf97f0`, `0x00cfbf50`, `0x00cfc900`):
  * Slide states: `"SlideBegin"`, `"SlideLoop"`, `"SlideLoopRight"` (at `0x00cfc4fd` the result of `0x112ddb0(PlayerDI::vslot[233] vector, yaw-direction from [PlayerDI + 0x11ec])` is compared to **`5.0f`**: `> 5.0` -> `"SlideLoopRight"`, else `"SlideLoop"`; the unit of that value is not resolved statically), `"SlideKick"`, `"SlideEnd"`.
  * Tackle state: `"Tackle"`. (`TackleLookMaxSpeed` `0x278` is read at `0x00d421eb` inside `0x00d42170`, a separate look-band function.)
* **Stamina lookups**:
  * `SlideStaminaUsage` (`0x341` @ `0x00d0148a`)
  * `SlideKickStaminaUsage` (`0x340` @ `0x00cffe64`, `0x00cfff3a`)
  * Related `PlayerParams` IDs registered in `0x00c59920`: `SlideCooldown` (`0x346`), `SlideDamageFactor` (`0x20f`), `TackleCoolDown` (`0x312`), `TackleStaminaUse` (`0x318`), `TackleSprintMinDuration` (`0x226`), `RunnerXPSkillSlide` (`0x185`), `RunnerXPSkillTackle` (`0x186`).

---

## 6. `PlayerFitnessModule` (`0x1728600`, `[PlayerDI + 0x1348]`)

Key functions: `slot[1]` = `0x00ce12e0`, update helpers `0x00ce139c`, `0x00ce1b82`, `0x00ce1e80`.

1. **Exhaustion & Smooth Speed-Scaling Curve (`0x00ce1521 .. 0x00ce15f1`)**:
   * Exhaustion state byte at `[fitness + 0x20]` (`1` = exhausted; locks sprint until recovered above threshold, gated in `0x00d4979c` by `cur > 0.06f` and exhaustion == 0).
   * Current fitness stored at `[fitness + 0x10]`.
   * **Smooth fitness scale curve**:
     $$\text{factor} = 0.8 + 0.2 \cdot \operatorname{clamp}\!\left(\frac{\text{cur} - 0.2 \cdot \text{max}}{0.3 \cdot \text{max}},\, 0.0,\, 1.0\right)$$
     *(Linear ramp from `0.8` at `<=20%` fitness up to `1.0` at `>=50%` fitness.)*
2. **Dynamic Drain / Regen Modifiers (`0x00ce139c .. 0x00ce1b82`)**:
   * **Moving / Crouching multiplier**: multiplies by **`0.75f`** if moving (`speed_sq > 0.2f`) or crouching.
   * **Camera / breath oscillation term**: `sin(t * 300 deg) * 0.9 + 1.0`.
   * **`PlayerParams` lookups**: `FitnessTimeToRegenerate` (`0x1f7` @ `0x00ce14ad`, `0x00ce1513`, `0x00ce1d14`), `FitnessRegenerationOnHalfHealth` (`0x1fb` @ `0x00ce1766`), `FitnessRegenerationFromDuck` (`0x1fc` @ `0x00ce17db`), plus registered IDs `MaxFitness` (`0x1f2`), `FitnessRegenRate` (`0x1f3`), `FitnessCriticalLevel` (`0x294`), `InfiniteFitness` (`0x3c9`).

---

## 7. `PlayerStaminaModule` (`0x1729f88`, `[PlayerDI + 0x1390]`)

Key functions: `slot[1]` = `0x00cf0500`, helpers `0x00cf0560`, `0x00cf0bd4`, `0x00cf0ff0`, `0x00cf13e3`.

* **Regeneration Timing Lookups**:
  * Normal regen delay: `StaminaTimeToRegenerate` (`0x1fd` @ `0x00cf0f9e`).
  * Empty-pool regen delay: `StaminaTimeToRegenerateOnEmpty` (`0x1fe` @ `0x00cf0d78`).
  * Regen rate: `StaminaRegeneration` (`0x2ba` @ `0x00cf13e3`).
* **Controller / Action Recovery Blocks**:
  Reads active climb/combat controller `[PlayerDI + 0xcd8]` (`0x00cf0c06`, `0x00cf1380`) and modifier container `[PlayerDI + 0x2a88]` (`0x00cf0581`). Dedicated boolean gating parameters in `0x00c59920`: `KickBlockStaminaRecovery` (`0x3f0`), `AirKickBlockStaminaRecovery` (`0x3f1`), `TackleBlockStaminaRecovery` (`0x3f2`), `SlideBlockStaminaRecovery` (`0x3f3`), `GrabsBlocksStaminaRecovery` (`0x3f4`), `StompBlocksStaminaRecovery` (`0x3f5`), `LowStaminaAttackEnabled` (`0x3e0`), `StaminaCanFullyDrain` (`0x385`), `InfiniteStamina` (`0x3ca`).
* `[STATIC LIMIT]`: Exact stamina cost per swing/kick/dodge and numeric regeneration per second are loaded into `PlayerParams` from external `.scr` configuration tables.
