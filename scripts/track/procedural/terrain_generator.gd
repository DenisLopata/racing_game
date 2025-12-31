class_name TerrainGenerator
extends RefCounted
## Generates themed terrain zones and paints tilemap with surfaces

## Zone types
enum ZoneType { FOREST, DESERT, ROCKY, PLAINS, SWAMP }

## Zone to surface mapping
const ZONE_SURFACES = {
	ZoneType.FOREST: {
		"primary": "grass",
		"secondary": "deep_grass",
		"accent": "dirt",
		"weights": [0.6, 0.3, 0.1]
	},
	ZoneType.DESERT: {
		"primary": "sand",
		"secondary": "dirt",
		"accent": "grass",
		"weights": [0.7, 0.25, 0.05]
	},
	ZoneType.ROCKY: {
		"primary": "dirt",
		"secondary": "grass",
		"accent": "sand",
		"weights": [0.6, 0.3, 0.1]
	},
	ZoneType.PLAINS: {
		"primary": "grass",
		"secondary": "dirt",
		"accent": "deep_grass",
		"weights": [0.7, 0.2, 0.1]
	},
	ZoneType.SWAMP: {
		"primary": "deep_grass",
		"secondary": "grass",
		"accent": "dirt",
		"weights": [0.5, 0.35, 0.15]
	}
}

## Tile atlas coordinates from track_tileset.tres
const SURFACE_TILE_COORDS = {
	"road": Vector2i(2, 2),
	"grass": Vector2i(1, 1),
	"deep_grass": Vector2i(0, 1),
	"dirt": Vector2i(1, 2),
	"sand": Vector2i(0, 3)
}

## Zone data
var zones: Array[Dictionary] = []
var zone_map: Array = []  # 2D array [x][y] -> ZoneType

## RNG reference
var rng: RandomNumberGenerator

## Map dimensions
var map_width: int = 80
var map_height: int = 80

## Tile size
var tile_size: int = 16

## Noise for terrain variation
var noise: FastNoiseLite

## Initialize terrain generator
func setup(random: RandomNumberGenerator, width: int, height: int) -> void:
	rng = random
	map_width = width
	map_height = height

	# Setup noise generator
	noise = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05

## Generate terrain zones
func generate_zones(num_zones: int = 5) -> void:
	zones.clear()
	var zone_types = ZoneType.values()

	# Place zone centers randomly, avoiding edges
	var margin = 10
	for i in num_zones:
		var center = Vector2(
			rng.randi_range(margin, map_width - margin),
			rng.randi_range(margin, map_height - margin)
		)

		# Pick zone type, trying to avoid repeating adjacent zones
		var zone_type = zone_types[rng.randi() % zone_types.size()]

		zones.append({
			"center": center,
			"type": zone_type
		})

	# Build zone map using Voronoi-like nearest neighbor
	_build_zone_map()

## Build 2D zone map
func _build_zone_map() -> void:
	zone_map.clear()
	zone_map.resize(map_width)

	for x in map_width:
		zone_map[x] = []
		zone_map[x].resize(map_height)

		for y in map_height:
			var pos = Vector2(x, y)
			var nearest_zone = _find_nearest_zone(pos)
			zone_map[x][y] = nearest_zone["type"]

## Find nearest zone center
func _find_nearest_zone(pos: Vector2) -> Dictionary:
	var min_dist = INF
	var nearest = zones[0] if zones.size() > 0 else {"type": ZoneType.PLAINS}

	for zone in zones:
		var dist = pos.distance_squared_to(zone["center"])
		if dist < min_dist:
			min_dist = dist
			nearest = zone

	return nearest

## Paint the tilemap with road and terrain
func paint_tilemap(tilemap: TileMapLayer, spline_points: PackedVector2Array,
		track_widths: Array[float]) -> void:
	# First, collect all road tiles
	var road_tiles: Dictionary = {}  # tile_pos -> true

	# Paint road along the spline
	_paint_road_tiles(tilemap, spline_points, track_widths, road_tiles)

	# Then fill remaining tiles with terrain
	_paint_terrain_tiles(tilemap, road_tiles)

## Paint road tiles along the track
func _paint_road_tiles(tilemap: TileMapLayer, spline_points: PackedVector2Array,
		track_widths: Array[float], road_tiles: Dictionary) -> void:

	var num_points = spline_points.size()
	if num_points == 0:
		return

	for i in num_points:
		var point = spline_points[i]
		var width = track_widths[i] if i < track_widths.size() else 5.0

		# Get perpendicular direction for track width
		var next_idx = (i + 1) % num_points
		var direction = (spline_points[next_idx] - point).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)

		# Paint tiles across track width
		var half_width = int(ceil(width / 2.0)) + 1  # Extra padding for safety

		for offset in range(-half_width, half_width + 1):
			var world_pos = point + perpendicular * offset * tile_size
			var tile_pos = tilemap.local_to_map(world_pos)

			# Check bounds
			if tile_pos.x >= 0 and tile_pos.x < map_width and \
			   tile_pos.y >= 0 and tile_pos.y < map_height:
				if tile_pos not in road_tiles:
					road_tiles[tile_pos] = true
					tilemap.set_cell(tile_pos, 0, SURFACE_TILE_COORDS["road"])

	# Fill any gaps in the road with flood fill from center
	_fill_road_gaps(tilemap, spline_points, road_tiles)

## Fill gaps in the road
func _fill_road_gaps(tilemap: TileMapLayer, spline_points: PackedVector2Array,
		road_tiles: Dictionary) -> void:
	# Simple approach: for each road tile, check neighbors and fill if they
	# should be road based on distance to spline
	var new_road_tiles: Array[Vector2i] = []

	for tile_pos in road_tiles.keys():
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor = Vector2i(tile_pos.x + dx, tile_pos.y + dy)
				if neighbor not in road_tiles:
					# Check if this tile is close to the spline
					var world_pos = tilemap.map_to_local(neighbor)
					var min_dist = _distance_to_spline(world_pos, spline_points)
					if min_dist < tile_size * 3:  # Within 3 tiles of spline
						new_road_tiles.append(neighbor)

	# Add new road tiles
	for tile_pos in new_road_tiles:
		if tile_pos.x >= 0 and tile_pos.x < map_width and \
		   tile_pos.y >= 0 and tile_pos.y < map_height:
			road_tiles[tile_pos] = true
			tilemap.set_cell(tile_pos, 0, SURFACE_TILE_COORDS["road"])

## Calculate minimum distance from a point to the spline
func _distance_to_spline(pos: Vector2, spline: PackedVector2Array) -> float:
	var min_dist = INF

	# Sample every 5th point for speed
	for i in range(0, spline.size(), 5):
		var dist = pos.distance_to(spline[i])
		if dist < min_dist:
			min_dist = dist

	return min_dist

## Paint terrain tiles outside the road
func _paint_terrain_tiles(tilemap: TileMapLayer, road_tiles: Dictionary) -> void:
	for x in map_width:
		for y in map_height:
			var tile_pos = Vector2i(x, y)

			# Skip road tiles
			if tile_pos in road_tiles:
				continue

			# Get zone type for this tile
			var zone_type = zone_map[x][y] if x < zone_map.size() and y < zone_map[x].size() else ZoneType.PLAINS

			# Get surface based on zone and noise
			var surface = _get_zone_surface(tile_pos, zone_type)

			# Paint the tile
			tilemap.set_cell(tile_pos, 0, SURFACE_TILE_COORDS[surface])

## Get surface type for a tile based on zone and noise
func _get_zone_surface(tile_pos: Vector2i, zone_type: ZoneType) -> String:
	var zone_data = ZONE_SURFACES[zone_type]
	var surfaces = [zone_data["primary"], zone_data["secondary"], zone_data["accent"]]
	var weights = zone_data["weights"]

	# Use noise to vary terrain within zone
	var noise_val = noise.get_noise_2d(tile_pos.x, tile_pos.y)
	noise_val = (noise_val + 1.0) / 2.0  # Normalize to 0-1

	# Select surface based on noise and weights
	var cumulative = 0.0
	for i in weights.size():
		cumulative += weights[i]
		if noise_val < cumulative:
			return surfaces[i]

	return surfaces[0]  # Default to primary

## Get zone at a specific tile position
func get_zone_at(tile_pos: Vector2i) -> ZoneType:
	if tile_pos.x >= 0 and tile_pos.x < map_width and \
	   tile_pos.y >= 0 and tile_pos.y < map_height:
		return zone_map[tile_pos.x][tile_pos.y]
	return ZoneType.PLAINS

## Get all zone centers for debug visualization
func get_zone_centers() -> Array[Dictionary]:
	return zones
