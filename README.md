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
| **Move** | `W`, `A`, `S`, `D` | Walk (`3.5 m/s`), strafe/backpedal (`2.5 m/s`) |
| **Look** | `Mouse` | First-person look; click window to capture cursor, `Esc` to unlock/pause |
| **Sprint** | `Shift` (hold + `W`) | `6.0 m/s`, drains `0.10` stamina/s, `+4.5°` FOV |
| **Jump / Vault / Wall-Jump** | `Space` | Jump (`5.6 m/s`), ledge vault/mantle, zombie vault (while sprinting), or wall-jump during Tic-Tac wall-run |
| **Crouch / Slide / Landing Roll** | `Ctrl` or `C` | Crouch (`1.5 m/s`), crouch-slide while sprinting (`8.4 m/s`), or parkour landing roll within `1.0s` of impact |
| **Quick Dodge / Sidestep** | `Alt` + `A` / `D` / `S` | `0.22s` burst at `12.5 m/s` (`0.20` stamina, `0.55s` cd) |
| **Melee Swing / Build / Repair** | `Left Mouse Button` | Slot 1: tap for L/R combo (`0.60s`), hold `>= 0.35s` for Heavy Power Swing; Slot 2/3: repair or place structure |
| **Upgrade Wall** | `Right Mouse Button` | Upgrades targeted Wood Wall to Reinforced Metal (`2 Metal`) |
| **Kick / Dropkick** | `Q` | Grounded kick (`0.625s` cycle, `0` stamina); mid-air + `W` triggers Dropkick (`0.35` stamina, `2.0×` knockback) |
| **Loot / Search** | `E` (hold) | Searches targeted container (`0.60s`–`0.95s`) |
| **Survivor Sense** | `V` | `3.5s` sonar pulse (`6.0s` cd) highlighting unlooted crates (gold) & infected within `45m` (red) through walls |
| **Hotbar Slots** | `1`, `2`, `3` | `1` Melee Weapon, `2` Wood Wall, `3` Auto-Turret |
| **Flashlight** | `F` | Toggles head-mounted `SpotLight3D` (`24m` range) |
| **Use Medkit** | `H` | Consumes 1 Medkit (`+50 HP`) |
| **Eat / Drink** | `G` | Consumes Water (`+45 Thirst`) or Food (`+45 Hunger`), prioritizing lowest need |
| **Skip Phase** | `T` | Advances current day/night timer to `0.05s` (testing shortcut) |
| **Pause / Restart** | `Esc` / `R` | `Esc` toggles pause + updater menu; `R` restarts on death/victory |

---

## 🏃 Core Mechanic Systems

### 1. Dying Light 1 Movement & Parkour (`scripts/player.gd`)
* **Base Kinematics**: Walk `3.5 m/s`, Back/Strafe `2.5 m/s`, Sprint `6.0 m/s`, Crouch `1.5 m/s`, Gravity `18.0 m/s²`, Air Control `0.22`, Jump `5.6 m/s` (`0.4s` cooldown).
* **Tic-Tac Wall-Run & Wall-Jump**: Running/jumping alongside a vertical surface engages up to `1.1s` wall-run (`WALL_RUN_EXTRA_GRAVITY = 9.5`, `±11°` camera roll, wall-footstep SFX). Pressing `Space` kicks upward & away (`WALL_JUMP_BACK_HEIGHT = 0.8`, up to `MAX_WALL_JUMPS = 2` chained jumps before touching ground).
* **Low Vault vs. High Ledge Mantle**:
  * **Low Vault (`0.45m`–`1.25m`)**: `0.20s` traversal preserving sprint momentum (`vault` animation).
  * **High Ledge Mantle (`1.25m`–`2.45m`)**: `0.34s` pull-up with camera dip (`climb_ledge` animation).
* **Fall Damage & Parkour Landing Roll**: Falls `> 4.8m` deal `clamp((fall_dist - 4.8) * 14.0, 8.0, 95.0)` HP unless `Ctrl`/`C` is pressed/held within `CROUCH_DAMPING_WINDOW_TIME = 1.0s` before impact, which triggers a `0.48s` `360°` forward roll (`7.8 m/s`, `0` fall damage).
* **Crouch-Slide & Vault-Over-Zombie**: Sliding (`0.50s` at `8.4 m/s`) knocks back infected (`6.0` dmg, `8.0` impulse, `0.7s` stagger). Sprinting + `Space` within `1.85m` of a zombie vaults overhead and stuns it for `2.5s`.
* **Survival Needs**: Max HP `100` (slow passive regen up to `25 HP` after `4.0s`); Stamina `1.0` (exhausted until `0.33`, regenerates at `0.45/s` or `0.22/s` when starving/dehydrated); Hunger `-0.16/s`, Thirst `-0.22/s` (`0` causes `-20%` speed and `-0.35 HP/s` down to `1 HP`).

### 2. Melee Combat & Weapons (`scripts/player.gd`, `scripts/loot_table.gd`)
* **Alternating Combo & Apex Timing**: Light swings alternate left/right (`0.60s` cycle, `±6°` camera roll) and connect at the swing apex (`0.16s` light, `0.22s` heavy), triggering a `0.045s` local hit-pause on both FPP rig and target zombie plus particle bursts.
* **Charged Heavy Swing**: Holding `LMB >= 0.35s` and releasing deals `1.8×` damage, `13.5` knockback, `0.95s` stagger (`1.5×` stamina cost).
* **Kick & Dropkick**: Grounded `Q` (`0.625s` cycle, `0.25s` hit beat, `0` stamina) deals `8.0` dmg, `11.5` knockback, `1.1s` stagger. Mid-air forward `Q` Dropkick (`0.35` stamina) deals `18.0` dmg, `23.0` knockback, `1.6s` stagger, with `0.28s` landing recovery.

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
│   ├── extract_dl_assets.py          # Dying Light RP6L archive extractor
│   └── rig_and_animate_dl.py         # Blender 5.3.0 rigging & NLA animation exporter
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
│   └── sfx.gd                        # Audio playback with procedural 16-bit PCM synth fallback
├── tests/
│   └── verify_prototype.gd           # Headless SceneTree verification suite
└── assets_ref/                       # (.gitignore) Local extracted 3D/audio/icon assets
```
