extends Button

var old_enabled_mods = {}

var outdated_modloader:bool = false

const MODLOADER_ENABLED_MODS_VAR:String = "enabled_mods"

func _ready():
	outdated_modloader = not MODLOADER_ENABLED_MODS_VAR in Mod
	
	if not outdated_modloader:
		old_enabled_mods = Mod.enabled_mods.duplicate()
	
	version_check()


func _on_ShowMods_pressed():
	show_mods_popup()
	
	if outdated_modloader:
		var warn = mods_popup.get_node("Warn")
		warn.popup_centered()
	
var mods_popup_scn = preload("res://MOD_CONTENT/CruS Mod Base/scenes/ModPopupNew.tscn")
var mods_label_scn = preload("res://MOD_CONTENT/CruS Mod Base/scenes/ModLabelNew.tscn")
var mods_popup
var more_info_popup
var toggle
var restart

var modloader_update
var modloader_update_text
var modbase_update
var modbase_update_text

func show_mods_popup():
	if is_instance_valid(mods_popup):
		mods_popup.popup_centered()
		return
	
	mods_popup = mods_popup_scn.instance()
	get_node_or_null("/root").add_child(mods_popup)
	mods_popup.find_node("ModloaderVersion").text = "Modloader version: " + Mod.MODLOADER_VERSION
	mods_popup.connect("confirmed", self, "save")
	
	more_info_popup = mods_popup.get_node("MoreInfo")
	restart = mods_popup.find_node("Restart")
	restart.text = " "
	
	var list = mods_popup.find_node("List")
	
	mods_popup.find_node("OpenMods").connect("pressed", self, "open_mods_folder")
	
	for mod in Mod.MODS:
		var label = mods_label_scn.instance()
		list.add_child(label)
		label.get_node("Label").text = mod["name"] + " " + mod["version"]
		label.get_node("More").connect("pressed", self, "more_info", [more_info_popup, mod])
		
		toggle = label.get_node("Toggle")
		toggle.connect("pressed", self, "mod_toggled", [toggle, mod])
		
		toggle.pressed = true
		
		if not outdated_modloader:
			if Mod.enabled_mods.has(mod["name"]):
				toggle.pressed = Mod.enabled_mods[mod["name"]]
			else:
				toggle.disabled = true
				
			if mod["name"] == "CruS Mod Base":
				toggle.disabled = true
		else:
			toggle.disabled = true
			#toggle.hide()
	
	
	
	modloader_update = mods_popup.find_node("ModloaderUpdate")
	modloader_update_text = mods_popup.find_node("ModloaderUpdateText")
	modbase_update = mods_popup.find_node("ModbaseUpdate")
	modbase_update_text = mods_popup.find_node("ModbaseUpdateText")
	modloader_update_text.text = "A newer version of modloader is available. (" + str(installed_modloader_version) + " -> " + str(remote_modloader_version) + ")"
	modbase_update_text.text = "A newer version of modbase is available. (" + str(installed_modbase_version) + " -> " + str(remote_modbase_version) + ")"
	modloader_update.visible = show_modloader_update
	modbase_update.visible = show_modbase_update
	
	
	
	mods_popup.popup_centered()


func more_info(info_label, mod):
	var info = info_label.find_node("Info")
	
	info.text = "Mod: " + mod["name"] + "\n" + \
	"Version: " + mod["version"] + "\n" + \
	"Author(s): " + mod["author"] + "\n" + \
	"Description: " + mod["description"]  + "\n"
	
	var info2 = info_label.find_node("Info2")
	info2.text = "\n" + "Dependencies: " + (str(mod["dependencies"])  if "dependencies" in mod else "None") + "\n" + \
	"Packs: " + (str(mod["packs"])  if "packs" in mod else "") + "\n" + \
	"Mod Path: " + (str(mod["modpath"])  if "modpath" in mod else "") + "\n" + \
	"Priority: " + (str(mod["priority"])  if "priority" in mod else "")
	
	more_info_popup.popup_centered()

func mod_toggled(tgl, mod):
	if outdated_modloader:
		return
	if Mod.enabled_mods.has(mod["name"]):
		Mod.enabled_mods[mod["name"]] = tgl.pressed
	print("Set " + mod["name"] + " enabled to " + str(tgl.pressed))
	
	restart_required = is_modified(Mod.enabled_mods, old_enabled_mods)
	
	restart.text = "The game will be restarted." if \
	restart_required else \
	" "

var restart_required:bool = false

func save():
	if outdated_modloader:
		return
	
	Mod.save_enabled_mods()
	
	if restart_required:
		OS.execute(OS.get_executable_path(), [], false)
		get_tree().quit()
	
func is_modified(current: Dictionary, original: Dictionary) -> bool:
	for key in original.keys():
		if current.has(key) and current[key] != original[key]:
			return true
	return false

func open_mods_folder():
	print(OS.get_user_data_dir())
	OS.shell_open(OS.get_user_data_dir() + "/mods")



var installed_modloader_version = ""
var remote_modloader_version = ""
var installed_modbase_version = ""
var remote_modbase_version = ""


signal found_latest_version

var checked_modloader_latest:bool = false

var show_modloader_update:bool = false
var show_modbase_update:bool = false


func version_check():
	
	installed_modloader_version = Mod.MODLOADER_VERSION
	
	for mod in Mod.MODS:
		if mod["name"] == "CruS Mod Base":
			installed_modbase_version = mod["version"]
	
	connect("found_latest_version", self, "update_latest_version")
	check_for_new_version(MODLOADER_URL)


func update_latest_version(latest):
	if not checked_modloader_latest:
		remote_modloader_version = latest
		
		if compare_versions(remote_modloader_version, installed_modloader_version) > 0:
			print("A new version of modloader is available: %s" % latest)
			show_modloader_update = true
		else:
			print("Using the modloader latest version: %s" % current_version)
		
		checked_modloader_latest = true
		check_for_new_version(MODBASE_URL)
	else:
		remote_modbase_version = latest
	
		if compare_versions(remote_modbase_version, installed_modbase_version) > 0:
			print("A new version of modbase is available: %s" % latest)
			show_modbase_update = true
		else:
			print("Using the latest modbase version: %s" % current_version)


onready var current_version = Mod.MODLOADER_VERSION

const MODLOADER_URL:String = "https://api.github.com/repos/CruS-Modding-Infrastructure/crus-modloader/releases/latest"
const MODBASE_URL:String = "https://api.github.com/repos/CruS-Modding-Infrastructure/crus-modbase/releases/latest"

func check_for_new_version(url:String):
	var http_request := HTTPRequest.new()
	add_child(http_request)

	http_request.connect("request_completed", self, "_on_request_completed")
	var error = http_request.request(url)
	if error != OK:
		print("An error occurred in the HTTP request.")

func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("Failed to get latest release info. HTTP Response Code: %s" % response_code)
		return
	
	var json = JSON.parse(body.get_string_from_utf8())
	if json.error != OK:
		print("Failed to parse JSON response.")
		return
	
	var latest_version = json.result["tag_name"]
	emit_signal("found_latest_version", latest_version)
	
	print("Latest version: %s" % latest_version)

func compare_versions(version1, version2):
	var v1 = version1.strip_edges().split(".")
	var v2 = version2.strip_edges().split(".")

	for i in range(min(v1.size(), v2.size())):
		if int(v1[i]) > int(v2[i]):
			return 1
		elif int(v1[i]) < int(v2[i]):
			return -1
	
	if v1.size() > v2.size():
		return 1
	elif v1.size() < v2.size():
		return -1
	
	return 0
