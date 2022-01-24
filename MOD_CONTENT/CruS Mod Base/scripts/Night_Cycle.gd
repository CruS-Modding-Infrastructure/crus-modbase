extends DirectionalLight
tool

onready var toolctx := Engine.editor_hint
onready var gamectx := not toolctx

func dprint(msg: String, ctx: String = "") -> void:
	if Engine.editor_hint:
		print("[%s] %s" % [ "CMB:Night_Cycle" + (":" + ctx if len(ctx) > 0 else ""), msg])
	else:
		Mod.mod_log(msg, "CMB:Night_Cycle" + (":" + ctx if len(ctx) > 0 else ""))

var t = 0
var time = 12

onready var env = get_parent().get_node_or_null("WorldEnvironment")

var init_fog = Color(0, 0, 0)
onready var audio_player = AudioStreamPlayer.new()

func _set_init_energy(value: float) -> void:
	init_energy = value
	if toolctx:
		light_energy = init_energy

func _set_init_energy_ambient(value: float) -> void:
	init_energy_ambient = value
	if toolctx:
		env.environment.ambient_light_energy = init_energy_ambient

export (float) var init_energy:         float = 1.0 setget _set_init_energy
export (float) var min_light:           float = 0.0
export (float) var init_energy_ambient: float = 1.0 setget  _set_init_energy_ambient

export (bool) var darkness = false
export (bool) var permanight = false

func _set_debug_time(value: int) -> void:
	if value == -1:
		debug_time = value
	if value >= 0:
		debug_time = value % 24

export (int, -1, 24) var debug_time = -1  setget _set_debug_time

# Get modified, environment modified light_energy
func get_active_light_energy() -> float:
	return light_energy_base + light_energy_thunder_mod

# Update light energy level base for computing light_energy
func set_base_light_energy(energy: float) -> void:
	dprint('Updating base light energy: %s => %s' % [ light_energy, energy ])
	light_energy_base = energy

# Stores base light energy, should be used for configuration.
var light_energy_base:        float = 1.0
# Stores modification of light energy by thunder env effect
var light_energy_thunder_mod: float = 0.0
var thunder_energy:           float = 90.0
# Temp debug state tracker
var thunder_sound_queued:     bool = false

var init_sky_color
onready var musicbus = AudioServer.get_bus_index("Music")

func using_custom_time() -> bool:
	return debug_time >= 0

class EnvCopy:
	var fd_begin: float
	var fd_end:   float
	var al_nrg:   float
	var al_color: Color
	var bg_mode:  int
	var init_fog: Color
	var init_sc:  Color
	var toolctx := Engine.editor_hint

	func _init():
		pass

	func record(world) -> void:
		fd_begin = world.environment.fog_depth_begin
		fd_end   = world.environment.fog_depth_end
		al_nrg   = world.environment.ambient_light_energy
		al_color = Color(world.environment.ambient_light_color.to_html())
		bg_mode  = world.environment.background_mode
		init_fog = Color(world.environment.fog_color.to_html())
		init_sc  = Color(world.environment.background_color.to_html())

	func restore(g_light) -> void:
		g_light.env.environment.fog_depth_begin      = fd_begin
		g_light.env.environment.fog_depth_end        = fd_end
		g_light.env.environment.ambient_light_color  = al_color
		g_light.env.environment.ambient_light_energy = al_nrg
		g_light.init_fog                             = init_fog
		g_light.init_sky_color                       = init_sc
		g_light.env.environment.background_mode      = bg_mode

onready var orig_env = EnvCopy.new()

func record_orig_env() -> void:
	if not toolctx:
		orig_env.record(env)
		dprint('Stored Original Env:\n%s' % [ JSON.print(orig_env, '\t') ], 'record_orig_env')

func tool_retry_get_env() -> void:
	env = get_tree().edited_scene_root.get_node("WorldEnvironment")

# @NOTE: Testing fixing the weather snapping on load - anything past the
#        dprint statements was added and possibly causing the issue
func _init() -> void:

	dprint('<INIT> light_energy_base:   %s' % [ light_energy_base   ], 'on:init')
	dprint('       init_energy:         %s' % [ init_energy         ], 'on:init')
	dprint('       init_energy_ambient: %s' % [ init_energy_ambient ], 'on:init')

func _ready():
	dprint('', 'on:ready')
	if gamectx:
		env = get_parent().get_node("WorldEnvironment")
	else:
		tool_retry_get_env()

	if not is_instance_valid(env):
		if toolctx:
			print('Failed to get WorldEnvironment, dumping child nodes of edited_scene_root')
			for child in get_tree().edited_scene_root.get_children():
				print(' - @%s' % [ child ])

	dprint('<READY> light_energy_base:   %s' % [ light_energy_base   ], 'on:ready')
	dprint('        init_energy:         %s' % [ init_energy         ], 'on:ready')
	dprint('        init_energy_ambient: %s' % [ init_energy_ambient ], 'on:ready')

	# @TODO: Convert orig_env use into a subclass
	if gamectx:
		dprint('Performing inital save of original env dict.', 'on:ready')
		record_orig_env()

	if gamectx:
		# Debugging rain being enabled after replaying custom level smh
		var rand_range_val = rand_range(0, 100)
		if 	rand_range_val > 90:
			dprint('Random range value > 90, setting rain state (%s).' % [ rand_range_val ], 'on:ready')
			Global.rain = true

		elif Global.implants.head_implant.fishing_bonus:
			dprint('Fishing implant active, enabling rain.', 'on:ready')
			Global.rain = true
		else:
			dprint('Disabling rain.', 'on:ready')
			Global.rain = false

		add_child(audio_player)
		audio_player.stream = load("res://Sfx/sfx100v2_thunder_02.ogg")

		if Global.hope_discarded:
			dprint("Hope Discarded enabled, exiting _ready early.", 'on:ready')
			return

	if gamectx:
		dprint("light_energy_base    => %s"       % [ light_energy_base ],               'on:ready')
		dprint("init_energy          => %s => %s" % [ init_energy, light_energy_base  ], 'on:ready')
		init_energy = light_energy_base
	else:
		light_energy_base = init_energy

	if gamectx:
		init_energy_ambient = env.environment.ambient_light_energy
		dprint("init_energy_ambient  => %s" % [ init_energy_ambient ], 'on:ready')
	else:
		env.environment.ambient_light_energy = init_energy_ambient

	if toolctx or not Global.rain:
		init_fog = env.environment.fog_color
		init_sky_color = env.environment.background_color

	else:
		if Global.CURRENT_LEVEL != Global.L_SWAMP:
			env.environment.fog_depth_begin = 0
			env.environment.fog_depth_end = 100
			env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		init_fog = Color(0.6, 0.6, 0.6)
		init_sky_color = Color(0.6, 0.6, 0.6)
		env.environment.background_mode = 1

	if debug_time == -1:
		debug_time = OS.get_time().hour
		dprint('Using irl debug_time (%s)' % [ debug_time ], 'on:ready')
	else:
		dprint('Using preset debug_time (%s)' % [ debug_time ], 'on:ready')

func _physics_process(delta) -> void:
	if not env:
		if toolctx:
			tool_retry_get_env()
		# Skip process if env not initialized yet, or better yet process should be disabled until
		# then
		return

	# @TODO: Actually check if all this isnt tool context
	if not toolctx and not darkness:
		# lerp thunder energy instead of base light_energy, and then add it to base
		light_energy = light_energy_base + light_energy_thunder_mod
		light_energy_thunder_mod =- lerp(light_energy_thunder_mod, 0.0, clamp(delta * 30, 0, 1))
		if thunder_sound_queued:
			dprint("thunder_level -> %s" % [ light_energy_thunder_mod ], 'on:physics_process')

	if gamectx:
		if Global.hope_discarded:
			return

		# If darkness mode
		if darkness:
			if Global.player.global_transform.origin.y < - 0.5:
				AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), - 80, 0.05))
				light_energy = lerp(light_energy, 0, 0.2)

				env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, 0, 0.2)
				env.environment.fog_color = lerp(env.environment.fog_color, Color(0, 0, 0), 0.2)

				# (Exit early stops thunder effect roll below)
				return
		else:
			AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), Global.music_volume, 0.05))
			if not Global.rain:
			#light_energy = lerp(light_energy, init_energy, 0.2)
				pass
			else:
				#light_energy = lerp(light_energy, init_energy, delta * 30)
				# lerp(light_energy_thunder_mod, 0.0, clamp(delta * 30, 0, 1))
				pass

			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, init_energy_ambient, 0.2)
			if not is_equal_approx(env.environment.ambient_light_energy, init_energy_ambient):
				env.environment.fog_color = lerp(env.environment.fog_color, init_fog, 0.2)

		if toolctx:
			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, init_energy_ambient, 0.2)
			if not is_equal_approx(env.environment.ambient_light_energy, init_energy_ambient):
				env.environment.fog_color = lerp(env.environment.fog_color, init_fog, 0.2)

		if gamectx:
			if fmod(t, 60) != 0 and t != 0:
				t += 1
				return

			t += 1
			var thunder_roll: int = rand_range(0, 100)
			if not darkness and Global.rain and thunder_roll > 95:
				dprint('Rolled thunder: %s' % [ thunder_roll] , 'on:physics_process')
				fire_thunder()

	time = debug_time if debug_time >= 0 else OS.get_time().hour
	# print('[Night_Cycle:on:physics_process] time => %s' % [ time ])

	if time == 0:
		time = 24

	var t_norm = (time - 0) / (24 - 0)
	t_norm = wrapf(t_norm, 0, 1)

	var dist: float = abs(12 - time)
	var t_norm_light: float = (dist - 0) / (12 - 0)
	t_norm_light = clamp(t_norm_light, 0, 0.95)
	t_norm_light = 1 - t_norm_light

	env.environment.fog_color = Color(init_fog.r * t_norm_light, init_fog.g * t_norm_light, init_fog.b * t_norm_light)
	env.environment.background_color = env.environment.fog_color

	if not permanight:
		env.environment.background_energy = clamp(t_norm_light, min_light, 1)

	t_norm_light = clamp(t_norm_light + 0.5, 0.8, 1)
	light_color = Color(t_norm_light, t_norm_light, 1)

	t_norm = wrapf(((t_norm - 0.5) * PI * 2) - PI / 2, - PI, PI)

var thunder_timer: Timer
func fire_thunder() -> void:
	dprint('Firing thunder effect', 'fire_thunder')
	#dprint('Initial light levels:',  'fire_thunder')
	#dprint('  -> light_energy => %s' % [ light_energy ], 'fire_thunder')
	#dprint('  -> init_energy  => %s' % [ init_energy  ], 'fire_thunder')

	light_energy_thunder_mod = thunder_energy
	thunder_timer = Timer.new()
	thunder_sound_queued = true
	add_child(thunder_timer)
	thunder_timer.connect("timeout", self, "thunder")
	thunder_timer.one_shot = true
	thunder_timer.start(2)

func thunder():
	thunder_sound_queued = false
	audio_player.pitch_scale = 0.5 + rand_range(0, 0.5)
	if not audio_player.playing:
		audio_player.play()
