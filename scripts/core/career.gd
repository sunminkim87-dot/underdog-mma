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
	if not validate_schedule(state.schedule): return {"ok":false, "error":"일정 데이터가 올바르지 않습니다."}
	var next = state.duplicate(true)
	var a: Dictionary = next.current_athlete
	var d = GameCatalog.data()
	var start_cash: int = a.cash
	var start_stats: Dictionary = a.stats.duplicate(true)
	var logs: Array = []
	var overdue: int = 0
	for week_index in 4:
		var notes: Array = []
		for slot in ["main", "aux", "life"]:
			var act = GameCatalog.action(next.schedule[week_index][slot])
			var scale: float = float(d.aux_scale) if slot == "aux" else 1.0
			var cost: int = ceili(float(act.cost) * scale)
			if a.cash < cost:
				notes.append("%s: 자금 부족 → 휴식 대체" % act.name)
				a.fatigue = clampf(a.fatigue - 12.0, 0, 100)
				continue
			a.cash += int(act.get("income", 0)) - cost
			var efficiency: float = 1.0 - (float(a.fatigue) / 100.0) * 0.65
			for stat in act.gains:
				a.stats[stat] = clampf(float(a.stats[stat]) + float(act.gains[stat]) * scale * efficiency, 1, 100)
			a.fatigue = clampf(float(a.fatigue) + float(act.fatigue) * scale, 0, 100)
			notes.append(str(act.name))
			a.fatigue = snappedf(a.fatigue, 0.01)
		a.fatigue = maxf(0, a.fatigue - float(d.weekly_recovery))
		logs.append("%d주: %s · 피로 %d" % [week_index + 1, " / ".join(notes), roundi(a.fatigue)])
	var fixed_cost: int = int(d.living_cost) + int(d.gym_cost)
	# An unpaid balance blocks the month; the planner can add work without losing progress.
	if a.cash < fixed_cost:
		overdue = fixed_cost - int(a.cash)
		return {"ok":false, "error":"월말 생활비·체육관비가 %d만원 부족합니다. 알바를 늘리거나 훈련비를 줄여 주세요. 이번 달은 아직 진행되지 않았습니다." % overdue}
	a.cash -= fixed_cost
	a.months += 1
	a.age = 18 + int(a.months) / 12
	var gains: Array = []
	for stat in a.stats:
		var delta: float = float(a.stats[stat]) - float(start_stats[stat])
		if delta > 0: gains.append("%s +%.1f" % [d.stat_names[stat], delta])
	var report = {"month":a.months, "cash_delta":a.cash-start_cash, "cash":a.cash, "fatigue":a.fatigue,
		"logs":logs, "gains":gains, "fixed_cost":fixed_cost}
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
