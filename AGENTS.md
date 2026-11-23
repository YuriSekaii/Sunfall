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
6. **Read actual reference game files directly before implementing or tuning mechanics** (never guess or invent parameters):
   - **Dying Light 1**: `D:\Program File\Dying.Light.v1.54.0_LinkNeverDie.Com.part3\Dying.Light.v1.54.0_LinkNeverDie.Com` (`DW/Data0.pak`..`Data3.pak`, `DW/Data/*.rpack`, `gamedll_x64_rwdi.dll`, `engine_x64_rwdi.dll`).
   - **7 Days to Die**: `D:\Program File\7.Days.To.Die.v3.3.0\7.Days.To.Die.v3.3.0\game`.
