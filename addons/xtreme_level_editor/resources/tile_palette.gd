@tool
class_name XtremeTilePalette
extends Resource

## A collection of tile definitions available for level editing.
## Organize your tiles into palettes by theme, level, or project.

## All tile definitions in this palette
@export var tiles: Array[XtremeTileDefinition] = []

## Palette name for display
@export var palette_name: String = "Default Palette"

## Get a tile by its ID
func get_tile(tile_id: StringName) -> XtremeTileDefinition:
	for tile in tiles:
		if tile.tile_id == tile_id:
			return tile
	return null

## Get all tiles in a category
func get_tiles_by_category(category: String) -> Array[XtremeTileDefinition]:
	var result: Array[XtremeTileDefinition] = []
	for tile in tiles:
		if tile.category == category:
			result.append(tile)
	return result

## Get all tiles matching a theme
func get_tiles_by_theme(theme: String) -> Array[XtremeTileDefinition]:
	var result: Array[XtremeTileDefinition] = []
	for tile in tiles:
		if tile.matches_theme(theme):
			result.append(tile)
	return result

## Get all unique categories in this palette
func get_categories() -> PackedStringArray:
	var categories: PackedStringArray = []
	for tile in tiles:
		if tile.category not in categories:
			categories.append(tile.category)
	return categories

## Get tiles suitable for procedural generation with given constraints
func get_generation_candidates(theme: String = "", exclude_types: Array[XtremeTileDefinition.TileType] = []) -> Array[XtremeTileDefinition]:
	var result: Array[XtremeTileDefinition] = []
	for tile in tiles:
		if tile.generation_weight <= 0:
			continue
		if not theme.is_empty() and not tile.matches_theme(theme):
			continue
		if tile.tile_type in exclude_types:
			continue
		result.append(tile)
	return result

## Add a tile to the palette (prevents duplicates by ID)
func add_tile(tile: XtremeTileDefinition) -> bool:
	if get_tile(tile.tile_id) != null:
		push_warning("Tile with ID '%s' already exists in palette" % tile.tile_id)
		return false
	tiles.append(tile)
	emit_changed()
	return true

## Remove a tile from the palette
func remove_tile(tile_id: StringName) -> bool:
	for i in range(tiles.size()):
		if tiles[i].tile_id == tile_id:
			tiles.remove_at(i)
			emit_changed()
			return true
	return false
