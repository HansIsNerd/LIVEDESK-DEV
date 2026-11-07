# Runtime test suite for GameState, ChatEngine, and AppWindow foundation.
extends Node

const TROLL_SAMPLES: int = 100
const MAX_ADVANCE_STEPS: int = 50
const UPGRADE_KEYS: Array[String] = ["mic", "camera", "pc", "lighting", "chair"]
const TRUST_KEYS: Array[String] = ["moderator", "editor", "friend"]
const RESULT_KEYS: Array[String] = ["subs", "money", "hype", "health"]
const MESSAGE_KEYS: Array[String] = ["text", "audience", "user", "color"]
const CLOSE_LABEL: String = "×"

class Watcher extends RefCounted:
	var calls: Array = []

	func record(...args: Array) -> void:
		calls.append(args)

var _total: int = 0
var _passed: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_initial_state()
	_test_modify()
	_test_stream()
	_test_day_and_endings()
	_test_chat_engine()
	await _test_app_window()
	print("%d/%d passed" % [_passed, _total])


func _check(id: String, desc: String, ok: bool, detail: String = "") -> void:
	_total += 1
	if ok:
		_passed += 1
		print("[PASS] %s %s" % [id, desc])
	else:
		print("[FAIL] %s %s — %s" % [id, desc, detail])


func _eq(id: String, desc: String, got: Variant, expected: Variant) -> void:
	_check(id, desc, got == expected, "expected %s, got %s" % [str(expected), str(got)])


func _watch(sig: Signal) -> Watcher:
	var watcher: Watcher = Watcher.new()
	sig.connect(watcher.record)
	return watcher


func _unwatch(sig: Signal, watcher: Watcher) -> void:
	if sig.is_connected(watcher.record):
		sig.disconnect(watcher.record)


func _emitted_with(watcher: Watcher, expected: Array) -> bool:
	for args: Array in watcher.calls:
		if args.size() != expected.size():
			continue
		var matched: bool = true
		for i: int in expected.size():
			if args[i] != expected[i]:
				matched = false
				break
		if matched:
			return true
	return false


func _missing_keys(data: Dictionary, keys: Array[String]) -> Array[String]:
	var missing: Array[String] = []
	for key: String in keys:
		if not data.has(key):
			missing.append(key)
	return missing


func _run_to_end() -> void:
	var steps: int = 0
	while not GameState.is_game_over and steps < MAX_ADVANCE_STEPS:
		GameState.advance_day()
		steps += 1


func _find_script(class_name_str: String) -> GDScript:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == class_name_str:
			return load(entry["path"]) as GDScript
	return null


func _find_button(root: Node, label: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text == label:
			return child as Button
		var found: Button = _find_button(child, label)
		if found != null:
			return found
	return null


func _test_initial_state() -> void:
	GameState.reset()
	_eq("A.1", "initial day == 1", GameState.day, 1)
	_eq("A.2", "initial money == 500", GameState.money, 500)
	_eq("A.3", "initial energy == 100", GameState.energy, 100)
	_eq("A.4", "initial mood == 70", GameState.mood, 70)
	_eq("A.5", "initial reputation == 10", GameState.reputation, 10)
	_eq("A.6", "initial subscribers == 0", GameState.subscribers, 0)
	_eq("A.7", "initial is_live == false", GameState.is_live, false)
	_eq("A.8", "initial is_game_over == false", GameState.is_game_over, false)
	var missing_upgrades: Array[String] = _missing_keys(GameState.upgrades, UPGRADE_KEYS)
	_check("A.9", "upgrades has 5 keys", missing_upgrades.is_empty() and GameState.upgrades.size() == UPGRADE_KEYS.size(), "missing %s, size %d" % [str(missing_upgrades), GameState.upgrades.size()])
	var all_zero: bool = true
	for key: String in UPGRADE_KEYS:
		if GameState.upgrades.get(key, -1) != 0:
			all_zero = false
	_check("A.10", "upgrades all 0", all_zero, "got %s" % str(GameState.upgrades))
	var missing_trust: Array[String] = _missing_keys(GameState.trust, TRUST_KEYS)
	_check("A.11", "trust has 3 keys", missing_trust.is_empty() and GameState.trust.size() == TRUST_KEYS.size(), "missing %s, size %d" % [str(missing_trust), GameState.trust.size()])


func _test_modify() -> void:
	GameState.reset()
	var stat_watch: Watcher = _watch(GameState.stat_changed)
	var mood_watch: Watcher = _watch(GameState.mood_changed)
	GameState.modify("money", -100)
	_eq("B.1", "modify money -100 -> 400", GameState.money, 400)
	_check("B.2", "stat_changed(money, 400) emitted", _emitted_with(stat_watch, ["money", 400]), "calls %s" % str(stat_watch.calls))
	GameState.modify("money", -9999)
	_eq("B.3", "modify money -9999 clamps to 0", GameState.money, 0)
	GameState.modify("energy", 50)
	_eq("B.4", "modify energy +50 clamps to 100", GameState.energy, 100)
	GameState.modify("mood", -1000)
	_eq("B.5", "modify mood -1000 -> 0", GameState.mood, 0)
	_check("B.6", "mood_changed(0) emitted", _emitted_with(mood_watch, [0]), "calls %s" % str(mood_watch.calls))
	_unwatch(GameState.stat_changed, stat_watch)
	_unwatch(GameState.mood_changed, mood_watch)
	GameState.reset()


func _test_stream() -> void:
	GameState.reset()
	var started: Watcher = _watch(GameState.stream_started)
	var live_changed: Watcher = _watch(GameState.is_live_changed)
	var ended: Watcher = _watch(GameState.stream_ended)
	GameState.start_stream("Gaming", 60)
	_eq("C.1a", "start_stream is_live == true", GameState.is_live, true)
	_eq("C.1b", "start_stream stream_quality == 60", GameState.stream_quality, 60)
	_eq("C.1c", "start_stream stream_health == 100", GameState.stream_health, 100)
	_eq("C.1d", "start_stream hype == 10", GameState.hype, 10)
	_eq("C.1e", "stream_started emitted once", started.calls.size(), 1)
	_check("C.1f", "is_live_changed(true) emitted", _emitted_with(live_changed, [true]), "calls %s" % str(live_changed.calls))
	var topic_before: String = GameState.current_topic
	GameState.start_stream("Other", 90)
	_check("C.2a", "start_stream guard — state unchanged", GameState.is_live and GameState.stream_quality == 60 and GameState.current_topic == topic_before, "expected is_live unchanged, got quality %d topic %s" % [GameState.stream_quality, GameState.current_topic])
	_eq("C.2b", "guard — stream_started not re-emitted", started.calls.size(), 1)
	GameState.end_stream()
	_eq("C.3a", "end_stream is_live == false", GameState.is_live, false)
	_eq("C.3b", "stream_ended emitted once", ended.calls.size(), 1)
	var result: Dictionary = {}
	if ended.calls.size() > 0 and typeof(ended.calls[0][0]) == TYPE_DICTIONARY:
		result = ended.calls[0][0]
	var missing: Array[String] = _missing_keys(result, RESULT_KEYS)
	_check("C.3c", "stream_ended result has subs/money/hype/health", missing.is_empty(), "missing %s" % str(missing))
	_check("C.3d", "is_live_changed(false) emitted", _emitted_with(live_changed, [false]), "calls %s" % str(live_changed.calls))
	_unwatch(GameState.stream_started, started)
	_unwatch(GameState.is_live_changed, live_changed)
	_unwatch(GameState.stream_ended, ended)
	GameState.reset()


func _test_day_and_endings() -> void:
	GameState.reset()
	var day_watch: Watcher = _watch(GameState.day_advanced)
	GameState.advance_day()
	_eq("D.1a", "advance_day -> day == 2", GameState.day, 2)
	_check("D.1b", "day_advanced(2) emitted", _emitted_with(day_watch, [2]), "calls %s" % str(day_watch.calls))
	_unwatch(GameState.day_advanced, day_watch)

	GameState.reset()
	var ending_watch: Watcher = _watch(GameState.ending_triggered)
	GameState.mood = 60.0
	GameState.reputation = 50.0
	_run_to_end()
	_eq("D.2a", "stable: is_game_over == true", GameState.is_game_over, true)
	_eq("D.2b", "stable: ending", GameState.ending, "Stabil & Autentik")
	_eq("D.2c", "stable: ending_triggered emitted once", ending_watch.calls.size(), 1)
	_unwatch(GameState.ending_triggered, ending_watch)

	GameState.reset()
	GameState.subscribers = 150
	GameState.mood = 20.0
	_run_to_end()
	_eq("D.3", "viral ending", GameState.ending, "Viral tapi Kosong")

	GameState.reset()
	_run_to_end()
	_eq("D.4", "lost ending", GameState.ending, "Hilang Ditelan Algoritma")
	GameState.reset()


func _test_chat_engine() -> void:
	var fan: Dictionary = ChatEngine.get_message("fan")
	var missing: Array[String] = _missing_keys(fan, MESSAGE_KEYS)
	_check("E.1a", "get_message(fan) has text/audience/user/color", missing.is_empty(), "missing %s" % str(missing))
	_eq("E.1b", "get_message(fan) audience == fan", fan.get("audience"), "fan")
	var unknown: Dictionary = ChatEngine.get_message("nonexistent_audience")
	_check("E.2", "unknown audience returns valid Dictionary", _missing_keys(unknown, MESSAGE_KEYS).is_empty(), "got %s" % str(unknown))
	var wrong: int = 0
	for i: int in TROLL_SAMPLES:
		if ChatEngine.get_message("troll").get("audience") != "troll":
			wrong += 1
	_check("E.3", "%d troll samples all audience == troll" % TROLL_SAMPLES, wrong == 0, "%d mismatches" % wrong)


func _test_app_window() -> void:
	var script: GDScript = _find_script("AppWindow")
	if script == null:
		_check("F.0", "AppWindow class found", false, "no global class AppWindow")
		return
	var win: Control = script.new()
	win.set("window_title", "Test")
	add_child(win)
	await get_tree().process_frame
	_check("F.1", "content node exists", win.get("content") != null or win.find_child("content", true, false) != null, "content null and no child named content")
	_check("F.2", "title bar close button present", _find_button(win, CLOSE_LABEL) != null, "no Button with text %s" % CLOSE_LABEL)
	if win.has_method("_stub_content"):
		win.call("_stub_content", "hello")
		var content: Node = win.get("content") as Node
		if content == null:
			content = win.find_child("content", true, false)
		_check("F.3", "_stub_content adds child to content", content != null and content.get_child_count() >= 1, "content null or empty")
	else:
		_check("F.3", "_stub_content adds child to content", false, "method _stub_content missing")
	if win.has_method("_on_close_pressed"):
		win.call("_on_close_pressed")
		await get_tree().process_frame
		_check("F.4", "close queues node for deletion", not is_instance_valid(win) or win.is_queued_for_deletion(), "node still alive")
	else:
		_check("F.4", "close queues node for deletion", false, "method _on_close_pressed missing")
	if is_instance_valid(win) and not win.is_queued_for_deletion():
		win.queue_free()
