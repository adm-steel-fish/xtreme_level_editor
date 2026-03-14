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
│   └── retro_viewport_container.gd  # Post-process viewport
├── resources/retro/
│   ├── retro_settings.gd            # Settings resource class
│   └── default_retro_settings.tres  # Default configuration
└── scenes/retro/
    └── retro_viewport_container.tscn
```
