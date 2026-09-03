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

Internal resolution and texture size are **not** part of this table — they
apply the same way regardless of which style is active. See
[Resolution and texture size](#resolution-and-texture-size) below.

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

Unlike the fields in the table above, these are **not** `VisualStyleProfile`
fields — they aren't really part of a specific console's "look", they're a
blanket dev choice on top of whichever style is active, so they're their
own Project Settings (Retro Style category, added by the same
`addons/retro_visual_style` plugin as Visual Style itself). They differ
from each other in *when* they take effect, though:

- **Force Resolution** (`retro_style/force_resolution`, bool) +
  **Forced Resolution** (`retro_style/forced_resolution`, e.g. `320x240`):
  baked into `project.godot` by
  `tools/setup_project.gd::_setup_window_stretch()` — as
  `display/window/stretch/mode = "viewport"`,
  `display/window/size/viewport_width`/`viewport_height` set to the forced
  resolution, and `window_width_override`/`window_height_override` set to
  a normal starting window size — **not** applied live by
  `SettingsManager`. It was, originally, via
  `Window.content_scale_mode`/`content_scale_size` at runtime; that
  produced a *wrongly-positioned* UI in an actual exported build (menus
  rendering shifted into a corner, not just wrongly scaled) even though the
  underlying anchor math checked out fine in isolation — changing a
  Window's content-scale properties at runtime, after it and its
  `CanvasLayer`s already rendered a frame, isn't reliable. Baking the
  equivalent `display/window/*` project settings before the window is ever
  created avoids that entirely — same reasoning, and the same fix, as the
  texture-filter fields already being baked this way. **Re-run
  `tools/setup_project.gd` after changing either of these**, same as the
  texture-filter fields — this is the one Retro Style setting pair that
  needs it (Visual Style's own texture-filter half does too; everything
  else applies live).

  **This affects the UI too, not just the 3D scene** — the low internal
  render resolution applies to everything drawn into the window, so every
  `CanvasLayer`/`Control` (HUD, menus, dialogue box) gets laid out within
  that same low-res canvas. There's no separate "crisp UI over blocky 3D"
  split here (that would need routing the 3D scene through its own
  `SubViewport`, which this template doesn't do — a bigger change than
  seemed worth it for the default 320×240/640×480 profiles). Practically:
  every menu panel's fixed pixel size needs to comfortably fit within the
  *smallest* resolution you expect to force. The existing menus
  (`ui/main_menu`, `ui/pause_menu`, `ui/settings_menu`, `ui/inventory_ui`)
  are all sized to fit inside 320×240 with margin to spare;
  `settings_menu.tscn` additionally splits its content across
  Audio/Video/General tabs (a `TabContainer`) rather than one long list, so
  only one category's rows need to fit at a time. Keep both in mind for any
  new menu: size it to fit 320×240, and reach for tabs or a
  `ScrollContainer` if the content genuinely can't be trimmed to fit.
- **Force Texture Downsample** (`retro_style/force_texture_downsample`,
  bool) + **Max Texture Size** (`retro_style/max_texture_size`, a
  128/256/512 dropdown): when the toggle is on, every
  `BaseMaterial3D.albedo_texture` wider or taller than this gets shrunk
  (aspect preserved, nearest-neighbor resize — deliberately blocky, not
  smoothed, to match the rest of the look) the same way
  `texture_filter_nearest` gets patched on. Only `albedo_texture`: this
  project's art direction is single-albedo, no PBR maps (see
  `docs/blender_asset_guidelines.md`), so that's the only slot that matters.
  Already-small textures are left alone — this only ever shrinks, so it's a
  safe no-op on repeated calls (every scene change re-applies it). Off by
  default.
- **Override Fog** (`retro_style/override_fog`, bool) + **Fog Enabled**
  (`retro_style/fog_enabled`, bool) + **Fog Color**
  (`retro_style/fog_color`) + **Fog Density**
  (`retro_style/fog_density`, range 0–0.2) + **Fog Depth Begin/End**
  (`retro_style/fog_depth_begin`/`fog_depth_end`, range in meters): when
  Override Fog is on, these five completely replace the active
  `VisualStyleProfile`'s `fog_*` fields — including forcing fog off on a
  style that normally has it on (N64), or on for one that normally doesn't
  (PS1). Applied in `SettingsManager._apply_visual_style()` right where the
  profile's own fog fields would otherwise be read, so it's a full swap,
  not a blend. Off by default — each style's own fog applies as documented
  in the table above.

## Resolution and fullscreen: the player-facing side

Unlike `visual_style`, **window resolution and fullscreen are already
exposed in `ui/settings_menu/`** — `SettingsManager.window_resolution`
(picked from `RESOLUTION_CHOICES`, a curated list) and
`SettingsManager.fullscreen`, both persisted like every other setting.

The Resolution dropdown only makes sense when the game isn't already
forcing its own internal resolution — picking "1920x1080" would do nothing
visible while PS1's 320×240 forcing is active, since the forced size wins
over `Window.size`. So `settings_menu.gd` checks
`SettingsManager.is_resolution_forced()` and swaps the dropdown for an
explanatory label in that case. Fullscreen stays available either way — it
toggles the OS window state, orthogonal to the internal render resolution.

`is_resolution_forced()` deliberately checks the *baked*
`display/window/stretch/mode` setting, not the `retro_style/force_resolution`
Project Setting directly — the Project Setting is only ever an intent,
`tools/setup_project.gd` has to be re-run for it to actually take effect
(see [Resolution and texture size](#resolution-and-texture-size) above), so
checking it directly could tell the player "resolution is fixed" while the
game is, in reality, still running unforced because the bake is stale.
Checking the baked setting instead means the Settings menu can't lie about
this, whatever state the toggle happens to be in — it costs you nothing to
verify: re-run the script, and the label starts telling the truth again.

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
3. Apply once to also bake the mipmap bias/anisotropic level into
   `project.godot` — these two are true renderer-startup defaults, so they
   only take effect after applying, not just from changing the Project
   Setting. Either Project > Tools > "Applica impostazioni Retro Style..."
   (no terminal needed) or `godot --headless -s
   res://tools/setup_project.gd` — both run the same
   `ProjectSetup.apply()` (`tools/project_setup.gd`). Skip this if you're
   only comparing styles quickly; do it before shipping so all three knobs
   agree.

`SettingsManager.VISUAL_STYLE_SETTING` and
`ProjectSetup.VISUAL_STYLE_SETTING` both point at `retro_style/visual_style`
— there's one value to change, not two constants to keep in sync.

Force Texture Downsample/Max Texture Size/Override Fog (and its 5 fog
fields) sit right next to Visual Style in the same Project Settings
category and take effect immediately at Play — no apply step needed for
those, since `SettingsManager` reads them live rather than baking anything
into `project.godot`.

Force Resolution/Forced Resolution are the exception: like the
texture-filter fields, they only take effect after applying (see
[Resolution and texture size](#resolution-and-texture-size) above for
why) — apply again after changing either one.

## Not (yet) a player-facing setting

`SettingsManager.visual_style` is **not** persisted to
`user://settings.cfg` — deliberately, unlike `locale`/`mouse_sensitivity`/
`window_resolution`/`fullscreen`. It's always re-read live from the
Project Setting, in both `load_settings()` and `apply_settings()`. This
was a real bug at one point: it *was* bundled into
`save_settings()`/`load_settings()` "for when it becomes player-facing
later," but since it has no Settings-menu control yet, nothing ever
*means* to save it — it just silently rode along the first time a player
saved any other setting (e.g. adjusting mouse sensitivity), freezing
whatever the Project Setting happened to be at that moment into
`user://settings.cfg` forever, so a later Project Settings change
appeared to do nothing.

Wiring up a real in-game "Visual Style" option later means: add an
`OptionButton` to `ui/settings_menu/` (the same way `settings_menu.gd`
already handles language), have it call
`SettingsManager.visual_style = ...`, and *at that point* also add
`visual_style` back into `save_settings()`/`load_settings()`'s `ConfigFile`
round-trip — persistence only belongs there once a menu control is the
thing setting it.

## Previewing in the editor, without pressing Play

`SettingsManager` is an autoload — autoloads don't exist while you're just
editing a scene (they only spin up once the game actually starts), so
none of the above shows up in the editor's 3D viewport by default. Drop
`core/visual_style/visual_style_preview.tscn` into whatever scene you're
editing (a level, `main.tscn`, anywhere) to preview it live instead:

- Fog, ambient light, background and color grading update every frame
  while the editor is open, straight from the current Retro Style Project
  Settings (Visual Style + the fog override, if on).
- `texture_filter_nearest` gets patched onto every `BaseMaterial3D` in the
  *edited scene* the same way `SettingsManager` patches it at runtime, so
  PS1's nearest-filter blockiness is visible directly on your level's
  materials.
- It's inert outside the editor — `Engine.is_editor_hint()` is false during
  actual Play/export, so it frees itself immediately rather than competing
  with the real `WorldEnvironment` in `ui/main/main.tscn`. Safe to leave in
  a level's saved scene permanently if you want the preview to just always
  be there while editing it.

**Deliberately not previewed**, both for good reasons:

- **Texture downsampling.** This mutates a texture's actual pixel data.
  At Play, that's fine — everything's discarded when you stop. In the
  editor, a session can stay open for hours, and if you hit Ctrl+S while a
  downsampled copy is loaded in memory, Godot can bake that lossy resize
  into the saved resource, permanently degrading the source art. Press
  Play to check this one instead of previewing it live.
- **Resolution forcing.** This is a property of the actual game window
  (`DisplayServer`/`Window`), which has no equivalent inside the editor's
  own viewport — there's nothing to preview here even in principle.

`VisualStyleProfile.apply_to_environment()` and `.resolve_texture_filter()`
are the shared logic behind both the preview script and
`SettingsManager` — added specifically so the two never drift apart into
two slightly-different implementations of the same thing.

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
