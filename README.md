# Godot Studio

A small standalone **world / terrain editor** built in Godot 4.6 (Forward+,
Vulkan). Sculpt terrain, paint simple materials, drop in colored boxes, and tune
water, fog, weather, day-night and lighting — then save the map.

Everything renders from plain GDScript with simple built-in materials — no
external art, shaders, or textures required, so the editor runs self-contained
straight from a clone. Drop your own `.glb` models under `assets/` if you want.

## Quick start

```bash
./install.sh   # fetches a standalone Godot into ./.godot-bin (no root)
./run.sh       # launch the editor   (./run.sh -e opens the Godot editor)
```

On Windows, run `run-editor.bat` instead (after placing `godot.exe` in `.godot-bin\`).

## What it does

- **Terrain** — sculpt, flatten, match-height, set-elevation, noise
- **Materials** — paint simple colored terrain materials (grass, dirt, rock,
  sand, snow, lava), shown as per-vertex colors
- **Objects** — place / erase plain colored boxes; select, group and duplicate
- **Environment** — water (drain / fill), fog, weather, a day-night cycle, and a
  lighting / look-tuning panel
- **Character mode** — drop in and run around the world you just built
- **Save / load** worlds, with a minimap and undo

## Layout

```
project.godot          Project config + the Config autoload (grid + material constants)
tools/godot_studio.*   The editor (the project's main scene)
scripts/               Editor systems — terrain, materials, water, weather,
                       lighting, save/load, character mode
tests/                 Headless logic tests (./run_tests.sh)
```

If a machine lacks Vulkan, set `rendering/renderer/rendering_method` to
`gl_compatibility` in `project.godot`.
