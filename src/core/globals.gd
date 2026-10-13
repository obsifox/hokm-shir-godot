extends Node
## Global settings & helpers (autoload: S)

const AI_NAMES: Array[String] = [
    "اردلان", "بهرام", "کیانا", "شیرین", "رستم",
    "سهراب", "گلنار", "فرهاد", "تهمینه", "کیومرث",
]

const AI_LEVEL_NAMES: Array[String] = [
    "تازه‌کار", "کاربلد", "بازیکن", "حرفه‌ای", "جهنمی",
]

const FDIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

var master_vol: float = 1.0
var music_vol: float = 0.75
var sfx_vol: float = 1.0
var fast_ai: bool = false
var player_name: String = "شما"
var last_mode: String = "classic"
var last_level: int = 2
var muted: bool = false
var last_game_cfg: Dictionary = {}

var rng := RandomNumberGenerator.new()


func _ready() -> void:
    rng.randomize()
    load_settings()


func ai_delay() -> float:
    return rng.randf_range(0.5, 0.95) if fast_ai else rng.randf_range(0.8, 1.5)


func fa(n: int) -> String:
    var s := str(n)
    var out := ""
    for ch in s:
        if ch >= "0" and ch <= "9":
            out += FDIGITS[int(ch)]
        else:
            out += ch
    return out


func save_settings() -> void:
    var cf := ConfigFile.new()
    cf.set_value("audio", "master", master_vol)
    cf.set_value("audio", "music", music_vol)
    cf.set_value("audio", "sfx", sfx_vol)
    cf.set_value("audio", "muted", muted)
    cf.set_value("game", "fast_ai", fast_ai)
    cf.set_value("game", "player_name", player_name)
    cf.set_value("game", "last_mode", last_mode)
    cf.set_value("game", "last_level", last_level)
    cf.save("user://settings.cfg")


func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load("user://settings.cfg") != OK:
        return
    master_vol = cf.get_value("audio", "master", 1.0)
    music_vol = cf.get_value("audio", "music", 0.75)
    sfx_vol = cf.get_value("audio", "sfx", 1.0)
    muted = cf.get_value("audio", "muted", false)
    fast_ai = cf.get_value("game", "fast_ai", false)
    player_name = cf.get_value("game", "player_name", "شما")
    last_mode = cf.get_value("game", "last_mode", "classic")
    last_level = cf.get_value("game", "last_level", 2)
