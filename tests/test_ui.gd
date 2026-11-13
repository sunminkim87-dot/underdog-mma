extends SceneTree

var app: Control
var checks: int = 0
var failures: Array = []
var screenshots: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for _i in 5: await process_frame

func find_action(node: Node, action: String) -> Button:
	if node is Button and node.get_meta("action", "") == action and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		var found = find_action(child,action)
		if found != null: return found
	return null

func press(action: String) -> void:
	var control = find_action(app,action)
	check(control != null, "action exists: " + action)
	if control != null: control.pressed.emit()
	await settle()

func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	check(img.get_width() > 0 and img.save_png("res://tests/"+file+".png") == OK,"screenshot "+file)
	screenshots.append(file)

func check_width(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and not node is Popup and not node.is_queued_for_deletion():
		var rect = node.get_global_rect()
		check(rect.position.x >= -1 and rect.end.x <= root.get_visible_rect().size.x + 1,"fits portrait width: "+node.get_class())
	for child in node.get_children(): check_width(child)

func close_modal() -> void:
	if is_instance_valid(app.modal): await press("modal_confirm")

func run() -> void:
	for ext in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_test_career.json"+ext))
	root.size = Vector2i(540,960)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(app.screen == "create","first launch creation")
	check_width(app)
	await capture("01_creation")
	app.name_input.text = "   "
	await press("create")
	check(app.state.is_empty(),"empty name blocked")
	await close_modal()
	app.name_input.text = "테스트 선수"
	app.style_input.select(1)
	app.appearance_input.select(1)
	await press("create")
	check(app.screen == "home" and app.state.current_athlete.style == "wrestler","create wrestler through UI")
	check(app.state.current_athlete.appearance == 1,"appearance stored")
	check_width(app)
	for node in app.content.find_children("*","Label",true,false):
		if node.text in ["보유 현금","피로","컨디션"]: check(node.size.y < 60,"metric label stays readable")
	await capture("02_home")
	await press("nav_schedule")
	check_width(app)
	await capture("03_schedule")
	var dropdown: OptionButton
	for node in app.content.find_children("*","OptionButton",true,false):
		if node.get_meta("week",-1) == 0 and node.get_meta("slot","") == "main": dropdown = node
	check(dropdown != null,"week 1 main editor")
	if dropdown:
		dropdown.select(3)
		dropdown.item_selected.emit(3)
	await settle()
	check(app.state.schedule[0].main == "bjj","dropdown persists selection")
	await press("preset_save")
	check(app.state.saved_preset[0].main == "bjj","custom preset saves")
	await press("guide")
	check(is_instance_valid(app.modal),"action guide opens")
	await close_modal()
	await press("advance")
	await press("modal_cancel")
	check(app.state.current_athlete.months == 0,"month confirmation cancellation")
	for _i in 2:
		app.show_screen("schedule")
		await settle()
		await press("advance")
		await press("modal_confirm")
		check(is_instance_valid(app.modal),"monthly report shown")
		await close_modal()
	check(app.state.current_athlete.months == 2,"two months through UI")
	await press("nav_fight")
	check_width(app)
	check(not find_action(app,"start_fight").disabled,"first fight unlocks")
	await capture("04_fight")
	await press("start_fight")
	await press("modal_confirm")
	check(app.state.current_athlete.fights.size() == 1,"one recorded fight through UI")
	await capture("05_result")
	await close_modal()
	check(app.screen == "records","fight leads to records")
	check_width(app)
	await capture("06_records")
	var saved_cash = app.state.current_athlete.cash
	await press("nav_home")
	await press("save")
	app.state.current_athlete.cash = 0
	await press("load")
	check(app.state.current_athlete.cash == saved_cash,"manual load restores saved money")
	await press("nav_fight")
	check(find_action(app,"start_fight").disabled,"repeated fight locked")
	app.show_screen("records")
	await settle()
	await press("new_game")
	await press("create")
	await press("modal_cancel")
	check(app.state.current_athlete.fights.size() == 1,"new-game cancel preserves career")
	app.show_screen("home")
	await settle()
	root.size = Vector2i(360,800)
	await settle()
	check_width(app)
	await capture("07_tall_phone")
	# Recreate root to verify automatic loading after a genuine scene restart.
	app.queue_free()
	await settle()
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(app.screen == "home" and app.state.current_athlete.fights.size() == 1,"restart automatically loads career")
	var file = FileAccess.open("res://tests/ui_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":screenshots,"rendered":true},"\t"))
	file.close()
	print("UI checks: ",checks," failures: ",failures)
	for ext in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_test_career.json"+ext))
	quit(0 if failures.is_empty() else 1)
