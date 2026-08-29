extends Control

signal closed

@onready var instructions_label: Label = $Panel/VBoxContainer/InstructionsLabel
@onready var start_button: Button = $Panel/VBoxContainer/StartButton

func _ready() -> void:
	instructions_label.text = "Dungeon Hunter\n\nWASD - Move\nSpace - Attack\nShift - Dodge\n\nDefeat the boss to earn gold and buy enchants!"
	start_button.pressed.connect(_on_start_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.process_mode = Node.PROCESS_MODE_ALWAYS

func open() -> void:
	visible = true
	get_tree().paused = true

func _on_start_pressed() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
