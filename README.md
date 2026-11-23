# ☀️ Sunfall

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer](https://img.shields.io/badge/Renderer-Vulkan%20Forward%2B-red)](https://vulkan.org)
[![Status](https://img.shields.io/badge/Build-Solo%20Prototype%20%E2%86%92%20Co--op%20Vision-orange)](#)
[![Repository](https://img.shields.io/badge/GitHub-YuriSekaii%2FSunfall-181717?logo=github)](https://github.com/YuriSekaii/Sunfall)

First-person roguelike survival-defense prototype built in **Godot 4.7.2**. Stranded after a plane crash on an uncharted bio-weapon island, you have **10 days** until rescue: scavenge tools, food, and lab materials by day (or brave dark Bio-Lab bunkers where infected never sleep), build and upgrade barricades and auto-turrets, and survive relentless night hordes using Dying Light-style parkour and melee combat.

---

## 🎮 Quick Start & Launchers

The repository bundles **Godot 4.7.2** (`engine.zip`) and **MinGit** (`git.zip`) so players can launch and update with zero external setup. [`tools/ensure_git.bat`](tools/ensure_git.bat) unpacks portable git into `git_portable/` if `git` is missing from `PATH` and converts ZIP downloads into a tracked git clone on first online run.

| Launcher Script | Description |
| :--- | :--- |
| **`Play_Game.bat`** | Auto-unpacks `engine.zip` if needed, runs `--headless --import` when the git commit changed (`.godot/last_import_commit.txt`), and launches Sunfall. |
| **`Update_Game.bat`** | Pulls `origin main` via `git pull` and re-imports assets headlessly. |
| **`Open_In_Godot_Editor.bat`** | Opens the project directly inside the Godot 4.7.2 Editor. |
| **`Push_To_GitHub.bat`** | Pushes local `main` commits to `origin main`. |

---

## 🔄 In-Game Auto-Updater

Open the **Pause Menu (`Esc`)** and click **Check for Updates** (`scripts/autoload/update_manager.gd`):

* **Async Remote Check**: Runs `git fetch origin <branch>` in a background `Thread`, showing local build (`branch @ short_hash`) and up to 10 pending commit summaries when behind.
* **`⬇ Update Now (git pull)`**: Pulls latest commits, runs `godot --headless --import --path <proj_dir>`, and enables **`🚀 Restart Game`**.
* **Two-Click `⚠ Force Update (git reset --hard)`**: First click arms confirmation (`Click Again to Confirm: Discard Local Changes`); second click fetches and resets tracked files to `origin/<branch>` while keeping untracked local files.
* **`desktop.ini` Cleanup**: Purges hidden Windows `desktop.ini` files inside `.git/` before fetch/pull to prevent `fatal: bad object refs/desktop.ini`.
* **Portable Git Fallback**: Uses system `git` on `PATH` or falls back automatically to bundled `git_portable/cmd/git.exe`.

---

## 🕹️ Controls

| Action | Input | Details |
| :--- | :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` | Walk (`3.5 m/s`), strafe/backpedal (`2.5 m/s`), `0.51m` stair step-up |
| **Look / Lookback** | `Mouse` / `B` (hold) | First-person look; hold `B` to glance `180°` behind while sprinting |
| **Sprint / Tackle** | `Shift` (`+E` or `+RMB`) | `6.0 m/s` (`+4.5°` FOV, `0.10` fitness/s); `Shift+E`/`Shift+RMB` tackles (`+6.0 m/s`) |
| **Jump / Vault / Hang** | `Space` | Jump (`5.825 m/s`), low vault, high mantle, ledge hang (`A/D` shimmy, `180°` jump-off), zombie vault, or wall-jump |
| **Crouch / Slide / Roll** | `Ctrl` or `C` | Crouch (`1.5 m/s`, `1.05m` capsule), slide (`8.6→3.0 m/s`, knocks down), or `360°` landing roll (`1.0s` window) |
| **Quick Dodge / Sidestep** | `Alt` or `Space` + `A/D/S` | `0.24s` burst at `9.0 m/s` (`0.20` combat stamina, `0.75s` cd) |
| **Melee / Slam / Build** | `Left Mouse Button` | Tap for 5-ray combo (`0.60s`), hold `>= 0.50s` for Heavy Swing, airborne looking down/crouched for Ground Pound; Slot 2/3 builds/repairs |
| **Upgrade Wall** | `Right Mouse Button` | Upgrades targeted Wood Wall to Reinforced Metal (`2 Metal`) |
| **Kick / Dropkick / Stomp** | `Q` (or `E` on downed) | Grounded kick (`0` stam), Air Kick (`0.30` stam), forward Dropkick (`0.50` stam, `40` dmg + knockdown), or Head Stomp (`120` dmg) |
| **Grappling Hook** | `X` or `MMB` | `25m` range, `0.5` rope energy (`1.0` max, `10s` regen), zips `20 m/s` + auto-mantle |
| **Loot / Break Grab** | `E` (hold / mash) | Searches targeted container (`0.60s`–`0.95s`); mash `Space/E/A/D` to break zombie grab |
| **Survivor Sense** | `V` | `3.5s` sonar pulse (`6.0s` cd) highlighting unlooted crates (gold) & infected within `45m` (red) through walls |
| **Hotbar Slots** | `1`, `2`, `3` | `1` Melee Weapon, `2` Wood Wall, `3` Auto-Turret |
| **Flashlight** | `F` | Toggles head-mounted `SpotLight3D` (`24m` range) |
| **Use Medkit** | `H` | Consumes 1 Medkit (`+50 HP`) |
| **Eat / Drink** | `G` | Consumes Water (`+45 Thirst`) or Food (`+45 Hunger`), prioritizing lowest need |
| **Skip Phase** | `T` | Advances current day/night timer to `0.05s` (testing shortcut) |
| **Telemetry / Trace Dump** | `F3` / `F4` | `F3` toggles live DL1 parity scorecard; `F4` writes `user://dl_telemetry.json` |
| **Pause / Restart** | `Esc` / `R` | `Esc` toggles pause + updater menu; `R` restarts on death/victory |

---

## 🏃 Core Mechanic Systems

### 1. Dying Light 1 Movement & Parkour (`scripts/player.gd`, `scripts/dl_reference.gd`)
Calibrated directly from `DW/Data0.pak` and `gamedll_x64_rwdi.dll` reverse-engineering specs in [`docs/dl1_re/`](docs/dl1_re/01_data_catalog.md):
* **Base Kinematics (`Data0.pak` & `MoveController`)**: Gravity `16.80 m/s²`, Jump `5.825 m/s` (`1.01m` apex, `0.40s` interval, `0.12s` coyote time, `0.15s` jump buffer), Walk `3.5 m/s`, Back/Strafe `2.5 m/s`, Sprint `6.0 m/s`, Crouch `1.5 m/s`, `50°` max slope, `0.51m` stair step-up, linear `move_toward` accel/decel (`40.0` ground, `10.0` sprint, `4.0/10.0` crouch, `0.22` air control), and slope slide-down ramp `clamp(slope_deg * 0.0175556 + 0.01, 0.01, 0.80)`.
* **Real Crouch Capsule (`PlayerDuckModule`)**: Standing `1.75m` (eye `1.56m`) ↔ crouched/sliding `1.05m` (eye `0.90m`) with `0.30m × 1.50m` overhead `duck_capsule` clearance check before standing.
* **4-Phase Slide & Dodge**: Slide progresses through `SlideBegin` (`0.333s`) → `SlideLoop` / `SlideLoopRight` (`> 5°` yaw delta, `0.400s`) → `SlideKick` (`0.567s`, hit @ `0.233s`) → `SlideEnd` (`0.481s`). Dodge (`0.15s` min interval, `0.75s` cd) fires a `6.0` impulse + `9.0 m/s` burst.
* **Natural Movement, Ledge Grab, Shimmy & Wall-Run**:
  * **3-Band Obstacle Probes**: `0.85m` low hurdle/vault (`0.500s`, exits at `6.0 m/s`), `1.35m` waist mantle, `1.65m` chest climb (`0.725s`).
  * **Edge Grab (`EdgeGrabController`)**: `0.2158m` hand-to-ledge grip offset, discrete `0.40m` (`-0.03m` vertical slice) shimmy steps (`0.625s` beat), `±75°` hang / `±62°` shimmy yaw clamps, and `4.5 m/s` horizontal ballistic `180°` jump-off (`1.3m` peak clamp).
  * **Vertical Front Wall-Run & Lateral Tic-Tac**: Holding `W+Space` straight into a wall climbs `+1.8m` (`wall_run_up`), enabling `~4.3m` ledge grabs; lateral Tic-Tac runs up to `1.1s` (`WALL_RUN_EXTRA_GRAVITY = 9.5`, `±11°` roll, up to `2` wall-jumps).
* **Fall Helper, 6-Tier Landing & Amortizers (`PlayerFallHelperModule`, `LandingController`)**: `25.0m` downward lookahead ray (`vel.y <= -15.0 m/s` trigger, `8.5m / ±40°` amortizer capture); 6 landing severity tiers (`0..5`), `±90° / 0.3s` landing look blend, `> 5.0m` heavy vs. light shockwave, `CrouchDamper` (`0.80s`) vs. `360°` `CrouchDamperRoll` (`1.00s`, `0` dmg within `1.0s` window), and `amortizer` pads (`0` dmg, `-3.0°` FOV).
* **Dual Stamina (`PlayerFitnessModule` & `PlayerStaminaModule`)**:
  * **Fitness**: Drains `0.10/s` sprinting and `0.10` per jump (`0.75s` delay / `5.0s` on empty, `2.0/s` regen, `0.75×` while moving/crouching); sprint gated by `fitness > 0.06` & non-exhausted, with smooth `0.8 + 0.2 * clamp((fitness - 0.2)/0.3, 0, 1)` speed curve.
  * **Combat Stamina**: `2.5s` delay / `4.0s` on empty, `1.5/s` regen, `0.6×` cost on miss; exhausted swings remain usable (`1.567s` cycle, `0.65×` dmg).
  * **Needs**: Max HP `100` (slow regen up to `25 HP`); Hunger `-0.16/s`, Thirst `-0.22/s` (`0` causes `-20%` speed and `-0.35 HP/s` down to `1 HP`).
* **FPP Rig & Camera Coupling (`CameraFPPDI`, `LookController`, `player_dieselpunk_fpp`)**: Extracted real Dying Light 1 `player_dieselpunk_fpp` FPP mesh (`14,554` verts, hands + watch + legs + torso) with `21` bones incl. `WeaponSocket` and `EyeCamera` (`idx=14`), `28` `.scr`-timed clips, `LookParams` `[-89°, +70°]` pitch clamp, `LookController` cosine slew (`0.25 - cos(x*pi)*0.25`), `0.133s` `LookBack` whip, and stride footsteps (`0.567s` sprint / `0.883s` walk).

### 2. Melee Combat & Weapons (`scripts/player.gd`, `scripts/loot_table.gd`)
* **Continuous `±60°` Sweep, Headshots & Active Windows**: Light swings alternate RL (`0.600s`, hit `[0.093s..0.333s]`) and LR (`0.500s`, hit `[0.083s..0.333s]`) with `±6°` camera roll, continuous `±60°` multi-target sweep + per-swing deduplication, `2.0×` Headshot Crits (`z.is_headshot_pos`), and `0.045s` hit-pause + particle bursts.
* **Charged Heavy, Tackle & Ground Pound**: Hold `LMB >= 0.50s` for Heavy Swing (`1.667s`, `[0.667s..0.879s]`, `1.75×` dmg, `+0.15m` reach). `Shift+E`/`Shift+RMB` tackles (`+6.0 m/s`, `0.40` stam, `1.0s` cd, knockdown). Airborne `LMB` looking down (`pitch < -0.35`) or `Ctrl+LMB` triggers Ground Pound (`-16 m/s`, `3.0m` shockwave knockdown, `32` dmg).
* **Kick, Dropkick & Head Stomp**: Grounded `Q` (`0.625s`, `[0.25s..0.35s]`, `0` stam, `8` dmg), `KickLow` (`0.533s`), Air Kick (`0.567s`, `0.30` stam), Dropkick (`0.800s`, `0.50` stam, `40` dmg, `23.0` knockback + `2.5s` knockdown + `1.267s` `StandUpFast`), and `StompFinisher` (`1.200s`, `120` dmg).
* **Zombie Grab & Fast Break**: Active non-biters within `1.25m` (`8s` cd) can grab the player (`2.0s` struggle input window); mash `Space/E/A/D` (`3` taps) to shove free (`1.067s` `FastFinishWins`) and stun the zombie for `3.0s`. Active AI zombies can also perform `DodgeModule` sidesteps.

| Tier | Weapon | Damage | Reach | Stamina Cost |
| :---: | :--- | :---: | :---: | :---: |
| `1` | **Rusty Pipe** | `24.0` | `2.40m` | `0.16` |
| `2` | **Salvaged Machete** | `38.0` | `2.60m` | `0.14` |
| `3` | **Lab Fire-Axe** | `58.0` | `2.85m` | `0.20` |

### 3. Deterministic Seeded Loot Pools (`scripts/loot_table.gd`, `scripts/loot_container.gd`)
Containers roll deterministically from `(run_seed, container_id, pool, day)`. Weapon drop chance increases by `+3%/day` (capped at `+20%`).

| Pool | Display Name | Search Time | Rolls | Primary Contents | Weapon Chance (Max Tier) |
| :--- | :--- | :---: | :---: | :--- | :---: |
| `crash` | **Plane Case** | `0.60s` | `2–3` | Wood, Food, Water, Medkit, Metal | `18%` (Tier 2) |
| `supply` | **Supply Crate** | `0.75s` | `2–4` | Wood, Metal, Food, Water, Gunpowder, Medkit | `22%` (Tier 2) |
| `lab` | **Bio-Lab Locker** | `0.95s` | `3–4` | Metal, Gunpowder, Medkit, Wood, Water | `55%` (Tier 3) |

### 4. Base Defense Structures (`scripts/structure.gd`)
* **Wood Barricade (`wall`)**: Costs `3 Wood`. Tier 1 `120 HP`; repairs `+60 HP` for `1 Wood`; upgrades for `2 Metal` to Tier 2 **Metal Wall** (`280 HP`).
* **Auto-Turret (`turret`)**: Costs `3 Wood, 2 Metal, 1 Gunpowder`. `90 HP`, scans `15.0m` line-of-sight every `0.15s`, fires every `0.55s` dealing `16.0` damage + `3.0` knockback with tracer beams.

### 5. Day/Night Cycle, Sunlight Lore & Infected (`scripts/world.gd`, `scripts/zombie.gd`)
* **Cycle**: `DAY_DURATION = 90.0s`, `NIGHT_DURATION = 60.0s`, survive `MAX_DAYS = 10` nights to win.
* **Sunlight Lore**: Daytime outdoor infected are weakened (`detect_range = 9m`, `1.5 m/s`, `1.8s` attack cd, `0.65×` damage). Bio-Lab bunker infected and all zombies at night are fully active (`detect_range = 45m`, `4.4 m/s` / `3.3 m/s` brute, `1.1s` attack cd, `2.1×` forward lunge).
* **Spawning**: Daytime maintains `5` outdoor roamers spawned `>= 20m` away from the player. Night hordes spawn `8 + day * 5` infected with concurrent cap `min(6 + day * 2, 22)` (`~45%` Volatile night runners, `22%` Goons on Day 2+). Dead infected hold their `death` animation corpse for `4.0s`.

| Enemy Type | Role | Rigged Model | Base HP | Damage |
| :--- | :--- | :--- | :---: | :---: |
| **Biter** | Outdoor daytime roamer & night horde | `dl_zombie_biter.glb` | `65` | `14` (`9.1` day) |
| **Volatile** | Dark Bio-Lab bunker & night runner | `dl_zombie_volatile.glb` | `65` | `14` |
| **Goon (Brute)** | Day 2+ heavy horde (`1.22×` scale) | `dl_zombie_goon.glb` | `150` | `26` |

---

## 📂 Project Architecture

```text
Sunfall/
├── project.godot                     # Godot 4.7 config & UpdateManager autoload
├── AGENTS.md                         # Project workflow & documentation rules
├── Play_Game.bat / Update_Game.bat   # Bundled launcher, asset import & git pull
├── Open_In_Godot_Editor.bat          # Godot Editor launcher
├── Push_To_GitHub.bat                # Push main branch to GitHub
├── engine.zip / git.zip              # Bundled Godot 4.7.2 & MinGit
├── tools/
│   ├── ensure_git.bat                # Portable git unpack & ZIP->clone bootstrap
│   ├── extract_ref_assets.py         # 7D2D reference asset extractor
│   ├── extract_dl_assets.py          # Dying Light RP6L archive & FPP player extractor
│   ├── rig_and_animate_dl.py         # Blender 5.3.0 rigging (EyeCamera + 28 .scr-timed clips)
│   ├── re_dl_data.py                 # Data0.pak / Data2.pak / .rpack catalog extractor
│   └── re_dl_binary.py               # gamedll_x64_rwdi.dll RTTI/VTable & disassembly mapper
├── docs/
│   └── dl1_re/                       # Reverse-engineered Dying Light 1 data & binary specs (01..06)
├── scenes/
│   └── main.tscn                     # Root world scene
├── scripts/
│   ├── autoload/
│   │   └── update_manager.gd         # Async git fetch/pull/hard-reset + headless re-import
│   ├── world.gd                      # Island geometry, day/night director, HUD, pause/updater UI
│   ├── player.gd                     # FPP controller, DL1 parkour, melee/dropkick, building, FPP rig
│   ├── zombie.gd                     # Sunlight-lore infected AI, lunge, stun, 7-clip animation state
│   ├── structure.gd                  # Barricade walls (T1/T2) & LOS auto-turrets
│   ├── loot_container.gd             # Interactive crates + Survivor Sense highlights
│   ├── loot_table.gd                 # Seeded deterministic loot & weapon tier stats
│   ├── ref_assets.gd                 # Manifest-driven GLB/texture/audio/icon loader with fallbacks
│   ├── sfx.gd                        # Audio playback with procedural 16-bit PCM synth fallback
│   ├── dl_reference.gd               # Dying Light 1 Data0.pak tuning constants & PASS/FAIL spec evaluator
│   └── dl_telemetry.gd               # 60Hz movement ring-buffer, transition log, F3 scorecard & JSON dump
├── tests/
│   ├── verify_prototype.gd           # Headless SceneTree prototype & gameplay verification
│   └── verify_dl_parity.gd           # Headless physics parity suite (12 DL1 metrics + 23 functional checks)
└── assets_ref/                       # (.gitignore) Local extracted 3D/audio/icon assets
```
