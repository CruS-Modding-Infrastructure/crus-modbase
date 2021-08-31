extends Spatial
export  var damage:float = 75
export  var toxic = false
onready  var raycast:RayCast = $RayCast
export  var velocity_booster = false


func AI_shoot()->void :
	
	if raycast.is_colliding():
		var body = get_parent().get_parent()
		var collider = raycast.get_collider()
		#if body and is_instance_valid(body) and "player" in body:
		#	body.player = collider
		#	if collider and is_instance_valid(collider) and "player" in collider:
		#		collider.player = body
		if velocity_booster and "velocity" in collider:
			collider.velocity -= (global_transform.origin - Vector3.UP * 0.5 - collider.global_transform.origin).normalized() * damage
		raycast.force_raycast_update()
		if toxic and collider.has_method("set_toxic"):
			collider.set_toxic()
		if collider.has_method("damage"):
			collider.damage(damage, Vector3(0, 0, 0), Vector3(0, 0, 0), global_transform.origin)
		raycast.enabled = false
		if is_instance_valid($Attack_Sound) and not $Attack_Sound.playing:
			$Attack_Sound.play()
		body.anim_player.play("Attack", - 1, 2)
		yield (get_tree().create_timer(0.5), "timeout")
		raycast.enabled = true
