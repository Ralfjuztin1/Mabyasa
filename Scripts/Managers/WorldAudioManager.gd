extends Node

## MABYASA world music and ambience manager.
## This node should remain under Main.tscn so music survives zone changes.

@export_range(-30.0, 0.0, 0.5) var music_volume_db: float = -17.0
@export_range(0.5, 8.0, 0.5) var crossfade_seconds: float = 3.0
@export_range(0.1, 2.0, 0.1) var scene_poll_interval: float = 0.5

const GENERAL_AMBIENCE_PATH: String = \
	"res://Assets/Audio/World/bgm_yatu_pixelized.mp3"

const FOREST_MUSIC_PATH: String = \
	"res://Assets/Audio/World/bgm_yatu_pixelized.mp3"

var _poll_elapsed: float = 0.0
var _last_scene_path: String = ""
var _active_track_path: String = ""
var _active_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_switch_for_scene(_get_current_level_path(), true)
	set_process(true)


func _process(delta: float) -> void:
	_poll_elapsed += delta

	if _poll_elapsed < scene_poll_interval:
		return

	_poll_elapsed = 0.0

	var scene_path: String = _get_current_level_path()

	if scene_path != _last_scene_path:
		_switch_for_scene(scene_path)


func _get_current_level_path() -> String:
	if is_instance_valid(GameManager):
		var path: String = str(GameManager.current_level_path)

		if not path.is_empty():
			return path

	return "res://Scenes/Main/FirstTown.tscn"


func _switch_for_scene(
	scene_path: String,
	immediate: bool = false
) -> void:
	_last_scene_path = scene_path

	var normalized: String = scene_path.to_lower()

	# Use the pixelized music in Forest.
	# Other zones retain the existing Yatu ambience.
	var wanted_path: String = (
		FOREST_MUSIC_PATH
		if normalized.contains("forest")
		else GENERAL_AMBIENCE_PATH
	)

	if (
		wanted_path == _active_track_path
		and is_instance_valid(_active_player)
	):
		return

	if not ResourceLoader.exists(wanted_path):
		push_warning("[WORLD AUDIO] File not found: " + wanted_path)
		return

	var stream: AudioStream = load(wanted_path) as AudioStream

	if stream == null:
		push_warning("[WORLD AUDIO] Could not load: " + wanted_path)
		return

	# Loop the forest MP3.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	# Loop the existing general ambience WAV.
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)

	var next_player := AudioStreamPlayer.new()
	next_player.name = "WorldMusicPlayer"
	next_player.process_mode = Node.PROCESS_MODE_ALWAYS
	next_player.stream = stream
	next_player.volume_db = -60.0
	add_child(next_player)

	next_player.play()

	var previous_player: AudioStreamPlayer = _active_player

	_active_player = next_player
	_active_track_path = wanted_path

	var fade_in := create_tween()
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(
		next_player,
		"volume_db",
		music_volume_db,
		0.05 if immediate else crossfade_seconds
	)

	if is_instance_valid(previous_player):
		var fade_out := create_tween()
		fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade_out.tween_property(
			previous_player,
			"volume_db",
			-60.0,
			crossfade_seconds
		)
		fade_out.tween_callback(previous_player.stop)
		fade_out.tween_callback(previous_player.queue_free)
