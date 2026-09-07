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
var pending_action: String = "" # Tracks whether we are logging in or registering to prevent signal mix-ups

# --- Initialization ---
func _ready():
	auth_request.request_completed.connect(_on_auth_request_completed)

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
			print("Login successful!")
			login_completed.emit(true, "Welcome back!")
		else:
			print("Registration successful!")
			registration_completed.emit(true, "Registration successful!")
	else:
		var error_message = response.get("error_description", response.get("msg", "Unknown error."))
		print("Auth failed: ", error_message)
		
		if pending_action == "login":
			login_completed.emit(false, error_message)
		else:
			registration_completed.emit(false, error_message)
