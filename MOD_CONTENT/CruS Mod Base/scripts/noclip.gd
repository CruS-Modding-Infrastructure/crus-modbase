extends KinematicBody

var in_use = false
var dir = Vector3()
var velocity = Vector3.ZERO
var show_on_exit = true
var keep_weapon_disabled = false
var last_col_layer

export var max_speed = 500
var speed = max_speed

func _ready():
	$Pivot / Camera.fov = Global.FOV

func _process(delta):
	transform.basis = Global.player.transform.basis
	Global.player.weapon.disabled = true

func _physics_process(delta):
	var gxf = get_global_transform()
	if in_use:
		dir = Vector3()
		if Input.is_action_pressed("movement_jump"):
			dir += gxf.basis.y
		if Input.is_action_pressed("crouch"):
			dir -= gxf.basis.y
		if Input.is_action_pressed("movement_forward"):
			dir += gxf.basis.z
		if Input.is_action_pressed("movement_backward"):
			dir -= gxf.basis.z
		if Input.is_action_pressed("movement_left"):
			dir += gxf.basis.x
		if Input.is_action_pressed("movement_right"):
			dir -= gxf.basis.x
		dir = dir.normalized()
	Global.player.global_transform.origin = $Pivot.global_transform.origin
	velocity = move_and_slide(dir * speed * delta)

func player_use(hide_nodes=true):
	if not in_use and not Global.player.dead:
		$Pivot / Camera.current = true
		var player_head = Global.player.get_parent().get_node("Position3D/Rotation_Helper")
		global_transform.origin = player_head.global_transform.origin
		$Pivot / Camera.rotation = player_head.get_node("Camera").rotation
		if hide_nodes:
			Global.UI.hide()
			Global.border.hide()
			Global.player.get_parent().hide()
			Global.player.hide()
			Global.player.grab_hand.hide()
			Global.player.weapon.disabled = true
		Global.player.crush_check.disabled = true
		Global.player.disabled = true
		Global.player.collision_box.disabled = true
		last_col_layer = Global.player.collision_layer
		Global.player.collision_layer = 0
		speed = max_speed
		yield (get_tree(), "idle_frame")
		in_use = true

func player_exit(show_nodes=true):
	show_on_exit = show_nodes
	if not Global.player.dead:
		$Pivot / Camera.current = false
		Global.player.player_velocity = Vector3.ZERO
		Global.player.get_parent().get_node("Position3D/Rotation_Helper/Camera").transform.basis = $Pivot / Camera.transform.basis
		in_use = false
		Global.player.crush_check.disabled = false
		var preview_box = Global.get_node("BorderContainer").get_node("Preview_Box")
		var preview_off = !preview_box or (preview_box and !preview_box.visible)
		if show_nodes and preview_off:
			Global.UI.show()
			Global.border.show()
			Global.player.get_parent().show()
			Global.player.show()
			Global.player.grab_hand.show()
		if !keep_weapon_disabled:
			Global.player.weapon.disabled = false
		Global.player.player_view.current = true
		Global.player.crush_check.disabled = false
		Global.player.disabled = false
		Global.player.collision_box.disabled = false
		Global.player.collision_layer = last_col_layer
		queue_free()

func _exit_tree():
	# hopefully fix border remaining gone if you die in noclip
	if Global.player.died:
		Global.border.show()
	player_exit(show_on_exit)

func _on_Vehicle_body_entered(body):
	if body.has_method("physics_object"):
		body.queue_free()

func _input(event):
	if not in_use:
		return 
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = Global.mouse_sensitivity * Global.player.player_view.fov / Global.FOV
		var rot_deg_y = deg2rad(event.relative.y * sensitivity)
		if Global.invert_y:
			rot_deg_y *= - 1
		$Pivot.rotate_x(rot_deg_y)
		if Global.player.max_gravity > 0:
			rotate_y(deg2rad(event.relative.x * sensitivity * - 1))
		else :
			rotate_y(deg2rad(event.relative.x * sensitivity))
		var camera_rot = $Pivot.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, - 75, 75)
		$Pivot.rotation_degrees = camera_rot
	if event is InputEventMouseButton and event.shift:
		match event.button_index:
			BUTTON_WHEEL_UP:
				speed *= 1.5
			BUTTON_WHEEL_DOWN:
				speed /= 1.5
