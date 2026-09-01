# Blender workflow: animated models for this template

This describes how to build an animated model in Blender so it drops into
this template without touching any code. The only thing that ever changes
per character is the `.glb` file and its matching `AnimationSet` resource
(`resources/animation_sets/*.tres`) — the `AnimationController` component
(`core/animation/animation_controller.gd`) used by the player and every NPC
is identical for every character.

## Shared principles

- Low-poly mesh: a few hundred to a few thousand triangles is the target for
  the PS1/N64/GameCube look, not a hard limit.
- Small textures (e.g. 64x64 to 256x256), no PBR maps — a single color/albedo
  texture is typical. The project's default 2D texture filter is already set
  to Nearest for crisp, unblurred pixels.
- One `Armature` per file. Keep the bone count low — no finger rigs, no
  facial rig, for this art style.
- Action names: lowercase, matching the logical state name exactly (`idle`,
  `walk`, `attack`, ...). This is what `AnimationSet` maps from.
- Export format: glTF 2.0 Binary (`.glb`) — Godot's native import format, no
  intermediate conversion needed.

## Example A — humanoid character (idle, walk, hello)

1. Model in low-poly, then apply all transforms (`Ctrl+A` → *All Transforms*)
   before rigging — skipping this causes skewed animations after export.
2. Add a simple Armature: root/hips, spine, head, two arms
   (upper_arm/forearm/hand each side), two legs (thigh/shin/foot each side).
   No fingers, no facial bones needed for this style.
3. Parent the mesh to the armature with automatic weights
   (`Ctrl+P` → *With Automatic Weights*), then fix problem areas manually in
   Weight Paint mode only where needed.
4. Create three separate Actions in the Action Editor / Dope Sheet, named
   exactly `idle`, `walk`, `hello`:
   - `idle`: short loop (~60-90 frames), light breathing/sway.
   - `walk`: cyclic loop (~24-30 frames); make the first and last frame
     identical so the loop doesn't pop.
   - `hello`: one-shot (not looping), e.g. a wave.
5. Give every Action a fake user (the shield icon in the Action Editor) or
   place it in an NLA strip — an Action with no user is dropped on export.
6. Export: *File → Export → glTF 2.0 (.glb)*. Key options: Format = glTF
   Binary, include Armature + Skinning, enable exporting all actions (or
   export the NLA track), enable animation sampling for compatibility.
7. Import: drop the `.glb` into `assets/models/`. Godot generates an
   `AnimationPlayer` with the three clips under those exact names
   automatically — no import settings to touch.
8. Create an `AnimationSet` resource in `resources/animation_sets/` with
   `idle = "idle"`, `walk = "walk"`, and `hello` added to `custom_states`
   (it isn't one of the base states). Assign it to whichever
   `AnimationController` uses this model.

## Example B — quadruped character, e.g. a dog (idle, walk, attack)

1. Same process, different armature: a 2-3 segment spine (for back flex), a
   neck/head, a tail (1-2 bones), and four legs
   (upper_leg/lower_leg/paw each). No toes needed.
2. Automatic weights first, then manual correction — shoulders and hips are
   where automatic weights most often go wrong on quadrupeds.
3. Actions named `idle` (weight-shift/breathing), `walk` (a 4-beat loop —
   pay attention to the diagonal leg pairing typical of a walking gait), and
   `attack` (one-shot, e.g. a bite or lunge).
4. Same glTF export, same automatic import.
5. A dedicated `AnimationSet` for the dog: `idle = "idle"`, `walk = "walk"`,
   `attack` in `custom_states`.
6. The `AnimationController` node is unchanged from the humanoid example —
   only the `AnimationSet` assigned to it differs. That's the point of the
   system: adding a new character type (human, dog, monster, ...) never
   requires new code, only a new model and a new `.tres`.

## Common mistakes

- Forgetting to apply transforms before rigging — causes skewed animation.
- Actions without a fake user / not referenced by any NLA strip — silently
  missing after export.
- `walk` loop with a different first and last frame — visible pop each loop.
- Inconsistent Action naming (capitals, spaces, typos) — breaks the mapping
  in the `AnimationSet` `.tres` silently; double-check the exact clip name
  Godot imported under the model's `AnimationPlayer`.
