extends Control

const ENCHANT_PRICE := 30
signal closed
var _purchase_in_progress: bool = false
@onready var recommended_label: Label = $Panel/VBoxContainer/RecommendedLabel
@onready var currency_label: Label = $Panel/VBoxContainer/CurrencyLabel
@onready var buttons: Dictionary = {
	"Vampiric": $Panel/VBoxContainer/VampiricButton,
	"Swift": $Panel/VBoxContainer/SwiftButton,
	"Guardian": $Panel/VBoxContainer/GuardianButton,
	"Berserker": $Panel/VBoxContainer/BerserkerButton,
}

func _ready() -> void:
	for name in buttons:
		buttons[name].pressed.connect(_on_enchant_pressed.bind(name))

func open(recommended: String) -> void:
	visible = true
	_purchase_in_progress = false   # NEW -- reset the guard each time the shop opens
	recommended_label.text = "Recommended for you: " + recommended
	_refresh()
	get_tree().paused = true   # NEW -- freeze mobs/boss/player while shopping

func _refresh() -> void:
	currency_label.text = "Gold: " + str(GameManager.currency)
	for name in buttons:
		buttons[name].text = name + "  (" + str(ENCHANT_PRICE) + " gold)"
		buttons[name].disabled = GameManager.currency < ENCHANT_PRICE

func _on_enchant_pressed(enchant_name: String) -> void:
	if _purchase_in_progress:
		return   # NEW -- ignore any further presses until the shop reopens
	if GameManager.currency >= ENCHANT_PRICE:
		_purchase_in_progress = true   # NEW -- lock immediately, before anything else runs
		GameManager.currency -= ENCHANT_PRICE
		GameManager.equip_enchant(enchant_name)
		close()

func close() -> void:
	visible = false
	get_tree().paused = false   # NEW -- resume the game once a choice is made
	closed.emit()
