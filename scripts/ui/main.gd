extends Control

const BG = Color("101b2b")
const PANEL = Color("1b2b40")
const PANEL2 = Color("263a51")
const TEXT = Color("f1f3ed")
const MUTED = Color("9aabba")
const LIME = Color("ffd18a")
const GREEN = Color("8bdfbd")
const ORANGE = Color("ff9d89")
const BLUE = Color("7cbcff")

var state: Dictionary = {}
var screen: String = "lobby"
var shell: VBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var status_label: Label
var modal: Control
var forecast: Label
var name_input: LineEdit
var style_input: OptionButton
var appearance_input: OptionButton
var save_path: String = SaveStore.DEFAULT_PATH
var status_message: String = "개발 테스트 · 온라인 서버 미연결"
var cloud = OnlineGateway.new()
var playback: MonthPlayback
var picker_world: ActivityScene
var picker_week: int = 0
var picker_slot: String = "main"
var picker_id: String = "boxing"
var picker_info: Label
var picker_meter: ProgressBar
var hero_scene: ActivityScene

func _ready() -> void:
	var theme_resource = Theme.new()
	theme_resource.default_font = load("res://assets/fonts/NotoSansKR.otf")
	theme_resource.default_font_size = 17
	theme = theme_resource
	RenderingServer.set_default_clear_color(BG)
	# Tests can isolate their save path; normal builds always use user://.
	if OS.get_cmdline_user_args().has("--ui-test"): save_path = "user://ui_test_career.json"
	var loaded = SaveStore.load_game(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.recovered: status_message = "백업에서 복구됨 · 저장 버튼으로 확정"
	add_child(cloud)
	show_screen("lobby")

func box_style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(1)
	return style

func label(text_value: String, size_value: int = 18, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func stack(parent: Node, gap: int = 12) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

func row(parent: Node, gap: int = 10) -> HBoxContainer:
	var node = HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	parent.add_child(node)
	return node

func card(parent: Node, tint: Color = PANEL) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", box_style(tint))
	parent.add_child(panel)
	return stack(panel, 10)

func button(parent: Node, text_value: String, callback: Callable, primary: bool = false, id: String = "") -> Button:
	var node = Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 50
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 18)
	node.add_theme_color_override("font_color", BG if primary else TEXT)
	node.add_theme_color_override("font_hover_color", BG if primary else LIME)
	node.add_theme_color_override("font_pressed_color", BG if primary else LIME)
	node.add_theme_stylebox_override("normal", box_style(LIME if primary else PANEL2, Color.TRANSPARENT, 10))
	node.add_theme_stylebox_override("hover", box_style(LIME.lightened(.1) if primary else Color("293b4c"), LIME, 10))
	node.add_theme_stylebox_override("pressed", box_style(Color("b6ce50") if primary else Color("304054"), LIME, 10))
	node.add_theme_stylebox_override("disabled", box_style(Color("273035"), Color.TRANSPARENT, 10))
	node.add_theme_color_override("font_disabled_color", MUTED)
	if not id.is_empty(): node.set_meta("action", id)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func select(parent: Node, ids: Array, names: Dictionary, selected: String, callback: Callable) -> OptionButton:
	var node = OptionButton.new()
	node.custom_minimum_size = Vector2(0, 48)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.clip_text = true
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_stylebox_override("normal", box_style(PANEL2, Color("344252"), 8))
	node.add_theme_stylebox_override("hover", box_style(Color("293b4c"), LIME, 8))
	var popup = node.get_popup()
	popup.add_theme_font_override("font", theme.default_font)
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_constant_override("v_separation", 14)
	for id in ids:
		node.add_item(str(names[id]))
		node.set_item_metadata(node.item_count - 1, id)
		if id == selected: node.select(node.item_count - 1)
	node.item_selected.connect(func(index): callback.call(ids[index]))
	parent.add_child(node)
	return node

func section_title(kicker: String, title: String, detail: String = "") -> void:
	content.add_child(label(kicker, 13, LIME))
	content.add_child(label(title, 26))
	if not detail.is_empty(): content.add_child(label(detail, 16, MUTED))

func show_screen(target: String) -> void:
	screen = target
	for child in get_children():
		if child == cloud: continue
		remove_child(child)
		child.queue_free()
	modal = null
	shell = VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	add_child(shell)
	var top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", box_style(BG, Color.TRANSPARENT, 0))
	shell.add_child(top)
	var header = row(top)
	header.add_child(label("U / 언더독", 21, LIME))
	var p0 = label("v0.2  ·  " + ("서버 연결" if cloud.connected else "개발 테스트"), 12, GREEN if cloud.connected else MUTED)
	p0.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(p0)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "bottom"]: margin.add_theme_constant_override("margin_"+side, 20)
	margin.add_theme_constant_override("margin_top", 8)
	scroll.add_child(margin)
	content = stack(margin, 14)
	match target:
		"lobby": build_lobby()
		"hall": build_hall()
		"gym": build_gym()
		"shop": build_shop()
		"create": build_creation()
		"home": build_home()
		"schedule": build_schedule()
		"fight": build_fight()
		"records": build_records()
	var bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", box_style(BG, Color.TRANSPARENT, 0))
	shell.add_child(bottom)
	var footer = stack(bottom, 8)
	if target in ["home","schedule","fight","records"]:
		var nav = row(footer, 6)
		for item in [["home","선수"],["schedule","일정"],["fight","경기"],["records","기록"]]:
			var tab: String = item[0]
			button(nav, item[1], func(): show_screen(tab), target == tab, "nav_"+tab)
	status_label = label(status_message, 12, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(status_label)

func notify_message(message: String) -> void:
	status_message = message
	if is_instance_valid(status_label): status_label.text = message

func commit(next: Dictionary) -> bool:
	var err = SaveStore.save_game(next, save_path)
	if err != OK:
		show_modal("저장 실패", "변경 내용을 확정하지 않았습니다. 저장 공간과 폴더 권한을 확인해 주세요. 오류 코드: %d" % err)
		return false
	state = next
	notify_message("개발 테스트 · 저장 완료 %s" % Time.get_time_string_from_system())
	return true

func show_modal(title_value: String, body: String, confirm: Callable = Callable(), confirm_text: String = "확인") -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 50
	add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, .8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box_style(PANEL, Color("405242")))
	var dimensions = get_viewport_rect().size
	panel.size = Vector2(minf(500, dimensions.x - 32), minf(740, dimensions.y - 80))
	panel.position = (dimensions - panel.size) / 2
	modal.add_child(panel)
	var layout = stack(panel, 16)
	layout.add_child(label(title_value, 25, LIME))
	var scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroller)
	var body_label = label(body, 17)
	body_label.add_theme_constant_override("line_spacing", 7)
	scroller.add_child(body_label)
	var controls = row(layout)
	var overlay = modal
	if confirm.is_valid(): button(controls, "취소", func(): overlay.queue_free(), false, "modal_cancel")
	button(controls, confirm_text, func():
		overlay.queue_free()
		modal = null
		if confirm.is_valid(): confirm.call(), true, "modal_confirm")

func build_creation() -> void:
	section_title("18세, 첫 번째 코너", "무명의 오늘을, 전설의 시작으로.")
	hero_scene = scene_view(content,"boxing",220)
	var form = card(content)
	form.add_child(label("선수 이름",15,MUTED))
	name_input = LineEdit.new()
	name_input.text = "김도현"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 48
	name_input.add_theme_stylebox_override("normal",box_style(PANEL2))
	form.add_child(name_input)
	form.add_child(label("시작 스타일",15,MUTED))
	style_input = select(form,["striker","wrestler","grappler"],GameCatalog.data().style_names,"striker",func(_id): update_style_hint())
	var hint = label("",15,BLUE)
	hint.name = "StyleHint"
	form.add_child(hint)
	form.add_child(label("선수 트렁크 · 대한민국",15,MUTED))
	appearance_input = select(form,["0","1","2"],{"0":"코랄","1":"블루","2":"퍼플"},"0",func(id): hero_scene.appearance = int(id))
	update_style_hint()
	button(content,"이 선수로 시작하기",create_athlete,true,"create")
	button(content,"로비로",func(): show_screen("lobby"))

func update_style_hint() -> void:
	var hint = content.find_child("StyleHint", true, false)
	if hint == null: return
	var id = style_input.get_item_metadata(style_input.selected)
	var parts: Array = []
	for k in GameCatalog.data().style_bonus[id]: parts.append("%s +%d" % [GameCatalog.data().stat_names[k], GameCatalog.data().style_bonus[id][k]])
	hint.text = "초기 보너스: " + " · ".join(parts)
	if is_instance_valid(hero_scene): hero_scene.set_action({"striker":"boxing","wrestler":"wrestling","grappler":"bjj"}[id],appearance_input.selected if is_instance_valid(appearance_input) else 0)

func create_athlete() -> void:
	if name_input.text.strip_edges().is_empty():
		show_modal("이름을 입력해 주세요","선수 이름은 1~16자로 입력해 주세요.")
		return
	var athlete_name = name_input.text.strip_edges()
	var style: String = style_input.get_item_metadata(style_input.selected)
	var color: int = appearance_input.selected
	var finish = func():
		if cloud.connected:
			var response = await cloud.mutate("new",{"name":athlete_name,"style":style,"appearance":color})
			if accept_cloud(response): show_screen("home")
		else:
			var next = Career.new_generation(state,athlete_name,style,color)
			if commit(next): show_screen("home")
	if not state.is_empty():
		show_modal("새 선수로 시작할까요?","현재 선수는 새 선수로 바뀝니다. 명예의 전당·LP·체육관 시설은 유지됩니다. 은퇴 정산 전이라면 현재 선수의 보상은 받지 못합니다.",finish,"새 선수 시작")
	else: finish.call()

func build_home() -> void:
	var a: Dictionary = state.current_athlete
	var title_row = row(content)
	title_row.add_child(label("%s  ·  %d세" % [a.name,a.age],25))
	var back = button(title_row,"로비",func(): show_screen("lobby"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.add_theme_font_size_override("font_size",14)
	var info = row(content)
	info.add_child(label("%s · %d개월 차" % [GameCatalog.data().style_names[a.style],a.months],15,MUTED))
	var cash = label("%d만원" % a.cash,20,LIME)
	cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(cash)
	hero_scene = scene_view(content,"boxing",225)
	var scene_caption = row(content)
	scene_caption.add_child(label("언더독 MMA · 오늘도 한 걸음",15,MUTED))
	scene_caption.add_child(label("%d승 %d패 %d무" % [a.wins,a.losses,a.draws],17,LIME))
	var body = card(content)
	gauge(body,"활력",Career.energy(a),GREEN,"피로를 줄이면 활력이 회복됩니다")
	gauge(body,"피로",a.fatigue,ORANGE)
	var condition_row = row(body)
	condition_row.add_child(label("컨디션 %d%%" % Career.condition(a),15,BLUE))
	condition_row.add_child(label("충분히 회복됨" if a.fatigue<=0 else "휴식 최대 -22 · 지금 실제 -%.2f" % minf(22,a.fatigue),14,GREEN))
	if a.get("retired",false):
		button(content,"은퇴한 선수입니다 · 새 선수 시작",func(): show_screen("create"),true)
	elif Career.fight_due(state):
		var due = card(content,Color("4b3033"))
		due.add_child(label("오늘은 경기일",21,ORANGE))
		due.add_child(label("예정 경기를 먼저 진행해야 시간이 흐릅니다.",14))
		button(due,"경기장으로",func(): show_screen("fight"),true,"fight_due")
	else:
		button(content,"%d개월 차 일정 편성  →" % (int(a.months)+1),func(): show_screen("schedule"),true,"plan")
		content.add_child(label("다음 경기까지 %d개월 · 회복을 포함해 일정을 준비하세요" % (a.next_fight_month-a.months),14,BLUE))
	var stats = card(content)
	stats.add_child(label("선수 능력",18))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",10)
	stats.add_child(grid)
	for k in GameCatalog.data().stat_names:
		var stat = stack(grid,3)
		stat.add_child(label("%s   %.1f" % [GameCatalog.data().stat_names[k],a.stats[k]],15))
		meter_bar(stat,a.stats[k],BLUE if k in ["wrestling","grappling"] else LIME,6)
	var tools_row = row(content)
	button(tools_row,"저장 확인",func():
		if cloud.connected: await refresh_cloud()
		elif commit(state.duplicate(true)): notify_message("저장 완료"),false,"save")
	button(tools_row,"불러오기",load_clicked,false,"load")

func load_clicked() -> void:
	if cloud.connected:
		await refresh_cloud()
		if not state.is_empty(): show_screen("home")
		return
	var loaded = SaveStore.load_game(save_path)
	if not loaded.ok:
		show_modal("불러오기 실패",loaded.error)
		return
	state = loaded.state
	notify_message("백업 복구 완료" if loaded.recovered else "불러오기 완료 · 개발 테스트")
	show_screen("home")

func build_schedule() -> void:
	var a: Dictionary = state.current_athlete
	section_title("%d개월 차 · 월간 일정" % (int(a.months)+1),"네 번의 일주일, 나만의 페이스")
	if Career.fight_due(state) or a.get("retired",false):
		scene_view(content,"sparring",200)
		content.add_child(label("예정 경기 먼저 진행" if not a.get("retired",false) else "은퇴한 선수입니다",24,ORANGE))
		content.add_child(label("경기일을 넘겨서 훈련할 수 없습니다.",16))
		button(content,"경기장으로",func(): show_screen("fight"),true,"fight_due")
		var disabled = button(content,"일정 진행 불가",month_clicked,false,"advance")
		disabled.disabled = true
		return
	var presets = row(content,5)
	for p in [["balanced","균형"],["striking","타격"],["wrestling","레슬링"],["grappling","그래플링"],["recovery","회복"]]:
		var kind: String = p[0]
		var b = button(presets,p[1],func(): await apply_schedule(GameCatalog.default_schedule(kind)))
		b.add_theme_font_size_override("font_size",13)
		b.custom_minimum_size.y = 42
	var week_row = row(content)
	for i in 4:
		var week_label = label("%d주" % (i+1),16,LIME)
		week_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		week_row.add_child(week_label)
	for slot in ["main","aux","life"]:
		content.add_child(label({"main":"주요 훈련  ·  100%","aux":"보조 훈련  ·  55%","life":"생활  ·  수입과 회복"}[slot],14,MUTED))
		var tiles = row(content,7)
		for i in 4:
			var week_index: int = i
			var slot_key: String = slot
			var id: String = state.schedule[i][slot]
			var act = GameCatalog.action(id)
			var scale: float = .55 if slot == "aux" else 1.0
			var recovery: bool = float(act.fatigue)<0
			var tile = Button.new()
			tile.custom_minimum_size.y = 101
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.add_theme_stylebox_override("normal",box_style(Color("23443f") if recovery else PANEL,Color("3a7062") if recovery else Color("34465d"),9))
			tile.add_theme_stylebox_override("hover",box_style(PANEL2,LIME,9))
			tile.set_meta("action","slot_%d_%s" % [i,slot])
			tile.pressed.connect(func(): open_action_picker(week_index,slot_key))
			tiles.add_child(tile)
			var padding = MarginContainer.new()
			padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for side in ["top","bottom","left","right"]: padding.add_theme_constant_override("margin_"+side,6)
			padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(padding)
			var inside = stack(padding,2)
			inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon = ActivityIcon.new()
			icon.action_id = id
			icon.tint = GREEN if recovery else LIME
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			inside.add_child(icon)
			var short_name: String = {"life_rest":"충분한 휴식","rest":"휴식","kickboxing":"킥복싱","delivery":"배달 알바","job":"편의점 알바"}.get(id,act.name)
			var name_label = label(short_name,13)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inside.add_child(name_label)
			var effect = label("회복 %.1f" % (-act.fatigue*scale) if recovery else ("+%d만 · 피로 +%.0f" % [act.income,act.fatigue] if slot == "life" else "피로 +%.1f" % (act.fatigue*scale)),12,GREEN if recovery else ORANGE)
			effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inside.add_child(effect)
	var preview = card(content)
	preview.add_child(label("이번 달 실제 예상",16,LIME))
	forecast = label("",15)
	preview.add_child(forecast)
	var result = Career.month(state)
	if result.ok:
		gauge(preview,"월말 활력",100-result.report.fatigue,GREEN)
		preview.add_child(label("행동 회복 %.1f + 자연 회복 %.1f" % [result.report.recovery_total,result.report.natural_recovery],14,GREEN))
	update_forecast()
	button(content,"이 일정으로 한 달 시작",month_clicked,true,"advance")
	var presets_row = row(content)
	button(presets_row,"내 일정 저장",func():
		var next = state.duplicate(true)
		next.saved_preset = next.schedule.duplicate(true)
		if cloud.connected:
			var response = await cloud.mutate("preset",{"schedule":next.saved_preset})
			accept_cloud(response)
		else: commit(next),false,"preset_save")
	button(presets_row,"내 일정 적용",func(): await apply_schedule(state.saved_preset),false,"preset_load")
	button(content,"훈련·회복 수치 안내",show_action_guide,false,"guide")

func update_forecast() -> void:
	var preview = Career.month(state)
	if preview.ok:
		forecast.text = "현금 %d → %d만원 (%+d)
피로 %.1f → %.1f · 컨디션 %d%%
생활비·체육관비 %d만원 포함" % [state.current_athlete.cash,preview.report.cash,preview.report.cash_delta,state.current_athlete.fatigue,preview.report.fatigue,Career.condition(preview.state.current_athlete),preview.report.fixed_cost]
	else: forecast.text = preview.error

func show_action_guide() -> void:
	var lines: Array = ["주요 100%, 보조 55% 적용. 피로가 높으면 성장 효율이 감소합니다. 능력치 상한은 100입니다.\n"]
	for id in GameCatalog.data().actions:
		var act = GameCatalog.action(id)
		var gains: Array = []
		for k in act.gains: gains.append("%s +%.1f" % [GameCatalog.data().stat_names[k], act.gains[k]])
		lines.append("%s\n비용 %d만 · 수입 %d만 · 피로 %+d\n%s\n" % [act.name, act.cost, act.get("income",0), act.fatigue, " / ".join(gains)])
	show_modal("훈련·생활 가이드", "\n".join(lines))

func month_clicked() -> void:
	var result = Career.month(state)
	if not result.ok:
		show_modal("경기를 먼저 진행하세요" if result.get("fight_due",false) else "일정을 조정해 주세요",result.error)
		return
	var report: Dictionary = result.report
	show_modal("한 달을 시작할까요?","4주를 장면과 함께 진행합니다.

현금 %+d만원 → %d만원
피로 %.1f → %.1f
훈련·생활 회복 %.1f + 자연 회복 %.1f

완료한 달은 자동으로 저장됩니다." % [report.cash_delta,report.cash,state.current_athlete.fatigue,report.fatigue,report.recovery_total,report.natural_recovery],func():
		if cloud.connected:
			var response = await cloud.mutate("month",{})
			if accept_cloud(response): play_month(response.report)
		elif commit(result.state): play_month(report),"한 달 시작")

func show_month_report(report: Dictionary) -> void:
	var sheet = open_sheet("%d개월 차 · 성장 리포트" % report.month)
	var body: VBoxContainer = sheet.body
	var preview = scene_view(body,"life_rest",165)
	preview.paused = false
	body.add_child(label("한 달 동안, 이만큼 자랐습니다.",20,LIME))
	if report.has("stat_gains"):
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation",18)
		body.add_child(grid)
		for stat in report.stat_gains:
			if report.stat_gains[stat] > 0: grid.add_child(label("%s  +%.1f" % [GameCatalog.data().stat_names[stat],report.stat_gains[stat]],18,GREEN))
	else: body.add_child(label(" · ".join(report.gains),17,GREEN))
	gauge(body,"남은 피로",report.fatigue,ORANGE)
	body.add_child(label("현금 %+d만원  →  %d만원" % [report.cash_delta,report.cash],19,LIME))
	if report.has("recovery_total"): body.add_child(label("실제 회복 %.1f · 자연 회복 %.1f" % [report.recovery_total,report.natural_recovery],16,GREEN))
	button(body,"주간 상세 기록",func(): show_modal("주간 기록","\n\n".join(report.logs)))
	button(sheet.footer,"확인",func(): sheet.overlay.queue_free(),true,"modal_confirm")

func build_fight() -> void:
	var a: Dictionary = state.current_athlete
	var opponent = Career.opponent(state)
	section_title("FIGHT NIGHT  /  ROOKIE SERIES", "오늘의 상대", "3라운드 MMA · 전략을 고르고 출전하세요")
	scene_view(content,"sparring",205)
	var match_card = card(content)
	match_card.add_child(label("%s  VS  %s" % [a.name,opponent.name], 25))
	match_card.add_child(label(GameCatalog.data().style_names[opponent.style] + " · " + opponent.tag, 16, ORANGE))
	for k in ["striking","wrestling","grappling"]:
		var compare = row(match_card)
		compare.add_child(label(GameCatalog.data().stat_names[k],15,MUTED))
		compare.add_child(label("나 %.0f  :  상대 %.0f" % [a.stats[k],opponent.stats[k]],16,BLUE))
	gauge(match_card,"내 활력",Career.energy(a),GREEN)
	match_card.add_child(label("내 피로 %d · 컨디션 %d%%\n피로가 높으면 시작 체력과 공격·방어 효율이 낮아집니다." % [roundi(a.fatigue),Career.condition(a)], 17, BLUE))
	var controls = card(content)
	controls.add_child(label("코너 전략", 15, MUTED))
	select(controls, ["balanced","striking","counter","wrestling","submission"], GameCatalog.data().strategy_names, state.settings.strategy, func(id):
		var next = state.duplicate(true)
		next.settings.strategy = id
		commit(next))
	controls.add_child(label("타격: 유효타·대미지 / 카운터: 정확도\n레슬링: 클린치·테이크다운 / 서브미션: 상위에서 마무리", 14, MUTED))
	var check = CheckButton.new()
	check.text = "고정 시드 사용 (재현 테스트)"
	check.button_pressed = state.settings.fixed_seed
	check.disabled = cloud.connected
	check.custom_minimum_size.y = 48
	controls.add_child(check)
	var seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 2147483647
	seed_box.value = state.settings.seed
	seed_box.custom_minimum_size.y = 48
	seed_box.editable = state.settings.fixed_seed and not cloud.connected
	controls.add_child(seed_box)
	check.toggled.connect(func(enabled):
		seed_box.editable = enabled
		var next = state.duplicate(true)
		next.settings.fixed_seed = enabled
		commit(next))
	seed_box.value_changed.connect(func(value):
		var next = state.duplicate(true)
		next.settings.seed = int(value)
		commit(next))
	content.add_child(label("출전 수당 12만 · 승리 보너스 10만\n경기 후 피로 +24 · 다음 경기는 3개월 후", 16, MUTED))
	var wait: int = maxi(0, int(a.next_fight_month-a.months))
	var start = button(content, "경기까지 %d개월 · 훈련을 진행하세요" % wait if wait > 0 else "옥타곤에 입장하기  →", fight_clicked, true, "start_fight")
	start.disabled = wait > 0 or a.get("retired",false)

func fight_clicked() -> void:
	var match_seed: int = int(state.settings.seed) if state.settings.fixed_seed else int(randi() & 0x7fffffff)
	var result = Career.fight(state,state.settings.strategy,match_seed)
	if not result.ok:
		show_modal("출전할 수 없습니다",result.error)
		return
	show_modal("경기에 출전할까요?","상대: %s
전략: %s
활력 %.1f · 피로 %.1f

경기 후 다음 출전은 3개월 뒤입니다." % [Career.opponent(state).name,GameCatalog.data().strategy_names[state.settings.strategy],Career.energy(state.current_athlete),state.current_athlete.fatigue],func():
		if cloud.connected:
			var response = await cloud.mutate("fight",{"strategy":state.settings.strategy})
			if accept_cloud(response):
				show_screen("records")
				show_fight_report(response.result)
		elif commit(result.state):
			show_screen("records")
			show_fight_report(result.result),"경기 시작")

func show_fight_report(result: Dictionary) -> void:
	var outcome = {"player":"승리", "opponent":"패배", "draw":"무승부"}[result.winner]
	var sheet = open_sheet("%s · %s" % [outcome,result.method])
	scene_view(sheet.body,"sparring",190)
	var heading = label("%s  VS  %s" % [state.current_athlete.name,result.opponent],23,LIME)
	sheet.body.add_child(heading)
	if result.method == "판정": sheet.body.add_child(label("최종 판정  %d : %d" % [result.scores[0],result.scores[1]],26,GREEN if result.winner=="player" else ORANGE))
	else: sheet.body.add_child(label("R%d  %d:%02d 종료" % [result.round,int(result.second)/60,int(result.second)%60],23))
	for round_result in result.rounds:
		var c = card(sheet.body)
		c.add_child(label("ROUND %d · %s" % [round_result.round,"%d : %d" % [round_result.score[0],round_result.score[1]] if round_result.completed else "경기 중단"],17,LIME))
		var meters = row(c)
		var own = stack(meters,4)
		own.add_child(label("내 체력 %.0f" % round_result.hp[0],14,GREEN))
		meter_bar(own,round_result.hp[0],GREEN,8)
		var opponent = stack(meters,4)
		opponent.add_child(label("상대 체력 %.0f" % round_result.hp[1],14,ORANGE))
		meter_bar(opponent,round_result.hp[1],ORANGE,8)
	sheet.body.add_child(label("출전 수당 +%d만원 · 피로 +24" % result.reward,19,LIME))
	sheet.body.add_child(label("전략 %s · 시드 %d" % [GameCatalog.data().strategy_names[result.strategy],result.seed],13,MUTED))
	button(sheet.body,"상세 경기 로그",func(): show_modal("라운드별 경기 기록","\n".join(result.logs)))
	button(sheet.footer,"확인",func(): sheet.overlay.queue_free(),true,"modal_confirm")

func build_records() -> void:
	var a: Dictionary = state.current_athlete
	section_title("CAREER JOURNAL", "작은 성장을 기록하다", "%d개월 · %d승 %d패 %d무" % [a.months,a.wins,a.losses,a.draws])
	content.add_child(label("경기 기록", 22))
	if a.fights.is_empty(): content.add_child(label("아직 경기가 없습니다. 2개월 육성 후 첫 경기에 출전하세요.", 17, MUTED))
	for index in range(a.fights.size()-1,-1,-1):
		var result: Dictionary = a.fights[index]
		var c = card(content)
		var outcome = {"player":"WIN", "opponent":"LOSS", "draw":"DRAW"}[result.winner]
		c.add_child(label("%s  /  %s · %s" % [outcome,result.opponent,result.method], 21, LIME if result.winner == "player" else ORANGE))
		c.add_child(label("%d개월 차 · R%d · 수당 %d만원 · 시드 %d" % [result.month,result.round,result.reward,result.seed], 14, MUTED))
		button(c, "라운드 로그 보기", func(): show_fight_report(result))
	content.add_child(label("최근 월간 리포트", 22))
	for index in range(a.month_history.size()-1, maxi(-1,a.month_history.size()-7),-1):
		var report: Dictionary = a.month_history[index]
		button(content, "%d개월 차 · 현금 %+d만 · 피로 %d" % [report.month,report.cash_delta,roundi(report.fatigue)], func(): show_month_report(report))
	var management = card(content)
	management.add_child(label("저장 관리", 20))
	management.add_child(label("자동 저장 + 이전 저장 백업 1개\n버전 1 · 내 선수 ID " + str(a.athlete_id).left(8), 14, MUTED))
	button(management, "저장 폴더 열기", func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	button(management, "새 선수 만들기", func(): show_screen("create"), false, "new_game")
	content.add_child(label("P0 구현 범위\n국내 신인 육성 · 훈련 · 아르바이트 · 자동 경기 · 저장\n\n다음 단계\n해외 커리어, 전문 대회, 부상, 은퇴, 계승, 코치, 체육관 설립은 아직 구현하지 않았습니다.", 15, MUTED))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(playback):
			playback.finish()
		elif is_instance_valid(modal):
			modal.queue_free()
			modal = null
		elif not state.is_empty(): show_screen("home")

func meter_bar(parent: Node, value: float, color: Color, height: int = 12) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg = box_style(Color("0d1725"),Color.TRANSPARENT,4)
	bg.set_content_margin_all(0)
	var fill = box_style(color,Color.TRANSPARENT,4)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	return bar

func gauge(parent: Node, caption: String, value: float, color: Color, hint: String = "") -> ProgressBar:
	var section = stack(parent,4)
	var heading = row(section)
	heading.add_child(label(caption,15,MUTED))
	var number = label("%.1f / 100" % value,16,color)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(number)
	var bar = meter_bar(section,value,color,11)
	bar.set_meta("meter",caption)
	if not hint.is_empty(): section.add_child(label(hint,12,MUTED))
	return bar

func scene_view(parent: Node, action: String, height: int = 210) -> ActivityScene:
	var world = ActivityScene.new()
	world.custom_minimum_size.y = height
	world.action_id = action
	world.appearance = int(state.get("current_athlete",{}).get("appearance",0))
	parent.add_child(world)
	return world

func open_sheet(title_value: String) -> Dictionary:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 50
	add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",box_style(PANEL,Color("496074")))
	var dimensions = get_viewport_rect().size
	panel.size = Vector2(minf(500,dimensions.x-24),minf(855,dimensions.y-40))
	panel.position = (dimensions-panel.size)/2
	modal.add_child(panel)
	var layout = stack(panel,12)
	layout.add_child(label(title_value,23,LIME))
	var scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroller)
	var body = stack(scroller,12)
	var footer = row(layout)
	return {"overlay":modal,"body":body,"footer":footer}

func build_lobby() -> void:
	section_title("ROAD TO CHAMPION","무명에서, 챔피언까지.")
	scene_view(content,"boxing",250)
	content.add_child(label("언더독: MMA 선수 키우기",25,LIME))
	if cloud.connected:
		content.add_child(label("온라인 연결됨 · 진행과 재화는 서버에서 처리",14,GREEN))
	else:
		content.add_child(label("개발 테스트 모드 · 정식 서버와 Google Play 미연결",14,ORANGE))
	if not state.is_empty():
		var a: Dictionary = state.current_athlete
		var save_card = card(content)
		save_card.add_child(label("%s · %d세 · %d개월" % [a.name,a.age,a.months],20))
		save_card.add_child(label("%d승 %d패 %d무  /  %d만원" % [a.wins,a.losses,a.draws,a.cash],15,MUTED))
		button(save_card,"이어서 진행하기",func(): show_screen("home"),true,"continue")
	else:
		var locked = button(content,"이어서 진행하기 · 저장된 선수 없음",func(): pass,false,"continue")
		locked.disabled = true
	button(content,"새로 선수 키우기",func(): show_screen("create"),state.is_empty(),"new_game")
	var menu = row(content)
	button(menu,"명예의 전당",func(): show_screen("hall"),false,"hall")
	button(menu,"훈련소 강화",func(): show_screen("gym"),false,"gym")
	button(content,"캐시 상점",func(): show_screen("shop"),false,"shop")
	button(content,"온라인 서버 연결",show_connection,false,"connect")

func build_hall() -> void:
	section_title("선수의 이름은 남는다","명예의 전당")
	scene_view(content,"idle",180)
	var entries: Array = state.get("hall_of_fame",[])
	if entries.is_empty():
		var empty = card(content)
		empty.add_child(label("아직 은퇴한 선수가 없습니다.",20,LIME))
		empty.add_child(label("선수 생활 18개월 + 공식 경기 3회 이후 은퇴 정산을 할 수 있습니다. 정산한 선수의 기록과 LP는 다음 선수에게 이어집니다.",16,MUTED))
	for entry in entries:
		var c = card(content)
		c.add_child(label(str(entry.get("name","선수")),23,LIME))
		c.add_child(label("%d개월 · %d승 %d패 %d무 · LP %d" % [entry.get("months",0),entry.get("wins",0),entry.get("losses",0),entry.get("draws",0),entry.get("lp",0)],16))
	if not state.is_empty() and Career.can_retire(state):
		button(content,"현재 선수 은퇴 정산",func():
			show_modal("은퇴 정산할까요?","현재 선수의 기록을 보존하고 LP를 받습니다. 은퇴 후에는 새 선수로 육성을 시작해야 합니다.",func():
				if cloud.connected:
					var response = await cloud.mutate("retire",{})
					if accept_cloud(response): show_screen("hall")
				else:
					var result = Career.retire(state)
					if result.ok and commit(result.state): show_screen("hall"),"은퇴 정산"),true,"retire")
	button(content,"로비로",func(): show_screen("lobby"))

func build_gym() -> void:
	section_title("다음 세대의 출발선","훈련소 업그레이드")
	scene_view(content,"weights",180)
	var lp: int = int(state.get("account_legacy",{}).get("lp",0))
	content.add_child(label("보유 레거시 포인트  %d LP" % lp,21,LIME))
	content.add_child(label("유효 은퇴 정산으로 LP 획득 · 시설은 새 선수에게 유지됩니다.",14,MUTED))
	for id in GameCatalog.data().facilities:
		var facility_id: String = id
		var definition: Dictionary = GameCatalog.data().facilities[id]
		var level: int = int(state.get("gym_facilities",{}).get(id,{}).get("level",0))
		var cost: int = 5*(level+1)
		var c = card(content)
		c.add_child(label("%s   Lv.%d / 3" % [definition.name,level],21))
		meter_bar(c,level/3.0*100,GREEN,9)
		c.add_child(label("%s 훈련 성장 +%d%% → +%d%%" % [GameCatalog.data().stat_names[definition.stat],level*5,mini(level+1,3)*5],16,GREEN))
		var upgrade = button(c,"최대 레벨" if level>=3 else "%d LP로 업그레이드" % cost,func():
			if cloud.connected:
				var response = await cloud.mutate("upgrade",{"facility":facility_id})
				if accept_cloud(response): show_screen("gym")
			else:
				var result = Career.upgrade(state,facility_id)
				if result.ok and commit(result.state): show_screen("gym"),false,"upgrade_"+id)
		upgrade.disabled = level>=3 or lp<cost or state.is_empty()
	button(content,"로비로",func(): show_screen("lobby"))

func build_shop() -> void:
	section_title("캐시 상점","캐시는 계정에 보관됩니다")
	var c = card(content)
	c.add_child(label("보유 캐시   %d" % int(cloud.wallet.get("cash",0)),26,LIME))
	c.add_child(label("Google Play 개발자 계정과 결제 상품이 아직 연결되지 않았습니다. 현재 버전에서는 실제 결제를 시작할 수 없습니다.",16,MUTED))
	for product in [["캐시 100","캐시 100개"],["캐시 550","캐시 550개"]]:
		var item = card(content)
		item.add_child(label(product[0],23,LIME))
		item.add_child(label("가격은 Google Play 연결 후 표시됩니다.",15,MUTED))
		var purchase = button(item,"결제 연동 준비 중",func(): pass,false,"purchase")
		purchase.disabled = true
	content.add_child(label("결제 영수증·중복 지급 방지·계정별 잔액은 서버에서 검증하도록 분리했습니다. 화면의 버튼을 눌러 캐시를 임의로 지급하지 않습니다.",14,MUTED))
	button(content,"로비로",func(): show_screen("lobby"))

func open_action_picker(week: int, slot: String) -> void:
	picker_week = week
	picker_slot = slot
	picker_id = state.schedule[week][slot]
	var sheet = open_sheet("%d주 · %s 선택" % [week+1,{"main":"주요 훈련","aux":"보조 훈련","life":"생활 행동"}[slot]])
	picker_world = scene_view(sheet.body,picker_id,175)
	picker_info = label("",16)
	sheet.body.add_child(picker_info)
	picker_meter = meter_bar(sheet.body,0,GREEN,12)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	sheet.body.add_child(grid)
	var ids = GameCatalog.data().life_ids if slot == "life" else GameCatalog.data().main_ids
	for id in ids:
		var selected_id: String = id
		var act = GameCatalog.action(id)
		var scale: float = .55 if slot == "aux" else 1.0
		var summary: String = "회복 %.1f" % (-act.fatigue*scale) if act.fatigue < 0 else "피로 +%.1f" % (act.fatigue*scale)
		var title: String = "%s\n%s · %s" % [act.name,summary,"+%d만" % act.get("income",0) if act.get("income",0)>0 else "비용 %d만" % ceili(act.cost*scale)]
		var b = button(grid,title,func(): preview_action(selected_id),false,"choose_"+id)
		b.add_theme_font_size_override("font_size",14)
		b.custom_minimum_size.y = 73
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(sheet.footer,"취소",func(): sheet.overlay.queue_free(),false,"modal_cancel")
	button(sheet.footer,"이 행동 적용",func():
		var next_schedule = state.schedule.duplicate(true)
		next_schedule[picker_week][picker_slot] = picker_id
		sheet.overlay.queue_free()
		await apply_schedule(next_schedule),true,"action_apply")
	preview_action(picker_id)

func preview_action(id: String) -> void:
	picker_id = id
	picker_world.set_action(id,int(state.current_athlete.appearance))
	var simulated = state.duplicate(true)
	simulated.schedule[picker_week][picker_slot] = id
	var result = Career.month(simulated)
	var timeline: Array = result.report.timeline if result.ok else result.get("timeline",[])
	for event in timeline:
		if event.week != picker_week+1 or event.slot != picker_slot: continue
		var parts: Array = []
		for stat in event.gains: parts.append("%s +%.1f" % [GameCatalog.data().stat_names[stat],event.gains[stat]])
		var diff: float = event.fatigue_after-event.fatigue_before
		var effect = "회복 최대 %.2f · 실제 %.2f" % [event.potential_recovery,event.recovered] if event.potential_recovery>0 else "피로 +%.1f" % diff
		picker_info.text = "%s\n피로 %.2f → %.2f · 활력 %.2f\n%s" % [effect,event.fatigue_before,event.fatigue_after,100-event.fatigue_after," · ".join(parts)]
		picker_meter.value = 100-event.fatigue_after
		return
	picker_info.text = result.get("error","")

func apply_schedule(schedule: Array) -> void:
	var previous_scroll: int = scroll.scroll_vertical
	if cloud.connected:
		var response = await cloud.mutate("schedule",{"schedule":schedule})
		if not accept_cloud(response): return
	else:
		var next = state.duplicate(true)
		next.schedule = schedule.duplicate(true)
		if not commit(next): return
	show_screen("schedule")
	scroll.set_deferred("scroll_vertical",previous_scroll)

func play_month(report: Dictionary) -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null
	playback = MonthPlayback.new()
	add_child(playback)
	playback.setup(self,report,int(state.current_athlete.appearance))
	playback.finished.connect(func():
		show_screen("home")
		show_month_report(report))

func show_connection() -> void:
	var sheet = open_sheet("온라인 서버 연결")
	sheet.body.add_child(label("운영 서버 주소가 준비되면 입력합니다. 연결 후에는 경기·훈련·시설을 서버에서 처리하고 계정 진행을 불러옵니다.",16))
	var address = LineEdit.new()
	address.placeholder_text = "https://서버주소"
	address.text = cloud.base_url
	address.custom_minimum_size.y = 50
	sheet.body.add_child(address)
	var hint = label("정식 서버는 아직 배포하지 않았습니다. 현재 로컬 플레이는 기능 확인용 개발 테스트입니다.",14,ORANGE)
	sheet.body.add_child(hint)
	button(sheet.footer,"닫기",func(): sheet.overlay.queue_free(),false,"modal_confirm")
	button(sheet.footer,"연결",func():
		hint.text = "서버 확인 중…"
		var response = await cloud.connect_server(address.text)
		if response.get("ok",false):
			save_path = "user://online_cache_v1.json"
			state = {}
			if response.has("state") and response.state != null: accept_cloud(response)
			notify_message("온라인 서버 연결됨")
			show_screen("lobby")
		else: hint.text = str(response.get("error","서버 연결 실패")),true,"server_connect")

func accept_cloud(response: Dictionary) -> bool:
	if not response.get("ok",false):
		show_modal("서버 요청 실패",str(response.get("error","잠시 후 다시 시도해 주세요.")))
		return false
	if response.get("state") is Dictionary:
		if not SaveStore.valid(response.state):
			show_modal("서버 응답 확인 필요","지원하지 않는 선수 데이터입니다.")
			return false
		state = response.state
		var error = SaveStore.save_game(state,save_path)
		if error != OK: notify_message("서버 저장 완료 · 기기 캐시 저장 실패")
		else: notify_message("온라인 · 서버 저장 완료")
	return true

func refresh_cloud() -> void:
	var response = await cloud.fetch_state()
	accept_cloud(response)
