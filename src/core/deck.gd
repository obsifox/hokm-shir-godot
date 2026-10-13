class_name Deck
extends RefCounted
## Deck builder for classic & fantasy modes.


static func standard_52() -> Array[GameCard]:
    var out: Array[GameCard] = []
    for s in 4:
        for r in range(2, 15):
            out.append(GameCard.make(s, r))
    return out


## Fantasy deck: 1 deck for 4 players, 2 decks + 2 jokers for 5-8 players.
static func fantasy_deck(player_count: int) -> Array[GameCard]:
    var cards: Array[GameCard] = standard_52()
    if player_count > 4:
        cards.append_array(standard_52())
        cards.append(GameCard.make(0, 15, "joker_trump"))
        cards.append(GameCard.make(0, 16, "joker_color"))
    return cards


static func shuffle(cards: Array[GameCard], rng: RandomNumberGenerator) -> void:
    for i in range(cards.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = cards[i]
        cards[i] = cards[j]
        cards[j] = tmp


## The 6 special (Sp) card ids that can be dealt to players (jokers live in the deck).
static func sp_ids() -> Array[int]:
    return [0, 1, 2, 3, 4, 5]


static func sp_tex(id: int) -> String:
    var names := ["sp_shield", "sp_silence", "sp_swap", "sp_peek", "sp_double", "sp_golden", "sp_joker_trump", "sp_joker_color"]
    return "res://assets/sp/%s.jpg" % names[id]


static func sp_name(id: int) -> String:
    var names := ["سپر", "سکوت", "جابه‌جایی", "جاسوسی", "دو برابر", "طلایی", "جوکر حکم", "جوکر رنگ"]
    return names[id]


static func sp_desc(id: int) -> String:
    var descs := [
        "تا پایان دست، جلوی سکوت و جاسوسی و جابه‌جایی حریفان را می‌گیرد",
        "حریف انتخابی در دنگ بعدی مجبور است ضعیف‌ترین کارتش را بازی کند",
        "ضعیف‌ترین کارت تو با یک کارت تصادفی از دست حریف عوض می‌شود",
        "یکی از کارت‌های مخفی حریف انتخابی به مدت چند ثانیه پیدا می‌شود",
        "اگر دست را ببری، امتیاز آن دو برابر می‌شود",
        "دنگ بعدی که با این کارت برنده شوی، دو دنگ حساب می‌شود",
        "این کارت در دستت می‌نشیند و از همه حکم‌ها قوی‌تر است",
        "این کارت در دستت می‌نشیند و مثل حکم عمل می‌کند، اما از جوکر حکم ضعیف‌تر است",
    ]
    return descs[id]


## Evolution event cards for fantasy mode.
static func ev_ids() -> Array[int]:
    return [0, 1, 2, 3]


static func ev_tex(id: int) -> String:
    var names := ["ev_forbidden", "ev_golden_hand", "ev_reverse", "ev_swap_ruler"]
    return "res://assets/ev/%s.jpg" % names[id]


static func ev_name(id: int) -> String:
    var names := ["ممنوع", "دست طلایی", "برعکس", "تغییر حاکم"]
    return names[id]


static func ev_desc(id: int) -> String:
    var descs := [
        "تا سه دنگ، یک خال را نمی‌شود زمین زد",
        "بیشترین شاه و بی‌بی و سربازِ گرفته‌شده، یک دنگ اضافه می‌گیرد",
        "چرخش بازی در این دست برعکس می‌شود",
        "حاکمی از دو نفر جلوتر شروع می‌کند",
    ]
    return descs[id]
