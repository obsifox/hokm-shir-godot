extends Control
## Main game table - classic & fantasy Hokm, solo or LAN multiplayer.

const SP_DEAL_TEX := [0, 1, 2, 3, 4, 5]  # ids that can be dealt as Sp cards

var state: GameState
var cfg: Dictionary = {}
var my_seat := 0
var is_net := false
var am_server := true
var phase := "idle"

# UI
var bg: TextureRect
var fan: HandFan
var trick_area: TrickArea
var hud: GameHud
var banner: EventBanner
var emotes: EmoteBar
var avatars := {}            # absolute seat -> AvatarView
var sp_slot: Control
var sp_view: CardView = null
var sp_label: Label
var pause_menu: Control
var results: ResultsOverlay
var toast_l: Label
var _toast_tween: Tween

# server-side human-input sync
signal sig_human_card
signal sig_human_hokm
var _human_card: GameCard = null
var _human_hokm := -1
var _awaiting_input := false
var _pending_hand: Array[GameCard] = []

# sp targeting
var _picking_target := false
var _target_sp := -1
var _my_sp_id := -1


func set_cfg(c: Dictionary) -> void:
    cfg = c


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_scene()
    Snd.apply_volumes()
    Net.game = self
    var BGS := ["res://assets/bg/bg_gameplay_one.jpg", "res://assets/bg/bg_gameplay_two.jpg", "res://assets/bg/bg_gameplay_three.jpg"]
    bg.texture = load(BGS[S.rng.randi_range(0, 2)])
    if cfg.is_empty():
        cfg = Net.game_cfg
        Net.game_cfg = {}
    if cfg.is_empty():
        cfg = S.last_game_cfg
    if cfg.is_empty():
        cfg = {"mode": "classic", "level": 2, "net": false, "count": 4}
    is_net = bool(cfg.get("net", false))
    am_server = (not is_net) or Net.is_server
    my_seat = int(cfg.get("my_seat", 0))
    _start_match()


func _build_scene() -> void:
    bg = UIH.tex_rect("", Vector2(1080, 1920))
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(bg)
    add_child(UIH.vignette())

    trick_area = TrickArea.new()
    trick_area.setup(self)
    add_child(trick_area)

    fan = HandFan.new()
    add_child(fan)
    fan.play_requested.connect(_local_try_play)

    hud = GameHud.new()
    add_child(hud)
    hud.sort_pressed.connect(_on_sort)
    hud.sound_pressed.connect(_on_sound_toggle)
    hud.menu_pressed.connect(_on_pause)

    banner = EventBanner.new()
    add_child(banner)

    emotes = EmoteBar.new()
    add_child(emotes)
    emotes.react_picked.connect(_local_react)

    _build_sp_slot()

    toast_l = UIH.label("", 34, UIH.INK, "Bold", 5)
    toast_l.position = Vector2(540 - 400, 1150)
    toast_l.size = Vector2(800, 50)
    toast_l.modulate.a = 0.0
    add_child(toast_l)


func _build_sp_slot() -> void:
    sp_slot = Control.new()
    sp_slot.position = Vector2(820, 1540)
    sp_slot.size = Vector2(200, 300)
    sp_slot.mouse_filter = Control.MOUSE_FILTER_STOP
    sp_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    sp_slot.visible = false
    add_child(sp_slot)
    sp_slot.gui_input.connect(func(ev: InputEvent):
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            _local_use_sp())
    sp_label = UIH.label("کارت ویژه", 24, UIH.GOLD, "Bold", 4)
    sp_label.position = Vector2(0, 262)
    sp_label.size = Vector2(200, 34)
    sp_slot.add_child(sp_label)


# ================= match start =================

func _start_match() -> void:
    S.last_game_cfg = cfg
    state = GameState.new()
    var mode := GameState.Mode.CLASSIC if str(cfg.get("mode", "classic")) == "classic" else GameState.Mode.FANTASY
    var count := int(cfg.get("count", 4))
    if not is_net:
        state.setup(mode, count, S.player_name, int(cfg.get("level", 2)))
    else:
        var seat_peers: Dictionary = cfg.get("seat_peers", {})
        state.setup(mode, count, S.player_name, 0, seat_peers)
    Snd.play_music("gameplay")
    _build_avatars()
    _refresh_scores()
    if am_server:
        _match_loop()


func _build_avatars() -> void:
    for k in avatars:
        avatars[k].queue_free()
    avatars.clear()
    var n: int = state.player_count
    for seat in n:
        var rel := posmod(seat - my_seat, n)
        if rel == 0:
            continue
        var p: Dictionary = state.players[seat]
        var a := AvatarView.new(seat, str(p.name), bool(p.is_ai))
        avatars[seat] = a
        a.position = _avatar_position(rel, n)
        a.size = AvatarView.SIZE
        add_child(a)
        a.gui_input.connect(_on_avatar_pick_input.bind(seat))


func _avatar_position(rel: int, n: int) -> Vector2:
    var d := trick_area.seat_dir(rel, n)
    var pos := Vector2(540 + d.x * 500.0, 880 + d.y * 690.0)
    pos.x = clampf(pos.x, 150.0, 930.0)
    pos.y = clampf(pos.y, 200.0, 1400.0)
    pos -= AvatarView.SIZE / 2.0
    pos.y -= 20.0
    return pos


func _rel(seat: int) -> int:
    return posmod(seat - my_seat, state.player_count)


# ================= small UI helpers =================

func toast(msg: String, dur := 1.6) -> void:
    toast_l.text = msg
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    toast_l.modulate.a = 0.0
    _toast_tween = create_tween()
    _toast_tween.tween_property(toast_l, "modulate:a", 1.0, 0.2)
    _toast_tween.tween_interval(dur)
    _toast_tween.tween_property(toast_l, "modulate:a", 0.0, 0.4)


func _on_sort() -> void:
    if fan.views.is_empty():
        return
    var mode_name: String = fan.sort()
    toast(mode_name)


func _on_sound_toggle() -> void:
    Snd.toggle_mute()
    toast("صدا: " + ("خاموش" if S.muted else "روشن"))


func _on_pause() -> void:
    if pause_menu != null:
        return
    pause_menu = UIH.dim_overlay(0.7)
    add_child(pause_menu)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 26)
    box.position = Vector2(540 - 220, 640)
    box.custom_minimum_size = Vector2(440, 0)
    pause_menu.add_child(box)
    var t := UIH.label("توقف", 60, UIH.GOLD, "Black")
    box.add_child(t)
    var resume := UIH.text_btn("ادامه بازی", Vector2(440, 120), func(): _close_pause())
    box.add_child(resume)
    var mute := UIH.text_btn("قطع / وصل صدا", Vector2(440, 120), func(): _on_sound_toggle())
    box.add_child(mute)
    var quit := UIH.text_btn("خروج به منو", Vector2(440, 120), func(): _quit_to_menu(), 40, false)
    box.add_child(quit)


func _close_pause() -> void:
    if pause_menu != null:
        pause_menu.queue_free()
        pause_menu = null


func _quit_to_menu() -> void:
    Net.stop_all()
    Snd.play_music("main")
    get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")


func _avatar_center(seat: int) -> Vector2:
    if avatars.has(seat):
        return avatars[seat].position + AvatarView.SIZE / 2.0
    return Vector2(540, 1600)


func _refresh_scores() -> void:
    var pills: Array = []
    if state.mode == GameState.Mode.CLASSIC:
        var my_team := state.team_of(my_seat)
        for team in 2:
            var nm := "تیم ما" if team == my_team else "تیم حریف"
            var pts := 0
            for p in state.players:
                if state.team_of(p.seat) == team:
                    pts += p.score
            var tricks := state.team_tricks(team)
            var pl := UIH.pill("%s   دنگ %s | ست %s" % [nm, S.fa(tricks), S.fa(pts)], 30,
                Color(0.14, 0.2, 0.38, 0.92) if team == my_team else Color(0.4, 0.14, 0.16, 0.92))
            pills.append(pl)
    else:
        for p in state.players:
            var pl := UIH.pill("%s %s" % [p.name, S.fa(p.tricks)], 26,
                Color(0.14, 0.2, 0.38, 0.92) if p.seat == my_seat else Color(0.35, 0.13, 0.15, 0.92))
            pills.append(pl)
    hud.set_scores(pills)


func _refresh_all_tricks() -> void:
    for seat in avatars:
        avatars[seat].set_tricks(state.players[seat].tricks)
    _refresh_scores()


func _set_my_sp(id: int) -> void:
    _my_sp_id = id
    if id < 0:
        sp_slot.visible = false
        if sp_view != null:
            sp_view.queue_free()
            sp_view = null
        return
    sp_slot.visible = true
    if sp_view != null:
        sp_view.queue_free()
    var fake := GameCard.make(0, 0)
    fake.kind = "sp_dummy"
    sp_view = CardView.new(fake, true)
    var t: Texture2D = load(Deck.sp_tex(id))
    sp_view.front.texture = t
    sp_view.shadow.texture = t
    sp_view.scale = Vector2(0.68, 0.68)
    sp_slot.add_child(sp_view)
    sp_view.pop_in()


# ================= SERVER MATCH LOOP =================

func _match_loop() -> void:
    while not state.match_over:
        await _hand_loop()
        if state.match_over:
            break
    await _show_results()


func _hand_loop() -> void:
    state.hand_num += 1
    state.reset_hand_tracking()
    state.hokm = -1
    _refresh_scores()
    _net("hand_start", {"hand": state.hand_num})

    var deck := _build_deck()
    Deck.shuffle(deck, state.rng)

    # fantasy event roll
    if state.mode == GameState.Mode.FANTASY and state.hand_num >= 2 and state.rng.randf() < 0.45:
        var evs := Deck.ev_ids()
        var ev: int = evs[state.rng.randi_range(0, evs.size() - 1)]
        await _apply_event(ev)

    # wave 1: 5 cards each
    for i in 5:
        for s in state.player_count:
            var c: GameCard = deck.pop_back()
            state.players[s].hand.append(c)
    await _anim_deal_wave(true)

    # hokm pick
    await _hokm_phase()

    # wave 2
    var per := state.hand_size() - 5
    for i in per:
        for s in state.player_count:
            var c2: GameCard = deck.pop_back()
            state.players[s].hand.append(c2)
    await _anim_deal_wave(false)

    # fantasy: deal one Sp card per player
    if state.mode == GameState.Mode.FANTASY:
        var sp_pool := SP_DEAL_TEX.duplicate()
        for s in state.player_count:
            state.players[s].sp = sp_pool[state.rng.randi_range(0, sp_pool.size() - 1)]
        _give_sp_visuals()
        for s in state.player_count:
            var pr: int = state.players[s].peer
            if pr > 1:
                Net.send_cmd_to(pr, "sp_deal", {"sp": state.players[s].sp})
        await get_tree().create_timer(1.0).timeout

    # tricks
    var leader := state.next_seat(state.hakem)
    var tricks_total := state.tricks_in_hand()
    for t in tricks_total:
        if state.match_over:
            return
        state.trick_num = t + 1
        state.trick.clear()
        var seat := leader
        for k in state.player_count:
            state.turn = seat
            await _turn_begin(seat)
            var played := await _get_card(seat)
            state.trick.append({"seat": seat, "card": played.card, "golden_by": seat if played.get("golden", false) else -1})
            state.hand_history.append({"seat": seat, "card": played.card, "is_lead": k == 0})
            state.players[seat].hand.erase(played.card)
            state.players[seat].golden_pending = false
            await _v_play(seat, played.card, seat == my_seat)
            _net("play", {"seat": seat, "card": played.card.to_dict(), "self": seat == my_seat})
            seat = state.next_seat(seat)
        var wi := Rules.trick_winner_index(state.trick, state.hokm)
        var winner: int = state.trick[wi].seat
        var pts := 1
        for e in state.trick:
            if e.golden_by >= 0 and e.golden_by == winner:
                pts = 2
        for e in state.trick:
            if e.card.is_face():
                state.players[e.seat].face_taken += 1
        state.players[winner].tricks += pts
        _net("trick_end", {"winner": winner, "pts": pts, "my_tricks": _tricks_snapshot()})
        await _v_trick_end(winner, pts)
        leader = winner
    await _hand_end()


func _build_deck() -> Array[GameCard]:
    if state.mode == GameState.Mode.CLASSIC:
        return Deck.standard_52()
    return Deck.fantasy_deck(state.player_count)


func _tricks_snapshot() -> Array:
    var out := []
    for p in state.players:
        out.append(p.tricks)
    return out


func _apply_event(ev: int) -> void:
    state.event_id = ev
    match ev:
        1:
            pass
        2:
            state.turn_dir = -1
        3:
            state.hakem = state.next_seat(state.next_seat(state.hakem))
        0:
            state.forbidden_suit = state.rng.randi_range(0, 3)
            state.forbidden_left = 3
    _net("event", {"ev": ev})
    _v_event(ev, Deck.ev_name(ev), Deck.ev_desc(ev))
    await get_tree().create_timer(2.4).timeout


func _anim_deal_wave(first: bool) -> void:
    phase = "dealing"
    var hand_all: Array[GameCard] = state.players[my_seat].hand
    var my_new: Array[GameCard] = hand_all.duplicate() if first else hand_all.slice(5)
    if first:
        fan.set_hand(my_new, true)
        fan.set_input_enabled(false)
    else:
        fan.add_cards(my_new)
    if is_net and am_server:
        for s in state.player_count:
            var pr: int = state.players[s].peer
            if pr > 1:
                var to_send: Array = state.players[s].hand if first else state.players[s].hand.slice(5)
                Net.send_cmd_to(pr, "set_hand", {"cards": _cards_dict(to_send)})
    for seat in avatars:
        var a: AvatarView = avatars[seat]
        var tw := a.create_tween()
        tw.tween_property(a, "scale", Vector2(1.05, 1.05), 0.08)
        tw.tween_property(a, "scale", Vector2.ONE, 0.08)
    var cnt := state.hand_size() if first else state.hand_size() - 5
    await get_tree().create_timer(0.055 * cnt + 0.55).timeout
    _net("deal1" if first else "deal2", {})


func _give_sp_visuals() -> void:
    for seat in state.player_count:
        var sp: int = state.players[seat].sp
        if seat == my_seat:
            _set_my_sp(sp)
        elif avatars.has(seat):
            avatars[seat].show_status("کارت ویژه گرفت", Color(0.5, 0.3, 0.6, 0.92), 1.4)


func _hokm_phase() -> void:
    phase = "hokm"
    Snd.play_music("hokm")
    _net("hokm_phase", {"hakem": state.hakem})
    _v_hokm_phase(state.hakem, false)
    var suit := -1
    var hk: Dictionary = state.players[state.hakem]
    if hk.is_ai:
        if avatars.has(state.hakem):
            avatars[state.hakem].show_thinking()
        await get_tree().create_timer(S.ai_delay() + 0.6).timeout
        suit = AIBrain.choose_hokm(state, state.hakem)
    elif state.hakem == my_seat:
        suit = await _await_local_hokm()
    else:
        _human_hokm = -1
        _awaiting_input = true
        while _human_hokm < 0:
            await sig_human_hokm
        suit = _human_hokm
        _awaiting_input = false
    state.hokm = suit
    _net("hokm_chosen", {"suit": suit, "by": state.hakem})
    _v_hokm_chosen(suit)
    await get_tree().create_timer(1.5).timeout
    Snd.play_music("gameplay")


func _await_local_hokm() -> int:
    _human_hokm = -1
    _show_hokm_picker()
    while _human_hokm < 0:
        await sig_human_hokm
    return _human_hokm


func _show_hokm_picker() -> void:
    fan.set_input_enabled(false)
    var picker := HokmPicker.new(state.players[my_seat].hand)
    add_child(picker)
    picker.suit_chosen.connect(func(suit: int):
        _human_hokm = suit
        if is_net and not am_server:
            Net.send_to_server("pick_hokm", {"suit": suit})
        sig_human_hokm.emit()
        picker.queue_free())


func _turn_begin(seat: int) -> void:
    _v_turn(seat)
    _net("turn", {"seat": seat})
    if seat != my_seat:
        await get_tree().create_timer(S.ai_delay()).timeout


func _get_card(seat: int) -> Dictionary:
    var p: Dictionary = state.players[seat]
    if p.is_ai and state.mode == GameState.Mode.FANTASY:
        var want := AIBrain.want_sp(state, seat)
        if not want.is_empty():
            await _resolve_sp(seat, int(want.sp), int(want.target))
    var card: GameCard
    if p.is_ai:
        card = AIBrain.choose_card(state, seat)
    elif seat == my_seat:
        card = await _await_local_card()
    else:
        _human_card = null
        _awaiting_input = true
        while _human_card == null:
            await sig_human_card
        card = _human_card
        _awaiting_input = false
    var golden: bool = p.golden_pending
    return {"card": card, "golden": golden}


func _await_local_card() -> GameCard:
    fan.set_input_enabled(true)
    fan.set_hokm(state.hokm)
    _human_card = null
    _awaiting_input = true
    while _human_card == null:
        await sig_human_card
    _awaiting_input = false
    fan.set_input_enabled(false)
    return _human_card


func _legal_for(seat: int) -> Array[GameCard]:
    var p: Dictionary = state.players[seat]
    return Rules.legal_moves(p.hand, state.trick, state.hokm, state.forbidden_suit, state.forbidden_left, p.silenced)


func _resolve_sp(seat: int, sp: int, target: int) -> void:
    var p: Dictionary = state.players[seat]
    p.sp = -1
    var payload := {}
    match sp:
        0:
            p.shield = true
        1:
            if state.players[target].shield:
                state.players[target].shield = false
                target = -1
            else:
                state.players[target].silenced = true
        2:
            if state.players[target].shield:
                state.players[target].shield = false
                target = -1
            else:
                var mine: Array[GameCard] = p.hand
                var lowest: GameCard = null
                for c in mine:
                    if c.is_joker():
                        continue
                    if lowest == null or c.rank < lowest.rank:
                        lowest = c
                if lowest != null:
                    var theirs: Array[GameCard] = state.players[target].hand
                    if not theirs.is_empty():
                        var got: GameCard = theirs[state.rng.randi_range(0, theirs.size() - 1)]
                        mine.erase(lowest)
                        mine.append(got)
                        theirs.erase(got)
                        theirs.append(lowest)
                        payload = {"got": got.to_dict()}
                        if seat == my_seat:
                            fan.set_hand(mine.duplicate())
                        if target == my_seat:
                            fan.set_hand(state.players[my_seat].hand.duplicate())
                        if state.players[target].peer > 1:
                            Net.send_cmd_to(state.players[target].peer, "sync_hand", {"cards": _cards_dict(state.players[target].hand)})
                        if state.players[seat].peer > 1:
                            Net.send_cmd_to(state.players[seat].peer, "sync_hand", {"cards": _cards_dict(state.players[seat].hand)})
        3:
            var th: Array[GameCard] = state.players[target].hand
            if not th.is_empty():
                var seen: GameCard = th[state.rng.randi_range(0, th.size() - 1)]
                payload = {"card": seen.to_dict()}
        4:
            p.double = true
        5:
            p.golden_pending = true
    _net("sp", {"seat": seat, "sp": sp, "target": target})
    if sp == 3 and state.players[seat].peer > 1:
        Net.send_cmd_to(state.players[seat].peer, "sp", {"seat": seat, "sp": sp, "target": target, "payload": payload})
    _v_sp(seat, sp, target, payload)
    await get_tree().create_timer(1.1).timeout


func _cards_dict(hand: Array[GameCard]) -> Array:
    var out := []
    for c in hand:
        out.append(c.to_dict())
    return out


# ================= HAND END & RESULTS =================

func _hand_end() -> void:
    phase = "hand_end"
    fan.set_input_enabled(false)
    var msg := ""
    var kot := false
    var won_side := -1
    if state.mode == GameState.Mode.CLASSIC:
        var t0 := state.team_tricks(0)
        var t1 := state.team_tricks(1)
        var win_team := 0 if t0 >= 7 else 1
        var lose := t1 if win_team == 0 else t0
        var pts := 2 if lose == 0 else 1
        kot = lose == 0
        for p in state.players:
            if state.team_of(p.seat) == win_team and p.double:
                pts *= 2
        for p in state.players:
            if state.team_of(p.seat) == win_team:
                p.score += pts
        var hakem_team := state.team_of(state.hakem)
        if hakem_team != win_team:
            state.hakem = state.next_seat(state.hakem)
        won_side = win_team
        msg = "دست را بردیم!" if win_team == state.team_of(my_seat) else "دست را باختیم!"
    else:
        var best := 0
        for p in state.players:
            best = maxi(best, p.tricks)
        var winners: Array[int] = []
        for p in state.players:
            if p.tricks == best:
                winners.append(p.seat)
        if state.event_id == 1:
            var bf := 0
            for p in state.players:
                bf = maxi(bf, p.face_taken)
            for p in state.players:
                if p.face_taken == bf and bf >= 4:
                    p.score += 1
                    if p.seat == my_seat:
                        msg = "پاداش دست طلایی!"
        for s in winners:
            var pp: Dictionary = state.players[s]
            var pt := 2 if pp.double else 1
            pp.score += pt
            if s == my_seat and msg == "":
                msg = "دست را بردی! +%s" % S.fa(pt)
        if msg == "":
            msg = "دست تمام شد"
        state.hakem = state.next_seat(state.hakem)
    var match_over := false
    if state.mode == GameState.Mode.CLASSIC:
        var s0 := 0
        var s1 := 0
        for p in state.players:
            if state.team_of(p.seat) == 0:
                s0 += p.score
            else:
                s1 += p.score
        match_over = s0 >= state.target_points or s1 >= state.target_points
    else:
        for p in state.players:
            if p.score >= state.target_points:
                match_over = true
    state.match_over = match_over
    var scores := []
    var tricks := []
    for p in state.players:
        scores.append(p.score)
        tricks.append(p.tricks)
    _net("hand_end", {"scores": scores, "tricks": tricks, "msg": msg, "kot": kot, "match_over": match_over, "won_side": won_side})
    _v_hand_end({"scores": scores, "tricks": tricks, "msg": msg, "kot": kot, "won_side": won_side})
    await get_tree().create_timer(3.0 if kot else 2.4).timeout


func _show_results() -> void:
    var won := false
    var title := ""
    var lines := []
    if state.mode == GameState.Mode.CLASSIC:
        var s0 := 0
        var s1 := 0
        for p in state.players:
            if state.team_of(p.seat) == 0:
                s0 += p.score
            else:
                s1 += p.score
        var my_team := state.team_of(my_seat)
        var mine := s0 if my_team == 0 else s1
        var theirs := s1 if my_team == 0 else s0
        won = mine >= state.target_points
        title = "پیروزی!" if won else "شکست"
        lines = ["تیم ما: %s ست" % S.fa(mine), "تیم حریف: %s ست" % S.fa(theirs)]
    else:
        var best := 0
        for p in state.players:
            best = maxi(best, p.score)
        won = state.players[my_seat].score >= best and best >= state.target_points
        title = "پیروزی!" if won else "شکست"
        for p in state.players:
            lines.append("%s: %s امتیاز" % [p.name, S.fa(p.score)])
    Snd.play_music("victory" if won else "defeat")
    results = ResultsOverlay.new()
    add_child(results)
    results.setup(won, title, lines, true)
    if is_net:
        results.replay_pressed.connect(func(): _quit_to_menu())
    else:
        results.replay_pressed.connect(func(): get_tree().reload_current_scene())
    results.menu_pressed.connect(func(): _quit_to_menu())


# ================= SHARED VISUALS (server & client) =================

func _v_hokm_phase(hakem: int, show_picker_if_me := false) -> void:
    if avatars.has(hakem):
        avatars[hakem].show_thinking()
    if hakem == my_seat and show_picker_if_me:
        _show_hokm_picker()
    elif hakem != my_seat:
        banner.show_banner("انتخاب حکم", "حاکم دارد حکم را انتخاب می‌کند...", "", 1.8)


func _v_hokm_chosen(suit: int) -> void:
    for seat in avatars:
        avatars[seat].hide_thinking()
        avatars[seat].set_hakem(seat == state.hakem)
    hud.set_trump(suit)
    fan.set_hokm(suit)
    Snd.sfx("hokm_pick")
    banner.show_banner("حکم: " + GameCard.SUIT_NAMES[suit], "خال " + GameCard.SUIT_NAMES[suit] + " حکم این دست است",
        "res://assets/persian_cards/%s/%s_A.png" % [GameCard.suit_folder(suit), GameCard.SUIT_KEYS[suit]], 2.0)


func _v_event(ev: int, ev_name: String, desc: String) -> void:
    Snd.sfx("sp_use")
    banner.show_banner(ev_name, desc, Deck.ev_tex(ev), 2.2)


func _v_turn(seat: int) -> void:
    for s in avatars:
        avatars[s].set_turn(s == seat)
    if seat == my_seat:
        Snd.sfx("turn", 1.1, -6.0)
        fan.set_input_enabled(true)
        fan.set_hokm(state.hokm)


func _v_play(seat: int, card: GameCard, from_self: bool) -> void:
    var from_pos: Vector2
    if from_self:
        var info := fan.take_by_uid(card.uid)
        if not info.is_empty():
            from_pos = info.pos
        else:
            from_pos = Vector2(540, 1750)
        fan.set_input_enabled(false)
    else:
        from_pos = _avatar_center(seat)
    trick_area.play_card(seat, card, from_pos, true, not from_self)
    if state.trick.size() > 1:
        await get_tree().create_timer(0.34).timeout


func _v_trick_end(winner: int, pts: int) -> void:
    _refresh_all_tricks()
    var my_side_won := false
    if state.mode == GameState.Mode.CLASSIC:
        my_side_won = state.team_of(winner) == state.team_of(my_seat)
    else:
        my_side_won = winner == my_seat
    if my_side_won:
        Snd.sfx("trick_win", 1.0, -3.0)
    if avatars.has(winner):
        var a: AvatarView = avatars[winner]
        var t := a.create_tween()
        t.tween_property(a, "scale", Vector2(1.12, 1.12), 0.12)
        t.tween_property(a, "scale", Vector2.ONE, 0.15)
    if pts == 2:
        banner.show_big_text("دنگ طلایی ×۲", Color(1.0, 0.85, 0.4), 1.2)
        Snd.sfx("kot", 1.2, -6.0)
    var done := [false]
    trick_area.collect_to(_avatar_center(winner), func(): done[0] = true)
    while not done[0]:
        await get_tree().create_timer(0.1).timeout


func _v_sp(seat: int, sp: int, target: int, payload: Dictionary) -> void:
    Snd.sfx("sp_swap" if sp == 2 else "sp_use")
    var sp_name := Deck.sp_name(sp)
    if avatars.has(seat):
        avatars[seat].show_status(sp_name, Color(0.45, 0.25, 0.6, 0.95), 1.6)
    match sp:
        1:
            if target >= 0 and avatars.has(target):
                avatars[target].show_status("سکوت!", Color(0.3, 0.3, 0.34, 0.95), 2.0)
        2:
            if target >= 0 and avatars.has(target):
                avatars[target].show_status("کارت عوض شد", Color(0.45, 0.25, 0.6, 0.95), 1.6)
        3:
            if seat == my_seat and payload.has("card"):
                if target >= 0 and avatars.has(target):
                    avatars[target].show_mini_card(GameCard.from_dict(payload.card))
        4:
            if avatars.has(seat):
                avatars[seat].show_status("دو برابر!", Color(0.8, 0.5, 0.1, 0.95), 1.8)
        5:
            if avatars.has(seat):
                avatars[seat].show_status("طلایی!", Color(0.9, 0.7, 0.15, 0.95), 1.8)
        0:
            if avatars.has(seat):
                avatars[seat].show_status("سپر فعال", Color(0.25, 0.45, 0.65, 0.95), 1.8)
    if seat == my_seat:
        _set_my_sp(-1)


func _v_react(seat: int, id: int) -> void:
    if avatars.has(seat):
        avatars[seat].show_react("res://assets/react/" + EmoteBar.REACTS[id] + ".png")
    elif seat == my_seat:
        Snd.sfx("react")


func _v_hand_end(data: Dictionary) -> void:
    var scores: Array = data.scores
    var tricks: Array = data.tricks
    for i in mini(scores.size(), state.players.size()):
        state.players[i].score = int(scores[i])
        state.players[i].tricks = int(tricks[i])
    _refresh_all_tricks()
    if bool(data.get("kot", false)):
        Snd.sfx("kot")
        banner.show_big_text("کوت!", Color(1.0, 0.8, 0.3), 1.6)
        await get_tree().create_timer(1.4).timeout
    var my_win := false
    if state.mode == GameState.Mode.CLASSIC and int(data.get("won_side", -1)) >= 0:
        my_win = int(data.won_side) == state.team_of(my_seat)
    else:
        var best := 0
        for p in state.players:
            best = maxi(best, p.tricks)
        my_win = state.players[my_seat].tricks == best
    Snd.sfx("hand_win" if my_win else "hand_lose", 1.0, -2.0)
    banner.show_banner(str(data.msg), "", "", 2.0)


# ================= LOCAL INPUT =================

func _local_try_play(card: GameCard) -> void:
    if state == null or state.turn != my_seat:
        fan.reject_active()
        return
    if am_server:
        if not _awaiting_input:
            fan.reject_active()
            return
        var legal := _legal_for(my_seat)
        var ok := false
        for c in legal:
            if c.uid == card.uid:
                ok = true
                break
        if not ok:
            fan.reject_active()
            toast("این کارت را نمی‌توانی بازی کنی!")
            return
        _human_card = card
        sig_human_card.emit()
        fan.flash_active_green()
    else:
        Net.send_to_server("play", {"card": card.to_dict()})


func _local_use_sp() -> void:
    if _my_sp_id < 0:
        return
    if state == null or state.turn != my_seat:
        toast("کارت ویژه فقط در نوبت خودت!")
        return
    var sp := _my_sp_id
    if sp in [1, 2, 3]:
        if _picking_target:
            return
        _picking_target = true
        _target_sp = sp
        toast("حریف مورد نظر را انتخاب کن")
        for seat in avatars:
            var a: AvatarView = avatars[seat]
            a.mouse_filter = Control.MOUSE_FILTER_STOP
            a.modulate = Color(1.25, 1.15, 1.0)
    else:
        _do_use_sp(sp, -1)


func _on_avatar_pick_input(ev: InputEvent, seat: int) -> void:
    if not _picking_target:
        return
    if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
        _end_target_pick()
        _do_use_sp(_target_sp, seat)


func _end_target_pick() -> void:
    _picking_target = false
    for seat in avatars:
        var a: AvatarView = avatars[seat]
        a.mouse_filter = Control.MOUSE_FILTER_IGNORE
        a.modulate = Color.WHITE


func _do_use_sp(sp: int, target: int) -> void:
    if am_server:
        await _resolve_sp(my_seat, sp, target)
    else:
        Net.send_to_server("use_sp", {"sp": sp, "target": target})


func _local_react(id: int) -> void:
    _v_react(my_seat, id)
    if is_net:
        if am_server:
            _net("react", {"seat": my_seat, "id": id})
        else:
            Net.send_to_server("react", {"id": id})


# ================= NETWORK =================

func _net(cmd: String, data: Dictionary) -> void:
    if is_net and am_server:
        Net.broadcast_cmd(cmd, data)


func on_net_cmd(cmd: String, data: Dictionary) -> void:
    call_deferred("_handle_net", cmd, data)


func _handle_net(cmd: String, data: Dictionary) -> void:
    match cmd:
        "hand_start":
            for seat in avatars:
                state.players[seat].tricks = 0
                avatars[seat].set_tricks(0)
            state.event_id = -1
            _refresh_scores()
        "set_hand":
            _pending_hand.clear()
            for d in data.cards:
                _pending_hand.append(GameCard.from_dict(d))
        "deal1":
            fan.set_hand(_pending_hand.duplicate(), true)
            fan.set_input_enabled(false)
        "deal2":
            fan.add_cards(_pending_hand.duplicate())
        "hokm_phase":
            _v_hokm_phase(int(data.hakem), true)
        "hokm_chosen":
            state.hokm = int(data.suit)
            state.hakem = int(data.get("by", state.hakem))
            _v_hokm_chosen(int(data.suit))
        "event":
            state.event_id = int(data.ev)
            _v_event(int(data.ev), Deck.ev_name(int(data.ev)), Deck.ev_desc(int(data.ev)))
        "sp_deal":
            _set_my_sp(int(data.get("sp", -1)))
        "turn":
            state.turn = int(data.seat)
            _v_turn(int(data.seat))
        "play":
            state.turn = int(data.seat)
            _v_play(int(data.seat), GameCard.from_dict(data.card), int(data.seat) == my_seat)
        "sp":
            var seat: int = int(data.seat)
            var target: int = int(data.get("target", -1))
            if state != null and seat < state.players.size():
                state.players[seat].sp = -1
            _v_sp(seat, int(data.sp), target, data.get("payload", {}))
        "sync_hand":
            var arr: Array[GameCard] = []
            for d in data.cards:
                arr.append(GameCard.from_dict(d))
            fan.set_hand(arr)
        "trick_end":
            var snap: Array = data.get("my_tricks", [])
            for i in mini(snap.size(), state.players.size()):
                state.players[i].tricks = int(snap[i])
            _v_trick_end(int(data.winner), int(data.get("pts", 1)))
        "hand_end":
            await _v_hand_end(data)
        "match_end":
            if not am_server:
                await _show_results()
        "react":
            _v_react(int(data.seat), int(data.id))
        "reject":
            fan.reject_active()
            toast("حرکت نامعتبر!")
        "toast":
            toast(str(data.get("msg", "")))
        "peer_left":
            toast(str(data.get("msg", "بازیکنی خارج شد؛ هوش مصنوعی جایگزین شد")))
        _:
            pass


func on_client_cmd(sender: int, cmd: String, data: Dictionary) -> void:
    match cmd:
        "play":
            var seat := _seat_of_peer(sender)
            if seat < 0:
                return
            if state.turn != seat or not _awaiting_input:
                Net.send_cmd_to(sender, "reject", {})
                return
            var card := GameCard.from_dict(data.card)
            var legal := _legal_for(seat)
            var ok := false
            for c in legal:
                if c.uid == card.uid:
                    ok = true
                    break
            if not ok:
                Net.send_cmd_to(sender, "reject", {})
                return
            _human_card = card
            sig_human_card.emit()
        "pick_hokm":
            var seat2 := _seat_of_peer(sender)
            if seat2 == state.hakem and _human_hokm < 0:
                _human_hokm = int(data.suit)
                sig_human_hokm.emit()
        "use_sp":
            var seat3 := _seat_of_peer(sender)
            if seat3 >= 0 and state.players[seat3].sp >= 0:
                _resolve_sp(seat3, int(data.sp), int(data.target))
        "react":
            var seat4 := _seat_of_peer(sender)
            if seat4 >= 0:
                _net("react", {"seat": seat4, "id": int(data.id)})


func _seat_of_peer(peer_id: int) -> int:
    for p in state.players:
        if p.peer == peer_id:
            return p.seat
    return -1


func on_peer_left(peer_id: int) -> void:
    if not am_server or state == null:
        return
    for p in state.players:
        if p.peer == peer_id:
            p.is_ai = true
            p.level = 2
            if avatars.has(p.seat):
                avatars[p.seat].set_display_name(p.name + " (AI)")
            _net("peer_left", {"msg": "%s خارج شد؛ هوش مصنوعی جایگزین شد" % p.name})
            break


func _exit_tree() -> void:
    if Net.game == self:
        Net.game = null
