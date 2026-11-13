class_name Career
extends RefCounted

static func create(name: String, style: String, appearance: int = 0) -> Dictionary:
	var d = GameCatalog.data()
	var stats: Dictionary = {}
	for k in d.stat_names: stats[k] = float(d.base_stat) + float(d.style_bonus[style].get(k, 0))
	return {"save_version":1, "current_athlete":{
		"athlete_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"name":name.strip_edges().left(16), "nationality":"대한민국", "appearance":appearance,
		"style":style, "age":18, "months":0, "stats":stats, "fatigue":0.0,
		"cash":int(d.starting_cash), "wins":0, "losses":0, "draws":0,
		"next_fight_month":int(d.first_fight_month), "fights":[], "month_history":[]},
		"account_legacy":{"lp":0}, "gym_facilities":{}, "hall_of_fame":[],
		"coaches":[], "achievements":[], "settings":{"strategy":"balanced", "fixed_seed":false, "seed":2026},
		"schedule":GameCatalog.default_schedule(), "saved_preset":GameCatalog.default_schedule()}

static func condition(athlete: Dictionary) -> int:
	return roundi(100.0 - float(athlete.fatigue) * 0.65)

static func energy(athlete: Dictionary) -> float:
	return 100.0 - float(athlete.fatigue)

static func fight_due(state: Dictionary) -> bool:
	return int(state.current_athlete.months) >= int(state.current_athlete.next_fight_month)

static func validate_schedule(schedule: Array) -> bool:
	if schedule.size() != 4: return false
	for week in schedule:
		if not week is Dictionary: return false
		for slot in ["main", "aux", "life"]:
			if not week.get(slot) is String: return false
			var allowed = GameCatalog.data().life_ids if slot == "life" else GameCatalog.data().main_ids
			if not week[slot] in allowed: return false
	return true

# Pure simulation on a deep copy: previews and insufficient-funds failures do not mutate saves.
static func month(state: Dictionary) -> Dictionary:
	if state.current_athlete.get("retired",false): return {"ok":false,"error":"은퇴한 선수입니다. 새 선수를 시작해 주세요."}
	if fight_due(state): return {"ok":false,"error":"오늘은 경기일입니다. 경기 탭에서 예정 경기를 먼저 진행해 주세요.","fight_due":true}
	if not validate_schedule(state.schedule): return {"ok":false, "error":"일정 데이터가 올바르지 않습니다."}
	var next = state.duplicate(true)
	var a: Dictionary = next.current_athlete
	var d = GameCatalog.data()
	var start_cash: int = a.cash
	var start_stats: Dictionary = a.stats.duplicate(true)
	var logs: Array = []
	var timeline: Array = []
	var total_recovery: float = 0
	var natural_recovery: float = 0
	var total_fatigue: float = 0
	var overdue: int = 0
	for week_index in 4:
		var notes: Array = []
		for slot in ["main", "aux", "life"]:
			var act = GameCatalog.action(next.schedule[week_index][slot])
			var scale: float = float(d.aux_scale) if slot == "aux" else 1.0
			var cost: int = ceili(float(act.cost) * scale)
			var before_fatigue: float = a.fatigue
			var before_cash: int = a.cash
			var before_stats: Dictionary = a.stats.duplicate(true)
			var action_id: String = next.schedule[week_index][slot]
			if a.cash < cost:
				notes.append("%s: 자금 부족 → 휴식 대체" % act.name)
				a.fatigue = clampf(a.fatigue - 12.0, 0, 100)
				total_recovery += before_fatigue - float(a.fatigue)
				timeline.append({"week":week_index+1,"slot":slot,"action_id":action_id,"scene_id":"rest","name":"자금 부족 · 휴식 대체","fatigue_before":before_fatigue,"fatigue_after":a.fatigue,"recovered":before_fatigue-a.fatigue,"potential_recovery":12.0,"cash_before":before_cash,"cash_after":a.cash,"gains":{},"skipped":true})
				continue
			a.cash += int(act.get("income", 0)) - cost
			var efficiency: float = 1.0 - (float(a.fatigue) / 100.0) * 0.65
			for stat in act.gains:
				a.stats[stat] = clampf(float(a.stats[stat]) + float(act.gains[stat]) * scale * efficiency * facility_bonus(state,stat), 1, 100)
			a.fatigue = clampf(float(a.fatigue) + float(act.fatigue) * scale, 0, 100)
			notes.append(str(act.name))
			a.fatigue = snappedf(a.fatigue, 0.01)
			var action_gains: Dictionary = {}
			for stat in a.stats:
				var change: float = float(a.stats[stat]) - float(before_stats[stat])
				if change > 0: action_gains[stat] = change
			var recovered_amount: float = maxf(0, before_fatigue - float(a.fatigue))
			total_recovery += recovered_amount
			total_fatigue += maxf(0, float(a.fatigue) - before_fatigue)
			timeline.append({"week":week_index+1,"slot":slot,"action_id":action_id,"scene_id":action_id,"name":act.name,"fatigue_before":before_fatigue,"fatigue_after":a.fatigue,"recovered":recovered_amount,"potential_recovery":maxf(0,-float(act.fatigue)*scale),"cash_before":before_cash,"cash_after":a.cash,"gains":action_gains,"skipped":false})
		var before_natural: float = a.fatigue
		a.fatigue = maxf(0, a.fatigue - float(d.weekly_recovery))
		var recovered_natural: float = before_natural - float(a.fatigue)
		natural_recovery += recovered_natural
		timeline.append({"week":week_index+1,"slot":"recovery","action_id":"natural_recovery","scene_id":"life_rest","name":"주간 자연 회복","fatigue_before":before_natural,"fatigue_after":a.fatigue,"recovered":recovered_natural,"potential_recovery":float(d.weekly_recovery),"cash_before":a.cash,"cash_after":a.cash,"gains":{},"skipped":false})
		logs.append("%d주: %s · 피로 %d" % [week_index + 1, " / ".join(notes), roundi(a.fatigue)])
	var fixed_cost: int = int(d.living_cost) + int(d.gym_cost)
	# An unpaid balance blocks the month; the planner can add work without losing progress.
	if a.cash < fixed_cost:
		overdue = fixed_cost - int(a.cash)
		return {"ok":false, "error":"월말 생활비·체육관비가 %d만원 부족합니다. 알바를 늘리거나 훈련비를 줄여 주세요. 이번 달은 아직 진행되지 않았습니다." % overdue,"timeline":timeline}
	a.cash -= fixed_cost
	a.months += 1
	a.age = 18 + int(a.months) / 12
	var gains: Array = []
	for stat in a.stats:
		var delta: float = float(a.stats[stat]) - float(start_stats[stat])
		if delta > 0: gains.append("%s +%.1f" % [d.stat_names[stat], delta])
	var report = {"month":a.months, "cash_delta":a.cash-start_cash, "cash":a.cash, "fatigue":a.fatigue,
		"logs":logs, "gains":gains, "fixed_cost":fixed_cost,"timeline":timeline,
		"fatigue_before":state.current_athlete.fatigue,"recovery_total":total_recovery,
		"natural_recovery":natural_recovery,"fatigue_added":total_fatigue,
		"stat_gains":{}}
	for key in a.stats: report.stat_gains[key] = float(a.stats[key]) - float(start_stats[key])
	a.month_history.append(report)
	if a.month_history.size() > 120: a.month_history.pop_front()
	return {"ok":true, "state":next, "report":report}

static func opponent(state: Dictionary) -> Dictionary:
	var a: Dictionary = state.current_athlete
	var idx: int = (int(a.wins) + int(a.losses) + int(a.draws)) % 3
	var def: Dictionary = GameCatalog.data().opponents[idx]
	var other = create(str(def.name), str(def.style)).current_athlete
	# Slow progression for repeatable domestic P0 play; no rank or league system yet.
	var extra: float = minf(float(a.months) * 0.65, 24)
	for k in other.stats: other.stats[k] += extra
	other.tag = def.tag
	other.athlete_id = "opponent_%d_%d" % [idx, a.months]
	return other

static func fight(state: Dictionary, strategy: String, match_seed: int) -> Dictionary:
	var a: Dictionary = state.current_athlete
	if a.get("retired",false): return {"ok":false,"error":"은퇴한 선수입니다."}
	if a.months < a.next_fight_month:
		return {"ok":false, "error":"다음 경기까지 %d개월 남았습니다." % (a.next_fight_month-a.months)}
	if not strategy in GameCatalog.data().strategy_names: return {"ok":false,"error":"전략 오류"}
	var next = state.duplicate(true)
	var b = opponent(state)
	var result = Bout.simulate(a, b, strategy, match_seed)
	var n: Dictionary = next.current_athlete
	match result.winner:
		"player": n.wins += 1
		"opponent": n.losses += 1
		_: n.draws += 1
	var reward: int = int(GameCatalog.data().show_money)
	if result.winner == "player": reward += int(GameCatalog.data().win_bonus)
	n.cash += reward
	n.fatigue = minf(100, n.fatigue + 24)
	n.next_fight_month = n.months + int(GameCatalog.data().fight_gap)
	result.reward = reward
	result.month = n.months
	result.opponent = b.name
	n.fights.append(result)
	if n.fights.size() > 120: n.fights.pop_front()
	return {"ok":true, "state":next, "result":result}

static func new_generation(previous: Dictionary, name: String, style: String, appearance: int = 0) -> Dictionary:
	var next = create(name,style,appearance)
	for key in ["account_legacy","gym_facilities","hall_of_fame","coaches","achievements"]:
		if previous.has(key): next[key] = previous[key].duplicate(true)
	return next

static func can_retire(state: Dictionary) -> bool:
	var a: Dictionary = state.current_athlete
	return a.months >= 18 and int(a.wins+a.losses+a.draws) >= 3 and not a.get("retired",false)

static func retire(state: Dictionary) -> Dictionary:
	if not can_retire(state): return {"ok":false,"error":"은퇴 정산에는 18개월과 공식 경기 3회가 필요합니다."}
	var next = state.duplicate(true)
	var a: Dictionary = next.current_athlete
	var reward: int = mini(60,10+int(a.wins)*2)
	next.hall_of_fame.append({"athlete_id":a.athlete_id,"name":a.name,"months":a.months,"age":a.age,"wins":a.wins,"losses":a.losses,"draws":a.draws,"stats":a.stats.duplicate(true),"lp":reward})
	next.account_legacy.lp += reward
	a.retired = true
	return {"ok":true,"state":next}

static func upgrade(state: Dictionary, id: String) -> Dictionary:
	if not id in GameCatalog.data().facilities: return {"ok":false,"error":"시설을 찾을 수 없습니다."}
	var level: int = int(state.gym_facilities.get(id,{}).get("level",0))
	var price: int = 5*(level+1)
	if level >= 3 or int(state.account_legacy.lp) < price: return {"ok":false,"error":"LP가 부족하거나 최대 레벨입니다."}
	var next = state.duplicate(true)
	next.account_legacy.lp -= price
	next.gym_facilities[id] = {"level":level+1}
	return {"ok":true,"state":next}

static func facility_bonus(state: Dictionary, stat: String) -> float:
	var result: float = 1.0
	for id in GameCatalog.data().facilities:
		if GameCatalog.data().facilities[id].stat == stat: result += .05*mini(3,int(state.gym_facilities.get(id,{}).get("level",0)))
	return minf(1.15,result)
