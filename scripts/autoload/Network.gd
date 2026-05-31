extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected
signal map_data_received

const PORT = 7777
var peer = ENetMultiplayerPeer.new()

var scores = {}
signal scores_updated

# Map sync
var synced_map_data: Dictionary = {}

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Failed to start server: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", PORT)

func join_game(address: String):
	peer = ENetMultiplayerPeer.new()
	var ip = "127.0.0.1"
	var port = PORT
	if address != "":
		if ":" in address:
			var parts = address.split(":")
			ip = parts[0]
			port = int(parts[1])
		else:
			ip = address
	var error = peer.create_client(ip, port)
	if error != OK:
		print("Failed to join server: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Joining server at ", ip, ":", port)

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

func _on_peer_connected(id):
	print("Network: Peer connected: ", id)
	emit_signal("player_connected", id)
	# Server sends map data to the newly connected client
	if multiplayer.is_server():
		print("Network: Server sending map to peer ", id)
		var map_data = MapManager.load_map(MapManager.selected_map_name)
		rpc_id(id, "_rpc_receive_map_data", map_data)

# NO type hints on arguments — this is the critical fix
@rpc("authority", "call_remote", "reliable")
func _rpc_receive_map_data(map_data: Dictionary):
	print("Network: CLIENT received map data!")
	synced_map_data = map_data
	emit_signal("map_data_received")

func _on_peer_disconnected(id):
	print("Player disconnected: ", id)
	if scores.has(str(id)):
		scores.erase(str(id))
		emit_signal("scores_updated")
	emit_signal("player_disconnected", id)

func _on_server_disconnected():
	print("Server disconnected")
	emit_signal("server_disconnected")

@rpc("any_peer", "call_local")
func rpc_add_kill(id: String):
	if not scores.has(id):
		scores[id] = {"kills": 0, "deaths": 0}
	scores[id]["kills"] += 1
	emit_signal("scores_updated")

@rpc("any_peer", "call_local")
func rpc_add_death(id: String):
	if not scores.has(id):
		scores[id] = {"kills": 0, "deaths": 0}
	scores[id]["deaths"] += 1
	emit_signal("scores_updated")
