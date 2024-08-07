extends Container

onready var CMB = Mod.get_node("CruS Mod Base")
onready var debug_lvl_data = CMB.data.debug_level if "debug_level" in CMB.data else null
onready var level_editor   = CMB.get_node("LevelEditor")

onready var cheats  = get_tree().root.get_node("Level/Cheats")
onready var g_light = get_tree().root.get_node("Level/Global_Light")
onready var env: WorldEnvironment = get_tree().root.get_node("Level/WorldEnvironment")

onready var preview_box          = get_node("MarginContainer/Preview_Box")
onready var skybox_file_dropdown = get_node("MarginContainer/Skybox_Popup")
onready var level_container      = get_node("MarginContainer/VBoxContainer")
onready var export_btn           = get_node("MarginContainer/VBoxContainer/Export_Level/Button")
onready var fog_container        = get_node("MarginContainer/VBoxContainer/Fog_Settings/VBoxContainer")
onready var fog_height_label:  Label       = get_node("MarginContainer/VBoxContainer/Fog_Settings/VBoxContainer/HeightLabelAndToggle/Label")
onready var fog_height_toggle: CheckButton = get_node("MarginContainer/VBoxContainer/Fog_Settings/VBoxContainer/HeightLabelAndToggle/CheckButton")
onready var gls                  = get_node("MarginContainer/VBoxContainer/Global_Light_Settings")
onready var border_warn          = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Border_Warning")
onready var gl_bright_label      = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/GL_Brightness_Slider/Label")
onready var gl_bright_slide      = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/GL_Brightness_Slider/HSlider")
onready var gl_amb_light_label   = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/GL_Ambient_Slider/Label")
onready var gl_amb_light_slide   = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/GL_Ambient_Slider/HSlider")
onready var gl_dark_btn          = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Toggle_Darkness/HBoxContainer/CheckButton")
onready var gl_permn_btn         = get_node("MarginContainer/VBoxContainer/Global_Light_Settings/VBoxContainer/Toggle_Permanight/HBoxContainer/CheckButton")
onready var preview_image        = get_node("MarginContainer/VBoxContainer/Preview_Image/VBoxContainer/TextureRect")
onready var reload_bar           = get_node("MarginContainer/VBoxContainer/Reload_Loading/MarginContainer/VBoxContainer/ProgressBar")
onready var reload_container     = get_node("MarginContainer/VBoxContainer/Reload_Loading")
onready var skybox_file_image    = get_node("MarginContainer/VBoxContainer/Skybox_Settings/File/TextureRect")
onready var skybox_file_btn      = get_node("MarginContainer/VBoxContainer/Skybox_Settings/File/MarginContainer/HBoxContainer/Button")
onready var gl_btn               = get_node("MarginContainer/VBoxContainer/Toggle_Night_Cycle/HBoxContainer/CheckButton")

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
var last_img
var skybox_file_path = ""
var in_debug_lvl

signal settings_changed

func dprint(msg: String, ctx: String = "") -> void:
	Mod.mod_log(msg, 'CMB:level_menu' + (":" + ctx if len(ctx) > 0 else ""))

# Remove this after build fixed
func _init() -> void:
	dprint('', 'on:init')

func _ready():
	if cheats:
		cheats.enabled.append("debug")

	var skybox_path = ""
	var cur_lvl_data = Global.LEVEL_META[Global.CURRENT_LEVEL]
	
	# Just hide fog settings anyway since I keep forgetting to rehide it editing
	fog_container.get_node("..").hide()

	in_debug_lvl = "level_scene" in cur_lvl_data and debug_lvl_data and debug_lvl_data.level_scene == cur_lvl_data.level_scene
	if in_debug_lvl:
		var lvl_dir = debug_lvl_data.level_scene.get_base_dir()
		if lvl_dir == "":
			dprint('Using _debug level path %s' % [lvl_dir], 'on:ready')
			lvl_dir = "user://levels/_debug"

		var f = File.new()
		if not f.file_exists(lvl_dir + "/level.json"):
			dprint('Initializing _debug level.json: %s' % [ lvl_dir + "/level.json" ], 'on:ready')
			save_level_settings()
		elif f.open(lvl_dir + "/level.json", File.READ) == OK:
			
			var ld = parse_json(f.get_as_text())
			
			if ld is Dictionary:
				for key in ld.keys():
					CMB.data.debug_level[key] = ld[key]
					
			else:
				dprint("WARNING: Bad JSON file " + lvl_dir + "/level.json", 'on:ready')

			var p_img = Image.new()
			var p_img_path = get_file_path("image", debug_lvl_data)
			dprint('Level preview png path: <%s>' % [ Mod.path_wrap(p_img_path) if p_img_path else "NULL" ], 'on:ready')

			if p_img_path and p_img.load(p_img_path) == OK:
				preview_image.texture = ImageTexture.new()
				preview_image.texture.create_from_image(p_img)

			if "_debug" in ld:
				gl_btn.pressed        = ld["_debug"]["g_light_enabled"]
				gl_bright_slide.value = ld["_debug"]["g_light_energy"]
				gl_dark_btn.pressed   = ld["_debug"]["g_light_darkness"]
				gl_amb_light_label

				if "skybox_file_path" in ld["_debug"]:
					skybox_path = ld["_debug"]["skybox_file_path"]

				fog_container.get_node("Height_Min/HSlider").value  = ld["_debug"]["fog_height_min"]
				fog_container.get_node("Height_Max/HSlider").value  = ld["_debug"]["fog_height_max"]
				fog_container.get_node("Depth_Begin/HSlider").value = ld["_debug"]["fog_depth_begin"]
				fog_container.get_node("Depth_End/HSlider").value   = ld["_debug"]["fog_depth_end"]

				if "time_of_day" in ld["_debug"]:
					dprint('Setting time of day', "on:ready")
					g_light.debug_time = ld["_debug"]["time_of_day"]

				if "g_init_energy_ambient" in ld["_debug"]:
					dprint('Setting ambient light level', "on:ready")
					g_light.init_energy_ambient = ld["_debug"]["g_init_energy_ambient"]
					_on_GL_Ambient_value_changed(g_light.init_energy_ambient)
					
				if "fog_height_enabled" in ld["_debug"]:
					_on_FogHeight_toggled(ld["_debug"]["fog_height_enabled"])
				else:
					_on_FogHeight_toggled(false)
					
			# First guess at where to load audio?

			if "music" in ld:
				if ld["music"].begins_with("res://"):
					dprint("Setting music for debug level (%s/%s)" % [
						Global.LEVEL_SONGS.size(),
						Global.CURRENT_LEVEL
					], 'on:ready')

					Global.LEVEL_SONGS[Global.CURRENT_LEVEL] = load(ld["music"])

					if Global.music is AudioStreamPlayer:
						Global.music.stream = Global.LEVEL_SONGS[Global.CURRENT_LEVEL]
					else:
						dprint('Tried to load song for level, but Global.music is not an AudioStreamPlayer instance. (%s)' % [ str(Global.music) if Global.music != null else '<NULL>' ], 'on:ready')

			if "ambience" in ld:
				if ld["ambience"].begins_with("res://"):
					dprint("Setting ambience for debug level (%s/%s)" % [
						Global.LEVEL_AMBIENCE.size(),
						Global.CURRENT_LEVEL
					], 'on:ready')

					Global.LEVEL_AMBIENCE[Global.CURRENT_LEVEL] = load(ld["ambience"])
					if Global.ambience is AudioStreamPlayer:
						Global.ambience.stream = Global.LEVEL_AMBIENCE[Global.CURRENT_LEVEL]

						Global.ambience.volume_db = Global.music.volume_db
						if not Global.ambience.playing:
							Global.ambience.playing = true
					else:
						dprint('Tried to load ambient for level, but Global.ambient is not an AudioStreamPlayer instance. (%s)' % [ str(Global.ambient) if Global.ambient != null else '<NULL>' ], 'on:ready')

	level_container.get_node("Reload_Mapfile").visible = in_debug_lvl
	level_container.get_node("Save_Level").visible     = in_debug_lvl
	level_container.get_node("Export_Level").visible   = in_debug_lvl

	init_skybox_file_entries()
	if skybox_path != "":
		if add_skybox_file_entry(skybox_path):
			_on_Skybox_Popup_id_pressed(skybox_file_dropdown.get_item_count() - 1)
		elif skybox_files.find(skybox_path) != -1:
			_on_Skybox_Popup_id_pressed(skybox_files.find(skybox_path))
	else:
		skybox_path = env.environment.background_sky.panorama.get_path()

	connect("settings_changed", self, "_on_settings_changed")

# Copied from init until I make a utility thing
func get_file_path(key: String, dict: Dictionary) -> String:
	var p = ""
	if not dict.has(key) or not dict.get(key): return p

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
	var lvl_dir = "user://levels/_debug" # debug_lvl_data.level_scene.get_base_dir()
	dprint('Output directory: %s' % [Mod.path_wrap(lvl_dir)], 'save_level_settings')
	var f = File.new()
	if f.open(lvl_dir + "/level.json", File.WRITE) == OK:
		var dbg = {}
		if last_img:
			last_img.save_png(lvl_dir + "/preview.png")
			debug_lvl_data.image = "preview.png"
			dprint('Saving preview png to %s' % [ Mod.path_wrap(lvl_dir + '/preview.png') ], 'save_level_settings')

		dbg["g_light_enabled"]  = gl_btn.pressed
		# @NOTE: Should be better to save directly from g_light instance? Possibly had issues with
		#        saving info due to dsync between slider value/instance value
		dbg["g_light_energy"]   = gl_bright_slide.value
		dbg["g_light_darkness"] = gl_dark_btn.pressed
		dbg["skybox_file_path"] = skybox_file_path
		dbg["fog_height_min"]   = fog_container.get_node("Height_Min/HSlider").value
		dbg["fog_height_max"]   = fog_container.get_node("Height_Max/HSlider").value
		dbg["fog_depth_begin"]  = fog_container.get_node("Depth_Begin/HSlider").value
		dbg["fog_depth_end"]    = fog_container.get_node("Depth_End/HSlider").value
		
		dbg["g_init_energy_ambient"] = g_light.init_energy_ambient
		dbg["fog_height_enabled"] = fog_height_toggle.pressed
			
		if 'debug_time' in g_light and g_light.debug_time >= 0:
			dprint('Adding time of day to map _debug properties. (%s)' % [ g_light.debug_time ], 'save_level_settings')
			dbg["time_of_day"] = g_light.debug_time

		debug_lvl_data["_debug"] = dbg
		dprint('Saving _debug properties:\n%s' % [ var2str(debug_lvl_data["_debug"]) ], 'save_level_settings')

		f.store_string(level_editor.generate_level_json(debug_lvl_data))
		f.close()
	else:
		dprint('ERROR: Failed to open level.json for saving: %s' % [ lvl_dir + '/preview.png' ], 'save_level_settings')

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
	if gl_bright_slide.visible and "light_energy_base" in g_light:
		gl_bright_slide.value = g_light.light_energy_base

func _on_settings_changed():
	get_node("MarginContainer/VBoxContainer/Save_Level/Button").text = "Save (*)"

func _on_Night_Cycle_Toggle_toggled(button_pressed):
	g_light.visible = button_pressed
	gls.visible = button_pressed
	if not button_pressed:
		if "init_energy_ambient" in g_light:
			env.environment.ambient_light_energy = g_light.init_energy_ambient
			env.environment.fog_color            = g_light.init_fog
		if "darkness" in g_light:
			g_light.darkness    = false
			gl_dark_btn.pressed = false
		if "permanight" in g_light:
			g_light.permanight   = false
			gl_permn_btn.pressed = false

	dprint('Night Cycle Toggled: %s' % button_pressed, 'on:Night_Cycle_Toggle_toggled')
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
	if not dir.dir_exists("user://snapshots"):
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
		dprint("Took a level preview snapshot and saved it to " + filepath, 'take_preview_image')
	preview_image.texture = tex

func finish_preview_image():
	preview_box.hide()
	var cheats = get_tree().root.get_node("Level/Cheats")
	if not (is_instance_valid(cheats) and cheats.in_noclip()):
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
	gl_bright_slide.editable = not button_pressed
	dprint('Darkness: %s' % g_light.darkness, 'on:Permanight_toggled')
	set_process(button_pressed or reloading_map)
	emit_signal("settings_changed")

func _on_Permanight_toggled(button_pressed):
	g_light.permanight = button_pressed
	dprint('Permanight: %s' % g_light.permanight, 'on:Permanight_toggled')
	emit_signal("settings_changed")

func _on_GL_Brightness_value_changed(value):
	# if "init_energy" in g_light:
	# 	g_light.init_energy = value
	# 	dprint('init_energy: %s' % value, 'on:GL_Brightness_value_changed')
	# else:

	if g_light:
		g_light.set_base_light_energy(value)
		dprint('light_energy_base: %s' % [ g_light.light_energy_base ], 'on:GL_Brightness_value_changed')

		if is_instance_valid(gl_bright_label):
			gl_bright_label.text = '%4.2f' % [ g_light.light_energy_base ]

		emit_signal("settings_changed")
	else:
		dprint('Failed to read g_light object.', 'on:GL_Brightness_value_changed')

var pre_rebuild_pos: Transform

func _on_Reload_From_TB_pressed():
	if level_editor.map_built:
		reload_bar.value = 0
		reload_container.show()

		if not cheats.in_noclip():
			cheats.enter_noclip()

		pre_rebuild_pos = (cheats.noclip_inst as Spatial).get_global_transform()

		# Mod.log_mod('Calling clear_movement_state', 'CMB:level_menu:on:Reload_From_TB_pressed')
		# clear_movement_state()
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
		(cheats.noclip_inst as Spatial).set_global_transform(pre_rebuild_pos)
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
		gls.visible    = g_light.visible
		gl_dark_btn.visible = "darkness" in g_light
		gls.get_node("VBoxContainer/Darkness_Label").visible = gl_dark_btn.visible
		if gl_dark_btn.visible:
			gl_dark_btn.pressed = g_light.darkness
		border_warn.visible = Global.border.texture == Global.BORDERS[3]

func _on_Fog_Slider_value_changed(value, dimension, minmax):
	var val = "fog_%s_%s" % [dimension, minmax]
	env.environment.set(val, value)
	emit_signal("settings_changed")
	dprint('Fog Value %s: %s' % [val, value], 'on:Fog_Slider_value_changed')

func init_skybox_file_entries():
	for sf in skybox_files:
		var sb = load(sf)
		var icon = ImageTexture.new()
		icon.create_from_image(sb.get_data())
		icon.set_size_override(Vector2(32, 32))
		skybox_file_dropdown.add_icon_item(icon, sf)

func add_skybox_file_entry(filepath) -> bool:
	var sf = Image.new()
	if not (filepath in skybox_files) and sf.load(filepath) == OK:
		skybox_files.append(filepath)
		var icon = ImageTexture.new()
		icon.create_from_image(sf)
		icon.set_size_override(Vector2(32, 32))
		skybox_file_dropdown.add_icon_item(icon, filepath)
		return true
	return false

func _on_Skybox_Popup_id_pressed(id):
	var sb = load(skybox_files[id])
	if not sb:
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

func _on_GL_Ambient_value_changed(value) -> void:
	if g_light:
		g_light._set_init_energy_ambient(value)
		dprint('init_energy_ambient: %s' % [ g_light.init_energy_ambient ], 'on:GL_Ambient_value_changed')

		if is_instance_valid(gl_amb_light_label):
			gl_amb_light_slide.value = g_light.init_energy_ambient
			gl_amb_light_label.text = '%4.2f' % [ g_light.init_energy_ambient ]

		emit_signal("settings_changed")
	else:
		dprint('Failed to read g_light object.', 'on:GL_Ambient_value_changed')

const TOGGLEABLE_LABEL_COLOR = Color(1, 0, 0, 1)
const TOGGLEABLE_LABEL_COLOR_OFF = Color(1, 0, 0, 0.6)

func _on_FogHeight_toggled(pressed) -> void:
	(fog_height_toggle as BaseButton).pressed = pressed
	env.environment.fog_height_enabled = pressed
	
	if not is_instance_valid(fog_height_label.theme):
		fog_height_label.theme = Theme.new()
	
	if env.environment.fog_height_enabled:
		fog_height_label.add_color_override("font_color", TOGGLEABLE_LABEL_COLOR)
		fog_container.get_node("Height_Min").show()
		fog_container.get_node("Height_Max").show()
	else:
		fog_height_label.add_color_override("font_color", TOGGLEABLE_LABEL_COLOR_OFF)
		fog_container.get_node("Height_Min").hide()
		fog_container.get_node("Height_Max").hide()
