class_name ActivityIcon
extends Control
var action_id: String="boxing"
var tint: Color=Color("ffc16c")
static var atlas: Texture2D
func _ready() -> void:
	if custom_minimum_size.x<=0:custom_minimum_size=Vector2(48,48)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if atlas==null:atlas=load("res://assets/art/action_icons_v03.png")
func _draw() -> void:
	var side: float=minf(size.x,size.y)
	var rect=Rect2((size-Vector2.ONE*side)/2,Vector2.ONE*side)
	if action_id in ["social","date"]:
		var points=PackedVector2Array([Vector2(0.5,.9),Vector2(.07,.46),Vector2(.07,.2),Vector2(.3,.1),Vector2(.5,.28),Vector2(.7,.1),Vector2(.93,.2),Vector2(.93,.46)])
		for i in points.size():points[i]=rect.position+points[i]*side
		draw_colored_polygon(points,Color("ff82a6") if action_id=="date" else Color("9eaeff"))
		return
	var index: int=0
	if action_id in GameCatalog.data().actions:index=int(GameCatalog.action(action_id).get("icon",0))
	elif action_id in GameCatalog.extra().items:index=int(GameCatalog.extra().items[action_id].icon)
	elif action_id in GameCatalog.extra().skills:index=int(GameCatalog.extra().skills[action_id].icon)
	if atlas!=null:
		var cell=atlas.get_size()/Vector2(6,4)
		draw_texture_rect_region(atlas,rect,Rect2(Vector2(index%6,int(index/6))*cell,cell))
