extends Control

const ENCHANT_PRICE := 30
signal closed
var _purchase_in_progress: bool = false
var _free_mode: bool = false

@onready var recommended_label: Label = $Panel/VBoxContainer/RecommendedLabel
@onready var currency_label: Label = $Panel/VBoxContainer/CurrencyLabel
@onready var buttons: Dictionary = {
	"Vampiric": $Panel/VBoxContainer/VampiricButton,
	"Regeneration": $Panel/VBoxContainer/RegenerationButton,
	"Guardian": $Panel/VBoxContainer/GuardianButton,
	"Berserker": $Panel/VBoxContainer/BerserkerButton,
}

func _ready() -> void:
	for name in buttons:
		buttons[name].pressed.connect(_on_enchant_pressed.bind(name))

func open(recommended: String) -> void:
	visible = true
	_purchase_in_progress = false
	_free_mode = false
	recommended_label.text = "Recommended for you: " + recommended
	_refresh()
	get_tree().paused = true

func open_free_choice() -> void:
	visible = true
	_purchase_in_progress = false
	_free_mode = true
	recommended_label.text = "Choose your reward:"
	_refresh()
	get_tree().paused = true

func _refresh() -> void:
	currency_label.text = "Gold: " + str(GameManager.currency)
	for name in buttons:
		if _free_mode:
			buttons[name].text = name + "  (FREE)"
			buttons[name].disabled = false
		else:
			buttons[name].text = name + "  (" + str(ENCHANT_PRICE) + " gold)"
			buttons[name].disabled = GameManager.currency < ENCHANT_PRICE

func _on_enchant_pressed(enchant_name: String) -> void:
	if _purchase_in_progress:
		return
	if _free_mode or GameManager.currency >= ENCHANT_PRICE:
		_purchase_in_progress = true
		if not _free_mode:
			GameManager.currency -= ENCHANT_PRICE
		GameManager.equip_enchant(enchant_name)
		close()

func close() -> void:
	visible = false
	get_tree().paused = false   # NEW -- resume the game once a choice is made
	closed.emit()
