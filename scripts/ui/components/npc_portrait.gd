class_name NpcPortrait
extends Control
var npc_id: String="jisoo"
static var atlas: Texture2D
func _ready() -> void:
	custom_minimum_size.y=maxf(custom_minimum_size.y,130)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if atlas==null:atlas=load("res://assets/art/npc_portraits_v03.png")
func _draw() -> void:
	if atlas==null or not npc_id in GameCatalog.extra().npcs:return
	var cell=atlas.get_size()/Vector2(3,1)
	var side=minf(size.x,size.y)
	var index: int=GameCatalog.extra().npcs[npc_id].portrait
	draw_texture_rect_region(atlas,Rect2((size-Vector2.ONE*side)/2,Vector2.ONE*side),Rect2(Vector2(index*cell.x,0),cell))
