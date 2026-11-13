class_name OnlineGateway
extends Node

var base_url: String = ""
var token: String = ""
var revision: int = 0
var wallet: Dictionary = {"cash":0}
var connected: bool = false
var busy: bool = false
var transport: HTTPRequest

func _ready() -> void:
	transport = HTTPRequest.new()
	transport.timeout = 12
	add_child(transport)
	var config = ConfigFile.new()
	if config.load("user://server_connection.cfg") == OK:
		base_url = str(config.get_value("server","url",""))
		token = str(config.get_value("server","token",""))

func send(path: String, method: HTTPClient.Method, body: Dictionary = {}) -> Dictionary:
	if busy: return {"ok":false,"error":"이전 서버 요청을 처리하고 있습니다."}
	busy = true
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty(): headers.append("Authorization: Bearer " + token)
	var error = transport.request(base_url+path,headers,method,JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		busy = false
		return {"ok":false,"error":"서버에 요청할 수 없습니다. 연결 설정을 확인해 주세요."}
	var result = await transport.request_completed
	busy = false
	if result[0] != HTTPRequest.RESULT_SUCCESS: return {"ok":false,"error":"서버에 연결하지 못했습니다. 주소와 서버 실행 상태를 확인해 주세요."}
	var parser = JSON.new()
	if parser.parse(result[3].get_string_from_utf8()) != OK or not parser.data is Dictionary: return {"ok":false,"error":"올바르지 않은 서버 응답입니다."}
	var response: Dictionary = parser.data
	if result[1] < 200 or result[1] >= 300:
		return {"ok":false,"error":str(response.get("error",response.get("detail","서버 요청 실패")))}
	if response.has("revision"): revision = int(response.revision)
	if response.get("wallet") is Dictionary: wallet = response.wallet
	return response

func connect_server(address: String) -> Dictionary:
	var cleaned = address.strip_edges().trim_suffix("/")
	if not cleaned.begins_with("https://") and not cleaned.begins_with("http://127.0.0.1:") and not cleaned.begins_with("http://localhost:"):
		return {"ok":false,"error":"HTTPS 서버 주소를 입력해 주세요. 개발용 localhost만 HTTP를 허용합니다."}
	if cleaned != base_url: token = ""
	base_url = cleaned
	connected = false
	var health = await send("/health",HTTPClient.METHOD_GET)
	if not health.get("ok",false): return health
	if token.is_empty():
		var session = await send("/session",HTTPClient.METHOD_POST)
		if not session.get("ok",false): return session
		token = session.token
	var response = await fetch_state()
	if not response.get("ok",false): return response
	connected = true
	var config = ConfigFile.new()
	config.set_value("server","url",base_url)
	config.set_value("server","token",token)
	config.save("user://server_connection.cfg")
	return response

func fetch_state() -> Dictionary:
	return await send("/state",HTTPClient.METHOD_GET)

func mutate(operation: String, payload: Dictionary) -> Dictionary:
	var body = payload.duplicate(true)
	body.revision = revision
	body.request_id = Crypto.new().generate_random_bytes(16).hex_encode()
	return await send("/action/"+operation,HTTPClient.METHOD_POST,body)
