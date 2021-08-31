extends WorldEnvironment
export  var rotation_speed = 0.05
export  var z = false

var min_fog_end
var min_fog_begin
var helltexture = preload("res://Textures/sky10.png")
var helltexture2 = preload("res://Textures/sky11.png")

export var ignore_cursed_sky = false

func _ready():
	if Global.hope_discarded and Global.CURRENT_LEVEL != 18 and !ignore_cursed_sky:
		environment.background_sky.panorama = helltexture
		environment.fog_color = Color(1, 0, 0)
		if Global.ending_2:
			environment.fog_color = Color(0, 1, 0)
			environment.background_sky.panorama = helltexture2
		environment.background_color = environment.fog_color
	if Global.reflections:
		environment.ss_reflections_enabled = true
	else :
		environment.ss_reflections_enabled = false
	min_fog_end = environment.fog_depth_end
	min_fog_begin = environment.fog_depth_begin
	environment.fog_depth_begin = clamp(Global.draw_distance / 2, 0, min_fog_begin)
	environment.fog_depth_end = clamp(Global.draw_distance, 0, min_fog_end)
	if Global.draw_distance < 60:
		var image:Image = environment.background_sky.panorama.get_data()
		image.lock()
		var color = image.get_pixel(0, 0)
		var size = image.get_size()
		for p in range(1000):
			color = color.blend(image.get_pixel(rand_range(0, size.x), rand_range(0, size.y)))
		environment.fog_color = color
	if Global.draw_distance <= 30:
		environment.background_mode = 1
		environment.background_color = environment.fog_color
func _physics_process(delta):
	if z:
		environment.background_sky_rotation.x += rotation_speed * delta
		return 
	environment.background_sky_rotation.y += rotation_speed * delta
