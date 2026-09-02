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
var current_user_email: String = "guest" # Tracks who is currently logged in for local saves

# --- Initialization ---
func _ready():
	auth_request.request_completed.connect(_on_auth_request_completed)

# --- Authentication Functions ---
func register_user(email: String, password: String, username: String):
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
	# Save the user email locally so the SaveManager knows whose file to use
	current_user_email = email.strip_edges().to_lower()
	
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
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
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
		registration_completed.emit(false, error_message)
		login_completed.emit(false, error_message)
