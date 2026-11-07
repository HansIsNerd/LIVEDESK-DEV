# Global game state: stats, stream lifecycle, day progression, endings.
extends Node

signal stat_changed(stat: String, value: float)
signal mood_changed(mood: float)
signal is_live_changed(live: bool)
signal stream_started
signal stream_ended(result: Dictionary)
signal day_advanced(day: int)
signal ending_triggered(ending: String)

const MAX_DAY: int = 21
const MVP_DAYS: int = 7

const STAT_MIN: float = 0.0
const STAT_MAX: float = 100.0
const CLAMPED_STATS: Array[String] = ["energy", "mood", "reputation", "hype", "stream_health"]
const FREE_STATS: Array[String] = ["money", "subscribers"]

const START_MONEY: float = 500.0
const START_ENERGY: float = 100.0
const START_MOOD: float = 70.0
const START_REPUTATION: float = 30.0
const START_SUBSCRIBERS: int = 0
const START_HYPE: float = 30.0
const START_STREAM_HEALTH: float = 100.0
const INITIAL_TRUST: Dictionary = {"moderator": 0, "editor": 0, "friend": 0}
const INITIAL_UPGRADES: Dictionary = {"mic": 0, "camera": 0, "pc": 0, "lighting": 0, "chair": 0}

const TICK_INTERVAL: float = 1.0
const ENERGY_DRAIN_PER_TICK: float = 1.0
const HYPE_DECAY_PER_TICK: float = 1.0
const DAILY_ENERGY_RESTORE: float = 60.0

const FULL_STREAM_TICKS: int = 60
const HYPE_FACTOR_BASE: float = 0.5
const SUBS_MAX_GAIN: float = 40.0
const MONEY_PER_TICK: float = 2.0
const MONEY_SUBS_SCALE: float = 100.0
const REPUTATION_MAX_GAIN: float = 5.0

const ENDING_MOOD_MIN: float = 50.0
const ENDING_REPUTATION_MIN: float = 40.0
const ENDING_SUBSCRIBERS_MIN: int = 100
const ENDING_STABLE: String = "Stabil & Autentik"
const ENDING_VIRAL: String = "Viral tapi Kosong"
const ENDING_LOST: String = "Hilang Ditelan Algoritma"

var day: int = 1
var day_limit: int = MVP_DAYS
var money: float = START_MONEY
var energy: float = START_ENERGY
var mood: float = START_MOOD
var reputation: float = START_REPUTATION
var subscribers: int = START_SUBSCRIBERS
var trust: Dictionary = {}
var upgrades: Dictionary = {}
var current_topic: String = ""
var stream_quality: int = 0
var stream_health: float = START_STREAM_HEALTH
var hype: float = 0.0
var is_game_over: bool = false
var ending: String = ""

var is_live: bool = false:
	set(value):
		if is_live == value:
			return
		is_live = value
		set_process(value)
		is_live_changed.emit(value)

var _tick_accum: float = 0.0
var _stream_ticks: int = 0


func _ready() -> void:
	set_process(false)
	reset()


func _process(delta: float) -> void:
	_tick_accum += delta
	while _tick_accum >= TICK_INTERVAL:
		_tick_accum -= TICK_INTERVAL
		_stream_ticks += 1
		modify("energy", -ENERGY_DRAIN_PER_TICK)
		modify("hype", -HYPE_DECAY_PER_TICK)
		if energy <= STAT_MIN:
			end_stream()
			return


func reset() -> void:
	is_live = false
	day = 1
	day_limit = MVP_DAYS
	money = START_MONEY
	energy = START_ENERGY
	mood = START_MOOD
	reputation = START_REPUTATION
	subscribers = START_SUBSCRIBERS
	trust = INITIAL_TRUST.duplicate()
	upgrades = INITIAL_UPGRADES.duplicate()
	current_topic = ""
	stream_quality = 0
	stream_health = START_STREAM_HEALTH
	hype = 0.0
	is_game_over = false
	ending = ""
	_tick_accum = 0.0
	_stream_ticks = 0
	for stat: String in CLAMPED_STATS + FREE_STATS:
		stat_changed.emit(stat, float(get(stat)))
	mood_changed.emit(mood)
	day_advanced.emit(day)


func modify(stat: String, amount: float) -> void:
	var is_clamped: bool = stat in CLAMPED_STATS
	if not is_clamped and not stat in FREE_STATS:
		push_warning("GameState.modify: unknown stat '%s'" % stat)
		return
	var value: float = float(get(stat)) + amount
	if is_clamped:
		value = clampf(value, STAT_MIN, STAT_MAX)
	if stat == "subscribers":
		set(stat, maxi(0, roundi(value)))
	else:
		set(stat, value)
	stat_changed.emit(stat, float(get(stat)))
	if stat == "mood":
		mood_changed.emit(mood)


func start_stream(topic: String, quality: int) -> void:
	if is_live or is_game_over or energy <= STAT_MIN:
		return
	current_topic = topic
	stream_quality = clampi(quality, 0, roundi(STAT_MAX))
	_tick_accum = 0.0
	_stream_ticks = 0
	modify("stream_health", START_STREAM_HEALTH - stream_health)
	modify("hype", START_HYPE - hype)
	is_live = true
	stream_started.emit()


func end_stream() -> void:
	if not is_live:
		return
	var quality_factor: float = stream_quality / STAT_MAX
	var hype_factor: float = HYPE_FACTOR_BASE + hype / STAT_MAX
	var health_factor: float = stream_health / STAT_MAX
	var duration_factor: float = clampf(float(_stream_ticks) / FULL_STREAM_TICKS, 0.0, 1.0)
	var subs_gain: int = roundi(SUBS_MAX_GAIN * quality_factor * hype_factor * health_factor * duration_factor)
	var money_gain: float = MONEY_PER_TICK * _stream_ticks * quality_factor * (1.0 + subscribers / MONEY_SUBS_SCALE)
	var reputation_gain: float = REPUTATION_MAX_GAIN * quality_factor * hype_factor * health_factor * duration_factor
	var result: Dictionary = {
		"topic": current_topic,
		"quality": stream_quality,
		"duration_ticks": _stream_ticks,
		"final_hype": hype,
		"final_health": stream_health,
		"subscribers_gain": subs_gain,
		"money_gain": money_gain,
		"reputation_gain": reputation_gain,
	}
	is_live = false
	current_topic = ""
	modify("subscribers", subs_gain)
	modify("money", money_gain)
	modify("reputation", reputation_gain)
	modify("hype", -hype)
	stream_ended.emit(result)


func advance_day() -> void:
	if is_game_over:
		return
	if is_live:
		end_stream()
	if day >= day_limit:
		_end_game()
		return
	day += 1
	modify("energy", DAILY_ENERGY_RESTORE)
	day_advanced.emit(day)


func _end_game() -> void:
	is_game_over = true
	ending = _resolve_ending()
	ending_triggered.emit(ending)


func _resolve_ending() -> String:
	if mood >= ENDING_MOOD_MIN and reputation >= ENDING_REPUTATION_MIN:
		return ENDING_STABLE
	if subscribers >= ENDING_SUBSCRIBERS_MIN:
		return ENDING_VIRAL
	return ENDING_LOST