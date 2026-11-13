extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(args[0])) != OK:
		quit(2)
		return
	var input: Dictionary = parser.data
	var state: Dictionary = input.get("state",{})
	var payload: Dictionary = input.get("payload",{})
	var result: Dictionary = {"ok":false,"error":"지원하지 않는 행동입니다."}
	if input.operation == "new":
		var valid_name: bool = payload.get("name") is String and not payload.name.strip_edges().is_empty() and payload.name.length() <= 16
		if valid_name and payload.get("style") in GameCatalog.data().style_names and SaveStore.whole(payload.get("appearance"),0,2):
			result = {"ok":true,"state":Career.new_generation(state,payload.name,payload.style,int(payload.appearance))}
		else: result.error = "선수 생성 정보가 올바르지 않습니다."
	elif not SaveStore.valid(state): result.error = "선수를 먼저 생성해 주세요."
	else:
		match input.operation:
			"month": result = Career.month(state)
			"fight":
				if payload.get("strategy") in GameCatalog.data().strategy_names: result = Career.fight(state,payload.strategy,int(input.match_seed))
			"schedule", "preset":
				if payload.get("schedule") is Array and Career.validate_schedule(payload.schedule):
					if input.operation == "schedule" and Career.fight_due(state): result.error = "오늘은 경기일입니다. 경기를 먼저 진행해 주세요."
					else:
						var next = state.duplicate(true)
						next["schedule" if input.operation == "schedule" else "saved_preset"] = payload.schedule
						result = {"ok":true,"state":next}
			"retire": result = Career.retire(state)
			"upgrade":
				if payload.get("facility") is String: result = Career.upgrade(state,payload.facility)
	if result.get("ok",false) and not SaveStore.valid(result.state): result = {"ok":false,"error":"계산 결과 검증에 실패했습니다."}
	var output = FileAccess.open(args[1],FileAccess.WRITE)
	output.store_string(JSON.stringify(result))
	output.close()
	quit()
