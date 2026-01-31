# Xtreme Level Editor: Retro Visual Style Guide

## Overview

The retro shader system provides PS1/Saturn-era visual effects inspired by Sonic Mania's special stages, Sonic Jam's Sonic World, and Sonic Galactic. The goal is a **"nostalgic interpretation"** - capturing the aesthetic charm of the era without slavishly replicating hardware limitations.

**Default Intensity: 25-50%** for a playable but distinctly retro experience.

---

## Shader Variants

### 1. `retro_standard.gdshader`
**Use Case:** General-purpose shader supporting both textures and vertex colors.

**Features:**
- Vertex jitter (PS1 fixed-point wobble)
- Affine texture warping
- Gouraud (per-vertex) lighting
- Color depth reduction with optional dithering
- Emission support

**When to Use:**
- Environment geometry with mixed coloring
- Props and objects
- Anything that doesn't fit the specialized variants

### 2. `retro_vertex_color.gdshader`
**Use Case:** Models using vertex colors instead of textures (Sonic Mania character style).

**Features:**
- Optimized for vertex-colored models
- Saturation boost for vibrant Mania-style colors
- Damage flash support
- Gouraud lighting

**When to Use:**
- Player characters
- NPCs
- Enemies (Badniks)
- Any low-poly model with vertex colors

### 3. `retro_textured.gdshader`
**Use Case:** Environment geometry with low-resolution textures.

**Features:**
- Strong affine texture warping
- UV scale/offset controls
- Optional detail texture blending
- Vertex color tinting support

**When to Use:**
- Level tiles and geometry
- Background elements
- Textured environment objects

### 4. `retro_unlit.gdshader`
**Use Case:** Self-illuminated objects not affected by scene lighting.

**Features:**
- No lighting calculations (constant brightness)
- Pulse animation
- Fresnel rim highlighting
- Flash and fade effects
- Perfect for collectibles

**When to Use:**
- Rings
- Blue/Red Spheres
- Power-ups and items
- UI elements in 3D space
- Particle effects

---

## Effect Parameters

### Global Retro Intensity
The `retro_intensity` parameter (0.0-1.0) controls the overall strength of retro effects:

| Value | Preset | Visual Style |
|-------|--------|--------------|
| 0.00 | Modern | No retro effects |
| 0.25 | Minimal | Subtle hint |
| 0.35 | Light | **Default** - noticeable but clean |
| 0.50 | Balanced | Clear retro aesthetic |
| 0.75 | Heavy | Strong retro feel |
| 1.00 | Authentic | Hardware-accurate |

### Individual Effect Overrides
Set any override to `-1.0` to use automatic values derived from `retro_intensity`.

| Parameter | Range | Effect |
|-----------|-------|--------|
| `vertex_jitter_override` | 0.0-1.0 | Vertex snapping intensity |
| `affine_warp_override` | 0.0-1.0 | Texture warping intensity |
| `color_reduction_override` | 0.0-1.0 | Color banding intensity |
| `dither_override` | 0.0-1.0 | Dithering strength |
| `jitter_resolution` | 32-512 | Virtual grid resolution (lower = more wobble) |

---

## Lighting System (Sonic Mania Style)

The retro shaders use **Gouraud shading** - light is calculated per-vertex and interpolated across faces, matching Sonic Mania's special stage rendering.

### Lighting Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `lighting_enabled` | true | Toggle lighting |
| `light_direction` | (0.3, -0.7, -0.5) | Global light direction |
| `light_color` | (1.0, 0.98, 0.95) | Warm white light |
| `light_intensity` | 1.0 | Light brightness |
| `ambient_color` | (0.3, 0.3, 0.35) | Cool shadow color |
| `ambient_intensity` | 0.4 | Shadow brightness |
| `use_half_lambert` | true | Softer shading (recommended) |

### Half-Lambert vs Standard
- **Half-Lambert (default):** Softer shadows, more visible detail in dark areas. Matches Sonic Mania's friendly, readable lighting.
- **Standard:** Harsher shadows, more contrast. More "realistic" but can lose detail.

---

## Model Guidelines

### Character Models (Vertex Color Style)
- **Polygon count:** 200-600 triangles
- **Coloring:** All color from vertex colors (NO textures)
- **Shading:** Smooth vertex normals for Gouraud interpolation
- **Animation:** Skeletal preferred, 24-30 FPS playback

### Environment Geometry
- **Texture resolution:** 32x32 to 128x128 pixels max
- **Filtering:** Always use `filter_nearest` (point sampling)
- **UV mapping:** Simple, grid-aligned where possible
- **Polygon density:** Low-medium, visible facets are part of the aesthetic

### Collectibles (Unlit Objects)
- **Polygon count:** 20-80 triangles
- **Style:** Simple geometric shapes
- **Coloring:** Vertex colors with brightness boost
- **Effects:** Pulse animation and/or rim lighting

---

## Using the RetroMaterial Helper

```gdscript
# Create materials easily with the RetroMaterial class

# Standard colored material
var wall_mat = RetroMaterial.create_standard(Color.RED, 0.35)

# Textured environment
var floor_mat = RetroMaterial.create_textured(floor_texture, Color.WHITE)

# Character material
var player_mat = RetroMaterial.create_character(Color.WHITE, 0.35, 1.1)

# Collectibles
var ring_mat = RetroMaterial.create_ring()
var blue_sphere = RetroMaterial.create_blue_sphere()
var red_sphere = RetroMaterial.create_red_sphere()

# Apply effects
RetroMaterial.set_damage_flash(enemy_mat, 0.5, Color.WHITE)
RetroMaterial.set_fade(ring_mat, 0.5)  # For collection animation
```

---

## Post-Processing Setup

The `RetroViewportContainer` handles screen-space effects:

1. **Add to scene:** Drag `retro_viewport_container.tscn` into your main scene
2. **Place 3D content:** Put your game world inside the `GameplayViewport`
3. **UI outside:** Place UI/HUD as siblings (NOT inside the viewport) to keep them clean

### Post-Process Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `render_scale` | 0.75 | Resolution downscaling (0.25-1.0) |
| `effect_intensity` | 0.35 | Overall post-process strength |
| `color_banding_enabled` | true | Enable posterization |
| `band_levels` | 64 | Color levels (8-256) |
| `use_dithering` | true | Smooth banding with dither |
| `dither_strength` | 0.5 | Dither intensity |

---

## Global Control with RetroShaderParams

Add `RetroShaderParams` to your Project Settings > AutoLoad for global control:

```gdscript
# Set global intensity
RetroShaderParams.retro_intensity = 0.5

# Use a preset
RetroShaderParams.set_preset(RetroShaderParams.RetroPreset.BALANCED)

# Adjust lighting globally
RetroShaderParams.light_direction = Vector3(0.5, -0.8, -0.3)
RetroShaderParams.ambient_color = Color(0.2, 0.2, 0.3)

# Register custom materials for bulk updates
RetroShaderParams.register_material(my_material)

# Create materials through the singleton
var mat = RetroShaderParams.create_retro_material("character")
```

---

## Integration with Existing Shaders

The retro shaders are designed to work **alongside** (not merged with) existing shaders:

- **Curved World Shader:** Apply retro materials to geometry using the curved world shader separately. The visual effects stack.
- **Wireframe/Pixelation:** These distance effects work independently. Use the existing system for draw distance culling.

---

## Best Practices

### DO:
- ✅ Use vertex colors for characters (cleaner, Mania-style)
- ✅ Keep textures low-resolution (32-128px)
- ✅ Enable half-lambert for softer, more readable lighting
- ✅ Use pulse/rim effects sparingly for important collectibles
- ✅ Test at both 25% and 50% intensity
- ✅ Keep UI/HUD outside the post-process viewport

### DON'T:
- ❌ Use high-resolution textures (defeats the aesthetic)
- ❌ Over-use vertex jitter (causes motion sickness)
- ❌ Mix retro and modern rendering on the same object
- ❌ Apply post-processing to UI elements
- ❌ Set retro_intensity to 1.0 for extended gameplay (eye strain)

---

## File Reference

```
addons/xtreme_level_editor/
├── shaders/retro/
│   ├── retro_common.gdshaderinc     # Shared functions
│   ├── retro_standard.gdshader      # General purpose
│   ├── retro_vertex_color.gdshader  # Characters
│   ├── retro_textured.gdshader      # Environments
│   ├── retro_unlit.gdshader         # Collectibles
│   └── retro_post_process.gdshader  # Screen effects
├── scripts/retro/
│   ├── retro_shader_params.gd       # Global controller
│   └── retro_material.gd            # Material factory
├── nodes/retro/
│   ├── retro_viewport_container.gd  # Post-process viewport
│   ├── parallax_background_3d.gd    # Background system
│   └── parallax_layer_3d.gd         # Individual layer
├── resources/retro/
│   ├── retro_settings.gd            # Settings resource class
│   ├── zone_visual_settings.gd      # Per-zone settings
│   ├── default_retro_settings.tres  # Default configuration
│   └── zone_night_sky.tres          # Example zone preset
└── scenes/retro/
    ├── retro_viewport_container.tscn
    └── prefabs/
        ├── retro_ring.tscn
        ├── retro_blue_sphere.tscn
        ├── retro_red_sphere.tscn
        ├── retro_spring.tscn
        └── retro_enemy.tscn
```

---

## Parallax Background System

The `ParallaxBackground3D` system creates depth with multiple 2D layers in 3D space.

### Layer Structure

| Layer | Parallax Factor | Description |
|-------|-----------------|-------------|
| Sky | 0.0 - 0.1 | Furthest, barely moves (stars, moon) |
| Far | 0.1 - 0.3 | Slow movement (mountains, distant buildings) |
| Mid | 0.3 - 0.6 | Medium movement (architecture, trees) |
| Near | 0.6 - 0.9 | Fast movement (foreground elements) |

### Setup

```gdscript
# Create a parallax background
var bg = ParallaxBackground3D.new()
bg.auto_find_camera = true
add_child(bg)

# Add layers programmatically
var sky = bg.create_color_layer(Color(0.1, 0.05, 0.2), 0.05, 200.0)
var far = bg.create_sprite_layer(mountain_texture, 0.2, 100.0)

# Or add ParallaxLayer3D nodes in the editor
```

### ParallaxLayer3D Properties

| Property | Description |
|----------|-------------|
| `parallax_factor` | Movement ratio (0.0-1.0) |
| `vertical_parallax_factor` | Vertical movement (usually less) |
| `base_distance` | Distance from camera (Z position) |
| `repeat_x/y` | Enable horizontal/vertical tiling |
| `layer_width/height` | Size for repeat calculations |
| `auto_scroll_speed` | Constant scroll (for animated backgrounds) |

---

## Zone Visual Settings

Each zone can have unique visual parameters via `ZoneVisualSettings` resources.

### Usage

```gdscript
# Load zone settings
var zone_settings = load("res://zones/green_hill/visual_settings.tres")

# Apply when entering zone
zone_settings.apply_to_scene(get_tree().current_scene)
```

### Included Presets

| Preset | Description |
|--------|-------------|
| `create_green_hill_preset()` | Bright, sunny, grassy |
| `create_chemical_plant_preset()` | Industrial, purple tones |
| `create_lava_reef_preset()` | Hot, volcanic, orange/red |
| `create_night_preset()` | Dark, blue nighttime |

### Creating Custom Zones

1. Create new `ZoneVisualSettings` resource
2. Configure lighting, sky, fog, and retro intensity
3. Assign to your zone scene
4. Call `apply_to_scene()` when zone loads

---

## Lighting System (RetroLightManager)

The `RetroLightManager` provides centralized control over PS1/Saturn-style vertex lighting.

### Features

- **Global Directional Light** - Single light direction for all objects
- **Gouraud Shading** - Per-vertex lighting calculation (half-lambert default)
- **Ambient Color** - Flat ambient term for shadowed areas
- **Distance Fog** - Objects fade to fog color at distance
- **Height Fog** - Optional vertical fog gradient

### Usage

```gdscript
# Add RetroLightManager to your scene
var light_mgr = RetroLightManager.new()
add_child(light_mgr)

# Configure lighting
light_mgr.light_direction = Vector3(0.3, -0.8, -0.4)
light_mgr.light_color = Color(1.0, 0.98, 0.9)
light_mgr.light_intensity = 1.2
light_mgr.ambient_color = Color(0.4, 0.45, 0.5)

# Enable fog
light_mgr.fog_enabled = true
light_mgr.fog_color = Color(0.3, 0.35, 0.4)
light_mgr.fog_start = 30.0
light_mgr.fog_end = 100.0

# Apply a preset
light_mgr.apply_sunny_preset()
light_mgr.apply_night_preset()
light_mgr.apply_indoor_preset()
light_mgr.apply_sunset_preset()
```

### Lighting Presets

| Preset | Description |
|--------|-------------|
| `apply_sunny_preset()` | Bright outdoor daylight |
| `apply_night_preset()` | Dark blue nighttime |
| `apply_indoor_preset()` | Warm interior lighting |
| `apply_sunset_preset()` | Orange dramatic sunset |

---

## Blob Shadow System

Simple circular shadows for PS1/Saturn-style rendering (no real-time shadows).

### Usage

```gdscript
# Add as child of player/character
var shadow = preload("res://addons/xtreme_level_editor/scenes/retro/prefabs/blob_shadow.tscn").instantiate()
player.add_child(shadow)

# Configure appearance
shadow.shadow_size = 1.5
shadow.shadow_color = Color(0, 0, 0, 0.5)
shadow.shadow_softness = 0.3
shadow.distance_scaling = true  # Smaller when far from ground
```

### Properties

| Property | Description |
|----------|-------------|
| `shadow_size` | Diameter of the shadow |
| `shadow_color` | Color and alpha of shadow |
| `shadow_softness` | Edge softness (0 = hard, 1 = very soft) |
| `shadow_strength` | Overall opacity (0-1) |
| `distance_scaling` | Shrink shadow when far from ground |
| `max_distance` | Maximum raycast distance |

---

## Fog Parameters

All lit retro shaders support distance and height fog.

### Distance Fog

| Parameter | Description |
|-----------|-------------|
| `fog_enabled` | Toggle fog on/off |
| `fog_color` | Color objects fade to |
| `fog_start` | Distance where fog begins |
| `fog_end` | Distance where fog is 100% |

### Height Fog

| Parameter | Description |
|-----------|-------------|
| `height_fog_enabled` | Enable vertical fog |
| `height_fog_bottom` | Y position of maximum fog |
| `height_fog_top` | Y position of no fog |
| `height_fog_density` | Maximum fog density (0-1) |

---

## Retro HUD System (Phase 5)

Clean, readable HUD that's exempt from retro post-processing effects.

### Features

- **Ring Counter** with animated spinning ring icon
- **Score Display** (8-digit)
- **Timer** with centisecond precision
- **Lives Counter**
- Warning flash when rings hit zero

### Usage

```gdscript
# Add RetroHUD to your scene
var hud = preload("res://addons/xtreme_level_editor/ui/retro_hud/retro_hud.tscn").instantiate()
add_child(hud)

# Update values
hud.rings = 50
hud.add_rings(10)
hud.add_score(1000)
hud.lives = 3

# Timer control
hud.start_timer()
hud.stop_timer()
hud.reset_timer()
```

---

## Screen Effects System (Phase 7)

Transitions, flashes, and overlays for game events.

### Effects Available

| Effect | Description | Method |
|--------|-------------|--------|
| Flash | Screen flash (damage, collect) | `flash(color, duration)` |
| Fade | Fade to/from color | `fade_transition(duration, color)` |
| Iris Wipe | Circle in/out | `iris_transition(duration, color, center)` |
| Horizontal Wipe | Side-to-side | `horizontal_wipe(duration, color)` |
| Vertical Wipe | Top-to-bottom | `vertical_wipe(duration, color)` |
| Pixelate | Retro pixelation | `pixelate_transition(duration, color)` |

### Usage

```gdscript
# Add ScreenEffectsManager to scene
var fx = ScreenEffectsManager.new()
add_child(fx)

# Quick flashes
fx.flash_damage()      # Red flash
fx.flash_ring_collect() # Yellow flash
fx.flash_white()       # White flash

# Transitions (emit signals at midpoint)
fx.iris_transition(1.5)
fx.await transition_midpoint
# Load new scene here
fx.await transition_finished

# Speed blur for fast movement
fx.set_speed_blur(0.5, player.velocity.angle())
fx.clear_speed_blur()
```

---

## Retro Particles (Phase 7)

Particle effects matching the PS1/Saturn aesthetic.

### Available Prefabs

| Prefab | Use Case |
|--------|----------|
| `ring_sparkle.tscn` | Ring collection |
| `dust_puff.tscn` | Landing, skidding |
| `speed_lines.tscn` | High-speed movement |

### Usage

```gdscript
# Spawn particles
var sparkle = preload("res://addons/.../ring_sparkle.tscn").instantiate()
sparkle.global_position = ring_position
get_tree().root.add_child(sparkle)
sparkle.emitting = true

# Speed lines (attach to player)
var lines = preload("res://addons/.../speed_lines.tscn").instantiate()
player.add_child(lines)
lines.emitting = player_speed > threshold
```

---

## Editor Integration (Phase 6)

Preview retro effects while editing levels.

### RetroEditorPreview Plugin

The plugin adds a "Retro Preview" button to the 3D editor toolbar:

- **Toggle** retro effects on/off in editor
- **Intensity slider** (0-100%)
- **Quick presets**: Modern, Light, Balanced, Authentic
- **Toggle** individual effects (jitter, fog)

### Enabling Editor Preview

The RetroEditorPreview is part of the XtremeLevelEditor plugin. When enabled:

1. Click "Retro Preview" in the 3D toolbar
2. Adjust intensity with the slider
3. Toggle effects as needed
4. All changes preview in real-time
