extends Control
## Minimap
##
## Explored-rooms + corridor-trail minimap, not a rendered camera view.
## Rooms are revealed whole the moment the player enters them; corridor
## tiles are revealed one at a time as the player actually walks over them,
## leaving a thin connecting trail between rooms on the map.

@export var dungeon: Node
@export var player: Node2D

const CELL_SCALE: float = 4.0
const MARGIN: float = 8.0
const VISITED_COLOR := Color(0.85, 0.75, 0.25, 0.9)
const CURRENT_ROOM_COLOR := Color(0.95, 0.95, 0.95, 1.0)
const CORRIDOR_COLOR := Color(0.6, 0.55, 0.2, 0.85)
const PLAYER_DOT_COLOR := Color(1.0, 0.15, 0.15, 1.0)
const PLAYER_DOT_RADIUS: float = 3.0

var _visited: Dictionary = {}          # room index -> true
var _visited_cells: Dictionary = {}    # Vector2i (corridor cell) -> true
var _current_room: int = -1
var _rooms: Array[Rect2i] = []
var _bounds: Rect2i

func reset_for_new_dungeon() -> void:
	_rooms = dungeon.get_rooms()
	print("Minimap: reset_for_new_dungeon called, room count = ", _rooms.size())
	_visited.clear()
	_visited_cells.clear()
	_current_room = -1
	if _rooms.is_empty():
		_bounds = Rect2i()
	else:
		_bounds = _rooms[0]
		for i in range(1, _rooms.size()):
			_bounds = _bounds.merge(_rooms[i])
	queue_redraw()

func _process(_delta: float) -> void:
	if _rooms.is_empty() or player == null:
		return
	var idx: int = dungeon.get_room_index_at_world_pos(player.global_position)
	var changed := false
	if idx != _current_room:
		_current_room = idx
		if idx != -1:
			_visited[idx] = true
		changed = true
	if idx == -1:
		var cell: Vector2i = dungeon.get_cell_at_world_pos(player.global_position)
		if dungeon.is_floor_cell(cell) and not _visited_cells.has(cell):
			_visited_cells[cell] = true
			changed = true
	if changed:
		queue_redraw()

func _draw() -> void:
	if _rooms.is_empty():
		return
	for cell in _visited_cells.keys():
		var rel := Vector2(cell - _bounds.position) * CELL_SCALE
		var rect := Rect2(Vector2(MARGIN, MARGIN) + rel, Vector2(CELL_SCALE, CELL_SCALE))
		draw_rect(rect, CORRIDOR_COLOR, true)

	for i in _rooms.size():
		if i != _current_room and not _visited.has(i):
			continue
		var room: Rect2i = _rooms[i]
		var rel := Vector2(room.position - _bounds.position) * CELL_SCALE
		var size := Vector2(room.size) * CELL_SCALE
		var rect := Rect2(Vector2(MARGIN, MARGIN) + rel, size)
		var color: Color = CURRENT_ROOM_COLOR if i == _current_room else VISITED_COLOR
		draw_rect(rect, color, true)

	if _current_room != -1:
		var room: Rect2i = _rooms[_current_room]
		var center := Vector2(room.position - _bounds.position) * CELL_SCALE + Vector2(room.size) * CELL_SCALE / 2.0
		draw_circle(Vector2(MARGIN, MARGIN) + center, PLAYER_DOT_RADIUS, PLAYER_DOT_COLOR)
	elif player != null:
		var cell: Vector2i = dungeon.get_cell_at_world_pos(player.global_position)
		var rel := Vector2(cell - _bounds.position) * CELL_SCALE + Vector2(CELL_SCALE, CELL_SCALE) / 2.0
		draw_circle(Vector2(MARGIN, MARGIN) + rel, PLAYER_DOT_RADIUS, PLAYER_DOT_COLOR)
