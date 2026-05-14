extends Node

signal login_succeeded(user_id: String, username: String)
signal login_failed(message: String)
signal status_changed(message: String)

var network: NetworkClient
var user_id := ""
var username := ""
var email := ""
var logging_in := false

func _ready() -> void:
	network = NetworkClient.new()
	add_child(network)
	network.authenticated.connect(_on_authenticated)
	network.status_changed.connect(_on_network_status_changed)

func is_logged_in() -> bool:
	return not user_id.is_empty() and network.session != null

func login(login_email: String, password: String) -> void:
	if logging_in:
		return
	if is_logged_in():
		login_succeeded.emit(user_id, username)
		return

	email = login_email.strip_edges()
	logging_in = true
	status_changed.emit("正在登录...")
	await network.login(email, password)

func default_email() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--email" and index + 1 < args.size():
			return args[index + 1]
		if args[index].begins_with("--email="):
			return args[index].trim_prefix("--email=")
	return "player-%s@breach.local" % str(Time.get_ticks_usec())

func default_password() -> String:
	return "breach-local-password"

func _on_authenticated(auth_user_id: String, auth_username: String) -> void:
	user_id = auth_user_id
	username = auth_username
	logging_in = false
	login_succeeded.emit(user_id, username)

func _on_network_status_changed(message: String) -> void:
	status_changed.emit(message)
	if message.begins_with("Auth failed") or message.begins_with("Socket failed"):
		logging_in = false
		login_failed.emit(message)
