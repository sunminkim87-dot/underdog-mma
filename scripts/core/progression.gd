class_name Progression
extends RefCounted

# Additive v1-save migration. Call only on newly constructed or privately copied state.
# Never rewrite an existing athlete's learned stats, cash, ID or record.
static func initialize(state: Dictionary) -> void:
	if not state.get("current_athlete") is Dictionary: return
	var a: Dictionary = state.current_athlete
	var defaults = {"inventory":{},"equipment":{"gloves":"","trunks":"","mouthguard":"","shoes":""},"skills":[],"unlocks":[],"relationships":{},"partner_id":"","focus_npc":"","event_flags":[],"event_history":[],"event_cooldowns":{},"pending_event":"","last_event_month":-1,"last_skill_event_month":-10,"consumable_month":int(a.get("months",0)),"consumables_used":0,"last_awards":[]}
	for key in defaults:
		if not a.has(key): a[key] = defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	if a.get("equipment") is Dictionary:
		for slot in ["gloves","trunks","mouthguard","shoes"]:
			if not a.equipment.has(slot):a.equipment[slot]=""
	if not a.has("background_base"): a.background_base = {"striker":"boxing","wrestler":"wrestling","grappler":"bjj"}.get(a.get("style","striker"),"boxing")
	if not a.has("training_counts"):
		a.training_counts = {}
		for report in a.get("month_history",[]):
			for event in report.get("timeline",[]):
				var id: String = str(event.get("action_id",""))
				if not event.get("skipped",false) and id in GameCatalog.data().main_ids and id != "rest": a.training_counts[id] = int(a.training_counts.get(id,0))+1
	if not a.has("job_count"):
		a.job_count = 0
		for report in a.get("month_history",[]):
			for event in report.get("timeline",[]):
				var id: String = str(event.get("action_id",""))
				if not event.get("skipped",false) and id in GameCatalog.data().actions and int(GameCatalog.action(id).get("income",0))>0: a.job_count += 1

static func action_available(state: Dictionary, id: String) -> Dictionary:
	if not id in GameCatalog.data().actions: return {"ok":false,"reason":"알 수 없는 행동입니다."}
	var a: Dictionary = state.current_athlete
	var requirements: Dictionary = GameCatalog.action(id).get("requirements",{})
	if requirements.has("unlock") and not requirements.unlock in a.get("unlocks",[]): return {"ok":false,"reason":"감독의 지도 제안 이벤트로 해금" if id=="coach_job" else "행사 담당자 이벤트로 해금"}
	if requirements.get("met_friend",false) and a.get("focus_npc","").is_empty(): return {"ok":false,"reason":"인연 이벤트에서 친구를 만나 주세요."}
	if requirements.get("partner",false) and a.get("partner_id","").is_empty(): return {"ok":false,"reason":"연인 관계가 된 뒤 선택할 수 있습니다."}
	return {"ok":true}

static func schedule_reason(state: Dictionary, schedule: Array) -> String:
	for week in schedule:
		for slot in ["main","aux","life"]:
			var available = action_available(state,week[slot])
			if not available.ok: return str(GameCatalog.action(week[slot]).name)+": "+str(available.reason)
	return ""

static func on_action(state: Dictionary, id: String) -> Array:
	var a: Dictionary = state.current_athlete
	var action: Dictionary = GameCatalog.action(id)
	var notes: Array = []
	if action.kind=="training" and id!="rest": a.training_counts[id] = int(a.training_counts.get(id,0))+1
	if int(action.get("income",0))>0: a.job_count += 1
	if id in ["social","date"]:
		var npc: String = a.partner_id if id=="date" else a.focus_npc
		if npc in a.relationships and a.relationships[npc].get("met",false):
			var relation: Dictionary = a.relationships[npc]
			var before: int = int(relation.affinity)
			relation.affinity = mini(100,before+int(action.affinity))
			notes.append("%s 친밀도 +%d" % [GameCatalog.extra().npcs[npc].name,int(relation.affinity)-before])
	return notes

static func conditions_met(state: Dictionary, condition: Dictionary) -> bool:
	var a: Dictionary = state.current_athlete
	if a.months < int(condition.get("month",0)) or a.wins < int(condition.get("wins",0)): return false
	if int(a.wins+a.losses+a.draws)<int(condition.get("bouts",0)): return false
	if int(a.get("job_count",0))<int(condition.get("job_count",0)): return false
	if a.get("skills",[]).size()<int(condition.get("skills",0)): return false
	for id in condition.get("action_count",{}):
		if int(a.get("training_counts",{}).get(id,0))<int(condition.action_count[id]): return false
	var friends: int = 0
	for id in a.get("relationships",{}):
		if a.relationships[id].get("met",false): friends += 1
	if friends<int(condition.get("friends",0)): return false
	for id in condition.get("affinity",{}):
		if not a.get("relationships",{}).get(id,{}).get("met",false) or int(a.relationships[id].affinity)<int(condition.affinity[id]): return false
	if condition.get("no_partner",false) and not a.get("partner_id","").is_empty(): return false
	return true

static func achievements(state: Dictionary) -> Array:
	var a: Dictionary = state.current_athlete
	var earned: Array = []
	for id in GameCatalog.extra().achievements:
		if id in state.achievements: continue
		var definition: Dictionary = GameCatalog.extra().achievements[id]
		if conditions_met(state,definition.condition):
			state.achievements.append(id)
			var item: String = definition.reward_item
			a.inventory[item] = mini(99,int(a.inventory.get(item,0))+1)
			earned.append(id)
	a.last_awards = earned
	return earned

# One significant event per month; learning events are spaced by at least three months.
static func evaluate(state: Dictionary) -> void:
	initialize(state)
	var a: Dictionary = state.current_athlete
	achievements(state)
	if a.get("retired",false) or not a.pending_event.is_empty() or int(a.last_event_month)==int(a.months): return
	var order: Array = GameCatalog.extra().events.keys()
	var signature = "learn_"+str(a.background_base)
	if signature in order:
		order.erase(signature)
		order.push_front(signature)
	# Qualifying coaching work is a career event, independent from retirement coaching.
	order.erase("coach_offer")
	order.push_front("coach_offer")
	for id in order:
		if id in a.event_flags: continue
		if int(a.event_cooldowns.get(id,-1))>int(a.months): continue
		if str(id).begins_with("learn_") and int(a.months)-int(a.last_skill_event_month)<3: continue
		if not conditions_met(state,GameCatalog.extra().events[id].conditions): continue
		a.pending_event = id
		a.last_event_month = int(a.months)
		return

static func pending_reason(state: Dictionary) -> String:
	if not state.current_athlete.get("pending_event","").is_empty(): return "기다리는 이벤트의 선택을 먼저 마쳐 주세요. 인연·기술 화면에서 다시 열 수 있습니다."
	return ""

static func choice_reason(state: Dictionary, effects: Dictionary) -> String:
	if int(state.current_athlete.cash)<int(effects.get("cost",0)): return "현금이 부족합니다. 다음에 배우기를 선택할 수 있습니다."
	if effects.has("partner") and not state.current_athlete.partner_id.is_empty(): return "현재 연인이 있습니다."
	return ""

static func choose(state: Dictionary, event_id: String, choice_id: String) -> Dictionary:
	var a: Dictionary = state.current_athlete
	if a.get("pending_event","")!=event_id or not event_id in GameCatalog.extra().events: return {"ok":false,"error":"현재 기다리는 이벤트가 아닙니다."}
	var selected: Dictionary = {}
	for option in GameCatalog.extra().events[event_id].choices:
		if option.id==choice_id: selected=option.effects
	if selected.is_empty(): return {"ok":false,"error":"유효하지 않은 선택입니다."}
	var blocked = choice_reason(state,selected)
	if not blocked.is_empty(): return {"ok":false,"error":blocked}
	var next = state.duplicate(true)
	initialize(next)
	var n: Dictionary = next.current_athlete
	n.cash -= int(selected.get("cost",0))
	n.fatigue = clampf(float(n.fatigue)+float(selected.get("fatigue",0)),0,100)
	if selected.has("unlock") and not selected.unlock in n.unlocks: n.unlocks.append(selected.unlock)
	if selected.has("skill") and not selected.skill in n.skills: n.skills.append(selected.skill)
	if selected.has("meet"):
		n.relationships[selected.meet] = {"met":true,"affinity":int(selected.get("affinity",5)),"stage":"friend"}
		if n.focus_npc.is_empty(): n.focus_npc=selected.meet
	if selected.has("partner"):
		n.partner_id=selected.partner
		n.focus_npc=selected.partner
		n.relationships[selected.partner].stage="dating"
	if selected.has("friend_only"): n.relationships[selected.friend_only].stage="friend"
	if selected.get("defer",false): n.event_cooldowns[event_id]=int(n.months)+1
	else: n.event_flags.append(event_id)
	if event_id.begins_with("learn_"): n.last_skill_event_month=int(n.months)
	n.event_history.append({"event_id":event_id,"choice_id":choice_id,"month":n.months})
	if n.event_history.size()>120:n.event_history.pop_front()
	n.pending_event=""
	var earned=achievements(next)
	return {"ok":true,"state":next,"awards":earned,"notice":"선택이 기록되었습니다."}

static func focus(state: Dictionary, npc: String) -> Dictionary:
	var a: Dictionary = state.current_athlete
	if not npc in GameCatalog.extra().npcs or not a.relationships.get(npc,{}).get("met",false): return {"ok":false,"error":"아직 만나지 않은 인연입니다."}
	var next=state.duplicate(true)
	next.current_athlete.focus_npc=npc
	return {"ok":true,"state":next,"notice":"친구 만나기의 상대를 선택했습니다."}

static func buy(state: Dictionary, item: String) -> Dictionary:
	if not item in GameCatalog.extra().items:return {"ok":false,"error":"등록되지 않은 물품입니다."}
	var a: Dictionary=state.current_athlete
	var definition: Dictionary=GameCatalog.extra().items[item]
	if a.get("retired",false):return {"ok":false,"error":"새 선수를 시작한 뒤 구매할 수 있습니다."}
	if int(a.cash)<int(definition.price):return {"ok":false,"error":"게임 내 현금이 부족합니다."}
	if int(a.inventory.get(item,0)) >= (1 if definition.kind=="equipment" else 99):return {"ok":false,"error":"이미 보유했거나 보관 한도에 도달했습니다."}
	var next=state.duplicate(true)
	var n: Dictionary=next.current_athlete
	n.cash-=int(definition.price)
	n.inventory[item]=int(n.inventory.get(item,0))+1
	var equipped: bool=false
	if definition.kind=="equipment" and n.equipment.get(definition.slot,"").is_empty():
		n.equipment[definition.slot]=item
		equipped=true
	return {"ok":true,"state":next,"notice":"%s 구매%s" % [definition.name," · 착용 완료" if equipped else " 완료"]}

static func equip(state: Dictionary,item: String) -> Dictionary:
	if not item in GameCatalog.extra().items or GameCatalog.extra().items[item].kind!="equipment":return {"ok":false,"error":"장비를 선택해 주세요."}
	if state.current_athlete.get("retired",false):return {"ok":false,"error":"은퇴한 선수입니다."}
	if int(state.current_athlete.inventory.get(item,0))<1:return {"ok":false,"error":"보유하지 않은 장비입니다."}
	var next=state.duplicate(true)
	var slot: String=GameCatalog.extra().items[item].slot
	next.current_athlete.equipment[slot]="" if next.current_athlete.equipment.get(slot,"")==item else item
	return {"ok":true,"state":next,"notice":"장비 착용 상태를 바꿨습니다."}

static func use_item(state: Dictionary,item: String) -> Dictionary:
	if not item in GameCatalog.extra().items or GameCatalog.extra().items[item].kind!="consumable":return {"ok":false,"error":"회복 물품을 선택해 주세요."}
	var a: Dictionary=state.current_athlete
	if a.get("retired",false):return {"ok":false,"error":"은퇴한 선수입니다."}
	if int(a.inventory.get(item,0))<1:return {"ok":false,"error":"보유 수량이 없습니다."}
	if a.fatigue<=0:return {"ok":false,"error":"체력이 충분해 회복 물품을 사용하지 않았습니다."}
	var used: int=int(a.consumables_used) if int(a.consumable_month)==int(a.months) else 0
	if used>=int(GameCatalog.extra().consumables_per_month):return {"ok":false,"error":"이번 달 회복 물품 사용 한도 3회에 도달했습니다."}
	var next=state.duplicate(true)
	var n: Dictionary=next.current_athlete
	var recovered: float=minf(float(a.fatigue),float(GameCatalog.extra().items[item].recovery))
	n.fatigue=maxf(0,float(n.fatigue)-recovered)
	n.inventory[item]-=1
	n.consumable_month=int(a.months)
	n.consumables_used=used+1
	return {"ok":true,"state":next,"recovery":recovered,"fatigue_before":a.fatigue,"fatigue_after":n.fatigue,"notice":"체력 +%.2f 회복" % recovered}

static func combat_profile(athlete: Dictionary) -> Dictionary:
	var profile=athlete.duplicate(true)
	var bonuses: Dictionary={}
	for item in athlete.get("equipment",{}).values():
		if not item in GameCatalog.extra().items:continue
		for stat in GameCatalog.extra().items[item].get("combat",{}):bonuses[stat]=float(bonuses.get(stat,0))+float(GameCatalog.extra().items[item].combat[stat])
	for skill in athlete.get("skills",[]):
		if not skill in GameCatalog.extra().skills:continue
		for stat in GameCatalog.extra().skills[skill].combat:bonuses[stat]=float(bonuses.get(stat,0))+float(GameCatalog.extra().skills[skill].combat[stat])
	var actual: Dictionary={}
	for stat in bonuses:
		profile.stats[stat]=minf(100,float(profile.stats[stat])+minf(float(GameCatalog.extra().combat_bonus_cap),bonuses[stat]))
		actual[stat]=profile.stats[stat]-float(athlete.stats[stat])
	profile.combat_bonuses=actual
	return profile

static func valid_extension(a: Dictionary) -> bool:
	if a.has("background_base") and (not a.background_base is String or not a.background_base in GameCatalog.data().bases):return false
	for key in ["inventory","equipment","relationships","training_counts","event_cooldowns"]:
		if a.has(key) and not a[key] is Dictionary:return false
	for key in ["skills","unlocks","event_flags","event_history","last_awards"]:
		if a.has(key) and not a[key] is Array:return false
	for id in a.get("inventory",{}):
		if not id in GameCatalog.extra().items or not whole(a.inventory[id],0,99):return false
	for slot in a.get("equipment",{}):
		if not slot in ["gloves","trunks","mouthguard","shoes"]:return false
		var id=a.equipment[slot]
		if not id is String:return false
		if not id.is_empty() and (not id in GameCatalog.extra().items or GameCatalog.extra().items[id].get("slot","")!=slot or int(a.get("inventory",{}).get(id,0))<1):return false
	var seen: Dictionary={}
	for id in a.get("skills",[]):
		if not id is String or not id in GameCatalog.extra().skills or seen.has(id):return false
		seen[id]=true
	for id in a.get("unlocks",[]):
		if not id is String or not id in ["coach_job","event_work"]:return false
	for id in a.get("relationships",{}):
		if not id in GameCatalog.extra().npcs or not a.relationships[id] is Dictionary:return false
		var relation: Dictionary=a.relationships[id]
		if not relation.get("met") is bool or not whole(relation.get("affinity"),0,100) or not relation.get("stage") in ["friend","dating"]:return false
	for key in ["partner_id","focus_npc"]:
		if a.has(key):
			if not a[key] is String:return false
			if not a[key].is_empty() and not a.get("relationships",{}).get(a[key],{}).get("met",false):return false
	if not a.get("partner_id","").is_empty() and a.relationships[a.partner_id].stage!="dating":return false
	for id in a.get("training_counts",{}):
		if not id in GameCatalog.data().main_ids or not whole(a.training_counts[id],0,1000000000):return false
	for key in ["job_count","consumable_month","consumables_used"]:
		if a.has(key) and not whole(a[key],0,1000000000):return false
	if a.has("consumables_used") and int(a.consumables_used)>3:return false
	for key in ["last_event_month","last_skill_event_month"]:
		if a.has(key) and not whole(a[key],-10,int(a.months)):return false
	if a.has("pending_event") and (not a.pending_event is String or (not a.pending_event.is_empty() and not a.pending_event in GameCatalog.extra().events)):return false
	for id in a.get("event_flags",[]):
		if not id is String or not id in GameCatalog.extra().events:return false
	for id in a.get("event_cooldowns",{}):
		if not id in GameCatalog.extra().events or not whole(a.event_cooldowns[id],0,1000000000):return false
	for event in a.get("event_history",[]):
		if not event is Dictionary or not event.get("event_id") is String or not event.event_id in GameCatalog.extra().events or not event.get("choice_id") is String or not whole(event.get("month"),0,int(a.months)):return false
	for id in a.get("last_awards",[]):
		if not id is String or not id in GameCatalog.extra().achievements:return false
	return true

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and float(value)==floorf(float(value))

static func end_relationship(state: Dictionary) -> Dictionary:
	if state.current_athlete.partner_id.is_empty():return {"ok":false,"error":"현재 연인 관계가 없습니다."}
	var next=state.duplicate(true)
	var a: Dictionary=next.current_athlete
	a.relationships[a.partner_id].stage="friend"
	a.partner_id=""
	return {"ok":true,"state":next,"notice":"서로의 선택을 존중하며 친구로 지내기로 했습니다."}
