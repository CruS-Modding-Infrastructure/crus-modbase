extends HBoxContainer

var EQUIPMENT_BUTTONS:Array
enum {HEAD, TORSO, LEG, ARM}
var IMPLANTS
var confirmed = false
var cancel = false
var hover_info
var debug = true
var prev_footstep = null
var orbarms: PackedScene
var orig_env = {}

func update_implant_slots():
	$TextureRect / Head_Button.texture_normal = Global.implants.head_implant.texture
	$TextureRect / Torso_Button.texture_normal = Global.implants.torso_implant.texture
	$TextureRect / Arm_Button.texture_normal = Global.implants.arm_implant.texture
	$TextureRect / Leg_Button.texture_normal = Global.implants.leg_implant.texture

func reset_implants_state():
	var gp = Global.player
	var imenu = gp.get_parent().get_node("Stock_Menu/Character_Container/Implant_Menu")
	var leg_implant = Global.implants.leg_implant
	var arm_implant = Global.implants.arm_implant
	var head_implant = Global.implants.head_implant
	var torso_implant = Global.implants.torso_implant

	# ammo gland timer
	if arm_implant.regen_ammo:
		gp.weapon.regentimer1 = Timer.new()
		gp.weapon.add_child(gp.weapon.regentimer1)
		gp.weapon.regentimer1.one_shot = true
		gp.weapon.regentimer1.connect("timeout", gp.weapon, "regen_timeout1")
		gp.weapon.regentimer2 = Timer.new()
		add_child(gp.weapon.regentimer2)
		gp.weapon.regentimer2.one_shot = true
		gp.weapon.regentimer2.connect("timeout", gp.weapon, "regen_timeout2")
	else:
		if is_instance_valid(gp.weapon.regentimer1):
			gp.weapon.regentimer1.queue_free()
		if is_instance_valid(gp.weapon.regentimer2):
			gp.weapon.regentimer2.queue_free()

	# angular advantage sight line
	gp.weapon.IM2.clear()

	# biothrusters
	gp.weapon.kicktimer = 51
	gp.weapon.kickflag = false
	gp.friction_disabled = false

	# goggles
	if !is_instance_valid(gp.get_node_or_null("NV")):
		gp.add_child(load(Mod.get_node("CruS Mod Base").modpath + "/scenes/NV.tscn").instance())
	gp.get_node("NV").hide()
	gp.hazmat = false
	if head_implant.nightvision or head_implant.nightmare or head_implant.holy:
		gp.get_node("NV").show()
	gp.shader_screen.material.set_shader_param("scope", head_implant.nightvision)
	gp.shader_screen.material.set_shader_param("nightmare_vision", head_implant.nightmare)
	gp.shader_screen.material.set_shader_param("holy_mode", head_implant.holy)

	# cortical scaledown+
	var player_gpos = Vector3.ZERO + gp.global_transform.origin
	if Global.implants.head_implant.shrink:
		gp.get_parent().scale = Vector3(0.1, 0.1, 0.1)
	else:
		gp.get_parent().scale = Vector3(1, 1, 1)
	gp.global_transform.origin = player_gpos

	# tattered hat
	# TODO: figure out clean way to toggle rain in realtime
	#		from multiple places for official and custom levels
#	if head_implant.fishing_bonus:
#		Global.rain = true
#	gp.shader_screen.material.set_shader_param("rain", Global.rain)
#	for node in Global.current_scene.get_children():
#		if node.get_script() \
#		and (node.get_script().get_path() == "res://Scripts/Night_Cycle.gd" \
#		or node.get_script().get_path() == "res://MOD_CONTENT/CruS Mod Base/scripts/Night_Cycle.gd"):
#			var has_isc = false
#			if is_instance_valid(node.init_sky_color):
#				has_isc = true
#			if Global.rain:
#				if orig_env.empty():
#					orig_env["fd_begin"] = node.env.environment.fog_depth_begin
#					orig_env["fd_end"] = node.env.environment.fog_depth_end
#					orig_env["al_color"] = Color(node.env.environment.ambient_light_color.to_html())
#					orig_env["bg_mode"] = node.env.environment.background_mode
#					orig_env["init_fog"] = Color(node.init_fog.to_html())
#					orig_env["init_sc"] = Color(node.init_sky_color.to_html()) if has_isc else null
#					var debug_tab = get_parent().get_node("TabContainer/Debug")
#					if is_instance_valid(debug_tab) and "orig_env" in debug_tab:
#						debug_tab.orig_env = orig_env
#				if Global.CURRENT_LEVEL != Global.L_SWAMP:
#					node.env.environment.fog_depth_begin = 0
#					node.env.environment.fog_depth_end = 100
#					node.env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
#				node.init_fog = Color(0.6, 0.6, 0.6)
#				node.init_sky_color = Color(0.6, 0.6, 0.6)
#				node.env.environment.background_mode = 1
#			elif !orig_env.empty():
#				node.env.environment.fog_depth_begin = orig_env["fd_begin"]
#				node.env.environment.fog_depth_end = orig_env["fd_end"]
#				node.env.environment.ambient_light_color = orig_env["al_color"]
#				node.init_fog = orig_env["init_fog"]
#				node.init_sky_color = orig_env["init_sc"]
#				node.env.environment.background_mode = orig_env["bg_mode"]
#	if Global.rain and (gp.weapon.weapon1 == gp.weapon.W_ROD or gp.weapon.weapon2 == gp.weapon.W_ROD):
#		Global.music.stop()
#		Global.music.stream = load("res://Sfx/Music/rain.ogg")
#		Global.music.play()
#	elif Global.music.stream and Global.music.stream.resource_path == "res://Sfx/Music/rain.ogg":
#		Global.music.stop()
#		Global.music.stream = Global.LEVEL_SONGS[Global.CURRENT_LEVEL]
#		Global.music.play()

	gp.jump_bonus = leg_implant.jump_bonus + torso_implant.jump_bonus + head_implant.jump_bonus + arm_implant.jump_bonus

	# orb suit
	if gp.weapon.has_node("orbarms"):
		gp.weapon.get_node("orbarms").hide()
		gp.health = clamp(gp.health, 0, 100)
		gp.UI.set_health(gp.health)
		gp.get_node("Foot_Step").stream = load("res://Sfx/wood01.wav")
		match Global.player.weapon.held_weapon:
			1:
				gp.weapon.current_weapon = gp.weapon.weapon1
			2:
				gp.weapon.current_weapon = gp.weapon.weapon2
		if torso_implant.orbsuit:
			gp.orb = true
		else:
			gp.orb = false
		gp.weapon.orb = gp.orb
		if gp.orb:
			gp.weapon.get_node("orbarms").show()
			gp.weapon.weapon1 = null
			gp.weapon.weapon2 = null
			gp.weapon.current_weapon = null
			gp.weapon.anim.stop()
			gp.weapon.anim.play("Nogun", - 1, 100)
			gp.health = 200
			gp.UI.set_health(gp.health)
			gp.jump_bonus += 3
			gp.speed_bonus += 1
			print("orb walk ", gp.get_node("Foot_Step").stream.resource_path)
			if gp.get_node("Foot_Step").stream.resource_path != "res://Sfx/orbwalk.wav":
				prev_footstep = gp.get_node("Foot_Step").stream
			gp.get_node("Foot_Step").stream = load("res://Sfx/orbwalk.wav")

	gp.speed_bonus = leg_implant.speed_bonus + torso_implant.speed_bonus + head_implant.speed_bonus + arm_implant.speed_bonus
	if Global.husk_mode:
		gp.speed_bonus += 0.25
	if Global.death:
		gp.speed_bonus += 0.1
	gp.armor = clamp(leg_implant.armor + torso_implant.armor + head_implant.armor + arm_implant.armor, 0.5, 1.0)

	# hazmat suit
	if leg_implant.toxic_shield or torso_implant.toxic_shield or arm_implant.toxic_shield or head_implant.toxic_shield or gp.orb:
		gp.hazmat = true

	# biosuit
	if torso_implant.terror:
		gp.terrorsuit.show()
		gp.UI.hide()
		gp.shader_screen.material.set_shader_param("scope", true)
	else:
		gp.terrorsuit.hide()
		gp.UI.show()
		gp.shader_screen.material.set_shader_param("scope", head_implant.nightvision) # prevent conflict with nvgs

	# cursed torch
	if arm_implant.cursed_torch and !Global.hope_discarded:
		Global.set_hope()
	elif !Global.hope_discarded:
		gp.curse_torch.hide()
		gp.curse_torch.light_energy = 0

func _ready():
	yield (get_tree(), "idle_frame")
	$ConfirmationDialog.get_cancel().connect("pressed", self, "_on_Cancel_Pressed")
	$TextureRect / Arm_Button.connect("pressed", self, "_slot_button_pressed", [ARM])
	$TextureRect / Arm_Button.connect("mouse_entered", self, "_slot_button_entered", [ARM])
	$TextureRect / Leg_Button.connect("pressed", self, "_slot_button_pressed", [LEG])
	$TextureRect / Leg_Button.connect("mouse_entered", self, "_slot_button_entered", [LEG])
	$TextureRect / Head_Button.connect("pressed", self, "_slot_button_pressed", [HEAD])
	$TextureRect / Head_Button.connect("mouse_entered", self, "_slot_button_entered", [HEAD])
	$TextureRect / Torso_Button.connect("pressed", self, "_slot_button_pressed", [TORSO])
	$TextureRect / Torso_Button.connect("mouse_entered", self, "_slot_button_entered", [TORSO])
	hover_info = get_parent().get_parent().get_parent().get_node("Hover_Panel/Hover_Info")
	IMPLANTS = Global.implants.IMPLANTS
	for b in range(64):
		var new_button = TextureButton.new()
		$Equip_Grid.add_child(new_button)
		if b < IMPLANTS.size():
			new_button.name = IMPLANTS[b].i_name
			new_button.texture_normal = IMPLANTS[b].texture
			if !debug and Global.implants.purchased_implants.find(IMPLANTS[b].i_name) == - 1:
				new_button.modulate = Color(1, 0, 0)
				if IMPLANTS[b].hidden:
					new_button.modulate = Color(1, 1, 1)
					new_button.texture_normal = load("res://Textures/Menu/mystery.png")
		else:
			new_button.name = "n/a"
			new_button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		new_button.rect_size = Vector2(64, 64)
		new_button.expand = true

		new_button.connect("pressed", self, "_on_implant_pressed", [b])
		new_button.connect("mouse_entered", self, "_on_mouse_entered", [b])
		new_button.connect("mouse_exited", self, "_on_mouse_exited", [b])
		new_button.size_flags_horizontal = SIZE_EXPAND_FILL
		new_button.size_flags_vertical = SIZE_EXPAND_FILL
		new_button.stretch_mode = TextureButton.STRETCH_SCALE
		EQUIPMENT_BUTTONS.append(new_button)
		reset_implants_state()

func clear_equips():
	Global.implants.head_implant = Global.implants.empty_implant
	Global.implants.leg_implant = Global.implants.empty_implant
	Global.implants.arm_implant = Global.implants.empty_implant
	Global.implants.torso_implant = Global.implants.empty_implant
	$TextureRect / Head_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Torso_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Leg_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Arm_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")

func _slot_button_pressed(type):
	match type:
		HEAD:
			$Unequip.play()
			hover_info.get_parent().hide()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.head_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.head_implant = Global.implants.empty_implant
			$TextureRect / Head_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")

		TORSO:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.torso_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.torso_implant = Global.implants.empty_implant
			$TextureRect / Torso_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		LEG:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.leg_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.leg_implant = Global.implants.empty_implant
			$TextureRect / Leg_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		ARM:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.arm_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.arm_implant = Global.implants.empty_implant
			$TextureRect / Arm_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	reset_implants_state()

func _slot_button_entered(type):
	match type:
		HEAD:
			if Global.implants.head_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.head_implant))
		TORSO:
			if Global.implants.torso_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.torso_implant))
		ARM:
			if Global.implants.arm_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.arm_implant))
		LEG:
			if Global.implants.leg_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.leg_implant))

func update_buttons():
	for i in range(IMPLANTS.size()):
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(IMPLANTS[i].i_name) != - 1:
			EQUIPMENT_BUTTONS[i].texture_normal = IMPLANTS[i].texture
		elif Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == - 1:
			EQUIPMENT_BUTTONS[i].modulate = Color(1, 0, 0)
		if Global.implants.purchased_implants.find(IMPLANTS[i].i_name) != - 1 and EQUIPMENT_BUTTONS[i].modulate != Color(0.5, 0.5, 0.5):
			EQUIPMENT_BUTTONS[i].modulate = Color(1, 1, 1)

func _on_mouse_entered(i):
	if i < IMPLANTS.size():
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == - 1:
			hover_info.get_node("Image").show()
			hover_info.get_parent().raise()
			hover_info.get_node("Name").text = "???"
			hover_info.get_node("Hint").text = "Somewhere in this world something is waiting for you."
			hover_info.get_node("Image").texture = load("res://Textures/Menu/mystery.png")
			hover_info.get_parent().show()
			return
		hover_info.get_node("Image").show()
		hover_info.get_parent().raise()
		hover_info.get_node("Name").text = IMPLANTS[i].i_name
		hover_info.get_node("Image").texture = IMPLANTS[i].texture
		var infotext = IMPLANTS[i].explanation
		hover_info.get_node("Hint").text = ""
		if IMPLANTS[i].head:
			hover_info.get_node("Hint").text += "Slot: Head\n"
		if IMPLANTS[i].torso:
			hover_info.get_node("Hint").text += "Slot: Chest\n"
		if IMPLANTS[i].legs:
			hover_info.get_node("Hint").text += "Slot: Legs\n"
		if IMPLANTS[i].arms:
			hover_info.get_node("Hint").text += "Slot: Arms\n"
		if !debug and Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == - 1:
			hover_info.get_node("Hint").text += "$" + str(IMPLANTS[i].price) + "\n"
		hover_info.get_node("Hint").show()
		hover_info.get_node("Hint").text += infotext + "\n"
		if IMPLANTS[i].armor != 1:
			hover_info.get_node("Hint").text += "Armor: " + str(100 - IMPLANTS[i].armor * 100, "%") + "\n"
		if IMPLANTS[i].speed_bonus != 0:
			hover_info.get_node("Hint").text += "Speed: " + str(IMPLANTS[i].speed_bonus) + "\n"
		if IMPLANTS[i].jump_bonus != 0:
			hover_info.get_node("Hint").text += "Jump bonus: " + str(IMPLANTS[i].jump_bonus) + "\n"
		hover_info.get_parent().show()

func _on_mouse_exited(i):
	hover_info.get_node("Image").hide()
	hover_info.get_parent().hide()

func _on_implant_pressed(i):
	if i < IMPLANTS.size():
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == - 1:
			return
		if !debug and Global.implants.purchased_implants.find(IMPLANTS[i].i_name) == - 1:
			cancel = false
			if Global.money >= IMPLANTS[i].price:
				$ConfirmationDialog.popup(Rect2(get_global_mouse_position(), Vector2(256, 128)))
				$ConfirmationDialog.dialog_text = "Do you want to purchase " + IMPLANTS[i].i_name + " for $" + str(IMPLANTS[i].price) + "?"
				while confirmed == false and cancel == false:
					yield (get_tree(), "idle_frame")
				confirmed = false
				if cancel == true:
					cancel = false
					return
				cancel = false
				var m = Global.money
				Global.money -= IMPLANTS[i].price
				if Global.money < 0:
					Global.money = m
					return
				if IMPLANTS[i].i_name == "House":
					Global.BONUS_UNLOCK.append("House")
				EQUIPMENT_BUTTONS[i].modulate = Color(1, 1, 1)
				$TextureRect / Money.text = str("$", Global.money)
				Global.implants.purchased_implants.append(IMPLANTS[i].i_name)
				Global.save_game()
			return

		$Equip.play()
		if IMPLANTS[i].head:
			if Global.implants.head_implant != Global.implants.empty_implant:
				_slot_button_pressed(HEAD)
			Global.implants.head_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Head_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].torso:
			if Global.implants.torso_implant != Global.implants.empty_implant:
				_slot_button_pressed(TORSO)
			Global.implants.torso_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Torso_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].legs:
			if Global.implants.leg_implant != Global.implants.empty_implant:
				_slot_button_pressed(LEG)
			Global.implants.leg_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Leg_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].arms:
			if Global.implants.arm_implant != Global.implants.empty_implant:
				_slot_button_pressed(ARM)
			Global.implants.arm_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Arm_Button.texture_normal = IMPLANTS[i].texture
		reset_implants_state()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		cancel = true
	if is_visible():
		var scale = Vector2(get_parent().rect_size.x / 384, get_parent().rect_size.y / 384)
		var btn_size = Vector2(24, 32) * scale
		$TextureRect / Head_Button.rect_size = btn_size
		$TextureRect / Torso_Button.rect_size = btn_size
		$TextureRect / Arm_Button.rect_size = btn_size
		$TextureRect / Leg_Button.rect_size = btn_size
		$TextureRect / Head_Button.rect_position = Vector2(84, 20) * scale
		$TextureRect / Torso_Button.rect_position = Vector2(84, 72) * scale
		$TextureRect / Arm_Button.rect_position = Vector2(42, 140) * scale
		$TextureRect / Leg_Button.rect_position = Vector2(42, 278) * scale


func _on_ConfirmationDialog_confirmed():
	confirmed = true
func _on_Cancel_Pressed():
	cancel = true

