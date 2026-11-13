class_name SaveStore
extends RefCounted

const DEFAULT_PATH = "user://career_v1.json"

static func numeric(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func whole(value: Variant, low: int, high: int) -> bool:
	return numeric(value, low, high) and float(value) == floorf(float(value))

static func valid(state: Variant) -> bool:
	if not state is Dictionary or not whole(state.get("save_version"),1,1): return false
	for key in ["current_athlete", "account_legacy", "gym_facilities", "settings"]:
		if not state.get(key) is Dictionary: return false
	for key in ["hall_of_fame", "coaches", "achievements", "schedule", "saved_preset"]:
		if not state.get(key) is Array: return false
	if not Career.validate_schedule(state.schedule) or not Career.validate_schedule(state.saved_preset): return false
	var a: Dictionary = state.current_athlete
	for key in ["name", "athlete_id", "style", "nationality"]:
		if not a.get(key) is String or a[key].is_empty(): return false
	if a.name.length() > 16 or not a.style in GameCatalog.data().style_names: return false
	for key in ["age", "months", "cash", "wins", "losses", "draws", "next_fight_month", "appearance"]:
		if not whole(a.get(key),0,1000000000): return false
	if a.appearance > 2 or a.age != 18 + int(a.months) / 12: return false
	if not numeric(a.get("fatigue"),0,100) or not a.get("stats") is Dictionary: return false
	for key in GameCatalog.data().stat_names:
		if not numeric(a.stats.get(key),1,100): return false
	if not a.get("fights") is Array or not a.get("month_history") is Array: return false
	if a.fights.size() > 120 or a.month_history.size() > 120: return false
	for f in a.fights:
		if not f is Dictionary: return false
		for k in ["opponent", "method", "winner", "strategy"]:
			if not f.get(k) is String: return false
		if not f.winner in ["player", "opponent", "draw"]: return false
		if not f.strategy in GameCatalog.data().strategy_names: return false
		for k in ["month", "round", "second", "reward", "seed"]:
			if not whole(f.get(k),0,9223372036854775807): return false
		for k in ["logs", "rounds", "scores"]:
			if not f.get(k) is Array: return false
		if f.scores.size() != 2: return false
		for v in f.scores:
			if not numeric(v,0,30): return false
		for line in f.logs:
			if not line is String: return false
	for report in a.month_history:
		if not report is Dictionary: return false
		for k in ["month", "cash", "fixed_cost"]:
			if not whole(report.get(k),0,1000000000): return false
		if not numeric(report.get("cash_delta"),-1000000000,1000000000) or not numeric(report.get("fatigue"),0,100): return false
		for k in ["logs", "gains"]:
			if not report.get(k) is Array: return false
			for line in report[k]:
				if not line is String: return false
		for key in ["fatigue_before","recovery_total","natural_recovery","fatigue_added"]:
			if report.has(key) and not numeric(report[key],0,1600): return false
		if report.has("stat_gains"):
			if not report.stat_gains is Dictionary: return false
			for key in report.stat_gains:
				if not key in GameCatalog.data().stat_names or not numeric(report.stat_gains[key],0,100): return false
		if report.has("timeline"):
			if not report.timeline is Array or report.timeline.size() != 16: return false
			for event in report.timeline:
				if not event is Dictionary: return false
				for key in ["action_id","scene_id","name","slot"]:
					if not event.get(key) is String: return false
				if not whole(event.get("week"),1,4): return false
				for key in ["fatigue_before","fatigue_after","recovered","potential_recovery"]:
					if not numeric(event.get(key),0,100): return false
				for key in ["cash_before","cash_after"]:
					if not whole(event.get(key),0,1000000000): return false
				if not event.get("gains") is Dictionary or not event.get("skipped") is bool: return false
				for key in event.gains:
					if not key in GameCatalog.data().stat_names or not numeric(event.gains[key],0,100): return false
	if not whole(state.account_legacy.get("lp"),0,1000000000): return false
	for id in state.gym_facilities:
		if not id in GameCatalog.data().facilities or not state.gym_facilities[id] is Dictionary: return false
		if not whole(state.gym_facilities[id].get("level"),0,3): return false
	for entry in state.hall_of_fame:
		if not entry is Dictionary: return false
		for key in ["name","athlete_id"]:
			if not entry.get(key) is String or entry[key].is_empty(): return false
		for key in ["months","age","wins","losses","draws","lp"]:
			if not whole(entry.get(key),0,1000000000): return false
	if a.has("retired") and not a.retired is bool: return false
	var settings: Dictionary = state.settings
	if not settings.get("strategy") is String or not settings.strategy in GameCatalog.data().strategy_names: return false
	if not settings.get("fixed_seed") is bool or not whole(settings.get("seed"),0,2147483647): return false
	return true

static func read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	if FileAccess.get_file_as_bytes(path).size() > 20 * 1024 * 1024: return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	var raw = parser.data
	return raw if valid(raw) else {}

static func load_game(path: String = DEFAULT_PATH) -> Dictionary:
	var state = read_one(path)
	if not state.is_empty(): return {"ok":true,"state":state,"recovered":false}
	state = read_one(path + ".bak")
	if not state.is_empty(): return {"ok":true,"state":state,"recovered":true}
	return {"ok":false,"error":"읽을 수 있는 저장이 없습니다. 파일 손상 또는 지원하지 않는 버전일 수 있습니다."}

# Write, flush, validate, then rename. Preserve the last valid primary as a backup.
static func save_game(state: Dictionary, path: String = DEFAULT_PATH) -> Error:
	if not valid(state): return ERR_INVALID_DATA
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(state, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK: return write_error
	if read_one(path + ".tmp").is_empty(): return ERR_FILE_CORRUPT
	var absolute = ProjectSettings.globalize_path(path)
	if not read_one(path).is_empty():
		var backup_error = DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK: return backup_error
	return DirAccess.rename_absolute(absolute + ".tmp", absolute)
