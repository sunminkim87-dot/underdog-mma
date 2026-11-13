extends Control

const BG = Color("0b1018")
const PANEL = Color("141e2b")
const PANEL2 = Color("1b2939")
const TEXT = Color("f1f3ed")
const MUTED = Color("9aabba")
const LIME = Color("dafa63")
const ORANGE = Color("ff9b73")
const BLUE = Color("7cbcff")

var state: Dictionary = {}
var screen: String = "home"
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
var status_message: String = "로컬 저장 · 오프라인 플레이"

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
	else: screen = "create"
	show_screen(screen)

func box_style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(18)
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
	content.add_child(label(title, 30))
	if not detail.is_empty(): content.add_child(label(detail, 16, MUTED))

func show_screen(target: String) -> void:
	screen = target
	for child in get_children():
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
	header.add_child(label("U / UNDERDOG", 20, LIME))
	var p0 = label("P0  ·  육성 테스트", 13, MUTED)
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
		"create": build_creation()
		"home": build_home()
		"schedule": build_schedule()
		"fight": build_fight()
		"records": build_records()
	var bottom = PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", box_style(BG, Color.TRANSPARENT, 0))
	shell.add_child(bottom)
	var footer = stack(bottom, 8)
	if target != "create":
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
	notify_message("자동 저장 완료 · %s" % Time.get_time_string_from_system())
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
	section_title("ROAD TO CHAMPION", "위대한 시작은\n언제나 언더독.", "18세 국내 신인 프로. 당신의 첫 시즌을 시작하세요.")
	var hero = card(content)
	var art = TextureRect.new()
	art.texture = load("res://assets/art/fighter.svg")
	art.custom_minimum_size.y = 235
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(art)
	var form = card(content)
	form.add_child(label("선수 이름", 15, MUTED))
	name_input = LineEdit.new()
	name_input.text = "김도현"
	name_input.max_length = 16
	name_input.custom_minimum_size.y = 50
	name_input.add_theme_stylebox_override("normal", box_style(PANEL2, Color("344252"), 8))
	form.add_child(name_input)
	form.add_child(label("기본 스타일", 15, MUTED))
	style_input = select(form, ["striker","wrestler","grappler"], GameCatalog.data().style_names, "striker", func(_id): update_style_hint())
	var hint = label("", 15, BLUE)
	hint.name = "StyleHint"
	form.add_child(hint)
	form.add_child(label("트렁크 색상 · 국적: 대한민국", 15, MUTED))
	appearance_input = select(form, ["0","1","2"], {"0":"라임", "1":"블루", "2":"코랄"}, "0", func(_id): pass)
	update_style_hint()
	button(content, "18세 선수로 시작하기  →", create_athlete, true, "create")
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		button(content, "저장된 선수 불러오기", load_clicked, false, "load")
	content.add_child(label("선택한 스타일 외의 모든 종목도 훈련할 수 있습니다.\n수치와 경제는 P0 플레이 테스트용입니다.", 14, MUTED))

func update_style_hint() -> void:
	var hint = content.find_child("StyleHint", true, false)
	if hint == null: return
	var id = style_input.get_item_metadata(style_input.selected)
	var parts: Array = []
	for k in GameCatalog.data().style_bonus[id]: parts.append("%s +%d" % [GameCatalog.data().stat_names[k], GameCatalog.data().style_bonus[id][k]])
	hint.text = "초기 보너스: " + " · ".join(parts)

func create_athlete() -> void:
	if name_input.text.strip_edges().is_empty():
		show_modal("이름을 입력해 주세요", "선수 이름은 1~16자로 입력해 주세요.")
		return
	var next = Career.create(name_input.text, style_input.get_item_metadata(style_input.selected), appearance_input.selected)
	var finish = func():
		if commit(next): show_screen("home")
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		show_modal("새 선수로 시작할까요?", "현재 저장 슬롯이 새 선수로 바뀝니다. 기존 선수를 보존하려면 먼저 기록 화면에서 저장 폴더를 열어 파일을 복사해 두세요.", finish, "새 게임 시작")
	else: finish.call()

func build_home() -> void:
	var a: Dictionary = state.current_athlete
	section_title("DOMESTIC ROOKIE  /  국내 신인 프로", "%s의 코너" % a.name)
	var hero = card(content)
	var hero_row = row(hero)
	var info = stack(hero_row, 8)
	info.add_child(label("%d세 · %s" % [a.age, GameCatalog.data().style_names[a.style]], 17, MUTED))
	info.add_child(label("%d승  %d패  %d무" % [a.wins, a.losses, a.draws], 25))
	info.add_child(label("선수 생활 %d개월" % a.months, 15, LIME))
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/art/fighter.svg")
	portrait.custom_minimum_size = Vector2(180, 155)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = [Color.WHITE, Color("a0c8ff"), Color("ffbba1")][a.appearance]
	hero_row.add_child(portrait)
	var metrics = row(content)
	for item in [["보유 현금", "%d만원" % a.cash, LIME],["피로", "%d / 100" % roundi(a.fatigue), ORANGE],["컨디션", "%d%%" % Career.condition(a), BLUE]]:
		var c = card(metrics)
		c.add_child(label(item[0], 14, MUTED))
		c.add_child(label(item[1], 21, item[2]))
	var stats = card(content)
	stats.add_child(label("ATHLETE PROFILE", 13, MUTED))
	for k in GameCatalog.data().stat_names:
		var line = row(stats, 14)
		var title_label = label(GameCatalog.data().stat_names[k], 16)
		title_label.custom_minimum_size.x = 75
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(title_label)
		var bar = ProgressBar.new()
		bar.show_percentage = false
		bar.value = a.stats[k]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 9
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", box_style(PANEL2, Color.TRANSPARENT, 4))
		bar.add_theme_stylebox_override("fill", box_style(LIME, Color.TRANSPARENT, 4))
		line.add_child(bar)
		var value = label("%.1f" % a.stats[k], 17, LIME)
		value.custom_minimum_size.x = 45
		value.size_flags_horizontal = Control.SIZE_SHRINK_END
		line.add_child(value)
	var remaining = maxi(0, int(a.next_fight_month - a.months))
	content.add_child(label("다음 경기: " + ("지금 출전 가능" if remaining == 0 else "%d개월 후" % remaining), 17, BLUE))
	button(content, "다음 달 훈련 편성  →", func(): show_screen("schedule"), true, "plan")
	var tools_row = row(content)
	button(tools_row, "저장", func():
		if commit(state.duplicate(true)): notify_message("수동 저장 완료"), false, "save")
	button(tools_row, "불러오기", load_clicked, false, "load")

func load_clicked() -> void:
	var loaded = SaveStore.load_game(save_path)
	if not loaded.ok:
		show_modal("불러오기 실패", loaded.error)
		return
	state = loaded.state
	notify_message("백업 복구 완료 · 저장으로 확정" if loaded.recovered else "불러오기 완료")
	show_screen("home")

func build_schedule() -> void:
	var a = state.current_athlete
	section_title("MONTH %02d  /  4 WEEK PLAN" % (int(a.months)+1), "다음 한 달을 설계하세요", "주요 100% · 보조 55% 효율. 매주 생활 행동까지 선택하세요.")
	var preset = row(content, 6)
	for p in [["balanced","균형"],["striking","타격"],["wrestling","레슬링"],["grappling","그래플링"],["recovery","회복"]]:
		var kind: String = p[0]
		var b = button(preset, p[1], func():
			var next = state.duplicate(true)
			next.schedule = GameCatalog.default_schedule(kind)
			if commit(next): show_screen("schedule"))
		b.add_theme_font_size_override("font_size", 14)
	var custom_row = row(content)
	button(custom_row, "내 일정 저장", func():
		var next = state.duplicate(true)
		next.saved_preset = next.schedule.duplicate(true)
		if commit(next): notify_message("사용자 프리셋 저장 완료"), false, "preset_save")
	button(custom_row, "내 일정 적용", func():
		var next = state.duplicate(true)
		next.schedule = next.saved_preset.duplicate(true)
		if commit(next): show_screen("schedule"), false, "preset_load")
	var names: Dictionary = {}
	for id in GameCatalog.data().actions:
		var act = GameCatalog.action(id)
		names[id] = "%s · %s" % [act.name, ("+%d만" % act.income) if act.get("income",0) > 0 else "%d만" % act.cost]
	for i in 4:
		var week_index: int = i
		var week = card(content)
		week.add_child(label("WEEK 0%d" % (i+1), 14, LIME))
		for slot in ["main", "aux", "life"]:
			var slot_key: String = slot
			var slot_row = row(week)
			var caption = label({"main":"주요", "aux":"보조", "life":"생활"}[slot], 15, MUTED)
			caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			caption.custom_minimum_size.x = 42
			slot_row.add_child(caption)
			var ids = GameCatalog.data().life_ids if slot == "life" else GameCatalog.data().main_ids
			var choice = select(slot_row, ids, names, state.schedule[i][slot], func(id):
				var next = state.duplicate(true)
				next.schedule[week_index][slot_key] = id
				if commit(next): update_forecast())
			choice.set_meta("week", i)
			choice.set_meta("slot", slot)
	var preview = card(content, Color("202b24"))
	preview.add_child(label("월말 예상 · 현재 일정 기준", 15, LIME))
	forecast = label("", 17)
	preview.add_child(forecast)
	update_forecast()
	button(content, "이 일정으로 한 달 진행  →", month_clicked, true, "advance")
	button(content, "훈련별 성장·피로 안내", show_action_guide, false, "guide")
	content.add_child(label("표시 비용은 주요 기준입니다. 보조 비용은 55%를 올림합니다.\n매주 자연 회복 -8 · 월말 생활비 28만 + 체육관비 8만", 14, MUTED))

func update_forecast() -> void:
	var preview = Career.month(state)
	if preview.ok:
		forecast.text = "현금 %d만원 (%+d만) · 피로 %d\n%s" % [preview.report.cash, preview.report.cash_delta, roundi(preview.report.fatigue), " · ".join(preview.report.gains)]
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
		show_modal("일정을 조정해 주세요", result.error)
		return
	var report = result.report
	show_modal("한 달을 진행할까요?", "4주의 행동을 순서대로 실행합니다.\n\n예상 현금: %d만원 (%+d만)\n예상 피로: %d\n월말 고정비: %d만원\n\n%s" % [report.cash,report.cash_delta,roundi(report.fatigue),report.fixed_cost," · ".join(report.gains)], func():
		if commit(result.state):
			show_screen("home")
			show_month_report(report), "한 달 진행")

func show_month_report(report: Dictionary) -> void:
	show_modal("%d개월 차 훈련 완료" % report.month, "%s\n\n성장\n%s\n\n현금 %+d만원 → %d만원\n피로 %d · 고정비 %d만원" % ["\n\n".join(report.logs), " · ".join(report.gains), report.cash_delta, report.cash, roundi(report.fatigue), report.fixed_cost])

func build_fight() -> void:
	var a: Dictionary = state.current_athlete
	var opponent = Career.opponent(state)
	section_title("FIGHT NIGHT  /  ROOKIE SERIES", "다음 상대를 분석하세요", "가상 국내 프로 경기 · 3라운드 × 5분 자동 시뮬레이션")
	var match_card = card(content)
	match_card.add_child(label("%s  VS  %s" % [a.name,opponent.name], 25))
	match_card.add_child(label(GameCatalog.data().style_names[opponent.style] + " · " + opponent.tag, 16, ORANGE))
	var values: Array = []
	for k in opponent.stats: values.append("%s %.0f" % [GameCatalog.data().stat_names[k],opponent.stats[k]])
	match_card.add_child(label("상대 능력\n" + " · ".join(values), 17, MUTED))
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
	check.custom_minimum_size.y = 48
	controls.add_child(check)
	var seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 2147483647
	seed_box.value = state.settings.seed
	seed_box.custom_minimum_size.y = 48
	seed_box.editable = state.settings.fixed_seed
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
	start.disabled = wait > 0

func fight_clicked() -> void:
	var match_seed: int = int(state.settings.seed) if state.settings.fixed_seed else int(randi() & 0x7fffffff)
	var result = Career.fight(state, state.settings.strategy, match_seed)
	if not result.ok:
		show_modal("출전할 수 없습니다", result.error)
		return
	show_modal("경기에 출전할까요?", "%s와 3라운드 경기를 진행합니다.\n전략: %s\n피로: %d · 컨디션: %d%%\n\n경기 결과·수당·전적은 자동 저장됩니다.\n시드: %d" % [Career.opponent(state).name,GameCatalog.data().strategy_names[state.settings.strategy],roundi(state.current_athlete.fatigue),Career.condition(state.current_athlete),match_seed], func():
		if commit(result.state):
			show_screen("records")
			show_fight_report(result.result), "경기 시작")

func show_fight_report(result: Dictionary) -> void:
	var outcome = {"player":"승리", "opponent":"패배", "draw":"무승부"}[result.winner]
	var score_text = "판정 점수 %d : %d" % [result.scores[0],result.scores[1]] if result.method == "판정" else "R%d %d:%02d 종료" % [result.round,int(result.second)/60,int(result.second)%60]
	show_modal("%s · %s" % [outcome,result.method], "상대 %s\n%s\n수당 +%d만원 · 경기 후 피로 +24\n전략 %s · 시드 %d\n\n%s" % [result.opponent,score_text,result.reward,GameCatalog.data().strategy_names[result.strategy],result.seed,"\n".join(result.logs)])

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
		if is_instance_valid(modal):
			modal.queue_free()
			modal = null
		elif not state.is_empty(): show_screen("home")
