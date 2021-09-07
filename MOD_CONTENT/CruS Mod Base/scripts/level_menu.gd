extends Container

onready var CMB = Mod.get_node("CruS Mod Base")
onready var debug_lvl_data = CMB.data.debug_level if "debug_level" in CMB.data else null
onready var level_editor = CMB.get_node("LevelEditor")

onready var cheats = get_tree().root.get_node("Level/Cheats")
onready var g_light = get_tree().root.get_node("Level/Global_Light")
onready var env = get_tree().root.get_node("Level/WorldEnvironment")

onready var level_container = get_node("MarginContainer/VBoxContainer")
onready var preview_box = get_node("MarginContainer/Preview_Box")
onready var preview_image = get_node("MarginContainer/VBoxContainer/Preview_Image/VBoxContainer/TextureRect")
onready var gl_btn = get_node("MarginContainer/VBoxContainer/Toggle_Night_Cycle/HBoxContainer/CheckButton")
onready var gls = get_node("MarginContainer/VBoxContainer/Global_Light_Settings")
onready var gl_dark_btn = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Toggle_Darkness/HBoxContainer/CheckButton")
onready var gl_bright_slide = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/GL_Brightness_Slider/HSlider")
onready var border_warn = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Border_Warning")
onready var reload_container = get_node("MarginContainer/VBoxContainer/Reload_Loading")
onready var reload_bar = get_node("MarginContainer/VBoxContainer/Reload_Loading/MarginContainer/VBoxContainer/ProgressBar")
onready var export_btn = get_node("MarginContainer/VBoxContainer/Export_Level/Button")
# disabled until i figure out exactly what the point of permanight is
onready var gl_permn_btn = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Toggle_Permanight/HBoxContainer/CheckButton")
onready var fog_container = get_node("MarginContainer/VBoxContainer/Fog_Settings/VBoxContainer")
onready var skybox_file_btn = get_node("MarginContainer/VBoxContainer/Skybox_Settings/File/MarginContainer/HBoxContainer/Button")
onready var skybox_file_image = get_node("MarginContainer/VBoxContainer/Skybox_Settings/File/TextureRect")
onready var skybox_file_dropdown = get_node("MarginContainer/Skybox_Popup")

var skybox_files = [
	"res://Textures/sky1.png",
	"res://Textures/sky2.png",
	"res://Textures/sky3.png",
	"res://Textures/sky4.png",
	"res://Textures/sky5.png",
	"res://Textures/sky6.png",
	"res://Textures/sky7.png",
	"res://Textures/sky8.png",
	"res://Textures/sky9.png",
	"res://Textures/sky10.png",
	"res://Textures/sky11.png",
	"res://Textures/skybox1.png",
	"res://Textures/skybox2.png",
	"res://Textures/skybox3.png"
]

var taking_preview_image = false
var cheat_noclip_enabled = false
var reloading_map = false
var last_img: Image
var skybox_file_path = ""
var in_debug_lvl

signal settings_changed

func _ready():
	if cheats:
		cheats.enabled.append("debug")
	var skybox_path = ""
	var cur_lvl_data = Global.LEVEL_META[Global.CURRENT_LEVEL]
	in_debug_lvl = "level_scene" in cur_lvl_data and debug_lvl_data and debug_lvl_data.level_scene == cur_lvl_data.level_scene
	if in_debug_lvl:
		var lvl_dir = debug_lvl_data.level_scene.get_base_dir()
		var f = File.new()
		if !f.file_exists(lvl_dir + "/level.json"):
			save_level_settings()
		elif f.open(lvl_dir + "/level.json", File.READ) == OK:
			var ld = parse_json(f.get_as_text())
			if ld is Dictionary:
				for key in ld.keys():
					CMB.data.debug_level[key] = ld[key]
			else:
				Mod.mod_log("WARNING: Bad JSON file " + lvl_dir + "/level.json", CMB)
			var p_img = Image.new()
			print(get_file_path("image", debug_lvl_data))
			if p_img.load(get_file_path("image", debug_lvl_data)) == OK:
				preview_image.texture = ImageTexture.new()
				preview_image.texture.create_from_image(p_img)
			if "_debug" in ld:
				gl_btn.pressed = ld["_debug"]["g_light_enabled"]
				gl_bright_slide.value = ld["_debug"]["g_light_energy"]
				gl_dark_btn.pressed = ld["_debug"]["g_light_darkness"]
				if "skybox_file_path" in ld["_debug"]:
					skybox_path = ld["_debug"]["skybox_file_path"]
				fog_container.get_node("Height_Min/HSlider").value = ld["_debug"]["fog_height_min"]
				fog_container.get_node("Height_Max/HSlider").value = ld["_debug"]["fog_height_max"]
				fog_container.get_node("Depth_Begin/HSlider").value = ld["_debug"]["fog_depth_begin"]
				fog_container.get_node("Depth_End/HSlider").value = ld["_debug"]["fog_depth_end"]
	level_container.get_node("Reload_Mapfile").visible = in_debug_lvl
	level_container.get_node("Save_Level").visible = in_debug_lvl
	level_container.get_node("Export_Level").visible = in_debug_lvl
	init_skybox_file_entries()
	if skybox_path != "" and add_skybox_file_entry(skybox_path):
		_on_Skybox_Popup_id_pressed(skybox_file_dropdown.get_item_count() - 1)
	skybox_path = env.environment.background_sky.panorama.get_path()
	if skybox_files.find(skybox_path) != -1:
		_on_Skybox_Popup_id_pressed(skybox_files.find(skybox_path))
	connect("settings_changed", self, "_on_settings_changed")

# Copied from init until I make a utility thing
func get_file_path(key: String, dict: Dictionary) -> String:
	var p = ""
	if !dict.has(key) or !dict.get(key): return p
	
	var f = File.new()
	if f.open(dict[key], File.READ) == OK or ResourceLoader.exists(dict[key]):
		p = dict[key]
	elif f.open("res://MOD_CONTENT/" + dict["name"] + "/" + dict[key], File.READ) == OK:
		p = "res://MOD_CONTENT/" + dict["name"] + "/" + dict[key]
	elif f.open("user://levels/" + dict["name"] + "/" + dict[key], File.READ) == OK:
		p = "user://levels/" + dict["name"] + "/" + dict[key]
	f.close()
	return p

func save_level_settings():
	var lvl_dir = debug_lvl_data.level_scene.get_base_dir()
	var f = File.new()
	if f.open(lvl_dir + "/level.json", File.WRITE) == OK:
		var dbg = {}
		if last_img:
			last_img.save_png("user://levels/_debug/preview.png")
			debug_lvl_data.image = "preview.png"
		dbg["g_light_enabled"] = gl_btn.pressed
		dbg["g_light_energy"] = gl_bright_slide.value
		dbg["g_light_darkness"] = gl_dark_btn.pressed
		dbg["skybox_file_path"] = skybox_file_path
		dbg["fog_height_min"] = fog_container.get_node("Height_Min/HSlider").value
		dbg["fog_height_max"] = fog_container.get_node("Height_Max/HSlider").value
		dbg["fog_depth_begin"] = fog_container.get_node("Depth_Begin/HSlider").value
		dbg["fog_depth_end"] = fog_container.get_node("Depth_End/HSlider").value
		debug_lvl_data["_debug"] = dbg
		f.store_string(level_editor.generate_level_json(debug_lvl_data))

func _input(ev):
	if taking_preview_image:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == BUTTON_LEFT:
				get_tree().paused = true
				$Preview_Shutter.play()
				taking_preview_image = false
			elif ev.button_index == BUTTON_RIGHT:
				taking_preview_image = false
				finish_preview_image()
	if in_debug_lvl and ev is InputEventKey and ev.pressed:
		if ev.get_scancode() == KEY_S and ev.control:
			_on_Save_pressed()
		elif (ev.get_scancode() == KEY_R and
			(ev.alt or ev.meta) and
			ev.shift):
			_on_Reload_From_TB_pressed()

func _process(delta):
	if reloading_map:
		get_tree().paused = true
	if gl_bright_slide.visible:
		gl_bright_slide.value = g_light.light_energy

func _on_settings_changed():
	get_node("MarginContainer/VBoxContainer/Save_Level/Button").text = "Save (*)"

func _on_Night_Cycle_Toggle_toggled(button_pressed):
	g_light.visible = button_pressed
	gls.visible = button_pressed
	if !button_pressed:
		if "init_energy_ambient" in g_light:
			env.environment.ambient_light_energy = g_light.init_energy_ambient
			env.environment.fog_color = g_light.init_fog
		if "darkness" in g_light:
			g_light.darkness = false
			gl_dark_btn.pressed = false
		if "permanight" in g_light:
			g_light.permanight = false
			gl_permn_btn.pressed = false
	emit_signal("settings_changed")

func _on_Take_Preview_Image_pressed():
	Global.UI.hide()
	Global.border.hide()
	Global.player.get_parent().hide()
	Global.player.hide()
	Global.player.grab_hand.hide()
	Global.player.reticle.hide()
	get_parent().get_parent().hide()
	Global.menu.set_physics_process(false)
	Global.menu.set_process_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var view = get_viewport().get_texture().get_data()
	var v_sz = view.get_size()
	var pbox = Global.border.get_parent().get_node("Preview_Box")
	if is_instance_valid(pbox) and pbox != preview_box:
		preview_box.queue_free()
		preview_box = pbox
	preview_box.setup(abs(v_sz.x - v_sz.y) / 2)
	preview_box.show()
	taking_preview_image = true
	cheat_noclip_enabled = cheats.enabled.has("noclip")
	if cheat_noclip_enabled:
		cheats.enabled.erase("noclip")

func _on_Preview_Shutter_finished():
	call_deferred("take_preview_image")
	finish_preview_image()
	emit_signal("settings_changed")

func take_preview_image():
	var view = get_viewport().get_texture().get_data()
	var img = Image.new()
	var v_sz = view.get_size()
	img.create(v_sz.y, v_sz.y, false, view.get_format())
	var x_off = abs(v_sz.x - v_sz.y) / 2
	img.blit_rect(view, Rect2(x_off, 0, v_sz.y, v_sz.y), Vector2.ZERO)
	img.resize(240, 240)
	img.flip_y()
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	last_img = img
	var dir = Directory.new()
	if !dir.dir_exists("user://snapshots"):
		dir.make_dir("user://snapshots")
	if dir.open("user://snapshots") == OK:
		var lvl = Global.LEVEL_META[Global.CURRENT_LEVEL]
		var lvl_name = "Level"
		if lvl is String:
			var json = File.new()
			if json.open(lvl, File.READ) == OK:
				lvl = parse_json(json.get_as_text())
				json.close()
		if "name" in lvl:
			lvl_name = lvl.name
		var t = OS.get_datetime()
		var filepath = str("user://snapshots/", lvl_name, "_", 
						 t.year, "-", t.month, "-", t.day, "_", 
						 t.hour, "_", t.minute, "_", t.second, ".png")
		img.save_png(filepath)
		Global.player.UI.notify("Image saved to " + filepath, Color(0.8, 0.8, 0.8))
		Mod.mod_log("Took a level preview snapshot and saved it to " + filepath, CMB)
	preview_image.texture = tex

func finish_preview_image():
	preview_box.hide()
	var cheats = get_tree().root.get_node("Level/Cheats")
	if !(is_instance_valid(cheats) and cheats.in_noclip()):
		Global.UI.show()
		Global.border.show()
		Global.player.get_parent().show()
		Global.player.show()
		Global.player.grab_hand.show()
	Global.player.reticle.show()
	get_parent().get_parent().show()
	Global.menu.set_physics_process(true)
	Global.menu.set_process_input(true)
	var pm = Global.player.get_parent()
	if pm.get_node("Stock_Menu").visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		pm.get_node("Position3D/Rotation_Helper/Weapon").disabled = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		pm.get_node("Position3D/Rotation_Helper/Weapon").disabled = false
	get_tree().paused = false
	if cheat_noclip_enabled:
		cheats.enabled.append("noclip")

func _on_Darkness_toggled(button_pressed):
	g_light.darkness = button_pressed
	gl_bright_slide.editable = !button_pressed
	set_process(button_pressed or reloading_map)
	emit_signal("settings_changed")
	
func _on_Permanight_toggled(button_pressed):
	g_light.permanight = button_pressed
	emit_signal("settings_changed")

func _on_GL_Brightness_value_changed(value):
	if "init_energy" in g_light:
		g_light.init_energy = value
	else:
		g_light.light_energy = value
	emit_signal("settings_changed")

func _on_Reload_From_TB_pressed():
	if level_editor.map_built:
		reload_bar.value = 0
		reload_container.show()
		if !cheats.in_noclip():
			cheats.enter_noclip()
		reloading_map = true
		var qmap = get_tree().root.get_node("Level/QodotMap")
		print(Global.player.get_parent().name)
		if Global.player.get_parent().get_parent() == qmap:
			qmap.remove_child(Global.player.get_parent())
			qmap.get_parent().add_child(Global.player.get_parent())
		level_editor.rebuild_qodotmap(qmap, self, "_on_Reload_Progress", ["Player"])
	else:
		Global.player.UI.notify("Level is still loading, please wait...", Color(1, 0.1, 0.1))
	

func _on_Reload_Progress(build_step, percent):
	reload_bar.value = floor(percent * 100)
	if reload_bar.value == 100:
		reloading_map = false
		get_tree().paused = false
		reload_container.hide()
		

func _on_Save_pressed():
	save_level_settings()
	get_node("MarginContainer/VBoxContainer/Save_Level/Button").text = "Save"
	Global.player.UI.notify("Saved level changes", Color(0.1, 0.1, 1))
	

func _on_Export_pressed():
	var dir = Directory.new()
	var qmap = get_tree().root.get_node("Level/QodotMap")
	var export_folder = "user://levels/" + qmap.map_file.get_file().trim_suffix(".map")
	if dir.dir_exists(export_folder):
		var export_dialog = get_node("MarginContainer/Export_ConfirmationDialog")
		export_dialog.dialog_text = "The folder %s already exists.\nExport anyways and overwrite it?" % export_folder
		export_dialog.set_as_minsize()
		export_dialog.popup_centered()
	else:
		_on_Save_pressed()
		level_editor.export_debug_level(qmap.map_file)
		Global.player.UI.notify("Finished exporting", Color(1, 0, 1))

func _on_Export_ConfirmationDialog_confirmed():
	_on_Save_pressed()
	var qmap = get_tree().root.get_node("Level/QodotMap")
	level_editor.export_debug_level(qmap.map_file)
	Global.player.UI.notify("Finished exporting", Color(1, 0, 1))

func _on_Reset_All_pressed():
	pass

func _on_Level_visibility_changed():
	gl_btn.visible = is_instance_valid(g_light)
	if gl_btn.visible:
		gl_btn.pressed = g_light.visible
		gls.visible = g_light.visible
		gl_dark_btn.visible = "darkness" in g_light
		gls.get_node("VBoxContainer/Darkness_Label").visible = gl_dark_btn.visible
		if gl_dark_btn.visible:
			gl_dark_btn.pressed = g_light.darkness
		#gl_permn_btn.visible = "permanight" in g_light
		#gls.get_node("VBoxContainer/Permanight_Label").visible = gl_permn_btn.visible
		#if gl_permn_btn.visible:
		#	gl_permn_btn.pressed = g_light.permanight
		border_warn.visible = Global.border.texture == Global.BORDERS[3]
	
func _on_Fog_Slider_value_changed(value, dimension, minmax):
	var val = "fog_%s_%s" % [dimension, minmax]
	env.environment.set(val, value)
	emit_signal("settings_changed")

func init_skybox_file_entries():
	for sf in skybox_files:
		var sb = load(sf)
		var icon = ImageTexture.new()
		icon.create_from_image(sb.get_data())
		icon.set_size_override(Vector2(32, 32))
		skybox_file_dropdown.add_icon_item(icon, sf)

func add_skybox_file_entry(filepath) -> bool:
	var sf = Image.new()
	if !(filepath in skybox_files) and sf.load(filepath) == OK:
		skybox_files.append(filepath)
		var icon = ImageTexture.new()
		icon.create_from_image(sf)
		icon.set_size_override(Vector2(32, 32))
		skybox_file_dropdown.add_icon_item(icon, filepath)
		return true
	return false

func _on_Skybox_Popup_id_pressed(id):
	var sb = load(skybox_files[id])
	if !sb:
		sb = Image.new()
		sb.load(skybox_files[id])
	if sb:
		skybox_file_path = skybox_files[id]
		var preview = ImageTexture.new()
		var img = sb if sb is Image else sb.get_data()
		preview.create_from_image(img)
		preview.set_size_override(Vector2(240, 240))
		skybox_file_btn.text = skybox_files[id].get_file()
		skybox_file_btn.icon = skybox_file_dropdown.get_item_icon(id)
		skybox_file_image.texture = preview
		var skytex = ImageTexture.new()
		skytex.create_from_image(img)
		
		env.environment.background_sky.panorama = skytex
		emit_signal("settings_changed")

func _on_Open_Skybox_File_pressed():
	var sfd = get_node("MarginContainer/Skybox_FileDialog")
	sfd.current_dir = debug_lvl_data.level_scene.get_base_dir() if debug_lvl_data else "user://"
	sfd.popup_centered_clamped(get_viewport_rect().size)

func _on_Skybox_FileDialog_files_selected(paths):
	for p in paths:
		add_skybox_file_entry(p)
	if len(paths) == 1:
		_on_Skybox_Popup_id_pressed(skybox_file_dropdown.get_item_count() - 1)


func _on_Skybox_Popup_popup_hide():
	skybox_file_btn.pressed = false

func _on_Skybox_File_Dropdown_toggled(button_pressed):
	if button_pressed:
		skybox_file_dropdown.set_as_minsize()
		skybox_file_dropdown.popup_centered_clamped(get_viewport_rect().size, 0.6)

func _on_Toggle_Skybox_Settings_toggled(button_pressed):
	get_node("MarginContainer/VBoxContainer/Skybox_Settings").visible = button_pressed

func _on_Toggle_Fog_Settings_toggled(button_pressed):
	get_node("MarginContainer/VBoxContainer/Fog_Settings").visible = button_pressed
