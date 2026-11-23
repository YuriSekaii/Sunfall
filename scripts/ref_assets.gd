class_name RefAssets
extends RefCounted

const MANIFEST_PATH := "res://assets_ref/manifest.json"
const DL_RIGGED_MANIFEST_PATH := "res://assets_ref/dl_rigged/manifest.json"

static var _manifest_loaded: bool = false
static var _manifest: Dictionary = {}
static var _dl_manifest_loaded: bool = false
static var _dl_manifest: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}


static func _ensure_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var txt := FileAccess.get_file_as_string(MANIFEST_PATH)
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_manifest = parsed


static func is_available() -> bool:
	_ensure_manifest()
	return not _manifest.is_empty()


static func get_manifest() -> Dictionary:
	_ensure_manifest()
	return _manifest


static func get_model_entry(key: String) -> Dictionary:
	_ensure_manifest()
	var models: Variant = _manifest.get("models", {})
	if models is Dictionary and models.has(key):
		var entry: Variant = models[key]
		if entry is Dictionary:
			return entry
	return {}


static func get_mesh(key: String) -> Mesh:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var entry := get_model_entry(key)
	var path := String(entry.get("mesh", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is Mesh:
		_mesh_cache[key] = res
		return res
	return null


static func get_model_texture(key: String) -> Texture2D:
	var entry := get_model_entry(key)
	var path := String(entry.get("texture", ""))
	return _load_tex_path(path)


static func get_texture(key: String) -> Texture2D:
	_ensure_manifest()
	var textures: Variant = _manifest.get("textures", {})
	if textures is Dictionary and textures.has(key):
		return _load_tex_path(String(textures[key]))
	return null


static func get_icon(key: String) -> Texture2D:
	_ensure_manifest()
	var icons: Variant = _manifest.get("icons", {})
	if icons is Dictionary and icons.has(key):
		return _load_tex_path(String(icons[key]))
	return null


static func get_audio(key: String) -> AudioStream:
	if _audio_cache.has(key):
		return _audio_cache[key]
	_ensure_manifest()
	var audio: Variant = _manifest.get("audio", {})
	if not (audio is Dictionary) or not audio.has(key):
		return null
	var path := String(audio[key])
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is AudioStream:
		_audio_cache[key] = res
		return res
	return null


static func _load_tex_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is Texture2D:
		_tex_cache[path] = res
		return res
	return null


static func make_model_material(key: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.78
	var tex := get_model_texture(key)
	if tex != null:
		mat.albedo_texture = tex
	return mat


static func create_normalized_model(key: String, target_height: float, target_max_horiz: float = 0.0, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mesh := get_mesh(key)
	if mesh == null:
		return null
	var entry := get_model_entry(key)
	var bounds: Dictionary = entry.get("bounds", {})
	var sz: Array = bounds.get("size", [1.0, 1.0, 1.0])
	var mn: Array = bounds.get("min", [0.0, 0.0, 0.0])
	var ctr: Array = bounds.get("center", [0.0, 0.5, 0.0])

	var sx := maxf(0.001, float(sz[0]))
	var sy := maxf(0.001, float(sz[1]))
	var sz_z := maxf(0.001, float(sz[2]))

	var s := 1.0
	if target_height > 0.0:
		s = target_height / sy
	elif target_max_horiz > 0.0:
		s = target_max_horiz / maxf(sx, sz_z)

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(-float(ctr[0]) * s, -float(mn[1]) * s, -float(ctr[2]) * s)
	inst.material_override = make_model_material(key, tint)
	return inst


static func apply_weapon_to_mesh(inst: MeshInstance3D, key: String, target_len: float = 0.62, tint: Color = Color.WHITE) -> bool:
	var mesh := get_mesh(key)
	if mesh == null or inst == null:
		return false
	var entry := get_model_entry(key)
	var bounds: Dictionary = entry.get("bounds", {})
	var sz: Array = bounds.get("size", [0.2, 0.5, 0.2])
	var ctr: Array = bounds.get("center", [0.0, 0.0, 0.0])
	var max_dim := maxf(0.001, maxf(float(sz[0]), maxf(float(sz[1]), float(sz[2]))))
	var s := target_len / max_dim

	inst.mesh = mesh
	inst.scale = Vector3(s, s, s)
	inst.position = Vector3(-float(ctr[0]) * s, -float(ctr[1]) * s, -float(ctr[2]) * s - 0.12)
	if float(sz[1]) > float(sz[2]):
		inst.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	else:
		inst.rotation_degrees = Vector3(15.0, 180.0, 0.0)
	inst.material_override = make_model_material(key, tint)
	return true


static func _ensure_dl_manifest() -> void:
	if _dl_manifest_loaded:
		return
	_dl_manifest_loaded = true
	if not FileAccess.file_exists(DL_RIGGED_MANIFEST_PATH):
		return
	var txt := FileAccess.get_file_as_string(DL_RIGGED_MANIFEST_PATH)
	if txt.is_empty():
		return
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		_dl_manifest = parsed


static func has_dl_rigged() -> bool:
	_ensure_dl_manifest()
	return not _dl_manifest.is_empty()


static func get_dl_manifest() -> Dictionary:
	_ensure_dl_manifest()
	return _dl_manifest


static func instantiate_dl_glb(glb_path: String) -> Node3D:
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return null
	var packed: PackedScene = null
	if _scene_cache.has(glb_path):
		packed = _scene_cache[glb_path]
	else:
		var res := ResourceLoader.load(glb_path)
		if res is PackedScene:
			packed = res
			_scene_cache[glb_path] = packed
	if packed == null:
		return null
	var inst := packed.instantiate()
	if inst is Node3D:
		return inst as Node3D
	if inst != null:
		inst.queue_free()
	return null


static func instantiate_dl_player_fpp() -> Node3D:
	_ensure_dl_manifest()
	var pf: Variant = _dl_manifest.get("player_fpp", {})
	if pf is Dictionary:
		return instantiate_dl_glb(String(pf.get("glb", "")))
	return null


static func instantiate_dl_zombie(key: String) -> Node3D:
	_ensure_dl_manifest()
	var zombies: Variant = _dl_manifest.get("zombies", {})
	if zombies is Dictionary and zombies.has(key):
		var entry: Variant = zombies[key]
		if entry is Dictionary:
			return instantiate_dl_glb(String(entry.get("glb", "")))
	return null


static func instantiate_dl_weapon(key: String) -> Node3D:
	_ensure_dl_manifest()
	var weapons: Variant = _dl_manifest.get("weapons", {})
	if weapons is Dictionary and weapons.has(key):
		var entry: Variant = weapons[key]
		if entry is Dictionary:
			return instantiate_dl_glb(String(entry.get("glb", "")))
	return null


static func find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node == null:
		return null
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null


static func find_skeleton(root_node: Node) -> Skeleton3D:
	if root_node == null:
		return null
	if root_node is Skeleton3D:
		return root_node as Skeleton3D
	for child in root_node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null


static func set_loop_mode_for_clips(anim_player: AnimationPlayer, looping_clips: Array[String]) -> void:
	if anim_player == null:
		return
	for clip in looping_clips:
		if anim_player.has_animation(clip):
			var anim := anim_player.get_animation(clip)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
