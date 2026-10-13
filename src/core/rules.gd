class_name Rules
extends RefCounted
## Pure Hokm rules — no scene references.

## Legal moves for a player.
static func legal_moves(hand: Array[GameCard], trick: Array, hokm: int, forbidden_suit: int, forbidden_left: int, silenced: bool) -> Array[GameCard]:
    var legal: Array[GameCard] = []
    if trick.is_empty():
        for c in hand:
            if c.is_joker():
                legal.append(c)
                continue
            if forbidden_left > 0 and c.suit == forbidden_suit and has_other_suit(hand, forbidden_suit):
                continue
            legal.append(c)
    else:
        var lead := lead_suit(trick, hokm)
        var has_lead := false
        for c in hand:
            if not c.is_joker() and c.suit == lead:
                has_lead = true
                break
        for c in hand:
            if c.is_joker():
                legal.append(c)
            elif not has_lead or c.suit == lead:
                legal.append(c)
    if silenced and legal.size() > 1:
        var lowest: GameCard = null
        for c in legal:
            if c.is_joker():
                continue
            if lowest == null or c.rank < lowest.rank or (c.rank == lowest.rank and c.suit < lowest.suit):
                lowest = c
        if lowest != null:
            return [lowest]
    return legal


static func has_other_suit(hand: Array[GameCard], exclude: int) -> bool:
    for c in hand:
        if c.is_joker():
            return true
        if c.suit != exclude:
            return true
    return false


## The suit that must be followed for the current trick.
static func lead_suit(trick: Array, hokm: int) -> int:
    var first: GameCard = trick[0].card
    if first.is_joker():
        return hokm
    return first.suit


## Power of a card within the trick context.
static func card_power(c: GameCard, hokm: int) -> int:
    if c.kind == "joker_trump":
        return 1000
    if c.kind == "joker_color":
        return 900
    return c.rank


## Effective suit used for comparisons.
static func card_cmp_suit(c: GameCard, hokm: int) -> int:
    if c.is_joker():
        return hokm
    return c.suit


## Returns index into entries of the winning seat.
static func trick_winner_index(entries: Array, hokm: int) -> int:
    if entries.is_empty():
        return -1
    var lead := lead_suit(entries, hokm)
    var best := 0
    for i in range(1, entries.size()):
        var b: GameCard = entries[best].card
        var c: GameCard = entries[i].card
        var bs := card_cmp_suit(b, hokm)
        var cs := card_cmp_suit(c, hokm)
        var bh := bs == hokm
        var ch := cs == hokm
        var take := false
        if ch and not bh:
            take = true
        elif ch == bh and cs == bs and card_power(c, hokm) > card_power(b, hokm):
            take = true
        if take:
            best = i
    return best


enum SortMode { TRUMP_FIRST, SUIT_ORDER, RANK_DESC }

static func sort_hand(hand: Array[GameCard], hokm: int, mode: int) -> void:
    var h := hokm
    if mode == SortMode.RANK_DESC:
        hand.sort_custom(func(a: GameCard, b: GameCard) -> bool:
            if a.suit != b.suit:
                return a.suit < b.suit
            return a.rank > b.rank)
    else:
        hand.sort_custom(func(a: GameCard, b: GameCard) -> bool:
            var sa := _sort_suit(a, h, mode)
            var sb := _sort_suit(b, h, mode)
            if sa != sb:
                return sa < sb
            return a.rank < b.rank)


static func _sort_suit(c: GameCard, hokm: int, mode: int) -> int:
    if mode == SortMode.TRUMP_FIRST and hokm >= 0 and c.suit == hokm:
        return -1
    return c.suit
