extends Control
class_name NeuronMenu

signal cast_requested
signal close_requested

@export var reduced_effects: bool = false

const FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const UIStyle=preload("res://scripts/ui/ui_style.gd")
const PLAYER_PREVIEW_PATH := "" # v001 rejected by user; keep source, stop adoption.
const INK := Color("#293834")
const DIM := Color("#68736a")
const ACCENT := Color("#9b7042")
const SKIN_DESCRIPTION := "皮肤刺激 · SKIN\n{\n  // 消耗1神经元\n  // 我会让他感到皮肤不适\n  // 这有概率让他放弃本次行动\n  COST: 1神经元;  COOLDOWN: 2 秒;\n  INTENSITY: 1;\n  SUCCESS: 抓挠 0.5 秒;\n  INTERRUPT: 打断搜寻;\n  RESIST: 抵抗不退款;\n}"

var _built: bool = false
var _can_cast: bool = false
var _submitted: bool = false
var _hovered: bool = false
var _phase: float = 0.0
var _coin: Label
var _description: Label
var _status: Label
var _skin: Button
var _crt_material: ShaderMaterial


func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build_ui()


func open_menu(neurons_value: int, can_cast: bool, resistance_test: bool = false) -> void:
	_build_ui()
	_can_cast = can_cast
	_submitted = false
	_hovered = false
	_phase = 0.0
	_coin.text = "神经元 %d" % neurons_value
	_skin.disabled = not can_cast
	_description.text = ""
	_status.text = "抵抗测试场次" if resistance_test else ""
	if not can_cast:
		_status.text = "当前不可提交" + (" · 抵抗测试场次" if resistance_test else "")
	visible = true


func close_menu() -> void:
	visible = false
	_hovered = false
	if is_instance_valid(_description):
		_description.text = ""
	if is_instance_valid(_skin):
		_skin.release_focus()


func _process(delta: float) -> void:
	if not visible or not _built:
		return
	_phase += delta
	_crt_material.set_shader_parameter("ui_time", _phase)
	_crt_material.set_shader_parameter("strength", 0.0 if reduced_effects else 0.035)
	var pulse: float = 1.0
	if _hovered and not reduced_effects:
		pulse = 0.94 + sin(_phase * 3.0) * 0.06
	_skin.modulate = Color(pulse, pulse, pulse, 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_requested.emit()


func _build_ui() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(1280, 720)
	var ui_theme := Theme.new()
	var ui_font := load(FONT_PATH) as Font
	if ui_font != null:
		ui_theme.default_font = ui_font
	ui_theme.default_font_size = 20
	theme = ui_theme

	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.035, 0.055, 0.052, 0.47)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	# Mask the underlying HUD and test controls while leaving the room visible centrally.
	for band_bounds in [Rect2(0, 0, 1280, 140), Rect2(0, 560, 1280, 160)]:
		var band := ColorRect.new()
		band.position = band_bounds.position
		band.size = band_bounds.size
		band.color = Color("#10201b")
		band.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(band)
	_label(self, "NEURONS", Rect2(110, 53, 440, 48), 34, INK)
	_label(self, "神经节点", Rect2(112, 107, 460, 30), 18, DIM)
	_coin = _label(self, "神经元", Rect2(680, 90, 300, 34), 19, ACCENT)

	var close := _button(self, "关闭 ×", Rect2(1045, 55, 125, 43))
	close.pressed.connect(func() -> void: close_requested.emit())

	var crt := _panel(Rect2(110, 150, 520, 390), Color("#182923"), Color("#64715c"))
	var code := _panel(Rect2(680, 175, 475, 380), Color(0.055, 0.075, 0.065, 0.93), DIM)
	_label(crt, "神经节点 / 01", Rect2(22, 14, 330, 30), 17, DIM)
	_label(crt, "已解锁 01", Rect2(22, 346, 400, 30), 16, DIM)

	var points: Array[Vector2] = [
		Vector2(78, 100), Vector2(203, 159), Vector2(327, 87),
		Vector2(427, 175), Vector2(332, 275), Vector2(180, 293), Vector2(73, 240),
	]
	var links: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(1, 3),
		Vector2i(3, 4), Vector2i(1, 5), Vector2i(5, 4), Vector2i(5, 6), Vector2i(0, 6),
	]
	for link in links:
		var wire := Line2D.new()
		wire.points = PackedVector2Array([points[link.x], points[link.y]])
		wire.default_color = Color(0.35, 0.44, 0.34, 0.48)
		wire.width = 2.0
		wire.antialiased = true
		crt.add_child(wire)
	for i in range(points.size()):
		var node_rect := Rect2(points[i] - Vector2(35, 20), Vector2(70, 40))
		var node_button := _button(crt, "皮肤刺激" if i == 1 else "...", node_rect)
		if i == 1:
			_skin = node_button
			_skin.add_theme_font_size_override("font_size",14)
			_skin.tooltip_text="SKIN"
			_skin.add_theme_color_override("font_color", ACCENT)
			_skin.mouse_entered.connect(_show_description)
			_skin.mouse_exited.connect(_hide_description)
			_skin.focus_entered.connect(_show_description)
			_skin.focus_exited.connect(_hide_description)
			_skin.pressed.connect(_request_cast)
		else:
			node_button.disabled = true
			node_button.focus_mode = Control.FOCUS_NONE
			node_button.tooltip_text = ""

	# The CRT layer only covers this panel. It never samples/blurs the world or UI text.
	var scan := ColorRect.new()
	scan.position = Vector2(4, 4)
	scan.size = Vector2(512, 382)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float ui_time = 0.0;
uniform float strength = 0.035;
void fragment() {
    float lines = 0.5 + 0.5 * sin(UV.y * 640.0);
    float band = 0.5 + 0.5 * sin(UV.y * 10.0 - ui_time * 0.5);
    COLOR = vec4(0.0, 0.0, 0.0, strength * (lines + band * 0.15));
}
"""
	_crt_material = ShaderMaterial.new()
	_crt_material.shader = shader
	scan.material = _crt_material
	crt.add_child(scan)

	_description = _label(code, "", Rect2(26, 16, 424, 348), 18, INK)
	_description.add_theme_constant_override("line_spacing", 0)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = _label(self, "", Rect2(680, 595, 475, 42), 18, Color("#c4ad80"))

	var preview := TextureRect.new()
	preview.position = Vector2(140, 583)
	preview.size = Vector2(96, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not PLAYER_PREVIEW_PATH.is_empty() and ResourceLoader.exists(PLAYER_PREVIEW_PATH):
		preview.texture = load(PLAYER_PREVIEW_PATH) as Texture2D
	add_child(preview)
	_label(self, "玩家小怪物 · 使用占位\n正式形象由用户制作", Rect2(255, 598, 360, 65), 18, INK)
	_label(self, "ESC 关闭", Rect2(1000, 651, 160, 30), 17, INK)


func _show_description() -> void:
	_hovered = true
	_description.text = SKIN_DESCRIPTION


func _hide_description() -> void:
	_hovered = false
	_description.text = ""


func _request_cast() -> void:
	if not _can_cast or _submitted:
		return
	_submitted = true
	_skin.disabled = true
	_status.text = "已提交干预"
	# The application decides whether the action can commit, be resisted, or be interrupted.
	# Emitting this signal does not deduct currency or change world state.
	cast_requested.emit()


func _panel(bounds: Rect2, fill: Color, edge: Color) -> Panel:
	var panel := Panel.new()
	panel.position = bounds.position
	panel.size = bounds.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _box(fill, edge, 2))
	add_child(panel)
	return panel


func _label(parent: Node, text_value: String, bounds: Rect2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = bounds.position
	label.size = bounds.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, bounds: Rect2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = bounds.position
	button.size = bounds.size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 18)
	UIStyle.style_button(button,UIStyle.mode_for(parent))
	parent.add_child(button)
	return button


func _box(fill: Color, edge: Color, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(0)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	return box
