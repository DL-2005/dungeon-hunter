extends Control

const ENCHANT_PRICE := 30

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
	recommended_label.text = "Recommended for you: " + recommended
	_refresh()

func _refresh() -> void:
	currency_label.text = "Gold: " + str(GameManager.currency)
	for name in buttons:
		buttons[name].text = name + "  (" + str(ENCHANT_PRICE) + " gold)"
		buttons[name].disabled = GameManager.currency < ENCHANT_PRICE

func _on_enchant_pressed(enchant_name: String) -> void:
	if GameManager.currency >= ENCHANT_PRICE:
		GameManager.currency -= ENCHANT_PRICE
		GameManager.equip_enchant(enchant_name)
		close()

func close() -> void:
	visible = false
