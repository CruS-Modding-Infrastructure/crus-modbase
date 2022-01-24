extends Node

var map_built = false
var debug_tab = null
var hover_panel = null
var CMB = Mod.get_node("CruS Mod Base")
var LevelVerifier = load(CMB.modpath + "/scripts/level_verifier.gd").new()
const CONFIG_FILE_PATH = 'user://cmb.cfg'
var config: ConfigFile

signal map_build_over()

# ass name
const export_nav_copy_default_project_subfolder = "Levels"

func dprint(msg: String, ctx: String = "") -> void:
	if Engine.editor_hint:
		print("[%s] %s" % [ "CMB:level_editor" + (":" + ctx if len(ctx) > 0 else ""), msg])
	else:
		Mod.mod_log(msg, "CMB:level_editor" + (":" + ctx if len(ctx) > 0 else ""))

var nav_cache_fmt_str := "res://Levels/%s-nav.tres" if Engine.editor_hint else "user://%s-nav.tres"

func _init() -> void:
	config = ConfigFile.new()
	if config.load(CONFIG_FILE_PATH) != OK:
		# Initialize
		config.save(CONFIG_FILE_PATH)

	nav_cache_fmt_str = config.get_value('build', 'verbose_log', nav_cache_fmt_str)

func _process(delta):
	# @NOTE: Could this be moved to _physics_process instead to reduce overhead?
	# Inject the debug and level tabs into the in-game stock menu
	if "debug_level" in CMB.data:
		if (not is_instance_valid(debug_tab)
				and is_instance_valid(Global.player)
				and Global.player.get_parent().get_node_or_null("Stock_Menu")):
			add_debug_menus()

# For base children of level directory only
export (Array) var ignored_debug_subdirs   = [ "autosave" ]
# For any child file in a level directory, recursively
export (Array) var ignored_debug_file_exts = [ "psd", "import", "ai" ]

func is_ignored_export_ext(fname: String) -> bool:
	# return ignored_debug_file_exts.has(fname.get_extension().trim_prefix('.'))
	var ignored : bool = ignored_debug_file_exts.has(fname.get_extension())
	if ignored:
		dprint(' [Ignored] %s' % [ fname ], 'export:is_ignored_ext')
	return ignored

func add_debug_menus():
	dprint('Loading debug menus', 'add_debug_menus')
	var noclip_restart_required: bool = false
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
		debug_tab   = dtab

	if is_instance_valid(debug_tab):
		hover_panel.rect_global_position = Global.menu.get_global_mouse_position() + Vector2(50, 20)
		hover_panel.rect_global_position.y = clamp(
				hover_panel.rect_global_position.y,
				0,
				(720 - hover_panel.rect_size.y - 100) * Global.menu.rect_scale.x)
		hover_panel.rect_global_position.x = clamp(
				hover_panel.rect_global_position.x,
				0,
				(1280 - hover_panel.rect_size.x - 100) * Global.menu.rect_scale.y)

		# Also enable console now, since its always added (now) don't remind the user
		debug_tab.cheats.enable_cheat_prompt(true)

	if !stabs.get_node_or_null("Level"):
		var ltab = load(CMB.modpath + "/scenes/LevelTab.tscn").instance()
		stabs.add_child(ltab)

# Scans the textures folder of a level to make a name->path dictionary of its custom textures
func get_custom_texture_dict(textures_path, dict: Dictionary, extension_whitelist: PoolStringArray) -> Dictionary:
	var dir = Directory.new()
	if dir.open(textures_path) == OK:
		dir.list_dir_begin(true, true)
		var fname: String = dir.get_next()
		var fext:  String = fname.get_extension()

		while fname != "":
			var p = textures_path + "/" + fname
			if dir.current_is_dir():
				get_custom_texture_dict(p, dict, extension_whitelist)
			else:
				var texdir = ""
				if "/textures/Maps" in textures_path:
					texdir = textures_path.get_file() + "/"

				# Moved inline from separate function until needed in another context to trim down
				# on declarations
				fext = fname.get_extension()
				for ext in extension_whitelist:
					if fext == ext:
						var key = texdir + fname.get_basename()
						dict[key] = p

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
				var p     = "%s/%s" % [ dirpath,     fname ]
				var new_p = "%s/%s" % [ new_dirpath, fname ]
				if dir.current_is_dir():
					# (Recursive directory name filter would go here)
					copy_directory(p, new_p)
				else:
					# Check if ignored file extension
					if not is_ignored_export_ext(fname):
						dir.copy(p, new_p)
				fname = dir.get_next()
			dir.list_dir_end()
			return true
		else:
			dprint("ERROR: Failed to open " + new_dirpath + " for copying!",  'copy_directory')
	else:
		dprint("ERROR: Failed to open " + dirpath + " for copying!",  'copy_directory')
	return false

# Allows rebuilding level QodotMaps in real time from the TrenchBroom .map
# NOTE: after rebuilding a QodotMap node with this the mesh_instances need to be reset
func rebuild_qodotmap(qmap: QodotMap, caller=null, progress_func_name="", ignore_list: Array = [ ]) -> QodotMap:
	dprint("Building .map to QodotMap node", 'rebuild_qodotmap')
	var qmap_new = QodotMap.new()
	qmap_new.name = qmap.name
	qmap_new.map_file = qmap.map_file
	qmap_new.base_texture_dir = qmap.base_texture_dir
	qmap.entity_fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	qmap_new.block_until_complete = false
	qmap_new.external_texture_dict = get_custom_texture_dict(
			"user://levels/_debug/textures", { }, qmap_new.texture_file_extensions)
	qmap_new.connect("build_failed", self, "_on_map_build_fail")
	qmap_new.connect("build_complete", self, "_on_map_build_succeed")
	qmap_new.connect("build_progress", self, "_on_map_build_progress")
	if is_instance_valid(caller) and caller.has_method(progress_func_name):
		qmap_new.connect("build_progress", caller, progress_func_name)
	map_built = false
	dprint('qmap_new.verify_and_build(null, ignore_list)', 'rebuild_qodotmap')
	qmap_new.verify_and_build(null, ignore_list)

	if map_built:
		for node in qmap_new.get_children():
			if "mesh_instance" in node: # reset mesh instances
				for n in node.get_children():
					if n is MeshInstance:
						node.mesh_instance = n
					if n is CollisionShape and "collision_shape" in node:
						node.collision_shape = n

		# swap out current QodotMap for new one
		var parent = qmap.get_parent()
		var qm_pos = qmap.get_position_in_parent()
		parent.remove_child(qmap)
		parent.add_child(qmap_new)
		parent.move_child(qmap_new, qm_pos)

		return qmap_new
	return null

const base_last_convert_map_to_tscn := {
	success          = false,
	nav_cache_loaded = false,
	errors           = [ ],
}
# Stores last tscn export result
var last_convert_map_to_tscn := base_last_convert_map_to_tscn

# Builds TrenchBroom map to a Godot scene.
# map_ospath - OS path to mapfile
# out_folder - Godot path to output folder
# export_mode - If true, erases the QodotMap's map_file property to prevent accidental doxxing
func convert_map_to_tscn(map_ospath: String, out_folder="user://levels/_debug", export_mode=false) -> String:
	# Immediately invalidate last result
	last_convert_map_to_tscn = base_last_convert_map_to_tscn

	dprint("Generating .tscn...", 'convert_map_to_tscn')

	var level_root = Spatial.new()
	dprint("glight", 'convert_map_to_tscn')
	var g_light = load(CMB.modpath + "/scenes/Global_Light.tscn").instance()

	dprint("nav", 'convert_map_to_tscn')
	var nav = Navigation.new()
	dprint("nav_mesh_inst", 'convert_map_to_tscn')
	var nav_mesh_inst = NavigationMeshInstance.new()
	dprint("nav_mesh_inst.navmesh", 'convert_map_to_tscn')
	nav_mesh_inst.navmesh = NavigationMesh.new()
	var world_env = WorldEnvironment.new()

	level_root.name = "Level"
	dprint("level_root <- g_light", 'convert_map_to_tscn')
	level_root.add_child(g_light, true)

	dprint("Setting nav script", 'convert_map_to_tscn')
	nav.set_script(load("res://Scripts/Navigation.gd"))

	# Try to load cached navmesh
	var nav_cache_path: String = nav_cache_fmt_str % [ map_ospath.get_file().get_basename() ] if nav_cache_fmt_str else null

	dprint('Checking for cached copy of navigation mesh at <%s>' % [ nav_cache_path ],  'convert_map_to_tscn')
	if nav_cache_path and ResourceLoader.exists(nav_cache_path):
		dprint('Found cached navigation mesh', 'convert_map_to_tscn')
		# Set navmesh to copy of cached
		var cache_res = ResourceLoader.load(nav_cache_path, "", true)
		var cached = cache_res.duplicate()
		if cached is NavigationMesh:
			nav_mesh_inst.navmesh = cache_res.duplicate()
			dprint("Loaded cached navmesh resource from <%s>" % [ nav_cache_path ], 'convert_map_to_tscn')
			last_convert_map_to_tscn.nav_cache_loaded = true
		else:
			dprint("WARNING: Resource loaded from expected nav cache path is not a NavigationMesh: <%s>" % [ nav_cache_path ], 'convert_map_to_tscn')
			

	nav.add_child(nav_mesh_inst, true)
	level_root.add_child(nav, true)

	dprint("Creating Environment", 'convert_map_to_tscn')
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.background_sky = PanoramaSky.new()
	env.background_sky.panorama = load("res://Textures/sky9.png")
	env.background_sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_sky_rotation_degrees.x = -45
	env.fog_enabled = true
	env.ambient_light_energy = 0.6
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
	qmap.external_texture_dict = get_custom_texture_dict(
		out_folder + "/textures",
		{ },
		qmap.texture_file_extensions)
	qmap.connect("build_failed", self, "_on_map_build_fail")
	qmap.connect("build_complete", self, "_on_map_build_succeed")
	qmap.connect("build_progress", self, "_on_map_build_progress")
	map_built = false
	qmap.verify_and_build(level_root)

	if "debug_level" in CMB.data and "_debug" in CMB.data.debug_level:
		dprint('CMB.data.debug_level._debug detected:', 'convert_map_to_tscn')
		var dbg = CMB.data.debug_level._debug
		g_light.visible = dbg["g_light_enabled"]
		dprint('Saved g_light.visible     => %s' % [ dbg["g_light_enabled"] ], 'convert_map_to_tscn')
		g_light.init_energy = dbg["g_light_energy"]
		dprint('Saved g_light.init_energy => %s' % [ dbg["g_light_energy"] ], 'convert_map_to_tscn')
		g_light.darkness = dbg["g_light_darkness"]
		dprint('Saved g_light.darkness    => %s' % [ dbg["g_light_darkness"] ], 'convert_map_to_tscn')
		
		if "g_init_energy_ambient" in dbg:
			g_light.init_energy_ambient = dbg["g_init_energy_ambient"]
		else:
			g_light.init_energy_ambient = 1.0 # @TODO: const defaults?
		dprint('Saved g_light.init_energy_ambient => %s' % [ g_light.init_energy_ambient ], 'convert_map_to_tscn')
			
			
		var sb = load(dbg["skybox_file_path"])
		if not sb:
			dprint('Failed to directly load skybox resource, creating new image instance to assign path.', 'convert_map_to_tscn')
			sb = Image.new()
			sb.load(dbg["skybox_file_path"])
		if sb:
			var img = sb if sb is Image else sb.get_data()
			var skytex = ImageTexture.new()
			skytex.create_from_image(img)
			env.background_sky.panorama = skytex
			dprint('Saved env.background_sky.panorama => %s' % [
					Mod.path_wrap(env.background_sky.panorama) ], 'convert_map_to_tscn')
		else:
			dprint("WARNING: Failed to load skybox " + dbg["skybox_file_path"], 'convert_map_to_tscn')

		env.fog_height_min  = dbg["fog_height_min"]
		dprint('Saved env.fog_height_min    => %s' % [ dbg["fog_height_min"] ], 'convert_map_to_tscn')
		env.fog_height_max  = dbg["fog_height_max"]
		dprint('Saved env.fog_height_max    => %s' % [ dbg["fog_height_max"] ], 'convert_map_to_tscn')
		env.fog_depth_begin = dbg["fog_depth_begin"]
		dprint('Saved env.fog_depth_begin   => %s' % [ dbg["fog_depth_begin"] ], 'convert_map_to_tscn')
		env.fog_depth_end   = dbg["fog_depth_end"]
		dprint('Saved env.fog_depth_end     => %s' % [ dbg["fog_depth_end"] ], 'convert_map_to_tscn')

		#region Bake in time of day, if configured

		if "time_of_day" in dbg and dbg["time_of_day"] >= 0:
			g_light.debug_time = dbg["time_of_day"]
			dprint('Saving g_light.debug_time => %s' % [ dbg["time_of_day"] ], 'convert_map_to_tscn')

		#endregion Bake in time of day, if configured
	else:
		if is_instance_valid(qmap):
			dprint('[ERROR] build failed but qmap is valid.', 'convert_map_to_tscn')
			# qmap.print_tree_pretty()
			pass

	var scene_ospath := ""
	var scene_name
	var scene
	dprint("Post build map_built check", 'convert_map_to_tscn')
	if map_built and qmap.get_child_count() > 0:
		scene = PackedScene.new()
		g_light.owner       = level_root
		nav.owner           = level_root
		nav_mesh_inst.owner = level_root
		world_env.owner     = level_root
		qmap.owner          = level_root
		scene.pack(level_root)
		scene_name = map_ospath.get_file().trim_suffix("map") + "tscn"
		scene_ospath = ProjectSettings.globalize_path(out_folder + "/" + scene_name)

		ResourceSaver.save(scene_ospath, scene)
		dprint("Successfully built map to %s, running checks..." % [ Mod.path_wrap(out_folder) ], 'convert_map_to_tscn')
		var errs = LevelVerifier.check_scene(out_folder.plus_file(scene_ospath.get_file()))
		dprint("Found %s errors %s" % [str(len(errs)), ("" if len(errs) == 0 else ": ")], 'convert_map_to_tscn')
		for err in errs:
			dprint("\t-> " + err, 'convert_map_to_tscn')
		if len(errs) > 0:
			last_convert_map_to_tscn.errors = Array(errs)
			return ""
		else:
			last_convert_map_to_tscn.success = true
	else:
		dprint("ERROR: Failed to build map to level scene", 'convert_map_to_tscn')
		if is_instance_valid(qmap):
			var ent_count = qmap.get_child_count()
			if ent_count > 0:
				dprint("    Build failed but QodotEntity has %d entities:" % [ ent_count ], 'convert_map_to_tscn')
				for idx in ent_count:
					dprint("      - @%s" % [ qmap.get_child(idx) ], 'convert_map_to_tscn')
		else:
			dprint("    QodotEntity not valid.", 'convert_map_to_tscn')

	return scene_ospath

# Generates JSON from level metadata
func generate_level_json(lvl_dict, export_mode=false) -> String:
	var lvl = {}
	if !("level_scene" in lvl_dict):
		dprint('ERROR: Can\'t generate level.json because property "level_scene" is missing', 'convert_map_to_tscn')
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
	# @NOTE: Originally removed the export_mode check, but it seems to fuck with loading an exported
	#        _debug map
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
			var fname: String = debug_dir.get_next()
			while fname != "":
				if debug_dir.current_is_dir():
					# Filter
					if ignored_debug_subdirs.has(fname):
						dprint('Skipping export of sub-directory %s' % [ fname ],  'export_debug_level')
					else:
						copy_directory("user://levels/_debug/" + fname, lvl_dir + "/" + fname)
				elif fname.get_extension() != ".map":
					if is_ignored_export_ext(fname):
						dprint('Skipping export child file with ignored extension %s' % [ fname ],  'export_debug_level')
					else:
						debug_dir.copy("user://levels/_debug/" + fname, lvl_dir + "/" + fname)
				fname = debug_dir.get_next()
			debug_dir.list_dir_end()

		var json_file = File.new()
		if json_file.open(lvl_dir + "/" + "level.json", File.WRITE) == OK:
			json_file.store_string(json_str)
			json_file.close()
		else:
			dprint("ERROR: Couldn't write level.json during export!", 'export_debug_level')

		convert_map_to_tscn(map_ospath, lvl_dir, true)
		dprint('Finished convert_map_to_tscn', 'export_debug_level')
		var scene_path = lvl_dir + "/" + lvl_name + ".tscn"

		var f = File.new()
		if not f.file_exists(scene_path):
			return false

		# Handle emitted errors/warnings
		var warnings := PoolStringArray()
		if not last_convert_map_to_tscn.nav_cache_loaded:
			warnings.append("Level has no navmesh, so enemies won't move properly. Due to engine limitations, you must bake it yourself in Godot")
		if 'errors' in last_convert_map_to_tscn and last_convert_map_to_tscn.errors.size() > 0:
			for w in last_convert_map_to_tscn.errors:
				warnings.append(w)
		if warnings.size() > 0:
			var warn_file := File.new()
			if warn_file.open(lvl_dir + "/" + "LEVEL_WARNINGS.txt", File.WRITE) == OK:
				warn_file.store_string(warnings.join('\n'))
				warn_file.close()

		var msg: String = "Successfully exported level to %s" % [ Mod.path_wrap(lvl_dir) ]
		dprint(msg, 'export_debug_level')
		Global.player.UI.message(msg, false)
		return true
	else:
		dprint("ERROR: Couldn't open " + lvl_dir + " for export!",  'export_debug_level')
	return false

func _on_map_build_fail():
	# THIS SHOULD BE FALSE RIGHT????
	map_built = true
	dprint("Map failed to build", 'on:map_build_fail')
	emit_signal("map_build_over")

func _on_map_build_succeed():
	map_built = true
	dprint("Map successfully built",  'on:map_build_succeed')
	emit_signal("map_build_over")


func _on_map_build_progress(build_step, percent):
	# Mod.mod_log(str("Build progressing, step: ", build_step, " (", percent * 100, "%)"), CMB)
	dprint("[%05.2f%s] Build Step: %s" % [
				(percent * 100),
				'%' if not is_equal_approx(percent, 1) else "",
				build_step
			],
			'on:map_build_progress')
