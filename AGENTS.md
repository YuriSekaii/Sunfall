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
