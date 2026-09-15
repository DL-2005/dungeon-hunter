extends Control

signal choice_made(choice: String)

@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel
@onready var hunt_button: Button = $Panel/VBoxContainer/HuntButton
@onready var skip_button: Button = $Panel/VBoxContainer/SkipButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	hunt_button.pressed.connect(_on_hunt_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS
	hunt_button.process_mode = Node.PROCESS_MODE_ALWAYS
	skip_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

func open(can_hunt: bool) -> void:
	info_label.text = "Gauntlet complete!"
	hunt_button.visible = can_hunt
	visible = true
	get_tree().paused = true

func _on_hunt_pressed() -> void:
	_close()
	choice_made.emit("hunt")

func _on_skip_pressed() -> void:
	_close()
	choice_made.emit("skip")

func _on_quit_pressed() -> void:
	_close()
	choice_made.emit("quit")

func _close() -> void:
	visible = false
	get_tree().paused = false
