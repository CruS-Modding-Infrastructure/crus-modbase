extends Node

class_name CModBase

const MOD_NAME = "CruS Mod Base"
const MOD_PATH = "res://MOD_CONTENT/" + MOD_NAME

const MOD_DPRINT_BASE = 'CMB'
func dprint(msg: String, ctx: String = "") -> void:
	if Engine.editor_hint:
		print("[%s] %s" % [ MOD_DPRINT_BASE + (":" + ctx if len(ctx) > 0 else ""), msg])
	else:
		Mod.mod_log(msg, MOD_DPRINT_BASE + (":" + ctx if len(ctx) > 0 else ""))

var Audio = load(MOD_PATH + "/lib/GDScriptAudioImport.gd").new()
var LevelVerifier = load(MOD_PATH + "/scripts/level_verifier.gd").new()
var LevelEditor = load(MOD_PATH + "/scenes/LevelEditor.tscn").instance()
var loaded_level_names = []

# Checks the default paths for levels in case only a filename is given
static func get_file_path(key: String, dict: Dictionary) -> String:
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

# Prep level.json data for loading into the game
func handle_level_data(lvl: Dictionary) -> bool:
	# handle tscn
	var scene_path = get_file_path("level_scene", lvl)
	if scene_path != "":
		dprint("    - Found level scene at: %s" % [ Mod.path_wrap(scene_path) ], "handle_level_data")
		var errs = LevelVerifier.check_scene(scene_path, lvl)
		if len(errs) == 0:
			lvl["scene_path"] = scene_path
		else:
			dprint("ERROR: Failed to load level scene:", "handle_level_data")
			for err in errs:
				dprint("\t-> " + err, "handle_level_data")
			return false
	elif lvl.level_scene != "":
		dprint("ERROR: Couldn't find level scene at: %s" % [ Mod.path_wrap(lvl.level_scene) ], "handle_level_data")
		return false
	else:
		dprint("ERROR: No level scene found!", "handle_level_data")
		return false

	# handle image
	var image_path = get_file_path("image", lvl)
	if image_path != "":
		var img = Image.new()
		if image_path.begins_with("res://"):
			lvl["image"] = load(image_path)
		else:
			var err = img.load(image_path)
			if err == OK:
				var tex = ImageTexture.new()
				tex.create_from_image(img, 0)
				lvl["image"] = tex
				dprint("    - Found level preview image at: %s" % [ Mod.path_wrap(lvl.get("image")) ], "handle_level_data")
			else:
				dprint("WARNING: Failed to open level preview image at path: %s" % [ Mod.path_wrap(lvl.get("image")) ], "handle_level_data")
				lvl["image"] = null
	else:
		if lvl.get("image"):
			dprint("WARNING: Couldn't get level preview image from path: %s" % [ Mod.path_wrap(lvl.get("image")) ], "handle_level_data")
		lvl["image"] = null

	# handle music
	var music_path = get_file_path("music", lvl)
	if music_path != "" and music_path.get_extension() == "ogg":
		lvl["music"] = load(music_path) if music_path.begins_with("res://") else Audio.loadfile(music_path)
		dprint("    - Found level music: " + Mod.path_wrap(music_path), "handle_level_data")
	elif music_path.get_extension() != "ogg":
		dprint("WARNING: Couldn't load level music, make sure it's in .ogg format", "handle_level_data")
		lvl["music"] = null
	else:
		if lvl.get("music"):
			dprint("WARNING: Couldn't find level music!", "handle_level_data")
		lvl["music"] = null

	# handle ambience
	var amb_path = get_file_path("ambience", lvl)
	if amb_path != "" and amb_path.get_extension() == "ogg":
		lvl["ambience"] = load(amb_path) if amb_path.begins_with("res://") else Audio.loadfile(amb_path)
		dprint("    - Found level ambience track: %s" % [ Mod.path_wrap(amb_path) ], "handle_level_data")
	elif amb_path.get_extension() != "ogg":
		dprint("WARNING: Couldn't load level ambience track, make sure it's in .ogg format.", "handle_level_data")
		lvl["ambience"] = null
	else:
		if lvl.get("ambience"):
			dprint("WARNING: Couldn't find level ambience track!", "handle_level_data")
		lvl["ambience"] = null

	# handle dialogue
	var dialogue_path = ""
	var dialogue_init = false
	if lvl.has("dialogue"):
		if lvl["dialogue"] is String:
			dialogue_path = get_file_path("dialogue", lvl)
		elif lvl["dialogue"] is float:
			dprint("   - Level will use the dialogue from level %s" % [ str(lvl["dialogue"]) ], "handle_level_data")
			lvl["dialogue"] = int(lvl["dialogue"])
			dialogue_init = true
		elif lvl["dialogue"] is Array:
			if (lvl["dialogue"].size() > 0):
				dprint("   - Loaded " + str(lvl["dialogue"].size()) + " lines of NPC dialogue", "handle_level_data")
				dialogue_init = true
			else:
				dprint("Empty dialogue array!", "handle_level_data")
		else:
			dprint("Invalid dialogue value, must be a string (Godot file path), string array (direct input) or integer (level number)", "handle_level_data")

	var f = File.new()
	if f.open(dialogue_path, File.READ) == OK:
		dprint("    - Found dialogue file: %s" % [ Mod.path_wrap(dialogue_path) ], "handle_level_data")
		var json = JSON.parse(f.get_as_text())
		if json.error == OK and json.result is Array:
			if json.result.size() == 0:
				dprint("No lines of level dialogue in dialogue file!", "handle_level_data")
				f.close()
				return false
			lvl["dialogue"] = json.result
			dprint("   - Loaded " + str(lvl["dialogue"].size()) + " lines of NPC dialogue", "handle_level_data")
			dialogue_init = true
		else:
			var err = json.error_string
			if !(json.result is Array):
				err = "file isn't an array"
			dprint("Failed to parse dialogue file!" + " (line: " + str(json.error_line) + ", error: " + err + ")", "handle_level_data")

	if !dialogue_init and dialogue_path != "":
		dprint("WARNING: Couldn't add dialogue or none found, defaulting to [\"...\"]", "handle_level_data")
	f.close()

	# pad fish tickers to 4 characters (for those 3 letter ticker fish)
	if lvl.has("fish"):
		for i in range(0, len(lvl["fish"])):
			if not (lvl["fish"][i] is String):
				dprint("WARNING: '" + lvl["fish"][i] + "' is not a valid fish ticker string, using default fish pool", "handle_level_data")
				lvl["fish"] = null
				break
			if len(lvl["fish"][i]) != 4:
				lvl["fish"][i] = "%-4s" % lvl["fish"][i]

	# correct ranks
	if lvl.has("ranks") and (lvl.get("ranks").get("normal") or lvl.get("ranks").get("hell")):
		var ranks = lvl["ranks"]
		var arrs = ["normal", "hell"]
		for a in arrs:
			if ranks.has(a):
				if !(ranks[a] is Array) or !(len(ranks[a]) == 3):
					dprint("WARNING: Rank times for " + a + " are not an array of three whole numbers, defaulting to [0, 0, 0]", "handle_level_data")
					ranks[a] = [0, 0, 0]
				elif !(ranks[a][0] is float) or !(ranks[a][1] is float) or !(ranks[a][2] is float):
					dprint("WARNING: Rank times for " + a + " are not all numbers, converting them", "handle_level_data")
					ranks[a] = [abs(float(ranks[a][0])), abs(float(ranks[a][1])), abs(float(ranks[a][2]))]
			else:
				dprint("WARNING: Missing " + a + " rank times, defaulting them to 0", "handle_level_data")
				ranks[a] = [0, 0, 0]
		if lvl.has("normal_stock_s") and not (lvl["normal_stock_s"] is float):
			dprint("WARNING: Invalid normal_stock_s value, defaulting to 0", "handle_level_data")
			lvl["normal_stock_s"] = 0
		if lvl.has("hell_stock_s") and not (lvl["hell_stock_s"] is float):
			dprint("WARNING: Invalid hell_stock_s value, defaulting to 0", "handle_level_data")
			lvl["hell_stock_s"] = 0
	return true

func load_level(current_dir: String, dir_name: String) -> Dictionary:
	var path = current_dir.plus_file(dir_name)
	dprint("Scanning %s" % [ Mod.path_wrap(path) ], "load_level")
	var dir = Directory.new()
	var lvl = null
	var files = []
	var loaded_count = 0
	var json_valid = false
	dir.open(path)
	dir.list_dir_begin(true, true)
	var fname = dir.get_next()
	while fname != "":
		var ext = fname.get_extension()
		if ext == "pck" or ext == "zip":
			files.append(dir.get_current_dir() + "/" + fname)
		elif fname == "level.json":
			lvl = {}
			var json = File.new()
			dprint(" - Reading level data from JSON file: %s" % [ Mod.path_wrap(dir.get_current_dir().plus_file(fname)) ], "load_level")
			if json.open(dir.get_current_dir() + "/" + fname, File.READ) == OK:
				lvl = JSON.parse(json.get_as_text())
				var json_errs = LevelVerifier.check_json(lvl.result)
				if lvl.error == OK and lvl.result is Dictionary and json_errs.empty():
					if lvl.result.has("name") and loaded_level_names.find(lvl.result.name) != -1:
						dprint("WARNING: Level with name \"" + lvl.result.name + "\" already exists, not loading this level", "load_level")
						dir.list_dir_end()
						return { }
					json_valid = true
				elif lvl.error != OK:
					match lvl.error:
						ERR_PARSE_ERROR: dprint("ERROR: Problem on line " + str(lvl.error_line) + " of level.json in " + path, "load_level")
						_: dprint("ERROR: Unspecified, code " + lvl.error, "load_level")
				elif !(lvl.result is Dictionary):
					dprint("ERROR: JSON is not an object (not enclosed in {}) for level.json in " + path, "load_level")
				elif !json_errs.empty():
					dprint("ERROR: Failed to load level.json:", "load_level")
					for err in json_errs:
						dprint("\t-> " + err, "load_level")
				json.close()
			else:
				dprint("ERROR: Failed to open level.json!", "load_level")
		fname = dir.get_next()
	dir.list_dir_end()

	if json_valid:
		for f in files:
			var loaded = ProjectSettings.load_resource_pack(f)
			if loaded:
				dprint("   - Loaded " + Mod.path_wrap(f), "load_level")
				loaded_count += 1
			else: dprint("    - Failed to load " + Mod.path_wrap(f), "load_level")
		if !lvl.result.has("name"):
			lvl.result["name"] = dir_name
		if !handle_level_data(lvl.result):
			loaded_count = -1
		return lvl.result if loaded_count > -1 else {}
	elif lvl == null:
		dprint("ERROR: No level.json found!", "load_level")
	return {}

const USER_LEVELS_DIR = 'user://levels'

func load_levels() -> Array:
	var levels = []
	var dir = Directory.new()
	if dir.open('user://') == OK:
		if !dir.dir_exists('user://levels'):
			dir.make_dir('user://levels')
		else:
			dir.change_dir('user://levels')
			dir.list_dir_begin(true, true)
			var fname = dir.get_next()
			while fname != "":
				if dir.current_is_dir() and fname != "_debug":
					var cur_dir = dir.get_current_dir()
					var lvl = load_level(cur_dir, fname)
					if lvl.has("name"):
						levels.append(lvl)
						loaded_level_names.append(lvl.name)
						Mod.mod_log("Finished loading level \"" + lvl["name"] + "\" by \"" + lvl["author"] + "\"", MOD_NAME)
					else:
						Mod.mod_log("Couldn't load level!", MOD_NAME)
				fname = dir.get_next()
			dir.list_dir_end()
	return levels

# Load the _debug level data, which is special because it can be built from a TrenchBroom .map
func init_debug_level():
	var map_ospath = ""
	var level_ospath = ""
	var level = {"error": "No .map found"}

	var dir = Directory.new()
	if !dir.dir_exists('user://levels'):
		dir.make_dir('user://levels')
	if dir.open('user://levels/_debug') == OK:
		#if dir.file_exists('user://qodot_fgd.tres') or dir.file_exists('user://levels/_debug/qodot_fgd.tres'):
		#	if !dir.file_exists('user://levels/_debug/qodot_fgd.tres'):
		#		dir.copy('user://qodot_fgd.tres', 'user://levels/_debug/qodot_fgd.tres')
			dir.list_dir_begin(true, true)
			var fname = dir.get_next()
			while fname != "":
				var ext = fname.get_extension()
				if ext == "map":
					map_ospath = OS.get_user_data_dir() + "/levels/_debug/" + fname
					if dir.file_exists(map_ospath.trim_suffix("map") + "tscn"):
						level_ospath = dir.get_current_dir() + "/" + fname
						level_ospath = level_ospath.trim_suffix("map") + "tscn"
					break
				fname = dir.get_next()
			dir.list_dir_end()

	if map_ospath == "":
		return level

	if map_ospath != "":
		dprint("Detected debug .map", "init_debug_level")
		level_ospath = LevelEditor.convert_map_to_tscn(map_ospath)
		if level_ospath == "":
			dprint("Failed to convert .map, not entering debug level", "init_debug_level")
			level = {"error": "Bad .map file"}

	if level_ospath != "":
		level = {}
		level["name"] = map_ospath.get_file().trim_suffix(".map")
		level["author"] = "Your author name"
		level["version"] = "0.0.0"
		level["description"] = "Your level description"
		level["objectives"] = ["Your level objectives"]
		# @TODO: Add ability to save it where it will go after loading via debug?
		#        e.g. level-name.map -> user://levels/level-name/level-name.tres
		level["level_scene"] = "user://levels/_debug/" + level_ospath.get_file()
		level["scene_path"] = level["level_scene"]

	return level

# Run when loading the mod for the first time in case it breaks someone's save somehow
func backup_saves():
	var dir = Directory.new()
	if !dir.dir_exists("user://backup"):
		dprint("No backup folder detected so this is probably the modbase's first start, backing up saves...", "backup_saves")
		dir.make_dir("user://backup")
		dir.copy("user://stocks.save", "user://backup/stocks.save")
		dir.copy("user://savegame.save", "user://backup/savegame.save")
		dir.copy("user://settings.save", "user://backup/settings.save")

func _init():
	dprint('', 'on:init')
	Mod.get_node(MOD_NAME).add_child(LevelEditor)
	backup_saves()

	dprint('init_debug_level', 'on:init')
	var debug_level = init_debug_level()
	var menu = Global.get_node("Menu")
	var showmods_btn = load(MOD_PATH + "/scenes/ShowMods.tscn").instance()
	var vbox = menu.get_node("Settings/GridContainer/PanelContainer6/VBoxContainer3/")
	vbox.add_child_below_node(vbox.get_node("CenterContainer"), showmods_btn)
	var data = Mod.get_node(MOD_NAME).data
	if !debug_level.has("error"):
		data["debug_level"] = debug_level
	else:
		dprint("Loading user levels...", 'on:init')
		data["levels"] = load_levels()
		if data["levels"].size() > 0:
			dprint("LEVEL LOADING COMPLETE: Successfully loaded " + str(data["levels"].size()) + " level(s)", 'on:init')
		else:
			dprint("LEVEL LOADING COMPLETE: No levels were loaded!", 'on:init')

	get_parent().initialized = true
