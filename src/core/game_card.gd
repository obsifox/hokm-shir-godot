class_name GameCard
extends RefCounted
## One playing card. rank 2..14 (11=J 12=Q 13=K 14=A)

enum Suit { SPADES = 0, HEARTS = 1, DIAMONDS = 2, CLUBS = 3 }

const SUIT_KEYS: Array[String] = ["s", "h", "d", "c"]
const SUIT_NAMES: Array[String] = ["پیک", "دل", "خشت", "گشنیز"]
const RANK_CHARS: Array[String] = ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

var suit: int = 0
var rank: int = 2
var kind: String = "normal"  # normal | joker_trump | joker_color
var uid: int = 0

static var _next_uid: int = 1


static func make(p_suit: int, p_rank: int, p_kind: String = "normal") -> GameCard:
    var c := GameCard.new()
    c.suit = p_suit
    c.rank = p_rank
    c.kind = p_kind
    c.uid = _next_uid
    _next_uid += 1
    return c


static func from_dict(d: Dictionary) -> GameCard:
    var c := GameCard.new()
    c.suit = int(d.get("s", 0))
    c.rank = int(d.get("r", 2))
    c.kind = str(d.get("k", "normal"))
    c.uid = int(d.get("u", 0))
    return c


func to_dict() -> Dictionary:
    return {"s": suit, "r": rank, "k": kind, "u": uid}


func is_joker() -> bool:
    return kind != "normal"


func is_face() -> bool:
    return kind == "normal" and rank >= 11 and rank <= 13


func tex_path() -> String:
    match kind:
        "joker_trump":
            return "res://assets/sp/sp_joker_trump.jpg"
        "joker_color":
            return "res://assets/sp/sp_joker_color.jpg"
        _:
            return "res://assets/persian_cards/%s/%s_%s.png" % [
                GameCard.suit_folder(suit), GameCard.SUIT_KEYS[suit], GameCard.RANK_CHARS[rank]
            ]


static func suit_folder(s: int) -> String:
    match s:
        Suit.SPADES: return "spades"
        Suit.HEARTS: return "hearts"
        Suit.DIAMONDS: return "diamonds"
        _: return "clubs"


static func suit_color(s: int) -> Color:
    if s == Suit.HEARTS or s == Suit.DIAMONDS:
        return Color(0.78, 0.18, 0.18)
    return Color(0.13, 0.13, 0.17)


func label() -> String:
    if kind == "joker_trump":
        return "جوکر حکم"
    if kind == "joker_color":
        return "جوکر رنگ"
    return "%s %s" % [GameCard.RANK_CHARS[rank], GameCard.SUIT_NAMES[suit]]


func sort_key() -> int:
    return suit * 100 + rank
