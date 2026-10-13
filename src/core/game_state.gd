class_name GameState
extends RefCounted
## Full state of one match. Lives on the server / solo game only.

enum Mode { CLASSIC, FANTASY }

var mode: int = Mode.CLASSIC
var player_count: int = 4
var players: Array[Dictionary] = []
var hakem: int = 0
var hokm: int = -1
var trick: Array = []          # [{seat, card, golden_by}]
var turn: int = 0
var turn_dir: int = 1          # 1 = CCW, -1 = reversed (fantasy event)
var hand_num: int = 0
var trick_num: int = 0
var event_id: int = -1         # current evo event (-1 none)
var forbidden_suit: int = -1
var forbidden_left: int = 0
var hand_history: Array = []   # all cards played this hand [{seat, card, is_lead}]
var match_over: bool = false
var target_points: int = 7     # classic 7 / fantasy 5

var rng := RandomNumberGenerator.new()


static func seat_player(p_seat: int, p_name: String, p_ai: bool, p_level: int, p_peer: int = 0) -> Dictionary:
    return {
        "seat": p_seat,
        "name": p_name,
        "is_ai": p_ai,
        "level": p_level,
        "peer": p_peer,
        "hand": [] as Array[GameCard],
        "sp": -1,
        "tricks": 0,
        "face_taken": 0,
        "score": 0,
        "silenced": false,
        "shield": false,
        "double": false,
        "golden_pending": false,
    }


func setup(p_mode: int, count: int, human_name: String, ai_level: int, seat_peers: Dictionary = {}) -> void:
    mode = p_mode
    player_count = count
    target_points = 7 if mode == Mode.CLASSIC else 5
    players.clear()
    for i in count:
        var info: Dictionary = seat_peers.get(i, {})
        var is_ai := (not info.has("peer")) and i != 0
        var nm: String = str(info.get("name", "")) if not is_ai else (human_name if i == 0 else S.AI_NAMES[i % S.AI_NAMES.size()])
        if is_ai:
            players.append(GameState.seat_player(i, nm, true, ai_level))
        else:
            players.append(GameState.seat_player(i, nm, false, 0, int(info.get("peer", 0))))
    rng.randomize()
    hakem = rng.randi_range(0, count - 1)


func is_ai(seat: int) -> bool:
    return players[seat].is_ai


func team_of(seat: int) -> int:
    return seat % 2


func next_seat(s: int) -> int:
    return posmod(s + turn_dir, player_count)


func hand_size() -> int:
    if mode == Mode.CLASSIC:
        return 13
    match player_count:
        4: return 13
        5: return 21
        6: return 18
        7: return 15
        8: return 13
    return 13


func tricks_in_hand() -> int:
    var total := 0
    if mode == Mode.CLASSIC:
        return 13
    match player_count:
        4: total = 52
        5: total = 105
        6: total = 108
        7: total = 105
        8: total = 104
    return int(total / float(player_count))


func team_tricks(team: int) -> int:
    var t := 0
    for p in players:
        if team_of(p.seat) == team:
            t += p.tricks
    return t


func reset_hand_tracking() -> void:
    trick.clear()
    hand_history.clear()
    trick_num = 0
    forbidden_suit = -1
    forbidden_left = 0
    turn_dir = 1
    event_id = -1
    for p in players:
        p.tricks = 0
        p.face_taken = 0
        p.silenced = false
        p.shield = false
        p.double = false
        p.golden_pending = false
