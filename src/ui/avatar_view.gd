class_name AvatarView
extends Control
## One seat: ring frame, name, tricks, hakem badge, turn glow, react bubble.

const SIZE := Vector2(220, 240)

var seat := 0
var pname := ""
var is_ai := true
var tricks := 0
var is_turn := false

var ring: TextureRect
var face_bg: Panel
var face_label: Label
var name_label: Label
var tricks_label: Label
var hakem_badge: PanelContainer
var glow: TextureRect
var bubble_holder: Control
var _bubble: Node = null
var _glow_tween: Tween


func _init(p_seat: int, p_name: String, p_ai: bool) -> void:
    seat = p_seat
    pname = p_name
    is_ai = p_ai
    custom_minimum_size = SIZE
    size = SIZE
    pivot_offset = SIZE / 2.0
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
    glow = UIH.tex_rect("res://assets/btn/btn_round.png", Vector2(240, 240))
    glow.position = Vector2(-10, -14)
    glow.modulate = Color(1.0, 0.85, 0.4, 0.0)
    add_child(glow)

    face_bg = Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.17, 0.34)
    sb.set_corner_radius_all(78)
    sb.border_width_bottom = 4
    sb.border_width_top = 4
    sb.border_width_left = 4
    sb.border_width_right = 4
    sb.border_color = Color(0.85, 0.7, 0.42, 0.9)
    sb.shadow_color = Color(0, 0, 0, 0.4)
    sb.shadow_size = 10
    face_bg.add_theme_stylebox_override("panel", sb)
    face_bg.position = Vector2(20, 12)
    face_bg.size = Vector2(180, 180)
    face_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(face_bg)

    var initial := pname.left(1) if pname.length() > 0 else "?"
    face_label = UIH.label(initial, 86, UIH.GOLD, "Black")
    face_label.position = Vector2(20, 6)
    face_label.size = Vector2(180, 180)
    add_child(face_label)

    ring = UIH.tex_rect("res://assets/btn/btn_round.png", Vector2(220, 220))
    ring.position = Vector2(0, 0)
    add_child(ring)

    name_label = UIH.label(pname, 30, UIH.INK)
    name_label.position = Vector2(-30, 196)
    name_label.size = Vector2(280, 36)
    add_child(name_label)

    tricks_label = UIH.label("", 26, UIH.GOLD_DIM, "Medium")
    tricks_label.position = Vector2(-30, 174)
    tricks_label.size = Vector2(280, 32)
    add_child(tricks_label)

    hakem_badge = UIH.pill("حاکم", 22, Color(0.78, 0.6, 0.18, 0.95), Color(1, 0.97, 0.85))
    hakem_badge.position = Vector2(128, -14)
    hakem_badge.rotation_degrees = 12
    hakem_badge.visible = false
    add_child(hakem_badge)

    bubble_holder = Control.new()
    bubble_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
    bubble_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bubble_holder)


func set_turn(v: bool) -> void:
    is_turn = v
    if _glow_tween != null:
        _glow_tween.kill()
        _glow_tween = null
    if v:
        glow.modulate.a = 0.85
        _glow_tween = create_tween()
        _glow_tween.set_loops()
        _glow_tween.tween_property(glow, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _glow_tween.tween_property(glow, "modulate:a", 0.85, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    else:
        var t := create_tween()
        t.tween_property(glow, "modulate:a", 0.0, 0.3)


func set_tricks(n: int, _total: int = 0) -> void:
    tricks = n
    tricks_label.text = "دنگ " + S.fa(n)


func set_hakem(v: bool) -> void:
    hakem_badge.visible = v


func set_display_name(nm: String) -> void:
    pname = nm
    name_label.text = nm
    var initial := nm.left(1) if nm.length() > 0 else "?"
    face_label.text = initial


## Floating react emote above the avatar.
func show_react(tex_path: String) -> void:
    Snd.sfx("react")
    _clear_bubble()
    var b := UIH.tex_rect(tex_path, Vector2(110, 110))
    b.position = Vector2(55, -125)
    b.rotation_degrees = -8
    bubble_holder.add_child(b)
    _bubble = b
    b.pivot_offset = Vector2(55, 55)
    b.scale = Vector2.ZERO
    var t := b.create_tween()
    t.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    t.tween_property(b, "position:y", -145.0, 1.4)
    t.parallel().tween_property(b, "modulate:a", 0.0, 1.4).set_delay(0.35)
    t.tween_callback(_clear_bubble)


## Show a mini revealed card (peek effect).
func show_mini_card(card: GameCard, dur := 2.6) -> void:
    Snd.sfx("sp_use")
    _clear_bubble()
    var b := Node2D.new()
    b.position = Vector2(110, -110)
    bubble_holder.add_child(b)
    _bubble = b
    var cv := CardView.new(card, false, "res://assets/back_special.png")
    cv.scale = Vector2(0.55, 0.55)
    cv.z_index = 500
    b.add_child(cv)
    cv.flip_to(true, 0.3)
    var t := b.create_tween()
    t.tween_interval(dur)
    t.tween_property(b, "modulate:a", 0.0, 0.4)
    t.tween_callback(_clear_bubble)


func show_status(text: String, color: Color, dur := 1.8) -> void:
    _clear_bubble()
    var p := UIH.pill(text, 24, color)
    p.position = Vector2(35, -60)
    p.pivot_offset = Vector2(70, 20)
    bubble_holder.add_child(p)
    _bubble = p
    p.scale = Vector2.ZERO
    var t := p.create_tween()
    t.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    t.tween_interval(dur)
    t.tween_property(p, "modulate:a", 0.0, 0.35)
    t.tween_callback(_clear_bubble)


func show_thinking() -> void:
    _clear_bubble()
    var p := UIH.pill("...", 30, Color(0.1, 0.14, 0.3, 0.9), UIH.GOLD)
    p.position = Vector2(65, -70)
    bubble_holder.add_child(p)
    _bubble = p
    var t := create_tween()
    t.set_loops()
    t.tween_property(p, "modulate:a", 0.45, 0.4)
    t.tween_property(p, "modulate:a", 1.0, 0.4)
    p.set_meta("loop", t)


func hide_thinking() -> void:
    if _bubble != null and _bubble.has_meta("loop"):
        var t: Tween = _bubble.get_meta("loop")
        if t != null and t.is_valid():
            t.kill()
    _clear_bubble()


func _clear_bubble() -> void:
    if _bubble != null and is_instance_valid(_bubble):
        _bubble.queue_free()
    _bubble = null
