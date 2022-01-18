extends Node

const MAX_LAST_KEYS_SIZE = 10

onready var CMB = Mod.get_node("CruS Mod Base")
onready var original_melee_script = load("res://Scripts/Enemy_Melee_Weapon.gd")
onready var new_melee_script = load(CMB.modpath + "/scripts/Enemy_Melee_Weapon.gd")
onready var Noclip = load(CMB.modpath + "/scenes/noclip.tscn")
onready var Prompt = load(CMB.modpath + "/scenes/CheatPrompt.tscn")

var enabled := []
var cheated := false

var noclip_inst = null
var prompt_inst = null

var inf_mag := false
var inf_jump := false
var inf_arm_aug := false
var disable_ai := false
var npc_ffa := false
var zombie := false

var last_keys := ""
var last_armor := 0
var last_arm_aug_ammo := 1
var last_col_layer := 2
var scene_npcs := []
var hostile_queue := []

func _process(delta):
	if inf_mag:
		var wep = Global.player.weapon
		var cur_wep = wep.weapon1 if wep.held_weapon == 1 else wep.weapon2
		if cur_wep or cur_wep == 0:
			wep.magazine_ammo[cur_wep] = wep.MAX_MAG_AMMO[cur_wep]
			wep.set_UI_ammo()
	if inf_jump:
		Global.player.double_jump_flag = 1
	if inf_arm_aug:
		Global.player.weapon.item_consumed = false
		Global.player.weapon.grenade_ammo = max(last_arm_aug_ammo, 1)
	if zombie:
		Global.player.armor = 0
	if npc_ffa:
		var remove = []
		for i in range(0, hostile_queue.size()):
			var npc = hostile_queue[i]
			if is_instance_valid(npc):
				set_npc_ffa_state(npc, npc_ffa)
				if npc.civ_killer:
					remove.append(i)
		for i in remove:
			hostile_queue.remove(i)

func _input(ev):
	if not(ev is InputEventKey and ev.is_pressed()):
		return
	if ev.get_scancode() == KEY_ENTER and !cheated and is_instance_valid(Global.nav):
		if last_keys.find("CEOMINDSET") != -1:
			enable_cheat_prompt()
	elif !cheated:
		var key = ev.as_text()
		if len(key) == 1:
			if len(last_keys) >= MAX_LAST_KEYS_SIZE:
				last_keys = last_keys.substr(1)
			last_keys += key
	if (ev is InputEventWithModifiers
			and (enabled.has("noclip") or enabled.has("debug"))
			and ev.get_scancode() == KEY_N
			and ev.shift):
		toggle_noclip()

func exit_game() -> void:
	# $SFX / Select.play()
	get_tree().quit()

func _exit_tree():
	if is_instance_valid(prompt_inst):
		# E 0:15:15.034   remove_child: Parent node is busy setting up children, remove_node() failed. Consider using call_deferred("remove_child", child) instead.
		# get_node("/root").remove_child(prompt_inst)
		get_node("/root").call_deferred("remove_child", prompt_inst)
		prompt_inst.queue_free()

func reset_noclip():
	if is_instance_valid(noclip_inst) and !noclip_inst.in_use:
		noclip_inst.queue_free()
	noclip_inst = null

func toggle_noclip():
	if (is_instance_valid(Global.player) and
			Global.menu.in_game and
			not in_noclip()):
		enter_noclip()
	else:
		exit_noclip()

func in_noclip() -> bool:
	return is_instance_valid(noclip_inst) and noclip_inst.in_use

func enter_noclip(hide_nodes := true) -> void:
	if is_instance_valid(noclip_inst):
		noclip_inst.queue_free()

	noclip_inst = Noclip.instance()
	Global.current_scene.add_child(noclip_inst)
	noclip_inst.player_use(hide_nodes)

func exit_noclip(show_nodes := true):
	if in_noclip():
		noclip_inst.player_exit(show_nodes)
		reset_noclip()

func toggle_zombie():
	if is_instance_valid(Global.player):
		if !enabled.has("zombie"):
			Global.player.UI.notify("Disconnecting your flow of Life", Color(1, 1, 1))
			enabled.append("zombie")
			last_armor = Global.player.armor
			zombie = true
		else:
			Global.player.UI.notify("Reconnecting your flow of Life", Color(0.7, 0.7, 0.7))
			zombie = false
			Global.player.armor = last_armor
			enabled.remove(enabled.find("zombie"))

func toggle_vanish():
	if is_instance_valid(Global.player):
		if !enabled.has("psychopass"):
			Global.player.UI.notify("Now untargetable by the violence of this world", Color(1, 1, 1))
			enabled.append("psychopass")
			last_col_layer = Global.player.collision_layer
			Global.player.collision_layer = 0
		else:
			Global.player.UI.notify("Now targetable by the violence of this world", Color(0.7, 0.7, 0.7))
			Global.player.collision_layer = last_col_layer
			enabled.remove(enabled.find("psychopass"))

func toggle_infinite_magazine():
	if is_instance_valid(Global.player):
		if !enabled.has("magpump"):
			Global.player.UI.notify("Activated infinite magazine", Color(1, 1, 1))
			enabled.append("magpump")
			inf_mag = true
		else:
			Global.player.UI.notify("Deactivated infinite magazine", Color(0.7, 0.7, 0.7))
			enabled.remove(enabled.find("magpump"))
			inf_mag = false

func toggle_infinite_jump():
	if is_instance_valid(Global.player):
		if !enabled.has("hoptoit"):
			Global.player.UI.notify("Activated infinite jumps", Color(1, 1, 1))
			enabled.append("hoptoit")
			inf_jump = true
		else:
			Global.player.UI.notify("Deactivated infinite jumps", Color(0.7, 0.7, 0.7))
			enabled.remove(enabled.find("hoptoit"))
			inf_jump = false

func toggle_infinite_arm_aug():
	if is_instance_valid(Global.player):
		if !enabled.has("kitted"):
			Global.player.UI.notify("Activated infinite arm implant uses", Color(1, 1, 1))
			enabled.append("kitted")
			last_arm_aug_ammo = Global.player.weapon.grenade_ammo
			inf_arm_aug = true
		else:
			Global.player.UI.notify("Deactivated infinite arm implant uses", Color(0.7, 0.7, 0.7))
			enabled.remove(enabled.find("kitted"))
			inf_arm_aug = false

func is_npc(node) -> bool:
	if node.get_script():
		var spath = node.get_script().get_path()
		match spath:
			"res://Scripts/EnemyHandler.gd", \
			"res://grid_enemy.gd", \
			"res://Scripts/abraxas.gd", \
			"res://Scripts/Abraxas_Laser.gd", \
			"res://Scripts/Abraxas_Rocket.gd", \
			"res://snake.gd", \
			"res://snakehead.gd":
				return true
	return false

func get_npc_list(parent):
	if not (parent and is_instance_valid(parent)):
		return []

	var npcs = []
	for node in parent.get_children():
		if node is Area:
			npcs += get_npc_list(node)

		if is_npc(node):
			var body = node.get_node_or_null("Body")

			if body:
				body = body[0] if body is Array else body
				if body.get_script():
					npcs.append(body)
			else:
				npcs.append(node)

			if node.name == "abraxas":
				npcs.append(node.get_node("Armature/Skeleton/BoneAttachment 3/Left_Tail"))
				npcs.append(node.get_node("Armature/Skeleton/BoneAttachment 4/Right_Tail"))
			if node.get_script().get_path() == "res://snake.gd":
				npcs.append(node.get_node("snake/Armature/Bone/Bone001/Bone002/Bone003/Bone004/Bone005/KinematicBody"))
	return npcs

func populate_npc_list():
	scene_npcs = []
	var lvl = get_node("/root/Level")
	var qmap = lvl.get_node_or_null("QodotMap")
	lvl = lvl[0] if lvl is Array else lvl
	qmap = qmap[0] if qmap is Array else qmap
	scene_npcs = get_npc_list(lvl)
	if !qmap:
		push_warning("Loaded level doesn't seem to have a QodotMap")
	else:
		scene_npcs += get_npc_list(qmap)

func toggle_disable_ai():
	if !enabled.has("lightsout"):
		Global.player.UI.notify("Pausing AI processes", Color(1, 1, 1))
		enabled.append("lightsout")
		disable_ai = true
		populate_npc_list()
	else:
		Global.player.UI.notify("Resuming AI processes", Color(0.7, 0.7, 0.7))
		enabled.remove(enabled.find("lightsout"))
		disable_ai = false
	for npc in scene_npcs:
		if is_instance_valid(npc):
			npc.set_physics_process(!disable_ai)
			npc.set_process(!disable_ai)
	if !disable_ai:
		scene_npcs = []

func toggle_death():
	if is_instance_valid(Global.player):
		if !enabled.has("soulswap"):
			enabled.append("soulswap")
		if Global.death:
			Global.player.UI.notify("Reverting to normal soul", Color(0, 1, 0))
			Global.death = false

			Global.UI.health_texture.texture = Global.UI.HEALTH
		else:
			Global.player.UI.notify("Changing to emulated soul", Color(1, 0, 1))
			Global.death = true
			Global.UI.health_texture.texture = Global.UI.DEATH
		Global.player.r = Global.status()

func set_npc_ffa_state(npc, enabled):
	if "weapon" in npc and npc.player_distance < npc.ai_distance:
		var wep = npc.weapon
		if "melee" in npc and npc.melee:
			var raycast = wep.raycast
			var dmg = wep.damage
			var toxic = wep.toxic
			var vel_boost = wep.velocity_booster
			wep.set_script(new_melee_script if enabled else original_melee_script)
			wep.set_process(true)
			wep.raycast = raycast
			wep.damage = dmg
			wep.toxic = toxic
			wep.velocity_booster = vel_boost
		if "civ_killer" in npc:
			npc.civ_killer = enabled
			if "magazine_ammo" in wep:
				wep.magazine_ammo[wep.current_weapon] = wep.MAX_AMMO[wep.current_weapon] * (3 if enabled else 1)
			var wep_cast = npc.get_node_or_null("Rotation_Helper/Weapon/RayCast")
			if wep_cast:
				wep_cast.set_collision_mask_bit(2, enabled)
				wep_cast.set_collision_mask_bit(4, enabled)
				if npc.melee:
					wep_cast.set_collision_mask_bit(3, enabled)

func toggle_npc_ffa():
	if !enabled.has("friday"):
		Global.player.UI.notify("Accidentally releasing mind-altering gas", Color(1, 1, 1))
		enabled.append("friday")
		npc_ffa = true
		populate_npc_list()
	else:
		Global.player.UI.notify("Dissipating mind-altering gas", Color(0.7, 0.7, 0.7))
		enabled.remove(enabled.find("friday"))
		npc_ffa = false
	for npc in scene_npcs:
		if is_instance_valid(npc) and npc.get_script().get_path() == "res://Scripts/E_Grunt_Movement_New.gd":
			set_npc_ffa_state(npc, npc_ffa)
			if !npc.civ_killer:
				hostile_queue.append(npc)

func enable_debug_menus():
	if is_instance_valid(Global.player) and Global.player.get_parent().get_node_or_null("Stock_Menu"):
		Global.player.UI.notify("Enabled debug menus", Color(1, 1, 1))
		Mod.get_node("CruS Mod Base/LevelEditor").add_debug_menus()

# Moved to separate function to allow initialization from context other than _input
func enable_cheat_prompt(silent = false) -> void:

	if cheated == true:
		return

	if not silent:
		Global.player.UI.notify("Cheat prompt activated", Color(1, 1, 1))

	prompt_inst = Prompt.instance()
	prompt_inst.cheats = self

	get_node("/root").add_child(prompt_inst)

	cheated = true
