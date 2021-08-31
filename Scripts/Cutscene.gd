extends Spatial





export  var next_scene = ""
export (Array, String, MULTILINE) var LINES:Array = [""]
export (Array, float) var DURATION:Array = [1]
export (String) var music
export  var instant = false
export  var line_skip = true
export  var introskip = false
var CAMERAS
onready  var TIMER = $Timer
onready  var SUBTITLE = $MarginContainer / CenterContainer / Subtitle
var current_scene = 0
var t = 0



func _ready():
	$MarginContainer / CenterContainer / Subtitle.get_font("font").size = 32 * (Global.resolution[0] / 1280)
	
	Global.menu.hide()
	if music != "":
		if music == "NO":
			Global.music.stop()
		else :
			Global.music.stream = load(music)
			Global.music.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Global.cutscene = true
	Global.border.hide()
	CAMERAS = $Cameras.get_children()
	
	
	if introskip and Global.skip_intro:
		Global.cutscene = false
		Global.border.show()
		var cmb = Mod.get_node("CruS Mod Base")
		var scn = "res://Menu/Main_Menu.tscn"
		if "debug_level" in cmb.data:
			Mod.mod_log("Debug level detected, loading debug level", cmb)
			var m = Global.menu
			#m.goto_menu(m.current_menu, m.START, 0)
			m.show_buttons(m.menu[m.START], 2, 4)
			m.in_game = true
			scn = cmb.data.debug_level.level_scene
		Global.goto_scene(scn)



func _process(delta):
	if instant:
		t += 1
		SUBTITLE.modulate = Color((cos(t * 0.01) + 1) * 0.5, 0, 0)
	if TIMER.is_stopped() and current_scene != LINES.size():
		
		current_scene = clamp(current_scene, 0, LINES.size() - 1)
		TIMER.wait_time = DURATION[current_scene]
		if CAMERAS.size() > 0:
			CAMERAS[current_scene].current = true
		SUBTITLE.text = LINES[current_scene]
		if not instant:
			SUBTITLE.speech()
		else :
			SUBTITLE.visible_characters = - 1
		current_scene += 1
		TIMER.start()
	if TIMER.is_stopped() and current_scene == LINES.size():
		Global.goto_scene(next_scene)
		Global.cutscene = false
		Global.border.show()
func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept"):
			Global.goto_scene(next_scene)
			Global.cutscene = false
			Global.border.show()
		if Input.is_action_just_pressed("movement_jump") and line_skip:
			
			TIMER.stop()
