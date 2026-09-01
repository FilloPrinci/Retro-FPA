# Visual style: PS1 / N64 / GameCube

A per-game choice of retro rendering look, driven by a `VisualStyleProfile`
resource. This covers what's actually implemented — global texture
filtering, fog, ambient light, background and basic color grading — not a
full hardware-accurate emulation of any of the three consoles. See
[Scope and what's not covered](#scope-and-whats-not-covered) below for the
line drawn here.

## What each style actually changes

| | PS1 | N64 | GameCube |
|---|---|---|---|
| Texture filter | Nearest (crisp, blocky) | Linear + mipmap blur bias (soft) | Linear, no extra blur |
| Anisotropic filtering | Off | Off | Low |
| Fog | Off by default | Heavy, close (hides short draw distance, background color matches fog so it blends into the "sky") | Light, far |
| Color grading | Slightly higher contrast, reduced saturation | Reduced contrast and saturation (hazy) | Neutral |
| Internal resolution | Forced 320×240 | Forced 320×240 | Forced 640×480 |
| Max texture size | 128px | 256px | 512px |

These are starting points (`resources/visual_style/ps1.tres`, `n64.tres`,
`gamecube.tres`) — tune the fields to taste for your game, they aren't
meant to be precise console specs.

## Two mechanisms, because 3D materials don't have a global default

`VisualStyleProfile` (`core/visual_style/visual_style_profile.gd`) has two
groups of fields, applied two different ways — not because one is more
"runtime-safe" than the other, but because **`BaseMaterial3D` (and imported
glTF materials) always has an explicit `texture_filter`** (default: linear
with mipmaps) rather than inheriting a project-wide default the way
`CanvasItem`/UI textures do. There is no single setting that makes every 3D
material in the game use nearest filtering.

- **`mipmap_bias` and `anisotropic_filtering_level`** genuinely are global
  renderer defaults. **`tools/setup_project.gd`** reads the chosen style
  and bakes these into `project.godot` when you (re-)run it.
- **`texture_filter_nearest`** has no such global knob, so
  **`SettingsManager`** patches it directly onto every `BaseMaterial3D` it
  can find, by walking the live scene tree — once in `apply_settings()`,
  and again whenever new 3D content appears
  (`SceneManager.scene_change_finished`, `GameManager.player_registered`).
  It mutates the shared `Material` *resources* in place, not per-instance
  overrides, so a material reused across many meshes only needs patching
  once and stays consistent — this only affects the running session, never
  anything saved to disk. `ShaderMaterial`s are left alone (see
  [Scope and what's not covered](#scope-and-whats-not-covered)).
- **Fog, ambient light, background, color grading** are plain `Environment`
  properties — safe to change at any time. `SettingsManager` applies these
  to the persistent shell's `WorldEnvironment` (`ui/main/main.tscn`) the
  same way.

## Resolution and texture size

Two more per-style knobs, both applied by `SettingsManager` the same way as
`texture_filter_nearest` (a live scene-tree/window pass, not a project
setting):

- **`force_resolution_enabled` + `forced_resolution`**: when on, the game
  renders internally at `forced_resolution` (e.g. PS1's 320×240) and
  stretches that up to fill the window — `Window.content_scale_mode =
  CONTENT_SCALE_MODE_VIEWPORT`. This is independent of the actual window
  size or fullscreen state: a 320×240-rendered game can still run in a
  1920×1080 window or fullscreen, it just looks blocky at any size, which
  is the point. When off, nothing is forced and the window renders at its
  native size.
- **`force_texture_downsample_enabled` + `max_texture_size`** (128/256/512):
  when on, every `BaseMaterial3D.albedo_texture` wider or taller than this
  gets shrunk (aspect preserved, nearest-neighbor resize — deliberately
  blocky, not smoothed, to match the rest of the look) the same way
  `texture_filter_nearest` gets patched on. Only `albedo_texture`: this
  project's art direction is single-albedo, no PBR maps (see
  `docs/blender_asset_guidelines.md`), so that's the only slot that matters.
  Already-small textures are left alone — this only ever shrinks, so it's
  a safe no-op on repeated calls (every scene change re-applies it).

## Resolution and fullscreen: the player-facing side

Unlike `visual_style`, **window resolution and fullscreen are already
exposed in `ui/settings_menu/`** — `SettingsManager.window_resolution`
(picked from `RESOLUTION_CHOICES`, a curated list) and
`SettingsManager.fullscreen`, both persisted like every other setting.

The Resolution dropdown only makes sense when the active style *isn't*
forcing its own internal resolution — picking "1920x1080" would do nothing
visible while PS1's 320×240 forcing is active, since the forced size wins
(`Window.content_scale_size` always takes priority over `Window.size` for
what actually gets rendered). So `settings_menu.gd` checks
`SettingsManager.is_resolution_forced()` and swaps the dropdown for an
explanatory label in that case. Fullscreen stays available either way — it
toggles the OS window state, orthogonal to the internal render resolution.

## Choosing the style for a new game

Both mechanisms read the same source: **Project > Project Settings >
General > Retro Style > Visual Style** — a PS1/N64/GameCube dropdown added
by `addons/retro_visual_style` (an `EditorPlugin`, enabled by default; the
raw value lives at `retro_style/visual_style` in `project.godot`, 0/1/2).
No script editing needed for the common case:

1. Pick the style in Project Settings and close the dialog (it saves
   `project.godot` immediately).
2. Press Play — fog, color grading, background and the nearest/linear
   material filter already reflect the new style, since `SettingsManager`
   reads the same setting as its default at startup.
3. Re-run `godot --headless -s res://tools/setup_project.gd` once to also
   bake the mipmap bias/anisotropic level into `project.godot` — these two
   are true renderer-startup defaults, so they only take effect after a
   (re-)run, not just from changing the Project Setting. Skip this if
   you're only comparing styles quickly; do it before shipping so all three
   knobs agree.

`SettingsManager.VISUAL_STYLE_SETTING` and
`tools/setup_project.gd::VISUAL_STYLE_SETTING` both point at
`retro_style/visual_style` — there's one value to change, not two
constants to keep in sync.

## Not (yet) a player-facing setting

`SettingsManager.visual_style` is persisted exactly like `locale` or
`mouse_sensitivity` (same `ConfigFile`, same `apply_settings()` path), so
the plumbing for an in-game "Visual Style" option already exists. It isn't
wired into `ui/settings_menu/` on purpose — this is meant as an
art-direction choice for the game, not something a player switches
mid-playthrough. Wiring it up later is just adding a control (an
`OptionButton`, the same way `settings_menu.gd` already handles language)
that sets `SettingsManager.visual_style` and calls `apply_settings()`.

## Scope and what's not covered

The look that most reads as "PS1" — wobbling vertices (affine precision
loss), warping textures (affine texture mapping instead of perspective-
correct), and dithered/banded color — isn't implemented here. Those need a
custom vertex/fragment shader that individual materials opt into, not
something a global setting can apply to arbitrary `StandardMaterial3D`s.
If that level of fidelity is wanted later, the plan is: a shared shader
under `resources/materials/` exposing the same kind of style parameters via
a [global shader parameter](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#global-uniforms)
(so `SettingsManager` can still drive it centrally), documented as a
convention in `docs/blender_asset_guidelines.md` for which materials should
use it.
