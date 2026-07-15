extends Node
## DungeonGenerator
##
## Procedural room-and-corridor dungeon generator that draws directly onto a
## TileMapLayer (DungeonTiles) instead of the old _draw() + StaticBody2D approach.
## Wall collision comes from the TileSet's Physics Layer 0 (already set up on
## atlas coords (2,0) and (3,0)) — no manual colliders needed anymore.
##
## This node is a CHILD of DungeonTiles, so dungeon_tiles_path defaults to "..".
##
## Exported knobs are grouped so this can later be driven by player metrics
## (playtime, easter eggs found, etc.) without restructuring the algorithm —
## just call generate() again with different values, or add a function that
## computes these from a stats dictionary before calling generate().

# --- TileSet mapping (confirmed from the editor) ---
const SOURCE_ID: int = 1
const FLOOR_TILES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
const WALL_TILES: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0)]

# --- Cell states for the internal grid ---
enum Cell { EMPTY, FLOOR, WALL }

# --- Generation parameters (tune by hand now, drive from metrics later) ---
@export_group("Grid")
@export var grid_width: int = 50
@export var grid_height: int = 50

@export_group("Rooms")
@export var room_count_min: int = 6
@export var room_count_max: int = 9
@export var room_min_size: int = 4
@export var room_max_size: int = 8

@export_group("Future adaptive hooks (unused for now)")
@export var difficulty_bias: float = 0.0      # e.g. more rooms / bigger rooms as this rises
@export var secret_room_chance: float = 0.0    # e.g. spawn optional bonus rooms

@export_group("Node refs")
@export var dungeon_tiles_path: NodePath = ^".."

var _tiles: TileMapLayer
var _grid: Array = []          # 2D array [x][y] -> Cell
var _rooms: Array[Rect2i] = [] # generated room rectangles, in grid coordinates
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_tiles = get_node(dungeon_tiles_path)
	_ensure_wall_collision(Vector2i(2, 0))
	_ensure_wall_collision(Vector2i(3, 0))


## Guarantees the given wall tile has a full-square collision polygon,
## regardless of whether one was successfully saved via the TileSet editor.
## Safe to call every run: skips tiles that already have a polygon.
func _ensure_wall_collision(atlas_coords: Vector2i) -> void:
	var source := _tiles.tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	var tile_data: TileData = source.get_tile_data(atlas_coords, 0)

	if tile_data.get_collision_polygons_count(0) > 0:
		return  # already has collision, nothing to do

	var tile_size: Vector2 = Vector2(_tiles.tile_set.tile_size)
	var half: Vector2 = tile_size / 2.0
	var points := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])

	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, points)
	print("Added collision polygon to wall tile ", atlas_coords)

## Runs the full generation pipeline. Call this from Main.gd on _ready(),
## same as before: dungeon.generate()
func generate(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	_init_grid()
	_place_rooms()
	_connect_rooms()
	_build_walls_around_floors()
	_draw_tiles()


func _init_grid() -> void:
	_rooms.clear()
	_grid.clear()
	_grid.resize(grid_width)
	for x in grid_width:
		var column: Array = []
		column.resize(grid_height)
		column.fill(Cell.EMPTY)
		_grid[x] = column


func _place_rooms() -> void:
	var target_count: int = _rng.randi_range(room_count_min, room_count_max)
	var attempts: int = 0
	var max_attempts: int = target_count * 20

	while _rooms.size() < target_count and attempts < max_attempts:
		attempts += 1

		var w: int = _rng.randi_range(room_min_size, room_max_size)
		var h: int = _rng.randi_range(room_min_size, room_max_size)
		# Keep a 1-tile margin so rooms never touch the grid edge.
		var x: int = _rng.randi_range(1, grid_width - w - 1)
		var y: int = _rng.randi_range(1, grid_height - h - 1)

		var candidate := Rect2i(x, y, w, h)
		if _overlaps_any_room(candidate):
			continue

		_rooms.append(candidate)
		_carve_room(candidate)


func _overlaps_any_room(candidate: Rect2i) -> bool:
	# Grow the candidate by 1 tile so rooms never end up directly adjacent
	# with no wall between them.
	var padded := candidate.grow(1)
	for room in _rooms:
		if padded.intersects(room):
			return true
	return false


func _carve_room(room: Rect2i) -> void:
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			_grid[x][y] = Cell.FLOOR


func _connect_rooms() -> void:
	# Connect each room to the next in sequence with an L-shaped corridor.
	# Simple and guarantees full connectivity since it's a single chain.
	for i in range(_rooms.size() - 1):
		var a: Vector2i = _rooms[i].get_center()
		var b: Vector2i = _rooms[i + 1].get_center()
		_carve_l_corridor(a, b)


func _carve_l_corridor(from: Vector2i, to: Vector2i) -> void:
	# Randomly choose horizontal-then-vertical or vertical-then-horizontal
	# so corridors don't all look the same shape.
	if _rng.randi_range(0, 1) == 0:
		_carve_horizontal(from.x, to.x, from.y)
		_carve_vertical(from.y, to.y, to.x)
	else:
		_carve_vertical(from.y, to.y, from.x)
		_carve_horizontal(from.x, to.x, to.y)


func _carve_horizontal(x1: int, x2: int, y: int) -> void:
	var start: int = min(x1, x2)
	var end: int = max(x1, x2)
	for x in range(start, end + 1):
		_grid[x][y] = Cell.FLOOR


func _carve_vertical(y1: int, y2: int, x: int) -> void:
	var start: int = min(y1, y2)
	var end: int = max(y1, y2)
	for y in range(start, end + 1):
		_grid[x][y] = Cell.FLOOR


func _build_walls_around_floors() -> void:
	# Any EMPTY cell that's orthogonally or diagonally adjacent to a FLOOR
	# cell becomes a WALL. This gives every corridor/room a solid border.
	var to_wall: Array[Vector2i] = []

	for x in grid_width:
		for y in grid_height:
			if _grid[x][y] != Cell.EMPTY:
				continue
			if _has_floor_neighbor(x, y):
				to_wall.append(Vector2i(x, y))

	for pos in to_wall:
		_grid[pos.x][pos.y] = Cell.WALL


func _has_floor_neighbor(x: int, y: int) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue
			if _grid[nx][ny] == Cell.FLOOR:
				return true
	return false


func _draw_tiles() -> void:
	_tiles.clear()
	for x in grid_width:
		for y in grid_height:
			var cell: Cell = _grid[x][y]
			if cell == Cell.FLOOR:
				var atlas: Vector2i = FLOOR_TILES[_rng.randi_range(0, FLOOR_TILES.size() - 1)]
				_tiles.set_cell(Vector2i(x, y), SOURCE_ID, atlas)
			elif cell == Cell.WALL:
				var atlas: Vector2i = WALL_TILES[_rng.randi_range(0, WALL_TILES.size() - 1)]
				_tiles.set_cell(Vector2i(x, y), SOURCE_ID, atlas)
			# EMPTY cells are simply left blank (no tile set there).


## Returns a random world-space position inside a random room's floor area.
## Used by Main.gd to place Player/Boss after generate() runs.
func get_random_floor_position() -> Vector2:
	if _rooms.is_empty():
		push_warning("DungeonGenerator: get_random_floor_position() called before generate() or no rooms exist.")
		return Vector2.ZERO

	var room: Rect2i = _rooms[_rng.randi_range(0, _rooms.size() - 1)]
	var cell_x: int = _rng.randi_range(room.position.x, room.position.x + room.size.x - 1)
	var cell_y: int = _rng.randi_range(room.position.y, room.position.y + room.size.y - 1)

	# Convert grid cell -> world position using the TileMapLayer's tile size,
	# centered in the cell.
	var tile_size: Vector2 = Vector2(_tiles.tile_set.tile_size)
	return _tiles.to_global(Vector2(cell_x, cell_y) * tile_size + tile_size / 2.0)


## Returns the list of generated rooms, in case Main.gd or other systems
## (e.g. loot placement, enemy spawning) need to pick specific rooms later.
func get_rooms() -> Array[Rect2i]:
	return _rooms
