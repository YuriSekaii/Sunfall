mod dl_reference;
mod dl_telemetry;
mod loot_table;
mod sfx;

use godot::prelude::*;

struct SunfallRustExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SunfallRustExtension {}
