extends SceneTree

var checks: int = 0
var failures: Array = []
var summary: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var original = Career.create("김도현", "striker")
	check(SaveStore.valid(original), "new save schema")
	check(original.current_athlete.age == 18 and original.current_athlete.stats.striking == 36, "age and striker bonus")
	for style in ["striker", "wrestler", "grappler"]:
		check(SaveStore.valid(Career.create("선수", style)), "style " + style)
	var serialized = JSON.stringify(original)
	var result = Career.month(original)
	check(result.ok, "default month succeeds")
	check(JSON.stringify(original) == serialized, "month and preview never mutate input")
	check(result.state.current_athlete.months == 1 and result.report.logs.size() == 4, "exactly four weekly slots")
	check(result.state.current_athlete.cash == 84, "income 36 minus training 16 minus fixed 36")
	check(result.state.current_athlete.stats.striking > 36 and result.state.current_athlete.stats.endurance > 24, "training improves chosen stats")
	check(is_equal_approx(result.report.fatigue,10.8), "slot fatigue + weekly recovery")
	var state = original.duplicate(true)
	for _i in 12:
		state.schedule = GameCatalog.default_schedule()
		for w in state.schedule: w.life = "job"
		var month = Career.month(state)
		check(month.ok, "sustainable working month")
		state = month.state
	check(state.current_athlete.age == 19 and state.current_athlete.months == 12, "age increments exactly after twelve months")
	var broke = original.duplicate(true)
	broke.current_athlete.cash = 0
	broke.schedule = GameCatalog.default_schedule("recovery")
	var broke_copy = JSON.stringify(broke)
	check(not Career.month(broke).ok and JSON.stringify(broke) == broke_copy, "insufficient fixed cost blocks without mutation")
	broke.schedule[0].life = "delivery"
	broke.schedule[1].life = "delivery"
	check(Career.month(broke).ok, "zero cash can recover through work")
	var recovery = state.duplicate(true)
	recovery.schedule = GameCatalog.default_schedule("recovery")
	var recovered = Career.month(recovery)
	check(recovered.ok and recovered.report.fatigue < state.current_athlete.fatigue, "rest reduces fatigue")
	check(Career.condition(recovered.state.current_athlete) > Career.condition(state.current_athlete), "recovery improves condition")
	var fresh = original.duplicate(true)
	var tired = original.duplicate(true)
	tired.current_athlete.fatigue = 100
	var f = Career.month(fresh)
	var t = Career.month(tired)
	check(f.state.current_athlete.stats.striking > t.state.current_athlete.stats.striking, "fatigue reduces growth")
	var capped = original.duplicate(true)
	for k in capped.current_athlete.stats: capped.current_athlete.stats[k] = 99.9
	capped.current_athlete.fatigue = 99.9
	var capped_month = Career.month(capped)
	check(SaveStore.valid(capped_month.state), "stats and fatigue remain within bounds")
	var invalid = original.duplicate(true)
	invalid.schedule.pop_back()
	check(not Career.month(invalid).ok and not SaveStore.valid(invalid), "invalid schedule rejected")
	check(not Career.fight(original,"balanced",42).ok, "first fight locked for two months")
	var ready = Career.month(Career.month(original).state).state
	var before_fight = JSON.stringify(ready)
	var fight = Career.fight(ready,"balanced",2026)
	check(fight.ok and SaveStore.valid(fight.state), "match produces valid persisted state")
	check(before_fight == JSON.stringify(ready), "match does not mutate input")
	check(fight.state.current_athlete.wins + fight.state.current_athlete.losses + fight.state.current_athlete.draws == 1, "record increments once")
	check(fight.state.current_athlete.cash == ready.current_athlete.cash + fight.result.reward, "match payment")
	check(not Career.fight(fight.state,"balanced",2026).ok, "cannot repeat fight without waiting")
	check(JSON.stringify(fight.result) == JSON.stringify(Career.fight(ready,"balanced",2026).result), "seed reproduces entire bout")
	check(fight.result.rounds.size() <= 3 and fight.result.rounds.size() >= 1, "one to three rounds")
	var path = "user://automated_test_save.json"
	for ext in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))
	check(SaveStore.save_game(original,path) == OK, "write initial save")
	check(SaveStore.save_game(fight.state,path) == OK, "atomic replacement and backup")
	var loaded = SaveStore.load_game(path)
	check(loaded.ok and loaded.state.current_athlete.months == 2, "roundtrip load")
	check(loaded.state.current_athlete.fights[0].logs == fight.result.logs, "fight logs preserved")
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string('{"corrupt":')
	file.close()
	loaded = SaveStore.load_game(path)
	check(loaded.ok and loaded.recovered and loaded.state.current_athlete.months == 0, "corrupted primary recovers previous good save")
	check(SaveStore.save_game(fight.state,path) == OK, "saving after recovery preserves good backup")
	check(not SaveStore.read_one(path+".bak").is_empty(), "valid backup retained after recovery")
	for change in ["future","stats","settings","history","schedule"]:
		var bad = original.duplicate(true)
		match change:
			"future": bad.save_version = 99
			"stats": bad.current_athlete.stats.power = "bad"
			"settings": bad.settings.seed = -1
			"history": bad.current_athlete.month_history = [{}]
			"schedule": bad.schedule[0].main = "unknown"
		check(not SaveStore.valid(bad), "reject malformed " + change)
	check(SaveStore.save_game(original,"/proc/underdog_no_write.json") != OK, "unwritable location returns error")
	for ext in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))
	var long_run = Career.create("장기 테스트","grappler")
	for i in 150:
		for week in long_run.schedule: week.life = "job"
		var next_month = Career.month(long_run)
		check(next_month.ok,"long-run economy remains playable")
		long_run = next_month.state
		if long_run.current_athlete.months >= long_run.current_athlete.next_fight_month:
			long_run = Career.fight(long_run,"submission",i).state
	check(SaveStore.valid(long_run) and long_run.current_athlete.month_history.size() == 120,"150-month bounded history and valid state")
	check(not long_run.current_athlete.fights[-1].player_snapshot.has("fights"),"fight snapshots do not recursively embed history")
	check(JSON.stringify(long_run).length() < 2000000,"long-run save size stays bounded")
	# Thousands of seeded fights: both sides, all starting styles, completion and schema invariants.
	var methods: Dictionary = {}
	var rates: Dictionary = {}
	var duration: int = 0
	for ps in ["striker","wrestler","grappler"]:
		for os_style in ["striker","wrestler","grappler"]:
			var p = Career.create("P",ps).current_athlete
			var o = Career.create("O",os_style).current_athlete
			var wins: int = 0
			for n in 500:
				var bout = Bout.simulate(p,o,"balanced",10000+n)
				if bout.winner == "player": wins += 1
				methods[bout.method] = methods.get(bout.method,0)+1
				duration += (bout.round-1)*300+bout.second
				check(bout.winner in ["player","opponent","draw"] and bout.round >= 1 and bout.round <= 3 and bout.logs.size()>0, "bout invariant")
			rates[ps+"_vs_"+os_style] = float(wins) / 500
	var healthy_wins: int = 0
	var tired_wins: int = 0
	var p = Career.create("P","striker").current_athlete
	var opponent = Career.create("O","striker").current_athlete
	var exhausted = p.duplicate(true)
	exhausted.fatigue = 100
	for n in 700:
		if Bout.simulate(p,opponent,"balanced",n).winner == "player": healthy_wins += 1
		if Bout.simulate(exhausted,opponent,"balanced",n).winner == "player": tired_wins += 1
	check(healthy_wins > tired_wins, "fatigue materially lowers seeded win rate")
	var strategy_rates: Dictionary = {}
	for strategy in GameCatalog.data().strategy_names:
		var wins: int = 0
		for n in 100:
			if Bout.simulate(p,opponent,strategy,50000+n).winner == "player": wins += 1
		strategy_rates[strategy] = wins
	check(methods.has("KO/TKO") and methods.has("서브미션") and methods.has("판정"), "all three result types observed")
	summary = {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"simulated_bouts":6400,"style_player_win_rates":rates,"methods_in_style_sweep":methods,"mean_duration_seconds":float(duration)/4500,"healthy_wins_out_of_700":healthy_wins,"fatigued_wins_out_of_700":tired_wins,"strategy_wins_out_of_100":strategy_rates}
	var report = FileAccess.open("res://tests/core_results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(summary,"\t"))
	report.close()
	print(JSON.stringify(summary,"\t"))
	quit(0 if failures.is_empty() else 1)
