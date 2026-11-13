extends SceneTree
var checks: int=0
var failures: Array=[]
var app: Control
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		print("FAIL: ",message)
func settle() -> void:
	for _i in 5:await process_frame
func find_action(node: Node,id: String) -> Button:
	if node is Button and node.get_meta("action","")==id and not node.is_queued_for_deletion():return node
	for child in node.get_children():
		var found=find_action(child,id)
		if found!=null:return found
	return null
func find_address(node: Node) -> LineEdit:
	if node is LineEdit:return node
	for child in node.get_children():
		var found=find_address(child)
		if found!=null:return found
	return null
func start_app() -> void:
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
func stop_app() -> void:
	app.queue_free()
	await settle()
func wait_connection() -> void:
	for _i in 300:
		await create_timer(0.02).timeout
		if not app.cloud.connecting:return
func run() -> void:
	create_timer(30).timeout.connect(func():print("FAIL: connection test timeout");quit(2))
	root.size=Vector2i(540,960)
	var original=Career.create_from_base("기존 로컬","boxing",0)
	check(SaveStore.save_game(original,"user://ui_test_career.json")==OK,"prepare isolated legacy local save")
	await start_app()
	app.show_connection()
	await settle()
	find_address(app.modal).text="http://127.0.0.1:8771"
	find_action(app,"server_connect").pressed.emit()
	await settle()
	check(app.cloud.connecting,"connection is in flight before closing dialog")
	find_action(app,"modal_confirm").pressed.emit()
	await wait_connection()
	check(not app.cloud.connected and not app.cloud.connecting,"closed delayed request restores prior connection")
	check(not is_instance_valid(app.modal),"closed dialog stays closed after delayed response")
	check(app.state.current_athlete.name=="기존 로컬","cancelled connection preserves local athlete")
	await stop_app()
	var helper=OnlineGateway.new()
	root.add_child(helper)
	await settle()
	var connected=await helper.connect_server("http://127.0.0.1:8765")
	check(connected.get("ok",false),"prepare real server account")
	var created=await helper.mutate("new",{"name":"서버 이어하기","base":"judo","style":"wrestler","appearance":0})
	check(created.get("ok",false),"prepare server athlete")
	var server_id: String=created.state.current_athlete.athlete_id
	helper.queue_free()
	await settle()
	await start_app()
	await wait_connection()
	check(app.cloud.connected and app.state.current_athlete.athlete_id==server_id,"restart automatically resumes exact online athlete")
	check(app.save_path=="user://online_cache_v1.json","online state writes only separate cache")
	check(SaveStore.load_game("user://ui_test_career.json").state.current_athlete.name=="기존 로컬","online resume keeps original local save")
	await stop_app()
	await start_app()
	await wait_connection()
	check(app.cloud.connected and app.state.current_athlete.athlete_id==server_id,"second restart retains server account and athlete")
	await stop_app()
	var config=ConfigFile.new()
	config.load("user://server_connection.cfg")
	config.set_value("server","url","http://127.0.0.1:8771")
	config.set_value("server","last_online",true)
	config.save("user://server_connection.cfg")
	await start_app()
	await wait_connection()
	check(app.state.is_empty() and not app.cloud.connected,"failed online resume never silently loads local save")
	check(find_action(app,"continue").disabled and find_action(app,"new_game").disabled,"failed online mode blocks accidental local career")
	find_action(app,"local_test").pressed.emit()
	await settle()
	check(not app.cloud.was_online and app.state.current_athlete.name=="기존 로컬","explicit development mode restores preserved local career")
	check(SaveStore.load_game("user://online_cache_v1.json").state.current_athlete.athlete_id==server_id,"switching mode retains online cache")
	await stop_app()
	var result=FileAccess.open("res://tests/connection_results.json",FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"real_http":true},"\t"))
	result.close()
	print("Connection UI checks: ",checks," failures: ",failures)
	quit(0 if failures.is_empty() else 1)
