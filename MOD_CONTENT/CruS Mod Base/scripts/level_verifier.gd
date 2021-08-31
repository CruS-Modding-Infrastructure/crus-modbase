extends Node

var MOD_NAME = "CruS Mod Base"

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
	
func check_scene(path, lvl={}) -> Array:
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
		Mod.mod_log('WARNING: Root node isn\'t called "Level", setting it to that for now', MOD_NAME)

	for node in scn.get_children():
		if node is Navigation:
			nav = node
			if !node.get_script() or node.get_script().get_path() != "res://Scripts/Navigation.gd":
				node.set_script(load("res://Scripts/Navigation.gd"))
				node.set_process(true)
				Mod.mod_log("WARNING: Navigation node doesn't have a Navigation.gd attached, attaching one for now", MOD_NAME)
			if !node.get_node_or_null("NavigationMeshInstance"):
				errors.append("Navigation node has no NavigationMeshInstance child")
			else:
				var navmesh: NavigationMesh = node.get_node("NavigationMeshInstance").navmesh
				if !navmesh or navmesh.get_polygon_count() == 0:
					Mod.mod_log("WARNING: Navmesh is empty, NPCs won't move properly (it has to be baked in Godot)", MOD_NAME)
		if node is QodotMap:
			if !nav:
				errors.append("Navigation node is after QodotMap in the scene tree, it should be before QodotMap and any entities")
			if node.base_texture_dir != "res://Maps/textures":
				Mod.mod_log("WARNING: QodotMap node \"" + node.get_name() + "\" base texture dir is not res://Maps/textures, setting it to that for now", MOD_NAME)
				node.base_texture_dir = "res://Maps/textures"
			qmaps.append(node)
		if node.get_filename() == "res://Player_Test.tscn":
			if player:
				errors.append("Multiple Player_Test.tscn instances found, there should only be one")
			else:
				player = node
	
	if len(qmaps) == 0:
		errors.append("Missing QodotMap node. Make sure it was taken back out of NavigationMeshInstance after navmesh baking")
	else:
		for qm in qmaps:
			for node in qm.get_children():
				if node.get_filename() == "res://Player_Test.tscn":
					if player:
						Mod.mod_log("Multiple Player_Test.tscn instances found, there should only be one", MOD_NAME)
					else:
						player = node
				if (node.get_script() and node.get_script().get_path() == "res://Scripts/Water.gd" and 
					!lvl.has("fish") and !fish_warned):
					Mod.mod_log("WARNING: Level seems to contain fishable water but no fish property is defined, using default [\"FISH\", \"DEAD\"]", MOD_NAME)
					fish_warned = true
	if !nav:
		errors.append("Missing or bad Navigation node")
	if !player:
		errors.append("Missing or bad player node (there should be an instance of res://Player_Test.tscn)")
	return errors
