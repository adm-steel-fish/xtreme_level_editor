# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 1: Game Overview, Core Pillars, Technical Foundation

---

# 1. GAME OVERVIEW

## 1.1 High Concept

**Gina the Gecko** is a 3D platformer featuring momentum-based gameplay inspired by classic Sonic the Hedgehog titles, combined with on-rails flying sequences between zones. The game features a distinctive PS1/Saturn-era visual aesthetic combined with Sonic Xtreme's signature fisheye lens curved world effect, creating a surrealistic, geometric, computer-themed world.

## 1.2 Genre Classification

| Category | Classification |
|----------|----------------|
| Primary Genre | 3D Platformer |
| Secondary Genres | Action, Racing, Shoot 'em Up |
| Sub-Genres | Momentum Platformer, Score Attack, Tycoon/Builder |
| Perspective | Third-Person (Curved World Fisheye) |
| Player Count | Single-Player, Co-op (2P), Competitive (2-8P) |

## 1.3 Target Platform

- **Primary**: PC (Windows)
- **Engine**: Godot 4.5
- **Target Performance**: 60 FPS minimum
- **Resolution**: 1080p native, 4K supported

## 1.4 Inspirational References

### Primary Gameplay References
| Reference | Elements Borrowed |
|-----------|-------------------|
| Sonic the Hedgehog (Classic) | Momentum physics, ring system, level design philosophy |
| Sonic Xtreme (Cancelled) | Curved world fisheye lens, tube-level design |
| Wario Land Series | Exploration-focused level design, multiple pathways |
| Super Mario Bros 3 / New Super Mario Bros | World map structure, fortress/castle progression |

### Alternative Gameplay References
| Reference | Elements Borrowed |
|-----------|-------------------|
| Star Fox 64 | On-rails flying, all-range mode |
| Space Harrier | Shooting mechanics inspiration |

### Visual Style References
| Reference | Elements Borrowed |
|-----------|-------------------|
| Sonic Mania Special Stages | Geometric world, surrealist backgrounds, Saturn aesthetic |
| Sonic Jam's Sonic World | 3D Saturn-era rendering style |
| Sonic Xtreme "Project Condor" | Fisheye lens effect, tube world design |

### Additional System References
| Reference | Elements Borrowed |
|-----------|-------------------|
| Crash Team Rumble | Competitive multiplayer structure |
| Sonic Adventure 2 (Chao Garden) | Side-mode progression loop |
| Civilization/Tycoon Games | Village builder mechanics |

---

# 2. CORE DESIGN PILLARS

## 2.1 Pillar 1: Momentum-Based Freedom

The core gameplay loop centers on building and maintaining momentum through levels. Players should feel a constant sense of speed and flow, with the ability to:

- Build speed through slopes, ramps, and spin dashes
- Maintain momentum through skilled platforming
- Lose momentum through poor decisions or obstacles
- Regain momentum through environmental features

**Design Mandate**: Every level must provide multiple paths that reward skilled momentum management. Higher paths should be faster but more challenging; lower paths should be safer but slower.

## 2.2 Pillar 2: Exploration Over Speed

Unlike pure speed-focused Sonic games, Gina the Gecko emphasizes exploration similar to Wario Land:

- Levels contain secrets, hidden areas, and collectibles
- Multiple pathways encourage replay
- Time pressure is minimal outside specific modes
- Players are rewarded for thorough exploration

**Design Mandate**: Each level must contain at least 3 distinct pathways, multiple secret areas, and hidden collectibles that encourage full exploration.

## 2.3 Pillar 3: Gameplay Variety

The game features multiple distinct gameplay styles to prevent monotony:

- 3D Platforming (Primary)
- 2D Side-scrolling Sections
- Boss Encounters
- Flying Levels
- Bonus Stages (Pool, Pinball)
- Special Stages
- Village Builder Side-Mode

**Design Mandate**: No single gameplay style should dominate. Players should experience variety within each zone.

## 2.4 Pillar 4: Surrealist Saturn Aesthetic

The visual identity combines:

- PS1/Saturn-era rendering techniques (vertex jitter, affine texturing, color banding)
- Sonic Xtreme's curved world fisheye lens effect
- Geometric, mathematical world design
- Surrealist backgrounds and environments
- Computer/VR thematic elements

**Design Mandate**: All visual elements must pass the "Saturn Screenshot Test" - could this reasonably be a Saturn game with modern resolution?

## 2.5 Pillar 5: Interconnected Progression

All game modes feed into each other:

```
┌─────────────────────────────────────────────────────────────┐
│                    PROGRESSION LOOP                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐     ┌──────────────┐     ┌─────────────┐ │
│  │  STORY MODE  │────▶│VILLAGE BUILDER│────▶│ MULTIPLAYER │ │
│  └──────────────┘     └──────────────┘     └─────────────┘ │
│         │                    │                    │         │
│         │    Pixel Atoms     │    Unlocks         │         │
│         │    Structures      │    Characters      │         │
│         │    Characters      │    Maps            │         │
│         ▼                    ▼                    ▼         │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              UNIFIED PROGRESSION SYSTEM                 ││
│  │         (Battle Pass + Achievement Unlocks)             ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design Mandate**: Progress in any mode should feel meaningful and contribute to overall game completion.

---

# 3. TECHNICAL FOUNDATION

## 3.1 Engine & Framework

```yaml
engine: Godot 4.5
language: GDScript (Primary), C# (Performance-Critical Systems)
rendering: Forward+ Renderer with Custom Shaders
physics: Godot Physics (Custom Character Controller)
```

## 3.2 Core Technical Systems

### 3.2.1 Curved World Shader System

The signature visual effect that defines the game's look.

```
CURVED_WORLD_PARAMETERS:
  horizontal_curve: 0.15 (default)
  vertical_curve: 0.08 (default)
  curve_center: camera_position
  curve_falloff: exponential
  
IMPLEMENTATION:
  - Vertex shader transforms world geometry around camera
  - Collision geometry remains flat (standard 3D)
  - Visual-only effect, no gameplay impact
  - Separate horizontal/vertical curve speeds for movement compensation
```

### 3.2.2 Retro Rendering Pipeline

Complete PS1/Saturn aesthetic system.

```
RETRO_SHADER_FEATURES:
  vertex_jitter:
    enabled: true
    resolution: 128
    intensity: 0.35 (default "Light" preset)
    
  affine_texture_mapping:
    enabled: true
    intensity: 0.35
    
  color_reduction:
    bit_depth: 15-bit (default)
    dithering: ordered_bayer_4x4
    
  vertex_lighting:
    type: gouraud
    half_lambert: true
    
  distance_fog:
    enabled: true
    start: 50.0
    end: 150.0
    color: zone_dependent
```

### 3.2.3 Character Controller Architecture

```
CHARACTER_CONTROLLER:
  type: custom_physics_body
  
  states:
    - GROUNDED
    - AIRBORNE
    - ROLLING
    - SPINDASH
    - HOMING_ATTACK
    - RAIL_GRINDING
    - SWIMMING
    - CLIMBING
    - DAMAGED
    - INTANGIBLE (post-damage invincibility)
    
  physics_model:
    acceleration: curve-based
    deceleration: friction-based
    max_speed: 25.0 units/sec (default)
    boost_max_speed: 40.0 units/sec
    gravity: 30.0 units/sec²
    jump_velocity: 15.0 units/sec
    
  collision:
    shape: capsule (standing), sphere (rolling)
    ground_detection: raycast_array
    wall_detection: shapecasts
```

### 3.2.4 Camera System

```
CAMERA_MODES:
  
  CURVED_WORLD_FOLLOW:
    description: "Standard gameplay camera"
    position: fixed_offset_behind_player
    rotation: fixed_pitch, no_yaw
    updates_shader: true
    
  DYNAMIC_BOSS:
    description: "Boss encounter camera"
    position: dynamic_orbit
    rotation: tracks_player_and_boss
    updates_shader: false (no curved world)
    
  SIDE_SCROLLER:
    description: "2D section camera"
    position: perpendicular_to_path
    rotation: fixed_side_view
    updates_shader: true (vertical curve variation)
    
  ON_RAILS:
    description: "Flying level camera"
    position: behind_vehicle
    rotation: follows_rail_path
    updates_shader: false
    
  FREE_FLIGHT:
    description: "All-range flying mode"
    position: third_person_follow
    rotation: follows_vehicle_orientation
    updates_shader: false
```

## 3.3 Scene Architecture

```
SCENE_HIERARCHY:

Game
├── Core/
│   ├── GameManager (autoload)
│   ├── SaveManager (autoload)
│   ├── AudioManager (autoload)
│   ├── InputManager (autoload)
│   └── TransitionManager (autoload)
│
├── Gameplay/
│   ├── Player/
│   │   ├── PlayerController
│   │   ├── PlayerStateMachine
│   │   ├── PlayerAbilities
│   │   └── PlayerVisuals
│   │
│   ├── Camera/
│   │   ├── XtremeCamera (curved world)
│   │   ├── BossCamera (dynamic)
│   │   ├── SideScrollCamera (2D sections)
│   │   └── RailCamera (flying)
│   │
│   ├── Levels/
│   │   ├── LevelLoader
│   │   ├── CheckpointManager
│   │   ├── CollectibleManager
│   │   └── TransitionZones
│   │
│   └── Combat/
│       ├── BossManager
│       ├── EnemyManager
│       └── HazardManager
│
├── UI/
│   ├── HUD/
│   │   ├── RetroHUD
│   │   ├── BossHealthBar
│   │   └── ModeSpecificHUD
│   │
│   ├── Menus/
│   │   ├── MainMenu
│   │   ├── PauseMenu
│   │   ├── WorldMap
│   │   └── OptionsMenu
│   │
│   └── Transitions/
│       └── ScreenEffectsManager
│
├── Modes/
│   ├── Flying/
│   ├── BonusStages/
│   └── VillageBuilder/
│
└── Multiplayer/
    ├── NetworkManager
    ├── LobbyManager
    └── MatchManager
```

## 3.4 Data Architecture

### 3.4.1 Save Data Structure

```
SAVE_DATA:
  
  profile:
    name: string
    playtime: float
    date_created: timestamp
    date_modified: timestamp
    
  story_progress:
    zones_unlocked: array[zone_id]
    levels_completed: dictionary[level_id: completion_data]
    bosses_defeated: array[boss_id]
    cosmic_crystals: int (0-8)
    total_pixel_atoms: int
    
  level_completion_data:
    best_time: float
    best_score: int
    rings_collected: int
    secrets_found: array[secret_id]
    rank: string (S/A/B/C/D)
    
  collectibles:
    medallions: int
    total_rings_lifetime: int
    
  village:
    structures: array[structure_data]
    population: int
    resources: dictionary
    missions_completed: array[mission_id]
    
  multiplayer:
    characters_unlocked: array[character_id]
    maps_unlocked: array[map_id]
    skins_unlocked: array[skin_id]
    battle_pass_level: int
    battle_pass_xp: int
    
  settings:
    audio: audio_settings
    video: video_settings
    controls: control_mappings
    accessibility: accessibility_settings
```

### 3.4.2 Zone Data Structure

```
ZONE_DATA:
  
  zone_id: string
  zone_name: string
  zone_theme: string
  
  visual_settings:
    sky_colors: gradient
    fog_color: color
    fog_distances: vector2
    ambient_color: color
    light_direction: vector3
    retro_intensity: float
    
  levels: array[level_data]
  
  bosses:
    mid_bosses: array[boss_id]
    final_boss: boss_id
    
  
  unlock_requirements:
    prerequisite_zones: array[zone_id]
    prerequisite_crystals: int
```

### 3.4.3 Level Data Structure

```
LEVEL_DATA:
  
  level_id: string
  level_name: string
  level_type: enum[STANDARD, BOSS, FLYING, SPECIAL]
  
  geometry:
    visual_mesh: resource_path
    collision_mesh: resource_path
    
  spawn_points:
    player_start: vector3
    checkpoints: array[checkpoint_data]
    
  collectibles:
    rings: array[position]
    secrets: array[secret_data]
    power_ups: array[powerup_data]
    
  enemies:
    spawns: array[enemy_spawn_data]
    
  transitions:
    to_2d_sections: array[transition_data]
    to_boss_areas: array[transition_data]
    level_exit: transition_data
    
  special_stage_warp:
    position: vector3 (or null)
    crystal_id: int
    
  par_times:
    s_rank: float
    a_rank: float
    b_rank: float
    c_rank: float
```

## 3.5 Input System

### 3.5.1 Control Schemes

```
CONTROL_SCHEME_PLATFORMING:
  
  movement:
    left_stick / WASD: move_direction
    
  actions:
    button_south / SPACE: jump
    button_south (hold): jump_higher
    button_west / SHIFT: spin_dash (hold + release)
    button_east / E: ability_secondary
    button_north / Q: ability_special
    
  triggers:
    right_trigger / MOUSE1: boost
    left_trigger / MOUSE2: brake / reverse
    
  camera:
    right_stick: camera_adjust (limited)
    
---

CONTROL_SCHEME_FLYING:
  
  movement:
    left_stick / WASD: ship_position
    
  actions:
    button_south / SPACE: shoot
    button_south (hold): charge_shot
    button_west / SHIFT: barrel_roll_left
    button_east / E: barrel_roll_right
    button_north / Q: bomb / special_weapon
    
  evasion:
    left_trigger + direction: quick_dodge
```

## 3.6 Performance Budgets

```
PERFORMANCE_TARGETS:
  
  frame_rate: 60 FPS (minimum)
  frame_time: 16.67ms (maximum)
  
  memory:
    total_budget: 4 GB
    level_geometry: 512 MB
    textures: 1 GB
    audio: 256 MB
    scripts: 128 MB
    particles: 128 MB
    ui: 64 MB
    reserve: 1.9 GB
    
  draw_calls:
    maximum: 2000 per frame
    target: 1000 per frame
    
  triangles:
    maximum: 500,000 per frame
    target: 300,000 per frame
    
  physics:
    collision_shapes: 1000 maximum active
    raycasts_per_frame: 100 maximum
```

---

# 4. NARRATIVE FOUNDATION

## 4.1 Setting Overview

The game takes place in **GECKO GRID**, a vibrant virtual reality world inhabited by anthropomorphic creatures. This VR world exists as a digital sanctuary, but has come under threat from outside forces.

### 4.1.1 World Lore

```
WORLD_BACKGROUND:

  The GECKO GRID was created generations ago as a digital paradise - 
  a virtual world where creatures could live free from the dangers 
  of the physical realm. The world is built from raw data, appearing 
  as geometric landscapes, mathematical patterns, and surrealist 
  environments that blend natural beauty with digital architecture.
  
  The TRIBAL VILLAGES within GECKO GRID have existed in peace for 
  centuries, their inhabitants unaware of the "real world" beyond 
  their digital borders. They believe their world is simply... the world.
  
  THE IMPERION SYNDICATE are criminal hackers from the physical world 
  who have discovered GECKO GRID. Seeking to escape prosecution in 
  reality, they plan to upload their consciousnesses permanently into 
  this digital paradise - but first, they must "clear out" the existing 
  inhabitants to make room for their new empire.
  
  When the Syndicate attacks TROPICA VILLAGE, home of Gina the Gecko, 
  most of her tribe is captured and imprisoned across the GRID. Gina, 
  who was away travelling when the attack occurred, returns to find her 
  home destroyed and her people gone.
  
  Now Gina must journey across the zones of GECKO GRID, rescue her 
  tribe members, collect the eight COSMIC CRYSTALS that power the 
  world's defenses, and ultimately confront the Syndicate before they 
  can complete their digital takeover.
```

## 4.2 Main Character

### 4.2.1 Gina the Gecko - Protagonist

```
CHARACTER_PROFILE:
  
  name: "Gina"
  species: Gecko
  color: Orange with purple accents
  attire: Purple tribal clothing, arm wraps, ankle wraps
  age: 16 (equivalent)
  
  physical_design:
    style: Classic cartoon (Mickey Mouse era influence)
    body_type: Streamlined, capable of curling into ball
    height: Standard Sonic-like proportions
    distinctive_features:
      - Large expressive eyes
      - Spotted gecko patterns
      - Sticky gecko pads (gameplay relevant)
      - Tail used for balance
      
  personality_traits:
    positive:
      - Brave and courageous
      - Confident in abilities
      - Quick learner
      - Loyal to tribe and friends
      - Determined to succeed
    negative:
      - Stubborn
      - Reckless
      - Rushes into danger
      - Can be overconfident
      - Impatient
      
  abilities_lore:
    innate:
      - Wall climbing (gecko pads)
      - High agility and speed
    learned:
      - Jet piloting (stolen Syndicate tech)
      - Combat techniques (necessity)
      
  motivation:
    primary: "Rescue captured tribe members"
    secondary: "Stop the Imperion Syndicate"
    personal: "Prove she can protect her people"
    
  character_arc:
    start: "Reckless warrior who acts without thinking"
    middle: "Learns that some battles require strategy"
    end: "Balanced hero who knows when to fight and when to plan"
```

## 4.3 Rival Characters

The **IMPERION SYNDICATE COMMANDERS** serve as recurring boss encounters throughout the game.

### 4.3.1 Commander Nexus - The Strategist

```
RIVAL_PROFILE:
  
  name: "Commander Nexus"
  role: Syndicate Field Commander
  species: Digital Avatar (human consciousness)
  appearance: Geometric humanoid, sharp angles, chrome and blue
  
  personality:
    - Cold and calculating
    - Views everything as data to be processed
    - Respects efficiency, despises "chaos" (like Gina)
    
  boss_theme: "Order vs Chaos"
  
  encounters:
    1: Zone 3 - Tutorial rival fight, tests player basics
    2: Zone 8 - More aggressive, new attack patterns
    3: Zone 14 - Desperate, unpredictable
    4: Zone 17 - Final confrontation, full power
    
  fighting_style:
    - Precise, predictable patterns (early)
    - Adapts to player tactics (later)
    - Uses geometric projectiles and barriers
```

### 4.3.2 Surge - The Speedster

```
RIVAL_PROFILE:
  
  name: "Surge"
  role: Syndicate Enforcer
  species: Digital Avatar (human consciousness)
  appearance: Sleek, lightning-themed, yellow and black
  
  personality:
    - Arrogant and boastful
    - Obsessed with being the fastest
    - Takes Gina's speed as a personal insult
    
  boss_theme: "Speed vs Speed"
  
  encounters:
    1: Zone 4 - Race-style boss fight
    2: Zone 9 - Combat while both moving at high speed
    3: Zone 15 - Chase sequence boss
    
  fighting_style:
    - Relies on speed and quick attacks
    - Vulnerable when he stops to taunt
    - Creates speed-based hazards
```

### 4.3.3 Titanica - The Colossus

```
RIVAL_PROFILE:
  
  name: "Titanica"
  role: Syndicate Heavy Unit
  species: Digital Avatar (human consciousness)
  appearance: Massive mech-like form, industrial, red and grey
  
  personality:
    - Slow-speaking but intelligent
    - Believes might makes right
    - Sees small creatures as beneath her
    
  boss_theme: "David vs Goliath"
  
  encounters:
    1: Zone 6 - Shadow of the Colossus-style climbing fight
    2: Zone 11 - Arena fight with terrain destruction
    3: Zone 16 - Multi-phase colossus battle
    
  fighting_style:
    - Slow but devastating attacks
    - Must be climbed to reach weak points
    - Environmental destruction creates hazards
```

### 4.3.4 Glitch - The Trickster

```
RIVAL_PROFILE:
  
  name: "Glitch"
  role: Syndicate Saboteur
  species: Digital Avatar (corrupted data)
  appearance: Constantly shifting, pixelated, multicolored static
  
  personality:
    - Unpredictable and chaotic
    - Finds everything amusing
    - May not be entirely sane
    
  boss_theme: "Reality vs Illusion"
  
  encounters:
    1: Zone 5 - Environment manipulation fight
    2: Zone 10 - Clone/illusion battle
    3: Zone 13 - Reality-warping arena
    
  fighting_style:
    - Creates false copies of itself
    - Warps the arena mid-fight
    - Unpredictable attack patterns
```

### 4.3.5 Director Vex - The Mastermind (Final Boss)

```
RIVAL_PROFILE:
  
  name: "Director Vex"
  role: Syndicate Leader
  species: Digital Avatar (human consciousness)
  appearance: Corporate suit aesthetic gone digital, 
              black and gold, imposing presence
  
  personality:
    - Believes he's saving humanity
    - Views GECKO GRID inhabitants as "just programs"
    - Genuinely thinks he's the hero
    
  boss_theme: "What is Real?"
  
  encounters:
    1: Zone 12 - Mid-game confrontation (escapes)
    2: Zone 18 - Final battle, multiple phases
    
  fighting_style:
    phase_1: Uses Syndicate tech and minions
    phase_2: Absorbs power, becomes threat himself
    phase_3: God-like abilities, tests all player skills
    cosmic_phase: Only beatable with Cosmic Mode
```

## 4.4 Supporting Characters

### 4.4.1 Tribe Members (Rescue Targets)

```
SUPPORTING_CAST:
  
  ELDER_PIXEL:
    role: Tribal elder, guide
    provides: Story exposition, hints
    rescued: Zone 2
    
  CHIP:
    role: Gina's best friend, tech-savvy
    provides: Tutorial hints, upgrade explanations
    rescued: Zone 1
    
  MARINA:
    rescued: Zone 4
    
  FROST:
    role: Northern tribe visitor
    rescued: Zone 7
    
  Additional tribe members rescued throughout zones
  provide village builder population and side quests
```

---

# 5. CONTENT SCOPE SUMMARY

## 5.1 Total Content Overview

```
GAME_SCOPE:
  
  zones: 18
  levels_per_zone: 6-10 (average 8)
  total_main_levels: ~144
  
  flying_levels: 17 (zone transitions)
  
  bosses:
    rival_bosses: 15 encounters (5 rivals × 3 each)
    zone_bosses: 36+ (2+ per zone)
    
  cosmic_crystals: 8
  special_stages: 8
  
  multiplayer:
    playable_characters: 18
    maps: TBD (minimum 8)
    
  estimated_playtime:
    story_completion: 15-20 hours
    100%_completion: 40-60 hours
    multiplayer: Unlimited
```

## 5.2 Development Priority

```
PHASE_1_CORE:
  - Core 3D platforming mechanics
  - 3 complete zones (tutorial + 2)
  - Basic boss system
  - Core visual style
  
PHASE_2_VARIETY:
  - 2D section system
  - Flying gameplay
  
PHASE_3_EXPANSION:
  - Remaining zones
  - All boss encounters
  - Bonus stages
  - Special stages
  
PHASE_4_MULTIPLAYER:
  - Co-op campaign
  - Competitive mode
  - Character roster
  
PHASE_5_POLISH:
  - Village builder
  - Level editor
  - Full progression system
  - Achievements/unlocks
```

---

**END OF PART 1**

*Next: Part 2 - Core 3D Platforming Gameplay*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 2: Core 3D Platforming Gameplay

---

# 6. MOVEMENT SYSTEM

## 6.1 Core Movement Philosophy

Gina's movement is built on **momentum-based physics** where speed is earned through skillful play and maintained through proper technique. The system draws from Classic Sonic's physics while adding gecko-specific abilities.

### 6.1.1 Movement States

```
MOVEMENT_STATES:

  IDLE:
    description: "Standing still, no input"
    transitions_to: [WALKING, JUMPING, CROUCHING, LOOKING]
    physics: Full friction applied
    
  WALKING:
    description: "Low-speed ground movement"
    speed_range: 0 - 5 units/sec
    acceleration: 15 units/sec²
    transitions_to: [RUNNING, IDLE, JUMPING, SKIDDING]
    
  RUNNING:
    description: "Standard ground movement"
    speed_range: 5 - 15 units/sec
    acceleration: 12 units/sec²
    transitions_to: [SPRINTING, WALKING, JUMPING, ROLLING, SKIDDING]
    
  SPRINTING:
    description: "High-speed ground movement"
    speed_range: 15 - 25 units/sec
    acceleration: 8 units/sec²
    transitions_to: [BOOST, RUNNING, JUMPING, ROLLING]
    boost_requirement: Boost meter > 0
    
  BOOST:
    description: "Maximum speed with boost active"
    speed_range: 25 - 40 units/sec
    acceleration: 20 units/sec²
    transitions_to: [SPRINTING, AIRBORNE]
    boost_drain: 10% per second
    
  SKIDDING:
    description: "Decelerating from high speed with opposite input"
    trigger: "Input opposite to velocity when speed > 10"
    deceleration: 25 units/sec²
    transitions_to: [RUNNING, IDLE, JUMPING]
    visual: Dust particles, skid marks
    audio: Skid sound effect
    
  CROUCHING:
    description: "Ducking while stationary"
    trigger: "Down input while IDLE or low speed"
    transitions_to: [ROLLING, SPINDASH, IDLE]
    
  ROLLING:
    description: "Ball form while moving"
    trigger: "Down input while moving OR crouching while on slope"
    speed_modifier: 1.2x on slopes, 0.8x deceleration on flat
    transitions_to: [RUNNING, AIRBORNE, SPINDASH]
    collision: Sphere shape, can damage enemies
    
  SPINDASH:
    description: "Charged roll attack"
    trigger: "Jump while CROUCHING"
    charge_time: 0.0 - 2.0 seconds
    speed_output: 15 + (charge_time × 10) units/sec
    max_speed: 35 units/sec
    transitions_to: [ROLLING]
```

## 6.2 Aerial Movement

```
AERIAL_STATES:

  JUMPING:
    description: "Initial jump, upward velocity"
    initial_velocity: 15 units/sec
    variable_height: true (release early = lower jump)
    air_control: 0.6x ground acceleration
    transitions_to: [FALLING, DOUBLE_JUMP, HOMING_ATTACK, BOUNCE]
    
  DOUBLE_JUMP:
    description: "Second jump in air"
    velocity_boost: 12 units/sec (added to current)
    limit: 1 per airborne sequence
    transitions_to: [FALLING, HOMING_ATTACK, BOUNCE]
    
  FALLING:
    description: "Descending without upward velocity"
    gravity: 30 units/sec²
    terminal_velocity: 50 units/sec
    air_control: 0.6x ground acceleration
    transitions_to: [GROUNDED, HOMING_ATTACK, BOUNCE, STOMPING]
    
  HOMING_ATTACK:
    description: "Lock-on aerial dash to target"
    trigger: "Jump button while airborne with valid target"
    speed: 35 units/sec
    range: 15 units
    target_types: [enemies, springs, item_boxes, homing_targets]
    transitions_to: [FALLING, chain_HOMING_ATTACK]
    cooldown: 0.2 seconds between chains
    
  BOUNCE:
    description: "Downward ball attack"
    trigger: "Down + Jump while airborne"
    downward_velocity: 25 units/sec
    bounce_height: 0.8x of fall distance (capped)
    enemy_bounce: 1.2x normal jump height
    transitions_to: [FALLING, BOUNCE (chain)]
    
  STOMPING:
    description: "Fast downward attack, no bounce"
    trigger: "Down + Attack while airborne"
    downward_velocity: 40 units/sec
    landing_impact: Damages nearby enemies, triggers switches
    transitions_to: [GROUNDED]
```

## 6.3 Special Movement States

```
SPECIAL_STATES:

  WALL_RUNNING:
    description: "Running along vertical surfaces"
    trigger: "Contact wall while moving fast enough"
    minimum_speed: 12 units/sec
    duration: Based on speed (max 3 seconds)
    gravity_modifier: 0.5x while running
    transitions_to: [WALL_JUMP, FALLING]
    
  WALL_CLIMBING:
    description: "Gecko ability - climbing walls slowly"
    trigger: "Contact wall + hold toward wall"
    climb_speed: 5 units/sec
    stamina_cost: 10% per second
    stamina_regeneration: When grounded
    transitions_to: [WALL_JUMP, FALLING, WALL_RUNNING]
    
  WALL_JUMP:
    description: "Jump away from wall"
    trigger: "Jump while WALL_RUNNING or WALL_CLIMBING"
    velocity: 12 units/sec perpendicular + 10 units/sec up
    transitions_to: [FALLING, WALL_RUNNING (opposite wall)]
    
  RAIL_GRINDING:
    description: "Grinding on rails"
    trigger: "Land on grind rail"
    speed: Maintained from entry + slope acceleration
    controls: 
      - Left/Right: Balance (prevents falling)
      - Jump: Exit rail
      - Down: Crouch (speed boost, lower profile)
    tricks: Can perform tricks for score
    transitions_to: [JUMPING, FALLING]
    
  SWIMMING_SURFACE:
    description: "Swimming at water surface"
    trigger: "Contact water surface"
    speed: 0.7x normal max speed
    controls:
      - Movement: 8-directional
      - Jump: Leap out of water
    transitions_to: [SWIMMING_SUBMERGED, GROUNDED]
    
  SWIMMING_SUBMERGED:
    description: "Swimming underwater"
    trigger: "Dive from surface OR fall into deep water"
    speed: 0.6x normal max speed
    air_meter: 30 seconds
    air_bubbles: Reset air meter
    controls:
      - Movement: Full 3D
      - Jump: Swim burst upward
      - Attack: Underwater spin attack
    transitions_to: [SWIMMING_SURFACE, DROWNED (death)]
```

## 6.4 Physics Parameters

```
PHYSICS_CONFIG:

  GROUND_PHYSICS:
    base_acceleration: 15.0
    max_walk_speed: 5.0
    max_run_speed: 15.0
    max_sprint_speed: 25.0
    max_boost_speed: 40.0
    
    friction_coefficient: 0.95 (per frame at 60fps)
    slope_factor_up: 0.7 (speed multiplier going uphill)
    slope_factor_down: 1.3 (speed multiplier going downhill)
    
    skid_threshold: 10.0 (speed to trigger skid)
    skid_deceleration: 25.0
    
  AIR_PHYSICS:
    air_acceleration: 9.0 (0.6x ground)
    air_drag: 0.98 (per frame)
    gravity: 30.0
    terminal_velocity: 50.0
    
    jump_velocity: 15.0
    jump_cut_modifier: 0.5 (velocity multiplied when releasing jump early)
    double_jump_velocity: 12.0
    
    coyote_time: 0.1 seconds (can still jump after leaving ground)
    jump_buffer: 0.15 seconds (jump input remembered before landing)
    
  ROLL_PHYSICS:
    roll_friction: 0.98 (less than ground)
    roll_slope_up: 0.5 (slow down more on uphills)
    roll_slope_down: 1.5 (speed up more on downhills)
    uncurl_speed_threshold: 3.0 (auto-uncurl below this speed)
    
  SPINDASH_PHYSICS:
    min_charge: 0.0 seconds
    max_charge: 2.0 seconds
    base_speed: 15.0
    charge_speed_bonus: 10.0 per second of charge
    max_release_speed: 35.0
    charge_decay: None (hold to maintain charge)
```

---

# 7. ABILITIES SYSTEM

## 7.1 Core Abilities

These abilities are always available to the player.

### 7.1.1 Spin Jump

```
ABILITY: SPIN_JUMP
  
  description: "Basic jump that damages enemies on contact"
  
  input: Jump button
  
  mechanics:
    - Player curls into ball during jump
    - Contact with enemy top/side deals damage
    - Contact with enemy underside or hazard damages player
    - Can be extended with double jump
    
  parameters:
    jump_velocity: 15.0
    double_jump_velocity: 12.0
    hitbox: sphere, radius 0.8
    
  visual:
    - Ball sprite/model
    - Motion blur at high speeds
    - Landing dust particles
```

### 7.1.2 Spin Dash

```
ABILITY: SPIN_DASH
  
  description: "Charged rolling attack from standstill"
  
  input: Crouch + Jump (hold jump to charge, release to launch)
  
  mechanics:
    - Player crouches and revs in place
    - Charge builds over time
    - Release launches player in facing direction
    - Maintains ball form after launch
    
  parameters:
    charge_rate: Linear over 2 seconds
    min_speed: 15.0
    max_speed: 35.0
    charge_time_for_max: 2.0 seconds
    
  visual:
    - Rev animation (spinning in place)
    - Dust cloud grows with charge
    - Speed lines on release
    - Screen shake on max charge release
    
  audio:
    - Rev sound (pitch increases with charge)
    - Release whoosh
```

### 7.1.3 Homing Attack

```
ABILITY: HOMING_ATTACK
  
  description: "Lock-on dash attack to nearby targets"
  
  input: Jump button while airborne (with valid target)
  
  mechanics:
    - Scans for valid targets in range
    - Displays reticle on nearest valid target
    - Launches toward target on button press
    - Bounces off target on hit, can chain to next
    
  targeting:
    range: 15.0 units
    cone_angle: 60 degrees (forward)
    priority: [enemies, springs, homing_targets, item_boxes]
    
  parameters:
    dash_speed: 35.0
    bounce_velocity: 10.0 upward
    chain_cooldown: 0.2 seconds
    max_chain: Unlimited (as long as targets exist)
    
  visual:
    - Reticle on valid target
    - Dash trail during attack
    - Impact burst on hit
    
  audio:
    - Lock-on sound
    - Dash whoosh
    - Hit impact
```

### 7.1.4 Bounce Attack

```
ABILITY: BOUNCE_ATTACK
  
  description: "Downward ball attack with bounce"
  
  input: Down + Jump while airborne
  
  mechanics:
    - Player curls and shoots downward
    - Bounces on ground or enemies
    - Bounce height based on fall distance
    - Can be chained for increasing height
    
  parameters:
    downward_velocity: 25.0
    bounce_multiplier: 0.8 (of fall velocity, converted to upward)
    enemy_bounce_multiplier: 1.2
    max_bounce_velocity: 20.0
    ground_impact_damage: true (to nearby enemies)
    
  visual:
    - Downward motion blur
    - Impact dust/shockwave
    - Bounce stretch animation
```

### 7.1.5 Stomp Attack

```
ABILITY: STOMP_ATTACK
  
  description: "Fast downward attack, no bounce"
  
  input: Down + Attack while airborne
  
  mechanics:
    - Rapid descent to ground
    - Creates shockwave on landing
    - Activates ground switches
    - No bounce (ends aerial movement)
    
  parameters:
    downward_velocity: 40.0
    shockwave_radius: 3.0
    shockwave_damage: true
    
  visual:
    - Fast drop animation
    - Large impact dust cloud
    - Shockwave ring effect
```

## 7.2 Gecko-Specific Abilities

Unique abilities that set Gina apart from other platformer protagonists.

### 7.2.1 Wall Climb

```
ABILITY: WALL_CLIMB
  
  description: "Gecko pads allow climbing any vertical surface"
  
  input: Hold toward wall while touching it
  
  mechanics:
    - Gina sticks to wall and can climb freely
    - Uses stamina while climbing
    - Cannot attack while climbing
    - Can jump off wall at any time
    
  parameters:
    climb_speed: 5.0 units/sec
    stamina_max: 100%
    stamina_drain: 10% per second
    stamina_regen: 20% per second (when grounded)
    
  visual:
    - Wall-cling pose
    - Gecko pad glow effect
    - Stamina indicator when active
    
  restrictions:
    - Cannot climb certain surfaces (marked/slippery)
    - Cannot climb while holding items
```

### 7.2.2 Wall Run

```
ABILITY: WALL_RUN
  
  description: "Run along walls horizontally at high speed"
  
  input: Automatic when hitting wall at sufficient speed
  
  mechanics:
    - Triggered by wall contact above minimum speed
    - Maintains momentum along wall surface
    - Gravity reduced while running
    - Duration based on entry speed
    
  parameters:
    minimum_entry_speed: 12.0
    gravity_multiplier: 0.5
    max_duration: 3.0 seconds
    speed_decay: 5% per second
    
  transitions:
    - Jump: Wall jump
    - Slow down: Fall off
    - End of wall: Fall or jump
```

### 7.2.3 Tongue Grapple

```
ABILITY: TONGUE_GRAPPLE
  
  description: "Grappling hook using gecko tongue"
  
  input: Secondary ability button toward grapple point
  
  mechanics:
    - Fires tongue toward grapple targets
    - Pulls Gina toward the target
    - Can swing from certain targets
    - Quick traversal option
    
  parameters:
    range: 20.0 units
    travel_speed: 30.0 units/sec
    valid_targets: [grapple_points, certain_enemies, rings]
    
  modes:
    PULL: Pull directly to target point
    SWING: Swing from target (rope physics)
    YANK: Pull small objects/enemies to Gina
    
  visual:
    - Tongue extension animation
    - Tongue stretch/retract
    - Target highlight when in range
```

## 7.3 Boost System

```
BOOST_SYSTEM:
  
  description: "Speed boost meter filled through gameplay"
  
  METER:
    max_value: 100
    display: Bar on HUD
    
  FILLING:
    ring_collect: +2 per ring
    enemy_defeat: +5 per enemy
    trick_perform: +1-10 based on trick
    rail_grind: +1 per second
    
  DRAINING:
    boost_active: -10 per second
    damage_taken: -25 instant
    
  USAGE:
    input: Hold boost button (right trigger/shift)
    effect: Increases max speed to 40 units/sec
    requirement: Meter > 0
    
  VISUAL:
    - Speed lines around player
    - Color shift on character
    - Screen edge blur
    - Boost trail effect
```

---

# 8. RING SYSTEM

## 8.1 Ring Mechanics

```
RING_SYSTEM:
  
  description: "Rings serve as health, currency, and score"
  
  COLLECTION:
    method: Contact with ring hitbox
    hitbox: Sphere, radius 0.5
    sound: Classic ring collect sound
    visual: Ring disappears with sparkle
    
  HEALTH_FUNCTION:
    rings > 0: Player survives any hit (except instant-death)
    rings = 0: Next hit kills player
    
  ON_DAMAGE:
    rings_lost: All current rings
    rings_dropped: min(rings_held, 32) scattered
    recovery_time: 3.0 seconds (can recollect)
    invincibility: 2.0 seconds after hit
    
  DROPPED_RINGS:
    scatter_pattern: Circular burst
    scatter_radius: 5.0 units
    lifetime: 3.0 seconds
    blink_start: 2.0 seconds
    attraction: None (must manually collect)
    
  CAPS:
    display_cap: 999
    actual_cap: None (internally tracked)
    
  BONUSES:
    100_rings: Extra score bonus
    checkpoint_20: Access to bonus stage
    level_end_100: Access to pinball bonus
```

## 8.2 Ring Types

```
RING_VARIANTS:

  STANDARD_RING:
    value: 1
    appearance: Gold torus
    behavior: Static or moving on path
    
  SUPER_RING:
    value: 10
    appearance: Large gold ring with "10" display
    behavior: Static, often in secret areas
    
  TRAIL_RINGS:
    value: 1 each
    appearance: Line of rings
    behavior: Often guide player through optimal path
    
  RING_CAPSULE:
    value: 5-20
    appearance: Floating capsule with ring icon
    behavior: Breaks on contact, releases rings
    
  ATTRACTION_RING:
    value: 1
    appearance: Glowing ring
    behavior: Pulls nearby rings toward player for 10 seconds
```

---

# 9. POWER-UP SYSTEM

## 9.1 Shield Power-Ups

Shields provide protection and special abilities. Only one shield can be active at a time.

### 9.1.1 Basic Shield

```
POWER_UP: BASIC_SHIELD
  
  protection: Absorbs one hit without ring loss
  duration: Until hit
  ability: None
  appearance: Blue bubble around player
  
  stacking: Replaces any existing shield
```

### 9.1.2 Flame Shield

```
POWER_UP: FLAME_SHIELD
  
  protection: Absorbs one hit, immune to fire hazards
  duration: Until hit OR water contact (destroyed by water)
  
  ability: FLAME_DASH
    input: Jump while airborne
    effect: Horizontal fire dash
    distance: 8 units
    damage: Burns enemies in path
    
  appearance: Rotating flames around player
```

### 9.1.3 Aqua Shield

```
POWER_UP: AQUA_SHIELD
  
  protection: Absorbs one hit, unlimited underwater breathing
  duration: Until hit
  
  ability: AQUA_BOUNCE
    input: Jump while airborne
    effect: Bounces on ground like ball
    bounces: 3 before stopping
    damage: On contact during bounce
    
  appearance: Water bubble with ripple effect
```

### 9.1.4 Electric Shield

```
POWER_UP: ELECTRIC_SHIELD
  
  protection: Absorbs one hit, immune to electric hazards
  duration: Until hit OR water contact (destroyed by water)
  
  ability: RING_MAGNET
    passive: Attracts nearby rings (radius 10 units)
    
  ability: DOUBLE_JUMP_ENHANCED
    input: Jump while airborne
    effect: Double jump with electric burst
    damage: Shocks nearby enemies
    
  appearance: Electric sparks orbiting player
```

### 9.1.5 Wind Shield

```
POWER_UP: WIND_SHIELD
  
  protection: Absorbs one hit
  duration: Until hit
  
  ability: AIR_DASH
    input: Jump while airborne
    effect: Quick dash in input direction
    distance: 6 units
    cooldown: 0.5 seconds
    
  ability: GLIDE
    input: Hold jump while falling
    effect: Slow descent, horizontal movement
    
  appearance: Swirling wind currents around player
```

## 9.2 Temporary Power-Ups

### 9.2.1 Invincibility

```
POWER_UP: INVINCIBILITY
  
  effect: Cannot be damaged by any source
  duration: 15 seconds
  
  additional:
    - Damages enemies on contact
    - Music changes to invincibility theme
    - Cannot protect from pits/crushing
    
  appearance: Flashing rainbow colors, sparkle trail
```

### 9.2.2 Speed Shoes

```
POWER_UP: SPEED_SHOES
  
  effect: Increased max speed and acceleration
  duration: 15 seconds
  
  parameters:
    speed_multiplier: 1.5x
    acceleration_multiplier: 1.3x
    
  appearance: Speed lines always visible, slight motion blur
  audio: Faster music tempo
```

## 9.3 Item Boxes

```
ITEM_BOX_SYSTEM:
  
  appearance: Floating cubic containers with icon
  
  activation: 
    - Spin jump from below
    - Roll/spin attack from side
    - Homing attack
    
  contents:
    RING_BOX: +10 rings
    SHIELD_BOX: Grants basic shield
    FLAME_BOX: Grants flame shield
    AQUA_BOX: Grants aqua shield
    ELECTRIC_BOX: Grants electric shield
    WIND_BOX: Grants wind shield
    INVINCIBILITY_BOX: Grants invincibility
    SPEED_BOX: Grants speed shoes
    1UP_BOX: [REMOVED - no lives system]
    RANDOM_BOX: Random power-up
    
  respawn: Does not respawn in same playthrough
```

---

# 10. ENEMY SYSTEM

## 10.1 Enemy Design Philosophy

```
ENEMY_DESIGN_PRINCIPLES:
  
  1. READABLE: Player should understand threat at a glance
  2. FAIR: All attacks should be avoidable with skill
  3. VARIED: Different enemies require different approaches
  4. REWARDING: Defeating enemies feels satisfying
  5. THEMATIC: Enemies fit the digital/VR aesthetic
```

## 10.2 Standard Enemy Types

### 10.2.1 Patrol Enemies

```
ENEMY_CLASS: PATROL
  
  behavior: Walks back and forth on platform
  threat: Contact damage
  defeat: Any attack
  
  VARIANTS:
  
    BIT_WALKER:
      appearance: Small cubic robot with legs
      speed: Slow
      health: 1 hit
      score: 100
      
    DATA_CRAWLER:
      appearance: Centipede-like data stream
      speed: Medium
      health: 1 hit (but segments)
      score: 50 per segment
      
    PIXEL_GUARD:
      appearance: Pixelated soldier
      speed: Medium
      health: 2 hits
      score: 200
```

### 10.2.2 Projectile Enemies

```
ENEMY_CLASS: PROJECTILE
  
  behavior: Stationary or slow, fires projectiles
  threat: Projectiles and contact
  defeat: Attack between shots
  
  VARIANTS:
  
    BYTE_TURRET:
      appearance: Mounted gun turret
      projectile: Energy ball, straight line
      fire_rate: Every 2 seconds
      health: 1 hit
      score: 150
      
    VIRUS_SPITTER:
      appearance: Organic-looking corrupted data
      projectile: Arcing glob, spreads on impact
      fire_rate: Every 3 seconds
      health: 2 hits
      score: 250
      
    HOLO_SNIPER:
      appearance: Floating eye with laser
      projectile: Laser beam, tracks briefly
      fire_rate: Every 4 seconds
      health: 1 hit
      score: 300
      warning: Laser sight shows before firing
```

### 10.2.3 Flying Enemies

```
ENEMY_CLASS: FLYING
  
  behavior: Airborne movement patterns
  threat: Dive attacks, projectiles, contact
  defeat: Homing attack, jump timing
  
  VARIANTS:
  
    DATA_BAT:
      appearance: Bat made of flowing code
      pattern: Swooping dive attacks
      health: 1 hit
      score: 150
      
    PIXEL_DRONE:
      appearance: Quadcopter drone
      pattern: Hovers, drops bombs
      health: 1 hit
      score: 200
      
    FIREWALL_WASP:
      appearance: Geometric wasp
      pattern: Chase player, explode on contact
      health: 1 hit (but avoidance preferred)
      score: 100
      warning: Beeping increases before explosion
```

### 10.2.4 Armored Enemies

```
ENEMY_CLASS: ARMORED
  
  behavior: Protected from certain attacks
  threat: Contact, special attacks
  defeat: Specific method required
  
  VARIANTS:
  
    SHELL_BYTE:
      appearance: Turtle-like robot
      armor: Top protected, sides vulnerable
      health: 1 hit on weak point
      score: 250
      strategy: Attack from side or flip with stomp
      
    SPIKE_CUBE:
      appearance: Cube with extending spikes
      armor: Spikes out = invulnerable
      health: 2 hits
      score: 300
      strategy: Wait for spike retraction
      
    MIRROR_DRONE:
      appearance: Reflective surface drone
      armor: Reflects projectiles, homing attacks
      health: 1 hit from behind
      score: 350
      strategy: Get behind or use environment
```

### 10.2.5 Elite Enemies

```
ENEMY_CLASS: ELITE
  
  behavior: Mini-boss level threats
  threat: Multiple attack types
  defeat: Pattern recognition required
  
  VARIANTS:
  
    ADMIN_UNIT:
      appearance: Humanoid authority figure
      attacks: [melee_combo, projectile_burst, summon_minions]
      health: 5 hits
      score: 1000
      placement: Guards important areas
      
    CORRUPTED_GUARDIAN:
      appearance: Large glitched creature
      attacks: [ground_slam, laser_sweep, charge]
      health: 8 hits
      score: 1500
      placement: Mid-level challenges
```

## 10.3 Enemy Behavior Parameters

```
ENEMY_AI_CONFIG:
  
  DETECTION:
    sight_range: 15 units (default)
    sight_cone: 90 degrees (default)
    hearing_range: 8 units
    
  REACTIONS:
    detection_delay: 0.2 seconds
    attack_telegraph: 0.3-0.5 seconds
    recovery_time: 0.5-1.0 seconds
    
  DIFFICULTY_SCALING:
    easy_mode:
      health_modifier: 0.75x
      damage_modifier: 0.75x
      speed_modifier: 0.9x
      
    normal_mode:
      health_modifier: 1.0x
      damage_modifier: 1.0x
      speed_modifier: 1.0x
      
    hard_mode:
      health_modifier: 1.25x
      damage_modifier: 1.25x
      speed_modifier: 1.1x
```

---

# 11. HAZARD SYSTEM

## 11.1 Environmental Hazards

```
HAZARD_TYPES:

  SPIKES:
    damage: Instant (regardless of rings)
    visual: Clearly marked spike formations
    placement: Pits, walls, ceilings
    note: Some can retract on timers
    
  PITS:
    damage: Death (regardless of rings)
    visual: Bottomless or very deep drops
    safety: Some have safety nets below
    
  CRUSHING:
    damage: Death (regardless of rings)
    visual: Moving platforms, walls
    warning: Telegraph movement
    timing: Predictable patterns
    
  FIRE:
    damage: Ring loss
    protection: Flame shield immune
    types: [flames, lava_surface, fire_jets]
    
  ELECTRICITY:
    damage: Ring loss
    protection: Electric shield immune
    types: [electric_floors, tesla_coils, live_wires]
    
  WATER:
    damage: Drowning (30 second timer)
    protection: Aqua shield (no timer)
    air_bubbles: Reset timer
    
  SLIPPERY:
    damage: None
    effect: Reduced friction, no wall climbing
    types: [ice, oil, slime]
    
  WIND:
    damage: None
    effect: Pushes player
    types: [fans, gusts, updrafts]
```

## 11.2 Hazard Visual Language

```
HAZARD_COMMUNICATION:
  
  principles:
    - All hazards must be visible before they can hurt player
    - Instant-death hazards should be VERY obvious
    - Moving hazards need clear tells
    - Sound cues supplement visual cues
    
  color_coding:
    red: Danger, damaging
    yellow: Caution, moving hazard
    blue: Water, can be safe or hazardous
    purple: Corrupted/glitched areas
    
  warning_signs:
    spikes: Pointed shapes, metallic sheen
    pits: Dark emptiness, no visible floor
    crushing: Industrial look, moving parts
    fire: Orange glow, flickering
    electricity: Blue sparks, humming sound
```

---

# 12. SCORING SYSTEM

## 12.1 Score Sources

```
SCORING:

  ENEMIES:
    basic_enemy: 100-300 points
    elite_enemy: 1000-1500 points
    boss: 10000-50000 points
    
  COLLECTIBLES:
    ring: 10 points each
    super_ring: 100 points
    secret_item: 500 points
    
  ACTIONS:
    enemy_chain: +100 per enemy in chain
    homing_chain: +50 per target
    trick: 100-1000 based on complexity
    
  BONUSES:
    level_clear: 1000 points
    ring_bonus: rings × 10
    time_bonus: max(0, (par_time - actual_time) × 100)
    secret_bonus: 1000 per secret found
    no_damage_bonus: 5000 points
```

## 12.2 Ranking System

```
RANK_THRESHOLDS:
  
  S_RANK:
    score: 90% of maximum possible
    time: Under S-rank par time
    rings: 80% of level rings
    secrets: All found
    
  A_RANK:
    score: 75% of maximum possible
    time: Under A-rank par time
    rings: 60% of level rings
    
  B_RANK:
    score: 50% of maximum possible
    time: Under B-rank par time
    rings: 40% of level rings
    
  C_RANK:
    score: 25% of maximum possible
    time: Under C-rank par time
    
  D_RANK:
    score: Below C requirements
    
  REWARDS:
    S_RANK: Medallion + Character unlock progress
    A_RANK: Medallion
    B_RANK: Standard completion
    C_RANK: Standard completion
    D_RANK: Standard completion
```

---

# 13. CHECKPOINT SYSTEM

## 13.1 Checkpoint Mechanics

```
CHECKPOINT_SYSTEM:
  
  description: "Progress save points within levels"
  
  ACTIVATION:
    trigger: Pass through checkpoint post
    visual: Post lights up, spins
    audio: Checkpoint sound effect
    
  ON_DEATH:
    respawn: Last activated checkpoint
    rings_retained: 0 (start fresh)
    power_ups_retained: None
    enemies_reset: Yes
    collectibles_retained: Yes (already collected stay collected)
    time_retained: Continues from checkpoint moment
    
  CHECKPOINT_TYPES:
    standard: Basic respawn point
    ring_gate: Requires 20+ rings for bonus stage access
    
  CHECKPOINT_DATA_SAVED:
    - Position
    - Camera orientation
    - Time elapsed
    - Score
    - Collectibles obtained
```

## 13.2 Bonus Stage Access

```
CHECKPOINT_BONUS_ACCESS:
  
  requirement: Pass checkpoint with 20+ rings (or multiple of 20)
  
  trigger:
    visual: Stars appear above checkpoint
    prompt: "Press [button] to enter bonus stage"
    
  entering:
    - Player transported to Pool Bonus Stage
    - Level progress paused
    - Returns to checkpoint on exit
    
  rewards:
    per_section: 1 Medallion
    full_clear: 100 rings + Medallion
    
  limitation:
    - Each checkpoint can only be used once per playthrough
    - Re-entering level allows re-access
```

---

**END OF PART 2**

*Next: Part 3 - 2D Sections & Boss Encounters*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 3: 2D Sections & Boss Encounters

---

# 14. 2D LEVEL SECTIONS

## 14.1 2D Section Overview

2D sections are integrated segments within 3D levels where gameplay shifts to a side-scrolling perspective while maintaining all core abilities and mechanics.

```
2D_SECTION_PHILOSOPHY:
  
  purpose:
    - Provide gameplay variety within levels
    - Enable Classic Sonic-style platforming
    - Showcase different level design approaches
    - Create memorable set-pieces
    
  integration:
    - Seamlessly woven into 3D levels
    - Same character, same abilities
    - Uses explicit transition points (doors, pipes)
    - Can last from 30 seconds to several minutes
```

## 14.2 Transition System

### 14.2.1 Transition Types

```
TRANSITION_METHODS:

  DOOR_TRANSITION:
    trigger: Player enters marked doorway
    animation:
      1. Screen dims slightly
      2. Door opening animation
      3. Player runs through
      4. Screen transitions (fade/wipe)
      5. Player emerges in new perspective
    duration: 1.5 seconds total
    reversible: Yes (return door exists)
    
  PIPE_TRANSITION:
    trigger: Player enters pipe entrance
    animation:
      1. Player pulled into pipe
      2. Pipe travel sequence (brief)
      3. Player ejected into new area
    duration: 2.0 seconds total
    reversible: Sometimes (one-way pipes exist)
    
  WARP_RING_TRANSITION:
    trigger: Player enters giant ring
    animation:
      1. Ring glow intensifies
      2. Player pulled in with spiral effect
      3. Flash transition
      4. Player appears in new area
    duration: 1.0 seconds total
    reversible: Usually one-way
```

### 14.2.2 Transition Zones

```
TRANSITION_ZONE_SETUP:

  3D_SIDE:
    zone_type: Area3D trigger
    visual_marker: Glowing doorframe/pipe entrance
    approach_any_angle: true
    auto_align_player: true (faces transition)
    
  2D_SIDE:
    zone_type: Area3D trigger (thin, perpendicular to 2D plane)
    visual_marker: Exit door/pipe
    auto_align_player: true (faces 2D direction)
    
  DATA_TRANSFERRED:
    - Player velocity (converted to 2D)
    - Ring count
    - Power-up status
    - Boost meter
    - Score
```

## 14.3 2D Camera System

### 14.3.1 Camera Configuration

```
2D_CAMERA:

  perspective: Orthographic or slight perspective (2.5D)
  
  position:
    distance: Fixed distance from 2D plane
    height: Follows player with slight lag
    horizontal: Leads player slightly in movement direction
    
  curved_world_effect:
    enabled: true
    variation: "Vertical curve" - level bends DOWNWARD
    intensity: 0.1 (subtler than 3D sections)
    
  boundaries:
    vertical: Soft limits with camera push
    horizontal: Level bounds
    
  zoom:
    default: Shows ~20 units of vertical space
    dynamic: Zooms out slightly at high speeds
```

### 14.3.2 Camera Behavior

```
2D_CAMERA_BEHAVIOR:

  FOLLOWING:
    horizontal_lead: 3 units ahead of player
    vertical_center: Player at 40% from bottom
    smoothing: 5.0 (lerp factor)
    
  SPEED_RESPONSE:
    high_speed_zoom: Zoom out 10% above speed 15
    vertical_expansion: Shows more above/below at high speed
    
  BOUNDARIES:
    left_bound: Cannot scroll left of level start
    right_bound: Cannot scroll right of level end
    vertical_bounds: Defined per section
    
  SPECIAL_CASES:
    boss_areas: Lock camera to arena
    set_pieces: Camera may pan to show objective
    secrets: Brief pan to reveal hidden area
```

## 14.4 2D Movement Adaptations

### 14.4.1 Movement Translation

```
2D_MOVEMENT_MAPPING:

  GROUND_MOVEMENT:
    input: Left/Right only (up/down for looking)
    physics: Identical to 3D ground physics
    slopes: Full slope physics preserved
    
  AERIAL:
    input: Left/Right air control
    physics: Identical to 3D
    
  ABILITIES_PRESERVED:
    - Spin Jump ✓
    - Spin Dash ✓
    - Homing Attack ✓ (2D targeting)
    - Bounce Attack ✓
    - Stomp Attack ✓
    - Wall Climb ✓
    - Wall Run ✓
    - Wall Jump ✓
    - Tongue Grapple ✓ (2D plane only)
    - Boost ✓
    
  HOMING_ATTACK_2D:
    targeting: Only targets in 2D plane
    visual: Reticle appears on screen
    behavior: Dashes along 2D plane to target
```

### 14.4.2 2D-Specific Considerations

```
2D_DESIGN_CONSIDERATIONS:

  DEPTH_ELEMENTS:
    background_layers: Parallax scrolling (visual only)
    foreground_elements: Can obscure view briefly
    z_depth_gameplay: None (strictly 2D plane)
    
  VISUAL_CUES:
    player_highlight: Slight glow to stand out
    interactables: Clear visual distinction
    paths: Obvious platforming routes
    
  LEVEL_DESIGN:
    loop_de_loops: Classic Sonic-style loops
    corkscrews: Spiral paths
    springs: Bouncy objects
    speed_boosters: Directional speed pads
    
  CLASSIC_ELEMENTS:
    - Half-pipes
    - S-tubes
    - Spiral runs
    - Pinball sections (within 2D)
    - Vertical shafts
```

## 14.5 2D Level Design Guidelines

```
2D_LEVEL_DESIGN:

  STRUCTURE:
    minimum_length: 30 seconds at normal pace
    maximum_length: 5 minutes at normal pace
    typical_length: 1-2 minutes
    
  PATH_DESIGN:
    multiple_routes: Minimum 2, ideally 3
    top_route: Fastest, requires skill
    middle_route: Balanced
    bottom_route: Safer, slower
    
  RHYTHM:
    speed_sections: Maintain momentum
    platforming_sections: Precise jumps
    combat_sections: Enemy encounters
    breathing_room: Brief safe areas
    
  SECRETS:
    hidden_paths: Breakable walls, hidden springs
    reward_rooms: Contains rings, power-ups
    super_rings: Reward exploration
    
  ENEMY_PLACEMENT:
    purpose: Obstacle or reward (bounce chains)
    spacing: Allow reaction time
    variety: Mix enemy types
```

---

# 15. BOSS ENCOUNTERS

## 15.1 Boss Design Philosophy

```
BOSS_DESIGN_PHILOSOPHY:

  CORE_PRINCIPLES:
    1. READABILITY: Attacks clearly telegraphed
    2. FAIRNESS: All attacks avoidable with skill
    3. ESCALATION: Difficulty increases through phases
    4. SATISFACTION: Victory feels earned
    5. VARIETY: Each boss offers unique challenge
    
  STRUCTURE:
    phases: 3 per boss (standard)
    health_per_phase: Varies by boss
    recovery_time: Brief invincibility between phases
    
  DIFFICULTY_CURVE:
    zone_1_bosses: Teach boss mechanics
    mid_game_bosses: Test learned skills
    late_game_bosses: Challenge mastery
    final_boss: Ultimate test
```

## 15.2 Boss Camera System

### 15.2.1 Dynamic Boss Camera

```
BOSS_CAMERA:

  type: Dynamic third-person
  curved_world: DISABLED
  
  POSITIONING:
    default: Behind and above player
    distance: 15-25 units (varies by arena)
    height: 5-10 units above player
    
  TRACKING:
    primary_target: Player
    secondary_target: Boss (keeps in frame when possible)
    blend: 70% player, 30% boss
    
  BEHAVIOR:
    player_focused: Centers on player
    action_focused: Pulls back for big attacks
    cinematic: Brief locks for boss actions
    
  TRANSITIONS:
    phase_change: Camera may reposition
    special_attacks: Camera may zoom/pan
    victory: Cinematic angle
```

### 15.2.2 Arena Boundaries

```
BOSS_ARENA:

  BOUNDARY_TYPES:
    invisible_walls: Gentle pushback
    visual_walls: Clear barriers (energy walls, etc.)
    environmental: Pits, hazards at edges
    
  ARENA_SHAPES:
    circular: Most common for rival fights
    rectangular: Platform-based arenas
    irregular: Colossus fights
    multi_level: Arenas with height variation
    
  ARENA_SIZES:
    rival_boss: 30x30 units typical
    monster_boss: 50x50 units or larger
    colossus_boss: 100x100+ units with verticality
```

## 15.3 Rival Boss Encounters

### 15.3.1 Rival Boss Framework

```
RIVAL_BOSS_FRAMEWORK:

  SHARED_TRAITS:
    size: Player-scale (similar hitbox)
    mobility: High (can match player movement)
    intelligence: Reactive to player actions
    
  COMBAT_LOOP:
    1. Boss attacks with telegraphed move
    2. Player dodges/avoids
    3. Boss has recovery window
    4. Player attacks during window
    5. Repeat with increasing complexity
    
  PHASE_PROGRESSION:
    phase_1: Basic attacks, long windows
    phase_2: New attacks, shorter windows
    phase_3: Combined attacks, minimal windows
    
  HEALTH_SYSTEM:
    health_bar: Visible UI element
    damage_per_hit: 1 unit (8-12 hits per phase typical)
    total_health: 24-36 hits typical
```

### 15.3.2 Rival Boss: Commander Nexus

```
BOSS: COMMANDER_NEXUS

  ENCOUNTER_1 (Zone 3):
    arena: Geometric platform arena
    total_health: 24 (8 per phase)
    
    phase_1_attacks:
      - GRID_PROJECTILE: Fires geometric shapes in patterns
        telegraph: 0.5s charge glow
        dodge: Jump or move between projectiles
        window: 2s recovery after burst
        
      - DASH_SLICE: Quick dash with energy blade
        telegraph: Brief crouch, blade glow
        dodge: Jump over
        window: 1s recovery at end
        
    phase_2_additions:
      - BARRIER_SUMMON: Creates temporary barriers
        effect: Restricts movement temporarily
        counter: Destroy barriers or wait
        
      - COMBO_ATTACK: Dash into projectile burst
        telegraph: Combined tells
        dodge: Requires jump then air dodge
        
    phase_3_additions:
      - GRID_TRAP: Floor hazard zones
        telegraph: Floor glows before activation
        dodge: Stay in safe zones
        
      - DESPERATION: Faster attack speed
        
  ENCOUNTER_2 (Zone 8):
    additions:
      - Adapts to player patterns
      - Uses arena hazards
      - New combo strings
    total_health: 30
    
  ENCOUNTER_3 (Zone 14):
    additions:
      - Clones self briefly
      - Ultimate attack (large arena wipe)
      - Minimal recovery windows
    total_health: 36
```

### 15.3.3 Rival Boss: Surge

```
BOSS: SURGE

  ENCOUNTER_1 (Zone 4):
    arena: Racing track style arena with loops
    total_health: 24 (8 per phase)
    gimmick: Must chase/race while fighting
    
    phase_1_attacks:
      - SPEED_DASH: Lightning-fast charge
        telegraph: Electricity crackle, pose
        dodge: Time a jump
        window: Taunts after missing
        
      - LIGHTNING_TRAIL: Leaves damaging trail
        telegraph: Visible charge-up
        avoid: Don't follow directly behind
        
    phase_2_additions:
      - THUNDER_SLAM: Leaps and creates shockwave
        telegraph: Jump wind-up
        dodge: Jump over shockwave
        
      - SPEED_STEAL: Temporarily slows player
        effect: 50% speed for 3 seconds
        counter: Land hits to break effect
        
    phase_3_additions:
      - LIGHTNING_CAGE: Traps player in small area
        escape: Must damage Surge
        
  ENCOUNTER_2 (Zone 9):
    gimmick: Both running at high speed throughout
    additions:
      - Environmental hazards while chasing
      - Split paths in arena
    total_health: 30
    
  ENCOUNTER_3 (Zone 15):
    gimmick: Multi-stage chase across arena
    additions:
      - Must catch up to damage
      - Ultimate speed mode
    total_health: 36
```

## 15.4 Colossus Boss Encounters

### 15.4.1 Colossus Framework

```
COLOSSUS_BOSS_FRAMEWORK:

  SHARED_TRAITS:
    size: 10-50x player size
    mobility: Slow but powerful
    weak_points: Must be reached and attacked
    
  CLIMBING_MECHANICS:
    grip_points: Glowing areas on boss body
    stamina: Wall climb stamina applies
    shaking: Boss tries to shake player off
    
  COMBAT_LOOP:
    1. Avoid boss attacks from ground
    2. Find/create opportunity to climb
    3. Navigate boss body to weak point
    4. Attack weak point
    5. Get knocked off, repeat
    
  PHASE_PROGRESSION:
    phase_1: One weak point, easy access
    phase_2: Weak point moves/protected
    phase_3: Multiple stages to reach weak point
```

### 15.4.2 Colossus Boss: Titanica

```
BOSS: TITANICA

  ENCOUNTER_1 (Zone 6):
    arena: Industrial area with platforms
    boss_height: 20 units tall
    total_health: 24 (8 per phase)
    
    phase_1:
      weak_point: Glowing core on chest
      access: Climb from leg grip points
      
      attacks_while_climbing:
        - ARM_SWIPE: Sweeps arm across body
          telegraph: Arm pulls back
          avoid: Move to other side
          
      attacks_from_ground:
        - GROUND_POUND: Fist slam creates shockwave
          telegraph: Raises fist
          dodge: Jump over shockwave
          opportunity: Arm stays down briefly (climb point)
          
        - STOMP: Foot slam at player
          telegraph: Leg raises
          dodge: Move away from shadow
          
    phase_2:
      weak_point: Moves to back
      access: Must climb all the way up and over
      
      new_attacks:
        - BACK_JETS: Fire from back periodically
          avoid: Watch for glow, move away
          
        - SPIN: Slow rotation
          effect: Must keep up while climbing
          
    phase_3:
      weak_point: Inside head (opens periodically)
      access: Reach head, wait for opening
      
      new_attacks:
        - LASER_SWEEP: Head laser sweeps arena
          telegraph: Targeting laser
          dodge: Jump or find cover
          
        - RAGE_MODE: Increased attack speed
```

## 15.5 Monster Boss Encounters

### 15.5.1 Zone Monster Bosses

```
MONSTER_BOSS_FRAMEWORK:

  description: Large creatures that aren't climbed
  
  SHARED_TRAITS:
    size: 3-10x player size
    mobility: Varied
    attack_patterns: Learnable sequences
    
  COMBAT_LOOP:
    1. Learn boss attack pattern
    2. Find windows between attacks
    3. Attack vulnerable areas
    4. Adapt to phase changes
```

### 15.5.2 Example Zone Bosses

```
ZONE_BOSS_EXAMPLES:

  TROPICAL_ZONE_BOSS: "CORRUPTED_TIKI"
    type: Animated statue monster
    size: 5x player
    arena: Circular temple arena
    
    attacks:
      - Face laser beams (rotate around arena)
      - Ground pound (area denial)
      - Summon minion totems
      
    strategy: Destroy totems to stun, attack face
    phases: Adds more totems and lasers
    
  SNOW_ZONE_BOSS: "BLIZZARD_BEAST"
    type: Ice elemental creature
    size: 8x player
    arena: Frozen lake with platforms
    
    attacks:
      - Ice breath (freezes ground)
      - Icicle rain (area hazards)
      - Body slam (breaks ice platforms)
      
    strategy: Use fire shield or heat vents
    phases: Arena shrinks as ice breaks
    
  FIRE_ZONE_BOSS: "MAGMA_WYRM"
    type: Lava serpent
    size: 10x player (long body)
    arena: Volcanic crater with rock platforms
    
    attacks:
      - Lava spray (area denial)
      - Dive attack (travels through lava)
      - Tail swipe (platform destruction)
      
    strategy: Attack head when surfacing
    phases: Lava rises, fewer platforms
```

## 15.6 Final Boss: Director Vex

```
BOSS: DIRECTOR_VEX

  ENCOUNTER_1 (Zone 12 - Mid-Game):
    context: Confrontation, Vex escapes
    type: Chase sequence with brief fight
    health: 12 (defeated triggers escape cutscene)
    purpose: Establish Vex as threatening
    
  ENCOUNTER_2 (Zone 18 - Final):
    arena: Syndicate Core - massive digital space
    
    PHASE_1: "THE EXECUTIVE"
      form: Human-like avatar in suit of armor
      health: 24
      
      attacks:
        - BOARDROOM_BARRAGE: Summons holographic weapons
        - HOSTILE_TAKEOVER: Traps in contract barriers
        - DOWNSIZING: Summons minion drones
        
      strategy: Standard rival boss tactics
      
    PHASE_2: "THE SYSTEM"
      form: Merges with arena, becomes environment
      health: 32 (distributed across nodes)
      
      attacks:
        - NODE_LASERS: Arena turrets fire patterns
        - FIREWALL: Moving barrier walls
        - SYSTEM_CRASH: Temporary blindness/glitches
        
      strategy: Destroy power nodes around arena
      
    PHASE_3: "THE GOD"
      form: Giant digital deity form
      health: 24
      
      attacks:
        - DELETION_BEAM: Massive laser sweep
        - REALITY_TEAR: Arena warps temporarily
        - ADMIN_OVERRIDE: Disables player ability briefly
        
      strategy: Climb to reach weak points (colossus style)
      
    PHASE_4: "COSMIC CONFRONTATION"
      requirement: All 8 Cosmic Crystals collected
      player_state: Cosmic Mode Gina
      form: Vex absorbs remaining power
      
      attacks:
        - All previous attacks, empowered
        - NEW: Cannot be dodged, must be tanked
        
      strategy: Overwhelming offense with Cosmic power
      duration: Cosmic Mode provides enough time
      
    ALTERNATE (No Crystals):
      phase_3_ends_game: True ending locked
      ending: "Good" ending, threat contained but not eliminated
```

## 15.7 Boss Rewards

```
BOSS_REWARDS:

  ON_DEFEAT:
    score: 10000-50000 based on boss
    rings: 50 rings drop
    boost_meter: Filled to 100%
    
  PROGRESSION:
    zone_unlock: Next zone becomes accessible
    character_unlock: Progress toward MP character
    story_advancement: Cutscene/dialogue
    
  OPTIONAL_CHALLENGES:
    no_damage: Medallion reward
    speed_kill: Bonus score
    style_kill: Bonus XP
```

---

# 16. LEVEL STRUCTURE INTEGRATION

## 16.1 Standard Level Flow

```
STANDARD_LEVEL_STRUCTURE:

  OPENING:
    - Player spawns at level start
    - Brief area to get bearings
    - First enemies introduce zone threats
    
  ACT_1 (3D):
    - Main 3D platforming section
    - Multiple paths established
    - Checkpoint 1 at ~25% mark
    
  TRANSITION_TO_2D:
    - Door/Pipe transition
    - Visual change to side-scroller
    
  ACT_2 (2D):
    - Side-scrolling section
    - Classic platforming challenges
    - Checkpoint 2 at ~50% mark
    
  TRANSITION_TO_3D:
    - Return to 3D perspective
    
  ACT_3 (3D):
    - Climax section
    - Increased challenge
    - Checkpoint 3 at ~75% mark
    - Paths converge toward end
    
  FINALE:
    - Final challenge/set-piece
    - Goal marker
    - Results screen
```

## 16.2 Boss Level Structure

```
BOSS_LEVEL_STRUCTURE:

  APPROACH:
    - Short platforming section
    - Sets up arena visually
    - Checkpoint before boss
    
  BOSS_TRANSITION:
    - Cutscene/dialogue trigger
    - Camera transitions to boss cam
    - Arena boundaries activate
    
  BOSS_FIGHT:
    - Full boss encounter
    - No mid-fight checkpoints
    - Death restarts entire boss
    
  VICTORY:
    - Boss defeat cutscene
    - Rewards given
    - Exit opens
    - Level complete
```

## 16.3 Fortress/Castle Level Structure

```
FORTRESS_LEVEL_STRUCTURE:

  description: Mid-zone levels with mini-bosses
  
  STRUCTURE:
    - Longer than standard levels
    - Multiple 2D/3D transitions
    - Environmental hazards themed to zone
    - Mid-boss encounter (not full rival)
    - Ends with zone story beat
    
  MID_BOSS:
    - Elite enemy or unique mini-boss
    - 1 phase, 8-12 hits
    - Teaches mechanics for zone final boss
```

---

**END OF PART 3**

*Next: Part 4 - Alternative Gameplay Modes (Flying)*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 4: Alternative Gameplay Modes (Flying)

---

# 19. FLYING LEVELS

## 19.1 Flying Overview

Flying levels serve as transitions between zones, featuring **Star Fox-style** on-rails shooting gameplay with a boss encounter at the end.

```
FLYING_PHILOSOPHY:

  reference_games: "Star Fox 64, Space Harrier"
  gameplay_type: On-rails shooter
  perspective: Behind-vehicle third-person
  
  integration:
    - One flying level between each zone
    - Story context: Stolen Syndicate aircraft
    - Shorter than other level types (1-2 minutes)
    - Boss at end of each flying level
```

## 19.2 Flying Controls

```
FLYING_CONTROLS:

  MOVEMENT:
    left_stick / WASD:
      - Full 8-directional movement
      - Ship moves within screen bounds
      - Does NOT change camera direction (on-rails)
      
  SHOOTING:
    button_south / SPACE:
      - Tap: Single shot
      - Hold: Charge shot (release to fire)
      
  SPECIAL_WEAPONS:
    button_north / Q:
      - Fire bomb/special weapon
      - Limited ammo (3 default)
      
  EVASION:
    button_west / SHIFT:
      - Barrel roll left
      - Brief invincibility
      
    button_east / E:
      - Barrel roll right
      - Brief invincibility
      
    left_trigger + direction:
      - Quick dodge in direction
      - Faster than normal movement
```

## 19.3 Flying Mechanics

### 19.3.1 On-Rails Movement

```
ON_RAILS_SYSTEM:

  CAMERA_PATH:
    movement: Automatic along predetermined path
    speed: Variable (level-scripted)
    player_control: None (camera moves automatically)
    
  PLAYER_BOUNDS:
    horizontal: Screen width (can't leave view)
    vertical: Screen height (can't leave view)
    depth: Fixed distance from camera
    
  MOVEMENT_FEEL:
    responsiveness: Immediate
    momentum: Slight (smooths movement)
    speed: Fast enough to dodge, not twitchy
```

### 19.3.2 Shooting System

```
SHOOTING_MECHANICS:

  STANDARD_SHOT:
    type: Energy projectile
    damage: 1 unit
    fire_rate: 5 shots/second (tap)
    auto_fire: Hold button for continuous
    spread: Single forward shot
    
  CHARGE_SHOT:
    charge_time: 1.5 seconds for full charge
    damage: 5 units (full charge)
    effect: Passes through weak enemies
    lock_on: Targets nearest enemy
    visual: Glowing charge effect
    
  TARGETING:
    standard_shot: Free aim (hits where cursor/center)
    charge_shot: Lock-on to nearest enemy
    lock_on_range: 50 units
    lock_on_indicator: Reticle appears on target
    
  BOMB:
    ammo: 3 per level (can find more)
    damage: 10 units, area effect
    radius: Large (clears screen section)
    use: Emergency clear, boss damage
```

### 19.3.3 Upgrade System

```
FLYING_UPGRADES:

  UPGRADE_TYPES:
  
    WEAPON_POWER_UP:
      effect: Increases shot damage
      levels: 1 → 2 → 3 (max)
      visual: Shot color/size changes
      
    SPREAD_SHOT:
      effect: Fires 3 shots in spread
      duration: Until hit
      downgrade: Loses on damage
      
    AUTO_FIRE:
      effect: Continuous fire without holding
      duration: 30 seconds
      
    SHIELD:
      effect: Absorbs one hit
      duration: Until hit
      visual: Barrier around ship
      
    BOMB_REFILL:
      effect: +1 bomb
      max: 9 bombs
      
  UPGRADE_PICKUP:
    appearance: Floating power-up icons
    collection: Fly through
    placement: Reward for defeating enemies, exploration
    
  PERSISTENCE:
    within_level: Upgrades last until lost
    between_levels: Upgrades reset (fresh start)
```

### 19.3.4 Health System (Flying)

```
FLYING_HEALTH:

  RING_SYSTEM:
    rings_in_flying: Yes
    collection: Fly through
    function: Same as main game
    
  DAMAGE:
    enemy_projectile: -10 rings
    enemy_collision: -20 rings
    obstacle_collision: -15 rings
    boss_attack: -20-30 rings
    
  NO_RINGS:
    first_hit: Warning (ship damaged visually)
    second_hit: Ship destroyed, respawn
    
  RESPAWN:
    location: Nearest checkpoint (mid-level)
    rings: Start with 10
    upgrades: Lost
    
  SHIELD_PROTECTION:
    effect: Absorbs one hit completely
    acquisition: Shield power-up
```

## 19.4 Flying Level Design

### 19.4.1 Level Structure

```
FLYING_LEVEL_STRUCTURE:

  LENGTH: 1.5-2 minutes typical
  
  SEGMENTS:
  
    TAKEOFF_ZONE:
      duration: 10 seconds
      purpose: Establish setting
      enemies: Few, tutorial
      
    APPROACH_ZONE:
      duration: 30-45 seconds
      purpose: Main gameplay
      enemies: Waves and formations
      obstacles: Environmental hazards
      
    CHECKPOINT:
      trigger: Automatic mid-level
      effect: Save progress
      
    GAUNTLET_ZONE:
      duration: 30-45 seconds
      purpose: Increased challenge
      enemies: Dense formations
      mini_boss: Sometimes
      
    BOSS_APPROACH:
      duration: 15 seconds
      purpose: Brief respite, setup
      enemies: Few
      
    BOSS_FIGHT:
      duration: 30-60 seconds
      type: Flying boss or all-range mode
      details: See Boss Section
```

### 19.4.2 Enemy Types

```
FLYING_ENEMIES:

  DRONE_SWARM:
    description: Small weak enemies in formation
    health: 1 shot
    attack: Collision only
    behavior: Fly in patterns
    score: 50 each
    
  FIGHTER:
    description: Enemy aircraft
    health: 2 shots
    attack: Shoots at player
    behavior: Fly-by attacks
    score: 200
    
  BOMBER:
    description: Slow, heavy enemy
    health: 5 shots
    attack: Drops bombs below
    behavior: Flies across screen
    score: 500
    
  TURRET:
    description: Stationary gun
    health: 3 shots
    attack: Aimed shots
    behavior: Fixed position (on structure)
    score: 300
    
  ELITE:
    description: Dangerous single enemy
    health: 8 shots
    attack: Rapid fire, missiles
    behavior: Pursues player
    score: 1000
```

### 19.4.3 Environmental Elements

```
FLYING_ENVIRONMENT:

  OBSTACLE_TYPES:
  
    ASTEROIDS:
      damage: 15 rings
      destruction: Can shoot (1 shot)
      
    STRUCTURES:
      damage: 20 rings
      destruction: Cannot destroy
      
    DEBRIS:
      damage: 10 rings
      destruction: Can shoot
      
    ENERGY_BARRIERS:
      damage: 25 rings
      destruction: Some have weak points
      
  HAZARD_ZONES:
    asteroid_field: Dense obstacles
    canyon_run: Tight navigation
    station_interior: Close quarters
    
  RING_PLACEMENT:
    safe_paths: Lines of rings
    challenge_paths: Rings in dangerous areas
    bonus_areas: Ring clusters off main path
```

## 19.5 Flying Boss Encounters

### 19.5.1 On-Rails Bosses

```
ON_RAILS_BOSS:

  description: Boss fought while still on rails
  
  STRUCTURE:
    position: Boss in front of camera
    movement: Boss moves around screen
    player: Normal on-rails controls
    
  ATTACK_PATTERN:
    phase_1: Telegraphed attacks, long windows
    phase_2: Faster attacks, movement patterns
    phase_3: Dangerous attacks, short windows
    
  WEAK_POINTS:
    visual: Glowing areas on boss
    targeting: Charge shot locks on
    hit_count: 3-5 hits per phase
```

### 19.5.2 All-Range Mode Bosses

```
ALL_RANGE_MODE:

  description: Free-flight arena boss fight
  
  TRANSITION:
    trigger: Reach boss arena
    camera: Switches to free third-person
    movement: Full 3D flight control
    
  ARENA:
    shape: Bounded cubic/spherical area
    boundaries: Soft walls (push back)
    
  CONTROLS_CHANGE:
    left_stick: Pitch and roll
    right_stick: Camera/yaw
    acceleration: Automatic (maintain speed)
    
  BOSS_BEHAVIOR:
    movement: Free flight in arena
    attacks: Missiles, beams, rams
    weak_points: Must maneuver behind/under
    
  PHASE_STRUCTURE:
    similar to on-rails, 3 phases typical
```

## 19.6 Flying Level Completion

```
FLYING_COMPLETION:

  WIN_CONDITION:
    requirement: Defeat boss
    
  FAILURE_CONDITIONS:
    ship_destroyed: Respawn at checkpoint
    
  SCORING:
    enemy_destruction: Points per enemy
    ring_bonus: Rings × 10
    accuracy_bonus: Hit% × 1000
    no_damage_bonus: 5000 points
    boss_bonus: 10000 points
    
  ZONE_TRANSITION:
    on_victory: Cutscene to next zone
    story_beat: Often includes dialogue
```

---

# 20. RING INTEGRATION ACROSS MODES

## 20.1 Unified Ring System

```
RING_SYSTEM_ACROSS_MODES:

  PRINCIPLE:
    - Rings work similarly in all modes
    - Having rings = survival
    - No rings + hit = failure state
    
  MODE_SPECIFIC_BEHAVIOR:
  
    PLATFORMING:
      lose_on_hit: All rings
      scatter: Yes (can recollect)
      death: Hit with 0 rings
      
    FLYING:
      lose_on_hit: 10-30 based on attack
      scatter: No
      death: Second hit with 0 rings
```

## 20.2 Power-Up Availability

```
POWER_UPS_BY_MODE:

  PLATFORMING:
    shields: All 5 types
    invincibility: Available
    speed_shoes: Available
    
  FLYING:
    shields: Basic only (ship shield)
    invincibility: N/A
    upgrades: Weapon upgrades instead
```

---

**END OF PART 4**

*Next: Part 5 - Bonus Stages & Special Stages*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 5: Bonus Stages & Special Stages

---

# 21. CHECKPOINT BONUS STAGES (POOL)

## 21.1 Pool Bonus Stage Overview

Pool Bonus Stages are billiards-themed challenges accessed through checkpoints. Players control Gina as a "cue ball" and must knock pool balls into pockets.

```
POOL_BONUS_PHILOSOPHY:

  theme: Billiards/Pool with digital twist
  access: Checkpoint with 20+ rings (or multiple of 20)
  goal: Clear sections, earn Medallions
  
  aesthetic:
    - Surreal pool table environments
    - Geometric obstacles
    - Digital/VR visual effects
    - Not realistic billiards - arcade style
```

## 21.2 Pool Controls

```
POOL_CONTROLS:

  AIMING:
    left_stick / WASD:
      - Rotate aim direction
      - 360-degree aiming
      
    visual:
      - Aim line shows trajectory
      - Dotted line shows bounce prediction (1 bounce)
      
  POWER:
    button_south / SPACE (hold):
      - Pull back to charge power
      - Power meter fills
      - Release to shoot
      
    power_levels:
      - Tap: Gentle shot
      - Half: Medium shot
      - Full: Powerful shot
      
  CAMERA:
    right_stick / MOUSE:
      - Look around table
      - Returns to player on release
      
  CANCEL:
    button_east / E:
      - Cancel current aim
      - Reset position (if stuck)
```

## 21.3 Pool Mechanics

### 21.3.1 Ball Physics

```
BALL_PHYSICS:

  physics_type: Arcade (not realistic simulation)
  
  PLAYER_BALL (Gina):
    behavior: Controlled like cue ball
    collision: Transfers momentum to other balls
    stopping: Moderate friction
    
  TARGET_BALLS:
    types:
      - STANDARD (colored): Must pocket
      - OBSTACLE (black): Avoid pocketing
      - BONUS (gold): Extra rewards
      
    behavior:
      - Realistic collision response
      - Can bounce off walls/obstacles
      - Fall into pockets when close
      
  POCKETS:
    size: Generous (arcade-friendly)
    suction: Slight pull when ball near
    glow: Visual indicator
    
  MOMENTUM:
    transfer: ~80% on collision
    spin: Simplified (affects angle slightly)
    wall_bounce: ~70% energy retained
```

### 21.3.2 Table Layout

```
TABLE_DESIGN:

  shape: Non-standard (not rectangular)
  
  LAYOUT_ELEMENTS:
  
    WALLS:
      function: Bounce balls
      types: Straight, curved, angled
      
    POCKETS:
      count: 4-8 per section
      positions: Corners, edges, center obstacles
      size: Various (harder pockets = smaller)
      
    OBSTACLES:
      bumpers: Bounce balls away
      blockers: Cannot pass through
      movers: Moving walls/barriers
      spinners: Rotate balls on contact
      
    HAZARDS:
      enemy_balls: Moving obstacles, damage on contact
      time_drains: Areas that cost extra time
      trap_zones: Temporarily stuck
```

### 21.3.3 Section Progression

```
SECTION_SYSTEM:

  sections_per_stage: 3-5
  
  SECTION_STRUCTURE:
  
    GOAL:
      requirement: Pocket all TARGET_BALLS
      ball_count: 5-10 per section
      
    LAYOUT:
      new_layout: Each section has unique design
      increased_difficulty: More balls, harder layouts
      
    COMPLETION:
      trigger: All target balls pocketed
      reward: 1 Medallion
      transition: Brief celebration, next section loads
      
  FINAL_SECTION:
    difficulty: Highest
    bonus: Extra reward for clearing all sections
    reward: 100 rings + Medallion
```

## 21.4 Pool Time System

```
POOL_TIME_SYSTEM:

  STARTING_TIME:
    base: 60 seconds
    bonus: +5 seconds per 20 rings at checkpoint entry
    
  TIME_LOSS:
    per_shot: None (unlimited shots)
    enemy_hit: -10 seconds
    obstacle_ball_pocketed: -15 seconds
    
  TIME_GAIN:
    target_ball_pocketed: +5 seconds
    bonus_ball_pocketed: +10 seconds
    perfect_shot (first try): +3 seconds
    
  TIME_OUT:
    effect: Stage ends immediately
    result: Keep medallions earned so far
    no_bonus: Miss final completion bonus
```

## 21.5 Pool Enemies and Hazards

```
POOL_ENEMIES:

  ROAMING_BALL:
    appearance: Dark ball with angry face
    behavior: Moves around table randomly
    damage: -10 seconds on contact
    defeat: Cannot defeat (avoid only)
    
  BOUNCER_BALL:
    appearance: Spiky ball
    behavior: Bounces off walls continuously
    damage: -10 seconds, pushes player
    pattern: Predictable bounce path
    
  GUARD_BALL:
    appearance: Ball with shield icon
    behavior: Guards specific pocket
    damage: -5 seconds, blocks shots
    defeat: Must be knocked away first
    
  HAZARD_ZONES:
    time_drain_pool: -1 second per second in zone
    sticky_zone: Slows ball movement
    teleport_pad: Sends ball to random location
```

## 21.6 Pool Rewards

```
POOL_REWARDS:

  PER_SECTION:
    medallion: 1
    
  FULL_CLEAR:
    medallions: 1 (in addition to section medallions)
    rings: 100
    
  MEDALLION_USES:
    - Unlock cosmetics (skins, colors)
    - Unlock cheats (big head mode, etc.)
    - Unlock gallery content (art, music)
    - Unlock multiplayer content
    - Unlock level editor features
```

---

# 22. END-OF-LEVEL BONUS STAGES (PINBALL)

## 22.1 Pinball Bonus Stage Overview

Pinball Bonus Stages are accessed by completing a level with 100+ rings. Gina becomes the pinball, and players can win various prizes.

```
PINBALL_BONUS_PHILOSOPHY:

  theme: Digital pinball machine
  access: Finish level with 100+ rings
  goal: Collect prizes, exit when ready
  
  aesthetic:
    - Neon/digital pinball table
    - VR/computer themed elements
    - Single universal table design
    - Prizes physically appear on table
```

## 22.2 Pinball Controls

```
PINBALL_CONTROLS:

  FLIPPERS:
    left_trigger / A / LEFT_SHIFT:
      - Activate left flipper
      
    right_trigger / D / RIGHT_SHIFT:
      - Activate right flipper
      
    both_triggers:
      - Both flippers simultaneously
      
  NUDGE:
    left_stick / WASD:
      - Nudge table slightly
      - Limited uses (tilt warning)
      
  LAUNCH:
    button_south / SPACE (at start):
      - Pull back plunger
      - Release to launch ball
```

## 22.3 Pinball Mechanics

### 22.3.1 Table Layout

```
PINBALL_TABLE:

  layout_type: Standard pinball with digital theme
  
  ELEMENTS:
  
    FLIPPERS:
      count: 2 (standard)
      position: Bottom of playfield
      size: Standard pinball flipper
      
    BUMPERS:
      count: 3-5
      position: Upper playfield
      effect: Bounce ball, +10 score
      
    TARGETS:
      drop_targets: Hit to lower, reveal prizes
      standing_targets: Hit for points
      spinner: Rapid points when passed
      
    RAMPS:
      count: 2-3
      effect: Loop for bonus, access upper areas
      
    LANES:
      outlanes: Exits table (drain)
      inlanes: Safe return paths
      skill_shot_lane: Bonus at launch
      
    PRIZE_LOCATIONS:
      scattered: Around playfield
      ramp_rewards: At end of ramps
      target_rewards: Behind drop targets
      
    DRAIN:
      position: Bottom center
      effect: Exit stage (voluntary or ball loss)
      saver: Brief ball save at start
```

### 22.3.2 Prize System

```
PINBALL_PRIZES:

  PRIZE_TYPES:
  
    RING_BUNDLE:
      values: 10, 25, 50 rings
      appearance: Ring icon
      frequency: Common
      
    POWER_UP:
      types: Shield, Speed Shoes, Invincibility
      appearance: Item box icon
      frequency: Uncommon
      effect: Added to inventory for next level
      
    SUPER_RING:
      value: 100 rings
      appearance: Large glowing ring
      frequency: Rare
      
    MEDALLION:
      value: 1 medallion
      appearance: Medal icon
      frequency: Rare (max 1 per session)
      
    PIXEL_ATOMS:
      value: 50-200 atoms
      appearance: Atom icons
      frequency: Uncommon
      use: Village builder currency
      
  PRIZE_SPAWNING:
    locations: Fixed positions on table
    visibility: Prizes glow when available
    collection: Ball passes through prize
    respawn: Some prizes respawn after time
```

### 22.3.3 Scoring

```
PINBALL_SCORING:

  POINT_SOURCES:
    bumper_hit: 100 points
    target_hit: 500 points
    ramp_complete: 2000 points
    spinner_per_spin: 50 points
    combo_multiplier: Increases with consecutive hits
    
  BONUS_MODES:
    multiball: N/A (single ball only)
    jackpot: Hit all targets for 10000 points
    super_jackpot: Complete all ramps + targets
    
  SCORE_USE:
    contributes_to: Overall game score
    rank_effect: None (bonus stage)
```

## 22.4 Pinball Exit

```
PINBALL_EXIT:

  METHODS:
  
    VOLUNTARY_EXIT:
      trigger: Let ball drain intentionally
      result: Keep all collected prizes
      
    NATURAL_DRAIN:
      trigger: Ball falls past flippers
      result: Keep all collected prizes
      
  NO_FAILURE:
    philosophy: Pinball is reward, not challenge
    ball_save: Brief period after launch
    
  TRANSITION:
    animation: Ball drains, prizes tally
    return: Level results screen
    prizes_applied: Next level start
```

---

# 23. SPECIAL STAGES (COSMIC CRYSTAL)

## 23.1 Special Stage Overview

Special Stages are hidden exploration challenges containing Cosmic Crystals. Finding all 8 crystals unlocks Cosmic Mode.

```
SPECIAL_STAGE_PHILOSOPHY:

  access: Hidden giant rings in main levels
  goal: Find Cosmic Crystal before time runs out
  count: 8 total (one per crystal)
  
  aesthetic:
    - Abstract wireframe environments
    - Unfinished computer program look
    - Single-color wireframes
    - Flat, basic textures
    - Surreal impossible geometry
```

## 23.2 Special Stage Access

### 23.2.1 Hidden Warp Locations

```
WARP_RING_SYSTEM:

  appearance:
    - Giant ring (3x normal size)
    - Swirling energy effect
    - Distinct sound when nearby
    
  locations:
    - Hidden in secret areas
    - Requires exploration to find
    - One per level (not all levels have one)
    - 8 total across all zones
    
  activation:
    trigger: Jump through ring
    transition: Warp effect, load special stage
    
  cooldown_system:
    after_exit: Warp ring disappears
    respawn: After completing 10 other levels
    purpose: Prevent farming, encourage variety
```

### 23.2.2 Crystal Distribution

```
CRYSTAL_LOCATIONS:

  ZONE_DISTRIBUTION:
    crystals: 8 total
    zones: 18 total
    ratio: ~1 crystal per 2 zones
    
  SUGGESTED_PLACEMENT:
    crystal_1: Zone 2 (early, teaches mechanic)
    crystal_2: Zone 4
    crystal_3: Zone 6
    crystal_4: Zone 8
    crystal_5: Zone 11
    crystal_6: Zone 13
    crystal_7: Zone 15
    crystal_8: Zone 17 (late game)
    
  DIFFICULTY_CURVE:
    early_stages: Simpler layouts, more time
    mid_stages: Complex layouts, moderate time
    late_stages: Maze-like, tight time
```

## 23.3 Special Stage Mechanics

### 23.3.1 Time System

```
SPECIAL_STAGE_TIME:

  REPRESENTATION:
    display: Ring counter (not seconds)
    starting: 30 rings/seconds
    
  RING_COLLECTION:
    effect: +1 second per ring collected
    visual: Timer increases
    
  TIME_DRAIN:
    rate: 1 per second (constant)
    
  ENEMY_HIT:
    penalty: -5 rings/seconds
    
  TIME_OUT:
    effect: Ejected from stage
    crystal: Not obtained
    retry: Must find warp ring again (after cooldown)
```

### 23.3.2 Ring Density

```
SPECIAL_STAGE_RINGS:

  density: HIGH (more than regular stages)
  
  PLACEMENT:
    pathways: Dense ring trails mark routes
    exploration_rewards: Clusters in side areas
    crystal_path: Rings guide toward crystal
    
  TYPICAL_COUNT:
    total_available: 300-500 rings per stage
    survival_requirement: Collect ~50% to have time
    
  RING_TYPES:
    standard: +1 time
    super_ring: +10 time (rare)
```

### 23.3.3 Movement and Abilities

```
SPECIAL_STAGE_GAMEPLAY:

  MOVEMENT:
    type: Standard platforming controls
    all_abilities: Available
    
  EXPLORATION:
    structure: Non-linear maze-like
    paths: Multiple routes to crystal
    dead_ends: Some (cost time)
    
  PROGRESSION:
    no_checkpoints: Must complete in one run
    ring_emphasis: Keep collecting to survive
```

## 23.4 Special Stage Environment

### 23.4.1 Visual Design

```
SPECIAL_STAGE_AESTHETIC:

  STYLE: "Unfinished Computer Program"
  
  GEOMETRY:
    type: Wireframe with flat fills
    color: Single color per stage (varies)
    complexity: Simple shapes, impossible spaces
    
  TEXTURES:
    type: Flat, untextured surfaces
    patterns: Grid lines, basic gradients
    
  BACKGROUND:
    type: Void with distant geometry
    movement: Slow rotation/drift
    
  LIGHTING:
    type: Ambient only (no shadows)
    effect: Even, flat illumination
    
  EXAMPLES:
    stage_1: Blue wireframe, floating platforms
    stage_2: Green wireframe, tube structures
    stage_3: Purple wireframe, M.C. Escher-style stairs
    stage_4: Orange wireframe, fractured cubes
```

### 23.4.2 Stage Layouts

```
SPECIAL_STAGE_LAYOUTS:

  LAYOUT_PHILOSOPHY:
    - Non-linear exploration
    - Multiple paths to crystal
    - Rewards thorough exploration (rings)
    - Punishes aimless wandering (time)
    
  COMMON_ELEMENTS:
    floating_platforms: Disconnected geometry
    impossible_corridors: Wrap around, lead nowhere
    height_variation: Vertical exploration
    ring_trails: Visual guidance
    
  CRYSTAL_LOCATION:
    position: Somewhat hidden
    hint: Larger ring clusters nearby
    visibility: Can see from distance sometimes
```

## 23.5 Special Stage Enemies

```
SPECIAL_STAGE_ENEMIES:

  ENEMY_TYPES:
  
    VOID_WALKER:
      appearance: Wireframe humanoid
      behavior: Patrols platforms
      damage: -5 time on contact
      defeat: Standard attacks work
      
    DATA_GHOST:
      appearance: Translucent floating shape
      behavior: Phases through geometry
      damage: -5 time, briefly stuns
      defeat: Only while solid (flickers)
      
    ERROR_TRAP:
      appearance: Glitching geometry
      behavior: Stationary hazard
      damage: -10 time
      avoid: Jump over/around
      
    FIREWALL:
      appearance: Moving barrier wall
      behavior: Sweeps across areas
      damage: -5 time, pushes back
      avoid: Time passage through gaps
      
  ENEMY_DENSITY:
    lower_than: Normal levels
    purpose: Time pressure, not combat focus
```

## 23.6 Cosmic Crystal

```
COSMIC_CRYSTAL:

  appearance:
    shape: Multifaceted gem
    color: Shifts through spectrum
    effect: Bright glow, particle trail
    size: Large (easy to spot when close)
    
  collection:
    trigger: Touch crystal
    animation: Absorption sequence
    result: Stage complete
    
  INDIVIDUAL_CRYSTALS:
    crystal_1: "Courage Crystal" (Red)
    crystal_2: "Wisdom Crystal" (Blue)
    crystal_3: "Hope Crystal" (Yellow)
    crystal_4: "Love Crystal" (Pink)
    crystal_5: "Nature Crystal" (Green)
    crystal_6: "Spirit Crystal" (Purple)
    crystal_7: "Time Crystal" (White)
    crystal_8: "Space Crystal" (Black/Starfield)
```

---

# 24. COSMIC MODE

## 24.1 Cosmic Mode Overview

Collecting all 8 Cosmic Crystals grants access to Cosmic Mode - a super transformation.

```
COSMIC_MODE_PHILOSOPHY:

  reference: Super Sonic from Sonic games
  requirement: All 8 Cosmic Crystals
  activation: 50 rings + trigger
  
  abilities:
    - Invincibility
    - Super speed
    - Enhanced attacks
```

## 24.2 Cosmic Mode Activation

```
COSMIC_ACTIVATION:

  REQUIREMENTS:
    crystals: All 8 collected
    rings: Minimum 50
    
  ACTIVATION:
    input: Double-tap jump (or dedicated button)
    animation: Transformation sequence
    duration: 2 seconds (player invincible during)
    
  RESTRICTIONS:
    where: Most gameplay situations
    not_available: 
      - Flying levels (ship-based)
      - Bonus stages
      - Boss cutscenes
```

## 24.3 Cosmic Mode Abilities

```
COSMIC_ABILITIES:

  INVINCIBILITY:
    effect: Cannot be damaged
    exceptions: Pits, crushing (instant death)
    visual: Glowing aura, color shift
    
  SPEED:
    max_speed: 60 units/sec (1.5x boost speed)
    acceleration: Instant to max
    
  FLIGHT:
    enabled: Yes
    control: Full 3D movement
    speed: Same as ground speed
    
  ATTACKS:
    contact_damage: Destroys most enemies
    damage_value: 10x normal
    boss_damage: Standard (not overpowered)
    
  RING_DRAIN:
    rate: 1 ring per second
    warning: Audio cue at 10 rings
    deactivation: 0 rings = transform back
```

## 24.4 Cosmic Mode Visuals

```
COSMIC_VISUALS:

  GINA_TRANSFORMATION:
    color: Orange → Glowing Gold/White
    eyes: Glowing energy
    particles: Cosmic sparkles, star trail
    
  AURA:
    type: Pulsing energy field
    color: Rainbow/spectrum shift
    size: ~2x character size
    
  EFFECTS:
    speed_lines: Always visible
    ground_contact: Energy ripples
    enemy_defeat: Spectacular explosions
```

## 24.5 Cosmic Mode in Story

```
COSMIC_STORY_INTEGRATION:

  FINAL_BOSS:
    requirement: Cosmic Mode for true ending
    phase_4: Only beatable with Cosmic power
    duration: Cosmic Mode lasts entire phase
    
  TRUE_ENDING:
    condition: Defeat Vex with Cosmic Mode
    content: Extended ending, full resolution
    
  GOOD_ENDING:
    condition: Defeat Vex without all crystals
    content: Vex contained but not fully defeated
    sequel_hook: Threat remains
```

---

# 25. BONUS STAGE SUMMARY

```
BONUS_STAGE_COMPARISON:

  ┌─────────────────┬─────────────────┬─────────────────┐
  │ FEATURE         │ POOL BONUS      │ PINBALL BONUS   │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Access          │ Checkpoint      │ Level End       │
  │                 │ (20+ rings)     │ (100+ rings)    │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Goal            │ Clear sections  │ Collect prizes  │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Failure         │ Time runs out   │ None (exit any) │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Primary Reward  │ Medallions      │ Items/Rings     │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Challenge       │ Skill-based     │ Casual          │
  ├─────────────────┼─────────────────┼─────────────────┤
  │ Replayability   │ Per checkpoint  │ Per level       │
  └─────────────────┴─────────────────┴─────────────────┘

  ┌─────────────────────────────────────────────────────┐
  │ SPECIAL STAGES (COSMIC CRYSTAL)                     │
  ├─────────────────────────────────────────────────────┤
  │ Access: Hidden warp rings in levels                 │
  │ Goal: Find Cosmic Crystal before time out           │
  │ Failure: Time runs out                              │
  │ Reward: Cosmic Crystal (8 = Cosmic Mode)            │
  │ Challenge: Exploration under time pressure          │
  │ Replayability: After 10-level cooldown              │
  └─────────────────────────────────────────────────────┘
```

---

**END OF PART 5**

*Next: Part 6 - World Structure, Zones, Progression*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 6: World Structure, Zones, Progression

---

# 26. WORLD MAP SYSTEM

## 26.1 World Map Overview

The world map follows a **Super Mario Bros. 3 / New Super Mario Bros.** style structure with branching pathways, allowing players choice in progression.

```
WORLD_MAP_PHILOSOPHY:

  reference: "Super Mario Bros. 3, New Super Mario Bros."
  structure: Branching paths within zones
  navigation: Node-based movement
  
  key_features:
    - Visual representation of each zone
    - Multiple paths through zones
    - Locked paths requiring progression
    - Flying level transitions between zones
```

## 26.2 World Map Navigation

```
WORLD_MAP_CONTROLS:

  MOVEMENT:
    d_pad / left_stick / WASD:
      - Move between connected nodes
      - Cannot move off paths
      
  SELECTION:
    button_south / SPACE / ENTER:
      - Enter selected level
      - Confirm menu options
      
  BACK:
    button_east / ESCAPE:
      - Exit to zone select
      - Cancel menus
      
  INFO:
    button_north / TAB:
      - View level details
      - View completion status
```

## 26.3 World Map Elements

```
WORLD_MAP_ELEMENTS:

  NODE_TYPES:
  
    STANDARD_LEVEL:
      appearance: Circular platform with level icon
      states: Locked, Available, Completed
      completion_marker: Flag/star when completed
      
    FORTRESS_LEVEL:
      appearance: Castle/fortress structure
      states: Locked, Available, Completed
      boss_indicator: Shows mini-boss present
      
    BOSS_LEVEL:
      appearance: Large structure with boss icon
      states: Locked, Available, Completed
      required: Must complete for zone progression
      
    FLYING_TRANSITION:
      appearance: Runway/launch pad
      connects: Current zone to next zone
      requirement: Defeat zone boss
      
  PATH_TYPES:
  
    MAIN_PATH:
      appearance: Solid, prominent line
      requirement: Standard progression
      
    ALTERNATE_PATH:
      appearance: Dotted or dimmer line
      requirement: May need special conditions
      
    SECRET_PATH:
      appearance: Hidden until discovered
      requirement: Find secret exit in level
      
  SPECIAL_NODES:
  
    TOAD_HOUSE_EQUIVALENT:
      name: "Supply Cache"
      function: Free power-up or items
      respawn: After completing certain levels
      
    MINI_GAME_NODE:
      name: "Challenge Shrine"
      function: Bonus mini-game for prizes
      types: Ring challenge, time attack
```

---

# 27. ZONE STRUCTURE

## 27.1 Zone Design Philosophy

```
ZONE_PHILOSOPHY:

  total_zones: 18
  levels_per_zone: 6-10 (varies by zone)
  
  ZONE_COMPOSITION:
    main_levels: 4-6 standard platforming levels
    fortress_levels: 1-2 mid-zone boss levels
    boss_level: 1 final zone boss
    
  PROGRESSION:
    branching_paths: Multiple routes through zone
    required_levels: Only some levels mandatory
    optional_content: Encourages exploration/replay
```

## 27.2 Zone Template

```
ZONE_TEMPLATE:

  ZONE_INFO:
    zone_id: Unique identifier
    zone_name: "[Adjective] [Noun] Zone"
    theme: Visual/gameplay theme
    difficulty: 1-10 scale
    
  LEVEL_STRUCTURE:
    act_1: Introduction level (teaches zone mechanics)
    act_2: Expansion level (more complex)
    act_3: Challenge level (tests mastery)
    fortress: Mid-boss level
    act_4: Pre-boss level
    act_5: Optional content
    boss: Zone final boss
    
  UNLOCKING:
    initial: Act 1 available
    progression: Completing levels unlocks adjacent
    branching: Some paths split, rejoin
    boss_unlock: Requires completing main path
    
  ZONE_EXIT:
    requirement: Defeat zone boss
    transition: Flying level to next zone(s)
    branching: May unlock multiple zones
```

---

# 28. COMPLETE ZONE LIST

## 28.1 Zone Overview Table

```
ZONE_LIST:

  ┌────┬─────────────────────────┬──────────────┬────────┬────────────┐
  │ #  │ ZONE NAME               │ THEME        │ LEVELS │ DIFFICULTY │
  ├────┼─────────────────────────┼──────────────┼────────┼────────────┤
  │ 1  │ Tropica Village Zone    │ Tropical     │ 6      │ 1          │
  │ 2  │ Emerald Jungle Zone     │ Jungle       │ 7      │ 2          │
  │ 3  │ Coral Reef Zone         │ Underwater   │ 7      │ 2          │
  │ 4  │ Sunset Beach Zone       │ Beach        │ 8      │ 3          │
  │ 5  │ Ancient Ruins Zone      │ Ruins        │ 7      │ 3          │
  │ 6  │ Crystal Caverns Zone    │ Cave/Crystal │ 8      │ 4          │
  │ 7  │ Frozen Peaks Zone       │ Snow/Ice     │ 8      │ 4          │
  │ 8  │ Glacial Valley Zone     │ Ice/Tundra   │ 7      │ 5          │
  │ 9  │ Scorching Sands Zone    │ Desert       │ 8      │ 5          │
  │ 10 │ Mirage Oasis Zone       │ Desert/Oasis │ 7      │ 5          │
  │ 11 │ Volcanic Crater Zone    │ Volcano/Fire │ 8      │ 6          │
  │ 12 │ Magma Fortress Zone     │ Fire/Factory │ 8      │ 6          │
  │ 13 │ Neon Circuit Zone       │ Cyber/City   │ 9      │ 7          │
  │ 14 │ Data Stream Zone        │ Digital      │ 8      │ 7          │
  │ 15 │ Storm Citadel Zone      │ Sky/Storm    │ 8      │ 8          │
  │ 16 │ Gravity Gardens Zone    │ Space        │ 9      │ 8          │
  │ 17 │ Cosmic Station Zone     │ Space Station│ 8      │ 9          │
  │ 18 │ Syndicate Core Zone     │ Final        │ 10     │ 10         │
  └────┴─────────────────────────┴──────────────┴────────┴────────────┘
  
  TOTAL LEVELS: ~140
```

## 28.2 Detailed Zone Descriptions

### Zone 1: Tropica Village Zone

```
ZONE_1: TROPICA_VILLAGE

  theme: Tropical paradise, Gina's home
  aesthetic: Palm trees, wooden structures, waterfalls
  story: Tutorial zone, village destroyed, begin journey
  
  LEVELS:
    1-1: "Village Outskirts" (Tutorial basics)
    1-2: "Palm Tree Path" (Speed mechanics)
    1-3: "Waterfall Heights" (Vertical platforming)
    1-4: "Coastal Cliffs" (Introduction complete)
    1-F: "Ruined Temple" (Fortress - First boss encounter)
    1-B: "Syndicate Outpost" (Zone Boss: Corrupted Tiki)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_2: Emerald Jungle Zone
    zone_3: Coral Reef Zone (alternate path)
```

### Zone 2: Emerald Jungle Zone

```
ZONE_2: EMERALD_JUNGLE

  theme: Dense rainforest, ancient trees
  aesthetic: Giant trees, vines, glowing plants
  story: Track fleeing Syndicate forces
  
  LEVELS:
    2-1: "Canopy Crossing" (Vine swinging)
    2-2: "Root Network" (Underground/roots)
    2-3: "Treetop Village" (Elevated platforms)
    2-4: "Mystic Grove" (Bioluminescent area)
    2-F: "Overgrown Fortress" (Fortress)
    2-B: "Heart of the Jungle" (Boss: Jungle Guardian)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 1 location
    
  UNLOCKS:
    zone_4: Sunset Beach Zone
```

### Zone 3: Coral Reef Zone

```
ZONE_3: CORAL_REEF

  theme: Underwater exploration
  aesthetic: Colorful coral, underwater ruins
  story: Rescue captured tribe members
  
  LEVELS:
    3-1: "Shallow Waters" (Introduce swimming)
    3-2: "Reef Maze" (Underwater navigation)
    3-3: "Sunken Ship" (Exploration focused)
    3-4: "Deep Trenches" (Darkness, light sources)
    3-5: "Current Channels" (Water current mechanics)
    3-F: "Coral Castle" (Fortress)
    3-B: "Abyssal Depths" (Boss: Commander Nexus #1)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_4: Sunset Beach Zone
```

### Zone 4: Sunset Beach Zone

```
ZONE_4: SUNSET_BEACH

  theme: Coastal paradise at golden hour
  aesthetic: Orange skies, pier structures, boardwalks
  
  LEVELS:
    4-1: "Boardwalk Blitz" (Pier platforming)
    4-2: "Lighthouse Loop" (Vertical challenge)
    4-3: "Tidal Caves" (Cave sections)
    4-F: "Pier Fortress" (Fortress)
    4-4: "Sunset Sprint" (Speed-focused)
    4-B: "Beach Showdown" (Boss: Surge #1)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 2 location
    
  UNLOCKS:
    zone_5: Ancient Ruins Zone
    zone_6: Crystal Caverns Zone (alternate)
```

### Zone 5: Ancient Ruins Zone

```
ZONE_5: ANCIENT_RUINS

  theme: Mysterious ancient civilization
  aesthetic: Stone temples, traps, puzzles
  story: Discover history of Gecko Grid
  
  LEVELS:
    5-1: "Temple Entrance" (Trap introduction)
    5-2: "Puzzle Chambers" (Switch puzzles)
    5-3: "Crumbling Corridors" (Platforming focus)
    5-4: "Sacred Grounds" (Outdoor ruins)
    5-F: "Guardian's Hall" (Fortress - Glitch #1)
    5-5: "Inner Sanctum" (Advanced puzzles)
    5-B: "Throne of Ages" (Boss: Ancient Construct)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_6: Crystal Caverns Zone
```

### Zone 6: Crystal Caverns Zone

```
ZONE_6: CRYSTAL_CAVERNS

  theme: Underground crystal formations
  aesthetic: Glowing crystals, mineral caves
  story: Find underground path to snow region
  
  LEVELS:
    6-1: "Crystal Entrance" (Cave introduction)
    6-2: "Gem Gallery" (Reflective surfaces)
    6-3: "Minecart Madness" (Rail section)
    6-4: "Underground Lake" (Water + caves)
    6-5: "Crystal Maze" (Complex navigation)
    6-F: "Gemstone Fortress" (Fortress - Titanica #1)
    6-6: "Diamond Deep" (Deepest caves)
    6-B: "Crystal Core" (Boss: Crystal Golem)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 3 location
    
  UNLOCKS:
    zone_7: Frozen Peaks Zone
```

### Zone 7: Frozen Peaks Zone

```
ZONE_7: FROZEN_PEAKS

  theme: Snowy mountains, ski resort
  aesthetic: Snow, ice, alpine structures
  
  LEVELS:
    7-1: "Snowy Summit" (Ice physics intro)
    7-2: "Avalanche Alley" (Hazard focused)
    7-3: "Frozen Falls" (Ice waterfall area)
    7-4: "Ski Lodge" (Indoor/outdoor mix)
    7-F: "Ice Fortress" (Fortress)
    7-B: "Summit Showdown" (Boss: Frost Titan)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_8: Glacial Valley Zone
    zone_9: Scorching Sands Zone (alternate)
```

### Zone 8: Glacial Valley Zone

```
ZONE_8: GLACIAL_VALLEY

  theme: Frozen tundra, ice caves
  aesthetic: Glaciers, frozen sea, aurora
  story: Chase Nexus through frozen lands
  
  LEVELS:
    8-1: "Glacier Path" (Slippery terrain)
    8-2: "Frozen Sea" (Ice floe platforming)
    8-3: "Ice Cave Network" (Cave exploration)
    8-4: "Aurora Fields" (Night ice level)
    8-F: "Frost Fortress" (Fortress - Nexus #2)
    8-5: "Cracking Ice" (Breaking platforms)
    8-B: "Heart of Winter" (Boss: Blizzard Beast)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 4 location
    
  UNLOCKS:
    zone_9: Scorching Sands Zone
```

### Zone 9: Scorching Sands Zone

```
ZONE_9: SCORCHING_SANDS

  theme: Desert dunes, ancient tombs
  aesthetic: Sand, pyramids, oasis glimpses
  story: Cross the digital desert
  
  LEVELS:
    9-1: "Dune Sea" (Sand physics)
    9-2: "Sandstorm Sprint" (Visibility challenge)
    9-3: "Pyramid Exterior" (Climbing structure)
    9-4: "Tomb Depths" (Indoor puzzles)
    9-F: "Desert Fortress" (Fortress - Surge #2)
    9-5: "Quicksand Quarry" (Hazard focus)
    9-B: "Pharaoh's Chamber" (Boss: Sand Colossus)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_10: Mirage Oasis Zone
```

### Zone 10: Mirage Oasis Zone

```
ZONE_10: MIRAGE_OASIS

  theme: Desert oasis, illusion mechanics
  aesthetic: Palm trees in desert, mirages, water
  story: Find hidden rebel base
  
  LEVELS:
    10-1: "Oasis Gates" (Water in desert)
    10-2: "Mirage Maze" (Visual tricks)
    10-3: "Hidden Springs" (Exploration)
    10-4: "Market District" (NPC area, light combat)
    10-F: "Illusion Fortress" (Fortress - Glitch #2)
    10-B: "Reality Shift" (Boss: Mirage Master)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_11: Volcanic Crater Zone
```

### Zone 11: Volcanic Crater Zone

```
ZONE_11: VOLCANIC_CRATER

  theme: Active volcano, lava flows
  aesthetic: Magma, volcanic rock, smoke
  story: Infiltrate Syndicate industrial base
  
  LEVELS:
    11-1: "Crater Rim" (Exterior volcano)
    11-2: "Lava Flows" (Platform timing)
    11-3: "Volcanic Vents" (Vertical section)
    11-4: "Magma Caves" (Underground lava)
    11-5: "Eruption Escape" (Chase sequence)
    11-F: "Molten Fortress" (Fortress - Titanica #2)
    11-6: "Core Approach" (Pre-boss)
    11-B: "Heart of Fire" (Boss: Magma Wyrm)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 5 location
    
  UNLOCKS:
    zone_12: Magma Fortress Zone
```

### Zone 12: Magma Fortress Zone

```
ZONE_12: MAGMA_FORTRESS

  theme: Industrial fire facility
  aesthetic: Factory + volcano, machinery
  story: First confrontation with Director Vex
  
  LEVELS:
    12-1: "Forge Entrance" (Factory intro)
    12-2: "Assembly Line" (Moving platforms)
    12-3: "Smelting Chamber" (Lava + machines)
    12-4: "Control Room" (Puzzle section)
    12-5: "Cooling Towers" (Height + hazards)
    12-F: "Security Station" (Fortress)
    12-6: "Executive Level" (Pre-boss)
    12-B: "Director's Office" (Boss: Director Vex #1)
    
  SPECIAL_FEATURES:
    story_beat: Major confrontation, Vex escapes
    cosmic_crystal: None
    
  UNLOCKS:
    zone_13: Neon Circuit Zone
    zone_14: Data Stream Zone (alternate)
```

### Zone 13: Neon Circuit Zone

```
ZONE_13: NEON_CIRCUIT

  theme: Cyberpunk city, digital nightlife
  aesthetic: Neon lights, digital displays, urban
  story: Track Vex through cyber city
  
  LEVELS:
    13-1: "Downtown" (City introduction)
    13-2: "Highway Chase" (Speed focus)
    13-3: "Rooftop Run" (Vertical city)
    13-4: "Underground Club" (Indoor neon)
    13-5: "Skybridge" (High platforms)
    13-F: "Data Center" (Fortress - Glitch #3)
    13-6: "Tower Climb" (Ascent level)
    13-B: "Pinnacle Plaza" (Boss: Neon Dragon)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 6 location
    
  UNLOCKS:
    zone_14: Data Stream Zone
```

### Zone 14: Data Stream Zone

```
ZONE_14: DATA_STREAM

  theme: Inside computer systems
  aesthetic: Pure digital, data visualization
  story: Dive into the Grid's core systems
  
  LEVELS:
    14-1: "Input Port" (Enter the data)
    14-2: "Processing Unit" (Logic puzzles)
    14-3: "Memory Banks" (Exploration)
    14-4: "Virus Sector" (Corrupted area)
    14-5: "Firewall" (Barrier obstacles)
    14-F: "Admin Access" (Fortress - Nexus #3)
    14-6: "Core Protocol" (Advanced challenges)
    14-B: "System Override" (Boss: Anti-Virus)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_15: Storm Citadel Zone
```

### Zone 15: Storm Citadel Zone

```
ZONE_15: STORM_CITADEL

  theme: Sky fortress in eternal storm
  aesthetic: Clouds, lightning, floating structures
  story: Assault Syndicate sky base
  
  LEVELS:
    15-1: "Cloud Approach" (Platforming in sky)
    15-2: "Wind Tunnels" (Air current mechanics)
    15-3: "Lightning Fields" (Timing hazards)
    15-4: "Outer Walls" (Fortress exterior)
    15-5: "Hangar Bay" (Indoor section)
    15-F: "Storm Tower" (Fortress - Surge #3)
    15-6: "Central Spire" (Vertical challenge)
    15-B: "Eye of the Storm" (Boss: Storm Lord)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 7 location
    
  UNLOCKS:
    zone_16: Gravity Gardens Zone
```

### Zone 16: Gravity Gardens Zone

```
ZONE_16: GRAVITY_GARDENS

  theme: Space with gravity manipulation
  aesthetic: Asteroids, space flora, gravity shifts
  story: Enter space, approach final destination
  
  LEVELS:
    16-1: "Launch" (Leave atmosphere)
    16-2: "Asteroid Belt" (Space platforming)
    16-3: "Gravity Flip" (Gravity mechanics)
    16-4: "Space Garden" (Alien plants)
    16-5: "Zero-G Zone" (Free-floating section)
    16-F: "Orbital Fortress" (Fortress - Titanica #3)
    16-6: "Station Approach" (Pre-final zone)
    16-B: "Garden Guardian" (Boss: Cosmic Entity)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None
    
  UNLOCKS:
    zone_17: Cosmic Station Zone
```

### Zone 17: Cosmic Station Zone

```
ZONE_17: COSMIC_STATION

  theme: Space station, final approach
  aesthetic: High-tech station, space views
  story: Infiltrate Syndicate headquarters
  
  LEVELS:
    17-1: "Docking Bay" (Station entry)
    17-2: "Living Quarters" (Interior section)
    17-3: "Research Labs" (Science area)
    17-4: "Power Core" (Energy hazards)
    17-5: "Security Wing" (Combat focus)
    17-F: "Command Deck" (Fortress - all rivals)
    17-6: "Escape Pods" (Tension level)
    17-B: "Bridge Battle" (Boss: Syndicate Commanders)
    
  SPECIAL_FEATURES:
    cosmic_crystal: Crystal 8 location (final)
    
  UNLOCKS:
    zone_18: Syndicate Core Zone
```

### Zone 18: Syndicate Core Zone

```
ZONE_18: SYNDICATE_CORE

  theme: Final zone, digital heart
  aesthetic: Abstract digital space, boss rush
  story: Final confrontation with Director Vex
  
  LEVELS:
    18-1: "Core Entrance" (Introduction)
    18-2: "Memory Lane" (Revisit zone themes)
    18-3: "Trial of Courage" (Challenge gauntlet)
    18-4: "Trial of Speed" (Speed gauntlet)
    18-5: "Trial of Combat" (Combat gauntlet)
    18-6: "Inner Sanctum" (Pre-final)
    18-7: "Rival Gauntlet" (Optional: refight rivals)
    18-8: "Path to Vex" (Final approach)
    18-9: "Vex's Domain" (Final level)
    18-B: "FINAL: Director Vex" (Final Boss)
    
  SPECIAL_FEATURES:
    cosmic_crystal: None (all should be collected)
    final_boss: 4-phase Director Vex fight
    
  ENDINGS:
    without_crystals: Good ending
    with_crystals: True ending (Cosmic Mode finale)
```

---

# 29. PROGRESSION SYSTEM

## 29.1 Zone Unlocking

```
ZONE_UNLOCK_SYSTEM:

  BRANCHING_PATHS:
  
    START:
      zone_1 → zone_2 (main path)
      zone_1 → zone_3 (alternate path)
      
    EARLY_GAME (Zones 1-6):
      Multiple entry points
      Paths converge around zone 6
      
    MID_GAME (Zones 7-12):
      More linear with some branching
      Major story beats
      
    LATE_GAME (Zones 13-18):
      Generally linear
      Building to finale
      
  UNLOCK_CONDITIONS:
  
    standard: Defeat zone boss
    alternate: Find secret exit in level
    special: Collect X items
```

## 29.2 World Map Visualization

```
WORLD_MAP_FLOW:

                    ┌─────┐
                    │ Z1  │ (Tropica Village - START)
                    └──┬──┘
              ┌───────┴───────┐
              ▼               ▼
          ┌─────┐         ┌─────┐
          │ Z2  │         │ Z3  │
          └──┬──┘         └──┬──┘
              └───────┬───────┘
                      ▼
                  ┌─────┐
                  │ Z4  │ (Sunset Beach)
                  └──┬──┘
              ┌───────┴───────┐
              ▼               ▼
          ┌─────┐         ┌─────┐
          │ Z5  │         │ Z6  │
          └──┬──┘         └──┬──┘
              └───────┬───────┘
                      ▼
              ┌───────┴───────┐
              ▼               ▼
          ┌─────┐         ┌─────┐
          │ Z7  │         │ Z9  │
          └──┬──┘         └──┬──┘
              ▼               ▼
          ┌─────┐         ┌─────┐
          │ Z8  │         │ Z10 │
          └──┬──┘         └──┬──┘
              └───────┬───────┘
                      ▼
          ┌─────┐         ┌─────┐
          │ Z11 │─────────│ Z12 │ (Vex #1)
          └──┬──┘         └──┬──┘
              └───────┬───────┘
              ┌───────┴───────┐
              ▼               ▼
          ┌─────┐         ┌─────┐
          │ Z13 │─────────│ Z14 │
          └──┬──┘         └──┬──┘
              └───────┬───────┘
                      ▼
                  ┌─────┐
                  │ Z15 │ (Storm Citadel)
                  └──┬──┘
                      ▼
                  ┌─────┐
                  │ Z16 │ (Gravity Gardens)
                  └──┬──┘
                      ▼
                  ┌─────┐
                  │ Z17 │ (Cosmic Station)
                  └──┬──┘
                      ▼
                  ┌─────┐
                  │ Z18 │ (FINAL - Syndicate Core)
                  └─────┘
```

## 29.3 Flying Level Transitions

```
FLYING_TRANSITIONS:

  Each zone-to-zone transition requires completing a flying level.
  
  FLYING_LEVEL_LIST:
    FL-1: Tropica → Jungle/Reef (jungle aerial)
    FL-2: Jungle → Beach (coastal flight)
    FL-3: Reef → Beach (ocean flight)
    FL-4: Beach → Ruins/Caverns (canyon flight)
    FL-5: Ruins → Caverns (underground approach)
    FL-6: Caverns → Frozen (mountain approach)
    FL-7: Beach → Desert (alternate: desert approach)
    FL-8: Frozen → Glacial (arctic flight)
    FL-9: Glacial → Desert (cross-climate)
    FL-10: Desert → Oasis (desert flight)
    FL-11: Oasis → Volcanic (volcano approach)
    FL-12: Volcanic → Magma (industrial aerial)
    FL-13: Magma → Circuit/Data (cyber entry)
    FL-14: Circuit → Data (digital dive)
    FL-15: Data → Storm (sky ascent)
    FL-16: Storm → Gravity (space launch)
    FL-17: Gravity → Cosmic (station approach)
    
  TOTAL: 17 flying levels
```

---

# 30. COMPLETION TRACKING

## 30.1 Per-Level Completion

```
LEVEL_COMPLETION_DATA:

  COMPLETION_FLAGS:
    completed: true/false
    secret_exit_found: true/false (if applicable)
    
  COLLECTIBLES:
    rings_collected: X / total
    secrets_found: X / total
    medallion_earned: true/false
    
  PERFORMANCE:
    best_time: seconds
    best_score: points
    rank: S/A/B/C/D
    
  SPECIAL:
    no_damage_clear: true/false
    speed_run_clear: true/false (under par time)
```

## 30.2 Overall Completion

```
GAME_COMPLETION_TRACKING:

  STORY_COMPLETION:
    zones_cleared: X / 18
    total_levels_cleared: X / ~140
    bosses_defeated: X / ~40
    cosmic_crystals: X / 8
    
  OPTIONAL_COMPLETION:
    all_secrets_found: percentage
    all_medallions: X / total
    all_S_ranks: X / total
    
  COMPLETION_PERCENTAGE:
    formula: (weighted sum of all factors)
    display: X% on file select
    
  REWARDS:
    50%: Unlock bonus content
    75%: Unlock additional content
    100%: Unlock everything, special reward
```

---

**END OF PART 6**

*Next: Part 7 - Multiplayer Systems (Co-op & Competitive)*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 7: Multiplayer Systems (Co-op & Competitive)

---

# 31. CO-OP MULTIPLAYER

## 31.1 Co-op Overview

Split-screen cooperative play allowing two players to experience the story campaign together.

```
COOP_PHILOSOPHY:

  player_count: 2 players
  screen_mode: Split-screen (horizontal split)
  progression: Shared (both players advance)
  
  design_goals:
    - Full campaign playable in co-op
    - No player left behind
    - Cooperative, not competitive
    - Drop-in/drop-out support
```

## 31.2 Co-op Screen Layout

```
SPLIT_SCREEN_LAYOUT:

  HORIZONTAL_SPLIT:
    player_1: Top half of screen
    player_2: Bottom half of screen
    
  INDIVIDUAL_ELEMENTS:
    - Each player has own camera
    - Each player has own HUD
    - Curved world effect per player
    
  SHARED_ELEMENTS:
    - Ring count (shared pool)
    - Score (combined)
    - Timer (single)
    
  ASPECT_RATIO:
    per_player: 16:4.5 (wide format)
    letterboxing: None (stretches to fit)
```

## 31.3 Co-op Gameplay Mechanics

### 31.3.1 Player Characters

```
COOP_CHARACTERS:

  PLAYER_1:
    character: Gina the Gecko (default)
    color: Orange (standard)
    
  PLAYER_2:
    character: Alternate character (same abilities)
    color: Different palette (blue suggested)
    abilities: Identical to Gina
    
  CHARACTER_SELECTION:
    unlock: Progress through story
    cosmetic_only: Same gameplay
```

### 31.3.2 Shared Resources

```
COOP_RESOURCES:

  RINGS:
    pool: Shared between players
    collection: Either player adds to pool
    damage: Lost from shared pool
    display: Single ring counter
    
  POWER_UPS:
    shields: Individual (per player)
    invincibility: Individual
    collection: Collector gets item
    
  BOOST_METER:
    type: Individual meters
    filling: Own actions fill own meter
```

### 31.3.3 Camera Behavior

```
COOP_CAMERA:

  INDEPENDENT_CAMERAS:
    each_player: Own camera following them
    curved_world: Applies to each view
    
  TETHERING:
    max_distance: 50 units apart
    warning: Visual indicator when far
    teleport: Lagging player warps to leader
    
  TETHER_TRIGGER:
    distance: When > 50 units apart for > 3 seconds
    or: When one player significantly ahead
    
  TELEPORT_BEHAVIOR:
    animation: Brief dissolve effect
    position: Near leading player
    rings: Retained
    invincibility: Brief (1 second)
```

### 31.3.4 Death and Respawn

```
COOP_DEATH:

  SINGLE_PLAYER_DEATH:
    effect: That player respawns
    respawn_point: Near surviving player
    respawn_delay: 3 seconds
    rings_cost: 10 from shared pool
    
  BOTH_PLAYERS_DEATH:
    effect: Return to checkpoint
    rings: Reset to 0
    
  CHECKPOINT:
    activation: Either player can activate
    respawn: Both players at checkpoint
```

## 31.4 Co-op in Different Modes

```
COOP_MODE_SUPPORT:

  PLATFORMING_LEVELS:
    support: Full
    notes: Standard split-screen
    
  2D_SECTIONS:
    support: Full
    camera: Both on same 2D plane
    
  BOSS_FIGHTS:
    support: Full
    camera: Shared arena view (no split)
    strategy: Coordinate attacks
    
  FLYING_LEVELS:
    support: Full (two ships)
    formation: Both on same rail path
    
  BONUS_STAGES:
    support: Alternating turns
    pool: One player at a time
    pinball: One player at a time
    
  SPECIAL_STAGES:
    support: Full (split-screen exploration)
```

## 31.5 Co-op Progression

```
COOP_PROGRESSION:

  SAVE_SYSTEM:
    type: Host player's save file
    progress: Updates host's campaign
    guest_rewards: XP and unlocks earned
    
  UNLOCKS:
    shared: Both players get unlocks
    medallions: Go to both players
    crystals: Collected once, shared
    
  DROP_IN:
    method: Player 2 joins via menu
    any_time: During gameplay or menus
    
  DROP_OUT:
    method: Player 2 pauses and exits
    effect: Game continues single-player
    rings: Remain in pool
```

---

# 32. COMPETITIVE MULTIPLAYER

## 32.1 Competitive Mode Overview

Team-based competitive mode inspired by **Crash Team Rumble**, featuring 4v4 matches where teams compete to collect Pixel Atoms.

```
COMPETITIVE_PHILOSOPHY:

  reference: "Crash Team Rumble"
  team_size: 4v4 (can use bots)
  objective: First team to 2000 Pixel Atoms
  
  key_features:
    - Class-based characters
    - Large arena maps
    - Dynamic map events
    - No curved world effect (boss-style camera)
```

## 32.2 Match Structure

```
MATCH_STRUCTURE:

  TEAMS:
    team_1: 4 players (or bots)
    team_2: 4 players (or bots)
    
  OBJECTIVE:
    goal: Collect 2000 Pixel Atoms first
    source: Atoms spawn around map
    deposit: Bring to team's bank
    
  MATCH_FLOW:
    1. Character select (30 seconds)
    2. Map loads
    3. Countdown (3 seconds)
    4. Match begins
    5. Play until 2000 atoms reached
    6. Victory/Results screen
    
  TIME_LIMIT:
    default: 10 minutes
    overtime: If tied, sudden death
```

## 32.3 Pixel Atoms System

```
PIXEL_ATOM_MECHANICS:

  COLLECTION:
    method: Touch atom to pick up
    carry_limit: 50 atoms per player
    visual: Atoms orbit player when carried
    
  ATOM_SOURCES:
    ground_spawns: Random locations
    enemy_defeat: Drop from eliminated players
    gem_stations: Special high-yield locations
    events: Random event rewards
    
  DEPOSITING:
    location: Team's bank (base)
    method: Enter bank zone
    time: Instant deposit
    bonus: Deposit streaks give bonus
    
  LOSING_ATOMS:
    on_elimination: Drop all carried atoms
    scatter: Atoms spread around elimination point
    pickup: Either team can collect
    
  ATOM_VALUES:
    standard: 1 atom
    silver: 5 atoms
    gold: 10 atoms
    mega: 25 atoms (rare)
```

## 32.4 Gem System

```
GEM_MECHANICS:

  RELICS (Gem Equivalent):
    description: Powerful map objectives
    spawn: Specific locations on map
    control: Team must capture and hold
    
  RELIC_TYPES:
  
    ATOM_GENERATOR:
      effect: Spawns atoms for controlling team
      rate: 5 atoms per 10 seconds
      capture: Stand in zone for 5 seconds
      
    SPEED_BOOST_RELIC:
      effect: Team gets 20% speed boost
      duration: While controlled
      
    DEFENSE_RELIC:
      effect: Team takes less damage
      duration: While controlled
      
  CONTROL:
    capture: Stand in zone, no enemies
    contest: Progress pauses if contested
    visual: Team color indicator
```

## 32.5 Character Classes

### 32.5.1 Class Overview

```
CHARACTER_CLASSES:

  SCORER:
    role: Primary atom collectors
    traits: Fast movement, high carry capacity
    weakness: Low combat ability
    count: 6 characters (3 unlocked start)
    
  BLOCKER:
    role: Combat and defense
    traits: High damage, area denial
    weakness: Slower, lower carry capacity
    count: 6 characters (3 unlocked start)
    
  BOOSTER:
    role: Team support
    traits: Buffs allies, debuffs enemies
    weakness: Moderate at everything
    count: 6 characters (3 unlocked start)
    
  TOTAL: 18 characters
```

### 32.5.2 Scorer Characters

```
SCORER_ROSTER:

  STARTER_SCORERS:
  
    DASH (Cheetah):
      speed: Very High
      carry: 60 atoms
      ability_1: "Sprint Burst" - Temporary super speed
      ability_2: "Slip Away" - Brief invisibility
      ultimate: "Speed Zone" - Area speed boost for team
      
    SWOOP (Hummingbird):
      speed: High
      carry: 50 atoms
      ability_1: "Hover" - Float briefly
      ability_2: "Dive Bomb" - Quick descent attack
      ultimate: "Flock Call" - Attracts nearby atoms
      
    SKITTER (Spider):
      speed: High
      carry: 55 atoms
      ability_1: "Wall Cling" - Climb any surface
      ability_2: "Web Line" - Quick grapple
      ultimate: "Web Network" - Team wall climb
      
  UNLOCKABLE_SCORERS:
  
    RIPPLE (Fish):
      unlock: Complete Zone 3
      
    FLASH (Firefly):
      unlock: Complete Zone 7
      
    PHASE (Ghost Gecko):
      unlock: Complete Zone 14
```

### 32.5.3 Blocker Characters

```
BLOCKER_ROSTER:

  STARTER_BLOCKERS:
  
    BOULDER (Turtle):
      health: Very High
      damage: High
      ability_1: "Shell Shield" - Block all frontal damage
      ability_2: "Ground Pound" - Area stun
      ultimate: "Fortress" - Immobile but invincible
      
    SPIKE (Porcupine):
      health: High
      damage: High
      ability_1: "Quill Shot" - Ranged attack
      ability_2: "Spike Trap" - Place damaging trap
      ultimate: "Quill Storm" - Area damage burst
      
    CRUNCH (Crocodile):
      health: High
      damage: Very High
      ability_1: "Jaw Snap" - Powerful melee
      ability_2: "Tail Sweep" - Knockback attack
      ultimate: "Death Roll" - Grab and eliminate
      
  UNLOCKABLE_BLOCKERS:
  
    VOLT (Electric Eel):
      unlock: Complete Zone 6
      
    BLAZE (Salamander):
      unlock: Complete Zone 11
      
    TITAN (Gorilla):
      unlock: Complete Zone 16
```

### 32.5.4 Booster Characters

```
BOOSTER_ROSTER:

  STARTER_BOOSTERS:
  
    PATCH (Frog Doctor):
      support: Healing
      ability_1: "Heal Pulse" - Heal nearby allies
      ability_2: "Cleanse" - Remove debuffs
      ultimate: "Rejuvenation" - Full team heal
      
    SCOUT (Owl):
      support: Vision/Intel
      ability_1: "Reveal" - Show nearby enemies
      ability_2: "Mark Target" - Highlighted enemy takes more damage
      ultimate: "All-Seeing" - Map-wide enemy reveal
      
    TEMPO (Rabbit DJ):
      support: Speed/Buffs
      ability_1: "Hype Beat" - Speed boost aura
      ability_2: "Drop the Bass" - Slow enemies in area
      ultimate: "Rave Mode" - Massive team buff
      
  UNLOCKABLE_BOOSTERS:
  
    SHIELD (Armadillo):
      unlock: Complete Zone 5
      
    MIRAGE (Chameleon):
      unlock: Complete Zone 10
      
    COSMIC (Story Character):
      unlock: Collect all Cosmic Crystals
```

## 32.6 Arena Maps

### 32.6.1 Map Design Philosophy

```
MAP_DESIGN:

  style: Boss arena-like (no curved world)
  terrain: Varied elevation, structures
  camera: Dynamic third-person
  
  LAYOUT_ELEMENTS:
    bases: Team spawn/bank areas
    lanes: Paths between bases
    jungle: Side areas with atoms/relics
    center: Contested high-value area
    
  MAP_SIZE:
    small: 2-3 minute traversal
    medium: 3-4 minute traversal
    large: 4-5 minute traversal
```

### 32.6.2 Map List

```
ARENA_MAPS:

  STARTER_MAPS:
  
    TROPICA_ARENA:
      theme: Tropical village
      size: Medium
      relics: 2
      features: Water hazards, vine shortcuts
      
    CYBER_DOME:
      theme: Digital arena
      size: Medium
      relics: 3
      features: Teleporters, data streams
      
    VOLCANIC_BASIN:
      theme: Lava arena
      size: Large
      relics: 3
      features: Lava rivers, eruption events
      
  UNLOCKABLE_MAPS:
  
    FROZEN_COLOSSEUM:
      unlock: Complete Zone 8
      
    SKY_FORTRESS:
      unlock: Complete Zone 15
      
    SYNDICATE_ARENA:
      unlock: Complete story mode
      
    COSMIC_VOID:
      unlock: 100% completion
      
  MINIMUM_MAPS: 8
```

## 32.7 Random Map Events

```
MAP_EVENTS:

  EVENT_SYSTEM:
    frequency: 1-2 events per match
    warning: 10 second announcement
    duration: 30-60 seconds
    
  EVENT_TYPES:
  
    ATOM_RUSH:
      effect: Massive atom spawn in center
      danger: Everyone converges
      
    WEATHER_HAZARD:
      types: Lightning storm, blizzard, sandstorm
      effect: Environmental damage zones
      strategy: Avoid hazard areas
      
    MINI_BOSS:
      spawn: Neutral enemy appears
      defeat_reward: 100 atoms to defeating team
      danger: Powerful enemy
      
    POWER_SURGE:
      effect: All abilities refresh instantly
      chaos: Massive ability usage
      
    GRAVITY_SHIFT:
      effect: Low gravity for duration
      gameplay: Higher jumps, floatier
      
    BLACKOUT:
      effect: Limited visibility
      duration: 30 seconds
      strategy: Rely on sound/minimaps
```

## 32.8 Competitive Progression

### 32.8.1 Battle Pass System

```
BATTLE_PASS:

  cost: FREE (no real money)
  
  PROGRESSION:
    xp_sources:
      - Match completion
      - Match victory
      - Atom deposits
      - Eliminations
      - Objectives completed
      
    levels: 100 per season
    xp_per_level: Scaling (more at higher levels)
    
  REWARDS_PER_TIER:
    common: Every 1-2 levels
    rare: Every 5 levels
    epic: Every 10 levels
    legendary: Level 50, 100
    
  REWARD_TYPES:
    - Character skins
    - Color palettes
    - Victory animations
    - Voice lines
    - Banners/icons
    - Map skins
```

### 32.8.2 Unlock Sources

```
UNLOCK_PROGRESSION:

  CHARACTERS:
    story_mode: Most characters unlock via story
    multiplayer: Some exclusive to MP progression
    achievements: Special unlock conditions
    
  MAPS:
    story_completion: Zone clears unlock maps
    multiplayer_wins: Some via win count
    
  COSMETICS:
    battle_pass: Primary source
    achievements: Special rewards
    medallions: Shop purchases (in-game currency only)
    
  NO_MONETIZATION:
    rule: Zero real-money purchases
    all_content: Earnable through play
```

## 32.9 Bot System

```
BOT_SYSTEM:

  PURPOSE:
    - Fill empty player slots
    - Allow solo competitive play
    - Practice mode
    
  BOT_DIFFICULTY:
    easy: Slow reactions, basic strategy
    medium: Decent reactions, uses abilities
    hard: Fast reactions, coordinates with team
    expert: Near-human performance
    
  BOT_BEHAVIOR:
    scoring: Prioritizes atom collection
    blocking: Seeks out enemies
    boosting: Supports nearby allies
    
  TEAM_FILL:
    auto: Bots fill when players leave
    manual: Host can add/remove bots
    minimum: At least 2 per team (including players)
```

---

# 33. MULTIPLAYER TECHNICAL

## 33.1 Network Architecture

```
NETWORK_SYSTEM:

  TYPE: Peer-to-peer with host migration
  
  HOST:
    selection: Best connection becomes host
    migration: If host leaves, new host selected
    
  SYNCHRONIZATION:
    type: Client-server (host authoritative)
    tick_rate: 60 Hz
    interpolation: Yes
    
  LATENCY_HANDLING:
    client_prediction: Yes
    lag_compensation: Yes
    max_ping: 200ms (higher = warning)
```

## 33.2 Matchmaking

```
MATCHMAKING:

  MODES:
    quick_play: Random match
    ranked: Skill-based (future feature)
    private: Friends only
    vs_bots: Solo with bots
    
  TEAM_FORMATION:
    solo_queue: Assigned to team
    party: Play with friends
    max_party: 4 (full team)
    
  MATCH_PARAMETERS:
    map_vote: Players vote on map
    random: If no consensus
```

---

**END OF PART 7**

*Next: Part 8 - Level Editor & User Content*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 8: Level Editor & User Content

---

# 34. LEVEL EDITOR OVERVIEW

## 34.1 Editor Philosophy

```
LEVEL_EDITOR_PHILOSOPHY:

  goal: Empower players to create and share content
  scope: 3D Platforming, 2D Sections, Boss Arenas
  excluded: Flying levels
  
  design_principles:
    - Accessible to beginners
    - Powerful for advanced users
    - Integrated with game systems
    - Seamless sharing
```

## 34.2 Editor Scope

```
EDITOR_CAPABILITIES:

  SUPPORTED:
    ✓ 3D Platforming levels
    ✓ 2D Side-scrolling sections
    ✓ Boss fight arenas
    ✓ Competitive multiplayer maps
    ✓ Challenge rooms
    
  NOT_SUPPORTED:
    ✗ Flying levels (on-rails pathing)
    ✗ Story cutscenes
    ✗ New enemies/bosses (use existing)
```

---

# 35. EDITOR INTERFACE

## 35.1 Editor Modes

```
EDITOR_MODES:

  BUILD_MODE:
    function: Place and modify objects
    camera: Free-fly
    tools: Tile placement, object placement
    
  TEST_MODE:
    function: Play the level
    camera: Normal gameplay camera
    instant_access: Quick toggle from build
    
  PAINT_MODE:
    function: Apply textures/materials
    tools: Brush, fill, eyedropper
    
  LOGIC_MODE:
    function: Set up triggers and events
    tools: Node connections, scripting
    
  SETTINGS_MODE:
    function: Level properties
    options: Time limits, music, skybox
```

## 35.2 Editor Controls

```
EDITOR_CONTROLS:

  CAMERA:
    WASD / left_stick: Move camera
    right_stick / mouse: Rotate camera
    Q/E: Move up/down
    scroll_wheel: Zoom in/out
    
  SELECTION:
    left_click: Select object
    shift_click: Multi-select
    ctrl_click: Add to selection
    box_select: Drag to select multiple
    
  MANIPULATION:
    G: Move (grab)
    R: Rotate
    S: Scale
    delete: Remove selected
    ctrl_D: Duplicate
    ctrl_Z: Undo
    ctrl_Y: Redo
    
  TOOLS:
    1-9: Quick tool select
    tab: Cycle tools
    space: Confirm placement
```

## 35.3 Editor UI Layout

```
EDITOR_UI:

  ┌─────────────────────────────────────────────────────────┐
  │ [File] [Edit] [View] [Tools] [Test] [Share]    [Help]   │ Menu Bar
  ├─────────┬───────────────────────────────────────┬───────┤
  │         │                                       │       │
  │  TOOL   │                                       │ PROP  │
  │  PANEL  │         VIEWPORT                      │ PANEL │
  │         │         (3D View)                     │       │
  │ [Tiles] │                                       │[Pos]  │
  │ [Items] │                                       │[Rot]  │
  │ [Enemy] │                                       │[Scale]│
  │ [Hazard]│                                       │[Tags] │
  │ [Logic] │                                       │       │
  │         │                                       │       │
  ├─────────┴───────────────────────────────────────┴───────┤
  │ [Grid: On] [Snap: 1.0] [Layer: Default]    [Zoom: 100%] │ Status
  └─────────────────────────────────────────────────────────┘
```

---

# 36. BUILDING TOOLS

## 36.1 Tile System

```
TILE_SYSTEM:

  TILE_TYPES:
  
    GROUND_TILES:
      - Flat floor
      - Slope (various angles)
      - Curved slope
      - Platform (thin)
      - Stairs
      
    WALL_TILES:
      - Vertical wall
      - Angled wall
      - Curved wall
      - Climbable wall
      
    CEILING_TILES:
      - Flat ceiling
      - Angled ceiling
      
    SPECIAL_TILES:
      - Loop section
      - Corkscrew
      - Half-pipe
      - Grind rail path
      
  TILE_PROPERTIES:
    material: Visual appearance
    collision: Solid, pass-through, one-way
    climbable: Can Gina climb it
    slippery: Reduced friction
    
  TILE_SETS:
    per_zone: Themed tile sets
    mixing: Can combine sets
    custom: Import custom (advanced)
```

## 36.2 Object Placement

```
PLACEABLE_OBJECTS:

  COLLECTIBLES:
    rings: Standard, trail, circular
    super_rings: 10-ring value
    medallions: Optional challenge reward
    pixel_atoms: Village builder currency
    
  POWER_UPS:
    item_boxes: Shield, speed, invincibility
    specific_shields: Flame, aqua, electric, wind
    
  INTERACTIVE:
    springs: Various strengths/directions
    dash_pads: Speed boost zones
    bounce_pads: Bouncy surfaces
    zip_lines: Quick traversal
    teleporters: Warp points
    
  HAZARDS:
    spikes: Static damage
    moving_spikes: Timed damage
    fire_jets: Periodic fire
    electric_fields: Shock zones
    crushers: Timing obstacles
    
  ENEMIES:
    all_enemy_types: From main game
    patrol_paths: Customizable routes
    spawn_triggers: Conditional spawning
    
  DECORATIVE:
    props: Visual only objects
    particles: Effect emitters
    lights: Illumination
```

## 36.3 Terrain Tools

```
TERRAIN_TOOLS:

  BRUSH_TOOL:
    function: Paint terrain height
    sizes: 1x1 to 16x16
    shapes: Square, circle, custom
    modes: Raise, lower, smooth, flatten
    
  PATH_TOOL:
    function: Create paths (rails, routes)
    nodes: Click to place, drag to adjust
    smoothing: Automatic curve smoothing
    
  SHAPE_TOOL:
    function: Create primitive shapes
    shapes: Box, sphere, cylinder, ramp
    modifiers: Boolean operations
    
  WATER_TOOL:
    function: Place water volumes
    properties: Depth, current direction
    surface: Visual water plane
```

---

# 37. LOGIC SYSTEM

## 37.1 Trigger System

```
TRIGGER_SYSTEM:

  TRIGGER_TYPES:
  
    AREA_TRIGGER:
      shape: Box, sphere, custom
      activation: Player enters
      options: Once, repeatable, team-specific
      
    TOUCH_TRIGGER:
      activation: Player touches object
      options: Specific object types
      
    TIMER_TRIGGER:
      activation: After X seconds
      options: Loop, delay, random
      
    CONDITION_TRIGGER:
      activation: When condition met
      conditions: Rings > X, enemies defeated, etc.
      
    BUTTON/SWITCH:
      activation: Player interaction
      states: On/Off, hold, toggle
```

## 37.2 Action System

```
ACTION_SYSTEM:

  TRIGGERED_ACTIONS:
  
    SPAWN_ACTIONS:
      spawn_enemy: Create enemy at point
      spawn_item: Create item
      spawn_effect: Visual/audio effect
      
    MOVE_ACTIONS:
      move_object: Translate object
      rotate_object: Rotate object
      path_follow: Move along path
      
    STATE_ACTIONS:
      enable/disable: Toggle objects
      destroy: Remove object
      change_property: Modify values
      
    LEVEL_ACTIONS:
      checkpoint: Set checkpoint
      level_complete: End level
      teleport_player: Move player
      camera_change: Modify camera
      
    AUDIO_ACTIONS:
      play_sound: One-shot audio
      play_music: Change music
      stop_audio: Silence
```

## 37.3 Visual Scripting

```
VISUAL_SCRIPTING:

  NODE_BASED:
    interface: Connect nodes with wires
    flow: Left to right execution
    
  NODE_TYPES:
  
    EVENT_NODES (Red):
      - On Level Start
      - On Trigger Enter
      - On Timer
      - On Button Press
      
    CONDITION_NODES (Yellow):
      - If/Else
      - Compare Values
      - Check State
      
    ACTION_NODES (Blue):
      - Spawn Object
      - Move Object
      - Play Effect
      - Set Variable
      
    VARIABLE_NODES (Green):
      - Get Ring Count
      - Get Timer
      - Custom Variables
      
  EXAMPLE_LOGIC:
    "When player enters trigger AND has 50 rings,
     spawn bridge AND play fanfare"
```

---

# 38. 2D SECTION EDITOR

## 38.1 2D Editor Mode

```
2D_EDITOR_MODE:

  ACTIVATION:
    method: Place 2D transition zone
    editor_view: Switches to 2D perspective
    
  CAMERA:
    view: Side-on (perpendicular)
    scroll: Horizontal and vertical pan
    zoom: In/out
    
  GRID:
    alignment: Pixel-perfect
    snap: Various increments
```

## 38.2 2D-Specific Tools

```
2D_SPECIFIC_TOOLS:

  LAYER_SYSTEM:
    foreground: In front of player
    playfield: Where player exists
    background: Behind player (parallax)
    
  PLATFORM_TYPES:
    solid: Full collision
    one_way: Pass through from below
    moving: Horizontal/vertical paths
    falling: Drops when touched
    
  CLASSIC_ELEMENTS:
    loops: Pre-made loop sections
    s_tubes: Pre-made tube sections
    corkscrews: Spiral platforms
    springs: Directional launchers
    
  BACKGROUND_LAYERS:
    parallax_setup: Multiple scrolling layers
    auto_scroll: Background movement
```

---

# 39. BOSS ARENA EDITOR

## 39.1 Arena Creation

```
ARENA_EDITOR:

  PURPOSE:
    single_player: Custom boss encounters
    multiplayer: Competitive map creation
    
  ARENA_SETUP:
    bounds: Define play area
    spawn_points: Player start locations
    camera_zones: Camera behavior areas
    
  TERRAIN:
    no_curved_world: Standard 3D
    varied_elevation: Hills, platforms
    hazard_zones: Lava, pits, etc.
```

## 39.2 Boss Configuration

```
BOSS_CONFIGURATION:

  BOSS_SELECTION:
    available: All defeated bosses
    placement: Center/designated area
    
  BOSS_MODIFICATIONS:
    health: Adjust hit points
    speed: Attack speed modifier
    patterns: Enable/disable attacks
    
  ARENA_HAZARDS:
    timed_events: Periodic hazards
    phase_triggers: Hazards at health thresholds
```

## 39.3 Multiplayer Arena Conversion

```
MP_ARENA_CONVERSION:

  AUTOMATIC:
    spawn_points: Converted to team spawns
    objectives: Atom spawn locations added
    
  MANUAL_ADDITIONS:
    team_banks: Place deposit zones
    relic_locations: Place objective points
    atom_spawns: Define spawn areas
    
  BALANCE_TOOLS:
    symmetry: Mirror tool
    path_analysis: Distance calculations
    test_bots: AI testing
```

---

# 40. LEVEL PROPERTIES

## 40.1 Level Settings

```
LEVEL_SETTINGS:

  BASIC_INFO:
    level_name: String (max 32 chars)
    description: String (max 256 chars)
    author: Auto-filled
    
  GAMEPLAY:
    level_type: Platforming, 2D, Boss, MP
    difficulty: 1-5 stars
    par_time: Target completion time
    
  VISUALS:
    zone_theme: Select from zones
    skybox: Choose skybox
    music: Select track
    ambient_sounds: Environment audio
    
  RULES:
    ring_requirement: Minimum to finish
    time_limit: Optional countdown
    checkpoint_rules: Frequency, placement
```

## 40.2 Level Validation

```
LEVEL_VALIDATION:

  AUTOMATIC_CHECKS:
    - Player spawn exists
    - Level exit exists
    - Path to exit possible
    - No stuck spots detected
    - Performance within limits
    
  WARNINGS:
    - Extremely long level
    - No checkpoints
    - Very few rings
    - Excessive enemies
    
  REQUIRED_TO_SHARE:
    - Pass all automatic checks
    - Creator has completed level
```

---

# 41. SHARING SYSTEM

## 41.1 Level Sharing

```
LEVEL_SHARING:

  UPLOAD:
    requirement: Pass validation
    requirement: Creator completion
    process:
      1. Level packaged
      2. Thumbnail generated
      3. Uploaded to server
      4. Assigned level code
      
  LEVEL_CODES:
    format: XXXX-XXXX-XXXX
    sharing: Copy/paste, QR code
    
  METADATA:
    - Title and description
    - Creator name
    - Creation date
    - Play count
    - Rating
    - Difficulty
```

## 41.2 Level Browser

```
LEVEL_BROWSER:

  CATEGORIES:
    new: Recently uploaded
    popular: Most played
    top_rated: Highest ratings
    featured: Staff picks
    friends: Created by friends
    
  FILTERS:
    type: Platforming, 2D, Boss, MP
    difficulty: 1-5 stars
    length: Short, medium, long
    theme: By zone aesthetic
    
  SEARCH:
    by_name: Text search
    by_code: Direct code entry
    by_creator: Find creator's levels
```

## 41.3 Ratings and Comments

```
COMMUNITY_FEATURES:

  RATINGS:
    type: 5-star system
    requirement: Must complete to rate
    display: Average rating, count
    
  COMMENTS:
    post: After playing
    moderation: Report system
    replies: Threaded comments
    
  CREATOR_STATS:
    total_plays: All levels combined
    average_rating: Across levels
    follower_count: Players following
```

---

# 42. EDITOR UNLOCKS

## 42.1 Unlock Progression

```
EDITOR_UNLOCKS:

  TILES:
    unlock_method: Complete zones
    zone_1_complete: Tropical tiles
    zone_7_complete: Snow tiles
    all_zones: All tile sets
    
  OBJECTS:
    enemy_unlock: Defeat enemy type
    boss_unlock: Defeat boss
    hazard_unlock: Encounter hazard
    
  FEATURES:
    basic_editor: Unlocked from start
    logic_system: Complete 10 levels
    2d_editor: Complete 2D section
    boss_editor: Defeat 5 bosses
    mp_editor: Play 10 MP matches
    
  COSMETIC:
    themes: Medallion purchases
    music_tracks: Story progression
    skyboxes: Zone completion
```

## 42.2 Medallion Shop (Editor)

```
EDITOR_SHOP:

  CURRENCY: Medallions
  
  PURCHASABLE:
    extra_themes: 10 medallions each
    special_objects: 5-20 medallions
    music_packs: 15 medallions
    prop_packs: 10 medallions
    
  NOTE: All gameplay items free, cosmetics cost medallions
```

---

# 43. EDITOR TECHNICAL

## 43.1 Performance Limits

```
EDITOR_LIMITS:

  OBJECT_COUNTS:
    max_tiles: 10,000
    max_objects: 1,000
    max_enemies: 100
    max_triggers: 200
    
  LEVEL_SIZE:
    max_dimensions: 1000 x 1000 x 500 units
    min_dimensions: 50 x 50 x 20 units
    
  FILE_SIZE:
    max_level_size: 10 MB
    recommended: Under 5 MB
```

## 43.2 Save Format

```
LEVEL_SAVE_FORMAT:

  FORMAT: Custom binary + JSON metadata
  
  CONTENTS:
    header: Version, metadata
    geometry: Tile data, terrain
    objects: Placed objects, properties
    logic: Trigger/action connections
    settings: Level configuration
    
  COMPRESSION: Yes (reduce file size)
  
  BACKWARDS_COMPATIBILITY:
    policy: Support 2 major versions back
    migration: Auto-update old levels
```

---

**END OF PART 8**

*Next: Part 9 - Village Builder Side-Mode*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 9: Village Builder Side-Mode

---

# 44. VILLAGE BUILDER OVERVIEW

## 44.1 Side-Mode Philosophy

```
VILLAGE_BUILDER_PHILOSOPHY:

  inspiration: "Chao Garden (Sonic Adventure)"
  genre: Tycoon/Civilization Builder (simplified)
  
  purpose:
    - Provide gameplay variety
    - Create progression feedback loop
    - Reward story mode play
    - Add long-term engagement
    
  core_loop:
    1. Play story mode → Earn Pixel Atoms
    2. Spend atoms in village → Build structures
    3. Complete missions → Unlock content
    4. Content unlocks → Use in story/multiplayer
```

## 44.2 Narrative Context

```
VILLAGE_STORY:

  PREMISE:
    Gina's home village (Tropica Village) was destroyed by the 
    Imperion Syndicate. As she rescues tribe members throughout 
    her adventure, they need a new home.
    
    The Village Builder represents rebuilding their community
    in a safe zone within Gecko Grid.
    
  PROGRESSION:
    early_game: Small camp with few survivors
    mid_game: Growing village with structures
    late_game: Thriving community
    end_game: Restored to former glory (and beyond)
```

---

# 45. VILLAGE MECHANICS

## 45.1 Resource System

```
RESOURCE_SYSTEM:

  PRIMARY_CURRENCY: Pixel Atoms
  
  EARNING_ATOMS:
    story_levels: 10-50 per level
    boss_defeats: 100-500 per boss
    ring_conversion: 10 rings = 1 atom (at level end)
    multiplayer: 5-20 per match
    
  SPENDING_ATOMS:
    structures: 50-5000 atoms
    upgrades: 25-1000 atoms
    decorations: 10-100 atoms
    
  ATOM_TRANSFER:
    automatic: Atoms added when entering village
    manual: Can store atoms in "bank" structure
    cap: No maximum
```

## 45.2 Population System

```
POPULATION_SYSTEM:

  VILLAGERS:
    source: Rescued tribe members from story
    unlock: Story progression
    total_possible: ~50 villagers
    
  POPULATION_NEEDS:
    housing: Each villager needs a home
    food: Food structures support X villagers
    happiness: Entertainment/religious structures
    
  POPULATION_EFFECTS:
    low_happiness: Villagers work slower
    high_happiness: Bonus production
    overcrowding: Negative mood effects
    
  VILLAGER_RESCUE_SCHEDULE:
    zone_1: 3 villagers (including Chip)
    zone_2-6: 2-3 per zone
    zone_7-12: 2-3 per zone
    zone_13-18: 2-3 per zone
    total: ~50 villagers
```

## 45.3 Building System

```
BUILDING_SYSTEM:

  PLACEMENT:
    grid_based: Snap to grid
    rotation: 4 directions
    terrain: Must be on buildable area
    
  BUILDING_PROCESS:
    1. Select structure from menu
    2. Place on valid location
    3. Pay Pixel Atom cost
    4. Construction instant (no wait times)
    
  BUILDING_MANAGEMENT:
    move: Relocate existing buildings
    upgrade: Improve building tier
    demolish: Remove (partial refund)
```

---

# 46. STRUCTURE TYPES

## 46.1 Residential Structures

```
RESIDENTIAL_STRUCTURES:

  SMALL_HUT:
    capacity: 2 villagers
    cost: 100 atoms
    unlock: Start
    
  MEDIUM_HOUSE:
    capacity: 4 villagers
    cost: 300 atoms
    unlock: Zone 3 complete
    
  LARGE_DWELLING:
    capacity: 6 villagers
    cost: 600 atoms
    unlock: Zone 7 complete
    
  APARTMENT_BLOCK:
    capacity: 10 villagers
    cost: 1200 atoms
    unlock: Zone 12 complete
    
  ELDER'S_MANOR:
    capacity: 4 villagers
    bonus: +10% village happiness
    cost: 2000 atoms
    unlock: Rescue Elder Pixel
```

## 46.2 Food Structures

```
FOOD_STRUCTURES:

  BERRY_BUSH_FARM:
    feeds: 5 villagers
    cost: 150 atoms
    unlock: Start
    
  FISHING_HUT:
    feeds: 10 villagers
    cost: 400 atoms
    unlock: Zone 3 complete
    requirement: Near water
    
  ORCHARD:
    feeds: 15 villagers
    cost: 700 atoms
    unlock: Zone 6 complete
    
  COMMUNITY_KITCHEN:
    feeds: 25 villagers
    bonus: +5% happiness
    cost: 1500 atoms
    unlock: Zone 10 complete
    
  GRAND_FEAST_HALL:
    feeds: 40 villagers
    bonus: +15% happiness
    cost: 3000 atoms
    unlock: Zone 15 complete
```

## 46.3 Happiness Structures

```
HAPPINESS_STRUCTURES:

  CAMPFIRE:
    effect: +5 happiness (small radius)
    cost: 50 atoms
    unlock: Start
    
  PLAYGROUND:
    effect: +10 happiness
    cost: 200 atoms
    unlock: Zone 2 complete
    
  MUSIC_STAGE:
    effect: +15 happiness
    cost: 500 atoms
    unlock: Zone 5 complete
    
  TRIBAL_SHRINE:
    effect: +20 happiness
    bonus: Unlocks special missions
    cost: 1000 atoms
    unlock: Zone 8 complete
    
  GRAND_TEMPLE:
    effect: +30 happiness
    bonus: Major happiness boost
    cost: 3000 atoms
    unlock: Zone 14 complete
    
  FESTIVAL_GROUNDS:
    effect: +25 happiness
    special: Enables village festivals
    cost: 2500 atoms
    unlock: Zone 11 complete
```

## 46.4 Production Structures

```
PRODUCTION_STRUCTURES:

  WORKSHOP:
    function: Produces decorations over time
    cost: 300 atoms
    unlock: Zone 4 complete
    
  TRAINING_GROUND:
    function: Unlocks character abilities faster
    bonus: +10% XP gain in story mode
    cost: 800 atoms
    unlock: Zone 7 complete
    
  RESEARCH_LAB:
    function: Unlocks advanced structures
    bonus: Required for tier 3 buildings
    cost: 1500 atoms
    unlock: Zone 10 complete
    
  ATOM_REFINERY:
    function: Converts excess rings to atoms
    rate: 100 rings = 15 atoms (improved rate)
    cost: 2000 atoms
    unlock: Zone 13 complete
```

## 46.5 Special Structures

```
SPECIAL_STRUCTURES:

  VILLAGE_BANK:
    function: Store atoms safely
    bonus: +5% atom income
    cost: 500 atoms
    unlock: Zone 5 complete
    
  PORTAL_STATION:
    function: Quick travel to/from village
    cost: 1000 atoms
    unlock: Zone 8 complete
    
  TROPHY_HALL:
    function: Display achievements
    bonus: View collected medallions, crystals
    cost: 800 atoms
    unlock: Zone 6 complete
    
  MULTIPLAYER_ARENA:
    function: Access competitive mode from village
    bonus: Multiplayer queue while in village
    cost: 1500 atoms
    unlock: Play 20 MP matches
    
  COSMIC_MONUMENT:
    function: Displays Cosmic Crystals
    bonus: Cosmic Mode visual effects in village
    cost: 5000 atoms
    unlock: Collect all 8 crystals
```

## 46.6 Decorations

```
DECORATIONS:

  PURPOSE:
    - Visual customization
    - Small happiness boosts
    - No functional requirement
    
  CATEGORIES:
    plants: Trees, flowers, bushes
    statues: Tribal art, character statues
    paths: Walkways, roads
    lights: Torches, lanterns
    water: Fountains, ponds
    
  COST_RANGE: 10-100 atoms each
  
  UNLOCKS:
    story_progression: Zone themes unlock
    medallions: Special decorations
    achievements: Unique items
```

---

# 47. MISSION SYSTEM

## 47.1 Mission Types

```
MISSION_TYPES:

  POPULATION_MISSIONS:
    example: "Reach 10 villagers"
    reward: Unlock new structure
    
  BUILDING_MISSIONS:
    example: "Build 5 houses"
    reward: Atoms, decorations
    
  HAPPINESS_MISSIONS:
    example: "Achieve 80% happiness"
    reward: Special structure unlock
    
  COLLECTION_MISSIONS:
    example: "Collect 1000 total atoms"
    reward: Cosmetic items
    
  STORY_LINKED_MISSIONS:
    example: "Rescue Marina"
    reward: Unique character interaction
```

## 47.2 Mission Rewards

```
MISSION_REWARDS:

  ATOM_REWARDS:
    small_mission: 50-100 atoms
    medium_mission: 200-500 atoms
    large_mission: 1000+ atoms
    
  UNLOCK_REWARDS:
    structures: New building types
    decorations: Special items
    cosmetics: Story/MP unlocks
    
  STORY_REWARDS:
    character_skins: For rescued villagers
    multiplayer_characters: Unlock for MP
    
  PROGRESSION_TRACKING:
    display: Mission log in village menu
    notification: Alert when completable
```

## 47.3 Mission Examples

```
MISSION_EXAMPLES:

  EARLY_MISSIONS:
    "First Steps"
      - Build your first structure
      - Reward: 50 atoms
      
    "Home Sweet Home"
      - House 5 villagers
      - Reward: Medium House unlock
      
    "Community Meal"
      - Build a food structure
      - Reward: 100 atoms
      
  MID_MISSIONS:
    "Growing Community"
      - Reach 20 population
      - Reward: Apartment Block unlock
      
    "Happy Village"
      - Achieve 60% happiness
      - Reward: Festival Grounds unlock
      
    "Chip's Workshop"
      - Build Workshop after rescuing Chip
      - Reward: Multiplayer character unlock
      
  LATE_MISSIONS:
    "Thriving Metropolis"
      - Reach 40 population
      - Reward: Grand Temple unlock
      
    "Paradise Restored"
      - Achieve 90% happiness
      - Reward: Cosmic Monument unlock
      
    "Master Builder"
      - Build one of every structure
      - Reward: Special decoration set
```

---

# 48. VILLAGER SYSTEM

## 48.1 Villager Properties

```
VILLAGER_PROPERTIES:

  BASIC_INFO:
    name: Unique name
    species: Various animals
    role: Rescued tribe member
    
  STATS:
    happiness: 0-100%
    housed: true/false
    fed: true/false
    
  BEHAVIOR:
    idle: Wander village
    working: At assigned structure
    socializing: Interacting with others
    sleeping: In their home (night)
```

## 48.2 Named Villagers

```
NAMED_VILLAGERS:

  STORY_CHARACTERS:
    These villagers have dialogue and special interactions.
    
    CHIP:
      rescue: Zone 1
      role: Tech expert
      special: Provides tutorial hints
      
    ELDER_PIXEL:
      rescue: Zone 2
      role: Village leader
      special: Gives story missions
      
    MARINA:
      rescue: Zone 4
      
    FROST:
      rescue: Zone 7
      role: Northern visitor
      
  GENERIC_VILLAGERS:
    appearance: Randomized from pool
    names: Randomized from name list
    dialogue: Generic greetings
```

## 48.3 Villager Interactions

```
VILLAGER_INTERACTIONS:

  TALK:
    action: Approach and interact
    result: Dialogue, hints, gratitude
    
  GIFT:
    action: Give items to villagers
    result: Happiness boost, special dialogue
    
  ASSIGN:
    action: Assign to structure
    result: Villager works there
    bonus: Some structures work better staffed
```

---

# 49. VILLAGE PROGRESSION

## 49.1 Village Tiers

```
VILLAGE_TIERS:

  TIER_1: "Refugee Camp"
    population: 0-10
    structures: Basic only
    visual: Sparse, temporary look
    
  TIER_2: "Small Settlement"
    population: 11-20
    structures: Medium tier unlocked
    visual: More permanent structures
    
  TIER_3: "Growing Village"
    population: 21-35
    structures: Large tier unlocked
    visual: Established community
    
  TIER_4: "Thriving Community"
    population: 36-50
    structures: All unlocked
    visual: Prosperous village
    
  TIER_5: "New Tropica" (Final)
    population: 50 (all rescued)
    requirement: 90%+ happiness
    visual: Paradise restored
    reward: Special ending scene
```

## 49.2 Story Integration

```
STORY_INTEGRATION:

  UNLOCKS_FROM_STORY:
    zone_completion: New structures
    boss_defeat: Special structures
    villager_rescue: Population increase
    crystal_collection: Cosmic structures
    
  UNLOCKS_TO_STORY:
    training_ground: +10% XP in story
    atom_refinery: Better atom conversion
    portal_station: Quick village access
    
  UNLOCKS_TO_MULTIPLAYER:
    specific_missions: Character unlocks
    building_count: Map unlocks
    tier_progression: Cosmetic rewards
```

---

# 50. VILLAGE ACCESS

## 50.1 Entry Methods

```
VILLAGE_ACCESS:

  FROM_LEVEL:
    trigger: Collect "Village Key" item in level
    effect: Auto-enter village after level
    key_locations: 1 per zone, hidden
    
  FROM_MENU:
    location: Main menu option
    requirement: Unlocked after Zone 1
    
  FROM_WORLD_MAP:
    location: Village node on map
    quick_access: Direct travel
    
  PORTAL_STATION:
    requirement: Build in village
    effect: Warp from any level checkpoint
```

## 50.2 Exit Methods

```
VILLAGE_EXIT:

  PAUSE_MENU:
    option: "Leave Village"
    destination: World map or main menu
    
  PORTAL_STATION:
    option: Return to last level
    destination: Level checkpoint
    
  MULTIPLAYER_ARENA:
    option: Enter MP queue
    destination: Matchmaking
```

## 50.3 Time in Village

```
VILLAGE_TIME:

  NO_TIME_LIMIT:
    stay: As long as desired
    no_penalties: No urgency
    
  DAY_NIGHT_CYCLE:
    visual: Gradual lighting change
    duration: 10 minutes per cycle
    effects: Villager behavior changes
    
  PRODUCTION:
    passive: Some structures produce over time
    collection: Gather resources when visiting
```

---

# 51. VILLAGE TECHNICAL

## 51.1 Village Save Data

```
VILLAGE_SAVE:

  STORED_DATA:
    structures: Type, position, rotation, level
    villagers: Name, stats, assignment
    resources: Atom count, production timers
    missions: Completed, in-progress
    decorations: All placed items
    stats: Happiness, population, tier
    
  SAVE_FREQUENCY:
    auto_save: Every structure change
    manual: Pause menu option
```

## 51.2 Performance Considerations

```
VILLAGE_PERFORMANCE:

  OBJECT_LIMITS:
    max_structures: 100
    max_decorations: 500
    max_villagers: 50 (story limited)
    
  LOD_SYSTEM:
    distant: Low detail models
    near: Full detail
    
  CULLING:
    off_screen: Not rendered
    far_objects: Simplified
```

---

**END OF PART 9**

*Next: Part 10 - UI, HUD, Menus, Audio, and Technical Specifications*
# GINA THE GECKO - GAME DESIGN DOCUMENT
## Part 10: UI, HUD, Menus, Audio & Technical Specifications

---

# 52. HUD DESIGN

## 52.1 Main Gameplay HUD

```
MAIN_HUD_LAYOUT:

  ┌─────────────────────────────────────────────────────────┐
  │ [RINGS: 000]              [TIME: 0:00:00]               │
  │ [SCORE: 00000000]                          [BOOST: ▓▓▓] │
  │                                                         │
  │                     (GAMEPLAY AREA)                     │
  │                                                         │
  │ [POWER-UP]                              [CRYSTAL: 0/8]  │
  └─────────────────────────────────────────────────────────┘

  ELEMENTS:
    rings: Top-left, animated ring icon
    score: Below rings
    time: Top-center
    boost_meter: Top-right, fills left to right
    power_up: Bottom-left, shows current shield/item
    crystal_count: Bottom-right (when applicable)
```

## 52.2 HUD Variations

```
HUD_VARIATIONS:

  BOSS_HUD:
    additions: Boss health bar, boss name, phase indicator
    removals: Time (optional)
      
  FLYING_HUD:
    additions: Ship health, weapon power, bomb count, reticle
    changes: Cockpit-style frame (optional)
```

---

# 53. MENU SYSTEMS

## 53.1 Main Menu

```
MAIN_MENU_OPTIONS:
  - STORY MODE
  - MULTIPLAYER
  - VILLAGE
  - LEVEL EDITOR
  - OPTIONS
  - EXTRAS
```

## 53.2 Options Menu

```
OPTIONS_MENU:

  AUDIO:
    master_volume: 0-100%
    music_volume: 0-100%
    sfx_volume: 0-100%
    voice_volume: 0-100%
    
  VIDEO:
    resolution: Supported resolutions
    display_mode: Fullscreen, Windowed, Borderless
    vsync: On/Off
    frame_rate_cap: 60, 120, Unlimited
    
  GRAPHICS:
    quality_preset: Low, Medium, High, Ultra
    retro_intensity: 0-100% slider
    curved_world_intensity: 0-100% slider
    
  GAMEPLAY:
    difficulty: Easy, Normal, Hard
    camera_sensitivity: 0-100%
    vibration: On/Off
    
  ACCESSIBILITY:
    colorblind_mode: Off, Protanopia, Deuteranopia, Tritanopia
    screen_shake: 0-100%
    flash_reduction: On/Off
    subtitle_size: Small, Medium, Large
```

---

# 54. AUDIO DESIGN

## 54.1 Music System

```
MUSIC_SYSTEM:

  ZONE_THEMES:
    each_zone: Unique main theme
    variations: Act 1, Act 2, Boss versions
    
  SPECIAL_TRACKS:
    invincibility: Override track
    boss_phases: Escalating intensity
    victory: Fanfare
```

## 54.2 Sound Effects

```
SFX_CATEGORIES:

  PLAYER: Jump, spin dash, homing attack, boost, damage
  COLLECTIBLES: Ring, power-up, medallion
  ENEMIES: Alert, attack, defeat
  ENVIRONMENT: Springs, checkpoints, doors
  UI: Navigate, select, back
```

---

# 55. VISUAL STYLE SPECIFICATIONS

## 55.1 Retro Shader Defaults

```
RETRO_SHADER_DEFAULTS:

  vertex_jitter: 0.35 (35%)
  affine_texture: 0.35 (35%)
  color_depth: 15-bit
  dithering: Ordered 4x4
  vertex_lighting: Gouraud, half-lambert
  fog: Zone-dependent
  render_scale: 0.75 (75%)
```

## 55.2 Curved World Defaults

```
CURVED_WORLD_DEFAULTS:

  STANDARD_3D:
    horizontal_curve: 0.15
    vertical_curve: 0.08
    
  2D_SECTIONS:
    horizontal_curve: 0.0
    vertical_curve: 0.10 (downward bend)
    
  BOSS_ARENAS: DISABLED
  FLYING_LEVELS: DISABLED
```

---

# 56. TECHNICAL SPECIFICATIONS

## 56.1 Target Hardware

```
MINIMUM_SPECS:
  os: Windows 10
  processor: Intel Core i3 / AMD Ryzen 3
  memory: 4 GB RAM
  graphics: GTX 750 Ti / RX 460
  storage: 5 GB

RECOMMENDED_SPECS:
  os: Windows 10/11
  processor: Intel Core i5 / AMD Ryzen 5
  memory: 8 GB RAM
  graphics: GTX 1060 / RX 580
  storage: 10 GB SSD
```

## 56.2 Engine Specifications

```
ENGINE: Godot 4.5
LANGUAGE: GDScript (primary), C# (performance-critical)
RENDERER: Forward+ (Vulkan), Compatibility fallback (OpenGL)
PHYSICS: Godot Physics with custom character controller
TICK_RATE: 60 Hz
```

---

# 57. ACCESSIBILITY FEATURES

```
ACCESSIBILITY:

  VISUAL:
    colorblind_modes: Protanopia, Deuteranopia, Tritanopia
    high_contrast_hud: Available
    scalable_text: Small to Extra Large
    motion_reduction: Adjustable screen shake, flash reduction
    
  AUDIO:
    full_subtitles: Dialogue and optional sound captions
    mono_audio: Available
    visual_sound_cues: Direction indicators
    
  CONTROLS:
    full_remapping: All inputs customizable
    presets: Default, Alternative, One-handed
    timing_assists: Adjustable input windows
    aim_assist: Homing attack leniency
    
  DIFFICULTY:
    damage_reduction: Take less damage
    infinite_boost: Always have boost available
    invincibility_mode: Cannot die (optional)
```

---

# 58. DEVELOPMENT ROADMAP

## 58.1 Phase Overview

```
DEVELOPMENT_PHASES:

  PHASE_1: Core Foundation (3-4 months)
    - Core 3D platforming mechanics
    - Character controller
    - Curved world shader
    - Retro visual system
    - 3 playable zones (tutorial + 2)
    - Basic enemy system
    - Ring and power-up system
    
  PHASE_2: Gameplay Variety (3-4 months)
    - 2D section system
    - Boss encounter framework
    - Flying level gameplay
    - 6 additional zones
    
  PHASE_3: Content Expansion (4-5 months)
    - Remaining zones (9 zones)
    - All boss encounters
    - Bonus stages (Pool, Pinball)
    - Special stages (Cosmic Crystals)
    - Full story implementation
    
  PHASE_4: Multiplayer (3-4 months)
    - Co-op campaign
    - Competitive mode
    - Character roster (18 characters)
    - Arena maps
    - Matchmaking system
    
  PHASE_5: Additional Content (3-4 months)
    - Village builder
    - Level editor
    - Community features
    - Polish and optimization
    
  PHASE_6: Launch Preparation (2-3 months)
    - Bug fixing
    - Balance tuning
    - Localization
    - Marketing materials
    - Platform certification
    
  TOTAL_ESTIMATE: 18-24 months
```

## 58.2 Priority Features

```
PRIORITY_MATRIX:

  CRITICAL (Must Have):
    - Core platforming gameplay
    - 18 zones with levels
    - All gameplay modes (3D, 2D, Boss)
    - Ring and power-up systems
    - Cosmic Crystal system
    - Story mode completion
    
  HIGH (Should Have):
    - Alternative gameplay (Flying)
    - Bonus stages
    - Co-op multiplayer
    - Basic level editor
    
  MEDIUM (Nice to Have):
    - Competitive multiplayer
    - Village builder
    - Full character roster
    - Community level sharing
    
  LOW (Future Content):
    - Additional zones (DLC potential)
    - New characters
    - Advanced editor features
    - Seasonal events
```

---

# 59. GLOSSARY

```
GLOSSARY:

  COSMIC_CRYSTAL: 
    One of 8 collectible gems that unlock Cosmic Mode
    
  COSMIC_MODE: 
    Super transformation granting invincibility and flight
    
  CURVED_WORLD: 
    Fisheye lens shader effect bending world around camera
    
  GECKO_GRID: 
    The VR world where the game takes place
    
  GOURAUD_SHADING: 
    PS1-era vertex lighting technique
    
  IMPERION_SYNDICATE: 
    The antagonist faction of criminal hackers
    
  MEDALLION: 
    Collectible currency for unlocking extras
    
  PIXEL_ATOMS: 
    Currency for village building mode
    
  RETRO_INTENSITY: 
    Adjustable level of PS1/Saturn visual effects
    
  STOKE_METER: 
    
  TROPICA_VILLAGE: 
    Gina's home village, destroyed at game start
```

---

# 60. DOCUMENT CHANGELOG

```
CHANGELOG:

  VERSION_1.0 (Current):
    - Initial comprehensive GDD
    - All 10 parts complete
    - Full gameplay systems documented
    - Zone structure finalized
    - Multiplayer systems detailed
    - Technical specifications included
    
  FUTURE_UPDATES:
    - Balance values will be tuned during development
    - Additional content may be added
    - Systems may be simplified or expanded based on testing
```

---

# APPENDIX A: QUICK REFERENCE

## A.1 Control Scheme Summary

```
PLATFORMING_CONTROLS:
  Move: Left Stick / WASD
  Jump: A / Space
  Spin Dash: B (hold) / Shift
  Homing Attack: A (air) / Space (air)
  Boost: RT / Mouse1
  
FLYING_CONTROLS:
  Move: Left Stick / WASD
  Shoot: A / Space
  Barrel Roll: LB/RB / Shift/E
  Bomb: Y / Q
```

## A.2 Collectible Summary

```
COLLECTIBLES:
  Rings: Health, score, bonus stage access
  Medallions: Unlock extras (Pool bonus stage)
  Pixel Atoms: Village currency
  Cosmic Crystals: 8 total, unlock Cosmic Mode
  Power-ups: Shields, invincibility, speed
```

## A.3 Mode Summary

```
GAMEPLAY_MODES:
  3D Platforming: Main gameplay, curved world
  2D Sections: Side-scrolling, all abilities
  Boss Fights: 3-phase encounters, no curved world
  Flying: Star Fox style, on-rails shooter
  Pool Bonus: Billiards puzzle
  Pinball Bonus: Prize collection
  Special Stage: Timed crystal hunt
  Village Builder: Tycoon side-mode
  Co-op: 2-player split-screen campaign
  Competitive: 4v4 Pixel Atom collection
```

---

**END OF PART 10**

**END OF GAME DESIGN DOCUMENT**

---

*Document Version: 1.0*
*Game: Gina the Gecko*
*Engine: Godot 4.5*
*Total Parts: 10*
