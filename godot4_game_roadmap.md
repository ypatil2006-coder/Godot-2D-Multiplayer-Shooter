# Godot 4 — 2D Local Multiplayer Game: Production Roadmap

> Spider-Man-swing combat arena · 4-player split-screen · Arch Linux · GDScript

---

## Part 1 — Architecture Decisions (Before Writing One Line)

### Why These Choices Matter First

Every performance problem, every refactor spiral, and every spaghetti mess in solo game dev traces back to an architecture decision made too casually in Week 1. Lock these in before prototyping.

**Player node:** `CharacterBody2D`, not `RigidBody2D`. You need deterministic movement control. `RigidBody2D` fights you on every frame when you want precise feel. Apply physics manually via `velocity` and `move_and_slide()`.

**Grapple physics:** Single anchor point + impulse-based velocity manipulation, not `Joint2D`. Rope joints in Godot 2D simulate wrong for gameplay; you get oscillation artifacts and feel nothing like Spider-Man. Fake the swing with a custom constraint: compute the tangent of the circle whose center is the anchor, redirect velocity along that tangent each physics frame, and apply a centripetal pull force. This is 30 lines of GDScript and feels better than any joint.

**Split-screen:** Four `SubViewport` nodes inside `SubViewportContainer` nodes, arranged in a 2×2 `GridContainer`. Each `SubViewport` owns one `Camera2D`. This is the only correct approach in Godot 4 — sharing a single viewport with offset cameras causes rendering artifacts and kills batching.

**Input:** Four separate `InputMap` action sets (player1_jump, player2_jump, etc.) bound to joypad device IDs 0–3. Never use `Input.get_joy_axis()` directly in player scripts; always route through your `InputHandler` component with device ID baked in.

**Signals over direct calls:** Every cross-system event uses signals. `Player` never directly touches `HUD`. `GameManager` never directly touches `Player`. This keeps modules swappable and prevents debugging nightmares.

---

## Part 2 — Folder Structure

```
res://
├── autoloads/
│   ├── GameManager.gd        # Round state, scores, match flow
│   ├── InputRouter.gd        # Joypad assignment, deadzone config
│   └── AudioManager.gd       # Pooled audio bus
│
├── scenes/
│   ├── game/
│   │   ├── Game.tscn          # Root scene: GameManager + Viewports
│   │   ├── SplitScreen.tscn   # 4x SubViewportContainers
│   │   └── HUD.tscn           # Overlay scores/kill feed
│   │
│   ├── player/
│   │   ├── Player.tscn        # CharacterBody2D + all components
│   │   ├── GrappleHook.tscn   # RayCast2D + Line2D + physics logic
│   │   └── Bullet.tscn        # Area2D, pooled
│   │
│   ├── maps/
│   │   ├── MapBase.tscn       # TileMapLayer + spawn points + bounds
│   │   ├── Arena01.tscn
│   │   └── Arena02.tscn
│   │
│   └── ui/
│       ├── MainMenu.tscn
│       └── PauseMenu.tscn
│
├── scripts/
│   ├── player/
│   │   ├── PlayerMovement.gd
│   │   ├── PlayerGrapple.gd
│   │   ├── PlayerShoot.gd
│   │   └── PlayerHealth.gd
│   ├── weapons/
│   │   └── BulletPool.gd
│   └── map/
│       └── SpawnManager.gd
│
├── assets/
│   ├── sprites/               # PNG, max 512x512 atlas
│   ├── tilemaps/              # TileSet .tres files
│   ├── audio/
│   │   ├── sfx/               # OGG, mono, 22kHz
│   │   └── music/
│   └── fonts/                 # .ttf, 1-2 max
│
└── project.godot
```

**Rule:** Scripts never live inside `scenes/`. A scene references a script from `scripts/`. This prevents the common mistake of duplicated logic across instanced scenes.

---

## Part 3 — Scene & Node Hierarchy

### Game Root (`Game.tscn`)
```
Game (Node)
├── GameManager (Node)          ← autoload ref or in-scene controller
├── SplitScreen (Control)
│   ├── ViewportGrid (GridContainer)
│   │   ├── VP1 (SubViewportContainer)
│   │   │   └── SubViewport1
│   │   │       ├── Player1 (instance)
│   │   │       └── Camera1 (Camera2D)
│   │   ├── VP2 (SubViewportContainer)
│   │   │   └── SubViewport2 ...
│   │   ├── VP3 ...
│   │   └── VP4 ...
│   └── MapInstance (TileMapLayer)  ← shared world, same scene
└── HUD (CanvasLayer)
    └── ScoreDisplay
```

**Critical:** The map (`TileMapLayer`) lives in the **main scene tree**, not inside any SubViewport. All four SubViewports render the same world through their own cameras. Instancing the map four times is a common beginner mistake that quadruples collision processing.

### Player (`Player.tscn`)
```
Player (CharacterBody2D)
├── Sprite2D (or AnimatedSprite2D)
├── CollisionShape2D
├── GrappleHook (Node2D)
│   ├── RayCast2D
│   └── Line2D          ← rope visual, NOT physics
├── GunPivot (Node2D)   ← rotates toward right stick
│   └── Muzzle (Marker2D)
├── HitBox (Area2D)
│   └── CollisionShape2D
└── CoyoteTimer (Timer) ← coyote time, jump buffer
```

---

## Part 4 — Split-Screen Implementation

### Setup in Code (`SplitScreen.gd`)

```gdscript
extends Control

@onready var viewports := [
    $ViewportGrid/VP1/SubViewport1,
    $ViewportGrid/VP2/SubViewport2,
    $ViewportGrid/VP3/SubViewport3,
    $ViewportGrid/VP4/SubViewport4,
]

func _ready() -> void:
    # Each viewport renders at half resolution for performance
    var vp_size := Vector2(
        ProjectSettings.get("display/window/size/viewport_width") / 2.0,
        ProjectSettings.get("display/window/size/viewport_height") / 2.0
    )
    for vp in viewports:
        vp.size = vp_size
        vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        # Disable AA per viewport — not needed for pixel-style
        vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
        vp.use_debanding = false
        vp.use_occlusion_culling = false
```

### Camera Per Player (`PlayerCamera.gd`)

```gdscript
extends Camera2D

var target: CharacterBody2D
const SMOOTH_SPEED := 8.0
const LEAD_DISTANCE := 80.0

func _physics_process(delta: float) -> void:
    if not target:
        return
    var lead := target.velocity.normalized() * LEAD_DISTANCE
    var desired := target.global_position + lead
    global_position = global_position.lerp(desired, SMOOTH_SPEED * delta)
```

**Performance rules for cameras:**
- Set `Camera2D.process_callback = CAMERA2D_PROCESS_PHYSICS` to sync with physics updates, preventing jitter.
- Use `limit_*` properties to clamp camera inside map bounds — never write custom clamping.
- Disable `Camera2D.drag_horizontal_enabled` / `drag_vertical_enabled` unless you specifically want those mechanics; they add lag.

---

## Part 5 — Grapple System (Most Important Mechanic)

### Philosophy

A realistic rope is a chain of rigid bodies. You do not want that. What you want is **the feeling of a rope** — momentum preservation, arc-based swinging, tension snap. Fake it with pure math. Spider-Man games (all of them) fake rope physics.

### Implementation (`PlayerGrapple.gd`)

```gdscript
extends Node

const GRAPPLE_SPEED       := 1200.0  # px/s pull force
const GRAPPLE_RANGE       := 450.0
const SWING_GRAVITY_SCALE := 0.6     # reduce gravity while swinging
const RETRACT_SPEED       := 180.0   # rope shortening speed

var anchor: Vector2 = Vector2.ZERO
var is_hooked: bool = false
var rope_length: float = 0.0

@onready var ray:    RayCast2D = $RayCast2D
@onready var line:   Line2D    = $Line2D
@onready var player: CharacterBody2D = owner

func shoot(direction: Vector2) -> void:
    ray.target_position = direction.normalized() * GRAPPLE_RANGE
    ray.force_raycast_update()
    if ray.is_colliding():
        anchor      = ray.get_collision_point()
        rope_length = player.global_position.distance_to(anchor)
        is_hooked   = true

func release() -> void:
    is_hooked = false
    line.clear_points()

func physics_tick(delta: float) -> void:
    if not is_hooked:
        return

    var to_anchor := anchor - player.global_position
    var dist      := to_anchor.length()

    # Constrain rope length — this IS the swing constraint
    if dist > rope_length:
        # Project velocity onto tangent of swing arc
        var rope_dir := to_anchor.normalized()
        var tangent  := Vector2(-rope_dir.y, rope_dir.x)
        player.velocity = tangent * player.velocity.dot(tangent)
        # Pull toward anchor
        player.velocity += rope_dir * GRAPPLE_SPEED * delta

    # Shorten rope on hold (retract)
    rope_length = max(50.0, rope_length - RETRACT_SPEED * delta)

    # Draw rope
    line.clear_points()
    line.add_point(Vector2.ZERO)
    line.add_point(to_anchor)

func get_gravity_scale() -> float:
    return SWING_GRAVITY_SCALE if is_hooked else 1.0
```

In `PlayerMovement.gd`, multiply gravity by `grapple.get_gravity_scale()` each physics frame. This gives the floaty sensation during a swing without any joint simulation.

### Feel Tuning Targets

| Parameter | Start Value | Target Feel |
|---|---|---|
| `GRAPPLE_SPEED` | 1200 | Zippy pull, not instant |
| `SWING_GRAVITY_SCALE` | 0.6 | Floaty arc, not weightless |
| `RETRACT_SPEED` | 180 | Reachable but not trivial |
| `rope_length` min | 50px | Prevents wall-clipping |

Spend two full days tuning only these four values before adding anything else. Feel is locked in early or not at all.

---

## Part 6 — Controller Input Architecture

### `InputRouter.gd` (Autoload)

```gdscript
extends Node

# Call this on game start after controllers are detected
func assign_devices() -> void:
    var connected := Input.get_connected_joypads()
    for i in range(min(connected.size(), 4)):
        _remap_player_actions(i, connected[i])

func _remap_player_actions(player_idx: int, device_id: int) -> void:
    var prefix := "p%d_" % (player_idx + 1)
    var actions := [
        [prefix + "move_left",  JOY_AXIS_LEFT_X, -1],
        [prefix + "move_right", JOY_AXIS_LEFT_X,  1],
        [prefix + "jump",       JOY_BUTTON_A,     -1],
        [prefix + "shoot",      JOY_AXIS_TRIGGER_RIGHT, 1],
        [prefix + "grapple",    JOY_AXIS_TRIGGER_LEFT,  1],
    ]
    for action_data in actions:
        # Clear existing events for this action first
        InputMap.action_erase_events(action_data[0])
        var ev := InputEventJoypadMotion.new() \
            if action_data[2] != -1 else InputEventJoypadButton.new()
        ev.device = device_id
        # ... configure axis/button
        InputMap.action_add_event(action_data[0], ev)
```

**Never** read `Input.get_joy_axis(0, JOY_AXIS_LEFT_X)` directly. Always use the remapped `InputMap` actions. Player 2 on device 1 should read `p2_move_left`, not hardcoded device calls. This makes keyboard fallback trivial to add later.

### Deadzone Configuration

Set `project.godot` deadzone to `0.2` globally. Cheap controllers have heavy drift below this. In `InputMap`, each analog action should also have its own per-action deadzone of `0.15`.

---

## Part 7 — Performance Optimization Strategies

### Viewport Budget

With four `SubViewport`s, you have four render passes per frame. Each viewport should render at `960×540` (half of 1080p) or `800×450`. The `SubViewportContainer` upscales via nearest-neighbor (`stretch_shrink = 2`) — correct for pixel art, invisible for flat geometric style.

```gdscript
# In project.godot or via script
ProjectSettings.set("rendering/2d/snap/snap_2d_vertices_to_pixel", true)
ProjectSettings.set("rendering/textures/canvas_textures/default_texture_filter", 0) # nearest
```

### Physics Budget

- Maximum **40 active `CollisionShape2D`s** per frame target. Profile with `Physics → Active Bodies` in Godot's built-in profiler.
- Bullets: use an **object pool** of 30 `Area2D` bullets per player. Recycle, never `queue_free()` during gameplay.
- Set collision layers strictly. Players are layer 1. Map geometry layer 2. Bullets layer 3. No cross-layer pollution.
- `TileMapLayer` with physics: enable `use_kinematic_bodies = false`. Static bodies only.

### Bullet Pool (`BulletPool.gd`)

```gdscript
extends Node

const POOL_SIZE := 30
var _pool: Array[Node] = []
var _idx: int = 0

func _ready() -> void:
    var scene := preload("res://scenes/player/Bullet.tscn")
    for i in POOL_SIZE:
        var b := scene.instantiate()
        b.visible = false
        b.set_process(false)
        add_child(b)
        _pool.append(b)

func fire(pos: Vector2, dir: Vector2, speed: float) -> void:
    var b := _pool[_idx % POOL_SIZE]
    _idx += 1
    b.global_position = pos
    b.direction       = dir
    b.speed           = speed
    b.visible         = true
    b.set_process(true)
    b.reset()

func recycle(bullet: Node) -> void:
    bullet.visible = false
    bullet.set_process(false)
```

### Rendering

- No `CanvasLayer` per player — one shared `HUD` CanvasLayer at the top level.
- No particle systems in Phase 1. Replace with `CPUParticles2D` (not `GPUParticles2D`) if you add them later.
- No `Light2D`. Zero. Neon aesthetic achieved through color, not lighting.
- `RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.08))` — deep blue-black background, free.

---

## Part 8 — Arena / Map Design Recommendations

### TileMapLayer Configuration

Use a single `32×32px` tileset with 8–12 tiles maximum: solid platform, one-way platform, wall, corner variations, background decoration tile. Export as a `.tres` `TileSet` resource shared across all maps.

### Map Design Principles for This Game Type

Four players with grapple + shooting creates extreme horizontal and vertical movement. Maps that work must satisfy: at minimum three grapple anchor surfaces within range of any floor position; multiple vertical layers (low floor, mid platforms, high ceiling perches); chokepoints no wider than 200px to force engagement; no dead-end corridors longer than 400px.

An ideal map footprint is **1920×1080 to 2400×1350px** (1.25–1.5× screen). Larger maps cause split-screen players to never meet. Smaller maps cause unavoidable spawn-kill.

### Arena Layout Pattern (Starting Template)

```
[HIGH WALL]  [PLATFORM]  [HIGH WALL]
   |         [PLATFORM]      |
   |    [FLOOR LEVEL]        |
   └────────────────────────┘
         [PIT / HAZARD]
```

Pits as kill zones are cheaper than health tracking in Phase 1 — touching the pit resets the player to a spawn point. Implement score-by-elimination, not health bars.

---

## Part 9 — Build Order (What to Build First)

### Phase 0 — Foundation (Days 1–7)

Do not touch split-screen. Do not touch multiplayer. Build one player in a single viewport.

1. `CharacterBody2D` player with `move_and_slide()` — left-stick movement, jump, gravity.
2. One flat arena map using `TileMapLayer`.
3. `Camera2D` following the player.
4. Controller input via `InputMap` for device 0 only.

**Exit criteria:** One player runs, jumps, and lands. Feels responsive. Frame rate is locked 60fps.

### Phase 1 — Grapple (Days 8–18)

This is your longest single phase. Ship nothing else until this feels excellent.

1. `RayCast2D` grapple shot toward right-stick direction.
2. Custom swing constraint (the `PlayerGrapple.gd` above).
3. `Line2D` rope visual.
4. Tune `GRAPPLE_SPEED`, gravity scale, rope retraction.
5. Add a map with varied vertical surfaces expressly for swing testing.

**Exit criteria:** You can cross the map without touching the floor using only grapple. The movement feels satisfying, not frustrating.

### Phase 2 — Split-Screen + Multiplayer Input (Days 19–26)

1. `SubViewport` 2×2 grid setup.
2. Instantiate 4 players, assign device IDs 0–3.
3. Each player's camera follows only its own character.
4. Map exists in shared scene tree once.

**Exit criteria:** Two controllers drive two players simultaneously in split-screen with no input bleed.

### Phase 3 — Shooting + Kills (Days 27–35)

1. Bullet pool.
2. `Area2D` hit detection — bullet overlaps player `HitBox`.
3. Kill signal → respawn at spawn point.
4. Kill counter per player displayed in HUD.

**Exit criteria:** Four players can fight. Kills register. Respawns work. No crashes after 10 minutes of play.

### Phase 4 — Maps + Replayability (Days 36–45)

1. Build 2 additional arenas.
2. Map selection on match start.
3. Round timer (3 minutes) → show winner screen → restart.
4. Basic sound effects (shoot, grapple hook, death, wall-hit).

**Exit criteria:** A full 10-minute session with four players is fun, stable, and restartable.

### Phase 5 — Polish (Days 46–60)

1. Screen shake on kills (CameraShake component, 0.1s max).
2. Kill feed text in HUD.
3. Spawn invincibility flicker (2 seconds).
4. Tune all feel parameters from actual session feedback.
5. Performance profiling — fix any frame spikes.

---

## Part 10 — What to Avoid Until Phase 4+

**Avoid entirely (or until explicitly needed):**

- Animated character sprites in Phase 1–2. Use a colored rectangle. Art is a distraction from mechanics.
- Health systems. Instant kills from pits/bullets only, until Phase 3+.
- Any shader, even simple ones. Profile first.
- Networked state synchronization code anywhere in the codebase. It bleeds into local architecture.
- `Node.call_deferred()` unless you have a concrete reason. It obscures call order.
- Scene autoloading for anything stateful beyond `GameManager`, `InputRouter`, `AudioManager`. Three autoloads maximum.
- `AnimationPlayer` for gameplay logic. Use `Tween` for one-shot animations, code for state transitions.
- Custom physics integration. `move_and_slide()` is fast, deterministic, and correct.

---

## Part 11 — Avoiding AI-Generated Spaghetti Code

AI code assistants (including Claude) will generate working code that accumulates technical debt silently. Specific failure patterns to watch for:

**Pattern 1 — God script.** AI will add logic to `Player.gd` forever rather than creating components. After 200 lines in any single script, split it. `PlayerMovement.gd`, `PlayerGrapple.gd`, `PlayerShoot.gd` are separate scripts attached as child node components. The Player scene instantiates them; they reference `owner` for access to the `CharacterBody2D`.

**Pattern 2 — Direct node path calls everywhere.** Code like `get_node("/root/Game/SplitScreen/VP1/SubViewport1/Player1/GrappleHook")` will appear. Every path is a fragile coupling. Use exported `@export var` references or signals.

**Pattern 3 — Missing `_physics_process` discipline.** Movement logic in `_process`, not `_physics_process`, causes frame-rate-dependent behavior. Every velocity mutation, collision check, and grapple calculation must be in `_physics_process`.

**Pattern 4 — Inline magic numbers.** AI writes `velocity.y += 980 * delta` scattered across files. Create a `PlayerStats` resource (`.tres`) or constants file. One location, all tuning values.

**Pattern 5 — Accumulating dead code.** AI-assisted iteration leaves disabled code paths everywhere. After each working phase, delete everything commented out. Version control is your safety net.

**Enforcement strategy:** After each working session, read every script file top to bottom. If any function exceeds 40 lines, it needs decomposition. If any script exceeds 150 lines, it needs to be split.

---

## Part 12 — Common Solo-Dev Mistakes

**Scope creep is the terminal risk.** The grapple mechanic alone can consume 3 weeks of feel tuning. Define the exact feature set for each phase in writing. Do not add anything mid-phase.

**Skipping the boring test session.** Play each phase for 15 uninterrupted minutes with real controllers before moving forward. Paper feel problems that only emerge under sustained play are impossible to diagnose in later phases.

**Not profiling early.** Run Godot's built-in profiler (`Debug → Monitor`) from Phase 2 onward. Split-screen performance problems are invisible until you're four sessions deep in code that's hard to unwind.

**Committing assets before mechanics.** Spending time on sprite art before the grapple feels correct is a morale-destroying trap. Ship a colored rectangle that swings well first.

**No version control.** `git init` on Day 1. Commit after every working phase milestone. Godot `.uid` files should be tracked; large binary assets in `assets/` can go in a separate commit or a `.gitignore` exception if using LFS.

---

## Part 13 — Free Tools and Assets

| Tool | Purpose |
|---|---|
| **Godot 4.3+** | Engine (AUR: `godot`) |
| **Aseprite** (compile from source, free) | Pixel art sprites |
| **Libresprite** | Aseprite fork, fully free binary |
| **Tiled Map Editor** | External map drafting (imports via plugin) |
| **Bfxr / SFXR** | Procedural SFX generation |
| **LMMS** | Background music |
| **Kenney.nl** | Free 2D game asset packs (CC0) |
| **Itch.io free assets** | Filter by CC0/public domain |
| **Git + GitHub/Codeberg** | Version control |

For Arch Linux: Godot 4 is in the AUR (`yay -S godot`). Joypad support requires `xboxdrv` or `jstest-gtk` for non-standard controllers. Steam controllers work natively via Steam Input.

---

## Part 14 — AI Workflow Strategy

Use AI for **generation of boilerplate and first drafts**, not for **architecture decisions**. Concretely:

- Ask AI to write the first draft of `PlayerGrapple.gd` using the exact architecture above. Review it line by line. Reject any line that introduces a new dependency not in the architecture plan.
- Use AI for TileSet setup scripts, UI layout boilerplate, and input remapping logic — repetitive structural code with clear correctness criteria.
- Do NOT ask AI to design the feel parameters, the map layout, or the game loop. These require iterative physical testing, not code generation.
- After every AI-generated script, trace the call graph manually: what calls this function, what does this function call. If you cannot answer both questions, the code is not yet yours.

---

## Part 15 — Realistic Timeline

| Phase | Duration | Deliverable |
|---|---|---|
| 0 — Foundation | 1 week | Single player moves, jumps, has camera |
| 1 — Grapple | 10 days | Swinging feels excellent, solo test |
| 2 — Split-screen | 1 week | 4 players move independently |
| 3 — Combat | 1 week | Kills, respawns, kill counter |
| 4 — Maps + Sessions | 10 days | 3 maps, round flow, restartable |
| 5 — Polish | 2 weeks | Sound, screen shake, session feel |
| **Total** | **~7–8 weeks** | **Playable local multiplayer build** |

This timeline assumes 2–3 hours of focused work per day and no scope additions mid-phase. The grapple phase is the wildcard — it may extend to 14 days. Budget for that.

---

## Part 16 — Performance Targets

| Metric | Target |
|---|---|
| Frame time (4-player) | < 16.7ms (60fps) |
| Draw calls per frame | < 80 |
| Active physics bodies | < 40 |
| VRAM usage | < 64MB |
| RAM usage | < 256MB |
| Viewport resolution (each) | 960×540 |

Profile against these targets at the end of Phase 2 and again at the end of Phase 5. Use `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` to track draw calls programmatically during dev sessions.

---

## Summary: Priority Stack

1. **Grapple feel.** Nothing else matters until swinging is satisfying.
2. **Split-screen architecture.** One shared world, four independent cameras.
3. **Controller input.** Four device IDs, remapped actions, deadzone tuned.
4. **Performance budget.** Locked from Phase 2, profiled every phase.
5. **Map design.** Dense, vertical, swing-friendly.
6. **Art last.** Ship a colored rectangle that plays like Spider-Man first.
