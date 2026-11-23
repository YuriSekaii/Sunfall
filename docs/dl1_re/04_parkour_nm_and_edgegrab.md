# Dying Light 1 Parkour, Natural Movement, EdgeGrab, Fall/Landing & Grappling Hook RE Spec

> Strictly derived from `gamedll_x64_rwdi.dll` disassembly (`edge_parkour.asm`, `fall_landing.asm`, `rope_loco.asm`, `parkour_extra.asm`, `hook_slide_damp.asm`, `melee_edge_tick.asm`, and `PlayerParams` `0x00c59920`). All numbers, RVAs, and strings were directly observed; script-table defaults from `.scr` files are marked `[STATIC LIMIT]`.

---

## 1. `NaturalMovementController` (`0x172e200`) — Vault, Jump-On, WallRun & WallJump

### 1.1 Entry & Dispatch Structure
* **Base dispatch**: `NaturalMovementController` inherits `PlayerController`. The controller-type name switch `0x00d5dfc0` (IDs `0..42`) sits in its address band (full table in [`02_binary_function_map.md`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/Sunfall/docs/dl1_re/02_binary_function_map.md) §3.3).
* **State controller & probe helpers**: `slot[16]=0x00084150`, `slot[18]=0x00d58a70`, core parkour helpers `0x00d52c48`, `0x00d54f1e`, `0x00d5733c`, `0x00d57bc0` (`slot[2]`).

### 1.2 Observed Probe Heights, Look Locks, WallRun & Momentum XP
1. **3-Band Vertical Mantle / Obstacle Probe Heights (`0x00d5733c`, lines `108..149`)**:
   Constructs three probe target frames (`[rsi+0x3f0]`, `[rsi+0x3f8]`, `[rsi+0x400]`) along player up-vector scaled by:
   * Band 1: **`0.85 m`** (`0x3f59999a`) — low vault / hurdle band
   * Band 2: **`1.35 m`** (`0x3faccccd`) — chest/waist mantle band
   * Band 3: **`1.65 m`** (`0x3fd33333`) — shoulder/head climb-up band
   *(With horizontal step `max(..., 0.01f)` halved by `0.5f` for midpoints.)*
2. **State Look Clamps & Parkour Momentum XP (`0x00d52c48`)**:
   * **XP Triggers via `0x00bb7220` (`"Momentum"`)**:
     * `RunnerXPSkillJumpOverZombie` (`0x188` @ `0x00d52d06`) on state `0x6`.
     * `RunnerXPJumpOn` (`0x183` @ `0x00d52da7`) on state `1..2` (if `[PlayerDI + 0x13e0]` Momentum cooldown check `0x00cebda0` passes).
     * `RunnerXPDodgedAttack` (`0x192` @ `0x00d52eed`) on state `8..10`.
   * **State `6` Look Limit (`0x00d52f7c .. 0x00d52ff2`)**:
     Clamps `[PlayerDI + 0xbb0]` (`LookController`) to yaw `±179.0°`, pitch `89.0°` with blend duration **`0.4 s`** (`0x3ecccccd`). Function also branches against `±40.0°`, `45.0°`, `-20.0°`, `-10.0°`, `0.2f`, and `0.5f`.
3. **WallRun & WallJump Back (`0x00d54f1e`, `0x00d57bc0`)**:
   * `0x00d54f1e`: evaluates directional offsets clamped to **`±2.5f`** and **`0.7f`**, queries **`WallJumpBackSpeed` (`0x1ec` @ `0x00d550be`)**; call sites `0x00d54740` and `0x00d553eb` read **`WallJumpingHeight` (`0x1e9`)**.
   * `0x00d57bc0`: applies **`WallRunExtraGravity` (`0x0c9` @ `0x00d57cb5`)** and **`WallStickExtraGravity` (`0x0c8` @ `0x00d57cf5`)**.
   * Additional `PlayerParams` IDs registered in `0x00c59920`: `WallrunStartJumpHeight` (`0x0c3`), `WallrunLoopTime` (`0x0c4`), `WalljumpMaxSequence` (`0x0c7`), `WallRunFrontHeight` (`0x1ea`), `WallJumpBackHeight` (`0x1eb`), `WallrunSpeed` (`0x292`), `WallrunEnabled` (`0x3df`), `WallJumpBackEnabled` (`0x3ed`), `AutoJumpLowObstacles` (`0x3ff`). `[STATIC LIMIT]`: Numeric `.scr` defaults are external to the DLL.

---

## 2. `EdgeGrabController` (`0x172baf8`) — Ledge Detection, Hang, Shimmy & Leap

Inherits `NaturalMovementController`. Primary slots: `slot[0]=0x00d08a90`, `slot[16]=0x00d0a2a0`, `slot[18]=0x00d08c20`, `slot[19]=0x00d09cc0`.

| Component | Observed Evidence (RVA / Constants) | Exact Behavior |
|---|---|---|
| Enter (`slot[18]`) | `0x00d08c20` | Loads `"EdgeGrabSounds.scr"` / `".bin"` (`0xd18f70`, `0xd08f80`, `0xd0eb80`) |
| Tick (`slot[16]`) | `0x00d0a2a0` | Drives `"HangFromEdge_Jump_Rest"` / `"_Begin"`, blends **`0.5f`**, dispatches shimmy/climb/jump sub-states |
| Hand offset | `0x00d084f6` -> **`0.2158 m`** | Fixed hand-to-ledge grip offset (`f32=0.2158`) |
| Shimmy lateral probe | `0x00d0e5b6` -> **`0.4 m`**, **`-0.03 m`** | Lateral shimmy test step **`0.4 m`** with **`-0.03 m`** vertical ledge slice |
| Look yaw clamps | `0x00d0b1c2` (**`±75.0°`**), `0x00d0b31e` (**`±62.0°`**) | Restricts camera yaw to **`±75°`** while hanging still and **`±62°`** while shimmying |
| Ledge-jump / leap solver | `0x00d104f0`, `0x00d0f28b` | Ballistic horizontal launch speed **`4.5 m/s`** (`20.25f` sq; `1/4.5 = 0.222222f`), vertical peak clamp **`1.3 m`**, `-0.5f` gravity term, directional alignment thresholds **`0.7f`**, **`0.6f`**, **`0.8f`**, `Tap`/`Hold` jump type (`0x00bd81c0`), `LogicJumpAirControllFactor` (`0x0ca` @ `0x00d10c56`), `MoveSprintSpeed` (`0x271` @ `0x00d1258c`). |
| `NaturalMovementController` & Edge XP IDs | `0x00c59920` | `RunnerXPClimbShimmyUp` (`0x17e`), `RunnerXPClimbEdgeGrab` (`0x17f`), `RunnerXPClimbJump180` (`0x180`), `RunnerXPClimbFromBottom` (`0x181`), `RunnerXPClimbFromTop` (`0x182`), `AllowEdgeHanging` (`0x3cb`), `JumpFromHangEnabled` (`0x3ec`). |

---

## 3. Fall Helper, Amortizers & `LandingController`

### 3.1 `PlayerFallHelperModule` (`0x1728578`) & `PlayerFallAmortizer` (`0x16b2978`)
Observed in `0x00cdfa00`, `0x00cdfc50 .. 0x00ce0df0`, and `0x00ae1950`:
* **Pre-land downward probe**: **`25.0 m`** vertical raycast (`0x00ce0043..0x00ce013e`) looking ahead for landing surfaces / amortizers.
* **High-velocity / fatal threshold**: checks vertical velocity **`vel.y <= -15.0 m/s`** (`0x00ce0df0` / `[PlayerDI + 0x1170]`) before enabling amortizer/helper capture.
* **Amortizer search volume**: **`8.5 m`** search radius, **`0.65 m`** capsule height+radius offset, **`±40.0°`** approach cone (`0x00ce0df0`).
* **`PlayerFallAmortizer` bounds (`0x00ae1950`)**: **`0.5 m`** box half-extents around garbage bags / car roofs / cushions.

### 3.2 `LandingController` (`0x172d578`, `[PlayerDI + 0xcc8]`)
Slots `slot[18]=0x00d3e4a0` and `slot[16]=0x00d3e7e0` are 15-byte thunks; logic observed in helpers `0x00d3e517`, `0x00d3e890`, and `0x00d3e9b6`:
* **6 Landing Severity Categories**: integer states `0 .. 5` dispatched on landing.
* **Landing Look Blend**: restricts look yaw within **`±90.0°`** over **`0.3 s`** (`0x00d3e890`).
* **Landing Shockwave Threshold (`0x00d3e9b6`)**: compares `[PlayerDI + 0x2884]` against **`5.0f`** (`0x40a00000`):
  * `> 5.0` -> triggers `"Melee_HeavyLandingShockwave"`
  * `<= 5.0` -> triggers `"Melee_LightLandingShockwave"`
* **Registered Fall / Roll / Damping Parameters (`0x00c59920`)**:
  * `FallHeightMedium` (`0x2a2`), `FallHeightHigh` (`0x2a3`), `FallingHeightToRespawn` (`0x330`), `CrouchDampRollHeight` (`0x022`), `CrouchDampingWindowTime` (`0x021` — read in `0x00d4a964`), `FallDampingDamageReduction` (`0x023`), `FallDampingLevel2MinHeight` (`0x32c`), `FallDampingLevel1MaxHeight` (`0x32d`), `FallDampingEnabled` (`0x3e2`), `AutomaticFallDamping` (`0x3e3`), `AmortizerJumpExtraGravity` (`0x0cd`), `AmortizerJumpMaxInfluaceTime` (`0x0ce`).
  * `[STATIC LIMIT]`: Exact threshold meter values inside `PlayerParams` (e.g., `FallHeightMedium`, `FallHeightHigh`, `CrouchDampRollHeight`) are stored in external `.scr` script configs.
* **Trigger Volume Helper (`0x003d8ec5`)**: environmental fall triggers check `"AnyPlayer"`, `"OnlyAtNight"`, `"FallHightMin"`, `"ZoneBoxName"`, `"FallSurfaces"`.

---

## 4. `RopeLocomotionController` (`0x17300b8`) vs Human Grappling Hook

> **Important Architectural Split**: `RopeLocomotionController` primarily runs the Night Hunter (Be The Zombie) tendril mechanic, whereas the **Human Grappling Hook** spans helper `0x00d7cd28`, `"Stick_Melee_Rope*"` states (`0x00d7c060`), and `WeaponMeleeController` aim (`0x00db7435`).

| Feature | Observed RVA / Params | Evidence & Behavior |
|---|---|---|
| **Human Grappling Hook Raycast** | `0x00d7cd28 .. 0x00d7cefc` | Gets look origin (`0x00d7dcc0`) + look forward (`PlayerDI::vslot[233]`), multiplies by **`ThrowHookRopeLength` (`0x049` @ `0x00d7cdfe`)**, and performs physics raycast against world geometry (reading `params[0x49]` = `0x00c594d0` / `[rcx+0x248]`). |
| **Human Grappling Hook Aim / Actions** | `0x00db7435`, `0x00d7c060`, `0x00c4418c` | `"Melee_RopeThrow_Aim"` (`0x00db7435` in `WeaponMeleeController`), `"Stick_Melee_RopeThrow"`, `"Stick_Melee_RopeThrowBack"`, `"Stick_Melee_RopeClimb"` (`0x00d7c060`), plus `ThrowRopeLength` (`0x048` @ `0x00db79a9`, `0x00dba47c`), `GrapplingHookCooldown` (`0x21e`), `GrapplingHookPullEnabled` (`0x3e7`), `GrapplingHookExtraGravityOnAttach` (`0x3e8`), `ThrowHookCanUseInAir` (`0x3be`). |
| **BTZ Night Hunter `RopeLocomotionController`** | `0x00d74fe0 .. 0x00d7c850`, `slot[16]=0x00d75180` | States `"Windup"`, `"Attaching"`, `"Connected"`, `"WallStick"`, `"Landing"`, `"Detaching"`, `"Falling"`, gated by `"f_btz_zombie_ropeloco_*"` script variables (`RopeLocomotionVelocity` `0x057`, `RopeLocomotionAcceleration` `0x058`, `RopeMaxEnergy` `0x05c`, `RopeEnergyRegenTime` `0x05d`). |
