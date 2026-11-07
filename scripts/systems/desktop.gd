# Desktop shell: wallpaper, app icons, window layer, status widget, notifications, taskbar, ending modal.
extends Control

const COLD_COLOR: Color = Color(0.09, 0.09, 0.13)
const WARM_COLOR: Color = Color(0.20, 0.12, 0.16)
const STAT_MAX: float = 100.0
const WALLPAPER_TWEEN_TIME: float = 0.4

const COLOR_BG: Color = Color("#F5F5F5")
const COLOR_PANEL: Color = Color("#FFFFFF")
const COLOR_BORDER: Color = Color("#D0D0D0")
const COLOR_ACCENT: Color = Color("#2563EB")
const COLOR_TEXT: Color = Color("#1F2937")
const COLOR_DIM: Color = Color(0, 0, 0, 0.55)
const BORDER_WIDTH: int = 2

const ICON_SIZE: Vector2 = Vector2(100, 72)
const ICON_COLUMNS: int = 2
const ICON_GAP: int = 16
const DESKTOP_MARGIN: int = 16

const WINDOW_SIZE: Vector2 = Vector2(420, 300)
const WINDOW_TOP_MARGIN: float = 16.0
const WINDOW_LEFT_MARGIN: float = 260.0

const STATUS_WIDTH: int = 220
const NOTIFICATION_WIDTH: int = 280
const NOTIFICATION_LIFETIME: float = 5.0
const NOTIFICATION_FADE_TIME: float = 0.3
const TASKBAR_HEIGHT: int = 40
const TASKBAR_GAP: int = 6
const MODAL_PANEL_WIDTH: int = 420

const APPS: Array[Dictionary] = [
	{"id": "streamdeck", "name": "StreamDeck", "color": Color("#2563EB")},
	{"id": "chat", "name": "Chat", "color": Color("#16A34A")},
	{"id": "editor", "name": "Editor", "color": Color("#9333EA")},
	{"id": "messages", "name": "Messages", "color": Color("#0891B2")},
	{"id": "social", "name": "Social", "color": Color("#DB2777")},
	{"id": "browser", "name": "Browser", "color": Color("#EA580C")},
	{"id": "bank", "name": "Bank", "color": Color("#CA8A04")},
	{"id": "files", "name": "Files", "color": Color("#64748B")},
]

var open_windows: Dictionary = {}

var _wallpaper: ColorRect
var _wallpaper_tween: Tween
var _icon_grid: GridContainer
var _window_layer: Control
var _money_label: Label
var _subs_label: Label
var _energy_bar: ProgressBar
var _mood_bar: ProgressBar
var _reputation_bar: ProgressBar
var _notification_layer: VBoxContainer
var _day_label: Label
var _task_buttons: HBoxContainer
var _next_day_button: Button
var _modal_layer: Control


func _ready() -> void:
	_build_wallpaper()
	_build_icon_grid()
	_build_window_layer()
	_build_status_widget()
	_build_notification_layer()
	_build_taskbar()
	_connect_signals()
	_refresh_all()


func open_app(app_id: String) -> void:
	if open_windows.has(app_id) and is_instance_valid(open_windows[app_id]):
		open_windows[app_id].move_to_front()
		return
	var window: AppWindow = AppWindow.new()
	window.app_id = app_id
	window.title = tr(_get_app_name(app_id))
	window.custom_minimum_size = WINDOW_SIZE
	_window_layer.add_child(window)
	window.position = _random_window_position()
	var placeholder: Label = Label.new()
	placeholder.text = tr(_get_app_name(app_id))
	window.content.add_child(placeholder)
	open_windows[app_id] = window
	window.tree_exited.connect(_on_window_exited.bind(app_id, window))
	_rebuild_taskbar()


func focus_app(app_id: String) -> void:
	if open_windows.has(app_id) and is_instance_valid(open_windows[app_id]):
		open_windows[app_id].move_to_front()


func notify(title: String, body: String, color: Color = COLOR_ACCENT) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size.x = NOTIFICATION_WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_box(COLOR_PANEL, COLOR_BORDER))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var stripe: ColorRect = ColorRect.new()
	stripe.color = color
	stripe.custom_minimum_size.x = BORDER_WIDTH * 2
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title_label: Label = _make_label(title)
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	texts.add_child(title_label)
	var body_label: Label = _make_label(body)
	body_label.add_theme_color_override("font_color", COLOR_TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(body_label)
	_notification_layer.add_child(card)
	var tween: Tween = card.create_tween()
	tween.tween_interval(NOTIFICATION_LIFETIME)
	tween.tween_property(card, "modulate:a", 0.0, NOTIFICATION_FADE_TIME)
	tween.tween_callback(card.queue_free)


func _connect_signals() -> void:
	GameState.stat_changed.connect(_on_stat_changed)
	GameState.mood_changed.connect(_on_mood_changed)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.is_live_changed.connect(_on_is_live_changed)
	GameState.stream_ended.connect(_on_stream_ended)
	GameState.ending_triggered.connect(_on_ending_triggered)
	_next_day_button.pressed.connect(_on_next_day_pressed)


func _build_wallpaper() -> void:
	_wallpaper = ColorRect.new()
	_wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wallpaper.color = COLD_COLOR
	add_child(_wallpaper)


func _build_icon_grid() -> void:
	_icon_grid = GridContainer.new()
	_icon_grid.columns = ICON_COLUMNS
	_icon_grid.position = Vector2(DESKTOP_MARGIN, DESKTOP_MARGIN)
	_icon_grid.add_theme_constant_override("h_separation", ICON_GAP)
	_icon_grid.add_theme_constant_override("v_separation", ICON_GAP)
	add_child(_icon_grid)
	for app: Dictionary in APPS:
		_icon_grid.add_child(_make_icon(app))


func _make_icon(app: Dictionary) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	var button: Button = Button.new()
	button.custom_minimum_size = ICON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	var color: Color = app["color"]
	for state: String in ["normal", "hover", "pressed"]:
		var tint: Color = color
		if state == "hover":
			tint = color.lightened(0.15)
		elif state == "pressed":
			tint = color.darkened(0.15)
		button.add_theme_stylebox_override(state, _make_box(tint, COLOR_BORDER))
	button.pressed.connect(open_app.bind(app["id"]))
	box.add_child(button)
	var label: Label = _make_label(tr(app["name"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_BG)
	box.add_child(label)
	return box


func _build_window_layer() -> void:
	_window_layer = Control.new()
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window_layer)


func _build_status_widget() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.custom_minimum_size.x = STATUS_WIDTH
	panel.offset_left = -STATUS_WIDTH - DESKTOP_MARGIN
	panel.offset_right = -DESKTOP_MARGIN
	panel.offset_top = DESKTOP_MARGIN
	panel.add_theme_stylebox_override("panel", _make_box(COLOR_PANEL, COLOR_BORDER))
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	_money_label = _make_dark_label()
	column.add_child(_money_label)
	_energy_bar = _add_stat_row(column, tr("Energy"))
	_mood_bar = _add_stat_row(column, tr("Mood"))
	_reputation_bar = _add_stat_row(column, tr("Reputation"))
	_subs_label = _make_dark_label()
	column.add_child(_subs_label)


func _add_stat_row(parent: VBoxContainer, caption: String) -> ProgressBar:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = _make_dark_label()
	label.text = caption
	label.custom_minimum_size.x = STATUS_WIDTH * 0.4
	row.add_child(label)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = STAT_MAX
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _make_box(COLOR_BG, COLOR_BORDER))
	bar.add_theme_stylebox_override("fill", _make_box(COLOR_ACCENT, COLOR_ACCENT))
	row.add_child(bar)
	return bar


func _build_notification_layer() -> void:
	_notification_layer = VBoxContainer.new()
	_notification_layer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_notification_layer.alignment = BoxContainer.ALIGNMENT_END
	_notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_layer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notification_layer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notification_layer.custom_minimum_size.x = NOTIFICATION_WIDTH
	_notification_layer.offset_left = -NOTIFICATION_WIDTH - DESKTOP_MARGIN
	_notification_layer.offset_right = -DESKTOP_MARGIN
	_notification_layer.offset_top = -DESKTOP_MARGIN * 20
	_notification_layer.offset_bottom = -TASKBAR_HEIGHT - DESKTOP_MARGIN
	add_child(_notification_layer)


func _build_taskbar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TASKBAR_HEIGHT
	bar.add_theme_stylebox_override("panel", _make_box(COLOR_PANEL, COLOR_BORDER))
	add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", TASKBAR_GAP)
	bar.add_child(row)
	_day_label = _make_dark_label()
	row.add_child(_day_label)
	_task_buttons = HBoxContainer.new()
	_task_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_buttons.add_theme_constant_override("separation", TASKBAR_GAP)
	row.add_child(_task_buttons)
	_next_day_button = Button.new()
	_next_day_button.text = tr("Next Day") + " ▶"
	_next_day_button.focus_mode = Control.FOCUS_NONE
	row.add_child(_next_day_button)


func _rebuild_taskbar() -> void:
	for child: Node in _task_buttons.get_children():
		child.queue_free()
	for app: Dictionary in APPS:
		var app_id: String = app["id"]
		if not open_windows.has(app_id):
			continue
		var button: Button = Button.new()
		button.text = tr(app["name"])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(focus_app.bind(app_id))
		_task_buttons.add_child(button)


func _refresh_all() -> void:
	_refresh_stats()
	_update_wallpaper(true)
	_refresh_day()
	_next_day_button.disabled = GameState.is_live


func _refresh_stats() -> void:
	_money_label.text = tr("Money") + ": " + str(GameState.money)
	_subs_label.text = tr("Subs") + ": " + str(GameState.subscribers)
	_energy_bar.value = GameState.energy
	_mood_bar.value = GameState.mood
	_reputation_bar.value = GameState.reputation


func _refresh_day() -> void:
	_day_label.text = tr("Day %d") % GameState.day


func _update_wallpaper(instant: bool = false) -> void:
	var weight: float = clampf(float(GameState.mood) / STAT_MAX, 0.0, 1.0)
	var target: Color = COLD_COLOR.lerp(WARM_COLOR, weight)
	if _wallpaper_tween:
		_wallpaper_tween.kill()
	if instant:
		_wallpaper.color = target
		return
	_wallpaper_tween = create_tween()
	_wallpaper_tween.tween_property(_wallpaper, "color", target, WALLPAPER_TWEEN_TIME)


func _random_window_position() -> Vector2:
	var max_x: float = maxf(WINDOW_LEFT_MARGIN, _window_layer.size.x - WINDOW_SIZE.x)
	var max_y: float = maxf(WINDOW_TOP_MARGIN, _window_layer.size.y - WINDOW_SIZE.y - TASKBAR_HEIGHT)
	return Vector2(
		randf_range(WINDOW_LEFT_MARGIN, max_x),
		randf_range(WINDOW_TOP_MARGIN, max_y)
	)


func _get_app_name(app_id: String) -> String:
	for app: Dictionary in APPS:
		if app["id"] == app_id:
			return app["name"]
	return app_id


func _close_all_windows() -> void:
	for window: Node in open_windows.values():
		if is_instance_valid(window):
			window.queue_free()
	open_windows.clear()
	_rebuild_taskbar()


func _show_ending_modal(ending_id: String) -> void:
	if _modal_layer:
		return
	_modal_layer = ColorRect.new()
	(_modal_layer as ColorRect).color = COLOR_DIM
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_layer)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = MODAL_PANEL_WIDTH
	panel.add_theme_stylebox_override("panel", _make_box(COLOR_PANEL, COLOR_BORDER))
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ICON_GAP)
	panel.add_child(column)
	var title: Label = _make_dark_label()
	title.text = tr("ENDING_" + ending_id.to_upper())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var summary: Label = _make_dark_label()
	summary.text = "\n".join([
		tr("Day %d") % GameState.day,
		tr("Money") + ": " + str(GameState.money),
		tr("Subs") + ": " + str(GameState.subscribers),
		tr("Reputation") + ": " + str(GameState.reputation),
		tr("Mood") + ": " + str(GameState.mood),
		tr("Trust") + ": " + str(GameState.trust),
	])
	column.add_child(summary)
	var restart: Button = Button.new()
	restart.text = tr("Restart")
	restart.pressed.connect(_on_restart_pressed)
	column.add_child(restart)


func _make_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_WIDTH)
	box.set_content_margin_all(ICON_GAP / 2)
	return box


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_dark_label() -> Label:
	var label: Label = _make_label("")
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _on_stat_changed(_stat: Variant = null, _value: Variant = null) -> void:
	_refresh_stats()


func _on_mood_changed(_value: Variant = null) -> void:
	_mood_bar.value = GameState.mood
	_update_wallpaper()


func _on_day_advanced(_day: Variant = null) -> void:
	_refresh_day()
	notify(tr("Day %d") % GameState.day, tr("A new day begins."))


func _on_is_live_changed(_live: Variant = null) -> void:
	_next_day_button.disabled = GameState.is_live


func _on_stream_ended(_result: Variant = null) -> void:
	notify(tr("Stream ended"), tr("You are offline."))


func _on_ending_triggered(ending_id: Variant = "") -> void:
	_show_ending_modal(str(ending_id))


func _on_next_day_pressed() -> void:
	GameState.advance_day()


func _on_window_exited(app_id: String, window: Node) -> void:
	if open_windows.get(app_id) == window:
		open_windows.erase(app_id)
		_rebuild_taskbar()


func _on_restart_pressed() -> void:
	GameState.reset()
	_close_all_windows()
	if _modal_layer:
		_modal_layer.queue_free()
		_modal_layer = null
	_refresh_all()
