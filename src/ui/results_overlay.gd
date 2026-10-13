class_name ResultsOverlay
extends Control
## Full-screen match result: victory / loss background + score table.

signal replay_pressed
signal menu_pressed


func _init() -> void:
	pass


func setup(won: bool, title: String, lines: Array, show_buttons := true) -> void:
	_ready_layout(won, title, lines, show_buttons)


func _ready_layout(won: bool, title: String, lines: Array, show_buttons := true) -> void:
	var bg := UIH.tex_rect("res://assets/bg/bg_victory.jpg" if won else "res://assets/bg/bg_loss.jpg", Vector2(1080, 1920))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(UIH.dim_overlay(0.35))

	var t := UIH.label(title, 96, UIH.GOLD if won else Color(0.9, 0.6, 0.55), "Black", 12)
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(540 - 450, 400)
	t.size = Vector2(900, 120)
	t.pivot_offset = Vector2(450, 60)
	add_child(t)
	t.scale = Vector2(0.4, 0.4)
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(540 - 320, 700)
	box.custom_minimum_size = Vector2(640, 0)
	add_child(box)

	for ln in lines:
		var row := UIH.pill(str(ln), 32, Color(0.08, 0.11, 0.24, 0.9))
		row.custom_minimum_size = Vector2(640, 0)
		box.add_child(row)

	if show_buttons:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 40)
		row2.set_anchors_preset(Control.PRESET_CENTER)
		row2.position = Vector2(540 - 250, 1250)
		add_child(row2)

		var replay := UIH.tex_btn("res://assets/btn/btn_replay.png", Vector2(150, 150), func():
			Snd.click()
			replay_pressed.emit())
		row2.add_child(replay)

		var back := UIH.tex_btn("res://assets/btn/btn_back.png", Vector2(150, 150), func():
			Snd.click()
			menu_pressed.emit())
		row2.add_child(back)
