class_name HokmPicker
extends Control
## Overlay where the human hakem picks the trump suit from their first 5 cards.

signal suit_chosen(suit: int)

var hand: Array[GameCard]


func _init(p_hand: Array[GameCard]) -> void:
    hand = p_hand.duplicate()


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(UIH.dim_overlay(0.72))

    var title := UIH.label("حکم را انتخاب کن", 54, UIH.GOLD, "Black", 6)
    title.position = Vector2(UIH.cx() - 300, UIH.vsize().y * 0.167)
    title.size = Vector2(600, 70)
    add_child(title)

    var sub := UIH.label("روی یکی از کارت‌هایت بزن؛ خال آن حکم می‌شود", 30, UIH.INK, "Medium")
    sub.position = Vector2(UIH.cx() - 400, UIH.vsize().y * 0.206)
    sub.size = Vector2(800, 44)
    add_child(sub)

    var n := hand.size()
    var mid := (n - 1) / 2.0
    for i in n:
        var c := hand[i]
        var holder := Control.new()
        var cs := CardView.size_px()
        holder.size = cs
        holder.position = Vector2(UIH.cx() - (i - mid) * 150.0 * UIH.us() - cs.x * 0.5, UIH.vsize().y * 0.29 + abs(i - mid) * 22.0 * UIH.us())
        holder.rotation = clampf((i - mid) * 0.06, -0.14, 0.14)
        holder.pivot_offset = cs * 0.5
        add_child(holder)
        var cv := CardView.new(c, false, "res://assets/back_classic.png")
        holder.add_child(cv)
        cv.flip_to(true, 0.25 + 0.08 * i)
        var chip := UIH.pill(GameCard.SUIT_NAMES[c.suit], 24, Color(GameCard.suit_color(c.suit), 0.92))
        chip.position = Vector2(cs.x * 0.29, -46.0)
        holder.add_child(chip)
        holder.mouse_filter = Control.MOUSE_FILTER_STOP
        holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        var idx := i
        holder.gui_input.connect(func(ev: InputEvent):
            if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
                Snd.sfx("card_flip", 0.9)
                var t := create_tween()
                t.tween_property(holder, "scale", Vector2(1.15, 1.15), 0.12)
                t.parallel().tween_property(holder, "modulate", Color(1.3, 1.25, 1.0), 0.12)
                t.tween_callback(func(): suit_chosen.emit(hand[idx].suit))
                mouse_filter = Control.MOUSE_FILTER_STOP)
