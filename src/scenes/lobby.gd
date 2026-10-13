extends Control
## Hotspot / LAN lobby: host a table or join a discovered one.

var mode := ""  # "" | "host" | "join"
var body: Control
var status_l: Label
var players_box: VBoxContainer
var rooms_box: VBoxContainer
var start_btn: TextureButton
var scan_l: Label
var ip_edit: LineEdit


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    Snd.play_music("main")

    var bg := UIH.tex_rect("res://assets/bg/bg_main.jpg", Vector2(1080, 1920))
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(bg)
    add_child(UIH.dim_overlay(0.5))

    var t := UIH.label("بازی چندنفره (هات‌اسپات)", 60, UIH.GOLD, "Black", 8)
    t.position = Vector2(90, 200)
    t.size = Vector2(900, 90)
    add_child(t)

    var info := UIH.label("هر دو گوشی باید به یک وای‌فای یا هات‌اسپات یکسان وصل باشند", 30, UIH.INK, "Medium")
    info.position = Vector2(90, 300)
    info.size = Vector2(900, 50)
    add_child(info)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 30)
    row.position = Vector2(90, 420)
    row.custom_minimum_size = Vector2(900, 0)
    add_child(row)
    row.add_child(UIH.text_btn("ساخت میز", Vector2(435, 130), func(): _host(), 40, true))
    row.add_child(UIH.text_btn("پیوستن به میز", Vector2(435, 130), func(): _join_mode(), 40, true))

    status_l = UIH.label("", 32, UIH.GOLD_DIM, "Bold")
    status_l.position = Vector2(90, 590)
    status_l.size = Vector2(900, 50)
    add_child(status_l)

    body = Control.new()
    body.set_anchors_preset(Control.PRESET_FULL_RECT)
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(body)

    var back := UIH.tex_btn("res://assets/btn/btn_back.png", Vector2(110, 110), func(): _back())
    back.position = Vector2(20, 20)
    add_child(back)

    Net.cmd_received.connect(_on_net_cmd)
    Net.lobby_changed.connect(_refresh_host_list)
    Net.rooms_changed.connect(_refresh_rooms)
    Net.joined_ok.connect(func(): _set_status("وصل شدی! منتظر شروع بازی توسط میزبان..."))
    Net.join_failed.connect(func(r: String): _set_status("خطا: " + r))
    Net.server_lost.connect(func():
        _set_status("ارتباط با میزبان قطع شد")
        _back())


func _set_status(s: String) -> void:
    status_l.text = s


func _back() -> void:
    Net.stop_all()
    get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")


# ---------------- host ----------------

func _host() -> void:
    if not Net.start_host(S.player_name):
        _set_status("ساخت میز ممکن نشد؛ دوباره تلاش کن")
        return
    mode = "host"
    _set_status("میز ساخته شد — منتظر بازیکن‌ها...")
    _build_host_ui()
    _refresh_host_list()


func _build_host_ui() -> void:
    for c in body.get_children():
        c.queue_free()
    var pl := UIH.label("بازیکن‌های میز:", 40, UIH.GOLD, "Black")
    pl.position = Vector2(90, 700)
    pl.size = Vector2(900, 60)
    body.add_child(pl)
    players_box = VBoxContainer.new()
    players_box.add_theme_constant_override("separation", 14)
    players_box.position = Vector2(140, 780)
    players_box.custom_minimum_size = Vector2(800, 0)
    body.add_child(players_box)
    var note := UIH.label("صندلی‌های خالی با هوش مصنوعی (سطح «بازیکن») پر می‌شوند", 26, UIH.INK, "Medium")
    note.position = Vector2(90, 1140)
    note.size = Vector2(900, 44)
    body.add_child(note)
    start_btn = UIH.text_btn("شروع بازی", Vector2(600, 140), func(): _start_game(), 44, true)
    start_btn.position = Vector2(240, 1560)
    start_btn.disabled = true
    body.add_child(start_btn)


func _refresh_host_list() -> void:
    if mode != "host" or players_box == null:
        return
    for c in players_box.get_children():
        c.queue_free()
    for p in Net.lobby_players:
        players_box.add_child(UIH.pill(str(p.name), 30, Color(0.14, 0.2, 0.38, 0.92)))
    if Net.lobby_players.size() >= 2 and start_btn != null:
        start_btn.disabled = false
    # announce to clients
    if Net.is_server:
        var names := []
        for p in Net.lobby_players:
            names.append(str(p.name))
        Net.broadcast_cmd("lobby", {"names": names})


func _start_game() -> void:
    if Net.lobby_players.size() < 2:
        return
    var peers := [1]
    var names := [S.player_name]
    for p in Net.lobby_players:
        if p.peer != 1:
            peers.append(int(p.peer))
            names.append(str(p.name))
    while peers.size() < 4:
        peers.append(0)
        names.append("")
    var sp := {}
    for i in peers.size():
        if peers[i] != 0:
            sp[i] = {"peer": peers[i], "name": names[i]}
    Net.broadcast_cmd("start", {"peers": peers, "names": names})
    Net.game_cfg = {"mode": "classic", "net": true, "count": 4, "my_seat": 0, "seat_peers": sp}
    get_tree().change_scene_to_file("res://src/scenes/game.tscn")


# ---------------- join ----------------

func _join_mode() -> void:
    mode = "join"
    _set_status("در حال جستجوی میزها...")
    Net.start_scan()
    for c in body.get_children():
        c.queue_free()
    var rl := UIH.label("میزهای پیدا شده:", 40, UIH.GOLD, "Black")
    rl.position = Vector2(90, 700)
    rl.size = Vector2(900, 60)
    body.add_child(rl)
    rooms_box = VBoxContainer.new()
    rooms_box.add_theme_constant_override("separation", 16)
    rooms_box.position = Vector2(140, 780)
    rooms_box.custom_minimum_size = Vector2(800, 0)
    body.add_child(rooms_box)
    var ml := UIH.label("یا ورود دستی با IP (مثلاً 192.168.43.1):", 30, UIH.INK, "Bold")
    ml.position = Vector2(90, 1180)
    ml.size = Vector2(900, 46)
    body.add_child(ml)
    ip_edit = LineEdit.new()
    ip_edit.text = "192.168.43.1"
    ip_edit.position = Vector2(140, 1240)
    ip_edit.size = Vector2(500, 66)
    ip_edit.add_theme_font_override("font", UIH.font("Bold"))
    ip_edit.add_theme_font_size_override("font_size", 30)
    ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.add_child(ip_edit)
    var jb := UIH.text_btn("ورود", Vector2(220, 66), func(): _join_ip(), 30, true)
    jb.position = Vector2(680, 1240)
    body.add_child(jb)
    _refresh_rooms()


func _refresh_rooms() -> void:
    if mode != "join" or rooms_box == null:
        return
    for c in rooms_box.get_children():
        c.queue_free()
    if Net.found_rooms.is_empty():
        rooms_box.add_child(UIH.pill("هنوز میزی پیدا نشد...", 28, Color(0.2, 0.22, 0.32, 0.9)))
    for r in Net.found_rooms:
        var nm := "%s  (%s نفر)" % [str(r.name), S.fa(int(r.players))]
        var ip := str(r.ip)
        var b := UIH.text_btn(nm, Vector2(800, 100), func(): _join_ip(ip), 32, true)
        rooms_box.add_child(b)


func _join_ip(ip := "") -> void:
    if ip == "" and ip_edit != null:
        ip = ip_edit.text.strip_edges()
    if ip == "":
        return
    _set_status("در حال اتصال به " + ip + " ...")
    Net.join(ip, S.player_name)


# ---------------- commands from host ----------------

func _on_net_cmd(cmd: String, data: Dictionary) -> void:
    match cmd:
        "lobby":
            if mode == "join":
                _set_status("بازیکن‌های میز: " + ", ".join(PackedStringArray(data.names)))
        "start":
            var peers: Array = data.peers
            var names: Array = data.names
            var my_id := multiplayer.get_unique_id()
            var my := peers.find(my_id)
            if my < 0:
                return
            var sp := {}
            for i in peers.size():
                if int(peers[i]) != 0:
                    sp[i] = {"peer": int(peers[i]), "name": str(names[i])}
            Net.game_cfg = {"mode": "classic", "net": true, "count": peers.size(), "my_seat": my, "seat_peers": sp}
            get_tree().change_scene_to_file("res://src/scenes/game.tscn")
