extends Node

var map_built = false
var debug_tab = null
var hover_panel = null
var CMB = Mod.get_node("CruS Mod Base")
var LevelVerifier = load(CMB.modpath + "/scripts/level_verifier.gd").new()
signal map_build_over()
	
func _process(delta):
	# Inject the debug and level tabs into the in-game stock menu
	if "debug_level" in CMB.data:
		if !is_instance_valid(debug_tab) and is_instance_valid(Global.player) and Global.player.get_parent().get_node_or_null("Stock_Menu"):
			add_debug_menus()

func add_debug_menus():
	var stabs = Global.player.get_parent().get_node("Stock_Menu/Character_Container/TabContainer")
	if !stabs.get_node_or_null("Debug"):
		var dtab = load(CMB.modpath + "/scenes/DebugTab.tscn").instance()
		stabs.add_child(dtab)
		var imenu = load(CMB.modpath + "/scenes/Implant_Menu_Ingame.tscn").instance()
		stabs.get_parent().add_child(imenu)
		var hpanel = load(CMB.modpath + "/scenes/Hover_Panel.tscn").instance()
		imenu.get_node("Character_Container").update_implant_slots()
		imenu.get_node("Character_Container").reset_implants_state()
		stabs.get_parent().get_parent().add_child(hpanel)
		hover_panel = hpanel
		debug_tab = dtab
	if is_instance_valid(debug_tab):
		hover_panel.rect_global_position = Global.menu.get_global_mouse_position() + Vector2(50, 20)
		hover_panel.rect_global_position.y = clamp(hover_panel.rect_global_position.y, 0, (720 - hover_panel.rect_size.y - 100) * Global.menu.rect_scale.x)
		hover_panel.rect_global_position.x = clamp(hover_panel.rect_global_position.x, 0, (1280 - hover_panel.rect_size.x - 100) * Global.menu.rect_scale.y)
	if !stabs.get_node_or_null("Level"):
		var ltab = load(CMB.modpath + "/scenes/LevelTab.tscn").instance()
		stabs.add_child(ltab)

# Scans the textures folder of a level to make a name->path dictionary of its custom textures
func get_custom_texture_dict(textures_path, dict={}) -> Dictionary:
	var dir = Directory.new()
	if dir.open(textures_path) == OK:
		dir.list_dir_begin(true, true)
		var fname = dir.get_next()
		while fname != "":
			var p = textures_path + "/" + fname
			if dir.current_is_dir():
				get_custom_texture_dict(p, dict)
			else:
				var texdir = ""
				if "/textures/Maps" in textures_path:
					texdir = textures_path.get_file() + "/"
				dict[texdir + fname.get_basename()] = p
			fname = dir.get_next()
		dir.list_dir_end()
	return dict

func copy_directory(dirpath, new_dirpath) -> bool:
	var dir = Directory.new()
	var copy_dir = Directory.new()
	if dir.open(dirpath) == OK:
		if !copy_dir.dir_exists(new_dirpath):
			copy_dir.make_dir_recursive(new_dirpath)
		if copy_dir.open(new_dirpath) == OK:
			dir.list_dir_begin(true, true)
			var fname = dir.get_next()
			while fname != "":
				var p = dirpath + "/" + fname
				var new_p = new_dirpath + "/" + fname
				if dir.current_is_dir():
					copy_directory(p, new_p)
				else:
					dir.copy(p, new_p)
				fname = dir.get_next()
			dir.list_dir_end()
			return true
		else:
			Mod.mod_log("ERROR: Failed to open " + new_dirpath + " for copying!", CMB)
	else:
		Mod.mod_log("ERROR: Failed to open " + dirpath + " for copying!", CMB)
	return false

# Allows rebuilding level QodotMaps in real time from the TrenchBroom .map
# NOTE: after rebuilding a QodotMap node with this the mesh_instances need to be reset
func rebuild_qodotmap(qmap: QodotMap, caller=null, progress_func_name="", ignore_list=[]) -> QodotMap:
	Mod.mod_log("Building .map to QodotMap node", CMB)
	var qmap_new = QodotMap.new()
	qmap_new.name = qmap.name
	qmap_new.map_file = qmap.map_file
	qmap_new.base_texture_dir = qmap.base_texture_dir
	qmap.entity_fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	qmap_new.block_until_complete = false
	qmap_new.external_texture_dict = get_custom_texture_dict("user://levels/_debug/textures")
	qmap_new.connect("build_failed", self, "_on_map_build_fail")
	qmap_new.connect("build_complete", self, "_on_map_build_succeed")
	if is_instance_valid(caller) and caller.has_method(progress_func_name):
		qmap_new.connect("build_progress", caller, progress_func_name)
	map_built = false
	qmap_new.verify_and_build(null, ignore_list)

	if map_built:
		for node in qmap_new.get_children():
			if "mesh_instance" in node: # reset mesh instances
				for n in node.get_children():
					if n is MeshInstance:
						node.mesh_instance = n
					if n is CollisionShape and "collision_shape" in node:
						node.collision_shape = n
				possible_doors.append(node)

		# swap out current QodotMap for new one
		var parent = qmap.get_parent()
		var qm_pos = qmap.get_position_in_parent()
		parent.remove_child(qmap)
		parent.add_child(qmap_new)
		parent.move_child(qmap_new, qm_pos)
		
		return qmap_new
	return null

# Builds TrenchBroom map to a Godot scene.
# map_ospath - OS path to mapfile
# out_folder - Godot path to output folder
# export_mode - If true, erases the QodotMap's map_file property to prevent accidental doxxing
func convert_map_to_tscn(map_ospath, out_folder="user://levels/_debug", export_mode=false) -> String:
	Mod.mod_log("Generating .tscn...", CMB)

	var level_root = Spatial.new()
	var g_light = load(CMB.modpath + "/scenes/Global_Light.tscn").instance()
	var nav = Navigation.new()
	var nav_mesh_inst = NavigationMeshInstance.new()
	var world_env = WorldEnvironment.new()
	
	level_root.name = "Level"
	
	level_root.add_child(g_light, true)
	
	nav.set_script(load("res://Scripts/Navigation.gd"))
	nav_mesh_inst.navmesh = NavigationMesh.new()
	nav.add_child(nav_mesh_inst, true)
	level_root.add_child(nav, true)
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_sky = PanoramaSky.new()
	env.background_sky.panorama = load("res://Textures/sky9.png")
	env.background_sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_sky_rotation_degrees.x = -45
	env.fog_enabled = true
	world_env.environment = env
	world_env.set_script(load("res://Levels/sky_rotator.gd"))
	level_root.add_child(world_env, true)
	
	var qmap = QodotMap.new()
	level_root.add_child(qmap, true)
	qmap.name = "QodotMap"
	qmap.map_file = map_ospath
	qmap.base_texture_dir = "res://Maps/textures"
	qmap.entity_fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	qmap.block_until_complete = true
	qmap.external_texture_dict = get_custom_texture_dict(out_folder + "/textures")
	qmap.connect("build_failed", self, "_on_map_build_fail")
	qmap.connect("build_complete", self, "_on_map_build_succeed")
	#qmap.connect("build_progress", self, "_on_map_build_progress")
	map_built = false
	qmap.verify_and_build(level_root)

	if "debug_level" in CMB.data and "_debug" in CMB.data.debug_level:
		var dbg = CMB.data.debug_level._debug
		g_light.visible = dbg["g_light_enabled"]
		g_light.init_energy = dbg["g_light_energy"]
		g_light.darkness = dbg["g_light_darkness"]
		var sb = load(dbg["skybox_file_path"])
		if !sb:
			sb = Image.new()
			sb.load(dbg["skybox_file_path"])
		if sb:
			var img = sb if sb is Image else sb.get_data()
			var skytex = ImageTexture.new()
			skytex.create_from_image(img)
			env.background_sky.panorama = skytex
		else:
			Mod.mod_log("WARNING: Failed to load skybox " + dbg["skybox_file_path"], CMB)
		env.fog_height_min = dbg["fog_height_min"]
		env.fog_height_max = dbg["fog_height_max"]
		env.fog_depth_begin = dbg["fog_depth_begin"]
		env.fog_depth_end = dbg["fog_depth_end"]

	var scene_ospath = ""
	if map_built and qmap.get_child_count() > 0:
		var scene = PackedScene.new()
		g_light.owner = level_root
		nav.owner = level_root
		nav_mesh_inst.owner = level_root
		world_env.owner = level_root
		qmap.owner = level_root
		if export_mode:
			qmap.map_file = ""
		scene.pack(level_root)
		var scene_name = map_ospath.get_file().trim_suffix("map") + "tscn"
		scene_ospath = ProjectSettings.globalize_path(out_folder + "/" + scene_name)
		ResourceSaver.save(scene_ospath, scene)
		Mod.mod_log("Successfully built map to " + out_folder + ", running checks...", CMB)
		var errs = LevelVerifier.check_scene(out_folder + "/" + scene_ospath.get_file())
		Mod.mod_log("Found " + str(len(errs)) + " errors" + ("" if len(errs) == 0 else ": "), CMB)
		for err in errs:
			Mod.mod_log("\t-> " + err, CMB)
		if len(errs) > 0:
			return ""
	else:
		Mod.mod_log("ERROR: Failed to build map to level scene", CMB)
	return scene_ospath

# Generates JSON from level metadata
func generate_level_json(lvl_dict, export_mode=false) -> String:
	var lvl = {}
	if !("level_scene" in lvl_dict):
		Mod.mod_log('ERROR: Can\'t generate level.json because property "level_scene" is missing', CMB)
		return '{"error": "Missing level_scene property"}'
	if "name" in lvl_dict and lvl_dict.level_scene.get_base_dir() != "user://levels/_debug":
		lvl["name"] = lvl_dict.name
	lvl["author"] = lvl_dict.author if "author" in lvl_dict else "Your author name"
	lvl["version"] = lvl_dict.version if "version" in lvl_dict else "Your version string"
	lvl["description"] = lvl_dict.description if "description" in lvl_dict else "Your level description"
	lvl["objectives"] = lvl_dict.objectives if "objectives" in lvl_dict else ["Your level objectives"]
	lvl["level_scene"] = lvl_dict.level_scene
	if export_mode and lvl.level_scene.get_base_dir() == "user://levels/_debug":
		lvl["level_scene"] = lvl.level_scene.get_file()
		
	lvl["image"] = lvl_dict.image if "image" in lvl_dict else "your_240x240_pic.png"
	lvl["music"] = lvl_dict.music if "music" in lvl_dict else "your_level_music.ogg"
	if "ambience" in lvl_dict:
		lvl["ambience"] = lvl_dict.ambience 
	lvl["dialogue"] = lvl_dict.dialogue if "dialogue" in lvl_dict else ["..."]
	lvl["reward"] = lvl_dict.reward if "reward" in lvl_dict else 0
	lvl["fish"] = lvl_dict.fish if "fish" in lvl_dict else ["FISH", "DEAD"]
	lvl["ranks"] = lvl_dict.ranks if "ranks" in lvl_dict else {
		"normal": [0, 0, 0],
		"normal_stock_s": 0,
		"hell": [0, 0, 0],
		"hell_stock_s": 0
	}
	if "_debug" in lvl_dict and !export_mode:
		lvl["_debug"] = lvl_dict._debug
	return JSON.print(lvl, "\t")
	
# Exports the level in _debug in a new folder, ready to be distributed
func export_debug_level(map_ospath) -> bool:
	var debug_lvl = CMB.data["debug_level"]
	var lvl_name = debug_lvl["name"]
	var json_str = generate_level_json(debug_lvl, true)
	var dir = Directory.new()
	var lvl_dir = "user://levels/" + lvl_name
	if !dir.dir_exists(lvl_dir):
		dir.make_dir_recursive(lvl_dir)
	if dir.open(lvl_dir) == OK:
		var debug_dir = Directory.new()
		if debug_dir.open("user://levels/_debug") == OK:
			debug_dir.list_dir_begin(true, true)
			var fname = debug_dir.get_next()
			while fname != "":
				if debug_dir.current_is_dir():
					copy_directory("user://levels/_debug/" + fname, lvl_dir + "/" + fname)
				elif fname.get_extension() != ".map":
					debug_dir.copy("user://levels/_debug/" + fname, lvl_dir + "/" + fname)
				fname = debug_dir.get_next()
			debug_dir.list_dir_end()
		
		var json_file = File.new()
		if json_file.open(lvl_dir + "/" + "level.json", File.WRITE) == OK:
			json_file.store_string(json_str)
			json_file.close()
		else:
			Mod.mod_log("ERROR: Couldn't write level.json during export!", CMB)
		convert_map_to_tscn(map_ospath, lvl_dir, true)
		var scene_path = lvl_dir + "/" + lvl_name + ".tscn"
		var f = File.new()
		if !f.file_exists(scene_path):
			return false
		var warn_file = File.new()
		if warn_file.open(lvl_dir + "/" + "LEVEL_WARNINGS.txt", File.WRITE) == OK:
			var warnings = "Level has no navmesh, so enemies won't move properly. Due to engine limitations, you must bake it yourself in Godot"
			var warn_arr = LevelVerifier.check_scene(scene_path, debug_lvl)
			for w in warn_arr:
				warnings += "\n" + w
			warn_file.store_string(warnings)
			warn_file.close()
		Mod.mod_log("Successfully exported level to \"%s\"" % lvl_dir, CMB)
		return true
	else:
		Mod.mod_log("ERROR: Couldn't open " + lvl_dir + " for export!", CMB)
	return false

func _on_map_build_fail():
	map_built = true
	Mod.mod_log("Map failed to build", CMB)
	emit_signal("map_build_over")

func _on_map_build_progress(build_step, percent):
	Mod.mod_log(str("Build progressing, step: ", build_step, " (", percent * 100, "%)"), CMB)

func _on_map_build_succeed():
	map_built = true
	Mod.mod_log("Map successfully built", CMB)
	emit_signal("map_build_over")
