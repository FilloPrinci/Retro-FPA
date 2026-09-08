# Systems reference: what's here, and when to use it

This is a **lookup reference**, not a tutorial — every reusable system in
this template, one section per system, each answering three questions:
what it is, how you use it, and which of its options/variants to pick for
a given situation. Read [`docs/getting_started.md`](getting_started.md)
first if you haven't built anything with this template yet — it walks you
through building a small game start to finish, in the order you'd
actually touch things. Come back here afterward to look things up, or to
see the full set of options a step there only showed part of.

[`CLAUDE.md`](../CLAUDE.md) stays the authoritative architecture summary
(autoload table, conventions, how to use this project as a template at
all) — this doc goes one level deeper into *using* what's there. A
closing [decision table](#decision-table) maps common goals straight to
the right tool.

## Autoloads

Every autoload is a global singleton (`GameManager.foo()` from any
script, no node reference needed) and they only ever talk to each other
through their own public methods/signals — never by reaching into one
another's internals. [`CLAUDE.md`](../CLAUDE.md#autoloads) has the
compact table; here's when you'd actually call each one.

**`GameManager`** — the single source of truth for what mode the game is
in. Read `GameManager.state` (`MAIN_MENU`/`PLAYING`/`PAUSED`/`DIALOGUE`/
`INVENTORY`) or connect to `state_changed` to react to it — never push a
menu open/closed from outside; every menu already reacts to state on its
own. `set_flag`/`get_flag`/`has_flag` are the general-purpose "did the
player do X" memory used by dialogue branching (below) and by
`ItemPickup` (already-taken bookkeeping) — use them for anything a
specific game's own scripts need to remember about progress, too. Values
must be JSON-safe (bool/int/float/String/Array/Dictionary) if they should
survive a save — see `SaveManager` below. `clear_flags()` is called by
`SceneManager.start_new_game()`; you don't need to call it yourself.
`set_control_enabled(false)` freezes the player controller (movement,
look, interact) — dialogue and pause already do this; do the same
around any custom cutscene/UI you build.

**`SettingsManager`** — persisted player preferences (`user://
settings.cfg`: resolution, fullscreen, volumes, mouse sensitivity, text
size, language). You'll rarely call this directly — the Settings screen
(already built) is the whole interface to it. `SettingsManager.visual_style`
is read live from its Project Setting instead, deliberately *not*
persisted here (no Settings-menu control exists for it yet — see
[Visual style & rendering](#visual-style--rendering)).
`SettingsManager.mouse_sensitivity`/`get_font_size()`/`UI_FONT` are the
exceptions worth knowing directly if you're building a custom Control
that needs to match the rest of the UI's text sizing.

**`AudioManager`** — bus-based sound playback, no exports, four fixed
bus names (`"SFX"`, `"Music"`, `"Ambient"`, `"UI"` — see
`resources/audio/default_bus_layout.tres`). Pick the call by what the
sound *is*:
- `play_sfx_2d(stream, bus="SFX", volume_db=0.0)` — a UI click, anything
  where 3D positioning doesn't matter.
- `play_sfx_3d(stream, world_position, bus="SFX", volume_db=0.0)` — a
  one-shot sound that should come from somewhere in the world (a door
  slam, an impact). `FootstepComponent` uses this.
- `play_music(stream, fade_time=1.0)` — crossfades from whatever's
  currently playing; call it again with a new track any time (a boss
  fight starting, a new area) rather than stopping/starting manually.
  `stop_music(fade_time=1.0)` fades out and stops.
- `play_ambient(stream, world_position=Vector3.ZERO) -> AudioStreamPlayer3D`
  — a *looping* environmental sound (wind, machinery hum). Returns the
  player node it created; you own it — stop/`queue_free()` it yourself
  when the source should go quiet (e.g. leaving the room).

**`InventoryManager`** — 8 slots (`SLOT_COUNT`), one of them optionally
"equipped". `add_item(item, quantity=1) -> bool` returns `false` if it
couldn't fit everything (still adds as much as it could — check the
return value if "did it actually all fit" matters, e.g. before deciding
to remove a `WorldItem` from the world). `remove_item(item_id, quantity=1)`
is what `RangedWeaponBehavior` calls to spend ammo. `equip_slot(index)`/
`unequip()` drive `EquippableBehavior.on_equip`/`on_unequip` and
`ui/hud`/`EquippedItemView` reactively — never touch those UI pieces
directly, just call these. `clear()` empties everything (called by
`start_new_game()`).

**`DialogueManager`** — a pure graph-walker; all actual content lives in
`DialogueData`/`DialogueLine`/`DialogueChoice` resources (below).
`start_dialogue(dialogue, start_id="")` is normally called by
`DialogueTrigger`, not by hand. `advance()`/`choose(index)` are what the
dialogue box UI calls on player input — build your own alternative UI
against these two plus the `line_changed`/`choices_presented`/
`dialogue_ended` signals if you ever need to.

**`SceneManager`** — level loading and the run's lifecycle. Reach for
`change_scene()`/`add_scene()` directly only when you need a scene
transition your own script triggers outside a `SceneChangeTrigger` (an
end-of-cutscene jump, a scripted event) — the trigger node covers the
"player walks somewhere / presses E" case entirely from the Inspector.
`get_current_level_path()`/`get_current_level_root()`/
`get_path_in_level(node)` are the tools for anything that needs to find
or identify something in the currently loaded level from outside it —
`SaveManager` and `ItemPickup` both use `get_path_in_level()` as a
stable per-node identifier that survives the level being torn down and
reloaded (unlike `node.get_path()`, which is relative to the whole
`SceneTree` and breaks if `Main`/`CurrentLevel`'s own names ever
changed). The `level_placed` signal fires once a level's tree exists and
the player's been placed, but *before* fade-in reveals it — the moment
to adjust anything about the level's own state so it never visibly
"pops" once the screen is showing (`SaveManager` restores physical
object positions here).

**`SaveManager`** — see its own [section](#saveload) below.

## Self-building nodes (prefabs)

Three nodes build their own child structure the moment you add them —
no manual assembly, everything that matters is an export. Each has a
matching `.tscn` under its own folder (e.g. `core/world_item/
world_item.tscn`) that's the identical node pre-built and saved, for
dragging in instead of using **Create New Node** — purely a Scene-dock
convenience (see ["Prefab scenes" in `getting_started.md`](getting_started.md#prefab-scenes-the-drag-it-in-shortcut)
for exactly what that buys you and its one caveat).

### WorldItem — `core/world_item/world_item.gd`

Any object that exists as a physical thing in the world: a crate, a key,
a weapon, a note. One node, two completely different bodies depending on
`kind`:

| | `kind = PHYSICAL` | `kind = PICKUPABLE` (default) |
|---|---|---|
| Body | `RigidBody3D` | `StaticBody3D` |
| Components | `Grabbable` + `InteractableComponent` (`"UI_INTERACT_GRAB"`) | `InteractableComponent` (`"UI_INTERACT_TAKE"`) + `ItemPickup` |
| Behavior | Player's `Grabber` picks it up, carries it, throws it — no inventory involved at all | Interacting adds `item` to the inventory and removes itself from the world |
| Use for | Furniture, crates, anything you shove around or throw | Keys, weapons, ammo, notes, anything that goes in the inventory |
| Fresnel glow | none | pulses automatically to signal "pick me up" — see below |

Other exports, both kinds: **Body Size** (`Vector3`, also resizes the
placeholder box mesh); **Model** (a `PackedScene` — an imported
Blender/glTF asset, replaces the placeholder box; leave empty to keep
testing with the box); **Material** (only used when `Model` is empty —
see the RetroSurfaceMaterial section below for why leaving this alone on
a pickup is usually right). `PICKUPABLE`-only: **Item** (the `ItemData`
— create it via the Item Tools wizard, don't hand-write one) and
**Quantity**.

**Pickup Glow group** (`PICKUPABLE` only): `pickup_glow_enabled` (default
`true`) and `pickup_glow_color` (default white) control the pulsing
fresnel rim every pickup gets automatically — every mesh surface is
switched to a `RetroSurfaceMaterial` (carrying over
albedo/metallic/roughness/emission from whatever was there, so the
switch doesn't change how it looks at rest) so there's a fresnel rim to
drive. Turn `pickup_glow_enabled` off for something deliberately meant
to be missable/subtle; change the color to differentiate item classes
(e.g. yellow for quest items).

Changing `kind` on an already-placed instance fully rebuilds the body —
every other setting (model/material/item/quantity) carries over.

### NpcBody — `core/npc/npc_body.gd`

A placeholder-ready NPC body: `StaticBody3D` + boxed placeholder mesh +
collision, sized like a standing person, resting on the floor.
**Body Size** (default `(0.6, 1.7, 0.6)`), **Model** (swap in a real
rigged character — see [`blender_workflow.md`](blender_workflow.md)),
**Material** (placeholder box only, ignored once `Model` is set — an
imported model brings its own materials).

NpcBody by itself has no dialogue, no animation state machine, nothing
opinionated — it's the body and nothing else. Add `InteractableComponent`
+ `DialogueTrigger` (usually via the Dialogue Tools wizard, below) for a
talking NPC; add `DamageableComponent` for something that can take
damage; add `AnimationController` if the model has animations to drive
(see [Components](#components-you-attach-directly)).

### SceneChangeTrigger — `core/scene_management/scene_change_trigger.gd`

Loads another scene. Builds whichever detector `trigger_mode` needs:

| `trigger_mode` | Detector built | Feel | Use for |
|---|---|---|---|
| `AREA` (default) | `Area3D` + `CollisionShape3D` — no solid collision | Walking into it fires the load | An open doorway, a threshold you just walk through |
| `INTERACT` | `StaticBody3D` + `CollisionShape3D` + `InteractableComponent` | Solid, press E | A real door you walk up to and open |

| `mode` | Effect | Use for |
|---|---|---|
| `EXCLUSIVE` (default) | Replaces the current level entirely via `SceneManager.change_scene()`, places the player on `target_spawn_id`'s matching `SpawnPoint` in the target scene | Leaving through a door into a genuinely different level |
| `ADDITIVE` | Instantiates `target_scene` alongside whatever's already loaded via `SceneManager.add_scene()`, never touches the player | Streaming in a sub-area (unlocking a wing of a house) without a loading transition |

Other exports: **Detector Size** (the box collider's size, either
detector kind); **Target Scene** (`.tscn` file); **Target Spawn Id**
(`EXCLUSIVE` only — which `SpawnPoint` in the target level); **Show
Transition** (fade to black while loading — turn off for a quiet
`ADDITIVE` load, since covering the whole screen to quietly add
something in the background usually defeats the point). Fires once,
then stays inert — an `ADDITIVE` trigger never double-adds its target,
walking back through an `AREA` one a second time does nothing.

## Components you attach directly

Small, single-purpose `Node`s you add as children of a collider or an
NPC — each does exactly one thing, found by whatever needs it via
"look at the children of the hit collider" (the same pattern
`Interactor`, `Grabber` and `WeaponBehavior` all use to find
`InteractableComponent`/`Grabbable`/`DamageableComponent`).

**`InteractableComponent`** (`core/interaction/interactable_component.gd`)
— marks something as interactable at all. `prompt_text_key` (default
`"UI_INTERACT_DEFAULT"`) is the translation key shown in the HUD prompt
— pick the right verb for the context (`"UI_INTERACT_TALK"`,
`"UI_INTERACT_OPEN"`, `"UI_INTERACT_TAKE"`, `"UI_INTERACT_GRAB"`, or add
your own). Connect to its `interacted(interactor: Node)` signal for
anything custom (a lever, a switch) — `DialogueTrigger`/`ItemPickup`/
`Grabber` already do this for you in their own cases.

**`Grabbable`** (`core/physics_grab/grabbable.gd`) — child of a
`RigidBody3D`, marks it pick-up-able by the player's `Grabber`.
`hold_distance` (default `1.5`) — how far in front of the camera it's
held; `throw_force` (default `8.0`) — impulse strength on throw.

**`ItemPickup`** (`core/inventory/item_pickup.gd`) — sibling of an
`InteractableComponent`, `item`/`quantity` exports, adds `item` to the
inventory and removes itself on interact. Remembers being taken via a
`GameManager` flag keyed by its own stable level path (so it doesn't
reappear on any level reload — a plain revisit within the same session,
or a save/load — see [Save/load](#saveload)). `WorldItem` builds one
for you at `kind = PICKUPABLE`; only add it by hand for a pickup that
isn't a `WorldItem` at all.

**`DamageableComponent`** (`core/combat/damageable_component.gd`) —
deliberately minimal health bookkeeping, nothing else opinionated (no
death animation, no loot, no AI reaction — that's a specific game's own
logic, wired through its signals). `max_health` (default `0.0` — leave
it at 0 to opt out of health tracking entirely while `damaged` still
fires every hit, e.g. a boss with its own custom phase logic). Public:
`take_damage(amount, source=null)` — always emits `damaged(amount,
source)`; decrements `health` and emits `died` (no parameters) once it
reaches 0, only if `max_health > 0`. `WeaponBehavior` finds and calls
this on whatever a weapon's hitscan hits.

**`DialogueTrigger`** (`core/dialogue/dialogue_trigger.gd`) — sibling of
an `InteractableComponent`, one `dialogue: DialogueData` export, calls
`DialogueManager.start_dialogue(dialogue)` on interact. Normally added
(along with the `InteractableComponent`) by the Dialogue Tools wizard,
below — add it by hand only for a dialogue trigger that isn't attached
to a fresh NPC (e.g. a sign, a phone).

**`FresnelFlash`** (`core/shading/fresnel_flash.gd`) — code-triggered
rim-light flash/pulse for anything to drive as a *reaction*, on top of
whatever fresnel look a `RetroSurfaceMaterial` already has (see below).
`WorldItem` attaches and drives one automatically for its pickup glow;
attach your own where you need a similar effect from custom code — e.g.
a single red/yellow `flash()` on an enemy taking damage (connect it to
`DamageableComponent.damaged`), or a `pulse()` on something else that
should visually call attention to itself. `mesh_instance` (defaults to
the parent). `flash(color, duration=0.15)` — one-shot, fades out.
`pulse(color, period=1.0, peak_strength=1.0)` — loops until
`stop_pulse()`. Makes its target's material locally unique on first use
(materials in this project are shared `Resource`s on purpose — see
`SettingsManager`'s own doc comment — so animating a shared one directly
would flash every other object using it too); only ever touches
`RetroSurfaceMaterial` surfaces, silently skips anything else.

**`SpawnPoint`** (`core/scene_management/spawn_point.gd`) — plain
`Node3D`, one `spawn_id` export (default `"default"`). A level needs at
least one; add more only if the level has multiple entry points (one
per door) that should each place the player differently.

**`AnimationController`** + **`AnimationSet`** (`core/animation/`) —
opt-in, not auto-attached by `NpcBody` or `Player`: add
`AnimationController` under an animated model yourself (Player's own
model or an NPC's) when it has clips to drive. `AnimationController`:
`animation_player` (leave empty to auto-find the first `AnimationPlayer`
under its *parent*), `animation_set` (an `AnimationSet` resource),
`blend_time` (default `0.15`, crossfade seconds on state switch). Call
`play_state("walk")` etc. — never play an `AnimationPlayer` clip by name
directly, always go through the state name so different characters with
differently-named clips work against the same calling code.
`AnimationSet`: `idle`/`walk` (default clip names `"idle"`/`"walk"`) plus
`custom_states: Dictionary` for anything else (`"attack"`, `"hello"`, a
quadruped's `"run"`, ...) — one `.tres` per character type under
`resources/animation_sets/`, see
[`blender_workflow.md`](blender_workflow.md) for authoring the actual
clips.

**Player-side components** (already wired on `player.tscn`, not
something you add per-level, but worth knowing what each one does):
`Interactor` (raycast that finds `InteractableComponent`s and fires
`interacted` on "interact" — the HUD's prompt comes from here),
`Grabber` (`grab_range`, `hold_stiffness`, `max_hold_speed`,
`rotate_sensitivity` exports — the physics side of `Grabbable`; grabbing
something auto-unequips whatever's equipped and restores it on release),
`HeadBob` (`enabled`, `bob_frequency`, `bob_amplitude` on the camera),
`FootstepComponent` (`surface_sounds: SurfaceSoundSet`, `step_interval`,
`min_speed_to_step` — detects a `SurfaceTag` on whatever the player's
walking on to pick the right footstep sound, falling back to
`"default"`).

## Data resources

**`ItemData`** (`core/inventory/item_data.gd`) — one `.tres` per item
under `resources/items/`, create via the Item Tools wizard rather than
by hand. `id`, `display_name_key`, `description_key`, `icon`,
`world_model` (physical pickup appearance — usually left unset;
`WorldItem.model` is the more common path), `view_model` (first-person
equipped appearance, shown by `EquippedItemView` under the player's
`EquipAnchor` — kept deliberately distinct from `world_model` to avoid a
resource-loading cycle), `item_type` (`GENERIC`/`EQUIPPABLE`/`KEY`/
`CONSUMABLE` — only `GENERIC` and `EQUIPPABLE` are reachable from the
wizard directly; set `KEY`/`CONSUMABLE` by hand afterward if you need
them — nothing in the current codebase branches on `KEY`/`CONSUMABLE`
specially, they're informational unless a specific game's own script
checks `item_type`), `stackable`, `max_stack` (default `99`),
`equip_behavior` (an `EquippableBehavior` — see next).

**`EquippableBehavior`** (`core/inventory/equippable_behavior.gd`) — base
class for what happens while an item is equipped. Any item can be
equipped regardless of `item_type` (even a `KEY`, just to look at it) —
`equip_behavior` being null just means nothing happens beyond showing
`view_model`. Hooks: `on_equip(player)`, `on_unequip(player)`,
`on_primary_use(player)` (`"primary_action"` input), `on_secondary_use(player)`
(`"secondary_action"`), `get_use_animation() -> String` (which procedural
view-model animation `EquippedItemView` plays — `"shake"` by default).
Subclass this directly only for equip behavior that isn't a weapon
(e.g. a flashlight toggling a light on secondary use); for a weapon, use:

**`WeaponBehavior`** (`core/inventory/weapon_behavior.gd`, extends
`EquippableBehavior`) — a forward hitscan from the player's camera,
cooldown-gated. `damage` (default `10.0`), `range` (default `2.5`),
`attack_cooldown` (default `0.5`, timestamp-based). Two concrete
subclasses — the choice between them:

| | `MeleeWeaponBehavior` | `RangedWeaponBehavior` |
|---|---|---|
| Extra exports | none | `ammo_item: ItemData`, `ammo_per_shot` (default `1`) |
| Attack | Always fires (subject to cooldown) | Only fires if `InventoryManager.has_item(ammo_item.id, ammo_per_shot)` — otherwise does nothing at all, not even starting the cooldown; consumes ammo via `InventoryManager.remove_item()` only on an attack that actually fired |
| `get_use_animation()` | `"melee_attack"` | `"ranged_recoil"` |
| Use for | A knife, a pipe, anything with infinite uses | A gun, anything that should run out |

Both are scaffolded with sensible defaults (melee: damage 15, range 1.6,
cooldown 0.4; ranged: damage 25, range 30, cooldown 0.35) by the Item
Tools wizard when you pick "Melee weapon"/"Firearm" — it does **not**
set `ammo_item` for a ranged weapon (create a plain stackable `ItemData`
for the ammo first, then assign it on the behavior `.tres` yourself;
"Validate objects" flags a ranged weapon with none assigned).

**`DialogueData`** (`core/dialogue/dialogue_data.gd`) — one `.tres` per
conversation under `resources/dialogues/`, `lines: Array[DialogueLine]`,
`start_id` (defaults to `lines[0]` if left empty). **`DialogueLine`**:
`id`, `speaker_name_key` (empty = unattributed/narrator line), `text_key`,
`next_id` (used only when `choices` is empty; empty ends the dialogue),
`choices: Array[DialogueChoice]`, `set_flag_key`/`set_flag_value`
(default `true` — set on `GameManager` the moment the line is shown).
**`DialogueChoice`**: `text_key`, `next_id` (empty ends the dialogue),
`required_flag_key`/`required_flag_value` (default `true` — gates the
choice; empty key = always available; an unset flag reads as `false`),
`set_flag_key`/`set_flag_value` (set the moment the choice is picked).
This is the whole branching mechanism — no separate quest-flag system
exists, dialogue and quest state are both just `GameManager` flags. The
Dialogue Tools dock's Inspector integration swaps the free-text
`next_id`/flag-key fields for dropdowns populated from the dialogue
actually being edited, so a link can't be typo'd — author conversations
there rather than hand-typing ids.

**`VisualStyleProfile`** (`core/visual_style/visual_style_profile.gd`) —
one `.tres` per console look under `resources/visual_style/` (`ps1`,
`n64`, `gamecube`), see [Visual style & rendering](#visual-style--rendering)
below. You won't normally create a new one — tune the three shipped
profiles' fields instead, unless you're deliberately adding a fourth
distinct look.

**`AnimationSet`** — covered above under Components, since it's always
paired with an `AnimationController`.

## The 3D object shader — RetroSurfaceMaterial

`core/shading/retro_surface_material.gd` — the material to use for any
real (non-placeholder) 3D art in this template. A `ShaderMaterial`
subclass, fully Inspector-editable, no shader code to write.

**When to use it vs a plain `StandardMaterial3D`**: always, for anything
meant to look "finished" — it's what makes texture filtering (nearest/
linear) actually follow the active Visual Style automatically (a
`StandardMaterial3D` only gets its filter patched live by
`SettingsManager`; a `ShaderMaterial`'s sampler filter is a compile-time
choice, which is exactly what this class exists to manage for you — see
`apply_texture_filter()`), and it's the only material type
`WorldItem`'s pickup glow and `FresnelFlash` know how to drive. Leave a
placeholder box on plain defaults while you're still testing gameplay;
switch to a `RetroSurfaceMaterial` once you're placing real art (or let
`WorldItem`'s pickup-glow conversion do it for you automatically on
anything pickupable — see above).

**Per-pixel vs per-vertex lighting** (`per_pixel_lighting`, default
`true`): per-pixel is the normal choice — smoother lighting, still cheap
at this project's poly counts. Switch a specific object to per-vertex for
a deliberately blockier, more N64-accurate look (lighting computed once
per vertex instead of per pixel) — a stylistic choice per-object, not a
global setting.

**Two independent layers** (`_1`/`_2` suffix on every field): each has
`albedo_color`/`albedo_texture`, `tiling`/`offset`, `scroll_speed`
(tiles/second on each axis — a nonzero value scrolls the texture, e.g.
a conveyor belt or a screen effect), `emission_color`/`emission_texture`,
a `normal_texture` + `normal_strength`, `smoothness` (+ mask texture),
`metallic` (+ mask texture). Leave layer 2 untouched (defaults to
`layer_blend = 0.0`) for a plain single-texture material — the two-layer
system only matters once you actually want to blend something on top.

**Combining the layers** (`layer_blend_mode` enum, `layer_blend` float
0–1 = "how much of the operation"):

| Mode | Effect | Use for |
|---|---|---|
| `ALPHA_OVER` (default) | Layer 2 stacks on top of layer 1 like Photoshop layers — layer 2's own texture alpha controls how much of *it* shows through, without dragging layer 1's own opacity down where layer 1 is opaque | A decal, a dirt/grime overlay, a transparent detail on top of a base material |
| `MULTIPLY` | Darkens layer 1 by layer 2 | A shadow/AO-style overlay, tinting |
| `ADDITIVE` | Brightens layer 1 by layer 2 | A glow/highlight overlay |
| `SUBTRACT` | Darkens by subtraction | Rarely — a specific corrective look |
| `DIVIDE` | Brightens by division | Rarely — a specific corrective look |

**Fresnel rim** (`fresnel_enabled`, default `true`; `fresnel_color`;
`fresnel_power`, default `3.0`, range 0.1–8 — higher narrows the rim to
grazing angles; `fresnel_strength`, default `1.0`, range 0–4) — the
*ambient, always-on* rim light, authored per-object from the Inspector.
Separate from `flash_color`/`flash_strength` (not exported — runtime
only, driven exclusively by `FresnelFlash`, above) — a code-triggered
flash adds on top of whatever the ambient fresnel is already doing, and
still shows even with `fresnel_enabled = false` on an object that should
otherwise look flat until something happens to it.

**Downsampling and filtering**: both happen automatically, nothing to
wire up — `SettingsManager` walks every `RetroSurfaceMaterial` in the
scene the same way it does `BaseMaterial3D` (see
[Visual style & rendering](#visual-style--rendering)).

## Visual style & rendering

**Visual Style** (Project Settings > General > Retro Style > `Visual
Style`: PS1/N64/GameCube) — each is a `VisualStyleProfile` `.tres`
under `resources/visual_style/` controlling texture filter (PS1
Nearest/crisp; N64 Linear + extra mipmap blur/soft; GameCube Linear, no
extra blur), anisotropic filtering (PS1/N64 off, GameCube low), fog
(PS1 off by default; N64 heavy and close; GameCube light and far), and
color grading (PS1 slightly higher contrast/less saturated; N64 hazy —
reduced contrast/saturation; GameCube neutral). These are starting
points to tune, not precise console specs. Preview live without Play by
dragging `core/visual_style/visual_style_preview.tscn` into the scene
you're editing.

**Force Resolution** (`force_resolution` bool + `forced_resolution_preset`
dropdown) — bakes a real low-res internal render. Presets: PS1
(320×240), PS1 Widescreen (427×240), N64 (256×224), N64 Widescreen
(398×224), GameCube (640×480), GameCube Widescreen (853×480), HD 720p
(1280×720), HD 1080p (1920×1080), Custom... (leaves `forced_resolution`
as whatever you typed in directly). The generic screens in `ui/` have
only been checked to fit comfortably at 320×240 — re-check them (Settings
in particular) if you force a tighter preset like N64's 256×224.

**Force Texture Downsample** (bool + `max_texture_size`: 16/32/64/128/
256/512) — shrinks any `BaseMaterial3D.albedo_texture` bigger than the
max (aspect preserved, blocky nearest-neighbor resize) — the same
mechanism reaches every `RetroSurfaceMaterial` texture slot too. Turn
this on once you're importing real, full-resolution art and want it to
read as retro without hand-shrinking every texture yourself.

**Bloom** (`glow_*` settings) — a blanket post-process independent of
which Visual Style is active, on by default, affecting anything bright
enough (most commonly emissive materials). Nothing per-object to wire
up; tune `glow_intensity`/`glow_strength`/`glow_bloom`/
`glow_hdr_threshold`/`glow_blend_mode` to taste.

**Fog Override** (`override_fog` + its own `fog_*` settings) — when on,
overrides whatever the active `VisualStyleProfile` says about fog with
these values instead, project-wide regardless of style. Use it if your
game wants one consistent fog look across every Visual Style rather than
each style's own default.

**Two things to always remember:**

1. **Some of this needs an apply step.** Texture filter/anisotropic
   level and Force Resolution/Forced Resolution are renderer-startup-time
   defaults baked into `project.godot` — changing the Project Setting
   alone does nothing until you run **Project > Tools > "Apply Retro
   Style Settings..."** (or `godot --headless -s
   res://tools/setup_project.gd`). Everything else here (fog, color
   grading, background, downsample, bloom, fog override) applies live,
   no apply step needed.
2. **The editor preview (`visual_style_preview.tscn`) doesn't cover
   everything.** It shows fog/ambient/background/color-grading/bloom and
   texture filter live, but deliberately skips texture downsampling
   (mutates real pixel data — an open editor session risks a Ctrl+S
   baking the lossy resize permanently into the source art) and
   resolution forcing (a `DisplayServer`/`Window` property with no
   equivalent inside the editor's own viewport). Press Play to check
   those two.

## UI screens

Every screen under `ui/` is generic — a new game shouldn't need to edit
any of them, only the content behind them (dialogue text, item icons,
translation strings).

- **Main Menu** (`ui/main_menu/`) — New Game, Continue (visible only
  once a slot-0 save exists), Settings, Quit. The one export a new game
  sets: `first_level_path`.
- **Pause Menu** (`ui/pause_menu/`) — Resume, Save Game, Load Game
  (disabled with no save yet, status label confirms success/failure),
  Settings, Main Menu, Quit. Esc opens/closes it, only while `PLAYING`/
  `PAUSED`.
- **Settings** (`ui/settings_menu/`) — Audio (bus volume sliders), Video
  (resolution — replaced by an explanatory label if `Force Resolution`
  is on; fullscreen), General (mouse sensitivity, text size, language).
  Every control saves immediately on change, not just on close. Shared
  instance between Main Menu and Pause Menu.
- **Inventory** (`ui/inventory_ui/`) — Tab toggles it. Click a slot to
  select (shows name/description + an Equip/Unequip button, not an
  immediate equip); gold fill = equipped, white border = selected.
- **Dialogue box** (`ui/dialogue_ui/`) — purely reactive to
  `DialogueManager`'s signals. Choices navigable with the same movement
  keys used to walk, confirmed with the interact key — nothing
  dialogue-specific to learn as a player.
- **HUD** (`ui/hud/`) — crosshair, interact prompt (reads the actually
  bound key from the Input Map, so it stays correct if you rebind keys),
  equipped-item icon (only shown for an item with no `view_model`, since
  the 3D view model already represents it), ammo count (only shown while
  a `RangedWeaponBehavior` with an `ammo_item` is equipped). No health
  display exists — add one yourself if your game gives the player a
  `DamageableComponent` (health isn't currently wired to the player at
  all; see [Pending Tasks](#what-this-template-doesnt-have-yet) below).

## Editor tooling (addons)

Three plugins, all on by default (Project Settings > Plugins), each
adding a bottom-panel dock — no terminal needed for day-to-day content
work.

### Dialogue Tools — "Dialogues" dock

**"New NPC dialogue..."** — select an NPC node first, then fill in
**Dialogue name (slug)** (e.g. `entrance_guard`) and **Speaker name**
(e.g. `The Guard`). Creates: a `DialogueData` `.tres` with one starting
`DialogueLine`, an `InteractableComponent` (`"UI_INTERACT_TALK"`) and a
`DialogueTrigger` under the selected node (reusing either if already
present), and two placeholder rows in `translations/dialogue.csv` (the
speaker name and the starting line — fill in the real EN/IT text
yourself, the wizard only scaffolds the rows).

**"Validate dialogues"** checks, per `resources/dialogues/*.tres`: file
loads; at least one line exists; no empty/duplicate line ids;
`start_id` resolves to a real line; every `speaker_name_key`/`text_key`
that's set exists in some `translations/*.csv` (empty `text_key` is only
a warning, not an error); every `next_id` (line or choice) resolves to a
real line in the same file (empty is valid — it ends the dialogue); a
line never reachable from `start_id` is a warning.

### Item Tools — "Objects" dock

**"New object..."** — select a `WorldItem` first if you want it assigned
automatically. Fields: **Item name (slug)**, **Display name**,
**Description**, **Icon** (a `Texture2D` picker), **Type** (**Plain
object** / **Melee weapon** / **Firearm** — see the
[`WeaponBehavior` table](#data-resources) above for what melee/firearm
scaffold). Creates the `ItemData` `.tres`
(plus a behavior `.tres` under `resources/items/behaviors/` for a
weapon type, with the sensible defaults listed earlier), placeholder
rows in `translations/items.csv`, and — if a `WorldItem` was selected —
sets its `kind = PICKUPABLE` and `item` automatically.

**"Validate objects"** checks, per `resources/items/*.tres`: file loads;
no empty/duplicate `id` (across every file); `display_name_key`/
`description_key` exist in some `translations/*.csv` if set (empty is
only a warning); a `RangedWeaponBehavior` with no `ammo_item` assigned
is a warning.

### Retro Visual Style — Project Settings + Tools menu item

Registers every `retro_style/*` Project Setting described in
[Visual style & rendering](#visual-style--rendering) above, and adds
**Project > Tools > "Apply Retro Style Settings..."** — the in-editor
equivalent of running `tools/setup_project.gd` from a terminal (both
call the same shared `ProjectSetup.apply()`, so there's one canonical
implementation). Click it after changing Visual Style, Force Resolution/
Forced Resolution, or after adding a brand-new `translations/*.csv` file
— it bakes texture-filter/anisotropic/mipmap-bias settings, the Force
Resolution window settings, the registered-translations list, the input
map, and the audio bus layout into `project.godot`, then rescans the
filesystem. A fresh Play (or an editor restart, for its own 3D viewport)
is what actually shows the change.

## Save/load

`autoload/save_manager.gd` — `SaveManager`. One slot = one
`user://saves/save_<slot>.json` file; every method takes an explicit
`slot: int` defaulting to `0`, so a single-save "Continue" game (the
default UI wiring) and a future multi-slot save screen use the exact
same API.

**What's captured**: which level; the player's exact position and
orientation (not just which `SpawnPoint` — resuming mid-room matters
more for a horror game than most genres); every `GameManager` flag
(which is also how a taken `ItemPickup` remembers not to reappear — see
[Components](#components-you-attach-directly)); the full inventory
(every slot's item + quantity, and which one's equipped); every
`Grabbable` physical object's exact transform (a moved crate stays
moved). Restoring all of this happens *before* the level's fade-in
reveals anything — nothing pops into its default position and then
jumps to the saved one.

**API**: `save_game(slot=0) -> bool` (fails with no active level/player,
e.g. called from the main menu), `load_game(slot=0) -> bool` (awaited —
swaps the level exactly like any other transition, fade included),
`has_save(slot=0) -> bool`, `delete_save(slot=0)`. Signals:
`save_completed`/`load_completed`/`save_failed`/`load_failed` (the
failed ones carry a short untranslated `reason` code for logging, not
player-facing text). Already wired into the Pause Menu (Save/Load
buttons) and Main Menu (Continue button, shown only once a save exists)
— nothing to build here for the default single-slot case.

**Two things worth knowing**: flag values must be JSON-safe (the same
constraint `GameManager.set_flag`/`get_flag` never itself enforced,
since nothing needed to serialize them before this existed) — and JSON
has no separate int type, so an int flag comes back as a float of the
same value after a load (harmless for the `==` comparisons dialogue/
quest flags normally do). And an old save under `user://saves/` doesn't
know about a level or item you've since renamed or deleted — delete
test saves (or call `SaveManager.delete_save()`) after a big content
restructure rather than debugging a "missing file" load error.

## Translations

Every piece of player-facing text goes through a translation key, never
a hardcoded string — `SCREAMING_SNAKE_CASE` with a domain prefix (`UI_`,
`ITEM_`, `DIALOGUE_`, `NPC_`), rows in `translations/*.csv`
(`keys,en,it`). The Item Tools/Dialogue Tools wizards scaffold the
*rows* automatically; you still fill in the actual English/Italian text.

Editing an existing `.csv` needs nothing else — Godot re-imports it, the
`.translation` resources update on their own. **Adding a new CSV file**
(a whole new text domain) needs one extra step so it's actually
registered: **Project > Tools > "Apply Retro Style Settings..."**, or
`godot --headless -s res://tools/setup_project.gd`.

## Dev tools

Headless maintenance scripts under `tools/`, not gameplay code:

- **`tools/setup_project.gd`** — `godot --headless -s
  res://tools/setup_project.gd`. Re-run (or use the in-editor "Apply
  Retro Style Settings..." menu item — same underlying code) after: a
  new `translations/*.csv` file; changing Visual Style, Force
  Resolution, or Forced Resolution; changing the action/bus lists at the
  top of `tools/project_setup.gd` (only relevant if you're editing the
  *template's own* input map/bus setup, not day-to-day content work).
  Max Texture Size is applied live and does **not** need a re-run.
- **`tools/smoke_test.gd`** — `godot --headless -s
  res://tools/smoke_test.gd`. Boots the persistent shell, starts a new
  game into `first_level_path`, checks the player/level/inventory came
  up clean. Run it any time after touching an autoload, `Main`, or
  `Player` — a quick "did I break the boot path" check, not a
  replacement for actually playing.

## Asset pipeline (Blender)

Two docs, different jobs — both assume glTF Binary (`.glb`) export,
1 Blender unit = 1 Godot meter, low-poly/small-texture/no-PBR:

- [`docs/blender_asset_guidelines.md`](blender_asset_guidelines.md) —
  **what should this asset look like, and where does it go.** Poly
  budgets, texture sizes, origin/pivot rules, and collision setup, split
  by category: static level geometry, grabbable/physics props,
  interactable set-dressing, weapons/equippable items (including the
  exact scale reference against the player's `EquipAnchor`), collectible/
  inventory items (world model + a 64×64-ish inventory icon), and
  entities (NPCs/animals/monsters). Ends with a quick-reference table
  and a handoff checklist — start here for any new asset.
- [`docs/blender_workflow.md`](blender_workflow.md) — **how do I actually
  rig and export something with animations.** The armature/weight-
  painting/Action-naming pipeline in full, worked through for a humanoid
  character (idle/walk/hello) and a quadruped, plus the common mistakes
  that break an import (unapplied transforms, missing fake user,
  mismatched loop frames, inconsistent Action naming). Go here once
  `blender_asset_guidelines.md` says something needs animation.

## What this template doesn't have yet

Worth knowing before you start relying on it: no player health/death
system (`DamageableComponent` exists and is ready to attach, but nothing
currently gives the *player* one or reacts to it dying), no enemy/AI of
any kind, no multi-slot save UI (the API supports it — see
[Save/load](#saveload) — only the screens don't exist). These are
deliberately left as game-specific content rather than core systems;
build them as part of your first real game, and port back to the master
template copy whatever turns out to be genuinely reusable (see "How to
use this project as a template" in [`CLAUDE.md`](../CLAUDE.md)).

## Decision table

| I want to... | Use |
|---|---|
| Add something the player can walk into and pick up/throw | `WorldItem`, `kind = PHYSICAL` |
| Add something that goes in the inventory | `WorldItem`, `kind = PICKUPABLE` + an `ItemData` (Item Tools wizard) |
| Add a weapon | Item Tools wizard, Type = Melee/Firearm — see the [melee-vs-ranged table](#data-resources) above for which |
| Add an NPC that talks | `NpcBody` + Dialogue Tools wizard's "New NPC dialogue..." |
| Add an NPC/target that can take damage | `DamageableComponent` as a child of its collider |
| Branch dialogue on player progress | `DialogueChoice.required_flag_key`/`required_flag_value` |
| Remember the player did something, across levels/saves | `GameManager.set_flag`/`get_flag` (any JSON-safe value) |
| Let the player leave through a door into another level | `SceneChangeTrigger`, `mode = EXCLUSIVE` |
| Stream in a sub-area without a full level swap | `SceneChangeTrigger`, `mode = ADDITIVE` |
| Make an object glow/pulse from code (hit flash, notice-me pulse) | `FresnelFlash` on a `RetroSurfaceMaterial`-shaded mesh |
| Blend two textures on one surface (decal, dirt overlay, tint) | `RetroSurfaceMaterial`'s two layers + `layer_blend_mode` |
| Play a one-shot/looping sound | `AudioManager.play_sfx_2d`/`play_sfx_3d`/`play_ambient` |
| Change music | `AudioManager.play_music`/`stop_music` |
| Drive an NPC's/the player's animation clips by state | `AnimationController` + an `AnimationSet` |
| Change the game's whole look (PS1/N64/GameCube) | Project Settings > Retro Style > Visual Style, then **Apply Retro Style Settings...** |
| Preview a Visual Style change without pressing Play | Drag in `core/visual_style/visual_style_preview.tscn` |
| Save/load the run | Already wired (Pause Menu, Main Menu) — see [Save/load](#saveload) for the API if you need it directly |
| Add new player-facing text | A key in the right `translations/*.csv`, `SCREAMING_SNAKE_CASE` with a domain prefix |
