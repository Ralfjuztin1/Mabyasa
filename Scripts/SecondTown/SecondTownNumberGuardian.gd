extends "res://Scenes/Characters/NPC/Enemy/Enemy.gd"

## Boss 2. Not visible/active until the Elder well quest is finished.
const NUMBER_BOSS_ID: String = "second_town_number_guardian"
const DEFEATED_FLAG: String = "st_number_guardian_defeated"
const NUMBER_BATTLE_SCREEN: PackedScene = preload("res://Scenes/Battle/SecondTownNumberBattleScreen.tscn")

var _gate_timer: float = 0.0
var _unlocked: bool = false

func _ready() -> void:
	super._ready()
	if QuestManager.has_dialogue_flag(DEFEATED_FLAG):
		_defeated = true
		detection_area.set_deferred("monitoring", false)
		queue_free()
		return
	_refresh_gate()

func _process(delta: float) -> void:
	_gate_timer += delta
	if _gate_timer >= 0.5:
		_gate_timer = 0.0
		_refresh_gate()

func _refresh_gate() -> void:
	if _defeated or not is_instance_valid(detection_area):
		return
	var allowed: bool = QuestManager.is_quest_completed("st_elder_well")
	if allowed == _unlocked and visible == allowed:
		return
	_unlocked = allowed
	visible = allowed
	detection_area.set_deferred("monitoring", allowed)

func _start_battle() -> void:
	if not _unlocked or _encounter_started or BattleManager.battle_active:
		return
	if get_tree().current_scene == null:
		push_error("[NUMBERS BOSS] Missing current scene.")
		return

	_encounter_started = true
	_battle_enemy_data = EnemyData.new()
	_battle_enemy_data.enemy_id = NUMBER_BOSS_ID
	_battle_enemy_data.display_name = enemy_name
	_battle_enemy_data.is_boss = true
	_battle_enemy_data.max_hp = maxi(enemy_max_hp, 1)
	_battle_enemy_data.max_barrier = maxi(enemy_max_barrier, 0)
	_battle_enemy_data.atk = maxi(enemy_atk, 1)
	_battle_enemy_data.exp_reward = maxi(enemy_exp_reward, 0)
	_battle_enemy_data.gold_reward = maxi(enemy_gold_reward, 0)
	_battle_enemy_data.battle_sprite_frames = battle_sprite_frames if battle_sprite_frames != null else world_sprite_frames
	_battle_enemy_data.battle_sprite_animation = battle_sprite_animation
	_battle_enemy_data.battle_attack_animation = battle_attack_animation
	_battle_enemy_data.battle_hit_animation = battle_hit_animation
	_battle_enemy_data.battle_attack_duration = battle_attack_duration
	_battle_enemy_data.battle_sprite_flip_h = battle_sprite_flip_h

	var screen: CanvasLayer = NUMBER_BATTLE_SCREEN.instantiate() as CanvasLayer
	if screen == null:
		_encounter_started = false
		_battle_enemy_data = null
		push_error("[NUMBERS BOSS] Number battle screen scene failed to instantiate.")
		return
	get_tree().current_scene.add_child(screen)
	BattleManager.start_battle(_battle_enemy_data)
	if not BattleManager.battle_active:
		screen.queue_free()
		_encounter_started = false
		_battle_enemy_data = null

func _on_battle_ended(victory: bool) -> void:
	if _battle_enemy_data == null or BattleManager.current_enemy != _battle_enemy_data:
		return
	if victory:
		QuestManager.set_dialogue_flag(DEFEATED_FLAG, true)
		GameManager.request_save()
	super._on_battle_ended(victory)
