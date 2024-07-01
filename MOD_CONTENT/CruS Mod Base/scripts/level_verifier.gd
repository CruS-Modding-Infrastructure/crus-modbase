extends Node

const MOD_NAME = "CruS Mod Base"

func dprint(msg: String, ctx: String = "") -> void:
	Mod.mod_log(msg, 'CMB:LevelVerifier' + (":" + ctx if len(ctx) > 0 else ""))

# TODO: load once in init.gd
var config: ConfigFile
var build_verbose_logging := false
const CONFIG_FILE_PATH = 'user://cmb.cfg'

func _init():
	dprint('', 'on:init')
	
	config = ConfigFile.new()
	if config.load(CONFIG_FILE_PATH) != OK:
		# Initialize
		config.save(CONFIG_FILE_PATH)

	build_verbose_logging = config.get_value('build', 'verbose_log', false)

func check_json(m: Dictionary) -> Array:
	var errors = []
	var missing = ""
	for key in ["author", "version", "description", "objectives", "level_scene"]:
		if !m.has(key):
			if !(key == "author"):
				missing += ", "
			missing += "'" + key + "'"
	if len(missing) > 0:
		errors.append("Missing " + ("property " if len(missing) == 1 else "properties: ") + missing)
	if m.has("fish") and !(m["fish"] is Array):
		errors.append("Property 'fish' must be an array of fish ticker strings")
	if m.has("reward") and !(m["reward"] is float):
		errors.append("Property 'reward' must be a number")
	return errors
	
func check_scene(path, lvl = { }) -> Array:
	# if path is String:
		# var deps := ResourceLoader.get_dependencies(path)
		# if len(deps) > 0:
			# Mod.mod_log(' - Scene Dependencies:', "CMB:check_scene")

			# for idx in deps.size():
				# Mod.mod_log('   -> %s' % [ deps[idx] ], "CMB:check_scene")
	dprint('Checking scene: %s' % [ path ], 'check_scene')
	
	var scn = load(path) if path is String else path
	var qmaps = []
	var nav = false
	var player = null
	var fish_warned = false
	
	var errors = []
	
	if !scn:
		return ["Broken scene file or missing dependencies"]
	elif path is String:
		scn = scn.instance()
	if scn.name != "Level":
		scn.name = "Level"
		dprint('WARNING: Root node isn\'t called "Level", setting it to that for now', "check_scene")
	
	for node in scn.get_children():
		if node is Navigation:
			nav = node
			if !node.get_script() or node.get_script().get_path() != "res://Scripts/Navigation.gd":
				node.set_script(preload("res://Scripts/Navigation.gd"))
				node.set_process(true)
				dprint("WARNING: Navigation node doesn't have a Navigation.gd attached, attaching one for now", "check_scene")
			if !node.get_node_or_null("NavigationMeshInstance"):
				errors.append("Navigation node has no NavigationMeshInstance child")
			else:
				var navmesh = node.get_node("NavigationMeshInstance").navmesh
				if !navmesh or navmesh.get_polygon_count() == 0:
					dprint("WARNING: Navmesh is empty, NPCs won't move properly (it has to be baked in Godot)", "check_scene")
		if node is QodotMap:
			if !nav:
				errors.append("Navigation node is after QodotMap in the scene tree, it should be before QodotMap and any entities")
			if node.base_texture_dir != "res://Maps/textures":
				dprint("WARNING: QodotMap node \"" + node.get_name() + "\" base texture dir is not res://Maps/textures, setting it to that for now", "check_scene")
				node.base_texture_dir = "res://Maps/textures"
			qmaps.push_back(node)
		if node.get_filename() == "res://Player_Test.tscn":
			if player:
				errors.append("Multiple Player_Test.tscn instances found, there should only be one")
			else:
				player = node
	
	if len(qmaps) == 0:
		errors.append("Missing QodotMap node. Make sure it was taken back out of NavigationMeshInstance after navmesh baking")
	else:
		for qm in qmaps:
			var child_count = (qm as QodotMap).get_children().size()
			if build_verbose_logging:
				dprint('Scanning %d children' % [ child_count ], 'check_scene')
			var node: Node
			for idx in child_count:
				node = (qm as QodotMap).get_child(idx)
				if build_verbose_logging:
					dprint('  [%04d/%04d] @%s' % [ idx + 1, child_count, node ], 'check_scene')
				if node.get_filename() == "res://Player_Test.tscn":
					if player:
						dprint('Multiple Player_Test.tscn instances found, there should only be one', 'check_scene')
					else:
						player = node
				elif (node.get_script() and node.get_script().get_path() == "res://Scripts/Water.gd" and 
						!lvl.has("fish") and !fish_warned):
					dprint("WARNING: Level seems to contain fishable water but no fish property is defined, using default [\"FISH\", \"DEAD\"]", "check_scene")
					fish_warned = true

	if !nav:
		errors.append("Missing or bad Navigation node")
	if !player:
		errors.append("Missing or bad player node (there should be an instance of res://Player_Test.tscn)")
	return errors
