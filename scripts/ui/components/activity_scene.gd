class_name ActivityScene
extends Control

var action_id: String = "boxing"
var appearance: int = 0
var clock: float = 0
var atlas: Texture2D
var paused: bool = false
var actor_texture: Texture2D
var actors: Array = []
var actors_used: int = 0
var moves_texture: Texture2D
var moves_actor: Sprite2D
var work_atlas: Texture2D
var icon_atlas: Texture2D
var accent: Color = Color("ffc16c")
const INK = Color("202437")
const SKIN = Color("e4aa7a")
const LIGHT = Color("ffce9c")

func _ready() -> void:
	if custom_minimum_size.y <= 0: custom_minimum_size.y = 225
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas = load("res://assets/art/life_atlas.png")
	actor_texture = load("res://assets/art/athlete_sheet.png")
	moves_texture=load("res://assets/art/combat_moves_v03.png")
	icon_atlas=load("res://assets/art/action_icons_v03.png")
	if ResourceLoader.exists("res://assets/art/work_atlas_v03.png"):work_atlas=load("res://assets/art/work_atlas_v03.png")
	moves_actor=Sprite2D.new()
	moves_actor.texture=moves_texture
	moves_actor.region_enabled=true
	moves_actor.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var move_palette=ShaderMaterial.new()
	move_palette.shader=load("res://assets/art/sprite_palette.gdshader")
	moves_actor.material=move_palette
	add_child(moves_actor)
	if actor_texture != null:
		for i in 2:
			var sprite = Sprite2D.new()
			sprite.texture = actor_texture
			sprite.region_enabled = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var palette = ShaderMaterial.new()
			palette.shader = load("res://assets/art/sprite_palette.gdshader")
			sprite.material = palette
			add_child(sprite)
			actors.append(sprite)

func set_action(id: String, color_index: int = 0) -> void:
	action_id = id
	appearance = color_index
	clock = 0
	queue_redraw()

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		queue_redraw()

func scene_index() -> int:
	if action_id == "job":return 1
	if action_id in ["cafe","date"]:return 4
	if action_id == "warehouse":return 5
	if action_id == "event_work":return 6
	if action_id == "coach_job":return 7
	if action_id in ["rest","life_rest","mental","natural_recovery"]: return 2
	if action_id in ["cardio","agility","delivery","social"]: return 3
	return 0

func location_name() -> String:
	return ["언더독 MMA 체육관","동네 편의점 · 야간 알바","선수 숙소 · 휴식","강변 트랙 · 아침","동네 카페","물류 창고","지역 스포츠 행사","초보 회원 지도"][scene_index()]

func rect_at(pos: Vector2, dimensions: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos.round(),dimensions),color)

func limb(a: Vector2, b: Vector2, color: Color, width: int = 7) -> void:
	var steps = maxi(1,ceili(a.distance_to(b)/2))
	for i in steps+1:
		var pos = a.lerp(b,float(i)/steps).snapped(Vector2(2,2))
		rect_at(pos-Vector2.ONE*(width+2)/2,Vector2.ONE*(width+2),INK)
	for i in steps+1:
		var pos = a.lerp(b,float(i)/steps).snapped(Vector2(2,2))
		rect_at(pos-Vector2.ONE*width/2,Vector2.ONE*width,color)

func person(pos: Vector2, pose: String, phase: float, mirrored: bool = false, other: bool = false) -> void:
	if actor_texture != null and actors_used < actors.size():
		var actor: Sprite2D = actors[actors_used]
		actors_used += 1
		actor.visible = true
		var cell = actor_texture.get_size()/4
		var column: int = int(floor(clock*7))%4
		var row_index: int = 0
		if pose in ["run","casual","carry"]:
			row_index = 1
			if pose == "casual":column=0
		elif pose == "lift": row_index = 2
		elif pose == "cashier":
			row_index = 3
			column = int(floor(clock*3))%2
		elif pose == "sit":
			row_index = 3
			column = 3
		elif pose == "sleep":
			row_index = 3
			column = 2
		elif pose == "guard": column = 0
		actor.region_rect = Rect2(Vector2(column*cell.x,row_index*cell.y),cell)
		var stage_scale = size/Vector2(384,192)
		actor.scale = Vector2(84,84)/cell*stage_scale
		actor.position = (pos+Vector2(0,-42+floorf(sin(phase)*1.3)))*stage_scale
		actor.flip_h = mirrored
		actor.rotation = (1.1 if mirrored else -1.1) if pose == "ground" else 0.0
		actor.material.set_shader_parameter("trunks_color",Color("75c5b3") if other else [Color("f06d5e"),Color("79bfff"),Color("c4a1ff")][appearance])
		return
	var shorts = [Color("f06d5e"),Color("79bfff"),Color("c4a1ff")][appearance]
	if other: shorts = Color("75c5b3")
	var bob: float = floorf(sin(phase)*2)
	var origin = pos + Vector2(0,bob)
	var lean: float = 0
	if pose in ["punch","kick"]: lean = maxf(0,sin(phase))*4
	if pose == "grapple": lean = 5
	var head = Vector2(lean,-62)
	var chest = Vector2(lean,-43)
	var hand_a = Vector2(lean+18,-41)
	var hand_b = Vector2(lean-16,-37)
	var foot_a = Vector2(-11,0)
	var foot_b = Vector2(13,0)
	if pose == "punch":
		hand_a = Vector2(26+maxf(0,sin(phase))*22,-51)
		hand_b = Vector2(8,-48)
	if pose == "kick":
		foot_b = Vector2(17+maxf(0,sin(phase))*33,-maxf(0,sin(phase))*30)
		hand_a = Vector2(19,-51)
	if pose == "lift":
		hand_a = Vector2(26,-48-maxf(0,sin(phase))*30)
		hand_b = Vector2(-26,-48-maxf(0,sin(phase))*30)
	if pose == "run":
		hand_a = Vector2(18*sin(phase),-37+9*cos(phase))
		hand_b = Vector2(-18*sin(phase),-37-9*cos(phase))
		foot_a = Vector2(18*sin(phase),-absf(9*cos(phase)))
		foot_b = Vector2(-18*sin(phase),-absf(9*sin(phase)))
	if pose == "grapple":
		hand_a = Vector2(24,-45+3*sin(phase))
		hand_b = Vector2(24,-35)
		head.y += 8
	if pose == "cashier":
		hand_a = Vector2(24,-33-8*maxf(0,sin(phase)))
		hand_b = Vector2(7,-31)
	if pose == "sit":
		foot_a = Vector2(-25,-5)
		foot_b = Vector2(25,-5)
		hand_a = Vector2(23,-17)
		hand_b = Vector2(-23,-17)
		origin.y += 13
	var stage_scale = size / Vector2(384,192)
	draw_set_transform(origin*stage_scale,0,Vector2(-1 if mirrored else 1,1)*stage_scale)
	draw_ellipse_shadow(Vector2(0,3),Vector2(25,5))
	limb(Vector2(-6,-22),foot_a,SKIN)
	limb(Vector2(7,-22),foot_b,LIGHT)
	rect_at(foot_a-Vector2(7,2),Vector2(14,6),INK)
	rect_at(foot_b-Vector2(5,2),Vector2(14,6),INK)
	rect_at(chest-Vector2(12,1),Vector2(26,25),INK)
	rect_at(chest-Vector2(10,-1),Vector2(22,20),LIGHT if not other else SKIN)
	rect_at(Vector2(-13,-25),Vector2(27,15),INK)
	rect_at(Vector2(-11,-24),Vector2(23,12),shorts)
	rect_at(Vector2(-11,-25),Vector2(23,4),Color("ffecce"))
	limb(chest+Vector2(-10,2),hand_b,SKIN)
	limb(chest+Vector2(10,2),hand_a,LIGHT)
	if pose not in ["cashier","sit","lift"]:
		for hand in [hand_a,hand_b]:
			rect_at(hand-Vector2(5,5),Vector2(11,10),INK)
			rect_at(hand-Vector2(4,4),Vector2(9,7),shorts)
	if pose == "cashier":
		rect_at(chest-Vector2(10,-1),Vector2(22,21),Color("5dab98"))
		rect_at(chest+Vector2(2,4),Vector2(5,3),Color("f8e3b4"))
	# Head, layered hair, ears and tiny facial features: entirely original pixel character.
	rect_at(head-Vector2(12,11),Vector2(24,25),INK)
	rect_at(head-Vector2(10,8),Vector2(20,21),SKIN)
	rect_at(head+Vector2(-7,-6),Vector2(17,15),LIGHT)
	rect_at(head+Vector2(-13,-8),Vector2(4,10),SKIN)
	rect_at(head+Vector2(-11,-12),Vector2(23,8),INK)
	rect_at(head+Vector2(-8,-15),Vector2(7,7),INK)
	rect_at(head+Vector2(-1,-14),Vector2(10,7),Color("30344a"))
	rect_at(head+Vector2(-10,-4),Vector2(4,8),INK)
	var blinking: bool = fmod(clock,4.2)>4.0 or pose == "sit"
	rect_at(head+Vector2(3,0),Vector2(4,1 if blinking else 3),INK)
	rect_at(head+Vector2(8,6),Vector2(3,2),Color("b97560"))
	if pose == "lift":
		var bar_y: float = hand_a.y-2
		limb(Vector2(-39,bar_y),Vector2(39,bar_y),Color("b4c4d5"),4)
		for x in [-41,33]:
			rect_at(Vector2(x,bar_y-11),Vector2(9,23),INK)
			rect_at(Vector2(x+2,bar_y-9),Vector2(5,18),Color("657a99"))
	draw_set_transform(Vector2.ZERO,0,stage_scale)

func draw_ellipse_shadow(pos: Vector2, radius: Vector2) -> void:
	# Rectangular clusters preserve the pixel-art treatment at every resolution.
	rect_at(pos-Vector2(radius.x,radius.y/2),Vector2(radius.x*2,radius.y),Color(0.05,0.08,0.14,.35))

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	actors_used = 0
	for actor in actors:actor.visible=false
	if moves_actor!=null:moves_actor.visible=false
	var virtual = Vector2(384,192)
	var scale_value = size / virtual
	if atlas != null:
		var idx=scene_index()
		var background: Texture2D=work_atlas if idx>=4 and work_atlas!=null else atlas
		var dims=background.get_size()/2
		var panel_index=idx%4
		var region=Rect2(Vector2((panel_index%2)*dims.x,int(panel_index/2)*dims.y),dims)
		draw_texture_rect_region(background,Rect2(Vector2.ZERO,size),region)
	else: draw_rect(Rect2(Vector2.ZERO,size),Color("304c60"))
	# Characters are drawn into a 384x192 pixel stage, independently of background detail.
	var phase: float = floorf(clock*9)/9.0*7
	draw_set_transform(Vector2.ZERO,0,scale_value)
	if action_id in ["judo","wrestling","bjj","kickboxing"] and moves_texture!=null:
		var row_index: int={"judo":0,"wrestling":1,"bjj":2,"kickboxing":3}[action_id]
		var cell=moves_texture.get_size()/4
		moves_actor.region_rect=Rect2(Vector2(int(floor(clock*3))%4*cell.x,row_index*cell.y),cell)
		moves_actor.position=Vector2(282 if action_id=="kickboxing" else 220,129)*scale_value
		moves_actor.scale=Vector2(168,84)/cell*scale_value
		moves_actor.visible=true
		moves_actor.material.set_shader_parameter("trunks_color",[Color("f06d5e"),Color("79bfff"),Color("c4a1ff")][appearance])
		draw_set_transform(Vector2.ZERO)
		return
	if action_id in ["rest","life_rest","natural_recovery"]:
		person(Vector2(307,138),"sleep",phase)
		draw_set_transform(Vector2.ZERO,0,scale_value)
		for i in 3:
			var y: float = 95-fmod(clock*10+i*14,42)
			var x: float = 286+i*10
			rect_at(Vector2(x,y),Vector2(7,2),Color("d7ecff"))
			rect_at(Vector2(x+4,y+2),Vector2(2,3),Color("d7ecff"))
			rect_at(Vector2(x,y+5),Vector2(7,2),Color("d7ecff"))
	elif action_id == "mental": person(Vector2(171,170),"sit",phase)
	elif action_id == "job":
		person(Vector2(281,158),"cashier",phase)
	elif action_id in ["cafe","warehouse","event_work","coach_job","cleaning","social","date"]:
		if action_id=="coach_job":
			person(Vector2(159,166),"guard",phase)
			draw_set_transform(Vector2.ZERO,0,scale_value)
			person(Vector2(284,166),"punch",phase,true,true)
		elif action_id=="cafe":person(Vector2(274,165),"cashier",phase)
		else:person(Vector2(190,168),"carry" if action_id=="warehouse" else ("cashier" if action_id=="cleaning" else "casual"),phase)
		draw_set_transform(Vector2.ZERO,0,scale_value)
		if action_id in ["warehouse","cleaning","event_work","coach_job"] and icon_atlas!=null:
			var index: int={"warehouse":14,"cleaning":13,"event_work":16,"coach_job":17}[action_id]
			var dims=icon_atlas.get_size()/Vector2(6,4)
			draw_texture_rect_region(icon_atlas,Rect2(211,117,38,38),Rect2(Vector2(index%6,int(index/6))*dims,dims))
	elif action_id == "delivery":
		person(Vector2(182,146),"run",phase)
		for x in [158,210]:
			draw_circle(Vector2(x,162),16,INK)
			draw_arc(Vector2(x,162),12,0,TAU,16,Color("b5d5dc"),3)
			limb(Vector2(x,162),Vector2(182,148),Color("6ed7c2"),3)
		limb(Vector2(182,148),Vector2(206,139),Color("6ed7c2"),3)
		rect_at(Vector2(156,99),Vector2(24,25),Color("f2a957"))
	elif action_id in ["cardio","agility"]:
		person(Vector2(180,164),"run",phase)
		for i in 3: rect_at(Vector2(115-i*12,126+i*9),Vector2(16,2),Color("f6e5b5"))
	elif action_id == "sparring":
		person(Vector2(187,166),"punch",phase)
		draw_set_transform(Vector2.ZERO,0,scale_value)
		person(Vector2(252,166),"punch",phase+2.5,true,true)
	elif action_id in ["wrestling","bjj","judo"]:
		var ground: bool = action_id == "bjj"
		person(Vector2(188,186 if ground else 163),"ground" if ground else "grapple",phase)
		draw_set_transform(Vector2.ZERO,0,scale_value)
		person(Vector2(229,186 if ground else 163),"ground" if ground else "grapple",phase+2,true,true)
	elif action_id == "weights": person(Vector2(196,166),"lift",phase)
	else:
		var punch: bool = action_id not in ["idle","gym"]
		person(Vector2(285,168),"kick" if action_id == "kickboxing" else ("punch" if punch else "guard"),phase)
		draw_set_transform(Vector2.ZERO,0,scale_value)
		if punch and sin(phase)>.65:
			for i in 5:
				var offset = Vector2(cos(i*TAU/5),sin(i*TAU/5))*10
				rect_at(Vector2(333,114)+offset,Vector2(4,4),Color("ffdf86"))
	# Reset for the next canvas draw; each person() temporarily uses local pixel coordinates.
	draw_set_transform(Vector2.ZERO)
