# Xtreme Level Editor

A 3D cubemap/tilemap level editor for Godot 4.5, inspired by Sonic Xtreme's level design system. This editor enables rapid creation of large, exploration-friendly levels with multiple pathways.

## Features

### Core Features (Phase 1)
- **3D Grid-Based Level Editing**: Place tiles in a 3D grid with configurable cell sizes
- **Adjustable Cell Dimensions**: Set X, Y, Z cell sizes project-wide
- **Adjustable Level Size**: Configure maximum level dimensions
- **Save/Load System**: Save levels as Godot resources (.tres)
- **Curved World Preview**: Toggle curved world shader preview in the editor
- **Level Export**: Export levels as playable scenes with optional curved world shader

### Tile System
- **Tile Definitions**: Create custom tile types with properties like:
  - Collision settings (solid, platform, passthrough)
  - Hazard properties
  - Visual settings (color, mesh, scene)
  - Generation weights for procedural placement
  - Connection tags for adjacency rules

### Chunk System
- **Reusable Level Chunks**: Save and load prefabricated level sections
- **Connection Points**: Mark where chunks can connect to other chunks or generated content
- **Chunk Transformations**: Rotate and mirror chunks

### Curved World Shader
- **Sonic Xtreme-Style Effect**: Vertex displacement shader that curves the world around the player
- **Multiple Modes**: Spherical, Cylindrical X, Cylindrical Z
- **Adjustable Intensity**: Fine-tune the curvature amount
- **Preview Toggle**: See the effect while editing

## Installation

1. Copy the `addons/xtreme_level_editor` folder to your Godot project's `addons` directory
2. In Godot, go to Project → Project Settings → Plugins
3. Enable "Xtreme Level Editor"

## Quick Start

### Creating Your First Level

1. Open a 3D scene in Godot
2. The "Xtreme Level Editor" dock appears on the right
3. Click "New" to create a new level
4. Configure grid settings (cell size) and level size
5. Use the toolbar to paint tiles

### Configuring Grid Settings

Grid settings are **project-wide** and affect all levels:

```
Cell X: 2.0  (width of each cell in Godot units)
Cell Y: 2.0  (height of each cell)
Cell Z: 2.0  (depth of each cell)
```

These settings are saved automatically and persist across sessions.

### Creating Tile Definitions

1. Create a new resource: Right-click in FileSystem → New Resource → XtremeTileDefinition
2. Configure the tile:
   - `tile_id`: Unique identifier (e.g., "solid_ground")
   - `display_name`: Name shown in editor
   - `category`: For organizing in palette
   - `editor_color`: Color for visualization
   - `tile_type`: SOLID, PLATFORM, HAZARD, ENEMY, etc.
   - `tile_scene`: Optional PackedScene to instantiate

### Creating a Tile Palette

1. Create a new resource: XtremeTilePalette
2. Add your tile definitions to the `tiles` array
3. Load the palette in the editor (future UI feature)

## File Structure

```
addons/xtreme_level_editor/
├── plugin.cfg              # Plugin configuration
├── plugin.gd               # Main editor plugin
├── resources/
│   ├── grid_settings.gd    # Project-wide grid configuration
│   ├── level_data.gd       # Level data storage
│   ├── level_chunk.gd      # Reusable level chunks
│   ├── tile_definition.gd  # Individual tile properties
│   ├── tile_palette.gd     # Collection of tiles
│   └── traversal_profile.gd # Player movement capabilities
├── nodes/
│   └── grid_visualizer.gd  # 3D grid rendering
├── scripts/
│   └── level_exporter.gd   # Export to playable scenes
└── shaders/
    ├── curved_world.gdshader   # Curved world effect
    └── grid_wireframe.gdshader # Editor grid display
```

## Resource Types

### XtremeGridSettings
Project-wide settings for cell dimensions.

```gdscript
var settings = XtremeGridSettings.new()
settings.cell_size_x = 2.0
settings.cell_size_y = 2.0
settings.cell_size_z = 2.0

# Convert between grid and world coordinates
var world_pos = settings.grid_to_world(Vector3i(5, 0, 10))
var grid_pos = settings.world_to_grid(Vector3(10.0, 0.0, 20.0))
```

### XtremeLevelData
Stores the 3D grid of tiles.

```gdscript
var level = XtremeLevelData.new()
level.initialize(grid_settings)
level.level_name = "My Level"
level.resize(64, 32, 64)  # Set dimensions

# Place tiles
level.set_tile(Vector3i(5, 0, 10), &"solid_ground")
var tile_id = level.get_tile(Vector3i(5, 0, 10))

# Get all tile positions
var positions = level.get_all_tile_positions()

# Copy/paste regions
var region = level.copy_region(Vector3i(0, 0, 0), Vector3i(7, 7, 7))
level.paste_region(region, Vector3i(10, 0, 10))
```

### XtremeTileDefinition
Defines a single tile type.

```gdscript
var tile = XtremeTileDefinition.new()
tile.tile_id = &"spike"
tile.display_name = "Spike Hazard"
tile.category = "Hazards"
tile.editor_color = Color.RED
tile.tile_type = XtremeTileDefinition.TileType.HAZARD
tile.is_solid = true
tile.is_hazardous = true
tile.damage_amount = 1
```

### XtremeLevelChunk
Reusable prefabricated sections.

```gdscript
# Create from existing level region
var chunk = XtremeLevelChunk.create_from_region(level, start_pos, end_pos)
chunk.chunk_name = "Platform Section A"

# Add connection points
chunk.add_connection_point(
    Vector3i(7, 0, 3),      # Position on chunk boundary
    Vector3i.RIGHT,          # Direction (facing outward)
    ["ground", "main_path"]  # Tags for matching
)

# Stamp into a level
chunk.stamp_into(level, Vector3i(20, 0, 0))

# Transform
chunk.rotate_y_90()
chunk.mirror_x()
```

### XtremeTraversalProfile
Defines player movement capabilities for procedural generation.

```gdscript
var profile = XtremeTraversalProfile.new()
profile.max_jump_height_cells = 2
profile.max_jump_distance_cells = 3
profile.max_safe_fall_cells = 4
profile.can_double_jump = false
profile.can_wall_jump = false

# Check if traversal between two points is valid
if profile.is_traversable(from_pos, to_pos):
    # Valid connection
    pass
```

## Curved World Shader

The shader creates a Sonic Xtreme-style curved world effect by displacing vertices based on their distance from a center point.

### Shader Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `curve_center` | vec3 | Center point (usually player position) |
| `curve_intensity` | float | How much the world curves (0.0 - 0.1) |
| `curve_mode` | int | 0=Spherical, 1=Cylindrical X, 2=Cylindrical Z |
| `curve_max_distance` | float | Maximum distance for curvature effect |
| `curve_enabled` | bool | Toggle the effect on/off |

### Runtime Usage

At runtime, you need to update the `curve_center` parameter to follow the player:

```gdscript
# In your player or camera script
func _process(delta):
    var player_pos = player.global_position
    
    # Update all curved world materials
    for material in curved_materials:
        material.set_shader_parameter("curve_center", player_pos)
```

## Exporting Levels

### Basic Export

```gdscript
var exporter = XtremeLevelExporter.new()
exporter.grid_settings = grid_settings
exporter.tile_palette = palette
exporter.level_data = level
exporter.apply_curved_world = true
exporter.curve_intensity = 0.01
exporter.curve_mode = 0  # Spherical

var error = exporter.export_level("res://levels/level_1.tscn")
```

### Export Options

| Option | Description |
|--------|-------------|
| `apply_curved_world` | Apply curved world shader to all materials |
| `curve_intensity` | Shader intensity setting |
| `curve_mode` | Shader mode setting |
| `generate_collision` | Create collision shapes for solid tiles |
| `optimize_meshes` | (Future) Merge meshes for performance |
| `create_navigation` | (Future) Generate navigation mesh |

## Future Phases

### Phase 2: Tile Painting UI
- Visual tile palette
- Brush sizes
- Fill tool
- Undo/redo

### Phase 3: Chunk System UI
- Select and save chunks
- Chunk browser
- Place chunks from library

### Phase 4: Game Integration
- Runtime tile instantiation
- Optimized rendering for large levels

### Phase 5: Procedural Connections
- A* pathfinding for critical paths
- Wave Function Collapse for area fill
- Traversal validation
- Theme-aware generation

## Tips and Best Practices

1. **Start with consistent cell sizes**: Choose cell dimensions that match your character's movement capabilities

2. **Use categories**: Organize tiles into categories like "Geometry", "Hazards", "Enemies", "Collectibles"

3. **Plan connection points**: When creating chunks, think about where they should connect

4. **Test curved world early**: Enable the preview to ensure your levels look good with the effect

5. **Use theme tags**: Tag tiles and chunks with themes for coherent procedural generation

## Troubleshooting

### Visualizer not appearing
- Ensure you have a 3D scene open
- Click "New" to create a level first

### Shader not working
- Check that the shader file exists at the expected path
- Ensure materials support the shader

### Performance issues with large levels
- Reduce visible distance in visualizer settings
- Use chunked editing for very large levels

## License

[Your license here]

## Credits

Inspired by the level design system of Sonic Xtreme (Sega, unreleased).
