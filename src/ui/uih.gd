class_name UIH
extends RefCounted
## UI helpers — fonts, labels, buttons, panels. Consistent golden Persian style.

const GOLD := Color(0.92, 0.78, 0.45)
const GOLD_DIM := Color(0.72, 0.6, 0.38)
const INK := Color(0.96, 0.93, 0.86)
const NAVY := Color(0.09, 0.13, 0.26)
const NAVY_DEEP := Color(0.05, 0.07, 0.16)
const RED := Color(0.85, 0.35, 0.3)
const GREEN := Color(0.4, 0.78, 0.45)

static var _fonts := {}


## ---- responsive helpers (design space: 1080x1920, stretch=canvas_items+expand) ----
static func vsize() -> Vector2:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_visible_rect().size
	return Vector2(1080, 1920)


static func cx() -> float:
	return vsize().x * 0.5


## width scale factor (1.0 on all 9:16+ phones, grows on wide screens)
static func us() -> float:
	return clampf(vsize().x / 1080.0, 0.85, 1.5)


static func font(weight: String = "Bold") -> FontFile:
	if not _fonts.has(weight):
		var path := "res://fonts/Vazirmatn-%s.ttf" % weight
		_fonts[weight] = load(path)
	return _fonts[weight]


static func label(text: String, size: int, color: Color = INK, weight: String = "Bold", outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", int(size * us()))
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_direction = Control.TEXT_DIRECTION_RTL
	return l


static func tex_rect(path: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.custom_minimum_size = size
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func tex_btn(path: String, size: Vector2, on_pressed: Callable) -> TextureButton:
	var b := TextureButton.new()
	if ResourceLoader.exists(path):
		b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = size
	b.size = size
	b.pressed.connect(func():
		Snd.click()
		on_pressed.call())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# press feedback: dip + darken, springy release
	b.pivot_offset = size / 2.0
	b.button_down.connect(func():
		Snd.sfx("tap", 1.0, -12.0)
		b.modulate = Color(0.8, 0.8, 0.86)
		_pop(b, 0.9))
	b.button_up.connect(func():
		b.modulate = Color.WHITE
		_pop(b, 1.0))
	return b


static func _pop(c: Control, target: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(target, target), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func text_btn(text: String, size: Vector2, on_pressed: Callable, font_size: int = 44, primary := true) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size * us()
	b.size = size * us()
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/btn/btn_primary.png" if primary else "res://assets/btn/btn_secondary.png")
	sb.texture_margin_left = 110
	sb.texture_margin_right = 110
	sb.texture_margin_top = 70
	sb.texture_margin_bottom = 70
	var sbp: StyleBoxTexture = sb.duplicate()
	sbp.modulate_color = Color(0.76, 0.76, 0.82)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var l := label(text, font_size, Color.WHITE if primary else GOLD)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pivot_offset = b.size / 2.0
	b.pressed.connect(func():
		Snd.click()
		on_pressed.call())
	b.button_down.connect(func(): _press_anim(b))
	b.button_up.connect(func(): _release_anim(b))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func _press_anim(c: Control) -> void:
	c.modulate = Color(0.85, 0.85, 0.88)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.9, 0.9), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _release_anim(c: Control) -> void:
	c.modulate = Color.WHITE
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func icon_btn(path: String, side: float, on_pressed: Callable) -> TextureButton:
	return tex_btn(path, Vector2(side, side), on_pressed)


static func pill(text: String, font_size: int, bg: Color, fg: Color = Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_bottom = 3
	sb.border_color = Color(0, 0, 0, 0.25)
	var k := us()
	sb.set_corner_radius_all(int(font_size * k * 0.9))
	sb.content_margin_left = font_size * k * 0.9
	sb.content_margin_right = font_size * k * 0.9
	sb.content_margin_top = font_size * k * 0.32
	sb.content_margin_bottom = font_size * k * 0.32
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, font_size, fg)
	l.name = "txt"
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func set_pill_text(p: PanelContainer, text: String) -> void:
	var l: Label = p.get_node("txt")
	l.text = text


static func dim_overlay(alpha := 0.62) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.01, 0.02, 0.06, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func vignette() -> TextureRect:
	# soft dark vignette via gradient texture
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.28)])
	g.offsets = PackedFloat32Array([0.62, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(0.5, 1.15)
	gt.width = 540
	gt.height = 960
	var t := TextureRect.new()
	t.texture = gt
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func shake(node: CanvasItem) -> void:
	var orig: Vector2 = node.position
	var tw := node.create_tween()
	for off in [Vector2(12, 0), Vector2(-12, 0), Vector2(7, 0), Vector2(-4, 0), Vector2.ZERO]:
		tw.tween_property(node, "position", orig + off, 0.045)
