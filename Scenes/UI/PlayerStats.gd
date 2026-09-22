extends CanvasLayer

signal closed

@onready var close_button: Button = $Center/StatsPanel/Margin/MainVBox/SubHeaderRow/CloseButton

@onready var level_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/LevelRow/LevelValueLabel
@onready var xp_bar: ProgressBar = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/XPBar
@onready var xp_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/XPLabel

@onready var atk_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/StatsGrid/AtkValueLabel
@onready var def_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/StatsGrid/DefValueLabel
@onready var hp_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/StatsGrid/HpValueLabel

@onready var sword_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/GearGrid/SwordValueLabel
@onready var armor_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/GearGrid/ArmorValueLabel
@onready var helmet_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/GearGrid/HelmetValueLabel

@onready var gold_value_label: Label = $Center/StatsPanel/Margin/MainVBox/DetailPanel/DetailMargin/DetailVBox/GoldRow/GoldValueLabel


func _ready() -> void:
	# Same convention as QuestLog: opened as a menu, keeps working while
	# the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	close_button.pressed.connect(close)

	if PlayerProgression:
		PlayerProgression.stats_changed.connect(_refresh)
		PlayerProgression.leveled_up.connect(_refresh)

	visible = false


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not PlayerProgression:
		return

	var level: int = PlayerProgression.level
	var current_exp: int = PlayerProgression.current_exp
	var max_exp: int = PlayerProgression.get_max_exp(level)

	level_value_label.text = "Lv. %d" % level

	if max_exp > 0:
		xp_bar.value = (float(current_exp) / float(max_exp)) * 100.0

	xp_label.text = "EXP  %d / %d" % [current_exp, max_exp]

	atk_value_label.text = str(PlayerProgression.get_total_atk())
	def_value_label.text = str(PlayerProgression.get_total_def())
	hp_value_label.text = str(PlayerProgression.get_total_max_hp())

	sword_value_label.text = "Lv. %d" % PlayerProgression.gear_levels.get("sword", 1)
	armor_value_label.text = "Lv. %d" % PlayerProgression.gear_levels.get("armor", 1)
	helmet_value_label.text = "Lv. %d" % PlayerProgression.gear_levels.get("helmet", 1)

	gold_value_label.text = "🪙 %d" % PlayerProgression.gold
