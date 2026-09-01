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

See "How to use this as a template" below for the concrete workflow, and
`docs/blender_workflow.md` for the animated-model pipeline.

## Architecture summary

- **Decoupled systems**: autoloads and components communicate through
  signals, never by reaching into each other's internals.
- **Data-driven content**: gameplay content (items, dialogue, animation
  mappings, surface sounds) lives in custom `Resource` (`.tres`) files
  editable from the Inspector, not hardcoded in scripts.
- **Persistent shell, disposable levels**: `ui/main/main.tscn` is the fixed
  run scene. It owns `CurrentLevel` (where level scenes are swapped in and
  out) and `UILayer` (menus/HUD, always present). The `Player` is
  instantiated on demand the first time gameplay starts, as a direct child
  of Main — it survives scene changes so inventory/state persist. Level
  scenes under `levels/` contain only geometry, `SpawnPoint`s, NPCs and
  triggers: never the player, never menus.
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
| `SettingsManager` | Persisted user prefs | `apply_settings`, `save_settings`/`load_settings` (`user://settings.cfg`), `settings_changed` signal |
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
   - `translations/*.csv`: new keys/text for that game.
   - `assets/`: your own models, textures, audio.
   - `first_level_path` export on `main_menu.gd`, pointing at the new
     game's first level.
3. What never changes: everything under `autoload/`, `core/`, and the
   generic screens in `ui/` (main, hud, menus, dialogue box, inventory ui).
   That is the reusable core — new games write content, not systems.
4. Bug fixes or improvements made to a core system while working on a
   specific game should be ported back to the master template copy so future
   games inherit them.

## Dev tools

`tools/` holds headless maintenance scripts, not gameplay code:

- `tools/setup_project.gd` — (re)generates the Input Map and Audio Bus
  Layout from code (`godot --headless -s res://tools/setup_project.gd`).
  Re-run it after changing the action/bus lists at the top of the file.
- `tools/smoke_test.gd` — boots the persistent Main shell, starts a new game
  into the demo level, and checks the player/level/inventory came up clean
  (`godot --headless -s res://tools/smoke_test.gd`). Useful after touching
  the autoloads or Main/Player scenes.

After adding or renaming a `class_name` script, rebuild the editor's global
class cache before relying on headless runs: `godot --headless --editor
--quit`.

## Maintenance note

When a core system is added or its API changes, update the autoload table
and conventions above in the same change.
