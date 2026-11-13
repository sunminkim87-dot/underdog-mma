extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:
		quit(2)
		return
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(args[0]))!=OK:
		quit(2)
		return
	var input: Dictionary=parser.data
	var state: Dictionary=input.get("state",{})
	var payload: Dictionary=input.get("payload",{})
	var result: Dictionary={"ok":false,"error":"지원하지 않거나 올바르지 않은 행동입니다."}
	if not state.is_empty() and SaveStore.valid(state):Progression.initialize(state)
	if input.operation=="new":
		var valid_name: bool=payload.get("name") is String and not payload.name.strip_edges().is_empty() and payload.name.length()<=16
		if valid_name and SaveStore.whole(payload.get("appearance"),0,2):
			if payload.get("base") is String and payload.base in GameCatalog.data().bases:result={"ok":true,"state":Career.new_generation(state,payload.name,GameCatalog.data().bases[payload.base].style,int(payload.appearance),payload.base)}
			elif not payload.has("base") and payload.get("style") is String and payload.style in GameCatalog.data().style_names:result={"ok":true,"state":Career.new_generation(state,payload.name,payload.style,int(payload.appearance))}
	elif not SaveStore.valid(state):result.error="선수를 먼저 생성해 주세요."
	else:
		match input.operation:
			"month":result=Career.month(state)
			"fight":
				if payload.get("strategy") is String and payload.strategy in GameCatalog.data().strategy_names:result=Career.fight(state,payload.strategy,int(input.match_seed))
			"schedule","preset":
				if payload.get("schedule") is Array and Career.validate_schedule(payload.schedule):
					var reason=Progression.schedule_reason(state,payload.schedule)
					if input.operation=="schedule" and Career.fight_due(state):result.error="오늘은 경기일입니다. 경기를 먼저 진행해 주세요."
					elif not reason.is_empty():result.error=reason
					else:
						var next=state.duplicate(true)
						next["schedule" if input.operation=="schedule" else "saved_preset"]=payload.schedule
						result={"ok":true,"state":next}
			"retire":result=Career.retire(state)
			"upgrade":
				if payload.get("facility") is String:result=Career.upgrade(state,payload.facility)
			"buy":
				if payload.get("item") is String:result=Progression.buy(state,payload.item)
			"equip":
				if payload.get("item") is String:result=Progression.equip(state,payload.item)
			"use_item":
				if payload.get("item") is String:result=Progression.use_item(state,payload.item)
			"event":
				if payload.get("event") is String and payload.get("choice") is String:result=Progression.choose(state,payload.event,payload.choice)
			"focus":
				if payload.get("npc") is String:result=Progression.focus(state,payload.npc)
			"end_relationship":result=Progression.end_relationship(state)
	if result.get("ok",false):
		if not input.operation in ["schedule","preset","upgrade"]:Progression.evaluate(result.state)
		if not SaveStore.valid(result.state):result={"ok":false,"error":"계산 결과 검증에 실패했습니다."}
	var output=FileAccess.open(args[1],FileAccess.WRITE)
	output.store_string(JSON.stringify(result))
	output.close()
	quit()
