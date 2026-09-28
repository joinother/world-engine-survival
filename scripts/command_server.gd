class_name CommandServer
extends Node

signal request_received(line: String, peer: StreamPeerTCP)

var tcp_server := TCPServer.new()
var clients: Array[Dictionary] = []
var listen_port := 9555
var is_running := false

func start(port: int = 9555) -> bool:
	listen_port = port
	var error := tcp_server.listen(listen_port, "127.0.0.1")
	if error != OK:
		push_warning("Command server could not listen on port %d: %s" % [listen_port, error_string(error)])
		return false
	is_running = true
	return true

func _process(_delta: float) -> void:
	if not is_running:
		return
	if tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		clients.append({"peer": peer, "buffer": ""})
	for index in range(clients.size() - 1, -1, -1):
		var peer: StreamPeerTCP = clients[index]["peer"]
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_NONE:
			clients.remove_at(index)
			continue
		var available := peer.get_available_bytes()
		if available <= 0:
			continue
		clients[index]["buffer"] = str(clients[index]["buffer"]) + peer.get_utf8_string(available)
		var buffer := str(clients[index]["buffer"])
		var newline := buffer.find("\n")
		while newline >= 0:
			var line := buffer.substr(0, newline).strip_edges()
			buffer = buffer.substr(newline + 1)
			if not line.is_empty():
				request_received.emit(line, peer)
			newline = buffer.find("\n")
		clients[index]["buffer"] = buffer

func send_json(peer: StreamPeerTCP, payload: Dictionary) -> void:
	if peer.get_status() == StreamPeerTCP.STATUS_NONE:
		return
	peer.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())

func _exit_tree() -> void:
	if is_running:
		tcp_server.stop()
		is_running = false
