# Sunfall — Agent Project Rules

Follow these rules on every task in this repository:

1. **Read `README.md` first** before inspecting code, making changes, or answering questions about the project.
2. **Document every core mechanic system in `README.md`** and update `README.md` after every change (mechanics, tuning numbers, controls, weapons, enemies, loot pools, structures, and architecture). Keep documentation informative, straightforward, and concise.
3. **Commit and Git Push after every change**:
   - Stage changes with `git add`, commit with a clear descriptive message, and push with `git push origin main`.
   - **Never** commit `.gitignore`d temporary reference assets (`assets_ref/`) or large unpacked runtime binaries.
4. **Verify with Godot 4.7.2 Headless CLI** before committing script/scene changes:
   - `--headless --import`
   - `--headless --check-only` on modified `.gd` scripts
   - `--headless --script res://tests/verify_prototype.gd` (must print `ALL CHECKS PASSED` and exit `0`).
5. **Save mechanic exploration reports to `report/`**:
   - Report to `C:\Users\Admin\Desktop\Code\SelfMadeProduct\Game\Sunfall\report` (`report/`) for all insights and findings when exploring Dying Light, 7 Days to Die (7D2D), or The Forest game mechanics.
6. **Read actual reference game files directly before implementing or tuning mechanics — NEVER invent, guess, or improvise out-of-the-box mechanics or animations**:
   - Dying Light 1 took a decade of engineering and already solved movement, combat feel, weapon inertia/rebound, and physical interaction. Every agent's job is strictly to inspect how Dying Light 1 actually works in its files/binaries and implement that exact system.
   - **Dying Light 1**: `D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com` (`DW/Data0.pak`..`Data3.pak`, `DW/Data/*.rpack`, `gamedll_x64_rwdi.dll`, `engine_x64_rwdi.dll`).
   - **7 Days to Die**: `D:\Program File\7.Days.To.Die.v3.3.0\7.Days.To.Die.v3.3.0\game`.
7. **Use REA (`D:\Program File\rea`, `https://github.com/morluto/rea`)** as the primary reverse-engineering workflow for inspecting reference binaries and game artifacts:
   - Entrypoint: `node "D:\Program File\rea\scripts\rea.mjs"` (or `rea` CLI / MCP once registered).
   - Skill reference: `D:\Program File\rea\skills\reverse-engineer-anything\SKILL.md`.
   - Runtime prerequisite: Node.js `22.x (>=22.23.4)`, `24.x (>=24.22.1)`, or `>=26.12.1`; fall back to Python `pefile`/`capstone` only when REA's Node prerequisite or native provider is unavailable, and report the blocker.
8. **Write in Rust (`rust/`, `godot-rust` GDExtension `api-4-7`) if it is better**:
   - Prefer Rust over GDScript for CPU-heavy loops, DSP/audio synthesis, deterministic math/physics kernels, binary/asset parsing, ring-buffers/telemetry, and performance- or safety-critical simulation logic.
   - Keep thin Godot scene-tree/UI glue in GDScript where GDScript is simpler and faster to iterate.
   - When modifying `rust/`, run `cargo test --lib` and `cargo build --release` in `rust/` and copy `rust/target/release/sunfall_rust.dll` to `addons/sunfall_rust/bin/sunfall_rust.dll` before Godot headless verification.
