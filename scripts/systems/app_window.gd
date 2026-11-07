# base class window app: chrome, drag, close
class_name AppWindow
extends PanelContainer

signal closed(window: AppWindow)

const MIN_SIZE: Vector2 = Vector2(320, 200)
const TITLE_FONT_SIZE: int = 13
const CLOSE_BUTTON_SIZE: Vector2 = Vector2(24, 24)
const CONTENT_PADDING: int = 12
const TITLE_PADDING_H: int = 10
const TITLE_PADDING_V: int = 4
const BORDER_WIDTH: int = 2
const TITLE_ACCENT_WIDTH: int = 2
const SHADOW_SIZE: int = 1
const SHADOW_OFFSET: Vector2 = Vector2(0, 1)

const COLOR_PANEL: Color = Color("#FFFFFF")
const COLOR_BG: Color = Color("#F5F5F5")
const COLOR_BORDER: Color = Color("#D0D0D0")
const COLOR_ACCENT: Color = Color("#2563EB")
const COLOR_TEXT: Color = Color("#1F2937")

var app_id: String = ""
var window_title: String = ""
var content: Control

var _title_bar: PanelContainer
var _title_label: Label
var _close_button: Button
var _dragging: bool = false


func _ready() -> void:
	custom_minimum_size = MIN_SIZE
	add_theme_stylebox_override("panel", _make_window_style())
	_build_chrome()
	_on_ready_content()


func _on_ready_content() -> void:
	pass


func _stub_content(text: String) -> void:
	var label: Label = Label.new()
	label.text = tr(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(label)


func _build_chrome() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_title_bar = PanelContainer.new()
	_title_bar.add_theme_stylebox_override("panel", _make_title_style())
	_title_bar.gui_input.connect(_on_title_gui_input)
	root.add_child(_title_bar)

	var title_row: HBoxContainer = HBoxContainer.new()
	_title_bar.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = tr(window_title)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	title_row.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "×"
	_close_button.custom_minimum_size = CLOSE_BUTTON_SIZE
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.add_theme_color_override("font_color", COLOR_TEXT)
	_close_button.add_theme_color_override("font_hover_color", COLOR_ACCENT)
	_close_button.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
	_close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_close_button.add_theme_stylebox_override("hover", _make_close_hover_style())
	_close_button.add_theme_stylebox_override("pressed", _make_close_hover_style())
	_close_button.pressed.connect(_on_close_pressed)
	title_row.add_child(_close_button)

	var body: PanelContainer = PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", _make_body_style())
	root.add_child(body)

	var body_box: VBoxContainer = VBoxContainer.new()
	body.add_child(body_box)
	content = body_box


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button_event.pressed
			if button_event.pressed:
				move_to_front()
	elif event is InputEventMouseMotion and _dragging:
		var motion_event: InputEventMouseMotion = event
		position += motion_event.relative


func _on_close_pressed() -> void:
	closed.emit(self)
	queue_free()


func _make_window_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(BORDER_WIDTH)
	style.shadow_color = COLOR_BORDER
	style.shadow_size = SHADOW_SIZE
	style.shadow_offset = SHADOW_OFFSET
	return style


func _make_title_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_ACCENT
	style.border_width_bottom = TITLE_ACCENT_WIDTH
	style.content_margin_left = TITLE_PADDING_H
	style.content_margin_right = TITLE_PADDING_V
	style.content_margin_top = TITLE_PADDING_V
	style.content_margin_bottom = TITLE_PADDING_V
	return style


func _make_body_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_content_margin_all(CONTENT_PADDING)
	return style


func _make_close_hover_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	return style
