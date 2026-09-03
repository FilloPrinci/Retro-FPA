# Retro FPA

A reusable [Godot 4.6.3](https://godotengine.org/) template for building small first-person
horror games with a low-poly PS1 / N64 / GameCube look. GL Compatibility renderer, Jolt
Physics (3D).

This isn't a single game — it's a **template**. Every new game starts as a copy of this
project, and building it means writing content (levels, dialogue, translations, models,
materials), not new systems. The decoupled autoloads, data-driven `Resource` content, and
self-building/prefab nodes described below are already done; a new game just fills them in.

## Features

- **Retro visual style system** — PS1/N64/GameCube presets (fog, ambient light, color
  grading, nearest/linear texture filtering), plus independent toggles for forced low
  internal resolution, texture downsampling, and bloom — live-previewable in the editor
  viewport with no need to press Play.
- **Data-driven branching dialogue** — a lightweight custom runner reading `DialogueData`
  `.tres` resources: linear or branching lines, flag-gated choices, keyboard or mouse
  navigation.
- **Inventory, pickups and weapons** — slot-based inventory, equip hotbar, stackable items,
  melee and ranged weapons with hitscan damage and ammo consumption, all defined as
  `ItemData` resources.
- **Physical interaction** — grab, carry and throw physics props; every interaction (talk,
  pick up, grab, open a door) uses one consistent key.
- **NPCs and scene transitions** — self-building placeholder NPC bodies, and a scene-loading
  trigger supporting both area-walk-in and press-to-interact activation, exclusive or
  additive loading.
- **Full translation pipeline** — every player-facing string goes through a
  `SCREAMING_SNAKE_CASE` key backed by CSV-driven `.translation` resources.
- **In-editor authoring tools, no terminal required** — dedicated bottom-panel docks
  ("Objects", "Dialogues") with wizards that scaffold items/dialogue and their translation
  rows in one step, plus one-click validators that catch broken references and missing
  translations before they ship. Ready-made prefab scenes for every reusable node
  (`NpcBody`, `WorldItem`, `SceneChangeTrigger`) — drag one in and configure it from the
  Inspector.

## Requirements

- [Godot 4.6.3](https://godotengine.org/), GL Compatibility rendering method.
- Jolt Physics (3D) — already the project's configured physics engine.

## Getting started

1. On GitHub, use **"Use this template"** to start your own repository from this one (or,
   without GitHub, keep a master copy and `cp -r` it per project).
2. Open the project in Godot 4.6.3.
3. Follow **[docs/getting_started.md](docs/getting_started.md)** — a hands-on, step-by-step
   walkthrough that builds a small game from the fresh clone: picking a visual style, your
   first level, a grabbable prop, an inventory item, a melee/ranged weapon, an NPC with
   branching dialogue, something that can take damage, and a second level to walk into.

## Documentation

- **[docs/getting_started.md](docs/getting_started.md)** — the tutorial above; start here.
- **[docs/visual_style.md](docs/visual_style.md)** — full depth on the PS1/N64/GameCube
  visual style system: what each field does, resolution forcing, texture downsampling,
  bloom, and how to preview changes without pressing Play.
- **[docs/blender_workflow.md](docs/blender_workflow.md)** — the animated-model pipeline,
  from Blender rig to an in-game `AnimationSet`.
- **[docs/blender_asset_guidelines.md](docs/blender_asset_guidelines.md)** — asset creation
  guidelines across every category (statics, props, entities).
- **[CLAUDE.md](CLAUDE.md)** — the architecture reference: every autoload's responsibility
  and API, project conventions, and the intended template workflow (what to change per game,
  what never changes, and how to port core fixes back to the master template copy).

## Project layout

| Path | Contents |
|---|---|
| `autoload/` | Global singletons — game state, settings, audio, inventory, dialogue, scene loading. Never game-specific. |
| `core/` | Reusable components and data-resource definitions (interaction, inventory, dialogue, combat, physics grab, NPCs, world items, scene transitions, animation, audio). |
| `addons/` | In-editor tooling: the Retro Style Project Settings plugin, and the Item/Dialogue Tools docks and wizards. |
| `ui/` | The persistent shell and every generic menu/HUD screen (main menu, pause, settings, inventory, dialogue box). |
| `levels/` | Game content: level scenes built from `core/` components. Start here for a new game. |
| `resources/` | Game content: item, dialogue, and visual style `.tres` data. |
| `translations/` | Game content: `.csv` source files for every player-facing string. |
| `assets/` | Game content: models, textures, audio. |
| `tools/` | Headless maintenance scripts (`setup_project.gd`, `smoke_test.gd`) — dev-only, not shipped gameplay code. |
| `docs/` | The documentation linked above. |

`autoload/`, `core/`, `addons/` and the generic screens in `ui/` are the reusable core —
building a new game means writing content under `levels/`, `resources/`, `translations/` and
`assets/`, not touching those.
