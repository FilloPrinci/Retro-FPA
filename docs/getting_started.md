# Getting started: build a game from this template

A hands-on walkthrough of every reusable system in this template, in the
order you'd actually use them: clone the repo, pick a look, build a level,
place a grabbable prop, an inventory item, a weapon, an NPC with dialogue,
something that can take damage, and a second level to walk into. Each
section is short and ends with something you can press Play and see.

This is the practical companion to [`CLAUDE.md`](../CLAUDE.md) (architecture
reference), [`docs/visual_style.md`](visual_style.md) (full depth on the
PS1/N64/GameCube look), and the Blender docs
([`blender_workflow.md`](blender_workflow.md),
[`blender_asset_guidelines.md`](blender_asset_guidelines.md)) for real art
instead of the placeholder boxes used throughout this tutorial.

## 0. Get the template

On GitHub, use **"Use this template"** on the Retro-FPA repository (or, without
GitHub, keep a master copy and `cp -r` it) to start a new, independent
repository for your game. Open it in Godot 4.6.3, GL Compatibility, Jolt
Physics — already configured, nothing to change there.

The only things every new game is expected to touch immediately:

- **Project Settings > Application > Config > Name** (and **Icon**) — your
  game's actual name, not "Retro FPA".
- `ui/main_menu/main_menu.tscn` — select the `MainMenu` node and set its
  **First Level Path** export to your first level's `.tscn` once you've
  made one (step 2 below). "New Game" on the main menu calls
  `SceneManager.start_new_game(first_level_path)` — this is the one wire-up
  a new game needs, everything else about starting a run is generic.

Everything under `autoload/`, `core/`, `addons/`, and the generic screens in
`ui/` (main menu, HUD, pause, settings, dialogue box, inventory) is the
reusable core — you're not expected to touch any of it to make a game. If
you find yourself needing to, see "How to use this project as a template"
in `CLAUDE.md` for the intended workflow (fix the core, port the fix back
to the master template copy).

Run `tools/smoke_test.gd` any time you want a quick sanity check that
nothing is broken (`godot --headless -s res://tools/smoke_test.gd`) — it
boots the persistent shell, starts a new game into whatever
`first_level_path` points at, and checks the player/level/inventory came
up clean.

## 1. Pick a visual style

**Project > Project Settings > General > Retro Style > Visual Style** —
PS1, N64, or GameCube. Each bakes a different fog density, ambient light,
color grading and texture-filter feel; see
[`docs/visual_style.md`](visual_style.md) for the full breakdown of what
each one actually changes and why. Pick one now, you can change it any
time later — nothing else in this tutorial depends on which.

Two things to know right away, both covered in depth in that doc:

- **Some of it needs an apply step.** Texture filtering and anisotropic
  level are renderer-startup defaults baked into `project.godot` — after
  changing Visual Style (or Force Resolution / Max Texture Size), run
  **Project > Tools > "Applica impostazioni Retro Style..."** once (no
  terminal needed) so a fresh Play picks it up. Fog, color grading,
  background and Bloom apply live, no apply step needed.
- **You can preview it without pressing Play.** Drag
  `core/visual_style/visual_style_preview.tscn` into whatever scene you're
  editing to see fog/color grading/texture filter/bloom live in the 3D
  viewport as you tweak the Project Settings. Texture downsampling and
  resolution forcing aren't previewable this way (see the doc for why) —
  press Play to check those.

**Bloom** (Project Settings > Retro Style > `glow_*`) is independent of
which style you picked — it's a blanket post-process, on by default,
affecting anything bright enough in the scene (most commonly emissive
materials). Nothing to wire up per-object; tune intensity/strength/bloom/
threshold/blend mode to taste.

## 2. Build your first level

A level is just a scene under `levels/` containing geometry, `SpawnPoint`s,
NPCs and triggers — **never** the player, **never** menus (`Player` is
instantiated once by the persistent shell and survives scene changes;
menus live in `ui/main/main.tscn`'s `UILayer`, always present). Look at
`levels/demo/demo_level_1.tscn` for a working reference if you want one
side by side while you build your own.

Minimum viable level:

1. New scene, root `Node3D`, name it (e.g. `MyFirstLevel`).
2. A floor: `StaticBody3D` with a `MeshInstance3D` (a `BoxMesh` is fine to
   start) + a matching `CollisionShape3D`.
3. A `DirectionalLight3D` so it isn't pitch black.
4. A `SpawnPoint` (`core/scene_management/spawn_point.gd`) — plain `Node3D`
   with the script attached, positioned above the floor. Its `spawn_id`
   export defaults to `"default"`, which is also what
   `SceneManager.start_new_game()`/`change_scene()` look for when you don't
   specify one — leave it as `"default"` unless you have multiple spawn
   points in the same level (e.g. one per door you can enter from).
5. Save it, then set it as `MainMenu.first_level_path` (step 0) so "New
   Game" loads it.

Press Play. You should be standing on your floor, mouse captured, WASD
working, Tab opens the (still-empty) inventory, Esc pauses. That's the
entire persistent-shell/autoload machinery working for you already —
nothing above was game-specific code, only content.

## 3. A physical object: grab, carry, throw

Drag **`core/world_item/world_item.tscn`** into your level (a ready-made
prefab — see "Prefab scenes" below for what that means and why it's
better than building one by hand). Select it, in the Inspector:

- **Kind**: `Physical`.
- **Body Size**: e.g. `(0.5, 0.5, 0.5)` for a crate-sized box.
- **Material**: optional, any `StandardMaterial3D` to give the placeholder
  box some color while you don't have real art yet.

Press Play, walk up to it, look at it — the HUD shows **"[E] Grab"**. Press
E to pick it up and carry it in front of the camera; left-click to throw it
(a real physics impulse); press E again to just set it down. That's the
whole interaction model for physical props in this template: **E is always
the interact key** (grab, talk, open, pick up — everything), **left-click
is reserved for throwing** a currently-held object (or for whatever's
equipped, see step 5).

Under the hood: `Kind = Physical` builds a `RigidBody3D` with a `Grabbable`
(the physics side — `hold_distance`/`throw_force` exports) and an
`InteractableComponent` (the HUD prompt). The player's `Grabber` component
does the actual carrying/throwing; you never touch it.

## 4. An inventory item you can pick up

Same `world_item.tscn` prefab, different `Kind`:

1. Drag another `world_item.tscn` in (or duplicate the first one).
2. **Kind**: `Pickupable` (this is also the prefab's default, so a fresh
   drag-in already has it).
3. You need an `ItemData` to assign to its **Item** field — don't
   hand-write one. Select the `WorldItem` node, open the **"Oggetti"**
   dock (bottom panel; if you don't see it, it's enabled by default via
   Project Settings > Plugins > "Item Tools"), click **"Nuovo oggetto..."**
   ("New object"). Fill in "Nome oggetto (slug)" (id, e.g. `rusty_key`),
   "Nome visualizzato" (display name), "Descrizione" and optionally
   "Icona", and leave **Tipo** ("Type") at "Oggetto normale" ("Plain
   object") for something you don't equip and use (a key, a note, ...).
   Confirm — it creates the `ItemData` `.tres` under `resources/items/`,
   adds placeholder rows to `translations/items.csv`, and assigns itself
   to the selected `WorldItem` automatically.
4. Fill in the real English/Italian text for the two translation keys it
   created (`ITEM_<ID>_NAME`/`ITEM_<ID>_DESC`) in `translations/items.csv`
   — the wizard scaffolds the rows, not the copy.

Press Play, walk up, press E — the HUD shows **"[E] Take"**, the object
disappears from the world and appears in your inventory (Tab to check).
Click **"Valida oggetti"** ("Validate objects") in the same dock any time
to catch duplicate/missing ids or translation keys you forgot to fill in.

## 5. A weapon: melee and ranged

Same wizard, this time picking **Tipo**:

- **"Arma da mischia"** ("Melee weapon" — a knife, a pipe): scaffolds a
  `MeleeWeaponBehavior` alongside the `ItemData` with sensible defaults
  (damage 15, range 1.6, cooldown 0.4s) — infinite uses, no ammo.
- **"Arma da fuoco"** ("Firearm" — a pistol, a shotgun): scaffolds a
  `RangedWeaponBehavior` (damage 25, range 30, cooldown 0.35s) that
  consumes an **Ammo Item** on every shot. The wizard doesn't set
  `ammo_item` for you — create a plain ("Oggetto normale",
  `stackable = true`) ammo `ItemData` first (e.g. `pistol_ammo`), then open
  the ranged weapon's behavior `.tres` (under `resources/items/behaviors/`)
  and assign it to **Ammo Item**. "Valida oggetti" flags a ranged weapon
  with no ammo assigned, so you won't ship one by accident.

Place the weapon as a `Pickupable` `WorldItem` (step 4), and an ammo pickup
too if it's ranged (a plain item works the same way — quantity on the
`ItemPickup`/`WorldItem` is how many you get per pickup). Press Play, pick
both up, press **1**-**4** (`equip_slot_1`..`4`, whichever slot it landed
in) to equip the weapon — a view-model shows in first person (if you
assigned one via `ItemData.view_model`; a placeholder is fine to start),
left-click to attack. A melee swing is a short-range hitscan from the
camera; a ranged shot is the same hitscan at longer range, minus one round
from the inventory each time (silently does nothing, not even starting the
cooldown, if you're out of ammo).

Re-clicking the equipped slot in the inventory UI (or clicking an empty
slot) unequips it.

## 6. An NPC with dialogue

Drag **`core/npc/npc_body.tscn`** into your level. In the Inspector:

- **Body Size**: `(0.6, 1.7, 0.6)` (the default — roughly a standing
  person) is usually fine as-is.
- **Model**/**Material**: optional, swap in a real Blender-imported
  character later (see `docs/blender_workflow.md`); the placeholder
  capsule/box is enough to test dialogue right now.

Select it, open the **"Dialoghi"** dock, click **"Nuovo dialogo NPC..."**
("New NPC Dialogue"). This one step scaffolds: a `DialogueData` `.tres`
under `resources/dialogues/`, an `InteractableComponent` +
`DialogueTrigger` added as children of the selected `NpcBody`, and
placeholder rows in `translations/dialogue.csv` for the NPC's name and its
first line. Fill in the real text in that CSV, same as items.

Author the actual conversation from the Inspector on the `DialogueData`
resource (or from the dock, which shows each line's live EN/IT text
inline instead of making you round-trip through the CSV): each
`DialogueLine` has an `id`, a `speaker_name_key`/`text_key`, and either a
`next_id` (linear) or a list of `DialogueChoice`s (branching) — the dock's
Inspector swaps the free-text `next_id` fields for dropdowns populated
from the dialogue actually being edited, so a link can't be typo'd into a
line that doesn't exist. A choice can gate itself on a flag
(`required_flag_key`/`required_flag_value`, checked against
`GameManager.get_flag()`) and/or set one when picked
(`set_flag_key`/`set_flag_value`) — the same two fields exist on a line
too, set the moment it's shown — so you can branch a conversation on
what the player has already done without any code. Click **"Valida
dialoghi"** ("Validate dialogues") to catch broken `next_id`s, unreachable
lines, or missing translation keys.

Press Play, walk up to the NPC — **"[E] Talk"** — press E, the dialogue box
opens. Navigate choices with the same movement keys you walk with (arrows
or WASD), confirm with E — no mouse needed, though clicking a choice also
works and keeps keyboard/mouse selection in sync.

## 7. Something that can take damage

`DamageableComponent` (`core/combat/damageable_component.gd`) is a plain
`Node` you add as a child of any collider — a `NpcBody`, a `WorldItem`, a
one-off `StaticBody3D` you build by hand as a target dummy. Set
**Max Health** (0 opts out of health/death bookkeeping entirely — useful
for something a specific game wants to manage differently, like a boss
with phases — while `damaged` still fires every hit). Connect to its
`damaged(amount, source)`/`died` signals for whatever should happen next
(flinch animation, drop loot, AI reaction) — this component is
deliberately just the health bookkeeping, nothing else opinionated.

Point a weapon (step 5) at it and attack — `WeaponBehavior` raycasts from
the camera and looks for a `DamageableComponent` among the children of
whatever it hits, the same "look at the hit collider's children" pattern
`InteractableComponent`/`Grabbable` also use.

## 8. A second level, and a way to get there

Build a second level the same way as step 2 (or start from one of the two
ready-made examples already in the repo:
`levels/demo/exclusive_target.tscn` and `levels/demo/additive_target.tscn`
— small, self-contained, safe to look at or copy from).

Drag **`core/scene_management/scene_change_trigger.tscn`** into your first
level, near a doorway or the edge you want to leave through. In the
Inspector:

- **Trigger Mode**: `Area` (walk into it, no solid collision — good for an
  open doorway) or `Interact` (solid, press E — good for a real door).
- **Target Scene**: your second level's `.tscn`.
- **Mode**: `Exclusive` (replaces the current level entirely, places the
  player on `Target Spawn Id`'s matching `SpawnPoint` in the target scene —
  use this for "leaving through a door") or `Additive` (instantiates the
  target scene alongside whatever's already loaded, doesn't touch the
  player at all — use this for streaming in a sub-area, like unlocking a
  new wing of a house without a loading transition).
- **Show Transition**: whether to fade to black while loading. Worth
  turning off for a quiet `Additive` load — fading the whole screen just to
  add something in the background usually defeats the point.

Fires once, then stays inert — walking through a second time (or
interacting again) does nothing, so an `Additive` trigger never
double-adds its target.

## Prefab scenes: the "drag it in" shortcut

`world_item.tscn`, `npc_body.tscn` and `scene_change_trigger.tscn` (used
above) are ready-made instances of `WorldItem`/`NpcBody`/`SceneChangeTrigger`
with their default structure already built and saved — literally the same
node you'd get from **Create New Node > WorldItem** (etc.), just saved once
so you can drag it in instead. Configuring them is identical either way:
everything that matters is an export on the root node's Inspector.

The one thing dragging the prefab in gets you that Create New Node
doesn't: since the child nodes are already part of the saved scene, Godot
shows them in the Scene dock immediately. A node built fresh by Create New
Node is functionally correct right away too (its collision shape shows in
the 3D viewport instantly) — it's only the Scene dock's *tree list* that
lags behind and needs a scene reload to catch up, a Godot editor quirk with
nodes that build their own children in `_ready()`. Changing an export that
forks the structure afterward (`WorldItem.kind`,
`SceneChangeTrigger.trigger_mode`, `NpcBody.model`) can still hit that same
lag either way — rare enough in practice not to worry about, and a scene
reload always fixes it.

If you ever need to reach in and manually tweak a prefab's built children
directly (reposition the mesh, swap a material by hand instead of through
an export) — right-click the instance in the Scene dock and **"Fai
Locale"** ("Make Local"). This detaches that one placed copy from the
shared prefab permanently (it stops being a linked instance, so future
edits to `world_item.tscn` itself won't reach it anymore) in exchange for
full manual access to its nodes. Most of the time you won't need this —
reach for it only when an export genuinely doesn't cover what you're
trying to do.

## 9. Translations, end to end

Every piece of player-facing text in this template goes through a
translation key, never a hardcoded string — `SCREAMING_SNAKE_CASE` with a
domain prefix (`UI_`, `ITEM_`, `DIALOGUE_`, `NPC_`), rows live in
`translations/*.csv` (`keys,en,it`). The wizards used above (Item Tools,
Dialogue Tools) scaffold the *rows* for you automatically; you still have
to fill in the actual English/Italian text yourself.

Editing an existing `.csv` needs nothing else — Godot re-imports it and
the `.translation` resources update automatically. Adding a **new** CSV
file (a whole new domain, e.g. `translations/lore.csv`) needs one extra
step so it actually gets registered:
`godot --headless -s res://tools/setup_project.gd`, or Project > Tools >
"Applica impostazioni Retro Style..." (same shared `ProjectSetup.apply()`
either way — see step 1).

## 10. Before you ship

- **Project Settings > General > Retro Style**: revisit Force Resolution
  (bakes a real low-res internal render, e.g. 320×240 — see
  `docs/visual_style.md` for how this interacts with UI sizing) and Force
  Texture Downsample (shrinks oversized albedo textures to match the
  retro look) if you haven't already.
- Run **Project > Tools > "Applica impostazioni Retro Style..."** once
  more so every renderer-startup setting (texture filter, anisotropic
  level, forced resolution) is actually baked into `project.godot` and not
  just sitting as an unapplied Project Setting.
- Click **"Valida oggetti"**/**"Valida dialoghi"** one last time across the
  whole project.
- Swap placeholder boxes/capsules for real art — `docs/blender_workflow.md`
  for the animated-model pipeline, `docs/blender_asset_guidelines.md` for
  guidelines across every asset category.

## What you never had to write

Look back at what actually happened above: no autoload was touched, no
core script was opened, nothing was hand-wired with signals. Every step
was placing a prefab or a plain node, filling in an Inspector, and running
a wizard. That's the point of the template — `GameManager`, `SceneManager`,
`InventoryManager`, `DialogueManager`, `SettingsManager`, `AudioManager`
(see the autoload table in `CLAUDE.md`) and the whole `core/` library
already handle state, persistence, input, and UI reactions; a new game is
supposed to be entirely the content you just built.
