class_name EventBanner
extends Control
## Center banner used for Evo events, hand results, kot, sp effects...

var panel: PanelContainer
var icon: TextureRect
var title_l: Label
var desc_l: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.22, 0.94)
	sb.set_corner_radius_all(34)
	sb.border_width_bottom = 4
	sb.border_width_top = 4
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_color = Color(0.85, 0.7, 0.4, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	icon = UIH.tex_rect("", Vector2(170, 255))
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	title_l = UIH.label("", 46, UIH.GOLD, "Black")
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(title_l)

	desc_l = UIH.label("", 28, UIH.INK, "Medium")
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.custom_minimum_size = Vector2(560, 0)
	col.add_child(desc_l)


func show_banner(title: String, desc: String, icon_path := "", dur := 2.2, big := false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	title_l.text = title
	desc_l.text = desc
	title_l.add_theme_font_size_override("font_size", 64 if big else 46)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
		icon.visible = true
	else:
		icon.visible = false
	panel.reset_size()
	var vs := UIH.vsize()
	panel.position = (vs - panel.size) * 0.5 + Vector2(0, -vs.y * 0.05)
	panel.pivot_offset = panel.size / 2.0
	Snd.sfx("banner", 1.0, -8.0)
	visible = true
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate = Color(1, 1, 1, 0)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	_tween.chain().tween_interval(dur)
	_tween.chain().tween_property(panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(hide)


## Big centre text like "کوت!" or "دنگ بردی"
func show_big_text(text: String, color := UIH.GOLD, dur := 1.6) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	panel.visible = false
	visible = true
	var l := UIH.label(text, 120, color, "Black", 10)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(UIH.cx() - 400, UIH.vsize().y * 0.454 - 100)
	l.size = Vector2(800, 200)
	l.pivot_offset = Vector2(400, 100)
	l.scale = Vector2(0.3, 0.3)
	l.modulate.a = 0.0
	add_child(l)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(l, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(l, "modulate:a", 1.0, 0.2)
	_tween.chain().tween_interval(dur)
	_tween.chain().tween_property(l, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(l.queue_free)
