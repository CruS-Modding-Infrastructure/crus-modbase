#GimbalControl Node v0.1.0

#	Notes:
#	- To use as a camera gimbal, just place a camera inside and reset it's rotation if it was rotated.
# 	- All offsets/transforms of it's children are kept.
#	- Do not scale parent nodes though, everything gets messed up.
#	- If the target is a sibling of the node, it MUST be above the node in the hierarchy (so that it moves first).
#	- Technically this script could be made to extend a camera node, but this way you could move anything
#	  with the gimbal (e.g. change lighting by rotating a light around a point)
#	- An interpolated camera can be used to target the node itself, but it zooms in a bit weird when rotating around.
#	- While running, you can't change the "origin/basis".
#	- To "reset" the rotation (relative to it's current target or real transform), you should use set_rotation_to(right/left in degrees,up/down in degrees).
#  - Note that keyboard ghosting can prevent multiple keys being registered (as might be the case if you're moving/looking only with keys)

extends Spatial

signal look_right(amount)
signal look_left(amount)
signal first_person_entered(distance)
signal first_person_exited(distance)

#PROPERTIES

# optional, can also just be parented to target
export (NodePath) var target setget set_target, get_target

# whether when we change a target as we move closer to it or stay the same distance
# or min/max distance if out of range
export (bool) var move_to_target_on_change = true
# whether to interpolate target changes (rotation, location optional)
export (bool) var interpolate_target_change = true
# if move_to_target_on_change is true, allow zooming to stop the distance interpolation (rotation can't be stopped)
export (bool) var allow_stop_move_interpolation = true

# whether to interpolate the set_rotation_to method
# this will correctly rotate around the target/origin in an arc
# the translation is not interpolated, it will move with the target at the speed the target moves
export (bool) var interpolate_set_rotation_to = true
# when you use set_rotation_to and interpolate_set_rotation_to is true, allows any movement to stop the interpolation
# will not stop rotations when interpolating between targets
export (bool) var allow_stop_rotation_interpolation = true

# multiplier for interpolations, higher is faster.
export (float) var interpolation_speed = 2

# whether it tilts with it's parent/target or stays aligned to the global axis
export (bool) var rotate_globally = false setget set_rotate_globally, get_rotate_globally

# regular speed
export (int) var move_speed = 2
# speed when mouse look is on
export (int) var look_speed = 0.3
# zoom can seem slow
export (int) var zoom_multiplier = 3
# because of how the scroll button is triggered, it seems even slower than regular zoom
# is multiplied by zoom_multiplier
export (int) var scroll_zoom_multiplier = 5

# zoom/distances (used interchangeably, initally this was just a camera gimbal)
export (int) var default_distance = 10
export (int) var min_distance = 0
export (int) var max_distance = 50

# note that the zoom toggles ignores min/max distances
export var zoom_toggle_distances = [0, 20, 40]
# a convenient way to change the array order, in this case true causes it to go from 40 to 0, far to near
export (bool) var reverse_zoom_toggle_order = true

# the distance at which the first person signal is triggered
export (int) var first_person_distance = 1

# rotation limits (the signal emitted ignores these)
# unlimit by setting to 360
export (int, 0, 360) var rotation_limit_up_in_degrees = 90 # technically negative
export (int, 0, 360) var rotation_limit_down_in_degrees = 90

# default unlimited
export (int, 0, 360) var rotation_limit_right_in_degrees = 360
export (int, 0, 360) var rotation_limit_left_in_degrees = 360 # technicall negative

# initial start rotaion (-x = left, -y = down, around target/origin)
export (Vector2) var start_rotation_in_degrees = Vector2(0,30)

# whether to invert movement
export (bool) var reverse_up_down = false
export (bool) var reverse_left_right = false

# reverse mouse wheel zoom (regular zoom keys work the same)
export (bool) var reverse_mouse_zoom = false
# move by dragging (enable mouse look should be off)
export (bool) var enable_mouse_dragging = false
# whether to hide the mouse when enable mouse look isn't on
export (bool) var hide_mouse = true
# enable mouse look, hides mouse by default
export (bool) var enable_mouse_look = true

# to control the a parent character's rotation with look right/left:
#- disable right left rotations in the node
#- connect the signal emitted to your character

# to disable right/left completely (no checking right/left input), disable = true and emit = false
export (bool) var disable_right_left = false
export (bool) var emit_right_left = true

# change the action names (note some options handle mouse vs key inputs differently e.g. reverse_mouse_zoom)
export (String) var look_right_action_name = "look_right"
export (String) var look_left_action_name = "look_left"
export (String) var look_up_action_name = "look_up"
export (String) var look_down_action_name = "look_down"
export (String) var look_click_action_name = "look_click"
export (String) var look_zoom_in_action_name = "look_zoom_in"
export (String) var look_zoom_out_action_name = "look_zoom_out"
export (String) var look_zoom_toggle_action_name = "look_zoom_toggle"

#PRIVATE VARIABLES
# shorthand variables for my sanity
var look_right # look_right_action_name
var look_left # look_left_action_name
var look_up # look_up_action_name
var look_down # look_down_action_name
var look_click # look_click_action_name
var look_zoom_in # look_zoom_in_action_name
var look_zoom_out # look_zoom_out_action_name
var look_zoom_toggle # look_zoom_toggle_action_name

var rot_limit_up # rotation_limit_up_in_degrees
var rot_limit_down # rotation_limit_down_in_degrees
var rot_limit_left # rotation_limit_left_in_degrees
var rot_limit_right # rotation_limit_right_in_degrees

# movement vector, used as (left/right, up/down, distance/zoom)
var movement = Vector3(0,0,0)

# whether we have a target
var target_mode = false
# so we can do things differently during initial ready (e.g. getsets)
var ready = false
# in set_target and align_to_target function we need to know the first time it was called
var first_call_target = true

# whether the mouse is zooming/dragging/looking
var mouse_wheel_zooming = false
var mouse_dragging = false
var mouse_looking = false

# whether we're in first person distance
var in_first_person = false

# zoom related variables for toggle
var zoom_toggled = false
var zoom_levels # array
var zoom_level # index

# to keep track of key states
var key_right = false
var key_left = false
var key_up = false
var key_down = false
var key_zoom_in = false
var key_zoom_out = false

# for when we change from having a target to not, and are not in global mode
# we have to have some way to reset our orientation to the initial "local" orientation
var original_global_transform
# we also need a reference to the transform origin to move with parent
var original_transform

# helps keep track of whether our target moved
var target_last_location

# the distance we need to be from the target
var current_distance

# interpolation_related
var forcing_transform = false
var interpo_end = {
	"basis": null,
	"look_target": null
}
var interpo_start # initial transform
var interpo_is_rotation = false
var slerp_value = 0
var lerp_value = 0
var lerp_stop = false
var rotation_stop = false

func set_rotation_to(rotation_vector):
	var start = {
		"origin": original_global_transform.origin if !target else target.global_transform.origin,
		"basis": global_transform.basis
	}
	if target_mode:
		global_transform.origin = target.global_transform.origin
	else:
		global_transform.origin = original_global_transform.origin

	# to set angle, start with a "default" vector (pointing forward)
	var start_position = Vector3(0,0,1)

	# rotate right/left then up/down
	start_position = start_position.rotated(Vector3(0,1,0), deg2rad(rotation_vector.x))
	start_position = start_position.rotated(Vector3(-1,0,0), deg2rad(rotation_vector.y))

	if !rotate_globally:
		# apply correct basis if not rotating globally
		var basis = target.global_transform.basis if target_mode else original_global_transform.basis
		start_position = 	basis * start_position

	global_transform.origin = original_global_transform.origin if !target else target.global_transform.origin
	global_translate(start_position * current_distance)

	# must be set like this otherwise end is a Transform and other properties can't be assigned
	var end = {
		"origin": global_transform.origin
	}

	if interpolate_set_rotation_to:
		interpo_is_rotation = true
		align_to_target(start, end)
	else:
		interpo_is_rotation = false
		align_to_target()

func get_target():
	return target

func set_target(value):
	if ready:
		if value != null and value != "Null":
			target = get_node(value)
			if target != null:
				target_mode = true
				target_last_location = target.global_transform.origin
			else:
				target = null
				target_mode = false
		else:
			target_mode = false

		# align_to_target takes care of looking at our new target	with interpolation if needed
		if !first_call_target:
			align_to_target()
	else:
		target = value

func get_rotate_globally():
	return rotate_globally

func set_rotate_globally(value):
	rotate_globally = value
	if ready:
		align_to_target()

func align_to_target(start = null, end = null):
	var look_target_transform = target.global_transform if target_mode else original_global_transform
	var look_target = look_target_transform.origin
	var vector_up = Vector3(0,1,0) # global

	if !rotate_globally: # replace vector_up if not in global mode
		var target_basis = look_target_transform.basis
		vector_up = target_basis * Vector3(0,1,0)

	var initial_transform = global_transform

	# will handle looking at target and setting orientation correctly
	if look_target != global_transform.origin:
		# if we're directly above/beneath our target, look at doesn't work
		var dir_to_target = (global_transform.origin - look_target).normalized()

		if dir_to_target != vector_up and -dir_to_target != vector_up:
			look_at(look_target, vector_up)
		else:
			# in which case we just rotate forward/backward 90 degrees to face it
			rotate_object_local(Vector3(-1,0,0) if dir_to_target.y > 0 else Vector3(1,0,0), deg2rad(90))
	else:
		# in the event we're already at the target, we can use other ways to get the "correct" rotation
		if !rotate_globally:
			global_transform.basis = look_target_transform.basis # todo mix with rotation, just change z?
		else:
			rotation.z = 0 # we just need to untilt the node

	var new_distance
	if !move_to_target_on_change:
		new_distance = look_target.distance_to(initial_transform.origin)
		if new_distance < min_distance:
			current_distance = min_distance
		elif new_distance > max_distance:
			current_distance = max_distance
	else:
		current_distance = current_distance

	global_transform.origin = look_target + (initial_transform.origin - look_target).normalized() * current_distance

	var final_transform = global_transform

	if interpo_is_rotation or (!first_call_target and interpolate_target_change):

		# reset the transform so now we can slowly transition to the new one
		global_transform.origin = initial_transform.origin
		global_transform.basis = initial_transform.basis

		if start == null:
			start =  {
				"basis": global_transform.basis,
				"origin": global_transform.origin
			}

		if end == null:
			end = {}
			end.origin = final_transform.origin

		end.basis = final_transform.basis
		end.look_target = look_target

		force_transform(start, end)

func force_transform(start, end):
	interpo_start = start
	interpo_end = end
	lerp_value = 0
	slerp_value = 0
	forcing_transform = true # must be set last

func rotation_slerp(delta):
	slerp_value += delta * interpolation_speed
	if slerp_value > 1:
		slerp_value = 1

	if !rotation_stop:
		var current_rotation = Quat(interpo_start.basis).slerp(interpo_end.basis, slerp_value)
		global_transform.basis = Basis(current_rotation)

	if slerp_value == 1 or rotation_stop:
		# only slerp should reset these
		forcing_transform = false
		rotation_stop = false
		movement = Vector3()
		slerp_value = 0

func location_lerp(delta):
	lerp_value += delta * interpolation_speed
	if lerp_value > 1:
		lerp_value = 1

	if !lerp_stop and !rotation_stop:
		# If we're not changing targets we want the interpolation to be at the correct distance from
		# the target/origin to make it travel in an arc we do the same thing as when we move
		# normally, and translate after rotating this is why the slerp has to be called first
		# there's no need to actually interpolate
		if interpo_is_rotation:
			if !target_mode:
				global_transform.origin = interpo_start.origin
			else:
				global_transform.origin = target.global_transform.origin # we can't use interpo start because this can have changed

			translate(Vector3(0,0, current_distance))
#		regular interpolation
		elif target_mode: # there should never be any reason why we're not in target mode
			global_transform.origin = interpo_start.origin.linear_interpolate(target.global_transform.origin + interpo_end.basis * Vector3(0,0,current_distance), lerp_value)

	if lerp_value == 1:
		lerp_value = 0
		# lerp should rest this one as only it uses it
		interpo_is_rotation = false

func _ready():

	ready = true

	# set shorthand variables
	rot_limit_up = -deg2rad(rotation_limit_up_in_degrees)
	rot_limit_down = deg2rad(rotation_limit_down_in_degrees)
	rot_limit_left = -deg2rad(rotation_limit_left_in_degrees)
	rot_limit_right = deg2rad(rotation_limit_right_in_degrees)

	look_right = look_right_action_name
	look_left = look_left_action_name
	look_up = look_up_action_name
	look_down = look_down_action_name
	look_click = look_click_action_name
	look_zoom_in = look_zoom_in_action_name
	look_zoom_out = look_zoom_out_action_name
	look_zoom_toggle = look_zoom_toggle_action_name

	zoom_levels = zoom_toggle_distances

	zoom_level = 1 if reverse_zoom_toggle_order else 0 # zoom_toggle_distances.size() if reverse_zoom_toggle_order else 0

	if zoom_levels.size() <= 1:
		print("WARNING in " + str(name) + ": Zoom Toggle Distances array should contain at least 2 values.")

	current_distance = default_distance

	# set transforms
	# reset scale because scale will messes with a bunch of things
	# to scale things, scale within a child node
	scale = Vector3(1,1,1)
	original_global_transform = global_transform
	original_transform = transform

	# properly set target variable (setget just does the path of target)
	# align_to_target will not be called
	set_target(target)
	# because we need to know where the target is then do the start rotation relative to that
	set_rotation_to(start_rotation_in_degrees)
	#THEN align to the target
	align_to_target()
	# now we can set this to false
	first_call_target = false

	if enable_mouse_dragging and enable_mouse_look:
		print("WARNING in " + str(name) + ": Enable Mouse Dragging and Enable Mouse Look cannot be enabled at the same time, Mouse Dragging has been disabled.")
		enable_mouse_dragging = false

	if enable_mouse_look:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if hide_mouse and !enable_mouse_look: # only one input mode can be set
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

#PROCESS INPUT
# using _input both to separate this logic and because sometimes we need event.is_action_pressed (which only fires on first press)
# as opposed to Input.is_action_pressed (which fires when held)
func _input(event):

	#MOUSE LOOK
	if enable_mouse_look and event.is_class("InputEventMouseMotion") and event.relative:
		movement = Vector3(event.relative.x if reverse_left_right else -event.relative.x, event.relative.y if reverse_up_down else -event.relative.y, movement.z)
		mouse_looking = true
	else:
		mouse_looking = false
		movement = Vector3(0,0, movement.z)

	#RIGHT/LEFT
	if !disable_right_left or (disable_right_left and emit_right_left):
		if event.is_action_released(look_right):
			movement.x = 0
			key_right = false
		if event.is_action_released(look_left):
			movement.x = 0
			key_left = false

		if Input.is_action_pressed(look_right):
			movement.x = 1 if reverse_left_right else -1
			key_right = true
		if Input.is_action_pressed(look_left):
			movement.x = -1 if reverse_left_right else 1
			key_left = true

		if key_right and key_left:
			movement.x = 0

	#UP/DOWN
	if event.is_action_released(look_up):
		movement.y = 0
		key_up = false
	if event.is_action_released(look_down):
		movement.y = 0
		key_down = false

	if Input.is_action_pressed(look_up):
		movement.y = 1 if reverse_up_down else -1
		key_up = true
	if Input.is_action_pressed(look_down):
		movement.y = -1 if reverse_up_down else 1
		key_down = true

	if key_up and key_down:
		movement.y = 0

	#ZOOM IN/OUT

	# because of how scroll is registered (it looks like _input fires twice quickly and _process is never reached)
	# movement/keys must be reset later, so we use mouse_wheel_zooming to trigger that
	# there might be other types of input this happens to?
	if !event.is_class("InputEventMouseButton"):
		if event.is_action_released(look_zoom_in):
			movement.z = 0
			key_zoom_in = false
		if event.is_action_released(look_zoom_out):
			movement.z = 0
			key_zoom_out = false
	elif event.is_action(look_zoom_out) or event.is_action(look_zoom_in):
		mouse_wheel_zooming = true

	if Input.is_action_pressed(look_zoom_in):
		movement.z = 1 if reverse_mouse_zoom and event.is_class("InputEventMouseButton") else -1
		key_zoom_in = true
	if Input.is_action_pressed(look_zoom_out):
		movement.z = -1 if reverse_mouse_zoom and event.is_class("InputEventMouseButton") else 1
		key_zoom_out = true

	if key_zoom_in and key_zoom_out:
		movement.z = 0

	#ZOOM TOGGLE
	if event.is_action_pressed(look_zoom_toggle):
		movement.z = 0
		zoom_toggled = true
		zoom_level += -1 if reverse_zoom_toggle_order else 1
		if zoom_level >= zoom_levels.size():
			zoom_level = 0
		elif zoom_level < 0:
			zoom_level = zoom_levels.size() - 1
	else:
		zoom_toggled = false

	#CLICKING/DRAGGING
	if enable_mouse_dragging:
		if event.is_action_pressed(look_click):
			mouse_dragging = true
		if event.is_action_released(look_click):
			mouse_dragging = false
			movement.x = 0
			movement.y = 0
		if mouse_dragging and event.is_class("InputEventMouseMotion"):
			var mouse_move = event.relative
			movement = Vector3(mouse_move.x if reverse_left_right else -mouse_move.x, mouse_move.y if reverse_up_down else -mouse_move.y, movement.z)


#APPLY MOVEMENT
# once input has processed we get a vector (right/left, up/down, zoomin/out) to change movement
# and can apply delta from here
func _process(delta):

	var target_moved = target_mode and target_last_location != target.global_transform.origin

	if !forcing_transform and (movement.length() != 0 or target_moved):
		if target_mode:
			target_last_location = target.global_transform.origin

		var speed

		# change speed if looking with mouse
		if mouse_looking:
			speed = look_speed * delta
		else:
			speed = move_speed * delta

		# get our target location (or initial local transform if no target)
		var look_target_transform = target.global_transform if target_mode else original_global_transform
		var look_target = look_target_transform.origin

		# record how far away we are from the target
		var distance = global_transform.origin.distance_to(look_target)

		# move our object to the target (all rotations happen around the object's center)
		if target_mode:
			global_transform.origin = look_target
		else:
			transform.origin = original_transform.origin

		# get real rotation, used to calculate new rotation and check limits
		# orthonormalized needed because after a few rotations we have messed up floats
		var start_rotation
		if rotate_globally:
			start_rotation = global_transform.basis.orthonormalized().get_euler()
		else:
			# gets the rotation as if local to target
			if target:
				# if we're local to ourselves, change the transform (later used to rotate around)
				start_rotation = (look_target_transform.affine_inverse() * global_transform).basis.orthonormalized().get_euler()
			else:
				start_rotation = (look_target_transform.affine_inverse() * transform).basis.orthonormalized().get_euler()

		#LEFT/RIGHT
		if movement.x != 0:
			var difference = movement.x * speed
			var new_rot = start_rotation.y + difference

			if !disable_right_left:
				if new_rot < rot_limit_right and new_rot > rot_limit_left:
					if !rotate_globally:
						# if we want the node to tilt with the character
						# we can get the relative axis to tilt about by applying it's global basis to an up vector
						if target:
							# so here Vector3(0,1,0) is the target's y axis
							global_rotate((look_target_transform.basis * Vector3(0,1,0)).normalized(), difference)
						else:
							# if we have no target, we can just rotate around the local y axis
							rotate(Vector3(0,1,0), difference)
					else:
						# if we don't want the node to tilt with a parent node, we can just rotate around the global y axis
						global_rotate(Vector3(0,1,0), difference)

			if emit_right_left:
					emit_signal("look_right" if movement.x > 0 else "look_left", difference)

		#UP/DOWN
		if movement.y != 0:
			var difference = movement.y * speed
			var new_rot = start_rotation.x + difference

			if new_rot > rot_limit_up and new_rot < rot_limit_down:
				# To understand why just rotate_object_local is enough imagine the cube is alone at
				# 0,0,0 and it's pole tilted as rotated by any parent nodes that's our starting
				# point always, so using any rotation method can cause tilting problems in global
				# mode to get around this for both modes. If we're in global mode, we can set the
				# rotation so the pole is aligned with global y axis in _ready otherwise we leave it
				# alone, rotated/tilted with it's parent and the axis/pole we're rotating up/down
				# towards will stay put
				rotate_object_local(Vector3(1,0,0), difference)

		# now that the object is rotated, we push it back along it's z axis
		# this works because the push is relative to it's rotation
		if !zoom_toggled:
			speed = speed * zoom_multiplier
			speed = speed * scroll_zoom_multiplier if mouse_wheel_zooming else speed
			var new_distance = current_distance + movement.z * speed
			if new_distance > min_distance and new_distance < max_distance:
				current_distance += movement.z * speed
		else:
			current_distance = zoom_levels[zoom_level]

		translate(Vector3(0,0,current_distance))

		#FIRST PERSON SIGNAL
		if !in_first_person and current_distance <= first_person_distance:
			in_first_person = true
			emit_signal("first_person_entered", current_distance )
		elif in_first_person and current_distance  > first_person_distance:
			in_first_person = false
			emit_signal("first_person_exited", current_distance )

		#SPECIAL INPUT CASES
		if mouse_wheel_zooming: # special reset
			key_zoom_in = false
			key_zoom_out = false
			mouse_wheel_zooming = false
			movement.z = 0

		if mouse_dragging or enable_mouse_look: # special reset
			movement = Vector3(0,0, movement.z)

	elif forcing_transform:
		# in mid transform, zooming can stop the distance interpolation if allowed
		if movement.z !=0:
			if move_to_target_on_change and allow_stop_move_interpolation:
				var new_distance = global_transform.origin.distance_to(target.global_transform.origin if target else interpo_end.look_target)
				if new_distance > min_distance < max_distance:
					lerp_stop = true
					current_distance = new_distance

		if allow_stop_rotation_interpolation and interpo_is_rotation and movement.length() !=0:
			rotation_stop = true

		# if forcing_transform we call the interpolations
		# rotation must be called first
		rotation_slerp(delta)
		location_lerp(delta)
