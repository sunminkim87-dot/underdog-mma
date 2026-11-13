class_name Bout
extends RefCounted

# Deterministic 3 x 5 minute MMA model: twelve 25-second exchanges per round.
# No UI, filesystem, global RNG, or modifications of supplied athletes.
static func simulate(player: Dictionary, opponent: Dictionary, strategy: String, match_seed: int) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = match_seed
	var fighters: Array = [Progression.combat_profile(player), Progression.combat_profile(opponent)]
	var tactics: Array = [strategy, {"striker":"striking", "wrestler":"wrestling", "grappler":"submission"}[opponent.style]]
	var hp: Array = [100.0, 100.0]
	var energy: Array = [100.0 - player.fatigue * 0.5, 100.0 - opponent.fatigue * 0.5]
	var condition: Array = [1.0 - player.fatigue * 0.0035, 1.0 - opponent.fatigue * 0.0035]
	var logs: Array = []
	var rounds: Array = []
	var totals: Array = [0, 0]
	var position: String = "standing"
	var controller: int = -1
	var finish: String = "판정"
	var winner: String = "draw"
	var end_round: int = 3
	var end_second: int = 300
	for r in range(1, 4):
		var points: Array = [0.0, 0.0]
		position = "standing"
		controller = -1
		logs.append("── ROUND %d ──" % r)
		for turn in 12:
			var active: int = rng.randi_range(0, 1)
			var defend: int = 1 - active
			var s: Dictionary = fighters[active].stats
			var ds: Dictionary = fighters[defend].stats
			var tactic: String = tactics[active]
			var readiness: float = condition[active] * (0.48 + energy[active] * 0.0052) * (0.9 + float(s.mental) * 0.002)
			var defense: float = condition[defend] * (0.48 + energy[defend] * 0.0052) * (0.9 + float(ds.mental) * 0.002)
			var label: String = str(fighters[active].name)
			var message: String = ""
			var damage: float = 0.0
			if position == "standing" and rng.randf() < (0.5 if tactic in ["wrestling", "submission"] else 0.19):
				position = "clinch"
				message = "%s, 거리를 좁혀 클린치." % label
			elif position == "clinch":
				var chance: float = clampf(0.5 + (s.wrestling * readiness - (ds.wrestling * 0.65 + ds.speed * 0.35) * defense) / 100.0, 0.1, 0.85)
				if tactic == "wrestling": chance += 0.08
				if rng.randf() < chance:
					position = "ground"
					controller = active
					points[active] += 3
					message = "%s, 테이크다운 성공! 그라운드 상위." % label
				else:
					position = "standing"
					message = "%s의 테이크다운 방어됨. 스탠딩 복귀." % label
			elif position == "ground":
				if active != controller:
					if rng.randf() < clampf(0.25 + (s.grappling * readiness - ds.grappling * defense) / 120.0, 0.08, 0.65):
						position = "standing"
						controller = -1
						points[active] += 1
						message = "%s, 포지션 탈출 후 일어납니다." % label
					else:
						points[defend] += 1.8
						message = "%s, 하위에서 방어. 상대가 포지션 유지." % label
				else:
					var sub_chance: float = clampf(0.035 + (s.grappling * readiness - ds.grappling * defense) / 650.0 + (0.045 if tactic == "submission" else 0.0), 0.01, 0.23)
					if rng.randf() < sub_chance:
						finish = "서브미션"
						winner = "player" if active == 0 else "opponent"
						message = "%s, 서브미션! 탭을 받아냅니다." % label
					else:
						damage = (4.0 + s.power * 0.075) * readiness * rng.randf_range(0.7, 1.3)
						points[active] += 2.5
						message = "%s, 상위 컨트롤과 파운딩." % label
			else:
				var hit_chance: float = clampf(0.55 + (s.striking * readiness - (ds.striking * 0.5 + ds.speed * 0.5) * defense) / 140.0, 0.18, 0.87)
				if tactic == "counter": hit_chance += 0.06
				if rng.randf() < hit_chance:
					damage = (5.0 + s.power * 0.1) * readiness * rng.randf_range(0.7, 1.4)
					if tactic == "striking": damage *= 1.2
					points[active] += damage * 0.5
					message = "%s, 유효 타격 적중." % label
				else: message = "%s의 타격, 거리 조절로 회피." % label
			hp[defend] = maxf(0, hp[defend] - damage)
			energy[active] = maxf(0, energy[active] - (5.5 if tactic == "striking" else 4.2) + float(s.endurance) * 0.025)
			energy[defend] = maxf(0, energy[defend] - 1.4)
			if finish == "판정" and damage > 0 and (hp[defend] <= 0 or (hp[defend] < 32 and rng.randf() < 0.13)):
				finish = "KO/TKO"
				winner = "player" if active == 0 else "opponent"
				message += " 심판이 경기를 중단합니다!"
			var seconds: int = (turn + 1) * 25
			logs.append("R%d %d:%02d | %s" % [r, seconds / 60, seconds % 60, message])
			if finish != "판정":
				end_round = r
				end_second = seconds
				break
		var score: Array = [10, 10]
		if absf(points[0] - points[1]) > 1:
			score[1 if points[0] > points[1] else 0] = 8 if absf(points[0]-points[1]) > 20 else 9
		if finish == "판정":
			totals[0] += score[0]
			totals[1] += score[1]
		rounds.append({"round":r, "points":points, "score":score, "hp":hp.duplicate(), "energy":energy.duplicate(), "completed":finish == "판정"})
		if finish != "판정": break
		logs.append("R%d 채점 %d : %d" % [r, score[0], score[1]])
		for i in 2:
			energy[i] = minf(100, energy[i] + 10 + float(fighters[i].stats.endurance) * 0.1)
	if finish == "판정":
		winner = "player" if totals[0] > totals[1] else ("opponent" if totals[1] > totals[0] else "draw")
	return {"seed":match_seed, "strategy":strategy, "winner":winner, "method":finish,
		"round":end_round, "second":end_second, "rounds":rounds, "scores":totals, "logs":logs,
		"player_id":player.athlete_id, "opponent_id":opponent.athlete_id,
		"player_snapshot":snapshot(player), "opponent_snapshot":snapshot(opponent),"combat_bonuses":[fighters[0].combat_bonuses,fighters[1].combat_bonuses]}

static func snapshot(athlete: Dictionary) -> Dictionary:
	return {"athlete_id":athlete.athlete_id,"name":athlete.name,"style":athlete.style,"stats":athlete.stats.duplicate(true),"fatigue":athlete.fatigue,"equipment":athlete.get("equipment",{}).duplicate(true),"skills":athlete.get("skills",[]).duplicate(true)}
