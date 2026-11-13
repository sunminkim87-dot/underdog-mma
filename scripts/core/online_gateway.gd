class_name OnlineGateway
extends Node

var base_url: String=""
var token: String=""
var revision: int=0
var wallet: Dictionary={"cash":0}
var connected: bool=false
var was_online: bool=false
var connecting: bool=false
var busy: bool=false
var connection_serial: int=0
var local_mode_requested: bool=false
var transport: HTTPRequest

func _ready() -> void:
	transport=HTTPRequest.new()
	transport.timeout=12
	add_child(transport)
	var config=ConfigFile.new()
	if config.load("user://server_connection.cfg")==OK:
		base_url=str(config.get_value("server","url",""))
		token=str(config.get_value("server","token",""))
		was_online=bool(config.get_value("server","last_online",not base_url.is_empty() and not token.is_empty()))

func persist_connection() -> void:
	var config=ConfigFile.new()
	config.set_value("server","url",base_url)
	config.set_value("server","token",token)
	config.set_value("server","last_online",was_online)
	config.save("user://server_connection.cfg")

func send(path: String,method: HTTPClient.Method,body: Dictionary={}) -> Dictionary:
	if busy:return {"ok":false,"error":"이전 서버 요청을 처리하고 있습니다."}
	busy=true
	var headers=PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():headers.append("Authorization: Bearer "+token)
	var error=transport.request(base_url+path,headers,method,JSON.stringify(body) if method!=HTTPClient.METHOD_GET else "")
	if error!=OK:
		busy=false
		return {"ok":false,"error":"서버 요청을 시작하지 못했습니다."}
	var result=await transport.request_completed
	busy=false
	if result[0]!=HTTPRequest.RESULT_SUCCESS:return {"ok":false,"error":"서버에 연결하지 못했습니다. 주소와 서버 실행 상태를 확인해 주세요."}
	var parser=JSON.new()
	if parser.parse(result[3].get_string_from_utf8())!=OK or not parser.data is Dictionary:return {"ok":false,"error":"올바르지 않은 서버 응답입니다."}
	var response: Dictionary=parser.data
	if result[1]<200 or result[1]>=300:
		response.ok=false
		response.error=str(response.get("error",response.get("detail","서버 요청 실패")))
		response.http_status=int(result[1])
		return response
	if response.has("revision"):revision=int(response.revision)
	if response.get("wallet") is Dictionary:wallet=response.wallet
	return response

func restore_connection(previous: Dictionary) -> void:
	base_url=previous.url
	token=previous.token
	revision=previous.revision
	wallet=previous.wallet
	connected=previous.connected
	was_online=previous.was_online
	connecting=false
	if local_mode_requested:
		connected=false
		was_online=false
		persist_connection()

func cancel_connection() -> void:
	if connecting:connection_serial+=1

func connect_server(address: String) -> Dictionary:
	if busy or connecting:return {"ok":false,"error":"연결 요청이 끝날 때까지 기다려 주세요."}
	var cleaned=address.strip_edges().trim_suffix("/")
	if not cleaned.begins_with("https://") and not cleaned.begins_with("http://127.0.0.1:") and not cleaned.begins_with("http://localhost:"):return {"ok":false,"error":"HTTPS 서버 주소를 입력해 주세요. 개발용 localhost만 HTTP를 허용합니다."}
	var previous={"url":base_url,"token":token,"revision":revision,"wallet":wallet.duplicate(true),"connected":connected,"was_online":was_online}
	connecting=true
	local_mode_requested=false
	connection_serial+=1
	var attempt: int=connection_serial
	if cleaned!=base_url:token=""
	base_url=cleaned
	var health=await send("/health",HTTPClient.METHOD_GET)
	if attempt!=connection_serial or not health.get("ok",false):
		restore_connection(previous)
		return health if attempt==connection_serial else {"ok":false,"cancelled":true,"error":"연결을 취소했습니다."}
	if int(health.get("protocol",0))!=2:
		restore_connection(previous)
		return {"ok":false,"error":"서버와 앱의 버전이 다릅니다. v0.3 서버로 업데이트해 주세요."}
	if token.is_empty():
		var session=await send("/session",HTTPClient.METHOD_POST)
		if attempt!=connection_serial or not session.get("ok",false) or not session.get("token") is String:
			restore_connection(previous)
			return session if attempt==connection_serial else {"ok":false,"cancelled":true,"error":"연결을 취소했습니다."}
		token=session.token
	var response=await fetch_state()
	if attempt!=connection_serial or not response.get("ok",false):
		restore_connection(previous)
		return response if attempt==connection_serial else {"ok":false,"cancelled":true,"error":"연결을 취소했습니다."}
	connected=true
	was_online=true
	connecting=false
	persist_connection()
	return response

func use_local_test() -> void:
	local_mode_requested=true
	cancel_connection()
	connected=false
	was_online=false
	persist_connection()

func fetch_state() -> Dictionary:return await send("/state",HTTPClient.METHOD_GET)

func mutate(operation: String,payload: Dictionary) -> Dictionary:
	var body=payload.duplicate(true)
	body.revision=revision
	body.request_id=Crypto.new().generate_random_bytes(16).hex_encode()
	return await send("/action/"+operation,HTTPClient.METHOD_POST,body)
