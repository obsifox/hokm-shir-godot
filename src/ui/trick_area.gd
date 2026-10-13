class_name TrickArea
extends Node2D
## The centre of the table: where played cards land and get collected.

signal anim_done

const CENTER := Vector2(540, 872)

var entries: Array = []  # {seat, card, view}
var host: Node


func setup(p_host: Node) -> void:
    host = p_host


func seat_angle(seat: int, n: int) -> float:
    return PI / 2.0 - seat * TAU / n


## Direction vector from table centre toward seat (screen coords, y down).
func seat_dir(seat: int, n: int) -> Vector2:
    var a := seat_angle(seat, n)
    return Vector2(cos(a), sin(a))


func slot_pos(seat: int, n: int) -> Vector2:
    return CENTER + seat_dir(seat, n) * 235.0


func avatar_pos(seat: int, n: int) -> Vector2:
    var d := seat_dir(seat, n)
    return CENTER + Vector2(d.x * 500.0, d.y * 700.0)


## Spawns a card flying in from from_pos (global design coords) to the slot.
func play_card(seat: int, card: GameCard, from_pos: Vector2, face_up := true, flip_from_back := false) -> CardView:
    var n: int = host.state.player_count
    var v := CardView.new(card, false, "res://assets/back_classic.png")
    v.position = from_pos
    v.scale = Vector2(0.9, 0.9)
    v.z_index = 400 + entries.size()
    add_child(v)
    var target := slot_pos(seat, n)
    var tw := v.create_tween()
    tw.set_parallel(true)
    tw.tween_property(v, "position", target, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(v, "scale", Vector2(0.86, 0.86), 0.34)
    tw.tween_property(v, "rotation", randf_range(-0.09, 0.09), 0.34)
    if face_up and (flip_from_back or not v.face_up):
        tw.chain().tween_callback(v.flip_to.bind(true, 0.16))
    entries.append({"seat": seat, "card": card, "view": v})
    Snd.sfx("card_throw", randf_range(0.95, 1.08))
    return v


## Golden marker on the card that carries the golden Sp effect.
func mark_golden(seat: int) -> void:
    for e in entries:
        if e.seat == seat:
            var star := UIH.label("۲×", 38, Color(1.0, 0.9, 0.35))
            star.position = Vector2(-22, -160)
            star.size = Vector2(60, 60)
            e.view.add_child(star)
            var t := star.create_tween()
            t.set_loops()
            t.tween_property(star, "modulate:a", 0.4, 0.5)
            t.tween_property(star, "modulate:a", 1.0, 0.5)
            break


func collect_to(target: Vector2, on_done: Callable) -> void:
    var any := false
    for e in entries:
        var v: CardView = e.view
        any = true
        var t := v.create_tween()
        t.set_parallel(true)
        t.tween_property(v, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
        t.tween_property(v, "scale", Vector2(0.3, 0.3), 0.45)
        t.tween_property(v, "modulate:a", 0.25, 0.45)
        t.chain().tween_callback(v.queue_free)
    entries.clear()
    if any:
        Snd.sfx("trick_collect", 1.0, -4.0)
        var timer := get_tree().create_timer(0.5)
        timer.timeout.connect(func():
            anim_done.emit()
            on_done.call())
    else:
        on_done.call()


func clear_all() -> void:
    for e in entries:
        if is_instance_valid(e.view):
            e.view.queue_free()
    entries.clear()
