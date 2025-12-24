class_name TrackAnalyzer
extends RefCounted
## Analyzes tilemap to find road tiles and track boundaries

var tile_map: TileMapLayer

# All road tiles (unordered)
var road_tiles: Array[Vector2i] = []
var road_tile_set: Dictionary = {}  # For fast lookup

# Boundary lines (ordered around the track)
var outer_boundary: Array[Vector2i] = []
var inner_boundary: Array[Vector2i] = []

# Track info
var start_line_tile: Vector2i
var track_bounds: Rect2i
var track_center_tile: Vector2i
var track_center_world: Vector2

## Analyze the tilemap and extract track structure
func analyze(tilemap: TileMapLayer, start_position: Vector2 = Vector2(295, 325)) -> void:
	tile_map = tilemap
	start_line_tile = tile_map.local_to_map(start_position)

	_scan_road_tiles()
	_build_tile_set()
	_calculate_bounds()
	_calculate_track_center()

	# Use radial sampling to find boundaries
	_find_boundaries_radial()

## Scan tilemap for all road tiles
func _scan_road_tiles() -> void:
	road_tiles.clear()
	var used_cells = tile_map.get_used_cells()

	for cell in used_cells:
		var tile_data = tile_map.get_cell_tile_data(cell)
		if tile_data and tile_data.has_custom_data("surface"):
			var surface = tile_data.get_custom_data("surface")
			if surface == "road":
				road_tiles.append(cell)

## Build a dictionary for O(1) tile lookup
func _build_tile_set() -> void:
	road_tile_set.clear()
	for tile in road_tiles:
		road_tile_set[tile] = true

## Calculate bounding box of the track
func _calculate_bounds() -> void:
	if road_tiles.is_empty():
		track_bounds = Rect2i()
		return

	var min_x = road_tiles[0].x
	var max_x = road_tiles[0].x
	var min_y = road_tiles[0].y
	var max_y = road_tiles[0].y

	for tile in road_tiles:
		min_x = mini(min_x, tile.x)
		max_x = maxi(max_x, tile.x)
		min_y = mini(min_y, tile.y)
		max_y = maxi(max_y, tile.y)

	track_bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

## Calculate the center of the track
func _calculate_track_center() -> void:
	if road_tiles.is_empty():
		track_center_tile = Vector2i.ZERO
		track_center_world = Vector2.ZERO
		return

	# Use bounding box center instead of centroid (more reliable for ring tracks)
	track_center_tile = Vector2i(
		track_bounds.position.x + track_bounds.size.x / 2,
		track_bounds.position.y + track_bounds.size.y / 2
	)
	track_center_world = tile_map.map_to_local(track_center_tile)

## Find boundaries using radial sampling from track center
func _find_boundaries_radial() -> void:
	outer_boundary.clear()
	inner_boundary.clear()

	if road_tiles.is_empty():
		return

	# Sample at regular angle intervals around the track
	var num_samples = 64  # Number of rays to cast
	var max_radius = max(track_bounds.size.x, track_bounds.size.y) + 10

	for i in num_samples:
		var angle = (float(i) / num_samples) * TAU
		var direction = Vector2(cos(angle), sin(angle))

		# Cast ray outward from center, find first and last road tile
		var first_road: Vector2i = Vector2i(-9999, -9999)
		var last_road: Vector2i = Vector2i(-9999, -9999)

		for dist in range(1, max_radius):
			var check_pos = Vector2(track_center_tile) + direction * dist
			var check_tile = Vector2i(roundi(check_pos.x), roundi(check_pos.y))

			if check_tile in road_tile_set:
				if first_road.x == -9999:
					first_road = check_tile
				last_road = check_tile

		# First road tile hit = inner boundary, last = outer boundary
		if first_road.x != -9999:
			inner_boundary.append(first_road)
		if last_road.x != -9999:
			outer_boundary.append(last_road)

## Convert tile coordinates to world positions
func tiles_to_world(tiles: Array[Vector2i]) -> PackedVector2Array:
	var points = PackedVector2Array()
	for tile in tiles:
		points.append(tile_map.map_to_local(tile))
	return points

## Get road tiles
func get_road_tiles() -> Array[Vector2i]:
	return road_tiles

## Get outer boundary
func get_outer_boundary() -> Array[Vector2i]:
	return outer_boundary

## Get inner boundary
func get_inner_boundary() -> Array[Vector2i]:
	return inner_boundary

## Check if a tile is a road tile
func is_road(tile: Vector2i) -> bool:
	return tile in road_tile_set

## Get track center point
func get_track_center() -> Vector2:
	return track_center_world
