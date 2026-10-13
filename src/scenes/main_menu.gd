extends Control
## Main menu: classic / fantasy / hotspot / settings.

var title_card: TextureRect
var mode_overlay: Control = null
var settings_panel: Control = null
var version_l: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    Snd.apply_volumes()
    Snd.play_music("main")

    var bg := UIH.tex_rect("res://assets/bg/bg_main.jpg", Vector2(1080, 1920))
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(bg)
    add_child(UIH.vignette())

    # decorative joker card, gently floating
    var deco := UIH.tex_rect("res://assets/joker.png", Vector2(300, 450))
    deco.position = Vector2(UIH.vsize().x - 380, 240)
    deco.rotation_degrees = 10
    deco.modulate = Color(1, 1, 1, 0.9)
    add_child(deco)
    var tw := create_tween()
    tw.set_loops()
    tw.tween_property(deco, "position:y", 260.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_property(deco, "position:y", 240.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

    var title := UIH.label("حکم شیر", 150, UIH.GOLD, "Black", 14)
    title.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.167)
    title.size = Vector2(900, 180)
    add_child(title)
    title.pivot_offset = Vector2(450, 90)
    title.scale = Vector2(0.4, 0.4)
    var tt := title.create_tween()
    tt.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

    var sub := UIH.label("بازی سنتی حکم — کلاسیک، فانتزی و آنلاینِ محلی", 34, UIH.INK, "Medium")
    sub.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.26)
    sub.size = Vector2(900, 50)
    add_child(sub)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 30)
    box.position = Vector2(UIH.cx() - 300, UIH.vsize().y * 0.365)
    box.custom_minimum_size = Vector2(600, 0)
    add_child(box)

    box.add_child(UIH.text_btn("بازی کلاسیک (۴ نفره)", Vector2(600, 140), func(): _open_classic(), 44, true))
    box.add_child(UIH.text_btn("حالت فانتزی (۴ تا ۸ نفره)", Vector2(600, 140), func(): _open_fantasy(), 44, true))
    box.add_child(UIH.text_btn("چندنفره با هات‌اسپات", Vector2(600, 140), func(): _go_lobby(), 44, true))
    box.add_child(UIH.text_btn("تنظیمات", Vector2(600, 120), func(): _open_settings(), 38, false))

    version_l = UIH.label("نسخه ۱.۰ — ساخته‌شده با Godot", 24, Color(1, 1, 1, 0.45), "Medium")
    version_l.position = Vector2(UIH.cx() - 250, UIH.vsize().y - 90)
    version_l.size = Vector2(500, 40)
    add_child(version_l)


func _open_classic() -> void:
    _show_level_picker("classic", 4)


func _open_fantasy() -> void:
    _show_count_picker()


func _go_lobby() -> void:
    get_tree().change_scene_to_file("res://src/scenes/lobby.tscn")


func _show_level_picker(mode: String, count: int) -> void:
    _close_overlays()
    mode_overlay = UIH.dim_overlay(0.75)
    add_child(mode_overlay)
    Snd.sfx("open", 1.0, -8.0)
    var t := UIH.label("سطح هوش مصنوعی را انتخاب کن", 48, UIH.GOLD, "Black")
    t.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.198)
    t.size = Vector2(900, 70)
    mode_overlay.add_child(t)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 22)
    box.position = Vector2(UIH.cx() - 400, UIH.vsize().y * 0.26)
    box.custom_minimum_size = Vector2(800, 0)
    mode_overlay.add_child(box)
    var descs := [
        "حرکت‌های ساده و شانسی",
        "منطق پایه بازی را می‌فهمد",
        "حریفی جدی و منظم",
        "کارت‌ها را می‌شمارد و نقشه می‌کشد",
        "بی‌رحم؛ حافظه کامل و بازی بهینه",
    ]
    for lv in 5:
        var row := UIH.text_btn(S.AI_LEVEL_NAMES[lv] + "  —  " + descs[lv], Vector2(800, 118),
            func(): _start(mode, count, lv), 32, lv % 2 == 0)
        box.add_child(row)
    var back := UIH.text_btn("بازگشت", Vector2(300, 90), func(): _close_overlays(), 30, false)
    back.position = Vector2(UIH.cx() - 150, UIH.vsize().y - 330)
    mode_overlay.add_child(back)


func _show_count_picker() -> void:
    _close_overlays()
    mode_overlay = UIH.dim_overlay(0.75)
    add_child(mode_overlay)
    Snd.sfx("open", 1.0, -8.0)
    var t := UIH.label("چند نفره بازی می‌کنی؟", 48, UIH.GOLD, "Black")
    t.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.219)
    t.size = Vector2(900, 70)
    mode_overlay.add_child(t)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 20)
    row.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.302)
    row.custom_minimum_size = Vector2(900, 0)
    mode_overlay.add_child(row)
    for n in range(4, 9):
        var b := UIH.text_btn(S.fa(n), Vector2(160, 160), func(): _show_level_picker("fantasy", n), 52, n % 2 == 0)
        row.add_child(b)
    var info := UIH.label("در حالت فانتزی، هر بازیکن یک کارت ویژه می‌گیرد و ایونت‌های تکاملی فعال می‌شوند", 28, UIH.INK, "Medium")
    info.position = Vector2(UIH.cx() - 450, UIH.vsize().y * 0.427)
    info.size = Vector2(900, 80)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mode_overlay.add_child(info)
    var back := UIH.text_btn("بازگشت", Vector2(300, 90), func(): _close_overlays(), 30, false)
    back.position = Vector2(UIH.cx() - 150, UIH.vsize().y - 330)
    mode_overlay.add_child(back)


func _start(mode: String, count: int, level: int) -> void:
    S.last_mode = mode
    S.last_level = level
    S.save_settings()
    S.last_game_cfg = {"mode": mode, "level": level, "net": false, "count": count}
    get_tree().change_scene_to_file("res://src/scenes/game.tscn")


func _open_settings() -> void:
    if settings_panel != null:
        return
    Snd.sfx("open", 1.0, -8.0)
    settings_panel = UIH.dim_overlay(0.75)
    add_child(settings_panel)
    var panel := Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.11, 0.24, 0.97)
    sb.set_corner_radius_all(40)
    panel.add_theme_stylebox_override("panel", sb)
    var vs := UIH.vsize()
    panel.position = Vector2((vs.x - 840) * 0.5, maxf(40.0, (vs.y - 1160) * 0.5 - 20.0))
    panel.size = Vector2(840, 1160)
    settings_panel.add_child(panel)

    var t := UIH.label("تنظیمات", 54, UIH.GOLD, "Black")
    t.position = Vector2(0, 40)
    t.size = Vector2(840, 70)
    panel.add_child(t)

    var nl := UIH.label("اسم تو:", 32, UIH.INK, "Bold")
    nl.position = Vector2(620, 150)
    nl.size = Vector2(180, 50)
    panel.add_child(nl)
    var name_edit := LineEdit.new()
    name_edit.text = S.player_name
    name_edit.position = Vector2(120, 145)
    name_edit.size = Vector2(460, 62)
    name_edit.add_theme_font_override("font", UIH.font("Bold"))
    name_edit.add_theme_font_size_override("font_size", 30)
    name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_edit.text_changed.connect(func(v: String): S.player_name = v)
    panel.add_child(name_edit)

    var rows := [
        ["صدای کل", S.master_vol],
        ["موسیقی", S.music_vol],
        ["جلوه‌های صوتی", S.sfx_vol],
    ]
    var y := 260
    for r in rows:
        var lbl := UIH.label(str(r[0]), 30, UIH.INK, "Bold")
        lbl.position = Vector2(520, y)
        lbl.size = Vector2(280, 46)
        panel.add_child(lbl)
        var sl := HSlider.new()
        sl.min_value = 0.0
        sl.max_value = 1.0
        sl.step = 0.05
        sl.value = float(r[1])
        sl.position = Vector2(110, y + 4)
        sl.size = Vector2(390, 40)
        var key: String = ["master_vol", "music_vol", "sfx_vol"][rows.find(r)]
        sl.value_changed.connect(func(v: float):
            S.set(key, v)
            Snd.apply_volumes())
        panel.add_child(sl)
        y += 90

    var fast := CheckBox.new()
    fast.text = "هوش مصنوعی سریع‌تر"
    fast.button_pressed = S.fast_ai
    fast.add_theme_font_override("font", UIH.font("Bold"))
    fast.add_theme_font_size_override("font_size", 30)
    fast.position = Vector2(220, y + 20)
    fast.size = Vector2(500, 60)
    fast.toggled.connect(func(v: bool): S.fast_ai = v)
    panel.add_child(fast)

    var ok := UIH.text_btn("ذخیره و بستن", Vector2(440, 110), func():
        S.save_settings()
        _close_overlays(), 36, true)
    ok.position = Vector2(200, 990)
    panel.add_child(ok)


func _close_overlays() -> void:
    var closed := false
    if mode_overlay != null:
        mode_overlay.queue_free()
        mode_overlay = null
        closed = true
    if settings_panel != null:
        settings_panel.queue_free()
        settings_panel = null
        closed = true
    if closed:
        Snd.sfx("close", 1.0, -10.0)
