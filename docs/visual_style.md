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

These are starting points (`resources/visual_style/ps1.tres`, `n64.tres`,
`gamecube.tres`) — tune the fields to taste for your game, they aren't
meant to be precise console specs.

## Two layers, applied at two different times

`VisualStyleProfile` (`core/visual_style/visual_style_profile.gd`) has two
groups of fields, because they're safe to change at different points:

- **Texture filtering** (`texture_filter_nearest`, `mipmap_bias`,
  `anisotropic_filtering_level`) are default sampler settings — meaningful
  at renderer-startup time, not something to flip while the game is
  running. **`tools/setup_project.gd`** reads the profile named by its
  `VISUAL_STYLE_PROFILE_PATH` constant and bakes these into `project.godot`
  when you (re-)run it.
- **Fog, ambient light, background, color grading** are plain `Environment`
  properties — safe to change at any time. **`SettingsManager`** applies
  these to the persistent shell's `WorldEnvironment`
  (`ui/main/main.tscn`) every time `apply_settings()` runs, based on
  `SettingsManager.visual_style`.

## Choosing the style for a new game

Both places default to PS1. To use a different style:

1. Open `tools/setup_project.gd` and point `VISUAL_STYLE_PROFILE_PATH` at
   `res://resources/visual_style/n64.tres` (or `gamecube.tres`), then
   re-run it: `godot --headless -s res://tools/setup_project.gd`.
2. Open `autoload/settings_manager.gd` and change `DEFAULT_VISUAL_STYLE` to
   match (`SettingsManager.VisualStyle.N64` / `.GAMECUBE`).

Do both — they're independent because of the timing split above, and
leaving them mismatched means the baked texture filter and the runtime
fog/color grading come from two different styles.

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
