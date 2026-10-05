class_name CutsceneAction
extends Node

## A single reusable cutscene instruction.
##
## Put these nodes under a CutsceneDirector. The Director executes them
## from top to bottom. Use CutsceneParallel for actions that should happen
## at the same time.

enum ActionType {
	WAIT,
	TELEPORT,
	MOVE,
	FACE_ACTOR,
	FACE_POINT,
	FACE_DIRECTION,
	PLAY_ANIMATION,
	DIALOGUE,
	CAMERA_SHOT,
	RETURN_CAMERA,
	FADE_OUT,
	FADE_IN,
	SHOW_HIDE
}

@export_category("Action")
@export_enum(
	"Wait",
	"Teleport",
	"Move",
	"Face Actor",
	"Face Point",
	"Face Direction",
	"Play Animation",
	"Dialogue",
	"Camera Shot",
	"Return Player Camera",
	"Fade Out",
	"Fade In",
	"Show / Hide"
)
var action_type: int = ActionType.WAIT

@export var enabled: bool = true

@export_category("Actor / Target")
## Use "Player" for the player. NPCs can use their node name, such as "ima".
@export var actor_id: String = ""

## Used for Teleport / Move / Face Point / Camera Shot.
## Example: "Scene1StartPoint", "ImaTalkPoint", "WakingUpCamera".
@export var target_id: String = ""

## Used by Face Actor.
@export var target_actor_id: String = ""

@export_category("Animation")
## Example: idle_front, idle_back, idle_left, idle_right, walk_front.
@export var animation_name: String = ""

@export_category("Dialogue")
@export_file("*.dtl")
var timeline_path: String = ""

@export_category("Timing")
@export_range(0.0, 30.0, 0.05)
var seconds: float = 0.0

@export_range(0.0, 2.0, 0.01)
var fade_duration: float = 0.18

@export_range(0.0, 1.0, 0.01)
var stopping_distance: float = 0.05

@export_category("Teleport")
## When enabled, teleport also stops velocity and resets the sprite from
## any previous run/walk state. This prevents the cutscene from inheriting
## the last gameplay animation.
@export var reset_visual_state: bool = true

## Copy only the target marker's Y rotation when teleporting.
@export var copy_target_y_rotation: bool = false

@export_category("Facing")
## Used by Face Direction.
@export var face_direction: Vector3 = Vector3(0.0, 0.0, 1.0)

@export_category("Visibility")
@export var visible_state: bool = true


func execute(director: CutsceneDirector) -> void:
	if not enabled:
		return

	if not is_instance_valid(director):
		return

	await director.execute_action(self)
