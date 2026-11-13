class_name MonthPlayback
extends Control
signal finished
var report: Dictionary
var timeline: Array = []
var index: int = -1
var elapsed: float = 0
var speed: float = 1
var done: bool = false
var ui: Control
var world: ActivityScene
var title_label: Label
var slot_label: Label
var effect_label: Label
var gain_label: Label
var energy_bar: ProgressBar
var fatigue_bar: ProgressBar
var energy_text: Label
var fatigue_text: Label
var progress_bar: ProgressBar
var week_labels: Array = []
var source_appearance: int = 0
var fast_button: Button
var npc_portrait: NpcPortrait

func setup(owner_ui: Control, month_report: Dictionary, color: int) -> void:
	ui = owner_ui
	report = month_report
	timeline = report.get("timeline",[])
	source_appearance = color
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60
	var background = ColorRect.new()
	background.color = Color("0c1724")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["top","bottom","left","right"]: margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var root = ui.stack(margin,14)
	root.add_child(ui.label("MONTH %02d  ·  월간 육성" % int(report.month),15,ui.LIME))
	var weeks = ui.row(root)
	for i in 4:
		var item = ui.label("%d주" % (i+1),18,ui.MUTED)
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weeks.add_child(item)
		week_labels.append(item)
	progress_bar = ui.meter_bar(root,0,ui.LIME,7)
	world = ActivityScene.new()
	world.custom_minimum_size.y = 270
	root.add_child(world)
	npc_portrait=NpcPortrait.new()
	npc_portrait.custom_minimum_size=Vector2(95,95)
	npc_portrait.size=Vector2(95,130)
	npc_portrait.position=Vector2(8,8)
	npc_portrait.visible=false
	world.add_child(npc_portrait)
	slot_label = ui.label("",15,ui.MUTED)
	root.add_child(slot_label)
	title_label = ui.label("",28)
	root.add_child(title_label)
	effect_label = ui.label("",25,ui.GREEN)
	root.add_child(effect_label)
	gain_label = ui.label("",18,ui.BLUE)
	gain_label.custom_minimum_size.y = 62
	root.add_child(gain_label)
	var meters = ui.card(root)
	energy_text = ui.label("",17,ui.GREEN)
	meters.add_child(energy_text)
	energy_bar = ui.meter_bar(meters,0,ui.GREEN,15)
	fatigue_text = ui.label("",17,ui.ORANGE)
	meters.add_child(fatigue_text)
	fatigue_bar = ui.meter_bar(meters,0,ui.ORANGE,12)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	root.add_child(ui.label("한 달의 결과는 저장되었습니다. 연출을 건너뛰어도 성장·수당은 중복 지급되지 않습니다.",13,ui.MUTED))
	var controls = ui.row(root)
	fast_button = ui.button(controls,"속도 ×1",func():
		speed = 2 if speed == 1 else 1
		fast_button.text = "속도 ×%d" % int(speed),false,"playback_speed")
	ui.button(controls,"결과 바로 보기",finish,true,"playback_skip")
	advance()

func advance() -> void:
	index += 1
	elapsed = 0
	if index >= timeline.size():
		finish()
		return
	var event: Dictionary = timeline[index]
	world.set_action(event.scene_id,source_appearance)
	npc_portrait.visible=false
	if event.action_id in ["social","date"]:
		var npc: String=ui.state.current_athlete.partner_id if event.action_id=="date" else ui.state.current_athlete.focus_npc
		if npc in GameCatalog.extra().npcs:
			npc_portrait.npc_id=npc
			npc_portrait.visible=true
			npc_portrait.queue_redraw()
	title_label.text = event.name
	slot_label.text = "%d주차  ·  %s  ·  %d / %d" % [event.week,{"main":"주요 훈련","aux":"보조 훈련","life":"생활","recovery":"주간 마무리"}[event.slot],index+1,timeline.size()]
	for i in 4: week_labels[i].add_theme_color_override("font_color",ui.LIME if i+1 == event.week else ui.MUTED)
	var diff: float = float(event.fatigue_after)-float(event.fatigue_before)
	if event.potential_recovery > 0:
		effect_label.text = "체력 +%.2f  ·  %.2f → %.2f" % [event.recovered,100-event.fatigue_before,100-event.fatigue_after]
		effect_label.add_theme_color_override("font_color",ui.GREEN)
	else:
		effect_label.text = "체력 -%.2f  ·  %.2f → %.2f" % [diff,100-event.fatigue_before,100-event.fatigue_after]
		effect_label.add_theme_color_override("font_color",ui.ORANGE)
	var effects: Array = event.get("notes",[]).duplicate()
	for stat in event.gains: effects.append("%s +%.1f" % [GameCatalog.data().stat_names[stat],event.gains[stat]])
	var cash_delta: int = int(event.cash_after-event.cash_before)
	if cash_delta != 0: effects.append("현금 %+d만원" % cash_delta)
	if event.potential_recovery > event.recovered+.05: effects.append("최대 %.2f 회복 · 남은 피로만큼 적용" % event.potential_recovery)
	gain_label.text = "  ·  ".join(effects) if not effects.is_empty() else "몸을 돌보는 것도 훈련의 일부입니다."

func _process(delta: float) -> void:
	if done or index < 0 or index >= timeline.size(): return
	elapsed += delta*speed
	var event: Dictionary = timeline[index]
	var duration: float = 0.85 if event.slot == "recovery" else 1.8
	var ratio: float = clampf(elapsed/duration,0,1)
	var shown: float = lerpf(event.fatigue_before,event.fatigue_after,ratio)
	energy_bar.value = 100-shown
	fatigue_bar.value = shown
	energy_text.text = "체력  %.1f / 100" % (100-shown)
	fatigue_text.text = "피로  %.1f / 100" % shown
	progress_bar.value = 100*(index+ratio)/maxi(timeline.size(),1)
	if ratio >= 1: advance()

func finish() -> void:
	if done: return
	done = true
	finished.emit()
	queue_free()
