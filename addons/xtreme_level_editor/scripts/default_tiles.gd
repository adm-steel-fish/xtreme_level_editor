@tool
extends Node

## Sample Tile Definitions
## Run this script to generate a default tile palette with common tile types

static func create_default_palette() -> XtremeTilePalette:
	var palette := XtremeTilePalette.new()
	palette.palette_name = "Default Palette"
	
	# ============ Geometry ============
	
	var solid := XtremeTileDefinition.new()
	solid.tile_id = &"solid"
	solid.display_name = "Solid Block"
	solid.category = "Geometry"
	solid.editor_color = Color(0.6, 0.6, 0.6)
	solid.tile_type = XtremeTileDefinition.TileType.SOLID
	solid.is_solid = true
	solid.is_standable = true
	solid.generation_weight = 5.0
	palette.tiles.append(solid)
	
	var large_block := XtremeTileDefinition.new()
	large_block.tile_id = &"large_block"
	large_block.display_name = "Large Block (2x1x1)"
	large_block.category = "Geometry"
	large_block.editor_color = Color(0.3, 0.5, 0.8)
	large_block.tile_type = XtremeTileDefinition.TileType.SOLID
	large_block.is_solid = true
	large_block.is_standable = true
	large_block.cell_size = Vector3i(2, 1, 1)  # 2 units wide
	large_block.generation_weight = 2.0
	palette.tiles.append(large_block)
	
	var tall_block := XtremeTileDefinition.new()
	tall_block.tile_id = &"tall_block"
	tall_block.display_name = "Tall Block (1x2x1)"
	tall_block.category = "Geometry"
	tall_block.editor_color = Color(0.8, 0.5, 0.3)
	tall_block.tile_type = XtremeTileDefinition.TileType.SOLID
	tall_block.is_solid = true
	tall_block.is_standable = true
	tall_block.cell_size = Vector3i(1, 2, 1)  # 2 units tall
	tall_block.generation_weight = 2.0
	palette.tiles.append(tall_block)
	
	var platform := XtremeTileDefinition.new()
	platform.tile_id = &"platform"
	platform.display_name = "Platform"
	platform.category = "Geometry"
	platform.editor_color = Color(0.4, 0.6, 0.4)
	platform.tile_type = XtremeTileDefinition.TileType.PLATFORM
	platform.is_solid = false
	platform.is_standable = true
	platform.generation_weight = 3.0
	palette.tiles.append(platform)
	
	var ramp := XtremeTileDefinition.new()
	ramp.tile_id = &"ramp"
	ramp.display_name = "Ramp"
	ramp.category = "Geometry"
	ramp.editor_color = Color(0.5, 0.5, 0.3)
	ramp.tile_type = XtremeTileDefinition.TileType.SOLID
	ramp.is_solid = true
	ramp.is_standable = true
	ramp.generation_weight = 2.0
	palette.tiles.append(ramp)
	
	# ============ Hazards ============
	
	var spike := XtremeTileDefinition.new()
	spike.tile_id = &"spike"
	spike.display_name = "Spikes"
	spike.category = "Hazards"
	spike.editor_color = Color(1.0, 0.2, 0.2)
	spike.tile_type = XtremeTileDefinition.TileType.HAZARD
	spike.is_solid = true
	spike.is_standable = false
	spike.is_hazardous = true
	spike.damage_amount = 1
	spike.generation_weight = 1.0
	spike.max_consecutive = 3
	palette.tiles.append(spike)
	
	var lava := XtremeTileDefinition.new()
	lava.tile_id = &"lava"
	lava.display_name = "Lava"
	lava.category = "Hazards"
	lava.editor_color = Color(1.0, 0.5, 0.0)
	lava.tile_type = XtremeTileDefinition.TileType.HAZARD
	lava.is_solid = false
	lava.is_standable = false
	lava.is_hazardous = true
	lava.damage_amount = 999
	lava.generation_weight = 0.5
	palette.tiles.append(lava)
	
	# ============ Interactive ============
	
	var spring := XtremeTileDefinition.new()
	spring.tile_id = &"spring"
	spring.display_name = "Spring"
	spring.category = "Interactive"
	spring.editor_color = Color(1.0, 1.0, 0.2)
	spring.tile_type = XtremeTileDefinition.TileType.SPRING
	spring.is_solid = true
	spring.is_standable = true
	spring.generation_weight = 1.5
	palette.tiles.append(spring)
	
	var boost := XtremeTileDefinition.new()
	boost.tile_id = &"boost"
	boost.display_name = "Boost Pad"
	boost.category = "Interactive"
	boost.editor_color = Color(0.2, 0.8, 1.0)
	boost.tile_type = XtremeTileDefinition.TileType.BOOST
	boost.is_solid = true
	boost.is_standable = true
	boost.generation_weight = 1.0
	palette.tiles.append(boost)
	
	var rail := XtremeTileDefinition.new()
	rail.tile_id = &"rail"
	rail.display_name = "Grind Rail"
	rail.category = "Interactive"
	rail.editor_color = Color(0.8, 0.8, 0.2)
	rail.tile_type = XtremeTileDefinition.TileType.RAIL
	rail.is_solid = false
	rail.is_standable = false
	rail.generation_weight = 1.0
	palette.tiles.append(rail)
	
	# ============ Entities ============
	
	var ring := XtremeTileDefinition.new()
	ring.tile_id = &"ring"
	ring.display_name = "Ring"
	ring.category = "Collectibles"
	ring.editor_color = Color(1.0, 0.85, 0.0)
	ring.tile_type = XtremeTileDefinition.TileType.COLLECTIBLE
	ring.is_solid = false
	ring.is_standable = false
	ring.generation_weight = 4.0
	palette.tiles.append(ring)
	
	var enemy_basic := XtremeTileDefinition.new()
	enemy_basic.tile_id = &"enemy_basic"
	enemy_basic.display_name = "Basic Enemy"
	enemy_basic.category = "Enemies"
	enemy_basic.editor_color = Color(0.8, 0.2, 0.8)
	enemy_basic.tile_type = XtremeTileDefinition.TileType.ENEMY
	enemy_basic.is_solid = false
	enemy_basic.is_standable = false
	enemy_basic.generation_weight = 1.0
	enemy_basic.max_consecutive = 2
	palette.tiles.append(enemy_basic)
	
	var checkpoint := XtremeTileDefinition.new()
	checkpoint.tile_id = &"checkpoint"
	checkpoint.display_name = "Checkpoint"
	checkpoint.category = "Progress"
	checkpoint.editor_color = Color(0.2, 1.0, 0.5)
	checkpoint.tile_type = XtremeTileDefinition.TileType.CHECKPOINT
	checkpoint.is_solid = false
	checkpoint.is_standable = false
	checkpoint.generation_weight = 0.0  # Don't generate randomly
	palette.tiles.append(checkpoint)
	
	var goal := XtremeTileDefinition.new()
	goal.tile_id = &"goal"
	goal.display_name = "Goal"
	goal.category = "Progress"
	goal.editor_color = Color(0.2, 0.5, 1.0)
	goal.tile_type = XtremeTileDefinition.TileType.GOAL
	goal.is_solid = false
	goal.is_standable = false
	goal.generation_weight = 0.0  # Don't generate randomly
	palette.tiles.append(goal)
	
	# ============ Decoration ============
	
	var deco_plant := XtremeTileDefinition.new()
	deco_plant.tile_id = &"deco_plant"
	deco_plant.display_name = "Plant"
	deco_plant.category = "Decoration"
	deco_plant.editor_color = Color(0.2, 0.7, 0.2)
	deco_plant.tile_type = XtremeTileDefinition.TileType.DECORATION
	deco_plant.is_solid = false
	deco_plant.is_standable = false
	deco_plant.generation_weight = 2.0
	palette.tiles.append(deco_plant)
	
	# ============ Water ============
	
	var water := XtremeTileDefinition.new()
	water.tile_id = &"water"
	water.display_name = "Water"
	water.category = "Water"
	water.editor_color = Color(0.2, 0.4, 0.9, 0.6)
	water.tile_type = XtremeTileDefinition.TileType.WATER
	water.is_solid = false
	water.is_standable = false
	water.generation_weight = 0.0
	palette.tiles.append(water)
	
	var water_surface := XtremeTileDefinition.new()
	water_surface.tile_id = &"water_surface"
	water_surface.display_name = "Water Surface"
	water_surface.category = "Water"
	water_surface.editor_color = Color(0.3, 0.5, 1.0, 0.7)
	water_surface.tile_type = XtremeTileDefinition.TileType.WATER
	water_surface.is_solid = false
	water_surface.is_standable = false
	water_surface.custom_properties["is_surface"] = true
	water_surface.generation_weight = 0.0
	palette.tiles.append(water_surface)
	
	var water_hazard := XtremeTileDefinition.new()
	water_hazard.tile_id = &"water_hazard"
	water_hazard.display_name = "Hazard Water"
	water_hazard.category = "Water"
	water_hazard.editor_color = Color(0.5, 0.8, 0.2, 0.6)
	water_hazard.tile_type = XtremeTileDefinition.TileType.WATER
	water_hazard.is_solid = false
	water_hazard.is_standable = false
	water_hazard.is_hazardous = true
	water_hazard.damage_amount = 5
	water_hazard.custom_properties["water_type"] = "hazardous"
	water_hazard.generation_weight = 0.0
	palette.tiles.append(water_hazard)
	
	# ============ Transport (Pipes/Portals) ============
	
	var pipe := XtremeTileDefinition.new()
	pipe.tile_id = &"pipe"
	pipe.display_name = "Pipe"
	pipe.category = "Transport"
	pipe.editor_color = Color(0.0, 0.8, 0.4)
	pipe.tile_type = XtremeTileDefinition.TileType.TRANSPORT
	pipe.is_solid = true
	pipe.is_standable = true
	pipe.custom_properties["transport_type"] = "pipe"
	pipe.custom_properties["requires_input"] = true
	pipe.custom_properties["input_direction"] = 2  # Down
	pipe.generation_weight = 0.0
	palette.tiles.append(pipe)
	
	var door := XtremeTileDefinition.new()
	door.tile_id = &"door"
	door.display_name = "Door"
	door.category = "Transport"
	door.editor_color = Color(0.6, 0.4, 0.2)
	door.tile_type = XtremeTileDefinition.TileType.TRANSPORT
	door.is_solid = false
	door.is_standable = false
	door.cell_size = Vector3i(1, 2, 1)  # Doors are usually 2 cells tall
	door.custom_properties["transport_type"] = "door"
	door.custom_properties["requires_input"] = true
	door.custom_properties["input_direction"] = 1  # Up
	door.generation_weight = 0.0
	palette.tiles.append(door)
	
	var warp_zone := XtremeTileDefinition.new()
	warp_zone.tile_id = &"warp_zone"
	warp_zone.display_name = "Warp Zone"
	warp_zone.category = "Transport"
	warp_zone.editor_color = Color(0.8, 0.2, 1.0)
	warp_zone.tile_type = XtremeTileDefinition.TileType.TRANSPORT
	warp_zone.is_solid = false
	warp_zone.is_standable = false
	warp_zone.custom_properties["transport_type"] = "warp"
	warp_zone.custom_properties["requires_input"] = false  # Auto-teleport on contact
	warp_zone.generation_weight = 0.0
	palette.tiles.append(warp_zone)
	
	var hole := XtremeTileDefinition.new()
	hole.tile_id = &"hole"
	hole.display_name = "Hole"
	hole.category = "Transport"
	hole.editor_color = Color(0.1, 0.1, 0.1)
	hole.tile_type = XtremeTileDefinition.TileType.TRANSPORT
	hole.is_solid = false
	hole.is_standable = false
	hole.custom_properties["transport_type"] = "hole"
	hole.custom_properties["requires_input"] = false  # Fall through
	hole.generation_weight = 0.0
	palette.tiles.append(hole)
	
	# ============ Goals ============
	
	var goal_standard := XtremeTileDefinition.new()
	goal_standard.tile_id = &"goal_portal"
	goal_standard.display_name = "Goal Portal"
	goal_standard.category = "Goals"
	goal_standard.editor_color = Color(1.0, 0.85, 0.0)
	goal_standard.tile_type = XtremeTileDefinition.TileType.GOAL
	goal_standard.is_solid = false
	goal_standard.is_standable = false
	goal_standard.custom_properties["goal_type"] = "standard"
	goal_standard.custom_properties["returns_to"] = "world_map"
	goal_standard.generation_weight = 0.0
	palette.tiles.append(goal_standard)
	
	var goal_secret := XtremeTileDefinition.new()
	goal_secret.tile_id = &"goal_secret"
	goal_secret.display_name = "Secret Exit"
	goal_secret.category = "Goals"
	goal_secret.editor_color = Color(0.7, 0.2, 1.0)
	goal_secret.tile_type = XtremeTileDefinition.TileType.GOAL
	goal_secret.is_solid = false
	goal_secret.is_standable = false
	goal_secret.custom_properties["goal_type"] = "secret"
	goal_secret.custom_properties["returns_to"] = "world_map"
	goal_secret.custom_properties["is_secret_exit"] = true
	goal_secret.generation_weight = 0.0
	palette.tiles.append(goal_secret)
	
	# ============ Spawn Points ============
	
	var spawn_point := XtremeTileDefinition.new()
	spawn_point.tile_id = &"spawn_point"
	spawn_point.display_name = "Spawn Point"
	spawn_point.category = "Progress"
	spawn_point.editor_color = Color(0.2, 1.0, 0.2)
	spawn_point.tile_type = XtremeTileDefinition.TileType.SPAWN
	spawn_point.is_solid = false
	spawn_point.is_standable = false
	spawn_point.custom_properties["spawn_type"] = "player"
	spawn_point.custom_properties["is_default"] = false
	spawn_point.generation_weight = 0.0
	palette.tiles.append(spawn_point)
	
	return palette

static func save_default_palette(path: String = "res://default_tile_palette.tres") -> Error:
	var palette := create_default_palette()
	return ResourceSaver.save(palette, path)
