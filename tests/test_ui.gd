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
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for _i in 5: await process_frame
func find_action(node: Node, action: String) -> Button:
	if node is Button and node.get_meta("action","") == action and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		var found = find_action(child,action)
		if found != null: return found
	return null
func press(action: String) -> void:
	var b = find_action(app,action)
	check(b != null,"action exists: "+action)
	if b != null: b.pressed.emit()
	await settle()
func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	check(img.get_width()>0 and img.save_png("res://tests/"+file+".png")==OK,"screenshot "+file)
	screenshots.append(file)
func check_width(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and not node is Popup and not node.is_queued_for_deletion():
		var rect = node.get_global_rect()
		check(rect.position.x>=-1 and rect.end.x<=root.get_visible_rect().size.x+1,"fits width: "+node.get_class())
	for child in node.get_children(): check_width(child)
func close_modal() -> void:
	if is_instance_valid(app.modal):await press("modal_confirm")

func resolve_pending() -> void:
	if app.state.is_empty() or app.state.current_athlete.get("pending_event","").is_empty():return
	app.show_event()
	await settle()
	var definition: Dictionary=GameCatalog.extra().events[app.state.current_athlete.pending_event]
	var selected: String=""
	for option in definition.choices:
		if int(option.effects.get("cost",0))==0:
			selected=option.id
			break
	await press("event_"+selected)
func run() -> void:
	create_timer(45).timeout.connect(func():print("FAIL: UI test timeout");quit(2))
	for ext in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_test_career.json"+ext))
	root.size = Vector2i(540,960)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(app.screen=="lobby","first launch opens lobby")
	check(find_action(app,"continue").disabled,"continue disabled without athlete")
	check_width(app)
	await capture("00_lobby")
	await press("cash_shop")
	check(find_action(app,"purchase").disabled,"real purchases disabled without Google Play")
	await capture("12_shop")
	app.show_screen("lobby")
	await settle()
	await press("hall")
	check(app.screen=="hall","hall opens without a career")
	app.show_screen("lobby")
	await settle()
	await press("gym")
	check(find_action(app,"upgrade_boxing").disabled,"facility upgrade needs earned LP")
	app.show_screen("lobby")
	await settle()
	await press("new_game")
	check_width(app)
	await capture("01_creation")
	app.name_input.text="   "
	await press("create")
	check(app.state.is_empty(),"blank name blocked")
	await close_modal()
	for index in 5:
		app.style_input.select(index)
		app.style_input.item_selected.emit(index)
		await settle()
		var base: String=app.style_input.get_item_metadata(index)
		check(app.hero_scene.action_id==base,"creation scene matches selected base: "+base)
	app.style_input.select(0)
	app.style_input.item_selected.emit(0)
	app.name_input.text="김도현"
	app.style_input.select(0)
	app.appearance_input.select(0)
	await press("create")
	check(app.screen=="home","athlete creation")
	check(app.state.current_athlete.stats.striking==38,"approved boxing base stats used")
	check_width(app)
	await capture("02_home")
	await press("nav_schedule")
	check_width(app)
	await capture("03_schedule")
	await press("slot_0_main")
	await press("choose_bjj")
	check(app.picker_id=="bjj","action card chooses bjj")
	await press("action_apply")
	check(app.state.schedule[0].main=="bjj","schedule saved")
	await press("slot_0_life")
	await press("choose_life_rest")
	check(app.picker_info.text.contains("실제"),"picker explicitly displays actual recovery")
	await capture("08_recovery_picker")
	await press("modal_cancel")
	await press("preset_save")
	check(app.state.saved_preset[0].main=="bjj","custom preset stored")
	await press("advance")
	await press("modal_cancel")
	check(app.state.current_athlete.months==0,"cancel doesn't advance")
	await press("advance")
	await press("modal_confirm")
	check(is_instance_valid(app.playback) and app.state.current_athlete.months==1,"month saved before animation")
	await create_timer(.25).timeout
	await capture("09_training")
	check_width(app.playback)
	var before = hash(root.get_texture().get_image().get_data())
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	check(before!=hash(root.get_texture().get_image().get_data()),"training scene and gauges actually animate")
	app.playback.index=1
	app.playback.advance()
	await settle()
	check(app.playback.world.action_id=="job","work uses convenience store scene")
	await capture("10_work")
	app.playback.index=2
	app.playback.advance()
	await settle()
	check(app.playback.world.action_id=="life_rest","natural recovery uses sleep scene")
	await capture("11_recovery")
	await press("playback_speed")
	check(app.playback.speed==2,"2x playback speed")
	var cash_saved=app.state.current_athlete.cash
	await press("playback_skip")
	check(app.state.current_athlete.cash==cash_saved,"skip never grants duplicate income")
	await close_modal()
	await resolve_pending()
	app.show_screen("schedule")
	await settle()
	await press("advance")
	await press("modal_confirm")
	await press("playback_skip")
	await close_modal()
	await resolve_pending()
	check(app.state.current_athlete.months==2,"two months advance")
	await capture("13_fight_due")
	app.show_screen("schedule")
	await settle()
	check(find_action(app,"advance").disabled,"schedule advance button locked at fight date")
	var due_cash=app.state.current_athlete.cash
	app.month_clicked()
	await settle()
	check(app.state.current_athlete.months==2 and app.state.current_athlete.cash==due_cash,"direct month invocation cannot bypass date lock")
	await close_modal()
	await press("nav_fight")
	check_width(app)
	await capture("04_fight")
	await press("start_fight")
	await press("modal_confirm")
	check(app.state.current_athlete.fights.size()==1,"one match recorded")
	await capture("05_result")
	await close_modal()
	await resolve_pending()
	app.show_screen("records")
	await settle()
	await capture("06_records")
	await press("nav_home")
	await press("save")
	var saved_cash=app.state.current_athlete.cash
	app.state.current_athlete.cash=0
	await press("load")
	check(app.state.current_athlete.cash==saved_cash,"manual load")
	await press("nav_schedule")
	check(not find_action(app,"advance").disabled,"calendar resumes after fight")
	app.show_screen("shop")
	await settle()
	var before_cash: int=app.state.current_athlete.cash
	var before_quantity: int=int(app.state.current_athlete.inventory.get("sports_drink",0))
	await press("buy_sports_drink")
	check(app.state.current_athlete.cash==before_cash-4 and app.state.current_athlete.inventory.sports_drink==before_quantity+1,"shop purchase changes cash and inventory")
	var before_fatigue: float=app.state.current_athlete.fatigue
	await press("use_sports_drink")
	check(app.state.current_athlete.fatigue==maxf(0,before_fatigue-12),"item use visibly restores actual health")
	await capture("14_item_recovery")
	await close_modal()
	await press("buy_training_gloves")
	check(app.state.current_athlete.equipment.gloves=="training_gloves","equipment auto-equipped")
	await capture("15_shop")
	await press("equip_training_gloves")
	check(app.state.current_athlete.equipment.gloves.is_empty(),"equipment can be removed")
	app.show_screen("social")
	await settle()
	check(app.state.current_athlete.relationships.jisoo.met,"NPC meeting persisted through other screens")
	var affinity: int=app.state.current_athlete.relationships.jisoo.affinity
	await press("focus_jisoo")
	check(app.state.current_athlete.relationships.jisoo.affinity==affinity,"selecting a friend never farms free affinity")
	await capture("16_relationships")
	app.state.current_athlete.last_skill_event_month=-10
	app.state.current_athlete.last_event_month=-1
	app.state.current_athlete.event_cooldowns.erase("learn_bjj")
	Progression.evaluate(app.state)
	check(app.state.current_athlete.pending_event=="learn_bjj","qualified cross-base technique event")
	app.show_event()
	await settle()
	await capture("17_technique_event")
	await press("event_learn")
	check(app.state.current_athlete.skills.has("tech_bjj"),"event teaches actual special technique")
	app.show_screen("skills")
	await settle()
	await capture("18_skills")
	app.show_screen("achievements")
	await settle()
	check(app.state.achievements.has("first_technique"),"technique achievement granted")
	await capture("19_achievements")
	app.show_screen("home")
	await settle()
	root.size=Vector2i(360,800)
	await settle()
	check_width(app)
	await capture("07_tall_phone")
	app.queue_free()
	await settle()
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(app.screen=="lobby" and not find_action(app,"continue").disabled,"restart opens lobby with continue")
	await press("continue")
	check(app.state.current_athlete.fights.size()==1,"continued save retains match")
	var file=FileAccess.open("res://tests/ui_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screenshots":screenshots,"rendered":true},"\t"))
	file.close()
	print("UI checks: ",checks," failures: ",failures)
	for ext in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_test_career.json"+ext))
	quit(0 if failures.is_empty() else 1)
