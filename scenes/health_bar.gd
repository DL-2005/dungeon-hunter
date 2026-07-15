extends Node2D

@export var bar_width: float = 60.0
@export var bar_height: float = 8.0
@export var offset_above_parent: float = 50.0
var health_ratio: float = 1.0

func _ready() -> void:
	position = Vector2(-bar_width / 2.0, -offset_above_parent)

func update_health(current: float, max_value: float) -> void:
	health_ratio = clamp(current / max_value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2))
	var fill_color := Color(1.0 - health_ratio, health_ratio, 0.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_width * health_ratio, bar_height)), fill_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_width, bar_height)), Color(0, 0, 0), false, 1.5)
