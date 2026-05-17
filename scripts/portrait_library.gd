extends Node

const PORTRAIT_ROOT := "res://assets/npc/"
const MAP_PATH := "res://data/portrait_map.json"

var _mood_map: Dictionary = {}
var _default_mood := "neutral"
var _default_stem := "Calm"
var _cache: Dictionary = {}


func _ready() -> void:
	_load_map()


func _load_map() -> void:
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_warning("PortraitLibrary: missing portrait_map.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_mood_map = parsed.get("moods", {})
		_default_mood = str(parsed.get("default_mood", "neutral"))
		_default_stem = str(parsed.get("default_stem", "Calm"))


func get_texture(agent_id: String, mood: String = "neutral") -> Texture2D:
	var folder := _folder_for(agent_id)
	if folder.is_empty():
		return _load_stem("NPC_1", _default_stem)
	var stems := _stems_for_mood(mood)
	for stem in stems:
		var tex := _load_stem(folder, stem)
		if tex:
			return tex
	return _load_stem(folder, _default_stem)


func _folder_for(agent_id: String) -> String:
	if GameManager.agents_meta.has(agent_id):
		return str(GameManager.agents_meta[agent_id].get("portrait_folder", ""))
	return ""


func _stems_for_mood(mood: String) -> Array:
	var key := mood.to_lower()
	var out: Array = []
	if _mood_map.has(key):
		var entry: Dictionary = _mood_map[key]
		out.append(str(entry.get("stem", _default_stem)))
		for fb in entry.get("fallback", []):
			out.append(str(fb))
	else:
		out.append(_default_stem)
	if not out.has(_default_stem):
		out.append(_default_stem)
	return out


func _load_stem(folder: String, stem: String) -> Texture2D:
	var cache_key := "%s/%s" % [folder, stem]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path := "%s%s/%s.png" % [PORTRAIT_ROOT, folder, stem]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if tex:
		_cache[cache_key] = tex
	return tex
