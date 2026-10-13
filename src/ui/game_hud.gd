class_name GameHud
extends Control
## Top bar: trump badge, scores, sort & sound & menu buttons.

signal sort_pressed
signal menu_pressed
signal sound_pressed

var trump_badge: TextureRect
var trump_holder: Control
var center_box: VBoxContainer
var scores_box: HFlowContainer
var hakem_label: Label
var sort_btn: TextureButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# top gradient backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.13, 0.55)
	bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bg.custom_minimum_size = Vector2(0, 118)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	sort_btn = UIH.icon_btn("res://assets/btn/btn_round.png", 92, func(): sort_pressed.emit())
	sort_btn.position = Vector2(24, 14)
	var sort_label := UIH.label("مرتب", 26, UIH.GOLD)
	sort_label.position = Vector2.ZERO
	sort_label.size = Vector2(92, 92)
	sort_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sort_btn.add_child(sort_label)
	add_child(sort_btn)

	var sound_btn := UIH.icon_btn("res://assets/btn/btn_sound.png", 86, func(): sound_pressed.emit())
	sound_btn.position = Vector2(128, 16)
	add_child(sound_btn)

	var menu_btn := UIH.icon_btn("res://assets/btn/btn_setting.png", 86, func(): menu_pressed.emit())
	menu_btn.position = Vector2(970, 16)
	add_child(menu_btn)

	center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_box.position = Vector2(540 - 180, 6)
	center_box.custom_minimum_size = Vector2(360, 0)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_box)

	trump_holder = Control.new()
	trump_holder.custom_minimum_size = Vector2(360, 96)
	trump_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(trump_holder)

	var hint := UIH.label("حکم", 22, UIH.GOLD_DIM, "Medium")
	hint.position = Vector2(0, 8)
	hint.size = Vector2(300, 30)
	trump_holder.add_child(hint)

	trump_badge = UIH.tex_rect("res://assets/persian_cards/spades/s_A.png", Vector2(64, 96))
	trump_badge.position = Vector2(150, 20)
	trump_badge.visible = false
	trump_holder.add_child(trump_badge)

	scores_box = HFlowContainer.new()
	
	scores_box.add_theme_constant_override("separation", 16)
	scores_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_child(scores_box)


func set_trump(suit: int) -> void:
	trump_badge.visible = true
	var key := GameCard.SUIT_KEYS[suit]
	trump_badge.texture = load("res://assets/persian_cards/%s/%s_A.png" % [GameCard.suit_folder(suit), key])
	trump_badge.pivot_offset = Vector2(32, 48)
	trump_badge.scale = Vector2(1.6, 1.6)
	var t := trump_badge.create_tween()
	t.tween_property(trump_badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_scores(pills: Array) -> void:
	for c in scores_box.get_children():
		c.queue_free()
	for p in pills:
		scores_box.add_child(p)


func refresh_tricks(state: GameState) -> void:
	# update trick counters inside existing pills
	var i := 0
	for c in scores_box.get_children():
		if i < state.player_count:
			var pl: Dictionary = state.players[i]
			UIH.set_pill_text(c, "%s  %s" % [pl.name, S.fa(pl.tricks)])
		i += 1
