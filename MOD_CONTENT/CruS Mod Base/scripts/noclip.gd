extends Spatial

func dprint(msg: String, ctx: String = "") -> void:
	Mod.mod_log('%s' % [ msg ],
			"noclip:" + ctx if len(ctx) > 0 else "noclip")

var in_use = false
var dir = Vector3()
var velocity = Vector3.ZERO
var show_on_exit = true
var keep_weapon_disabled = false
var last_col_layer

# FOV increment modifier for holding base key
export (float) var fov_inc = 0.5
# FOV increment modifier for holding both keys
export (float) var fov_inc_mod             = 5.0
export (float) var fov_max                 = 130
export (float) var fov_min                 = 20

export (float) var pov_max_yaw               = 80

export (bool)  var filter_reload_key_combo = true
export (float) var noclip_speed_accel_mod  = 1.1
export (float) var base_speed              = 1
export (float) var process_scale           = 0.6
export (float) var max_speed_mult          = 80
# Modifier for speed when called through _process
export (float) var noclip_speed_process_scale = 0.3

onready var in_debug_map = Mod.get_node("CruS Mod Base").data.has("debug_level")

var motion := Vector3.ZERO
var initial_rotation = PI / 2# $Pivot / Camera.rotation.y

var speed     = base_speed
var speed_cap = base_speed * max_speed_mult

const MOVE_ACTION := {
	UP      = "movement_jump",
	DOWN    = "Use",
	FORWARD = "movement_forward",
	BACK    = "movement_backward",
	LEFT    = "movement_left",
	RIGHT   = "movement_right",
}

enum UPDATE_MODE {
	PROCESS,
	PHYSICS_PROCESS
}

const UPDATE_MODE_DEFAULT: = UPDATE_MODE.PROCESS

# Save export, but dont assign - only assign if not previously set by another instance
export (UPDATE_MODE) var update_mode: int setget set_update_mode

# Used to store values between instancing in cheats (not all are actually used)
const State := {
	update_mode = null,
	fov = null
}
# Or dont
const Stateful: bool = true

func set_noclip_fov(new_fov: float) -> void:
	fov = clamp(new_fov, fov_min, fov_max)
	$Pivot / Camera.fov = fov

export (float) var fov setget set_noclip_fov

func player_use(hide_nodes = true):
	if in_use or Global.player.dead:
		return

	match update_mode:
		UPDATE_MODE.PHYSICS_PROCESS:
			set_physics_process(true)
		UPDATE_MODE.PROCESS:
			set_process(true)
		_:
			push_error('Unknown update mode: %s' % [ update_mode ])
			return

	# If noclip used in level pre-start
	if Global.player.start_flag == false:
		Global.player.start_flag = true
		# Clear `intro` parameter in case called at the start of a level
		Global.player.amp = 0
		Global.player.shader_screen.material.set_shader_param("amplitude", Global.player.amp)
		Global.player.shader_screen.material.set_shader_param("intro",     false)
		Global.player.set_process_input(true)
		Global.player.start_flag = true

	reset_keymod_player_states()

	var player_head = Global.player.get_node("../Position3D/Rotation_Helper")
	global_transform.origin = player_head.global_transform.origin
	$Pivot.rotation.x = player_head.rotation.x
	$Pivot / Camera.current = true
	$Pivot / Camera.transform.basis = player_head.get_node("Camera").transform.basis
	$Pivot / Camera.rotation.y = player_head.get_node("Camera").rotation.y
	$Pivot / Camera.rotation.z = player_head.get_node("Camera").rotation.z
	update_to_player_basis()

	if hide_nodes:
		hide_ui()

	Global.player.crush_check.disabled = true
	Global.player.disabled = true
	Global.player.collision_box.disabled = true
	Global.player.reticle.force_disable_draw(true, true)
	last_col_layer = Global.player.collision_layer
	Global.player.collision_layer = 0
	speed = base_speed


	in_use = true
	yield (get_tree(), "idle_frame")

func player_exit(show_nodes=true):
	show_on_exit = show_nodes

	if Global.player.dead:
		return

	$Pivot / Camera.current = false

	in_use = false

	var bc = Global.get_node("BorderContainer")
	var preview_box = bc.get_node("Preview_Box") if bc.has_node("Preview_Box") else null
	var preview_off = not preview_box or (preview_box and not preview_box.visible)

	if show_nodes and preview_off:
		restore_ui()

	if not keep_weapon_disabled:
		Global.player.weapon.disabled = false

	Global.player.player_velocity = Vector3.ZERO
	Global.player.reticle.force_disable_draw(false, true)
	Global.player.reticle.show()
	Global.player.player_view.current = true
	Global.player.crush_check.disabled = false
	Global.player.disabled = false
	Global.player.collision_box.disabled = false
	Global.player.collision_layer = last_col_layer

	reset_keymod_player_states()

	var cam = $Pivot/Camera
	var player_head = Global.player.get_node("../Position3D/Rotation_Helper")
	var player_cam: Camera = player_head.get_node("Camera")

	Global.player.global_transform.origin = global_transform.origin# $Pivot.global_transform.origin
	player_head.rotation.x = $Pivot.rotation.x
	player_cam.rotation.y = cam.rotation.y
	player_cam.rotation.z = cam.rotation.z

	queue_free()

func _ready():
	# @NOTE: If State.fov is ever used it should replace this
	$Pivot / Camera.fov = Global.FOV
	fov = Global.FOV
	initial_rotation = $Pivot / Camera.rotation.y

	# Initialize State if first instance (and Stateful)
	if Stateful:
		if State.update_mode == null:
			State.update_mode = UPDATE_MODE_DEFAULT
		else:
			# Restore last saved state from previous instance
			update_mode = State.update_mode
	else:
		update_mode = UPDATE_MODE_DEFAULT

	set_process(false)
	set_physics_process(false)

func update_to_player_basis():
	transform.basis = Global.player.transform.basis

func _process(delta):
	if not in_use:
		set_process(false)
		update_to_player_basis()
	else:
		# Global.player.weapon.disabled = true
		if update_mode == UPDATE_MODE.PROCESS:
			# Global.player.weapon.zoom_flag = false
			update_to_player_basis()
			_move_process(delta, false)
			Global.player.global_transform.origin = global_transform.origin

func _physics_process(delta: float) -> void:
	if not in_use:
		set_physics_process(false)
		update_to_player_basis()
	else:
		# Global.player.weapon.disabled = true
		if update_mode == UPDATE_MODE.PHYSICS_PROCESS:
			# Global.player.weapon.zoom_flag = false
			update_to_player_basis()
			_move_process(delta, true)
			Global.player.global_transform.origin = global_transform.origin

func cycle_update_mode() -> void:
	var new_mode = (update_mode + 1) % UPDATE_MODE.keys().size()
	match new_mode:
		UPDATE_MODE.PHYSICS_PROCESS, UPDATE_MODE.PROCESS:
			set_update_mode(new_mode)

func set_update_mode(new_mode: int) -> void:
	match new_mode:
		UPDATE_MODE.PHYSICS_PROCESS:
			# dprint('Switching to physics process movement', 'set_update_mode')

			if in_use:
				if is_processing():
					set_process(false)

				set_physics_process(true)

		UPDATE_MODE.PROCESS:
			# dprint('Switching to process movement', 'set_update_mode')
			if in_use:
				if is_physics_processing():
					set_physics_process(false)

				set_process(true)

		_:
			push_error('Invalid update enum %s' % [ new_mode ])
			# Return early to stop updating/recording new inner value
			return

	if Stateful and State.update_mode != new_mode:
		State.update_mode = new_mode

	update_mode = new_mode

func _input(event: InputEvent):
	if not in_use:
		return

	if event is InputEventKey:
		if (event.pressed and not event.echo):
			# Need to add an emum/const value for key
			if event.get_scancode_with_modifiers() == KEY_T:
				cycle_update_mode()

			else:
				if Input.is_action_pressed(MOVE_ACTION.FORWARD):
					motion.x -= 1
				if Input.is_action_pressed(MOVE_ACTION.BACK):
					motion.x += 1

				if Input.is_action_pressed(MOVE_ACTION.LEFT):
					motion.z += 1
				if Input.is_action_pressed(MOVE_ACTION.RIGHT):
					motion.z -= 1

				if Input.is_action_pressed(MOVE_ACTION.UP):
					motion.y += 1
				if Input.is_action_pressed(MOVE_ACTION.DOWN):
					motion.y -= 1

	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var sensitivity: float = (Global.mouse_sensitivity
				* fov / Global.FOV
				# Inline replacement for modloader fork's resolution adaptive
				# sensitivity
				# ```
				#mouse_sensitivity * (720 / Global.resolution[1])
				# ```
				* 720 / Global.resolution[1]
			)

			var rot_deg_y = deg2rad(event.relative.y * sensitivity)
			if Global.invert_y:
				rot_deg_y *= - 1
			$Pivot.rotate_x(rot_deg_y)
			if Global.player.max_gravity > 0:
				rotate_y(deg2rad(event.relative.x * sensitivity * - 1))
			else:
				rotate_y(deg2rad(event.relative.x * sensitivity))
			var camera_rot = $Pivot.rotation_degrees
			camera_rot.x = clamp(camera_rot.x, -pov_max_yaw, pov_max_yaw)
			$Pivot.rotation_degrees = camera_rot

	if event is InputEventMouseButton:
		# Also checks shift key, so has exclusive priority over speed control
		if Input.is_key_pressed(KEY_CONTROL):
			if Input.is_key_pressed(KEY_SHIFT):
				match event.button_index:
					BUTTON_WHEEL_UP:
						set_noclip_fov(($Pivot / Camera.fov) - (fov_inc * fov_inc_mod))
					BUTTON_WHEEL_DOWN:
						set_noclip_fov(($Pivot / Camera.fov) + (fov_inc * fov_inc_mod))
			else:
				match event.button_index:
					BUTTON_WHEEL_UP:
						set_noclip_fov(($Pivot / Camera.fov) - fov_inc)
					BUTTON_WHEEL_DOWN:
						set_noclip_fov(($Pivot / Camera.fov) + fov_inc)

		elif Input.is_key_pressed(KEY_SHIFT):
			match event.button_index:
				BUTTON_WHEEL_UP:
					speed = clamp(speed * noclip_speed_accel_mod, 0.0, speed_cap)
				BUTTON_WHEEL_DOWN:
					# Defensively clamping this for the inevitable accidental
					# fractional acceleration modifier
					speed = clamp(speed / noclip_speed_accel_mod, 0.0, speed_cap)

# When enabled moving up or down will move along the global y axis instead of moving relative to
# the camera
export (bool) var lock_y_axis = true

func _move_process(delta: float, in_physics_process: bool = false) -> void:
	var gxf: Transform = $Pivot / Camera.get_global_transform()
	if lock_y_axis:
		gxf.basis.y *= Vector3(0, 1, 0)
		# gxf.basis.z *= Vector3(1, 0, 1)
		# gxf.basis.x *= Vector3(1, 0, 1)

	dir = Vector3()

	# @NOTE: I'd assume doing all the input checks in `_input()` would be faster, especially when
	#        using _process isntead of _physics_process. To do so, `gxf` needs to integrate `motion`
	#        that's updated in `_input()`
	if Input.is_action_pressed(MOVE_ACTION.UP):
		dir += gxf.basis.y
	if Input.is_action_pressed(MOVE_ACTION.DOWN):
		dir -= gxf.basis.y

	if Input.is_action_pressed(MOVE_ACTION.FORWARD):
		dir += gxf.basis.z
	if Input.is_action_pressed(MOVE_ACTION.BACK):
		dir -= gxf.basis.z
	if Input.is_action_pressed(MOVE_ACTION.LEFT):
		dir += gxf.basis.x
	if Input.is_action_pressed(MOVE_ACTION.RIGHT):
		dir -= gxf.basis.x

	dir = dir.normalized()
	velocity = clamp(speed if in_physics_process else speed * noclip_speed_process_scale, -speed_cap, speed_cap)
	if is_zero_approx(velocity):
		return

	transform.origin -= dir * velocity

	Global.player.global_transform.origin = $Pivot.global_transform.origin

func hide_ui() -> void:
	Global.border.hide()
	Global.player.get_parent().hide()
	Global.player.hide()
	Global.player.grab_hand.hide()
	Global.UI.hide()
	Global.player.weapon.disabled = true

func restore_ui() -> void:
	Global.border.show()
	Global.player.get_parent().show()
	Global.player.show()
	Global.UI.show()
	Global.player.grab_hand.show()

func _exit_tree():
	set_process(false)
	set_physics_process(false)
	# hopefully fix border remaining gone if you die in noclip
	if Global.player.died:
		Global.border.show()
	player_exit(show_on_exit)

func _on_Vehicle_body_entered(body):
	if body.has_method("physics_object"):
		body.queue_free()

const viewmodel_offset_x: float = -0.135

# Normalizes any player input related state for noclip
# - Crouch
# - Zoom (weapon or noclip)
# - Movement Tilt
func reset_keymod_player_states() -> void:
	# Unset crouch flag, and simulate release
	Global.player.crouch_flag = false
	if Input.is_action_pressed("crouch"):
		Input.action_release("crouch")

	# Unset zoom flag, simulate release, and reinitialize to user fov
	Global.player.set_scope(false)
	Global.player.weapon.zoom_flag = false
	Global.player.get_node("../Position3D/Rotation_Helper/Camera").fov = Global.FOV
	if Input.is_action_pressed("zoom"):
		Input.action_release("zoom")
	# Also update viewmodel position
	Global.player.get_node("../Position3D/Rotation_Helper/Weapon/Player_Weapon").translation.x = viewmodel_offset_x

	# Reset lean
	Global.player.get_node("../Position3D/Rotation_Helper/Camera").transform.basis.x = Vector3(-1, 0, 0)
