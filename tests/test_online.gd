extends SceneTree
var failures: Array = []
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var client = OnlineGateway.new()
	root.add_child(client)
	await process_frame
	var connected = await client.connect_server("http://127.0.0.1:8765")
	check(connected.get("ok",false) and client.connected,"Godot connects to real HTTP server")
	var created = await client.mutate("new",{"name":"온라인 테스트","style":"wrestler","appearance":1})
	check(created.get("ok",false) and SaveStore.valid(created.get("state",{})),"server creates a validated career")
	var expected = Career.month(created.state)
	var month = await client.mutate("month",{})
	check(month.get("ok",false),"Godot requests server-authoritative month")
	var stats_match: bool = true
	for key in expected.state.current_athlete.stats:
		stats_match = stats_match and absf(month.state.current_athlete.stats[key]-expected.state.current_athlete.stats[key]) < 0.000001
	check(stats_match,"server and UI preview use identical training rules within JSON floating-point precision")
	var timeline_match: bool = month.report.timeline.size() == expected.report.timeline.size()
	for index in expected.report.timeline.size():
		var left: Dictionary = expected.report.timeline[index]
		var right: Dictionary = month.report.timeline[index]
		for key in ["fatigue_before","fatigue_after","recovered","cash_before","cash_after"]: timeline_match = timeline_match and absf(float(left[key])-float(right[key])) < 0.000001
	check(timeline_match,"server timeline matches actual recovery preview across JSON serialization")
	var second = await client.mutate("month",{})
	check(second.get("ok",false),"second server month")
	var blocked = await client.mutate("month",{})
	check(not blocked.get("ok",false),"online month blocked on fight date")
	var snapshot = await client.fetch_state()
	check(snapshot.state.current_athlete.months == 2,"failed month never advances server calendar")
	var fight = await client.mutate("fight",{"strategy":"wrestling"})
	check(fight.get("ok",false) and fight.state.current_athlete.fights.size()==1,"real server records a seeded MMA match")
	var resume = await client.mutate("month",{})
	check(resume.get("ok",false) and resume.state.current_athlete.months==3,"online calendar resumes after match")
	var forged = await client.mutate("month",{"cash":99999})
	check(not forged.get("ok",false),"forged money request denied across real HTTP")
	var reloaded = await client.fetch_state()
	check(reloaded.state.current_athlete.months==3 and client.wallet.cash==0,"server state retained; no premium cash was fabricated")
	var final = FileAccess.open("res://tests/online_results.json",FileAccess.WRITE)
	final.store_string(JSON.stringify({"checks":checks,"failures":failures,"real_http":true,"billing_connected":false},"\t"))
	final.close()
	print("Online checks: ",checks," failures: ",failures)
	quit(0 if failures.is_empty() else 1)
