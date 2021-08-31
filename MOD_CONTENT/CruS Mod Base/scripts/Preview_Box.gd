extends Control

export var offset_width = 0
onready var prev_parent = get_parent()
onready var new_parent = Global.get_node("BorderContainer")

func _ready():
	set_global_position(Vector2(0, 0))

func _draw():
	var v_sz = get_viewport().size
	draw_rect(Rect2(0, 0, offset_width, v_sz.y), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(v_sz.x - offset_width, 0, offset_width, v_sz.y), Color(0, 0, 0, 0.6))

func setup(width=offset_width):
	if !new_parent.get_node("Preview_Box"):
		prev_parent.remove_child(self)
		new_parent.add_child(self)
	offset_width = width
	update()
