extends Node

# ============================================================
# SUPABASE MANAGER
# ============================================================
# SUPABASE_KEY is the *anon* key. It is meant to be public, but that is only
# safe because Row Level Security (RLS) on your tables decides what each
# logged-in user can read/write. Make sure RLS is ON for `saves`.
#
# What changed vs. the previous version:
#  - Stores refresh_token + expiry, and refreshes the login token before it
#    expires (Supabase tokens last ~1 hour; before, cloud saves silently
#    started failing after that).
#  - Checks HTTP response codes (before, failures were ignored).
#  - Retries once after a 401 (expired token) with a fresh token.
#  - Timeouts on every request, so a bad connection can't hang login forever.
#  - All database calls are serialized (save + fetch can't collide on the
#    single HTTPRequest node anymore).
#  - A queued save now remembers which account it belongs to, so it can never
#    be uploaded into a different account after logout/login.
#  - Keeps working while the game is paused (HTTP used to stall when paused).
#  - Detects "email already registered" on signup.
#  - GameManager.active_user_email is no longer set before login succeeds
#    (initialize_session() already sets it after a successful login).
#  - The user ID comes from the signed login token ("sub" = the same ID
#    Supabase RLS uses as auth.uid()). A login/refresh without a verifiable
#    ID is rejected, and a refresh can never switch to another account.
#  - Auth responses are tied to the request and session generation that started them;
#    late login/refresh responses cannot revive a logged-out account.
#  - login_user() starts from a clean session, so previous account credentials are removed.
#  - Saves are snapshotted (deep copy) when queued, and restored rows are
#    checked to belong to the authenticated user ID.
# ============================================================

# --- Constants & Credentials ---
const SUPABASE_BASE_URL = "https://enqadhqpylshkgarsuog.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucWFkaHFweWxzaGtnYXJzdW9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0MDQwNzgsImV4cCI6MjEwMjk4MDA3OH0.BuRweg7FZXnhUzzgFfqn5w-JfP7ekK3iV6_sHsrw0Ww"

const REST_URL = SUPABASE_BASE_URL + "/rest/v1/"
const AUTH_URL = SUPABASE_BASE_URL + "/auth/v1/"

const REQUEST_TIMEOUT_SEC: float = 15.0
const TOKEN_REFRESH_MARGIN_SEC: int = 120
const DEFAULT_TOKEN_LIFETIME_SEC: int = 3600

var base_headers = [
	"apikey: " + SUPABASE_KEY,
	"Authorization: Bearer " + SUPABASE_KEY,
	"Content-Type: application/json",
	"Prefer: return=representation"
]

var auth_headers = [
	"apikey: " + SUPABASE_KEY,
	"Content-Type: application/json"
]

# --- Nodes & Variables ---
@onready var db_request = $SupabaseRequest
@onready var auth_request = $AuthRequest

signal registration_completed(success: bool, message: String)
signal login_completed(success: bool, message: String)
# Emitted when the login can no longer be renewed (refresh token rejected).
# The UI can listen to this and send the player back to the login screen.
signal session_expired
signal _refresh_finished(success: bool)

var session_token: String = ""
var refresh_token: String = ""
var token_expires_at: int = 0 # unix seconds
var current_user_email: String = "guest"
var current_user_id: String = ""
var current_adventurer_name: String = ""
var pending_action: String = "" # Kept for debug/compatibility; response routing uses the active request.

# HTTPRequest only permits one active request. Track the action and session
# generation belonging to that request so a late refresh response cannot be
# mistaken for a newly submitted login after logout/account switching.
var _session_generation: int = 0
var _auth_request_in_flight: bool = false
var _active_auth_action: String = ""
var _active_auth_generation: int = 0
var _queued_auth_action: String = ""
var _queued_auth_url: String = ""
var _queued_auth_body: String = ""
var _queued_auth_generation: int = 0

var _cloud_sync_in_progress: bool = false
var _pending_cloud_sync_data: Dictionary = {}
var _pending_cloud_sync_user_id: String = ""
var _db_busy: bool = false
var _refresh_in_progress: bool = false


# --- Initialization ---
func _ready():
	# HTTP requests must keep running while the game is paused
	# (e.g. saving from the pause menu or when the window is closed).
	process_mode = Node.PROCESS_MODE_ALWAYS

	auth_request.timeout = REQUEST_TIMEOUT_SEC
	db_request.timeout = REQUEST_TIMEOUT_SEC
	auth_request.request_completed.connect(_on_auth_request_completed)


# --- Authentication Functions ---
func register_user(email: String, password: String, username: String):
	# Registration should not reuse a previously authenticated account.
	clear_session()
	current_user_email = email.strip_edges().to_lower()
	var body: String = JSON.stringify({
		"email": email.strip_edges(),
		"password": password,
		"data": {
			"username": username.strip_edges()
		}
	})
	_request_or_queue_auth(
		"register",
		AUTH_URL + "signup",
		body
	)


func login_user(email: String, password: String):
	# Invalidate the previous session immediately. If an old HTTP request is
	# still running, its response is ignored and this login is queued behind it.
	clear_session()
	current_user_email = email.strip_edges().to_lower()

	var body: String = JSON.stringify({
		"email": email.strip_edges(),
		"password": password
	})
	_request_or_queue_auth(
		"login",
		AUTH_URL + "token?grant_type=password",
		body
	)


func _request_or_queue_auth(action: String, url: String, body: String) -> Error:
	var generation: int = _session_generation

	if _auth_request_in_flight:
		# Keep the newest requested operation. Any replaced queued operation is
		# explicitly failed so its UI does not wait forever for a signal.
		if not _queued_auth_action.is_empty():
			_notify_auth_failure(
				_queued_auth_action,
				"Authentication request replaced by a newer request."
			)
		_queued_auth_action = action
		_queued_auth_url = url
		_queued_auth_body = body
		_queued_auth_generation = generation
		return OK

	return _start_auth_request(action, url, body, generation, false)


func _start_auth_request(
	action: String,
	url: String,
	body: String,
	generation: int,
	from_queue: bool
) -> Error:
	if generation != _session_generation:
		if from_queue:
			_notify_auth_failure(action, "Authentication request cancelled because the session changed.")
		return FAILED

	_active_auth_action = action
	_active_auth_generation = generation
	_auth_request_in_flight = true
	pending_action = action

	var error: Error = auth_request.request(
		url,
		auth_headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		_auth_request_in_flight = false
		_active_auth_action = ""
		pending_action = ""
		if action == "refresh":
			# A queued refresh already has callers waiting for this signal.
			if from_queue:
				_refresh_finished.emit(false)
		else:
			_notify_auth_failure(action, "Network error.")
	return error


func _start_queued_auth_request() -> void:
	if _auth_request_in_flight or _queued_auth_action.is_empty():
		return

	var action: String = _queued_auth_action
	var url: String = _queued_auth_url
	var body: String = _queued_auth_body
	var generation: int = _queued_auth_generation

	_queued_auth_action = ""
	_queued_auth_url = ""
	_queued_auth_body = ""
	_queued_auth_generation = 0

	_start_auth_request(action, url, body, generation, true)


func _notify_auth_failure(action: String, message: String) -> void:
	match action:
		"login":
			login_completed.emit(false, message)
		"register":
			registration_completed.emit(false, message)
		"refresh":
			_refresh_finished.emit(false)


func _on_auth_request_completed(result, response_code, _headers, body) -> void:
	# Capture the action/generation that actually started this network request.
	# Never route a response using a mutable action set by a later button click.
	var action: String = _active_auth_action
	var request_generation: int = _active_auth_generation

	_auth_request_in_flight = false
	_active_auth_action = ""
	pending_action = ""

	if action.is_empty():
		call_deferred("_start_queued_auth_request")
		return

	if request_generation != _session_generation:
		# This response belongs to a session that was logged out or replaced.
		# Refresh waiters must always be released. For a stale login/registration,
		# suppress its failure signal if a replacement request is already queued;
		# otherwise an old result could disrupt the newer form submission.
		if action == "refresh" or _queued_auth_action.is_empty():
			_notify_auth_failure(action, "Authentication request cancelled because the session changed.")
		call_deferred("_start_queued_auth_request")
		return

	_handle_auth_response(action, result, response_code, body)
	call_deferred("_start_queued_auth_request")


func _handle_auth_response(action: String, result: int, response_code: int, body: PackedByteArray) -> void:
	var json_text: String = body.get_string_from_utf8()
	var response: Variant = JSON.parse_string(json_text) if not json_text.is_empty() else {}
	if not response is Dictionary:
		response = {}
	var data: Dictionary = response as Dictionary

	var ok: bool = (
		result == HTTPRequest.RESULT_SUCCESS
		and (response_code == 200 or response_code == 201)
	)

	# ---------------- TOKEN REFRESH ----------------
	if action == "refresh":
		if ok and data.has("access_token") and _store_session(data):
			_refresh_finished.emit(true)
		else:
			# A rejected refresh, or an invalid successful response, ends the
			# session. A temporary transport failure leaves account identity in
			# place so local saves remain mapped to that same user ID.
			var rejected: bool = ok or response_code == 400 or response_code == 401 or response_code == 403
			if rejected:
				session_token = ""
				refresh_token = ""
				token_expires_at = 0
				session_expired.emit()
			_refresh_finished.emit(false)
		return

	# ---------------- LOGIN ----------------
	if action == "login":
		if ok and data.has("access_token"):
			if _store_session(data):
				print("Login successful!")
				login_completed.emit(true, "Welcome back!")
			else:
				clear_session()
				login_completed.emit(false, "Could not verify your account ID. Please try again.")
		else:
			var message: String = _extract_error(result, data, "Login failed.")
			print("Auth failed: ", message)
			login_completed.emit(false, message)
		return

	# ---------------- REGISTER ----------------
	if action == "register":
		if ok:
			# With email confirmation ON, Supabase may return an empty identities
			# list when that email has already been registered.
			var identities: Variant = data.get("identities", null)
			if identities is Array and (identities as Array).is_empty():
				registration_completed.emit(false, "That email is already registered. Try logging in.")
				return
			print("Registration successful!")
			registration_completed.emit(true, "Registration successful!")
		else:
			var message: String = _extract_error(result, data, "Registration failed.")
			print("Auth failed: ", message)
			registration_completed.emit(false, message)


func _extract_error(result: int, data: Dictionary, fallback: String) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Network error. Check your connection and try again."
	return str(data.get("error_description", data.get("msg", data.get("message", fallback))))


# Validates and stores a login/refresh response. Returns false (and changes
# nothing) if the authenticated user ID cannot be determined, or if a refresh
# would move this session to a different account.
func _store_session(data: Dictionary) -> bool:
	var access_token: String = str(data.get("access_token", ""))

	# The ID inside the signed token ("sub") is the same ID Supabase uses for
	# Row Level Security (auth.uid()), so it is the authoritative one.
	var token_user_id: String = _user_id_from_jwt(access_token)

	var body_user_id: String = ""
	var profile_name: String = ""
	var user: Variant = data.get("user", null)
	if user is Dictionary:
		var user_data: Dictionary = user as Dictionary
		body_user_id = str(user_data.get("id", "")).to_lower()

		# The registration form stores Adventurer Name as Supabase user metadata.
		# Read it from the user object returned by login/refresh, but do not apply
		# it until the account ID has passed validation below.
		var metadata: Variant = user_data.get("user_metadata", {})
		if metadata is Dictionary:
			profile_name = str(
				(metadata as Dictionary).get(
					"username",
					(metadata as Dictionary).get("adventurer_name", "")
				)
			).strip_edges()

	var user_id: String = token_user_id if not token_user_id.is_empty() else body_user_id

	if user_id.is_empty():
		return false
	if not body_user_id.is_empty() and body_user_id != user_id:
		return false
	if not current_user_id.is_empty() and user_id != current_user_id:
		return false

	if not profile_name.is_empty():
		current_adventurer_name = profile_name

	session_token = access_token

	var new_refresh: String = str(data.get("refresh_token", ""))
	if not new_refresh.is_empty():
		refresh_token = new_refresh # Supabase rotates refresh tokens; always keep the newest

	var lifetime: int = int(data.get("expires_in", DEFAULT_TOKEN_LIFETIME_SEC))
	token_expires_at = int(Time.get_unix_time_from_system()) + lifetime
	current_user_id = user_id
	return true


# Reads the "sub" (user ID) claim from the JWT access token.
func _user_id_from_jwt(token: String) -> String:
	var parts: PackedStringArray = token.split(".")
	if parts.size() < 2:
		return ""

	var payload: String = parts[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="

	var json_text: String = Marshalls.base64_to_utf8(payload)
	if json_text.is_empty():
		return ""

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("sub", "")).to_lower()
	return ""


# --- Token handling ---
# True if there is a usable token afterwards (refreshing it first if it is
# about to expire).
func _ensure_fresh_token() -> bool:
	if session_token.is_empty():
		return false
	if int(Time.get_unix_time_from_system()) < token_expires_at - TOKEN_REFRESH_MARGIN_SEC:
		return true
	return await _refresh_session()


func _refresh_session() -> bool:
	if refresh_token.is_empty():
		return false

	# Multiple save calls can reach this at once; share one refresh response.
	if _refresh_in_progress:
		var shared_result: bool = await _refresh_finished
		return shared_result

	# Do not start/queue a refresh behind a login or registration. That could
	# use credentials that are being replaced. The caller can retry later.
	if _auth_request_in_flight and _active_auth_action != "refresh":
		return false

	_refresh_in_progress = true
	var body: String = JSON.stringify({"refresh_token": refresh_token})
	var error: Error = _request_or_queue_auth(
		"refresh",
		AUTH_URL + "token?grant_type=refresh_token",
		body
	)

	if error != OK:
		_refresh_in_progress = false
		return false

	var success: bool = await _refresh_finished
	_refresh_in_progress = false
	return success


# Clears everything that belongs to the logged-in account.
# GameManager.clear_session_data() calls this on logout.
func clear_session() -> void:
	# Incrementing this makes every currently running auth response stale.
	# The HTTP request may still finish, but it cannot resurrect the old login.
	_session_generation += 1

	if not _queued_auth_action.is_empty():
		_notify_auth_failure(
			_queued_auth_action,
			"Authentication request cancelled because the session was cleared."
		)
	_queued_auth_action = ""
	_queued_auth_url = ""
	_queued_auth_body = ""
	_queued_auth_generation = 0
	pending_action = ""

	# Keep GameManager's deferred saves/load continuations invalidated whenever
	# this manager clears an authenticated session, regardless of the caller.
	if GameManager:
		GameManager._session_generation += 1
		GameManager._session_ready = false
		GameManager.active_user_email = ""
		GameManager.adventurer_name = "Adventurer"
		GameManager.quest_save_queued = false

	session_token = ""
	refresh_token = ""
	token_expires_at = 0
	current_user_id = ""
	current_user_email = "guest"
	current_adventurer_name = ""
	_pending_cloud_sync_data = {}
	_pending_cloud_sync_user_id = ""


# --- Database call helper ---
# All REST calls go through here so they run one at a time on the single
# HTTPRequest node. Returns [result, response_code, headers, body].
func _db_call(url: String, headers: PackedStringArray, method: int, body: String = "") -> Array:
	while _db_busy:
		await get_tree().process_frame

	_db_busy = true
	var error = db_request.request(url, headers, method, body)

	if error != OK:
		_db_busy = false
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]

	var response: Array = await db_request.request_completed
	_db_busy = false
	return response


# --- Save Sync Functions ---
func sync_save_to_cloud(save_data: Dictionary) -> void:
	if session_token.is_empty() or current_user_id.is_empty():
		return # Guest or not logged in — nothing to sync.

	# Deep copy: the save dictionary holds live references to manager data
	# (quests, etc.) that gets cleared on logout. Upload a frozen snapshot.
	var snapshot: Dictionary = save_data.duplicate(true)

	if _cloud_sync_in_progress:
		# A sync is already running. Keep only the newest data (and who it
		# belongs to) and send it as soon as the current one finishes.
		_pending_cloud_sync_data = snapshot
		_pending_cloud_sync_user_id = current_user_id
		return

	_cloud_sync_in_progress = true
	_run_cloud_sync(snapshot, current_user_id) # intentionally not awaited


func _run_cloud_sync(save_data: Dictionary, user_id: String) -> void:
	await _post_save(save_data, user_id)
	_cloud_sync_in_progress = false

	if _pending_cloud_sync_data.is_empty():
		return

	var next_data: Dictionary = _pending_cloud_sync_data
	var next_user_id: String = _pending_cloud_sync_user_id
	_pending_cloud_sync_data = {}
	_pending_cloud_sync_user_id = ""

	# Only send the queued save if the SAME account is still logged in.
	if next_user_id == current_user_id and not session_token.is_empty():
		sync_save_to_cloud(next_data)


func _post_save(save_data: Dictionary, user_id: String) -> bool:
	for attempt: int in range(2):
		if not await _ensure_fresh_token():
			push_warning("[SUPABASE] Cloud save skipped: no valid login session.")
			return false

		if user_id != current_user_id:
			return false # logged out / switched account while waiting

		var headers := PackedStringArray([
			"apikey: " + SUPABASE_KEY,
			"Authorization: Bearer " + session_token,
			"Content-Type: application/json",
			"Prefer: resolution=merge-duplicates,return=minimal"
		])

		var body: String = JSON.stringify({
			"user_id": user_id,
			"save_data": save_data,
			"updated_at": Time.get_datetime_string_from_system(true) + "Z"
		})

		var response: Array = await _db_call(
			REST_URL + "saves?on_conflict=user_id",
			headers,
			HTTPClient.METHOD_POST,
			body
		)
		var code: int = int(response[1])

		if code == 200 or code == 201 or code == 204:
			return true

		if code == 401 and attempt == 0:
			token_expires_at = 0 # force a refresh, then try once more
			continue

		push_warning("[SUPABASE] Cloud save failed (HTTP %d)." % code)
		return false

	return false


func fetch_save_from_cloud() -> Dictionary:
	if session_token.is_empty() or current_user_id.is_empty():
		return {}

	var user_id: String = current_user_id

	for attempt: int in range(2):
		if not await _ensure_fresh_token():
			return {}

		if user_id != current_user_id:
			return {}

		var headers := PackedStringArray([
			"apikey: " + SUPABASE_KEY,
			"Authorization: Bearer " + session_token
		])

		var endpoint: String = REST_URL + "saves?user_id=eq." + user_id + "&select=user_id,save_data"
		var response: Array = await _db_call(endpoint, headers, HTTPClient.METHOD_GET)
		# Account may have changed while the HTTP request was in flight.
		if user_id != current_user_id or session_token.is_empty():
			return {}
		var code: int = int(response[1])

		if code == 401 and attempt == 0:
			token_expires_at = 0 # force a refresh, then try once more
			continue

		if code != 200:
			push_warning("[SUPABASE] Cloud save fetch failed (HTTP %d)." % code)
			return {}

		var result_body: PackedByteArray = response[3]
		var json_text: String = result_body.get_string_from_utf8()
		var rows: Variant = JSON.parse_string(json_text) if not json_text.is_empty() else []

		if rows is Array and (rows as Array).size() > 0:
			var first: Variant = (rows as Array)[0]
			if first is Dictionary and (first as Dictionary).has("save_data"):
				if str((first as Dictionary).get("user_id", "")).to_lower() != user_id:
					push_warning("[SUPABASE] Ignored a cloud save that does not belong to the authenticated user ID.")
					return {}
				var cloud_save: Variant = (first as Dictionary)["save_data"]
				if cloud_save is Dictionary:
					return cloud_save as Dictionary

		return {}

	return {}


# Waits (up to max_wait_sec) for any running cloud save/fetch to finish.
# Used when the window is closed so the last save has time to upload.
func wait_until_idle(max_wait_sec: float = 3.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(max_wait_sec * 1000.0)
	while (_cloud_sync_in_progress or _db_busy or _refresh_in_progress) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
