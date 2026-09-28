extends Node
## Test-only HTTP/1.1 server on 127.0.0.1 for exercising the real OTA update client in the unit
## suite. Each path can answer normally, hang (accept, never reply), be cut off halfway through
## its body, or 404.

## path -> body bytes
var routes := {}
## path -> "ok" | "hang" | "truncate" | "404"
var modes := {}
var port := 0
var requests: Array[String] = []
var _server := TCPServer.new()
var _conns: Array = []


func start() -> int:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in range(18500, 18700):
		if _server.listen(p, "127.0.0.1") == OK:
			port = p
			return p
	return 0


func url(path: String) -> String:
	return "http://127.0.0.1:%d%s" % [port, path]


func _process(_dt: float) -> void:
	while _server.is_connection_available():
		_conns.append({"peer": _server.take_connection(), "buf": PackedByteArray(), "done": false})
	for c in _conns:
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if c["done"] or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			# Packed arrays are values: append to a copy, then store it back.
			var buf: PackedByteArray = c["buf"]
			buf.append_array(peer.get_data(n)[1])
			c["buf"] = buf
		var head := (c["buf"] as PackedByteArray).get_string_from_utf8()
		if head.contains("\r\n\r\n"):
			c["done"] = true
			var path := head.get_slice(" ", 1).get_slice("?", 0)
			requests.append(path)
			_respond(peer, path)
	_conns = _conns.filter(func(c): return (c["peer"] as StreamPeerTCP).get_status() == StreamPeerTCP.STATUS_CONNECTED)


func _respond(peer: StreamPeerTCP, path: String) -> void:
	var mode: String = modes.get(path, "ok")
	if mode == "hang":
		return
	if mode == "404" or not routes.has(path):
		peer.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer())
		peer.disconnect_from_host()
		return
	var body: PackedByteArray = routes[path]
	peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()).to_utf8_buffer())
	peer.put_data(body.slice(0, body.size() / 2) if mode == "truncate" else body)
	peer.disconnect_from_host()


func stop() -> void:
	for c in _conns:
		(c["peer"] as StreamPeerTCP).disconnect_from_host()
	_conns.clear()
	_server.stop()
