class_name CardView
extends Node2D
## Visual card: front + back + soft shadow, flip & fly animations.

static func size_px() -> Vector2:
	return Vector2(240, 360) * UIH.us()

var front: Sprite2D
var back: Sprite2D
var shadow: Sprite2D
var card: GameCard
var face_up := true
var _back_tex: String = "res://assets/back_classic.png"


static func tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _init(p_card: GameCard = null, p_face_up := true, p_back := "res://assets/back_classic.png") -> void:
	card = p_card
	face_up = p_face_up
	_back_tex = p_back
	z_index = 10

	shadow = Sprite2D.new()
	shadow.modulate = Color(0, 0, 0, 0.30)
	shadow.position = Vector2(10, 20)
	add_child(shadow)

	front = Sprite2D.new()
	add_child(front)

	back = Sprite2D.new()
	add_child(back)

	var f := tex(card.tex_path()) if card != null else tex(_back_tex)
	var b := tex(_back_tex)
	_scale_sprite(front, f)
	_scale_sprite(back, b)
	shadow.texture = front.texture if face_up else back.texture
	front.visible = face_up
	back.visible = not face_up


func _scale_sprite(spr: Sprite2D, t: Texture2D) -> void:
	if t == null:
		spr.visible = false
		return
	spr.texture = t
	var ts: Vector2 = t.get_size()
	var cs: Vector2 = size_px()
	var k: float = min(cs.x / ts.x, cs.y / ts.y)
	spr.scale = Vector2(k, k)


func set_card(p_card: GameCard, p_face_up := true, animated := false) -> void:
	card = p_card
	var f := tex(p_card.tex_path())
	_scale_sprite(front, f)
	if animated:
		flip_to(p_face_up)
	else:
		face_up = p_face_up
		front.visible = p_face_up
		back.visible = not p_face_up
		shadow.texture = f if p_face_up else back.texture


func flip_to(p_face_up: bool, dur := 0.22) -> void:
	face_up = p_face_up
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.05, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		front.visible = p_face_up
		back.visible = not p_face_up
		shadow.texture = front.texture if p_face_up else back.texture)
	tw.tween_property(self, "scale:x", 1.0, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if p_face_up:
		tw.tween_callback(func(): Snd.sfx("card_flip", 1.0, -14.0))


func flip_over_texture(new_card: GameCard, dur := 0.25) -> void:
	## flip from back to a specific face
	var f := tex(new_card.tex_path())
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.05, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_scale_sprite(front, f)
		front.visible = true
		back.visible = false
		shadow.texture = f)
	tw.tween_property(self, "scale:x", 1.0, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func fly_to(target: Vector2, dur := 0.4, p_rot := 0.0, p_scale := 1.0) -> Tween:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", p_rot, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(p_scale, p_scale), dur)
	return tw


func pop_in(dur := 0.25) -> void:
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sets an elevated soft shadow (used for the raised/active hand card)
func set_raised(v: bool) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(shadow, "modulate", Color(0, 0, 0, 0.42 if v else 0.30), 0.12)
	tw.tween_property(shadow, "position", Vector2(14, 26) if v else Vector2(10, 20), 0.12)
