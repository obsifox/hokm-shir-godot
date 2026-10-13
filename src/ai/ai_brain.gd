class_name AIBrain
extends RefCounted
## 5-level AI: 0=تازه‌کار 1=کاربلد 2=بازیکن 3=حرفه‌ای 4=جهنمی

const L_ROOKIE := 0
const L_SKILLED := 1
const L_PLAYER := 2
const L_PRO := 3
const L_HELL := 4


static func choose_hokm(state: GameState, seat: int) -> int:
	var hand: Array[GameCard] = state.players[seat].hand
	var level: int = state.players[seat].level
	if level == L_ROOKIE:
		return state.rng.randi_range(0, 3)
	var best := 0
	var best_score := -1.0
	for s in 4:
		var sc := 0.0
		for c in hand:
			if c.is_joker():
				sc += 4.0
				continue
			if c.suit == s:
				var v := float(c.rank)
				if c.rank == 14: v += 6.0
				elif c.rank == 13: v += 3.0
				elif c.rank == 12: v += 1.0
				sc += v
		if level >= L_PRO:
			sc *= 1.0 + 0.12 * suit_count(hand, s)  # length bonus
		if sc > best_score:
			best_score = sc
			best = s
	return best


static func suit_count(hand: Array[GameCard], s: int) -> int:
	var n := 0
	for c in hand:
		if not c.is_joker() and c.suit == s:
			n += 1
	return n


static func choose_card(state: GameState, seat: int) -> GameCard:
	var p: Dictionary = state.players[seat]
	var hand: Array[GameCard] = p.hand
	var level: int = p.level
	var legal := Rules.legal_moves(hand, state.trick, state.hokm, state.forbidden_suit, state.forbidden_left, p.silenced)
	if legal.size() == 1:
		return legal[0]
	match level:
		L_ROOKIE:
			return legal[state.rng.randi_range(0, legal.size() - 1)]
		L_SKILLED:
			return _skilled(state, seat, legal)
		L_PLAYER:
			return _player(state, seat, legal)
		L_PRO:
			return _pro(state, seat, legal)
		_:
			return _hell(state, seat, legal)


# ---------- level 1: کاربلد ----------
static func _skilled(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var hokm := state.hokm
	if state.trick.is_empty():
		# lead highest non-trump honour, else lowest card
		var best: GameCard = null
		for c in legal:
			if c.is_joker():
				continue
			if c.suit != hokm and c.rank >= 13 and (best == null or c.rank > best.rank):
				best = c
		if best != null:
			return best
		return _lowest(legal, hokm)
	else:
		var win := _cheapest_winner(legal, state)
		if win != null and (win.suit == hokm or state.trick_num >= 4 or win.rank >= 13):
			return win
		return _lowest(legal, hokm)


# ---------- level 2: بازیکن ----------
static func _player(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var hokm := state.hokm
	var last := _am_last(state, seat)
	var partner_winning := _partner_winning(state, seat)
	if state.trick.is_empty():
		# prefer leading from the longest non-trump suit, high card
		var best: GameCard = null
		var best_len := -1
		for c in legal:
			if c.is_joker():
				continue
			var ln := suit_count(state.players[seat].hand, c.suit)
			if c.suit != hokm and c.rank >= 12 and (best == null or ln > best_len or (ln == best_len and c.rank > best.rank)):
				best = c
				best_len = ln
		if best != null:
			return best
		return _lowest(legal, hokm)
	if last:
		if partner_winning:
			return _lowest(legal, hokm)
		var win := _cheapest_winner(legal, state)
		if win != null:
			return win
		return _lowest(legal, hokm)
	else:
		if partner_winning:
			var strong := _is_boss(state, seat, _highest(legal, hokm))
			if strong:
				return _highest(legal, hokm)
			return _lowest(legal, hokm)
		var boss := _boss_in_legal(state, seat, legal)
		if boss != null and boss.suit != hokm:
			return boss
		var win := _cheapest_winner(legal, state)
		if win != null and win.rank >= 13:
			return win
		return _lowest(legal, hokm)


# ---------- level 3: حرفه‌ای ----------
static func _pro(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var c := _shared_pro(state, seat, legal)
	if c != null:
		return c
	return _player(state, seat, legal)


# ---------- level 4: جهنمی ----------
static func _hell(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var c := _shared_pro(state, seat, legal)
	if c != null:
		return c
	# Endgame certainty: if every card is a certain winner, lead them out.
	if state.trick.is_empty() and _all_boss(state, seat, legal):
		return _highest(legal, state.hokm)
	# Trump squeeze: if opponents likely void in a suit, force them.
	if state.trick.is_empty():
		var cand := _squeeze_lead(state, seat, legal)
		if cand != null:
			return cand
	return _player(state, seat, legal)


## Common "professional" heuristics shared by levels 3 & 4.
static func _shared_pro(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var hokm := state.hokm
	var last := _am_last(state, seat)
	if state.trick.is_empty():
		# Lead a boss card of a side suit; late game lead boss trumps to draw them.
		var boss := _boss_in_legal(state, seat, legal)
		if boss != null:
			if boss.suit != hokm:
				return boss
			var opp_trumps_left := _unseen_trumps(state, seat)
			if opp_trumps_left == 0 or suit_count(state.players[seat].hand, hokm) >= 3:
				return boss
		# Don't lead trumps early without length
		var non_trump: Array[GameCard] = []
		for c in legal:
			if not c.is_joker() and c.suit != hokm:
				non_trump.append(c)
		if not non_trump.is_empty() and state.trick_num < 4:
			return _lowest(non_trump, hokm)
		return _lowest(legal, hokm)
	if last:
		if _partner_winning(state, seat):
			# partner holds the trick; dump lowest — but if partner played a low
			# card and opponents behind are gone (we're last), keep it simple.
			return _lowest(legal, hokm)
		var win := _cheapest_winner(legal, state)
		if win != null:
			return win
		return _lowest(legal, hokm)
	else:
		# Not last: only spend high cards when they are boss, or cheap winners.
		var boss := _boss_in_legal(state, seat, legal)
		if boss != null and _trick_value(state) >= 1:
			return boss
		var win := _cheapest_winner(legal, state)
		if win != null and win.suit != hokm and win.rank >= 13:
			return win
		return _lowest(legal, hokm)


# ---------- helpers ----------

static func _lowest(legal: Array[GameCard], hokm: int) -> GameCard:
	var best: GameCard = null
	for c in legal:
		if best == null:
			best = c
			continue
		var cj := c.is_joker()
		var bj := best.is_joker()
		if cj != bj:
			if bj:
				best = c
			continue
		if c.suit == hokm and best.suit != hokm:
			continue
		if best.suit == hokm and c.suit != hokm:
			best = c
			continue
		if c.rank < best.rank:
			best = c
	return best


static func _highest(legal: Array[GameCard], hokm: int) -> GameCard:
	var best: GameCard = null
	for c in legal:
		if best == null or Rules.card_power(c, hokm) > Rules.card_power(best, hokm):
			best = c
	return best


## Cheapest card that currently takes the trick.
static func _cheapest_winner(legal: Array[GameCard], state: GameState) -> GameCard:
	if state.trick.is_empty():
		return _highest(legal, state.hokm)
	var hokm := state.hokm
	var lead := Rules.lead_suit(state.trick, hokm)
	var best: GameCard = null
	for c in legal:
		if _beats_trick(c, state):
			if best == null:
				best = c
				continue
			var c_tr := Rules.card_cmp_suit(c, hokm) == hokm
			var b_tr := Rules.card_cmp_suit(best, hokm) == hokm
			if c_tr != b_tr:
				if b_tr:
					best = c
				continue
			if c.rank < best.rank:
				best = c
	return best


static func _beats_trick(c: GameCard, state: GameState) -> bool:
	var hokm := state.hokm
	var lead := Rules.lead_suit(state.trick, hokm)
	var cs := Rules.card_cmp_suit(c, hokm)
	for e in state.trick:
		var ec: GameCard = e.card
		var es := Rules.card_cmp_suit(ec, hokm)
		if es == hokm and cs != hokm:
			return false
		if cs == hokm and es != hokm:
			continue
		if es != cs:
			continue
		if Rules.card_power(ec, hokm) >= Rules.card_power(c, hokm):
			return false
	return true


static func _am_last(state: GameState, seat: int) -> bool:
	return state.trick.size() == state.player_count - 1


static func _partner_winning(state: GameState, seat: int) -> bool:
	if state.trick.is_empty():
		return false
	if state.mode == GameState.Mode.CLASSIC:
		var win_i := Rules.trick_winner_index(state.trick, state.hokm)
		return state.team_of(state.trick[win_i].seat) == state.team_of(seat)
	return state.trick[Rules.trick_winner_index(state.trick, state.hokm)].seat == seat


static func _is_boss(state: GameState, seat: int, c: GameCard) -> bool:
	if c == null:
		return false
	var hokm := state.hokm
	if c.is_joker():
		return c.kind == "joker_trump"
	var s := c.suit
	if s == hokm and _has_unseen_higher(state, seat, s, c.rank):
		return false
	if s != hokm:
		if _has_unseen_higher(state, seat, s, c.rank):
			return false
	return true


static func _boss_in_legal(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	var best: GameCard = null
	for c in legal:
		if c.is_joker():
			if c.kind == "joker_trump":
				return c
			continue
		if _is_boss(state, seat, c) and (best == null or Rules.card_power(c, state.hokm) > Rules.card_power(best, state.hokm)):
			best = c
	return best


static func _all_boss(state: GameState, seat: int, legal: Array[GameCard]) -> bool:
	for c in legal:
		if not c.is_joker() and not _is_boss(state, seat, c):
			return false
	return legal.size() > 0


static func _has_unseen_higher(state: GameState, seat: int, s: int, rank: int) -> bool:
	# any card of suit s with higher rank not in my hand and not yet played?
	for r in range(rank + 1, 15):
		if _unseen_count(state, seat, s, r) > 0:
			return true
	return false


static func _unseen_count(state: GameState, seat: int, s: int, r: int) -> int:
	var decks := 1 if state.mode == GameState.Mode.CLASSIC or state.player_count == 4 else 2
	var total := decks
	for p in state.players:
		if p.seat == seat:
			continue
		for c in p.hand:
			if not c.is_joker() and c.suit == s and c.rank == r:
				total -= 1
	for e in state.hand_history:
		var c: GameCard = e.card
		if not c.is_joker() and c.suit == s and c.rank == r:
			total -= 1
	return max(total, 0)


static func _unseen_trumps(state: GameState, seat: int) -> int:
	var n := 0
	for r in range(2, 15):
		n += _unseen_count(state, seat, state.hokm, r)
	for p in state.players:
		if p.seat != seat:
			for c in p.hand:
				if c.is_joker():
					n += 1
	return n


static func _trick_value(state: GameState) -> int:
	return state.trick.size() + 1


## Lead a suit where opponents are likely void → forces trumps out.
static func _squeeze_lead(state: GameState, seat: int, legal: Array[GameCard]) -> GameCard:
	if state.trick_num < 5:
		return null
	var best: GameCard = null
	var best_sc := 0.0
	for c in legal:
		if c.is_joker() or c.suit == state.hokm:
			continue
		var voids := 0
		for p in state.players:
			if p.seat == seat:
				continue
			if state.mode == GameState.Mode.CLASSIC and state.team_of(p.seat) == state.team_of(seat):
				continue
			if _likely_void(state, seat, p.seat, c.suit):
				voids += 1
		var sc := float(voids) + c.rank * 0.05
		if sc > best_sc:
			best_sc = sc
			best = c
	return best


static func _likely_void(state: GameState, _seat: int, other: int, s: int) -> bool:
	# if 'other' never followed suit s when able... simplified: they discarded on a s-lead before
	for i in range(state.hand_history.size()):
		var e: Dictionary = state.hand_history[i]
		if e.seat != other:
			continue
		if e.card.is_joker():
			continue
		# find the lead suit of that trick
		var lead := -1
		for j in range(i, -1, -1):
			if state.hand_history[j].get("is_lead", false):
				lead = state.hand_history[j].card.suit
				break
		if lead == s and e.card.suit != s:
			return true
	return false


# ---------- SP card usage (fantasy) ----------

## Returns {} or {sp:int, target:int}
static func want_sp(state: GameState, seat: int) -> Dictionary:
	var p: Dictionary = state.players[seat]
	var sp: int = p.sp
	if sp < 0:
		return {}
	var level: int = p.level
	var chance: float = [0.25, 0.4, 0.55, 0.75, 0.95][level]
	if state.rng.randf() > chance:
		return {}
	var enemies: Array[int] = []
	for q in state.players:
		if q.seat != seat and not q.get("shield", false):
			enemies.append(q.seat)
	if enemies.is_empty():
		return {}
	match sp:
		3:  # peek — early info
			if state.trick_num > 2:
				return {}
			return {"sp": 3, "target": enemies[state.rng.randi_range(0, enemies.size() - 1)]}
		1:  # silence strongest enemy
			if state.trick_num < 1:
				return {}
			var t := _strongest_enemy(state, seat, enemies)
			return {"sp": 1, "target": t}
		2:  # swap when hand weak
			var avg := _hand_avg_rank(state, seat)
			if avg > 8.0:
				return {}
			return {"sp": 2, "target": enemies[state.rng.randi_range(0, enemies.size() - 1)]}
		4:  # double when winning
			if p.tricks < int(state.tricks_in_hand() * 0.45):
				return {}
			return {"sp": 4, "target": -1}
		5:  # golden when we will win the upcoming trick
			if state.trick.is_empty():
				var boss := _boss_in_legal(state, seat, state.players[seat].hand)
				if boss != null:
					return {"sp": 5, "target": -1}
			elif _cheapest_winner(state.players[seat].hand, state) != null:
				return {"sp": 5, "target": -1}
			return {}
		0:  # shield — keep unless many enemies alive late
			if state.trick_num > state.tricks_in_hand() / 2:
				return {"sp": 0, "target": -1}
			return {}
		_: return {}


static func _strongest_enemy(state: GameState, seat: int, enemies: Array[int]) -> int:
	var best := enemies[0]
	for s in enemies:
		if state.players[s].tricks > state.players[best].tricks:
			best = s
	return best


static func _hand_avg_rank(state: GameState, seat: int) -> float:
	var hand: Array[GameCard] = state.players[seat].hand
	if hand.is_empty():
		return 10.0
	var t := 0.0
	for c in hand:
		t += c.rank if not c.is_joker() else 14.0
	return t / hand.size()
