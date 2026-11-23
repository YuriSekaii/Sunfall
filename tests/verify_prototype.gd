extends SceneTree

var _failed: bool = false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		printerr("ASSERTION FAILED: " + msg)
		_failed = true


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	# 1. LootTable determinism and non-empty items for crash, supply, lab
	for pool in ["crash", "supply", "lab"]:
		var roll_a := LootTable.roll_container(42424, 7, pool, 1)
		var roll_b := LootTable.roll_container(42424, 7, pool, 1)
		_check(roll_a == roll_b, "LootTable.roll_container must be deterministic for pool '%s'" % pool)
		var items: Dictionary = roll_a.get("items", {})
		_check(not items.is_empty(), "LootTable.roll_container must return non-empty items for pool '%s'" % pool)

	# 2. Instantiate res://scenes/main.tscn and verify spawned entities
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "Failed to load res://scenes/main.tscn")
	if main_scene == null:
		quit(1)
		return

	var world := main_scene.instantiate()
	world.set("run_seed", 54321)
	root.add_child(world)

	# Step a couple frames so deferred children and _process/_physics_process run cleanly
	await process_frame
	await physics_frame

	var players := get_nodes_in_group("player")
	_check(players.size() == 1 and players[0] is Player, "Expected 1 Player in group 'player'")

	var containers := get_nodes_in_group("loot_containers")
	_check(containers.size() > 0, "Expected LootContainers in group 'loot_containers'")

	var bunker_zombies: Array[Zombie] = []
	var outdoor_zombies: Array[Zombie] = []
	for node in get_nodes_in_group("enemies"):
		if node is Zombie:
			var z := node as Zombie
			if z.is_bunker_enemy:
				bunker_zombies.append(z)
			else:
				outdoor_zombies.append(z)

	_check(bunker_zombies.size() > 0, "Expected at least 1 bunker Zombie")
	_check(outdoor_zombies.size() > 0, "Expected at least 1 outdoor Zombie")

	# 2b. Verify outdoor zombies spawn >= 20m from player start and HUD ignores mouse
	var player := players[0] as Player
	for oz in outdoor_zombies:
		var d2 := Vector2(oz.global_position.x - player.global_position.x, oz.global_position.z - player.global_position.z).length()
		_check(d2 >= 20.0, "Outdoor zombie spawned too close to player: %.2fm" % d2)

	var hud_nodes := world.find_children("*", "CanvasLayer", true, false)
	_check(hud_nodes.size() > 0, "Expected CanvasLayer HUD in main.tscn")
	var overlay_panel: PanelContainer = world.get("_overlay_panel")
	_check(overlay_panel != null and not overlay_panel.visible, "Pause/Overlay panel must stay hidden during gameplay")
	if hud_nodes.size() > 0:
		for ctrl in hud_nodes[0].find_children("*", "Control", true, false):
			if ctrl is Control:
				if overlay_panel != null and (ctrl == overlay_panel or overlay_panel.is_ancestor_of(ctrl)):
					continue
				_check((ctrl as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD Control '%s' must have MOUSE_FILTER_IGNORE" % ctrl.name)

	# 2c. Simulated InputEventMouseMotion rotates Player yaw and head/camera pitch
	var yaw_before := player.rotation.y
	var pitch_before := player._head.rotation.x
	player.allow_headless_mouse_look_for_test = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120.0, -80.0)
	root.push_input(motion)
	await process_frame
	_check(not is_equal_approx(player.rotation.y, yaw_before), "Simulated InputEventMouseMotion must rotate Player yaw")
	_check(not is_equal_approx(player._head.rotation.x, pitch_before), "Simulated InputEventMouseMotion must rotate Player head/camera pitch")
	player.allow_headless_mouse_look_for_test = false

	# 3. Sunlight lore checks
	if bunker_zombies.size() > 0:
		_check(bunker_zombies[0].is_active_state(false) == true, "Bunker zombie must be active during day")
	if outdoor_zombies.size() > 0:
		_check(outdoor_zombies[0].is_active_state(false) == false, "Outdoor zombie must be passive during day")
		_check(outdoor_zombies[0].is_active_state(true) == true, "Outdoor zombie must be active during night")

	# 4. Building loop: Structure ("wall"), damage, repair, upgrade
	var wall := Structure.new()
	wall.configure("wall")
	world.add_child(wall)
	wall.global_position = Vector3(5.0, 0.0, 5.0)
	_check(wall.tier == 1 and is_equal_approx(wall.max_hp, 120.0), "New wall should be tier 1 with 120 max_hp")

	wall.take_damage(45.0)
	_check(is_equal_approx(wall.hp, 75.0), "Wall HP after 45 damage should be 75.0")

	var repaired := wall.repair(25.0)
	_check(repaired and is_equal_approx(wall.hp, 100.0), "Wall repair should succeed and raise HP to 100.0")

	var upgraded := wall.upgrade()
	_check(upgraded and wall.tier == 2 and is_equal_approx(wall.max_hp, 280.0) and is_equal_approx(wall.hp, 280.0), "Wall upgrade should set tier == 2 and max_hp == 280.0")

	# 5. Looting a LootContainer via open_and_roll
	if containers.size() > 0 and containers[0] is LootContainer:
		var lc := containers[0] as LootContainer
		_check(lc.is_looted == false, "Fresh LootContainer should not be looted")
		var loot_res := lc.open_and_roll(54321, 1)
		_check(lc.is_looted == true, "LootContainer must be marked is_looted == true after open_and_roll")
		var loot_items: Dictionary = loot_res.get("items", {})
		_check(not loot_items.is_empty(), "open_and_roll must return items")

	# 6. Night horde trigger on world
	_check(world.get("is_night") == false, "World should start in daytime")
	world.call("start_night_horde_for_test")
	_check(world.get("is_night") == true, "start_night_horde_for_test() must set is_night == true")
	_check(int(world.get("horde_to_spawn")) > 0, "start_night_horde_for_test() must set horde_to_spawn > 0")

	# 7. RefAssets manifest & real extracted meshes/textures/audio/icons resolve cleanly
	_check(RefAssets.is_available(), "RefAssets must load res://assets_ref/manifest.json")
	for model_key in ["zombie_lab", "zombie_hazmat", "zombie_mutated", "plane", "crate", "barricade", "turret", "weapon_pipe", "weapon_machete", "weapon_axe", "weapon_hammer"]:
		_check(RefAssets.get_mesh(model_key) != null, "RefAssets.get_mesh('%s') must resolve" % model_key)
		_check(RefAssets.get_model_texture(model_key) != null, "RefAssets.get_model_texture('%s') must resolve" % model_key)
	for tex_key in ["grass", "dirt", "rock", "concrete", "wood", "metal"]:
		_check(RefAssets.get_texture(tex_key) != null, "RefAssets.get_texture('%s') must resolve" % tex_key)
	for audio_key in ["melee_swing", "melee_hit", "zombie_groan", "zombie_attack", "footstep", "turret_shot", "ambient_night", "music_night"]:
		_check(RefAssets.get_audio(audio_key) != null, "RefAssets.get_audio('%s') must resolve" % audio_key)
	for icon_key in ["wood", "metal", "gunpowder", "food", "water", "medkit", "pipe", "machete", "axe", "wall", "turret"]:
		_check(RefAssets.get_icon(icon_key) != null, "RefAssets.get_icon('%s') must resolve" % icon_key)

	# 8. DL1 combat & parkour sanity checks (combo alternation, Survivor Sense, zombie stun)
	var side_a := player._combo_side
	player._melee_swing(false)
	_check(player._pending_melee_timer > 0.0, "Melee swing must schedule delayed apex hit")
	var side_b := player._combo_side
	_check(side_a != side_b, "Alternating melee combo must flip _combo_side")
	_check(player.trigger_survivor_sense() == true, "trigger_survivor_sense() must activate")
	_check(bool(player.get_hud_state().get("sense_active", false)) == true, "Survivor Sense must report sense_active == true")

	# 8b. Fall damage + Active Parkour Landing Roll damping
	player.hp = 100.0
	player._crouch_damping_timer = 0.8
	player._resolve_landing(8.0)
	_check(is_equal_approx(player.hp, 100.0), "Landing roll within crouch window must deal 0 fall damage")
	_check(player._landing_roll_timer > 0.0, "Landing roll must start _landing_roll_timer")
	player._landing_roll_timer = 0.0
	player._crouch_damping_timer = 0.0
	player._resolve_landing(8.0)
	_check(player.hp < 100.0, "Hard landing > 4.8m without crouch must deal fall damage")
	player.hp = 100.0

	# 8c. Wall-run & Wall-jump check next to the corridor wall (inner face at x = -13.4, wall center x = -13.1)
	player.global_position = Vector3(-13.9, 1.5, -7.5)
	player.rotation.y = 0.0
	player.velocity = Vector3(0.0, 0.5, -5.0)
	await physics_frame
	var started_wr := player._try_start_wall_run(Vector2(0.0, -1.0))
	_check(started_wr and player._wall_running, "Player airborne alongside wall must start wall-run")
	if player._wall_running:
		player._perform_wall_jump()
		_check(not player._wall_running and player._wall_jumps_used == 1 and player.velocity.y > 5.0, "Wall-jump must launch player off wall")

	# 8d. Low vault (1.2m) & High ledge climb (2.2m) checks
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-7.5, 0.0, 0.2)
	player.rotation.y = 0.0
	player._vaulting = false
	await physics_frame
	var vaulted_low := player._try_vault()
	_check(vaulted_low and player._vault_kind == "vault", "1.2m obstacle must trigger low 'vault'")
	player._vaulting = false

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-8.5, 0.0, -4.2)
	player.rotation.y = 0.0
	await physics_frame
	var climbed_high := player._try_vault()
	_check(climbed_high and player._vault_kind == "climb_ledge", "2.2m obstacle must trigger high 'climb_ledge'")
	player._vaulting = false

	# 8e. Melee apex hit, Dropkick, and Vault-Over-Zombie checks
	var test_z := Zombie.new()
	test_z.configure(true, false)
	world.add_child(test_z)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.0, 8.0)
	player.rotation.y = 0.0
	player._head.rotation.x = 0.0
	test_z.global_position = Vector3(0.0, 0.0, 6.6)
	await physics_frame

	var hp_before_apex := test_z.hp
	player._attack_cd = 0.0
	player._melee_swing(false)
	for _i in 15:
		await physics_frame
	_check(test_z.hp < hp_before_apex, "Melee swing must connect at apex (~0.16s) and damage zombie")

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.0, 8.0)
	test_z.global_position = Vector3(0.0, 0.0, 6.6)
	test_z.stagger_timer = 0.0
	await physics_frame

	var hp_before_dk := test_z.hp
	var dk_hit := player._execute_kick_hit(true)
	_check(dk_hit and test_z.hp < hp_before_dk and test_z.knockback_vel.length() > 15.0, "Dropkick hit must deal damage and heavy 2.0x knockback")

	test_z.global_position = Vector3(0.0, 0.0, 6.6)
	test_z.stagger_timer = 0.0
	var vaulted_z := player._try_vault_over_zombie()
	_check(vaulted_z and player._vaulting and test_z.stagger_timer >= 2.4, "Vault-over-zombie must vault and stun zombie for 2.5s")
	player._vaulting = false

	if outdoor_zombies.size() > 0:
		outdoor_zombies[0].apply_stun(2.5)
		_check(outdoor_zombies[0].stagger_timer >= 2.4, "Zombie apply_stun(2.5) must set stagger_timer >= 2.5")

	# 9. Rigged Dying Light GLB verification (Player FPP + WeaponSocket + Zombies + active animations)
	_check(RefAssets.has_dl_rigged(), "RefAssets.has_dl_rigged() must be true")
	_check(player._fpp_rig != null and player._fpp_skel != null and player._fpp_anim != null, "Player must attach dl_player_fpp.glb with Skeleton3D and AnimationPlayer")
	_check(player._weapon_socket != null and player._weapon_socket.get_child_count() > 0, "Player BoneAttachment3D WeaponSocket must hold weapon mesh")
	if player._fpp_anim != null:
		for req_clip in ["idle", "walk", "sprint", "swing_right", "swing_left", "heavy_charge", "heavy_swing", "kick", "dropkick", "climb_ledge", "vault", "slide", "dodge_left", "dodge_right", "wall_run_left", "wall_run_right"]:
			_check(player._fpp_anim.has_animation(req_clip), "dl_player_fpp.glb missing animation '%s'" % req_clip)
		_check(player._fpp_anim.is_playing(), "Player FPP AnimationPlayer must actively play an animation (not frozen)")

	for z_key in ["dl_zombie_biter", "dl_zombie_volatile", "dl_zombie_goon"]:
		var z_rig := RefAssets.instantiate_dl_zombie(z_key)
		_check(z_rig != null, "Must load '%s' GLB" % z_key)
		if z_rig != null:
			var z_skel := RefAssets.find_skeleton(z_rig)
			var z_anim := RefAssets.find_animation_player(z_rig)
			_check(z_skel != null and z_anim != null, "'%s' must have Skeleton3D and AnimationPlayer" % z_key)
			if z_anim != null:
				for req_z_clip in ["idle_sunlight", "shamble", "chase_run", "attack_swipe", "stagger", "knockdown", "death"]:
					_check(z_anim.has_animation(req_z_clip), "'%s' missing animation '%s'" % [z_key, req_z_clip])
			z_rig.queue_free()

	if outdoor_zombies.size() > 0:
		var oz := outdoor_zombies[0]
		_check(oz._dl_rig != null and oz._anim_player != null and oz._anim_player.is_playing(), "Spawned outdoor zombie must actively play AnimationPlayer clip (not T-pose)")
	if bunker_zombies.size() > 0:
		var bz := bunker_zombies[0]
		_check(bz._dl_rig != null and bz._anim_player != null and bz._anim_player.is_playing(), "Spawned bunker zombie must actively play AnimationPlayer clip (not T-pose)")

	var brute_z := Zombie.new()
	brute_z.configure(false, true, false)
	world.add_child(brute_z)
	await physics_frame
	_check(brute_z._dl_rig != null and is_equal_approx(brute_z._dl_rig.scale.x, 1.22), "Brute zombie must use dl_zombie_goon at 1.22x scale")
	_check(brute_z._anim_player != null and brute_z._anim_player.is_playing(), "Brute zombie must actively play AnimationPlayer clip")

	# 10. UpdateManager autoload & local git detection
	var um := root.get_node_or_null("UpdateManager")
	_check(um != null, "UpdateManager autoload must be registered at /root/UpdateManager")
	if um != null:
		um.call("_detect_local_git_info")
		var branch := String(um.get("current_branch_name"))
		var commit_hash := String(um.get("current_commit_hash"))
		_check(not branch.is_empty() and commit_hash != "unknown" and not commit_hash.is_empty(), "UpdateManager must detect local git branch and short hash (got %s @ %s)" % [branch, commit_hash])

	# Step one more physics/process frame during night to verify night logic runs without errors
	await physics_frame
	await process_frame

	world.queue_free()
	await process_frame

	if _failed:
		quit(1)
	else:
		print("ALL CHECKS PASSED")
		quit(0)
