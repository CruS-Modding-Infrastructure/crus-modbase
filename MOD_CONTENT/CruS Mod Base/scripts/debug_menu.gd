extends Container

const WEP_NAMES = [
	"Parasonic D2 Silenced Pistol",
	"K&H R5",
	"SNOOZEFEST Animal Control Pistol",
	"Expandable Baton",
	"Balotelli Hypernova",
	"Security Systems Anti-Armor Device",
	"Stern AWS 3000",
	"K&H X20",
	"Minato M9",
	"New Safety M62",
	"Riot Pacifier",
	"AMG4",
	"Precise Industries AS15",
	"Mowzer SP99",
	"Security Systems Cerebral Bore",
	"Spectacular Dynamics MCR Carbine",
	"Bolt ACR",
	"Flashlight",
	"Zippy 3000",
	"BN-99",
	"BAG-82",
	"Stern M17",
	"Parasonic C3 DNA Scrambler",
	"Fiberglass Fishing Rod",
	"RPO-80 Sanitization System",
	"ZKZ Transactional Rifle",
	"Parasonic MP-1 Nailer",
	"Raymond Shocktroop Tactical",
	"Abscess Ironworks Lux ff374f727ce9d6d6e93be0793733c321"
]

var WEP_ICONS = [
	load("res://Textures/Menu/Weapon_Buttons/Pistol.png"), 
	load("res://Textures/Menu/Weapon_Buttons/SMG.png"), 
	load("res://Textures/Menu/Weapon_Buttons/tranq.png"), 
	load("res://Textures/Menu/Weapon_Buttons/baton.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Shotgun.png"), 
	load("res://Textures/Menu/Weapon_Buttons/RL.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Sniper.png"), 
	load("res://Textures/Menu/Weapon_Buttons/AR.png"), 
	load("res://Textures/Menu/Weapon_Buttons/S_SMG.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Nambu.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Gas_Launcher.png"), 
	load("res://Textures/Menu/Weapon_Buttons/MG3.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Autoshotgun.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Mauser.png"), 
	load("res://Textures/Menu/Weapon_Buttons/Bore.png"), 
	load("res://Textures/Menu/Weapon_Buttons/MKR.png"), 
	load("res://Textures/Menu/Weapon_Buttons/radgun.png"), 
	load("res://Textures/Menu/Weapon_Buttons/flashlight.png"), 
	load("res://Textures/Menu/Weapon_Buttons/zippy.png"), 
	load("res://Textures/Menu/Weapon_Buttons/AN94.png"), 
	load("res://Textures/Menu/Weapon_Buttons/vag72.png"), 
	load("res://Textures/Menu/Weapon_Buttons/steyr.png"), 
	load("res://Textures/Menu/Weapon_Buttons/dna.png"), 
	load("res://Textures/Menu/Weapon_Buttons/rod.png"), 
	load("res://Textures/Menu/Weapon_Buttons/flamethrower.png"), 
	load("res://Textures/Menu/Weapon_Buttons/SKS.png"), 
	load("res://Textures/Menu/Weapon_Buttons/nailer.png"), 
	load("res://Textures/Menu/Weapon_Buttons/shockwave.png"), 
	load("res://Textures/Menu/Weapon_Buttons/light.png"),
	load("res://Textures/rank_letters/N.png")
]

onready var wep_img_rects = [
	get_node("MarginContainer/VBoxContainer/Weapon_Select/HBoxContainer3/Weapon1/TextureRect"),
	get_node("MarginContainer/VBoxContainer/Weapon_Select/HBoxContainer3/Weapon2/TextureRect")
]

onready var dropdowns = [
	get_node("MarginContainer/VBoxContainer/Weapon_Select/HBoxContainer3/Weapon1/MenuButton"),
	get_node("MarginContainer/VBoxContainer/Weapon_Select/HBoxContainer3/Weapon2/MenuButton")
]

onready var border_warn = get_node("MarginContainer/VBoxContainer/Temp_Level_Settings/Border_Warning")
onready var time_slider_box = get_node("MarginContainer/VBoxContainer/Temp_Level_Settings/Time_Slider/HBoxContainer/")
onready var rain_toggle = get_node("MarginContainer/VBoxContainer/Temp_Level_Settings/Toggle_Rain/HBoxContainer/CheckButton")
onready var temp_lvl_settings = get_node("MarginContainer/VBoxContainer/Temp_Level_Settings")
onready var cheats = get_tree().root.get_node("Level/Cheats")
onready var g_light = get_tree().root.get_node("Level/Global_Light")

enum Dropdowns { D_WEAPON1, D_WEAPON2 }

var last_dropdown_id: int
var orig_env := {}

func _ready():
	#for i in range(0, len(WEP_ICONS)):
	#	var img = WEP_ICONS[i].get_data()
	#	img.resize(64, 64)
	#	var nt = ImageTexture.new()
	#	nt.create_from_image(img)
	#	WEP_ICONS[i] = nt
	
	# hide level debug settings if level doesn't have custom Night_Cycle.gd
	if !("orig_env" in g_light) or !("debug_time" in g_light):
		temp_lvl_settings.visible = false
	
	# init weapons
	if Global.implants.torso_implant != Global.implants.IMPLANTS[8]:
		Global.implants.torso_implant.orbsuit = false
	Global.player.weapon.weapon1 = Global.menu.weapon_1
	Global.player.weapon.weapon2 = Global.menu.weapon_2
	Global.player.weapon.held_weapon == 1
	reset_weapon_model(Global.menu.weapon_1)
	var d = get_node("MarginContainer/Weapon_Menu")
	for n in WEP_NAMES:
		d.add_item(n)
	d.connect("id_pressed", self, "_on_id_pressed")
	var play_ready = is_instance_valid(Global.player.weapon)
	if play_ready:
		update_weapons()
	
	# init border
	var bm = get_node("MarginContainer/VBoxContainer/Player_Border/Border_Menu")
	if Global.soul_intact:
		Global.border.texture = Global.BORDERS[1]
		bm.selected = 2
	elif Global.husk_mode:
		Global.border.texture = Global.BORDERS[2]
		bm.selected = 0
	elif Global.hope_discarded:
		Global.border.texture = Global.BORDERS[3]
		bm.selected = 3
	else :
		Global.border.texture = Global.BORDERS[0]
		bm.selected = 1
		
	# init death health
	var dt = get_node("MarginContainer/VBoxContainer/Toggle_Death/HBoxContainer/CheckButton")
	dt.pressed = Global.death
	
func _process(delta):
	if Global.rain:
		rain_toggle.pressed = true

func update_weapons():
	var weps = [Global.player.weapon.weapon1, Global.player.weapon.weapon2]
	wep_img_rects[0].texture = WEP_ICONS[weps[0]] if weps[0] != null else WEP_ICONS.back()
	wep_img_rects[1].texture = WEP_ICONS[weps[1]] if weps[1] != null else WEP_ICONS.back()
	dropdowns[0].text = WEP_NAMES[weps[0]] if weps[0] != null else ""
	dropdowns[1].text = WEP_NAMES[weps[1]] if weps[1] != null else ""

func reset_weapon_model(wep_id):
	Global.player.weapon.current_weapon = wep_id
	Global.player.weapon.anim.stop()
	Global.player.weapon.anim.play("Nogun", - 1, 100)
	Global.player.weapon.set_UI_ammo()

func _on_id_pressed(id):
	if last_dropdown_id < 2:
		wep_img_rects[last_dropdown_id].texture = WEP_ICONS[id]
		dropdowns[last_dropdown_id].text = WEP_NAMES[id]
		open_weapon_popup()
	match last_dropdown_id:
		Dropdowns.D_WEAPON1:
			Global.player.weapon.weapon1 = id
			if Global.player.weapon.held_weapon == 1:
				reset_weapon_model(id)
		Dropdowns.D_WEAPON2:
			Global.player.weapon.weapon2 = id
			if Global.player.weapon.held_weapon == 2:
				reset_weapon_model(id)

func _on_MenuButton_toggled(button_pressed, id):
	if button_pressed:
		last_dropdown_id = id
		open_weapon_popup()

func open_weapon_popup():
	var wm = get_node("MarginContainer/Weapon_Menu")
	wm.set_as_minsize()
	wm.popup_centered_clamped(get_viewport_rect().size)

func _on_TextureRect_gui_input(event, id):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		dropdowns[id].pressed = true


func _on_Select_Implants_toggled(button_pressed):
	get_parent().get_parent().get_node("Implant_Menu").visible = button_pressed
	get_parent().get_parent().get_node("VBoxContainer").visible = !button_pressed
	get_parent().get_parent().get_parent().rect_size.x *= 1.6 if button_pressed else 0.625


func _on_Death_Toggle_toggled(button_pressed):
	Global.death = button_pressed
	if Global.death:
		Global.UI.health_texture.texture = Global.UI.DEATH
	else:
		Global.UI.health_texture.texture = Global.UI.HEALTH
	Global.player.r = Global.status()

func _on_Weapon_Menu_popup_hide():
	dropdowns[last_dropdown_id].pressed = false


func _on_Border_Menu_item_selected(index):
	match index:
		0:
			if Global.hope_discarded:
				Global.player.UI.notify("Hope manifested", Color(1, 1, 1))
				Global.hope_discarded = false
			if Global.soul_intact:
				Global.player.UI.notify("Divine link severed", Color(0, 0, 1))
				Global.soul_intact = false
			if Global.money < 0:
				Global.money = 0
			Global.husk_mode = true
			Global.consecutive_deaths = 0
			Global.border.texture = Global.BORDERS[2]
		1:
			if Global.hope_discarded:
				Global.player.UI.notify("Hope manifested", Color(1, 1, 1))
				Global.hope_discarded = false
			if Global.husk_mode:
				Global.player.UI.notify("Bodily autonomy regained", Color(1, 0.5, 0.5))
				Global.husk_mode = false
			if Global.soul_intact:
				Global.player.UI.notify("Divine link severed", Color(0, 0, 1))
				Global.soul_intact = false
			Global.border.texture = Global.BORDERS[0]
		2:
			Global.set_soul()
		3:
			Global.set_hope()
	border_warn.visible = Global.border.texture == Global.BORDERS[3]


func _on_Noclip_toggled(button_pressed):
	var taking_preview_image = false
	if get_node("../Level"):
		taking_preview_image = get_node("../Level").taking_preview_image
	if is_instance_valid(cheats):
		if button_pressed:
			cheats.enter_noclip(!taking_preview_image)
		elif is_instance_valid(cheats.noclip_inst):
			cheats.noclip_inst.keep_weapon_disabled = true
			cheats.exit_noclip(!taking_preview_image)

func _on_Debug_visibility_changed():
	update_weapons()
	var ret_btn = get_node("MarginContainer/VBoxContainer/Show_Reticle/HBoxContainer/CheckButton")
	ret_btn.pressed = Global.player.reticle.visible
	if is_instance_valid(cheats):
		var nc_btn = get_node("MarginContainer/VBoxContainer/Noclip/HBoxContainer/CheckButton")
		nc_btn.pressed = cheats.in_noclip()
	border_warn.visible = Global.border.texture == Global.BORDERS[3]

# doesn't really work because most weapons automatically force showing it
func _on_Show_Reticle_toggled(button_pressed):
	if button_pressed:
		Global.player.reticle.show()
	else:
		Global.player.reticle.hide()


func _on_Time_value_changed(value):
	if "debug_time" in g_light:
		g_light.debug_time = value
		if value == -1:
			time_slider_box.get_node("Label").text = " NOW  "
		elif value == 0:
			time_slider_box.get_node("Label").text = " 12 AM"
		elif value == 12:
			time_slider_box.get_node("Label").text = " 12 PM"
		else:
			var pad = "  " if value < 10 else " "
			var xm = " AM" if value < 12 else " PM"
			time_slider_box.get_node("Label").text = pad + str(int(value) % 12) + xm

func _on_Rain_toggled(button_pressed):
	Global.rain = button_pressed
	Global.player.shader_screen.material.set_shader_param("rain", Global.rain)
	var has_isc = false
	if is_instance_valid(g_light.init_sky_color):
		has_isc = true
	if Global.rain:
		if Global.CURRENT_LEVEL != Global.L_SWAMP:
			g_light.env.environment.fog_depth_begin = 0
			g_light.env.environment.fog_depth_end = 100
			g_light.env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		g_light.init_fog = Color(0.6, 0.6, 0.6)
		g_light.init_sky_color = Color(0.6, 0.6, 0.6)
		g_light.env.environment.background_mode = 1
	else:
		g_light.env.environment.fog_depth_begin = g_light.orig_env["fd_begin"]
		g_light.env.environment.fog_depth_end = g_light.orig_env["fd_end"]
		g_light.env.environment.ambient_light_color = g_light.orig_env["al_color"]
		g_light.init_fog = g_light.orig_env["init_fog"]
		g_light.init_sky_color = g_light.orig_env["init_sc"]
		g_light.env.environment.background_mode = g_light.orig_env["bg_mode"]
	var wep = Global.player.weapon
	if Global.rain and (wep.weapon1 == wep.W_ROD or wep.weapon2 == wep.W_ROD):
		Global.music.stop()
		Global.music.stream = load("res://Sfx/Music/rain.ogg")
		Global.music.play()
	elif Global.music.stream and Global.music.stream.resource_path == "res://Sfx/Music/rain.ogg":
		Global.music.stop()
		Global.music.stream = Global.LEVEL_SONGS[Global.CURRENT_LEVEL]
		Global.music.play()
