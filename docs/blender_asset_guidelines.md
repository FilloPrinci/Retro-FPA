# Blender asset guidelines

Guidelines for modeling assets for this template in Blender: what to build,
how to build it, and how it plugs into the project once exported. Covers
every asset category — static level geometry, props, and entities (NPCs,
animals, monsters). For the full animation rigging/export pipeline, this
document summarizes the essentials and defers to
[`blender_workflow.md`](blender_workflow.md), which covers it in detail.

## The target look

Low-poly PS1 / N64 / GameCube-era style, rendered with Godot's GL
Compatibility renderer. Practically, this means:

- **Low-poly, faceted forms.** A few hundred to a few thousand triangles per
  asset is the target range, not a hard limit — see the per-category budgets
  below. Flat/hard-edge shading is in style, not a compromise; don't
  over-smooth.
- **Small, simple textures.** 64×64 to 256×256 per texture, a single
  color/albedo map per material in most cases — no PBR maps (normal,
  roughness, AO, ...), the compatibility renderer doesn't make good use of
  them and it breaks the era-accurate look. The project's default 2D texture
  filter is already Nearest, so textures stay crisp and unblurred
  automatically — don't pre-blur or add mipmapped detail expecting
  smoothing.
- **Consistent texel density.** Keep roughly the same texture-pixels-per-meter
  across every asset (aim for something clearly blocky, e.g. ~32 px/meter) so
  nothing looks conspicuously higher-res than its surroundings.
- **Minimal transparency.** Avoid materials that rely on alpha blending where
  possible (foliage cards, glass) — the compatibility renderer handles a few
  fine, but they don't sort well in numbers. Alpha *scissor*/cutout (e.g. a
  chain-link texture) is cheaper and safer than alpha blend.

## Shared rules for every asset

- **Scale**: 1 Blender unit = 1 Godot meter, real-world proportions. Use the
  player as your scale anchor — standing eye height is 1.6 m, crouching eye
  height is 1.0 m (`core/player/player.gd`). A doorway, a table, a weapon in
  someone's hand all need to read correctly against that.
- **Apply all transforms** (`Ctrl+A` → *All Transforms*) before export, every
  time — for rigged models this avoids skewed animation (see
  `blender_workflow.md`), and for everything else it avoids surprise scale/
  rotation after import.
- **Origin/pivot placement matters** — Godot instances a scene at its origin,
  and physics/animation both pivot around it:
  - Static architecture pieces: origin at the piece's floor-level corner, so
    modular pieces snap together predictably in the level editor.
  - Physics props (`Grabbable`): origin at the object's natural center of
    mass/balance point.
  - Hinged/pivoting props (doors, levers): origin at the hinge, not the
    center of the mesh.
  - Hand-held items: model to the scale/orientation implied by the player's
    equip anchor — see [Weapons and equippable items](#2c-weapons-and-equippable-items).
- **Keep meshes manifold** (no holes, no internal/duplicate faces) —
  especially for anything that becomes a `RigidBody3D` or gets its collision
  auto-generated from the mesh; a non-manifold mesh produces unstable or
  broken collision.
- **Export format**: glTF 2.0 Binary (`.glb`) for everything, always — it's
  Godot's native import format.
- **File naming and location**: `snake_case`, descriptive
  (`door_wood_01.glb`, `prop_lantern.glb`, `npc_villager_male.glb`). Drop
  into `assets/models/`; group into subfolders by category as the asset
  count grows (`assets/models/structures/`, `assets/models/props/`,
  `assets/models/entities/`) — `assets/models/` starts empty in the
  template, there's no fixed structure to match yet.

---

## 1. Static assets (structures, level architecture)

Walls, floors, ceilings, stairs, large fixed set pieces — anything that
becomes non-moving level geometry, dropped into a level scene under
`levels/` as a `StaticBody3D` (mesh + collision, the same pattern as the
`Floor` node in `levels/demo/demo_level_1.tscn`).

- **Build modular.** Model reusable pieces on a fixed grid unit (e.g. a 2 m or
  4 m wall/floor module) rather than one bespoke mesh per room. Levels get
  assembled by instancing and combining these pieces in the Godot editor —
  that's what keeps building a new level content work, not modeling work.
- **Poly budget**: a few hundred to a couple thousand triangles per modular
  piece is reasonable; think in terms of what a whole room adds up to, not
  just one piece in isolation.
- **Texture with a shared trim sheet.** Tile a handful of shared
  wall/floor/trim textures across every structural piece instead of
  unwrapping each piece uniquely — keeps texture memory low and every piece
  interchangeable.
- **Collision**: keep it simple. A wall or floor's collision should usually
  be a box, independent of whatever surface detail (trim, moldings) the
  visual mesh has — don't let Godot auto-generate a full trimesh collider
  from a highly detailed static mesh when a hand-placed box would do.
- No armature, no animation.

---

## 2. Props (interactive objects, set dressing, weapons, collectibles)

Props split into a few sub-categories because each pairs with a different
gameplay component. Confirm with whoever wires the scene which category a
given prop is before modeling it — it changes how the model should be built.

### 2a. Grabbable / physics props

Crates, bottles, tools — anything picked up and thrown via
`core/physics_grab/grabbable.gd`, which drives a `RigidBody3D`.

- Collision should approximate the shape with **convex primitives**
  (box/cylinder/capsule/convex hull), not a concave trimesh — dynamic
  `RigidBody3D`s need convex collision to behave stably under Jolt Physics.
  Simple shapes (crates, bottles) are usually fine with an auto-generated
  convex hull from the mesh; irregular shapes may need a hand-built
  compound collision instead.
  RigidBody3D uses its physical mass/scale together with `Grabbable.hold_distance`
  and `Grabbable.throw_force` (both tunable per-instance in the Inspector,
  not something to solve for in Blender) — just keep the model at a
  plausible real-world scale so those defaults feel right.
- Origin at the center of mass.
- No animation.

### 2b. Interactable set-dressing props

Doors, levers, switches, signs — anything paired with
`core/interaction/interactable_component.gd` that the player interacts with
(press "interact") rather than picks up.

- Origin at the pivot (a door's hinge edge, a lever's fulcrum), not the mesh
  center — this is what a Godot-side `AnimationPlayer` or script rotates
  around after import.
- Simple mechanical motion (a door swinging open, a lever tilting) can
  either be animated directly in Godot on the imported node (no Blender
  animation needed at all), or baked as a single Action in Blender and
  exported in the same `.glb` — no armature required for a single rigid
  mesh moving as one piece; a light 2-3 bone armature only if it needs to
  bend/articulate. Either approach is fine; agree with the programmer which
  one before building it, since it changes what gets exported.

### 2c. Weapons and equippable items

Anything assigned to an `ItemData` resource with
`item_type = EQUIPPABLE` (`core/inventory/item_data.gd`) and an
`EquippableBehavior` — held tools, flashlights, weapons.

- Model and scale to look correct when parented at the player's equip
  anchor: `Head/Camera3D/EquipAnchor` in `core/player/player.tscn`, local
  offset `(0.3, -0.3, -0.6)` from the camera, viewed at the camera's 70°
  FOV. Building/test-placing at roughly that offset from a first-person
  eye-level view is the most reliable way to get scale/position right
  without waiting for someone else to place it.
- If the item needs its own animation (idle sway, a swing, a reload), it can
  use a light armature or a single baked Action, exported the same way as
  any other animated model. **Note:** the template doesn't currently
  auto-play view-model animations — an `EquippableBehavior` subclass's
  `on_primary_use`/`on_secondary_use` would need to call an
  `AnimationPlayer`/`AnimationController` itself. Flag to the programmer
  when a weapon needs this so the behavior script accounts for it.
- Also needs a small **inventory icon** — see 2d, same requirement applies
  to `ItemData.icon`.

### 2d. Collectible / inventory items

Keys, notes, consumables — anything picked up into the inventory
(`ItemData`, `item_type` = `GENERIC`/`KEY`/`CONSUMABLE`).

Two deliverables per item, not one:

1. **World pickup model**, assigned to `ItemData.world_model` — simple, low
   detail (it's usually seen briefly and at a distance), paired with an
   `InteractableComponent` (and optionally `Grabbable`) in its own small
   scene.
2. **Inventory icon**, assigned to `ItemData.icon` — a flat `Texture2D`
   shown in the HUD and inventory grid, *not* a 3D asset. Render a small
   orthographic/quick-perspective shot of the model in Blender and export it
   as a PNG at a size consistent with other icons (64×64 is a reasonable
   default), matching the same low-res, unfiltered look as everything else.

Silhouette readability matters more than surface detail here — these render
very small.

---

## 3. Entities (NPCs, humans, animals, monsters)

Any animated character — human NPCs, animals, monsters. Full rigging/export
mechanics (armature setup, Action naming, export settings, common mistakes)
are already covered in detail in
[`blender_workflow.md`](blender_workflow.md); this section adds the
category-specific notes and how the result plugs into the project.

**Every entity needs, at minimum**: an `idle` and a `walk` Action, exactly
named lowercase (matching `AnimationSet.idle`/`AnimationSet.walk` in
`core/animation/animation_set.gd`). Anything beyond that (`attack`, `hello`,
`death`, a creature-specific state like `lunge`) is free-form and goes into
that character's `AnimationSet.custom_states` map — **agree on the exact
state name with the programmer before animating it**, since that name is
what code later calls `AnimationController.play_state("...")` with, and a
mismatch (typo, different casing) fails silently.

- **Humans / humanoid NPCs**: follow Example A in `blender_workflow.md`
  directly — root/hips, spine, head, two arms, two legs, no fingers, no
  facial rig. Clothing/accessories are simplest as part of the same mesh or
  as extra meshes parented to the armature (no cloth simulation — rigid
  attachment is period-correct for this style, not a shortcut).
- **Animals / quadrupeds**: follow Example B — 2-3 segment spine, neck/head,
  short tail, four legs, no toes. Watch the diagonal leg pairing on the
  `walk` cycle called out there; it's what sells a quadruped gait.
- **Monsters / non-standard creatures**: base the armature on whichever of
  the two archetypes above is closer to how it actually moves (or a hybrid),
  keeping the same low bone count. A creature with a genuinely unique
  locomotion or attack state still just needs its own lowercase Action name,
  agreed with the programmer up front so it lands correctly in
  `custom_states`.
- **Scale**: use the player's eye height (1.6 m standing, `player.gd`) as the
  proportion anchor for humanoid NPCs specifically, so they read correctly
  against the first-person camera.
- **Collision**: entities get simple capsule/cylinder collision set up
  directly on their Godot body node, independent of mesh detail — nothing to
  prepare for this in Blender.

### Animation authoring — quick checklist

(Full detail, including export settings and worked examples, in
[`blender_workflow.md`](blender_workflow.md).)

- One `Armature` per file; low bone count, no fingers, no facial rig.
- Actions named exactly by the lowercase logical state (`idle`, `walk`,
  `attack`, ...) — this is literally the string `AnimationSet`/
  `AnimationController` look up at runtime.
- Every Action needs a fake user (shield icon) or an NLA strip, or it's
  silently dropped on export.
- Looping clips (`idle`, `walk`, ...) need identical first and last frames,
  or the loop visibly pops.
- Export: glTF Binary, include Armature + Skinning, export all actions (or
  the NLA track), enable animation sampling.
- After import, create/update that character's `AnimationSet` `.tres` under
  `resources/animation_sets/` mapping `idle`/`walk` and any
  `custom_states` to the exact clip names Godot imported — double-check
  against the model's `AnimationPlayer`, since a typo'd clip name fails
  silently rather than erroring.

---

## Quick reference

| Category | Poly budget | Texture size | Origin | Collision | Animation |
|---|---|---|---|---|---|
| Static/structure | Few hundred–2k per module | 64–256 px, shared trim sheet | Floor-level corner | Simple box, separate from visual detail | None |
| Grabbable prop | Tens–low hundreds | 64–128 px | Center of mass | Convex primitive/hull | None |
| Interactable prop | Tens–low hundreds | 64–128 px | Pivot/hinge | Simple, matches motion | Optional, single Action or none |
| Weapon/equippable | Low hundreds | 64–128 px | Matches equip anchor scale | N/A (held, not physical) | Optional, light armature or baked Action |
| Collectible item | Tens | 64 px icon + tiny world model | Natural pickup point | Small convex/none | None |
| Entity (NPC/animal/monster) | Few hundred–2k | 64–256 px | Armature root at feet | Capsule/cylinder (set in Godot) | Required: `idle` + `walk`, plus any `custom_states` |

## Handoff checklist

Before considering an asset done:

- [ ] File named `snake_case`, exported as glTF Binary (`.glb`), transforms
      applied.
- [ ] Dropped into `assets/models/` (subfolder by category if one exists).
- [ ] Origin/pivot placed per the rules above for its category.
- [ ] For entities: exact Action names (and any new `custom_states` names)
      confirmed with the programmer.
- [ ] For collectible items and equippables: a matching icon delivered
      alongside the model.
- [ ] Opened once in the actual project (or handed off for someone to) to
      confirm scale/placement against the player — Blender viewport scale
      alone doesn't catch everything.
