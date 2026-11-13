class_name ActivityIcon
extends Control
var action_id: String = "boxing"
var tint: Color = Color("ffc16c")
func _ready() -> void:
	custom_minimum_size = Vector2(32,32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(32,32))
	var c = tint
	if action_id in ["rest","life_rest","mental","natural_recovery"]:
		draw_rect(Rect2(4,17,24,4),c)
		draw_rect(Rect2(4,9,4,17),c)
		draw_rect(Rect2(9,13,6,4),c)
		draw_rect(Rect2(17,10,11,7),c)
	elif action_id in ["job","delivery"]:
		draw_rect(Rect2(5,8,22,19),c)
		draw_rect(Rect2(8,4,16,5),c)
		draw_rect(Rect2(9,11,14,3),Color("203447"))
		draw_rect(Rect2(18,19,5,5),Color("203447"))
	elif action_id in ["weights","power"]:
		draw_rect(Rect2(3,8,5,17),c)
		draw_rect(Rect2(24,8,5,17),c)
		draw_rect(Rect2(8,14,16,5),c)
	elif action_id in ["wrestling","bjj","judo"]:
		draw_circle(Vector2(10,9),4,c)
		draw_circle(Vector2(23,11),4,c)
		draw_line(Vector2(10,14),Vector2(20,23),c,5)
		draw_line(Vector2(22,16),Vector2(9,25),c,5)
	elif action_id in ["cardio","agility"]:
		draw_rect(Rect2(8,8,7,12),c)
		draw_rect(Rect2(8,19,20,7),c)
		draw_rect(Rect2(2,12,4,3),c)
	else:
		draw_rect(Rect2(9,4,15,16),c)
		draw_rect(Rect2(5,10,8,9),c)
		draw_rect(Rect2(11,21,12,7),c)
		draw_rect(Rect2(12,7,8,3),Color("fff0c4"))
	draw_set_transform(Vector2.ZERO)
