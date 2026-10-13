class_name HandFan
extends Control
## The player's hand: circular fan layout.
## - Horizontal swipe: slide selection across cards
## - Drag up: throw the active card
## - Tap: select card

signal play_requested(card: GameCard)

const ACTIVE_LIFT := 84.0

const CARD_W := 240.0
const CARD_H := 360.0


func _base_y() -> float:
    return UIH.vsize().y - 88.0 * UIH.us()

var cards: Array[GameCard] = []
var views: Array[CardView] = []
var active_i := 0
var sort_mode: int = Rules.SortMode.TRUMP_FIRST
var input_enabled := false
var hokm := -1

var holder: Node2D
var _press_active := false
var _press_pos := Vector2.ZERO
var _drag_mode := 0  # 0 none, 1 horizontal, 2 vertical
var _last_active := 0


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    holder = Node2D.new()
    add_child(holder)


func set_hokm(h: int) -> void:
    hokm = h


func set_input_enabled(v: bool) -> void:
    input_enabled = v
    mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
    var tw := create_tween()
    tw.tween_property(holder, "modulate", Color(1, 1, 1, 1.0 if v else 0.55), 0.2)


func set_hand(p_cards: Array[GameCard], animate_in := false) -> void:
    for v in views:
        v.queue_free()
    views.clear()
    cards = p_cards.duplicate()
    active_i = clampi(active_i, 0, maxi(cards.size() - 1, 0))
    for c in cards:
        var v := CardView.new(c, true)
        holder.add_child(v)
        views.append(v)
    if animate_in:
        _deal_in()
    else:
        refresh_layout(false)


func clear_hand() -> void:
    for v in views:
        v.queue_free()
    views.clear()
    cards.clear()


func _slot(i: int, n: int) -> Dictionary:
    var mid := (n - 1) / 2.0
    var d := i - mid
    var cw := CardView.size_px().x
    var step_x := 64.0 * UIH.us() if n <= 1 else clampf((UIH.vsize().x * 0.86 - cw) / (n - 1), 60.0 * UIH.us(), 148.0 * UIH.us())
    var droop := 0.0 if n <= 1 else minf(2.4, 150.0 / maxf(mid * mid, 1.0))
    var x := UIH.cx() + d * step_x
    var y := _base_y() + d * d * droop
    var rot := clampf(d * 0.028, -0.16, 0.16)
    return {"pos": Vector2(x, y), "rot": rot, "z": 100 + i}


func refresh_layout(animate := true, stagger := 0.0) -> void:
    var n := views.size()
    if n == 0:
        return
    for i in n:
        var v := views[i]
        var s := _slot(i, n)
        var is_active := i == active_i
        var target: Vector2 = s.pos + Vector2(0, -ACTIVE_LIFT if is_active else 0)
        var t_scale := 1.10 if is_active else 1.0
        var t_rot: float = s.rot * 0.4 if is_active else s.rot
        v.z_index = 300 if is_active else s.z
        if animate:
            var t := v.create_tween()
            t.set_parallel(true)
            t.tween_property(v, "position", target, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            t.tween_property(v, "rotation", t_rot, 0.16)
            t.tween_property(v, "scale", Vector2(t_scale, t_scale), 0.16)
            t.tween_property(v, "modulate", Color(1, 1, 1, 1.0 if is_active else 0.92), 0.16)
        else:
            v.position = target
            v.rotation = t_rot
            v.scale = Vector2(t_scale, t_scale)
            v.modulate = Color(1, 1, 1, 1.0 if is_active else 0.92)
    if n > active_i:
        views[active_i].set_raised(true)


func _deal_in() -> void:
    ## cards fly from the centre deck to the fan, flipping face-up
    var n := views.size()
    refresh_layout(false)
    for i in n:
        var v := views[i]
        var s := _slot(i, n)
        v.position = Vector2(UIH.cx(), UIH.vsize().y * 0.43)
        v.scale = Vector2(0.7, 0.7)
        v.rotation = 0.0
        v.visible = false
        v.z_index = 100 + i
        var t := v.create_tween()
        t.tween_interval(0.055 * i)
        t.tween_callback(func():
            v.visible = true
            Snd.sfx("deal", 1.0 + i * 0.02, -8.0))
        t.set_parallel(true)
        t.tween_property(v, "position", s.pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        t.tween_property(v, "rotation", s.rot, 0.3)
        t.tween_property(v, "scale", Vector2.ONE, 0.3)
        t.tween_callback(v.flip_to.bind(true, 0.16))


func add_cards(p_cards: Array[GameCard]) -> void:
    ## second wave of dealing
    var first_idx := views.size()
    for c in p_cards:
        cards.append(c)
        var v := CardView.new(c, false)
        holder.add_child(v)
        views.append(v)
    refresh_layout(false)
    for j in range(first_idx, views.size()):
        var v := views[j]
        var s := _slot(j, views.size())
        v.position = Vector2(UIH.cx(), UIH.vsize().y * 0.43)
        v.scale = Vector2(0.7, 0.7)
        v.rotation = 0.0
        var t := v.create_tween()
        t.tween_interval(0.05 * (j - first_idx))
        t.tween_callback(func(): Snd.sfx("deal", 0.9 + 0.02 * j, -8.0))
        t.set_parallel(true)
        t.tween_property(v, "position", s.pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        t.tween_property(v, "rotation", s.rot, 0.3)
        t.tween_property(v, "scale", Vector2.ONE, 0.3)
        t.tween_callback(v.flip_to.bind(true, 0.16))


func set_active(i: int, silent := false) -> void:
    if views.is_empty():
        return
    i = clampi(i, 0, views.size() - 1)
    var changed := i != active_i
    active_i = i
    refresh_layout()
    if changed and not silent:
        Snd.sfx("select", 1.0, -6.0)


func active_card() -> GameCard:
    if cards.is_empty() or active_i >= cards.size():
        return null
    return cards[active_i]


## Sorts cards with the next sort mode. Returns mode name for toast.
func sort() -> String:
    sort_mode = (sort_mode + 1) % 3
    var act_uid := active_card().uid if active_card() != null else -1
    Rules.sort_hand(cards, hokm, sort_mode)
    for i in cards.size():
        views[i].card = cards[i]
        var f := CardView.tex(cards[i].tex_path())
        views[i]._scale_sprite(views[i].front, f)
        views[i].shadow.texture = f
    for i in views.size():
        if cards[i].uid == act_uid:
            active_i = i
    refresh_layout(true)
    Snd.sfx("sort")
    match sort_mode:
        Rules.SortMode.TRUMP_FIRST: return "چیدمان: حکم اول"
        Rules.SortMode.SUIT_ORDER: return "چیدمان: بر اساس خال"
        _: return "چیدمان: بر اساس امتیاز"


## Removes & returns transform info of the card with the given uid (throw handoff).
func take_by_uid(uid: int) -> Dictionary:
    for i in views.size():
        if cards[i] != null and cards[i].uid == uid:
            var v := views[i]
            var info := {
                "card": cards[i],
                "pos": v.global_position,
                "rot": v.rotation,
                "scale": v.scale,
            }
            v.queue_free()
            views.remove_at(i)
            cards.remove_at(i)
            if active_i >= views.size():
                active_i = maxi(views.size() - 1, 0)
            refresh_layout(true)
            return info
    return {}


func reject_active() -> void:
    refresh_layout()
    shake_card(active_i)


func shake_card(i: int) -> void:
    if i >= views.size():
        return
    var v := views[i]
    Snd.sfx("error", 1.0, -4.0)
    var orig: Vector2 = _slot(i, views.size()).pos + Vector2(0, -ACTIVE_LIFT if i == active_i else 0)
    var tw := v.create_tween()
    for off in [Vector2(16, 0), Vector2(-16, 0), Vector2(9, 0), Vector2.ZERO]:
        tw.tween_property(v, "position", orig + off, 0.05)


func flash_active_green() -> void:
    if active_i < views.size():
        var v := views[active_i]
        v.modulate = Color(0.75, 1.0, 0.75)
        var t := v.create_tween()
        t.tween_property(v, "modulate", Color(1, 1, 1), 0.25)


# ---------------- input ----------------

func _gui_input(event: InputEvent) -> void:
    if not input_enabled or views.is_empty():
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _on_press(event.position)
        else:
            _on_release()
    elif event is InputEventMouseMotion and _press_active:
        _on_motion(event.position)


func _hit_card(p: Vector2) -> int:
    for i in range(views.size() - 1, -1, -1):
        var v := views[i]
        var sc: float = v.scale.x
        var half := CardView.size_px() * 0.5 * sc
        var local := p - v.position
        if absf(local.x) <= half.x and absf(local.y) <= half.y:
            return i
    return -1


func _on_press(p: Vector2) -> void:
    _press_active = true
    _press_pos = p
    _drag_mode = 0
    _last_active = active_i
    var hit := _hit_card(p)
    if hit >= 0:
        if hit != active_i:
            set_active(hit)
        else:
            Snd.sfx("tap", 1.0, -10.0)
            var v := views[hit]
            var t := v.create_tween()
            t.tween_property(v, "scale", Vector2(1.05, 1.05), 0.06)
    else:
        _press_active = false


func _on_motion(p: Vector2) -> void:
    var dx := p.x - _press_pos.x
    var dy := p.y - _press_pos.y
    if _drag_mode == 0:
        if absf(dx) > 26.0 and absf(dx) > absf(dy):
            _drag_mode = 1
            Snd.sfx("swipe", 1.0, -8.0)
        elif dy < -36.0:
            _drag_mode = 2
            Snd.sfx("card_slide", 1.0, -8.0)
    if _drag_mode == 1:
        var shift := int(-dx / 64.0)
        var target := clampi(_last_active + shift, 0, views.size() - 1)
        if target != active_i:
            set_active(target)
    elif _drag_mode == 2:
        var v := views[active_i]
        var s := _slot(active_i, views.size())
        var lift := minf(-dy * 0.62, 170.0)
        v.position = s.pos + Vector2(0, -ACTIVE_LIFT - lift)
        v.rotation = s.rot * 0.4 + clampf(dx * 0.0004, -0.1, 0.1)
        v.scale = Vector2(1.10 + lift / 900.0, 1.10 + lift / 900.0)


func _on_release() -> void:
    if not _press_active:
        return
    _press_active = false
    if _drag_mode == 2 and views.size() > active_i:
        var v := views[active_i]
        var s := _slot(active_i, views.size())
        # if the card was dragged well above its slot, throw it
        if v.position.y < s.pos.y - ACTIVE_LIFT - 90.0:
            var c := active_card()
            if c != null:
                play_requested.emit(c)
                return
        # else animate back
        var t := v.create_tween()
        t.set_parallel(true)
        t.tween_property(v, "position", s.pos + Vector2(0, -ACTIVE_LIFT), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        t.tween_property(v, "rotation", s.rot * 0.4, 0.2)
        t.tween_property(v, "scale", Vector2(1.10, 1.10), 0.2)
