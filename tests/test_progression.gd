extends SceneTree
var checks: int=0
var failures: Array=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		print("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func fresh(base: String="boxing") -> Dictionary:return Career.create_from_base("새 선수",base)
func run() -> void:
	create_timer(20).timeout.connect(func():print("FAIL: progression test timeout");quit(2))
	for base in GameCatalog.data().bases:
		var state=fresh(base)
		var total: float=0
		for value in state.current_athlete.stats.values():total+=value
		check(total==184,"fixed 184 point budget: "+base)
		check(SaveStore.valid(state),"base save schema: "+base)
	check(fresh("judo").current_athlete.stats.power>fresh("bjj").current_athlete.stats.power,"judo power advantage")
	check(fresh("bjj").current_athlete.stats.grappling>fresh("judo").current_athlete.stats.grappling,"bjj technical advantage")
	check(GameCatalog.action("judo").icon!=GameCatalog.action("bjj").icon and GameCatalog.action("wrestling").icon!=GameCatalog.action("judo").icon,"three distinct sport icons")
	var original=fresh()
	check(not Progression.action_available(original,"coach_job").ok,"coach work locked before event")
	check(not Progression.action_available(original,"event_work").ok,"event staff locked before contact")
	var locked=original.duplicate(true)
	locked.schedule[0].life="coach_job"
	check(not Career.month(locked).ok,"locked work cannot bypass schedule")
	var month=Career.month(original)
	check(month.ok and month.report.achievements.has("first_month"),"first month achievement")
	var state: Dictionary=month.state
	Progression.evaluate(state)
	check(state.current_athlete.pending_event=="meet_jisoo","first NPC event is queued")
	check(not Career.month(state).ok,"unresolved event blocks time advance")
	check(not Progression.choose(state,"meet_harin","hello").ok,"cannot claim an unoffered event")
	var met=Progression.choose(state,"meet_jisoo","hello")
	check(met.ok and met.state.current_athlete.relationships.jisoo.met,"event creates a real friend")
	check(not Progression.choose(met.state,"meet_jisoo","hello").ok,"event cannot pay twice")
	check(met.state.achievements.has("first_friend"),"friend achievement")
	var count: int=int(met.state.current_athlete.inventory.sports_drink)
	Progression.evaluate(met.state)
	Progression.evaluate(met.state)
	check(int(met.state.current_athlete.inventory.sports_drink)==count,"achievement rewards issued once")
	check(Progression.action_available(met.state,"social").ok,"social activity unlocks after meeting")
	check(not Progression.action_available(original,"social").ok,"cannot socialize with an unmet NPC")
	var dating=met.state.duplicate(true)
	dating.current_athlete.months=2
	dating.current_athlete.relationships.jisoo.affinity=35
	Progression.evaluate(dating)
	check(dating.current_athlete.pending_event=="dating_jisoo","romance requires affinity and explicit event")
	var partner=Progression.choose(dating,"dating_jisoo","date")
	check(partner.ok and partner.state.current_athlete.partner_id=="jisoo","dating is an explicit saved choice")
	check(Progression.action_available(partner.state,"date").ok,"date action unlocks for partner")
	var just_friends=Progression.choose(dating,"dating_jisoo","friends")
	check(just_friends.ok and just_friends.state.current_athlete.partner_id.is_empty(),"friend-only path supported")
	var ended=Progression.end_relationship(partner.state)
	check(ended.ok and ended.state.current_athlete.partner_id.is_empty(),"relationship can return to friendship")
	var social=met.state.duplicate(true)
	social.current_athlete.cash=300
	for week in social.schedule:week.life="social"
	var social_month=Career.month(social)
	check(social_month.ok and social_month.state.current_athlete.relationships.jisoo.affinity==29,"life slots consume time and increase affinity")
	var buy=Progression.buy(original,"sports_drink")
	check(buy.ok and buy.state.current_athlete.cash==96 and buy.state.current_athlete.inventory.sports_drink==1,"game cash purchases actual inventory")
	check(original.current_athlete.cash==100 and original.current_athlete.inventory.is_empty(),"purchase never mutates input")
	var low=buy.state.duplicate(true)
	low.current_athlete.fatigue=3
	var used=Progression.use_item(low,"sports_drink")
	check(used.ok and used.recovery==3 and used.state.current_athlete.fatigue==0,"recovery clamps to remaining fatigue")
	check(used.state.current_athlete.inventory.sports_drink==0,"consumable quantity decremented")
	check(not Progression.use_item(buy.state,"sports_drink").ok,"full health does not waste a consumable")
	var supplies=original.duplicate(true)
	supplies.current_athlete.inventory.sports_drink=4
	supplies.current_athlete.fatigue=100
	for i in 3:supplies=Progression.use_item(supplies,"sports_drink").state
	check(not Progression.use_item(supplies,"sports_drink").ok,"monthly recovery item limit")
	var next_month=Career.month(supplies)
	check(next_month.ok and next_month.state.current_athlete.consumables_used==0,"item usage allowance resets next month")
	var gear=Progression.buy(original,"training_gloves")
	check(gear.ok and gear.state.current_athlete.equipment.gloves=="training_gloves","equipment purchase auto-equips empty slot")
	check(gear.state.current_athlete.stats==original.current_athlete.stats,"equipment never rewrites base stats")
	check(not Progression.buy(gear.state,"training_gloves").ok,"duplicate equipment purchase denied")
	var effective=Progression.combat_profile(gear.state.current_athlete)
	check(effective.stats.striking==original.current_athlete.stats.striking+3,"equipped gloves affect actual combat stats")
	var unequipped=Progression.equip(gear.state,"training_gloves")
	check(unequipped.ok and Progression.combat_profile(unequipped.state.current_athlete).stats.striking==original.current_athlete.stats.striking,"unequipping removes the combat effect")
	var poor=original.duplicate(true)
	poor.current_athlete.cash=0
	check(not Progression.buy(poor,"mouthguard").ok,"insufficient cash purchase denied")
	var trained=fresh("bjj")
	trained.current_athlete.months=3
	trained.current_athlete.wins=1
	trained.current_athlete.training_counts.bjj=3
	Progression.evaluate(trained)
	check(trained.current_athlete.pending_event=="learn_bjj","base technique offered after true training and match conditions")
	var technique=Progression.choose(trained,"learn_bjj","learn")
	check(technique.ok and technique.state.current_athlete.skills.has("tech_bjj"),"event teaches persistent skill")
	check(technique.state.current_athlete.cash==94 and technique.state.current_athlete.fatigue==4,"learning has an actual money and fatigue cost")
	check(Progression.combat_profile(technique.state.current_athlete).stats.grappling==trained.current_athlete.stats.grappling+4,"learned skill affects matches")
	trained.current_athlete.cash=1
	check(not Progression.choose(trained,"learn_bjj","learn").ok and Progression.choose(trained,"learn_bjj","later").ok,"broke athlete can defer learning without a deadlock")
	var coaching=fresh()
	coaching.current_athlete.months=6
	coaching.current_athlete.wins=1
	coaching.current_athlete.losses=1
	coaching.current_athlete.next_fight_month=9
	Progression.evaluate(coaching)
	check(coaching.current_athlete.pending_event=="coach_offer","coaching requires career and event")
	var coach=Progression.choose(coaching,"coach_offer","accept")
	check(coach.ok and Progression.action_available(coach.state,"coach_job").ok,"accepting event unlocks coaching work")
	for week in coach.state.schedule:week.life="coach_job"
	var coached=Career.month(coach.state)
	check(coached.ok and coached.report.cash_delta==76,"coaching work pays through actual weekly actions")
	var match_player=technique.state.current_athlete
	var opponent=Career.create("상대","wrestler").current_athlete
	var fight=Bout.simulate(match_player,opponent,"submission",318)
	check(fight.combat_bonuses[0].get("grappling",0)==4,"match stores the applied skill bonus")
	var replay=Bout.simulate(fight.player_snapshot,fight.opponent_snapshot,"submission",318)
	check(replay.logs==fight.logs,"skill/equipment snapshots reproduce the original match")
	var legacy=original.duplicate(true)
	legacy.current_athlete.stats.striking=61.5
	for key in ["inventory","equipment","skills","training_counts","background_base","pending_event"]:legacy.current_athlete.erase(key)
	var before_id=legacy.current_athlete.athlete_id
	Progression.initialize(legacy)
	check(legacy.current_athlete.stats.striking==61.5 and legacy.current_athlete.athlete_id==before_id,"old athlete migration preserves learned stats and identity")
	for candidate in [met.state,partner.state,social_month.state,coached.state,technique.state,gear.state,legacy]:check(SaveStore.valid(candidate),"extended save schema valid")
	var bad=original.duplicate(true)
	bad.current_athlete.skills=["tech_bjj","tech_bjj"]
	check(not SaveStore.valid(bad),"duplicate skill data rejected")
	bad=original.duplicate(true)
	bad.current_athlete.inventory.sports_drink=-1
	check(not SaveStore.valid(bad),"negative inventory rejected")
	bad=original.duplicate(true)
	bad.current_athlete.erase("months")
	check(not SaveStore.valid(bad),"missing calendar with progression fields is rejected without an exception")
	var output=FileAccess.open("res://tests/progression_results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	output.close()
	print("Progression checks: ",checks," failures: ",failures)
	quit(0 if failures.is_empty() else 1)
