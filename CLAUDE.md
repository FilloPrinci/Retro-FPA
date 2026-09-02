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

See "How to use this as a template" below for the concrete workflow,
`docs/blender_workflow.md` for the animated-model pipeline,
`docs/blender_asset_guidelines.md` for asset creation guidelines across every
category (statics, props, entities), and `docs/visual_style.md` for the
PS1/N64/GameCube visual style system.

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
| `SettingsManager` | Persisted user prefs + visual style + resolution | `apply_settings`, `save_settings`/`load_settings` (`user://settings.cfg`), `register_world_environment`, `visual_style` (`VisualStyle` enum, read live from its Project Setting — deliberately *not* persisted, since it has no Settings-menu control yet, see `docs/visual_style.md`), `window_resolution`/`fullscreen` (player-facing, persisted, in `ui/settings_menu/`), `is_resolution_forced`, `settings_changed` signal |
| `AudioManager` | Bus-based sound playback | `play_sfx_2d`/`play_sfx_3d`, `play_music`/`stop_music`, `play_ambient` |
| `InventoryManager` | Slot-based inventory + equip state | `add_item`/`remove_item`/`has_item`, `equip_slot`/`unequip`, `inventory_changed`/`item_equipped` signals |
| `DialogueManager` | Custom lightweight dialogue runner | `start_dialogue`, `advance`, `choose`, `end_dialogue`, `line_changed`/`choices_presented`/`dialogue_ended` signals |
| `SceneManager` | Level loading + game lifecycle | `register_main`, `start_new_game`, `change_scene`, `return_to_main_menu`, `scene_change_started`/`finished` signals |

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
  `docs/visual_style.md`), or adding a new `translations/*.csv` file.
- `tools/smoke_test.gd` — boots the persistent Main shell, starts a new game
  into the demo level, and checks the player/level/inventory came up clean
  (`godot --headless -s res://tools/smoke_test.gd`). Useful after touching
  the autoloads or Main/Player scenes.

After adding or renaming a `class_name` script, rebuild the editor's global
class cache before relying on headless runs: `godot --headless --editor
--quit`.

`addons/dialogue_tools/` is an in-editor plugin (Project Settings > Plugins)
for authoring NPCs and their dialogue without hand-writing `.tres`/CSV
content or scene nodes: a "Dialoghi" bottom-panel dock with a **New NPC**
button (scaffolds a placeholder body — `StaticBody3D` + boxed
`MeshInstance3D`/`CollisionShape3D` — under the selected node or the scene
root, see `npc_scaffolder.gd`), a **New NPC Dialogue** wizard (scaffolds a
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

## Maintenance note

When a core system is added or its API changes, update the autoload table
and conventions above in the same change.
