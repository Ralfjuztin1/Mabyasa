extends Node

signal completed(success: bool, message: String)

const WEB_APP_URL: String = "https://script.google.com/macros/s/AKfycbwfSecbUFOur9Hm454ob_uno2pSpMDcMwGvupx6OVDLc1lLMSuIotWn838Vpsnt7J5-9Q/exec"


func send_post_assessment_report(
	report: Dictionary,
	comparison: Dictionary,
	victory: bool,
	attempt_number: int
) -> void:
	if attempt_number != 1:
		completed.emit(false, "Only the first boss attempt is sent as the official post-assessment.")
		return

	if not is_instance_valid(SupabaseManager):
		completed.emit(false, "SupabaseManager is unavailable.")
		return

	if SupabaseManager.current_user_id.is_empty():
		completed.emit(false, "No authenticated player is signed in.")
		return

	if not await SupabaseManager._ensure_fresh_token():
		completed.emit(false, "Could not refresh the sign-in session.")
		return

	var body := {
		"assessment_type": "post",
		"access_token": SupabaseManager.session_token,
		"report": report.duplicate(true),
		"comparison": comparison.duplicate(true),
		"battle_outcome": "Victory" if victory else "Defeat",
		"attempt_number": attempt_number
	}

	var result: Dictionary = await _post_to_google(JSON.stringify(body))
	completed.emit(
		bool(result.get("success", false)),
		str(result.get("message", "Unknown email response."))
	)


func _post_to_google(body: String) -> Dictionary:
	var post := HTTPRequest.new()
	post.process_mode = Node.PROCESS_MODE_ALWAYS
	post.timeout = 35.0
	post.max_redirects = 0
	add_child(post)

	var err := post.request(
		WEB_APP_URL,
		PackedStringArray([
			"Content-Type: application/json",
			"Accept: application/json"
		]),
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		post.queue_free()
		return {"success": false, "message": "Could not start Google Apps Script request (%d)." % int(err)}

	var first: Array = await post.request_completed
	post.queue_free()

	if first.size() < 4:
		return {"success": false, "message": "Google returned an incomplete response."}

	var first_result := int(first[0])
	var first_code := int(first[1])
	var first_headers: PackedStringArray = first[2]
	var first_body := (first[3] as PackedByteArray).get_string_from_utf8()

	var response_code := first_code
	var response_body := first_body

	if first_code >= 300 and first_code < 400:
		var location := ""
		for header_line: String in first_headers:
			var colon := header_line.find(":")
			if colon < 0:
				continue
			if header_line.substr(0, colon).strip_edges().to_lower() == "location":
				location = header_line.substr(colon + 1).strip_edges()
				break

		if location.is_empty():
			return {"success": false, "message": "Google redirected the response without a Location header."}

		var get_request := HTTPRequest.new()
		get_request.process_mode = Node.PROCESS_MODE_ALWAYS
		get_request.timeout = 35.0
		get_request.max_redirects = 4
		add_child(get_request)

		err = get_request.request(
			location,
			PackedStringArray(["Accept: application/json"]),
			HTTPClient.METHOD_GET
		)
		if err != OK:
			get_request.queue_free()
			return {"success": false, "message": "Could not follow Google's response redirect."}

		var second: Array = await get_request.request_completed
		get_request.queue_free()

		if second.size() < 4:
			return {"success": false, "message": "Google redirect returned an incomplete response."}

		if int(second[0]) != HTTPRequest.RESULT_SUCCESS:
			return {"success": false, "message": "Google redirect transport failed."}

		response_code = int(second[1])
		response_body = (second[3] as PackedByteArray).get_string_from_utf8()

	elif first_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"message": "Google request failed (transport %d, HTTP %d)." % [first_result, first_code]
		}

	var parser := JSON.new()
	if parser.parse(response_body) != OK or not parser.data is Dictionary:
		return {
			"success": false,
			"message": "Google returned a non-JSON response (HTTP %d)." % response_code
		}

	var data: Dictionary = parser.data
	return {
		"success": response_code >= 200 and response_code < 300 and bool(data.get("success", false)),
		"message": str(data.get("message", "HTTP %d" % response_code))
	}
