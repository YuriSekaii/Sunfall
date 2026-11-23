# Dying Light 1 Binary Function Map (`gamedll_x64_rwdi.dll`)

> Static reverse-engineering inventory extracted from `D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com\gamedll_x64_rwdi.dll` via [`tools/re_dl_binary.py`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/Sunfall/tools/re_dl_binary.py) into `assets_ref/dl_re_raw/dl1_binary_map.json` (PE metadata, MSVC x64 RTTI, `.pdata` runtime functions, and Capstone x86-64 disassembly). All addresses are RVAs relative to `ImageBase = 0x180000000`. Unresolved indirect calls and external `.scr` script defaults are marked `[STATIC LIMIT]`.

---

## 1. PE Sections & Binary Overview

| Section | Virtual Address (RVA) | Virtual Size | Raw Ptr | Raw Size | Notes |
|---|---|---|---|---|---|
| `.text` | `0x00001000` | `0x01377fb1` | `0x00000400` | `0x01378000` | Machine code; `88,209` `.pdata` `RUNTIME_FUNCTION` entries |
| `.rdata` | `0x01379000` | `0x0082be72` | `0x01378400` | `0x0082c000` | RTTI descriptors, VTables, strings, IEEE-754 float/double literals |
| `.data` | `0x01ba5000` | `0x0017b760` | `0x01ba4400` | `0x0006ba00` | Global singletons and runtime tables |
| `.pdata` | `0x01d21000` | `0x001026cc` | `0x01c0fe00` | `0x00102800` | x64 unwind / function range descriptors |
| `_RDATA` | `0x01e24000` | `0x0000b130` | `0x01d12600` | `0x0000b200` | Secondary read-only data |
| `.rsrc` | `0x01e30000` | `0x000001e0` | `0x01d1d800` | `0x00000200` | Resource directory |
| `.reloc` | `0x01e31000` | `0x00131620` | `0x01d1da00` | `0x00131800` | Base relocations |

* **RTTI totals**: `6,295` MSVC x64 RTTI classes, `14,934` VTables (`77` target RTTI records extracted, `3,437` string xrefs mapped, `7,231` `.pdata` functions indexed).
* **Primary PlayerController code band**: `0x00cdb000 .. 0x00df5000`.
* **Shared `PlayerParams` property subsystem**:
  * `0x00c594d0` *(not in `.pdata`; tail helper)* — reads `(params_table_ptr, prop_id)` -> `*(float*)(*(params_table_ptr)[prop_id] + 8)`. When `prop_id` is in `[0x269, 0x292]` (42 `Move*` / `Aim*` / `Crouch*` / `ZipLine*` / `WallrunSpeed` parameters) and `[player + 0x2a88]` has an active modifier (`+0xc >= 1`), scales the returned float by `0.8f` (`0x19262d4`) instead of `1.0f` (`0x1925fea`).
  * `0x00c59920 .. 0x00c5d9fc` (`size=16,604`) — `PlayerParams` ID-to-name jump table mapping `1 .. 0x410` (`1,040` IDs) via table at `0x00c5c9bc`. `[STATIC LIMIT]`: Default numeric values loaded into `PlayerParams` come from external `.scr` script assets (not stored as literal constants inside `0xc59920`).
  * `0x00bb7220 .. 0x00bb74b8` (`size=664`) — XP award / `"Momentum"` reporter; multiplies XP amounts by `RunnerXPFactor` (`0x18b`), `FighterXPFactor` (`0x1a3`), or `DriverXPFactor` (`0x199`).

---

## 2. Core Classes (18 Requested Targets)

All 18 core classes resolved directly in MSVC RTTI:

| Class | Base Chain (Primary) | Primary VT (`off=0x0`) | Slots (`off=0`) | Secondary Interface VTables (`offset : vt_rva : slots`) |
|---|---|---|---|---|
| `PlayerDI` | `PlayerDI -> ActorDI -> ... -> GameObject` | `0x17016e8` | `337` | `25` total VTables (`0x18:0x1701448:83`, `0x28:0x1700cb8:241`, `0x30..0x970`) |
| `MoveController` | `MoveController -> PlayerController -> PlayerModuleBase` | `0x172e068` | `34` | `0x18:0x172e008:11`, `0x20:0x172dfe8:3`, `0x28:0x172df80:12` |
| `NaturalMovementController` | `NaturalMovementController -> PlayerController -> PlayerModuleBase` | `0x172e200` | `47` | `0x18:0x172e1a0:11`, `0x20:0x172e3c0:12`, `0x28:0x172e380:7`, `0x30:0x172e180:3` |
| `EdgeGrabController` | `EdgeGrabController -> NaturalMovementController -> PlayerController` | `0x172baf8` | `50` | `0x18:0x172bcf8:11`, `0x20:0x172bc90:12`, `0x28:0x172bab8:7`, `0x30:0x172ba98:3` |
| `LandingController` | `LandingController -> PlayerController -> PlayerModuleBase` | `0x172d578` | `34` | `0x18:0x172d538:7`, `0x20:0x172d6f8:11`, `0x28:0x172d690:12` |
| `LookController` | `LookController -> PlayerController -> PlayerModuleBase` | `0x172da70` | `34` | `0x18:0x172db88:12` |
| `CameraFPPDI` | `CameraFPPDI -> BaseCameraDI -> Camera -> GameObject` | `0x147f680` | `12` | `0x10:0x147eef0:241`, `0x18:0x147f6f8:4`, `0x20:0x147f6e8:1`, `0x40:0x147f720:2` |
| `PlayerFppVis` | `PlayerFppVis -> PlayerVis -> HumanVis -> BodyVis` | `0x17044a0` | `439` | `0x8:0x1704468:4`, `0x10:0x1704490:1`, `0x30:0x17043c0:2`, `0x40:0x17043d8:17`, `0x48:0x1704338:2`, `0x2cb0:0x1704350:13` |
| `WeaponMeleeController` | `WeaponMeleeController -> PlayerController -> PlayerModuleBase` | `0x1732b40` | `34` | `0x18:0x1732a80:12`, `0x20:0x1732a20:11`, `0x28:0x1732b00:7`, `0x30:0x1732ae8:2` |
| `ChargeController` | `ChargeController -> PlayerController -> PlayerModuleBase` | `0x172a910` | `34` | *(single inheritance)* |
| `StompFinisherController` | `StompFinisherController -> PlayerController -> PlayerModuleBase` | `0x17310c8` | `35` | `0x18:0x1731248:12`, `0x20:0x17311e8:11`, `0x28:0x1731088:7` |
| `GrabController` | `GrabController -> PlayerController -> PlayerModuleBase` | `0x172bfd0` | `34` | `0x18:0x172c148:12`, `0x20:0x172c0e8:11`, `0x28:0x172c218:7`, `0x30:0x172c1b0:12`, `0x38:0x172c288:3`, `0x40:0x172c258:5` |
| `RopeLocomotionController` | `RopeLocomotionController -> PlayerController -> PlayerModuleBase` | `0x17300b8` | `34` | `0x18:0x1730050:12`, `0x20:0x1730230:12`, `0x28:0x17301d0:11`, `0x30:0x1730010:7`, `0x38:0x172fff0:3` |
| `PlayerFitnessModule` | `PlayerFitnessModule -> PlayerModuleBase` | `0x1728600` | `16` | *(single inheritance)* |
| `PlayerStaminaModule` | `PlayerStaminaModule -> PlayerModuleBase` | `0x1729f88` | `16` | *(single inheritance)* |
| `DodgeModule` | `DodgeModule -> AIModule -> GameObject` | `0x144cea8` | `263` | `0x8:0x144d6e8:4`, `0x10:0x144d710:1`, `0x30:0x144d720:2` (**AI dodge**, not player!) |
| `PlayerFallAmortizer` | `PlayerFallAmortizer -> EditorRenderableObject -> ControlObject` | `0x16b2978` | `83` | `0x10:0x16b21e8:241`, `0x18:0x16b21c0:4`, `0x20:0x16b21b0:1`, `0x40:0x16b2198:2`, `0x50:0x16b2168:5`, `0x58:0x16b2130:6` |
| `PlayerFallHelperModule` | `PlayerFallHelperModule -> PlayerModuleBase` | `0x1728578` | `16` | *(single inheritance)* |

*(Related auxiliary RTTI class: `PlayerDuckModule` in `0x00cde22e .. 0x00cde9d0`, mounted at `[PlayerDI + 0x13c8]`.)*

---

## 3. `PlayerController` Virtual Slot ABI & Hierarchy

### 3.1 Observed Primary VTable (`offset = 0x0`) Slot Semantics
Verified across `PlayerFitnessModule::slot[1]` (`0xce12e0`), `PlayerStaminaModule::slot[1]` (`0xcf0500`), `MoveController::slot[16/18/25]`, `WeaponMeleeController::slot[18/25]`, and `0x00d5f250`:

| Slot | Byte Offset | Observed Role | Reference RVA |
|---|---|---|---|
| `slot[0]` | `+0x00` | Scalar deleting destructor | `0xd08a90` (`EdgeGrab`), `0xd40b00` (`Look`) |
| `slot[1]` | `+0x08` | `AttachToPlayer` / Register owner | `0xce12e0`, `0xcf0500` |
| `slot[4]` | `+0x20` | `GetOwner()` (`PlayerDI*`) | Called ubiquitously (`call [rax + 0x20]`) |
| `slot[5]` | `+0x28` | `IsActive()` (`bool`) | Called before gating logic (`0xd52d47`) |
| `slot[6]` | `+0x30` | `GetElapsedTime()` / Update timer | Returns `xmm0` (`0xd8adfb`, `0xd4ff3b`) |
| `slot[16]` | `+0x80` | `PreUpdate` / Per-frame Tick | `0xd485b0`, `0xd0a2a0`, `0xd75180`, `0xdb23a0` |
| `slot[18]` | `+0x90` | `Activate` / Enter state | `0xd4a330`, `0xd08c20`, `0xdb18c0`, `0xd22930` |
| `slot[19]` | `+0x98` | `Deactivate` / Exit state | `0xd09cc0` |
| `slot[22]` | `+0xb0` | `PostUpdate` / Secondary tick | `0xdb3db0` (`WeaponMelee`), `0xd8c930` (`Stomp`) |
| `slot[25]` | `+0xc8` | `DebugDump()` -> formatted state string | `0xd5f250` (shared formatter), `0xdc8000`, `0xd29b50` |

### 3.2 Complete `PlayerController` Subclass Table (`44` RTTI Subclasses)

All `44` RTTI classes in the extracted target set whose base chain includes `PlayerController` (`PlayerController` itself has no standalone record in `target_classes`):

| Class | `VT[0]` RVA | Slots | `slot[16]` (Tick) | `slot[18]` (Enter) | `slot[25]` (Debug) |
|---|---|---|---|---|---|
| `BreakDoorController` | `0x172a790` | 34 | `0xcf5860` | `0xcf5b90` | `0xd5f250` |
| `ChargeController` | `0x172a910` | 34 | `0xcf6990` | `0xcf6670` | `0xd5f250` |
| `CinematicController` | `0x172ab10` | 35 | `0xcf7c90` | `0xcf74f0` | `0xcf8a90` |
| `DeadController` | `0x172acb0` | 35 | `0xcf9280` | `0xcf92c0` | `0xd5f250` |
| `DefensiveController` | `0x172b108` | 34 | `0xcfa440` | `0xcf9fb0` | `0xd5f250` |
| `DialogController` | `0x172b338` | 35 | `0xd05670` | `0xd050c0` | `0xd5f250` |
| `EdgeGrabController` | `0x172baf8` | 50 | `0xd0a2a0` | `0xd08c20` | `0xd5f250` |
| `EquipmentController` | `0x172be10` | 34 | `0xd1d250` | `0xd1d150` | `0xd5f250` |
| `GrabController` | `0x172bfd0` | 34 | `0xd21a70` | `0xd22930` | `0xd29b50` |
| `HealingController` | `0x172c350` | 34 | `0xd2a8c0` | `0xd2a720` | `0xd5f250` |
| `InfectionController` | `0x172c578` | 34 | `0xd2be50` | `0xd2bc70` | `0xd5f250` |
| `InjectionController` | `0x172c7f0` | 34 | `0xd2c970` | `0xd2c6b0` | `0xd5f250` |
| `InteractionController` | `0x172ca48` | 34 | `0xd300c0` | `0xd2f860` | `0xd5f250` |
| `KnockDownController` | `0x172cda8` | 34 | `0xd32670` | `0xd31fa0` | `0xd32e50` |
| `LadderController` | `0x172d3e0` | 34 | `0xd362b0` | `0xd349d0` | `0xd3ce60` |
| `LandingController` | `0x172d578` | 34 | `0xd3e7e0` | `0xd3e4a0` | `0xd5f250` |
| `LockpickController` | `0x172d848` | 34 | `0xd3fe20` | `0xd3f800` | `0xd5f250` |
| `LookController` | `0x172da70` | 34 | `0xd40ce0` | `0xd41ca0` | `0xd5f250` |
| `MoveController` | `0x172e068` | 34 | `0xd485b0` | `0xd4a330` | `0xd4bab0` |
| `NaturalMovementController` | `0x172e200` | 47 | `0x84150` | `0xd58a70` | `0xd5f250` |
| `ObjectsCarryController` | `0x172e510` | 34 | `0xd593a0` | `0xd59a10` | `0xd5f250` |
| `PVPGrabController` | `0x172f328` | 34 | `0xd65100` | `0xd64e70` | `0xd5f250` |
| `PlayerGrabAttackController` | `0x172eae8` | 34 | `0xd601c0` | `0xcf6670` | `0xd5f250` |
| `ReactionController` | `0x172f568` | 34 | `0xd72b60` | `0xd72a40` | `0xd5f250` |
| `RepairWeaponController` | `0x172f6d8` | 34 | `0xd73eb0` | `0xd73d40` | `0xd5f250` |
| `RopeLocomotionController` | `0x17300b8` | 34 | `0xd75180` | `0xd75890` | `0xd5f250` |
| `SelfieController` | `0x17303c8` | 34 | `0xd7f830` | `0xd7fb60` | `0xd80b00` |
| `ShieldController` | `0x17306a8` | 34 | `0xd81830` | `0xd816b0` | `0xd82b50` |
| `SpecialUseController` | `0x17308b0` | 34 | `0xd85910` | `0xd85590` | `0xd5f250` |
| `SpikesHitController` | `0x1730ba8` | 34 | `0xd861c0` | `0xcf6670` | `0xd5f250` |
| `StationaryCannonController` | `0x1730f48` | 34 | `0xd88d60` | `0xd892c0` | `0xd5f250` |
| `StompFinisherController` | `0x17310c8` | 35 | `0xd8ace0` | `0xd8a990` | `0xd8cf40` |
| `SwimController` | `0x17313e0` | 34 | `0xd8da40` | `0xd8d520` | `0xd5f250` |
| `TriggerController` | `0x1731600` | 34 | `0xd8fc20` | `0xd90d10` | `0xd5f250` |
| `TutorialController` | `0x1731848` | 34 | `0xd93900` | `0xd93800` | `0xd5f250` |
| `WeaponBowController` | `0x1731f60` | 34 | `0xd9c670` | `0xd9c3c0` | `0xd5f250` |
| `WeaponFireController` | `0x17328a8` | 34 | `0xda3150` | `0xd9fa00` | `0xda7980` |
| `WeaponFireControllerLeft` | `0x1732750` | 34 | `0xda3150` | `0xd9fa00` | `0xda7980` |
| `WeaponFireControllerRight` | `0x17325f8` | 34 | `0xda3150` | `0xd9fa00` | `0xda7980` |
| `WeaponMeleeController` | `0x1732b40` | 34 | `0xdb23a0` | `0xdb18c0` | `0xdc8000` |
| `WeaponThrowController` | `0x1733550` | 34 | `0xdd1cd0` | `0xdd19f0` | `0xd5f250` |
| `ZipLineController` | `0x17337a8` | 34 | `0xdd6290` | `0xdd5a70` | `0xd5f250` |
| `ZombieAbilitiesController` | `0x1733fa0` | 34 | `0xdd97b0` | `0xdd8a00` | `0xd5f250` |
| `ZombieVehicleAttackController` | `0x1734340` | 34 | `0xddf700` | `0xddf610` | `0xd5f250` |

### 3.3 Controller-Type Name Switch (`0x00d5dfc0`, table `0x00d5e694`, in the `NaturalMovementController` address band)

`43` IDs (`0..42`); `40` named, `3` fall to the default branch (`10`, `30`, `34`).

| ID | Name | ID | Name | ID | Name |
|---|---|---|---|---|---|
| `0` | `"Move"` | `15` | `"WeaponFireRight"` | `30` | `[default]` |
| `1` | `"Dead"` | `16` | `"WeaponFireLeft"` | `31` | `"ZombieAbilities"` |
| `2` | `"Look"` | `17` | `"WeaponThrow"` | `32` | `"ChargeController"` |
| `3` | `"Grab"` | `18` | `"WeaponBow"` | `33` | `"ZipLine"` |
| `4` | `"Vehicle"` | `19` | `"Injection"` | `34` | `[default]` |
| `5` | `"Cinematic"` | `20` | `"ObjectsCarry"` | `35` | `"Infection"` |
| `6` | `"Trigger"` | `21` | `"Dialog"` | `36` | `"Reaction"` |
| `7` | `"Ladder"` | `22` | `"Equipment"` | `37` | `"Landing"` |
| `8` | `"StationaryCannon"` | `23` | `"Defensive"` | `38` | `"SpecialUse"` |
| `9` | `"Healing"` | `24` | `"EdgeGrab"` | `39` | `"Shield"` |
| `10` | `[default]` | `25` | `"Interaction"` | `40` | `"SpikesHit"` |
| `11` | `"KnockDown"` | `26` | `"Swim"` | `41` | `"ZombieVehicleAttack"` |
| `12` | `"BreakDoor"` | `27` | `"Lockpick"` | `42` | `"Selfie"` |
| `13` | `"StompFinisher"` | `28` | `"RopeLocomotion"` | | |
| `14` | `"WeaponMelee"` | `29` | `"PVPGrab"` | | |

---

## 4. Verified `PlayerDI` Object Offsets

Observed directly in controller and module disassembly:

| Offset | Type / Target | Observed Evidence RVAs |
|---|---|---|
| `+0x50` | Local vs remote/replicated byte flag | `0x00d52cd6`, `0x00d7cdce`, `0x00bb723f` |
| `+0xb98` | Controller active-state byte array (`+idx`, `+idx+0x2b`, `+idx+0x56`) | `0x00db18f4`, `0x00d485b0` |
| `+0xba0` | `MoveController*` | `0x00d10b7e`, `0x00d10c16` |
| `+0xbb0` | Look subcontroller (inferred: passed to look-angle clamp helper `0xd46220` with `179°/89°`, `0.4 s`) | `0x00d52fbc` |
| `+0xbb8` | Charge/sprint subcontroller (`+0x10` active, `+0xcc <= 4`) | `0x00d4979c` band |
| `+0xc10` | `WeaponMeleeController*` | `0x00d4a872`, `0x00d4a89b` |
| `+0xc18` | Secondary combat/aim subcontroller (`+0x10`, `+0x58/+0x5c`) | `0x00d43b0e`, `0x00d4985f` |
| `+0xc30` | Subcontroller contributing look offsets `+0x94/+0x98` | `0x00d43b7a`, `0x00d43d48` |
| `+0xc58` | Defensive/Rope/Active subcontroller (`+0x38 == 0xc`, `0xd01310`) | `0x00d8af5f`, `0x00d4a812` |
| `+0xc60` | Active stance / duck lock struct (`0xce0e69`, `0xcde298`) | `0x00ce0e69`, `0x00cde298` |
| `+0xc80` | Grapple/subcontroller pointer (`+0x68`) | Observed in `MoveController` |
| `+0xc98` | `DefensiveController` / Slide state (`+0x38 == 6`) | `0x00d48a9b` |
| `+0xcc8` | `LandingController*` | `0x00d4e90d` |
| `+0xcd8` | Climb/stamina-block controller | `0x00cf0c06`, `0x00cf1380` |
| `+0xe58 -> +0xd0` | `PlayerParams*` float lookup table (`0x00c594d0`) | `0x00d52cf3`, `0x00d7cdeb` |
| `+0x116c..+0x11ec` | Physics velocity (`+0x1170` Y vel) & look angles (`+0x1174/+0x1178`, `+0x11ec` yaw deg) | `0x00cfc463`, `0x00d43af3`, `0x00d5226f`, `0x00cde385` |
| `+0x1348` | `PlayerFitnessModule*` | `0x00d4979c` (`[player+0x1348]`) |
| `+0x1370` | Light damage module (`0x00ce3fe0`) | `0x00ce3fe0` |
| `+0x1380` | Secondary combat resource / stamina block (`+0x20`) | `0x00db3ff6` |
| `+0x1390` | `PlayerStaminaModule*` | `0x00ce1e94` |
| `+0x13c8` | `PlayerDuckModule*` | `0x00cde22e`, `0x00cde585` |
| `+0x13e0` | Momentum/parkour XP cooldown subobject (`0x00cebda0`, `0x00cebd50`) | `0x00d52d5b`, `0x00d52dda` |
| `+0x2884` | Fall height / landing severity scalar | `0x00d3e9c6` |
| `+0x2a88` | Active movement debuff/modifier container (`0x00c59520`) | `0x00c59520`, `0x00cf0581`, `0x00d4a247` |
