extends Node
## LAN / hotspot multiplayer (autoload: Net).
## Server-authoritative. Host = seat 0. UDP broadcast discovery on port 24566,
## ENet game traffic on port 24565.

signal rooms_changed
signal lobby_changed
signal joined_ok
signal join_failed(reason: String)
signal cmd_received(cmd: String, data: Dictionary)
signal server_lost

const GAME_PORT := 24565
const DISCO_PORT := 24566

var peer: ENetMultiplayerPeer = null
var is_server := false
var active := false

var room_name := "میز حکم"
var lobby_players: Array[Dictionary] = []   # [{peer, name}] host-side
var found_rooms: Array[Dictionary] = []     # client-side [{name, ip, players}]

var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var game: Node = null       # game scene registers itself for command dispatch
var game_cfg: Dictionary = {}  # config passed to the game scene at net start


# ================= host =================

func start_host(name_: String) -> bool:
    stop_all()
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_server(GAME_PORT, 7)
    if err != OK:
        peer = null
        return false
    multiplayer.multiplayer_peer = peer
    is_server = true
    active = true
    lobby_players = [{"peer": 1, "name": name_}]
    _start_broadcast()
    return true


func _start_broadcast() -> void:
    _broadcaster = PacketPeerUDP.new()
    _broadcaster.set_broadcast_enabled(true)
    _broadcaster.set_dest_address("255.255.255.255", DISCO_PORT)


var _bc_accum := 0.0

func _process(dt: float) -> void:
    if _broadcaster != null and active and is_server:
        _bc_accum += dt
        if _bc_accum >= 1.0:
            _bc_accum = 0.0
            var info := {"hokm": true, "name": room_name, "players": lobby_players.size()}
            _broadcaster.put_packet(JSON.stringify(info).to_utf8_buffer())
    if _listener != null:
        while _listener.get_available_packet_count() > 0:
            var pkt := _listener.get_packet()
            var ip := _listener.get_packet_ip()
            var data = JSON.parse_string(pkt.get_string_from_utf8())
            if data is Dictionary and data.get("hokm", false):
                var exists := false
                for r in found_rooms:
                    if r.ip == ip:
                        exists = true
                        break
                if not exists:
                    found_rooms.append({"name": str(data.get("name", "?")), "ip": ip, "players": int(data.get("players", 1))})
                    rooms_changed.emit()


# ================= join =================

func start_scan() -> void:
    stop_all()
    found_rooms.clear()
    _listener = PacketPeerUDP.new()
    var err := _listener.bind(DISCO_PORT)
    if err != OK:
        _listener = null


func join(ip: String, name_: String) -> bool:
    stop_all()
    peer = ENetMultiplayerPeer.new()
    var err := peer.create_client(ip, GAME_PORT)
    if err != OK:
        peer = null
        return false
    multiplayer.multiplayer_peer = peer
    is_server = false
    active = true
    _pending_name = name_
    return true


var _pending_name := ""


func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connect_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(id: int) -> void:
    if is_server:
        lobby_players.append({"peer": id, "name": "..."})
        lobby_changed.emit()


func _on_peer_disconnected(id: int) -> void:
    if is_server:
        for i in lobby_players.size():
            if lobby_players[i].peer == id:
                lobby_players.remove_at(i)
                break
        lobby_changed.emit()
        if game != null:
            game.on_peer_left(id)


func _on_connected() -> void:
    c_hello.rpc_id(1, _pending_name)
    joined_ok.emit()


func _on_connect_failed() -> void:
    stop_all()
    join_failed.emit("اتصال برقرار نشد")


func _on_server_disconnected() -> void:
    stop_all()
    server_lost.emit()


func stop_all() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    peer = null
    active = false
    is_server = false
    if _broadcaster != null:
        _broadcaster.close()
        _broadcaster = null
    if _listener != null:
        _listener.close()
        _listener = null


# ================= RPC channels =================

## server -> clients broadcast (authority-only sender)
@rpc("authority", "call_remote", "reliable")
func rs_cmd(cmd: String, data: Dictionary) -> void:
    cmd_received.emit(cmd, data)
    if game != null:
        game.on_net_cmd(cmd, data)


## client -> server
@rpc("any_peer", "call_remote", "reliable")
func cr_cmd(cmd: String, data: Dictionary) -> void:
    if is_server and game != null:
        var sender := multiplayer.get_remote_sender_id()
        game.on_client_cmd(sender, cmd, data)


@rpc("any_peer", "call_remote", "reliable")
func c_hello(name_: String) -> void:
    if is_server:
        var sender := multiplayer.get_remote_sender_id()
        for p in lobby_players:
            if p.peer == sender:
                p.name = name_
        lobby_changed.emit()


func broadcast_cmd(cmd: String, data: Dictionary) -> void:
    rs_cmd.rpc(cmd, data)


func send_cmd_to(peer_id: int, cmd: String, data: Dictionary) -> void:
    rs_cmd.rpc_id(peer_id, cmd, data)


func send_to_server(cmd: String, data: Dictionary) -> void:
    cr_cmd.rpc_id(1, cmd, data)
