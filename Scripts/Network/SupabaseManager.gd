extends Node

# --- Constants & Credentials ---
const SUPABASE_BASE_URL = "https://enqadhqpylshkgarsuog.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucWFkaHFweWxzaGtnYXJzdW9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0MDQwNzgsImV4cCI6MjEwMjk4MDA3OH0.BuRweg7FZXnhUzzgFfqn5w-JfP7ekK3iV6_sHsrw0Ww"

const REST_URL = SUPABASE_BASE_URL + "/rest/v1/"
const AUTH_URL = SUPABASE_BASE_URL + "/auth/v1/"

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

var session_token: String = ""
var current_user_email: String = "guest"
var current_user_id: String = ""
var pending_action: String = "" # Tracks whether we are logging in or registering to prevent signal mix-ups

var _cloud_sync_in_progress: bool = false
var _pending_cloud_sync_data: Dictionary = {}

# --- Initialization ---
func _ready():
	auth_request.request_completed.connect(_on_auth_request_completed)
	db_request.request_completed.connect(_on_db_request_completed)

# --- Authentication Functions ---
func register_user(email: String, password: String, username: String):
	pending_action = "register"
	current_user_email = email.strip_edges().to_lower()
	
	if GameManager:
		GameManager.active_user_email = current_user_email
		print("🔑 [SUPABASE] Registration intent locked for: ", current_user_email)

	var body = JSON.stringify({
		"email": email,
		"password": password,
		"data": {
			"username": username
		}
	})
	
	var endpoint = AUTH_URL + "signup"
	var error = auth_request.request(endpoint, auth_headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("An error occurred while making the registration request.")
		registration_completed.emit(false, "Network error.")

func login_user(email: String, password: String):
	pending_action = "login"
	current_user_email = email.strip_edges().to_lower()
	
	# ➔ SECURED: Immediately store email in both managers before network call
	if GameManager:
		GameManager.active_user_email = current_user_email
		print("🔑 [SUPABASE] Login session secured for: ", current_user_email)
	
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	var endpoint = AUTH_URL + "token?grant_type=password"
	var error = auth_request.request(endpoint, auth_headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("An error occurred while making the login request.")
		login_completed.emit(false, "Network error.")

func _on_auth_request_completed(result, response_code, headers, body):
	var json_text = body.get_string_from_utf8()
	var response = JSON.parse_string(json_text) if not json_text.is_empty() else {}
	if response == null: response = {}
	
	if response_code == 200 or response_code == 201:
		if pending_action == "login":
			if response.has("access_token"):
				session_token = response["access_token"]
			# Login response nests the user object under "user".
			if response.has("user") and typeof(response["user"]) == TYPE_DICTIONARY:
				current_user_id = response["user"].get("id", "")
			print("Login successful!")
			login_completed.emit(true, "Welcome back!")
		else:
			# Signup response returns the user object at the top level.
			current_user_id = response.get("id", "")
			print("Registration successful!")
			registration_completed.emit(true, "Registration successful!")
	else:
		var error_message = response.get("error_description", response.get("msg", "Unknown error."))
		print("Auth failed: ", error_message)
		
		if pending_action == "login":
			login_completed.emit(false, error_message)
		else:
			registration_completed.emit(false, error_message)


# --- Save Sync Functions ---
# These are what was actually missing: login only ever handled auth.
# Nothing previously pushed a save to Supabase or pulled one back down,
# which is why progress didn't follow the account across devices.

func sync_save_to_cloud(save_data: Dictionary) -> void:
	if session_token.is_empty() or current_user_id.is_empty():
		return # Guest or not logged in — nothing to sync.

	if _cloud_sync_in_progress:
		# A sync is already in flight on this HTTPRequest node — it can
		# only handle one request at a time. Remember this (newer) data
		# and send it automatically once the current one finishes,
		# instead of firing a second request that would just error.
		_pending_cloud_sync_data = save_data
		return

	_cloud_sync_in_progress = true
	_start_cloud_sync_request(save_data)


func _start_cloud_sync_request(save_data: Dictionary) -> void:
	var endpoint = REST_URL + "saves?on_conflict=user_id"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + session_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates,return=minimal"
	]
	var body = JSON.stringify({
		"user_id": current_user_id,
		"save_data": save_data,
		"updated_at": Time.get_datetime_string_from_system(true)
	})

	var error = db_request.request(endpoint, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		push_warning("[SUPABASE] Failed to start cloud save sync.")
		_cloud_sync_in_progress = false


func fetch_save_from_cloud() -> Dictionary:
	if session_token.is_empty() or current_user_id.is_empty():
		return {}

	var endpoint = REST_URL + "saves?user_id=eq." + current_user_id + "&select=save_data"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + session_token
	]

	var error = db_request.request(endpoint, headers, HTTPClient.METHOD_GET)

	if error != OK:
		push_warning("[SUPABASE] Failed to start cloud save fetch.")
		return {}

	var result = await db_request.request_completed
	var result_body: PackedByteArray = result[3]
	var json_text = result_body.get_string_from_utf8()
	var rows = JSON.parse_string(json_text) if not json_text.is_empty() else []

	if rows is Array and rows.size() > 0 and rows[0].has("save_data"):
		return rows[0]["save_data"]

	return {}


func _on_db_request_completed(_result, _response_code, _headers, _body) -> void:
	# fetch_save_from_cloud() awaits this signal directly for its own
	# response, so it doesn't need anything handled here.
	#
	# For sync_save_to_cloud(), this is what clears the in-flight flag
	# and — if newer save data queued up while this request was
	# running — immediately fires that one off next.
	if _cloud_sync_in_progress:
		_cloud_sync_in_progress = false

		if not _pending_cloud_sync_data.is_empty():
			var next_data := _pending_cloud_sync_data
			_pending_cloud_sync_data = {}
			sync_save_to_cloud(next_data)
