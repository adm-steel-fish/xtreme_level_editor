extends Area3D
class_name XtremeInteractiveTile

## Generic fallback for exported interactive tiles.
## Tile-specific scenes should implement their own logic when available.

@export var tile_id: StringName = &""
@export var tile_type: int = 0
@export var damage_amount: int = 1
@export var collectible_value: int = 1
@export var custom_properties: Dictionary = {}
@export var destroy_on_collect: bool = true

var _consumed: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)


func apply_xtreme_tile_properties(props: Dictionary) -> void:
	custom_properties = props.duplicate(true)
	if custom_properties.has("damage_amount"):
		damage_amount = int(custom_properties["damage_amount"])
	if custom_properties.has("value"):
		collectible_value = int(custom_properties["value"])
	if custom_properties.has("collectible_value"):
		collectible_value = int(custom_properties["collectible_value"])


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if not (body is PlayerController):
		return

	var player := body as PlayerController
	match tile_type:
		XtremeTileDefinition.TileType.HAZARD:
			_apply_hazard(player)
		XtremeTileDefinition.TileType.COLLECTIBLE:
			_collect(player)
		XtremeTileDefinition.TileType.GOAL:
			_trigger_goal()
		XtremeTileDefinition.TileType.BOOST:
			_apply_boost(player)
		XtremeTileDefinition.TileType.SPRING:
			_apply_spring(player)
		XtremeTileDefinition.TileType.CHECKPOINT:
			_activate_checkpoint()
		XtremeTileDefinition.TileType.TRANSPORT:
			_trigger_transport()
		_:
			pass


func _apply_hazard(player: PlayerController) -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(self, max(1, damage_amount))


func _collect(_player: PlayerController) -> void:
	_consumed = true
	_add_rings(collectible_value)
	if destroy_on_collect:
		queue_free()


func _trigger_goal() -> void:
	var gm := _find_game_manager()
	if gm and gm.has_method("complete_level"):
		var is_secret := bool(custom_properties.get("is_secret_exit", false))
		gm.complete_level(is_secret)


func _apply_boost(player: PlayerController) -> void:
	var boost_strength := float(custom_properties.get("boost_strength", 20.0))
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var current_vertical := player.velocity.y
	player.velocity = forward * boost_strength
	player.velocity.y = current_vertical


func _apply_spring(player: PlayerController) -> void:
	var spring_velocity := float(custom_properties.get("spring_velocity", 22.0))
	player.velocity.y = spring_velocity


func _activate_checkpoint() -> void:
	# Reserved for save/checkpoint integration.
	pass


func _trigger_transport() -> void:
	# Reserved for chunk-set connection logic.
	pass


func _add_rings(amount: int) -> void:
	var gm := _find_game_manager()
	if gm and gm.has_method("add_rings"):
		gm.add_rings(max(1, amount))


func _find_game_manager() -> Node:
	var tree := get_tree()
	if not tree:
		return null

	var root := tree.get_root()
	if not root:
		return null

	for child in root.get_children():
		if child is XtremeGameManager:
			return child
	return null
