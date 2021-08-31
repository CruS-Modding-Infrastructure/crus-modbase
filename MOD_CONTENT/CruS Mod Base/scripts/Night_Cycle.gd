extends DirectionalLight





var t = 0
var time = 12
onready  var env:WorldEnvironment = get_parent().get_node("WorldEnvironment")
var init_fog = Color(0, 0, 0)
var init_energy = 1
export  var min_light:float = 0
var init_energy_ambient:float = 1
onready  var audio_player:AudioStreamPlayer = AudioStreamPlayer.new()

export  var darkness = false
export  var permanight = false
export var debug_time = -1

var init_sky_color
onready  var musicbus = AudioServer.get_bus_index("Music")

onready var orig_env = {}

func _ready():
	orig_env["fd_begin"] = env.environment.fog_depth_begin
	orig_env["fd_end"] = env.environment.fog_depth_end
	orig_env["al_color"] = Color(env.environment.ambient_light_color.to_html())
	orig_env["bg_mode"] = env.environment.background_mode
	orig_env["init_fog"] = Color(env.environment.fog_color.to_html())
	orig_env["init_sc"] = Color(env.environment.background_color.to_html())
	
	if rand_range(0, 100) > 90 or Global.implants.head_implant.fishing_bonus:
		Global.rain = true
	else :
		Global.rain = false
	add_child(audio_player)
	audio_player.stream = load("res://Sfx/sfx100v2_thunder_02.ogg")

	if Global.hope_discarded:
		return 
	init_energy = light_energy
	init_energy_ambient = env.environment.ambient_light_energy
	if not Global.rain:
		init_fog = env.environment.fog_color
		init_sky_color = env.environment.background_color
	else :
		if Global.CURRENT_LEVEL != Global.L_SWAMP:
			env.environment.fog_depth_begin = 0
			env.environment.fog_depth_end = 100
			env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		init_fog = Color(0.6, 0.6, 0.6)
		init_sky_color = Color(0.6, 0.6, 0.6)
		env.environment.background_mode = 1
	
	if debug_time == -1:
		debug_time = OS.get_time().hour
func _physics_process(delta):
	if not darkness:
		light_energy = lerp(light_energy, init_energy, clamp(delta * 30, 0, 1))
	
		
		
	if Global.hope_discarded:
		return 

	
	if darkness:
		if Global.player.global_transform.origin.y < - 0.5:
			AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), - 80, 0.05))
			light_energy = lerp(light_energy, 0, 0.2)
			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, 0, 0.2)
			env.environment.fog_color = lerp(env.environment.fog_color, Color(0, 0, 0), 0.2)
			return 
		elif not is_equal_approx(env.environment.ambient_light_energy, init_energy_ambient):
			AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), Global.music_volume, 0.05))
			if not Global.rain:
				light_energy = lerp(light_energy, init_energy, 0.2)
			else :
				light_energy = lerp(light_energy, init_energy, delta * 30)
			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, init_energy_ambient, 0.2)
			env.environment.fog_color = lerp(env.environment.fog_color, init_fog, 0.2)
	
	if fmod(t, 60) != 0 and t != 0:
		t += 1
		return 
		
	t += 1
	if rand_range(0, 100) > 95 and Global.rain and not darkness:
		light_energy = 100
		var timer = Timer.new()
		add_child(timer)
		timer.connect("timeout", self, "thunder")
		timer.one_shot = true
		timer.start(2)
	
	
	time = debug_time if debug_time >= 0 else OS.get_time().hour
	
	if time == 0:
		time = 24
	var t_norm = (time - 0) / (24 - 0)
	t_norm = wrapf(t_norm, 0, 1)
	var dist:float = abs(12 - time)
	var t_norm_light:float = (dist - 0) / (12 - 0)
	t_norm_light = clamp(t_norm_light, 0, 0.95)
	t_norm_light = 1 - t_norm_light
	env.environment.fog_color = Color(init_fog.r * t_norm_light, init_fog.g * t_norm_light, init_fog.b * t_norm_light)
	env.environment.background_color = env.environment.fog_color
	if not permanight:
		env.environment.background_energy = clamp(t_norm_light, min_light, 1)
		
	t_norm_light = clamp(t_norm_light + 0.5, 0.8, 1)
	light_color = Color(t_norm_light, t_norm_light, 1)
	
	
	

	t_norm = wrapf(((t_norm - 0.5) * PI * 2) - PI / 2, - PI, PI)
	
	
func thunder():
	audio_player.pitch_scale = 0.5 + rand_range(0, 0.5)
	if not audio_player.playing:
		audio_player.play()
