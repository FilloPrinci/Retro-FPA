# Retro FPA

Reusable Godot 4.6.3 template for small first-person horror games with a
low-poly PS1 / N64 / GameCube look. Renderer: GL Compatibility. Physics:
Jolt Physics (3D).

This file is the fast-context reference for any Claude Code session working
on this project (or on a copy of it). Keep it in sync whenever a core system
changes — it should always describe what the code actually does, not what
was originally planned.

## What this project is

Not a single game: a **template**. Every future horror game starts as a copy
of this project. The goal is that building a new game means writing content
(levels, dialogue, translations, models, materials) rather than writing new
systems.

See `docs/getting_started.md` for a hands-on, step-by-step walkthrough of
every reusable system (visual style, levels, physical/inventory objects,
weapons, NPCs/dialogue, damage, scene transitions) building a small game
from a fresh clone; "How to use this as a template" below for the
high-level workflow; `docs/blender_workflow.md` for the animated-model
pipeline; `docs/blender_asset_guidelines.md` for asset creation guidelines
across every category (statics, props, entities); and `docs/visual_style.md`
for the PS1/N64/GameCube visual style system.

## Architecture summary

- **Decoupled systems**: autoloads and components communicate through
  signals, never by reaching into each other's internals.
- **Data-driven content**: gameplay content (items, dialogue, animation
  mappings, surface sounds) lives in custom `Resource` (`.tres`) files
  editable from the Inspector, not hardcoded in scripts.
- **Persistent shell, disposable levels**: `ui/main/main.tscn` is the fixed
  run scene. It owns `CurrentLevel` (where level scenes are swapped in and
  out), `UILayer` (menus/HUD, always present) and `WorldEnvironment` (the
  project-wide fog/color-grading look, see `docs/visual_style.md`). The
  `Player` is instantiated on demand the first time gameplay starts, as a
  direct child of Main — it survives scene changes so inventory/state
  persist. Level scenes under `levels/` contain only geometry,
  `SpawnPoint`s, NPCs and triggers: never the player, never menus.
- **Game state drives UI, not the other way around**: `GameManager.state`
  (`MAIN_MENU` / `PLAYING` / `PAUSED` / `DIALOGUE` / `INVENTORY`) is the
  single source of truth. Menus, HUD and the player controller each react to
  `GameManager.state_changed` independently instead of being pushed around
  by a central UI controller. `GameManager` also owns the mouse cursor mode
  from this state: captured while `PLAYING`, visible for every other state.

## Autoloads

Registration order matters (see Project Settings > Autoload):
`GameManager` → `SettingsManager` → `AudioManager` → `InventoryManager` →
`DialogueManager` → `SceneManager`.

| Autoload | Responsibility | Key API |
|---|---|---|
| `GameManager` | Global game state, control locking, save-independent flags | `register_player`/`get_player`, `set_flag`/`get_flag`, `set_control_enabled`, `state` (`GameState` enum) + `state_changed` signal |
| `SettingsManager` | Persisted user prefs + visual style + resolution | `apply_settings`, `save_settings`/`load_settings` (`user://settings.cfg`), `register_world_environment`, `visual_style` (`VisualStyle` enum, read live from its Project Setting — deliberately *not* persisted, since it has no Settings-menu control yet, see `docs/visual_style.md`), `window_resolution`/`fullscreen`/`text_scale` (player-facing, persisted, in `ui/settings_menu/` — `text_scale` rescales every default-themed Control at once via a Theme assigned to the game window), `is_resolution_forced`, `settings_changed` signal |
| `AudioManager` | Bus-based sound playback | `play_sfx_2d`/`play_sfx_3d`, `play_music`/`stop_music`, `play_ambient` |
| `InventoryManager` | Slot-based inventory + equip state | `add_item`/`remove_item`/`has_item`, `equip_slot`/`unequip`, `inventory_changed`/`item_equipped` signals |
| `DialogueManager` | Custom lightweight dialogue runner | `start_dialogue`, `advance`, `choose`, `end_dialogue`, `line_changed`/`choices_presented`/`dialogue_ended` signals |
| `SceneManager` | Level loading + game lifecycle | `register_main`, `start_new_game`, `change_scene` (exclusive: replaces `CurrentLevel`, places the player; returns `bool` — `false` without doing anything if a change is already in progress, so a caller like `SceneChangeTrigger` knows not to treat a rejected call as done), `add_scene` (additive: instantiates alongside whatever's loaded, doesn't touch the player), `return_to_main_menu`, `scene_change_started`/`finished` signals |

No separate event bus: the signals on these autoloads already are the
decoupled communication channel.

## Conventions

- Files/folders: `snake_case`. Custom classes: `PascalCase` via
  `class_name`.
- Translation keys: `SCREAMING_SNAKE_CASE` with a domain prefix (`UI_`,
  `ITEM_`, `DIALOGUE_`, `NPC_`). Dialogue and UI text always reference a
  key, never hardcoded strings — see `translations/*.csv`.
- Animation clips baked into imported `.glb` models use lowercase,
  predictable names (`idle`, `walk`, `run`, `attack`, ...). A per-character
  `AnimationSet` resource maps the logical state to the actual clip name, so
  a model with different clip names only needs a new `.tres`, never a code
  change. Full workflow: `docs/blender_workflow.md`.
- All code, identifiers, comments, docs and commit messages are written in
  English.

## How to use this project as a template

This project *is* the template — not an addon to install elsewhere, a whole
project to duplicate.

1. Put it in its own git repository. On GitHub, mark it as a *Template
   repository* and use "Use this template" for each new game; without
   GitHub, keep a master copy and `cp -r` it per project.
2. What to change per new game (this is the only required work beyond
   content itself):
   - `project.godot`: `config/name`, `config/icon`.
   - `resources/` and `levels/`: replace the example `.tres` files (items,
     dialogue, animation sets) and demo levels with real content.
   - `translations/*.csv`: new keys/text for that game. Re-run
     `tools/setup_project.gd` after adding a new CSV file (not just editing
     an existing one) so its generated `.translation` resources get
     registered — Godot doesn't auto-load them otherwise.
   - `assets/`: your own models, textures, audio.
   - `first_level_path` export on `main_menu.gd`, pointing at the new
     game's first level.
   - Project Settings > General > Retro Style — Visual Style (the game's
     PS1/N64/GameCube look), plus optional resolution forcing and texture
     downsampling; see `docs/visual_style.md`.
3. What never changes: everything under `autoload/`, `core/`, `addons/`,
   and the generic screens in `ui/` (main, hud, menus, dialogue box,
   inventory ui). That is the reusable core — new games write content, not
   systems.
4. Bug fixes or improvements made to a core system while working on a
   specific game should be ported back to the master template copy so future
   games inherit them.

## Dev tools

`tools/` holds headless maintenance scripts, not gameplay code:

- `tools/setup_project.gd` — (re)generates the Input Map, Audio Bus Layout,
  visual style texture-filter/window-stretch defaults, and the registered
  translations list from code (`godot --headless -s
  res://tools/setup_project.gd`). Re-run it after changing the action/bus
  lists at the top of the file, the Visual Style or Force
  Resolution/Forced Resolution project settings (see
  `docs/visual_style.md`), or adding a new `translations/*.csv` file. Its
  actual logic lives in `tools/project_setup.gd` (`ProjectSetup.apply()`),
  shared with the in-editor equivalent — Project > Tools > "Apply Retro
  Style Settings..." (added by `addons/retro_visual_style`) — so changes
  made through Project Settings can be applied without a terminal.
- `tools/smoke_test.gd` — boots the persistent Main shell, starts a new game
  into the demo level, and checks the player/level/inventory came up clean
  (`godot --headless -s res://tools/smoke_test.gd`). Useful after touching
  the autoloads or Main/Player scenes.

After adding or renaming a `class_name` script, rebuild the editor's global
class cache before relying on headless runs: `godot --headless --editor
--quit`.

A placeholder NPC body needs no wizard: `core/npc/npc_body.gd` (`NpcBody`,
`class_name` + `@tool`) is a plain node added the same way as any other
(Create New Node > NpcBody) that builds its own boxed
`MeshInstance3D`/`CollisionShape3D` — sized like a standing person,
resting on the floor — the moment it has none yet, live in the editor.
Resize later via its `body_size` export; never rebuilds/resets a manual
reposition once the children exist. Prefer dragging in
`core/npc/npc_body.tscn` instead of Create New Node when you don't need to
watch it self-build: it's the same node with its default structure already
saved, so the Scene dock shows its children immediately — a node built
live by Create New Node is correct right away too (its `CollisionShape3D`
gizmo shows instantly), but the *dock listing itself* only catches up
after the scene is reloaded, a known Godot editor limitation of the
self-building-in-`_ready()` pattern (harmless, but worth dodging when you
don't care to watch it build).

`addons/dialogue_tools/` is an in-editor plugin (Project Settings > Plugins)
for authoring NPC dialogue without hand-writing `.tres`/CSV content: a
"Dialogues" bottom-panel dock with a **New NPC Dialogue** wizard (scaffolds a
`DialogueData`, an `InteractableComponent` + `DialogueTrigger` on the
selected node, and placeholder `translations/dialogue.csv` rows in one
step — see `dialogue_scaffolder.gd`) and a **Validate dialogues** button
(`dialogue_validator.gd` — checks every `resources/dialogues/*.tres` for
broken `next_id` references, unreachable lines, and text/speaker keys
missing from `translations/*.csv`). It also swaps the Inspector's free-text
`next_id`/flag fields on `DialogueLine`/`DialogueChoice` for dropdowns
populated from the dialogue actually being edited, so links can't be
typo'd, and shows each line/choice's actual EN/IT text inline (read from
and written straight to `translations/dialogue.csv`) instead of requiring
a trip to the CSV file. Everything runs from the dock/Inspector — no
terminal needed.

The same idea applies to world objects. `core/world_item/world_item.gd`
(`WorldItem`, `class_name` + `@tool`) is a node added like any other
(Create New Node > WorldItem) with a `kind` export toggling between
PHYSICAL (a grabbable prop: `RigidBody3D` + `Grabbable`, like the demo
Crate) and PICKUPABLE (`StaticBody3D` + `InteractableComponent` +
`ItemPickup`) — it builds/rebuilds the right body itself, same
model/material/body_size exports as `NpcBody`. `core/world_item/world_item.tscn`
is the same prefab shortcut as `npc_body.tscn` above (default `kind` =
PICKUPABLE; switch it in the Inspector after dragging in if you want
PHYSICAL). `addons/item_tools/` is the matching in-editor plugin: an
"Objects" dock with a **New object** wizard (scaffolds an `ItemData` .tres
— plus a `MeleeWeaponBehavior`/`RangedWeaponBehavior` .tres with sensible
defaults for melee/ranged — and placeholder `translations/items.csv` rows;
assigns the result straight to a selected `WorldItem`'s `item` field — see
`item_scaffolder.gd`) and a **Validate objects** button
(`item_validator.gd` — duplicate/missing ids, text/name keys missing from
`translations/*.csv`, a ranged weapon behavior with no `ammo_item` set).

Scene transitions follow the same self-building pattern:
`core/scene_management/scene_change_trigger.gd` (`SceneChangeTrigger`,
`class_name` + `@tool`) builds whatever `trigger_mode` needs — an `Area3D`
(walk into it) or a `StaticBody3D` + `InteractableComponent` (press
"interact") — and fires `SceneManager.change_scene`
(`mode = EXCLUSIVE`) or `SceneManager.add_scene` (`mode = ADDITIVE`) on
`target_scene`, once. `core/scene_management/scene_change_trigger.tscn` is
the prefab shortcut (default `trigger_mode` = AREA); either way you still
need to set `target_scene` yourself.

## Maintenance note

When a core system is added or its API changes, update the autoload table
and conventions above in the same change.
