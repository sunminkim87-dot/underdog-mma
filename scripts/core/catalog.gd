class_name GameCatalog
extends RefCounted

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	return _data

static func action(id: String) -> Dictionary:
	return data().actions[id]

static func default_schedule(kind: String = "balanced") -> Array:
	var mains = ["boxing", "wrestling", "bjj", "judo"]
	if kind == "striking": mains = ["boxing", "kickboxing", "boxing", "sparring"]
	if kind == "wrestling": mains = ["wrestling", "judo", "wrestling", "wrestling"]
	if kind == "grappling": mains = ["bjj", "judo", "bjj", "bjj"]
	if kind == "recovery": mains = ["rest", "rest", "rest", "mental"]
	var result: Array = []
	for i in 4:
		result.append({"main":mains[i], "aux":"rest" if kind == "recovery" else "cardio", "life":"life_rest" if kind == "recovery" else ("job" if i % 2 == 0 else "life_rest")})
	return result

static var _extra: Dictionary = {}
static func extra() -> Dictionary:
	if _extra.is_empty():
		_extra = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression_data.json"))
	return _extra
