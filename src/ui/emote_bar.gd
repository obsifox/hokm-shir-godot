class_name EmoteBar
extends Control
## Bottom-left reaction emotes that expand in an arc.

signal react_picked(id: int)

const REACTS: Array[String] = [
	"react_clap", "react_laugh", "react_flower",
	"react_sad", "react_angry", "react_surprised",
]

var open := false
var main_btn: TextureButton
var buttons: Array[TextureButton] = []
var cooldown := false


func _ready() -> void:
	position = Vector2(30, 1450)
	size = Vector2(400, 420)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in REACTS.size():
		var b := UIH.icon_btn("res://assets/react/%s.png" % REACTS[i], 110, _on_react.bind(i))
		b.position = Vector2.ZERO
		b.visible = false
		b.modulate.a = 0.0
		b.z_index = 60
		add_child(b)
		buttons.append(b)

	main_btn = UIH.icon_btn("res://assets/react/react_clap.png", 108, _toggle)
	main_btn.z_index = 70
	main_btn.position = Vector2.ZERO
	add_child(main_btn)


func _toggle() -> void:
	if cooldown:
		return
	open = not open
	Snd.sfx("select")
	for i in buttons.size():
		var b := buttons[i]
		var target := Vector2(10 + (i % 2) * 118.0, -(i / 2) * 118.0 - 10.0)
		var t := b.create_tween()
		if open:
			b.visible = true
			t.set_parallel(true)
			t.tween_property(b, "position", target, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(b, "modulate:a", 1.0, 0.18).set_delay(i * 0.03)
		else:
			t.set_parallel(true)
			t.tween_property(b, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(b, "modulate:a", 0.0, 0.15)
			t.chain().tween_callback(b.hide)


func _on_react(id: int) -> void:
	if cooldown:
		return
	cooldown = true
	react_picked.emit(id)
	Snd.sfx("react")
	if open:
		_toggle()
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func(): cooldown = false)
