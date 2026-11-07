# Loads chat templates from JSON and produces random chat messages with safe fallback.
extends Node

const DATA_PATH: String = "res://data/chat_templates.json"
const DEFAULT_AUDIENCE: String = "fan"
const DEFAULT_USER: String = "viewer_01"
const DEFAULT_COLOR: Color = Color("#1F2937")

var _names: Array[String] = []
var _templates: Array[Dictionary] = []
var _by_audience: Dictionary = {}


func _ready() -> void:
	load_data()


func load_data() -> bool:
	_names.clear()
	_templates.clear()
	_by_audience.clear()
	var ok: bool = _parse_file()
	if not ok:
		_apply_fallback()
	_index_templates()
	return ok


func get_message(audience: String = DEFAULT_AUDIENCE) -> Dictionary:
	var pool: Array = _by_audience.get(audience, [])
	if pool.is_empty():
		pool = _templates
	var template: Dictionary = pool.pick_random()
	return {
		"text": template["text"],
		"audience": template["audience"],
		"user": _names.pick_random(),
		"color": template["color"],
	}


func _parse_file() -> bool:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("ChatEngine: missing %s" % DATA_PATH)
		return false
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("ChatEngine: cannot open %s" % DATA_PATH)
		return false
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_warning("ChatEngine: parse error line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("ChatEngine: root must be Dictionary")
		return false
	var data: Dictionary = json.data
	for raw_name: Variant in data.get("names", []):
		_names.append(str(raw_name))
	for raw: Variant in data.get("templates", []):
		if typeof(raw) != TYPE_DICTIONARY or not raw.has("text"):
			continue
		var color_text: String = str(raw.get("color", ""))
		_templates.append({
			"text": str(raw["text"]),
			"audience": str(raw.get("audience", DEFAULT_AUDIENCE)),
			"color": Color.from_string(color_text, DEFAULT_COLOR),
		})
	if _names.is_empty() or _templates.is_empty():
		push_warning("ChatEngine: names/templates empty")
		return false
	return true


func _apply_fallback() -> void:
	_names.clear()
	_templates.clear()
	_names.append(DEFAULT_USER)
	_templates.append({
		"text": tr("CHAT_FALLBACK_TEXT"),
		"audience": DEFAULT_AUDIENCE,
		"color": DEFAULT_COLOR,
	})


func _index_templates() -> void:
	for template: Dictionary in _templates:
		var key: String = template["audience"]
		if not _by_audience.has(key):
			_by_audience[key] = []
		_by_audience[key].append(template)