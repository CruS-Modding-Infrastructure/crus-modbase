extends Control
var keylist
export  var x_size = 640
func _ready():
	pass


func come():
	show()
	rect_size.y = 0
	rect_size.x = x_size
	rect_position.y = 60
	while (rect_size.y < 600):
		rect_size.y += 50
		if (rect_size.y > 600):
			rect_size.y = 600
		yield (get_tree(), "idle_frame")
func go():
	# the settings panel will never go away if you have four buttons in the bottom-right because of this code??? 
	# never noticed this animation anyways if it even works so oh well
#	while (rect_size.y > 600):
#		rect_size.y -= 50
#		yield (get_tree(), "idle_frame")
	hide()


func _on_Punishment_Mode_toggled(button_pressed):
	Global.punishment_mode = button_pressed


func _on_Chaos_Mode_toggled(value):
	Global.chaos_mode = value
