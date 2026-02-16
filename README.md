# 🌹 Blooming Rose &nbsp;<a href="https://uk.mathworks.com/matlabcentral/fileexchange/183268-bloomingrose"><img src="https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg" height="30"></a>&nbsp;<a href="https://matlab.mathworks.com/open/github/v1?repo=Vasileios-Bellos/BloomingRose"><img src="https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg" height="30"></a>&nbsp;<a href="https://vasileios-bellos.github.io/BloomingRose/"><img src="https://img.shields.io/badge/Live_Demo-Interactive_3D_GUI-e6454d?style=flat" height="30"></a>

A single rose blooms from a tight bud to full flower over 120 frames, rendered entirely on MATLAB using parametric surfaces. The rose sits on a botanically-inspired stem with a gently curved Bézier spine, five cupping sepals, and six thorns - all built from first principles with no external meshes or textures. The rose head geometry is adapted from [Eric Ludlam's original work](https://github.com/Vasileios-Bellos/BloomingRose?tab=readme-ov-file#acknowledgements).

<p align="center">
  <img src="gif/BloomingRose.gif" alt="Blooming Rose" width="50%">
</p>

---

## Quick Start

```matlab
BloomingRose
```

The animation loops continuously. Press **Space** to pause/unpause, **q** / **x** / **Esc** to quit. You can rotate the view interactively while it runs.

To switch the look, set a scene preset at the top of the script:

```matlab
scenePreset = 'turbo';
```

Or set `scenePreset = 'custom'` and dial in `colormapMode`, `customColormap`, `customCLim`, and `lightingMode` yourself.

## Scene Presets

Presets bundle the colormap mode, colormap, color limits, and lighting into a single setting. Set `scenePreset` to any of these:

| Preset | Look |
|--------|------|
| `'classic'` | Dynamic red ramp with full lighting - the default |
| `'matte red'` | Dynamic red with no lighting - flat, velvety |
| `'dark velvet'` | Black Baccara burgundy, full lighting, fixed CLim |
| `'rose gold'` | Coppery bronze to soft metallic pink, full lighting |
| `'aurora'` | Aurora Borealis palette, full lighting |
| `'neon'` | Cyberwave cyan-to-magenta, matte |
| `'frozen'` | Ice-blue palette, hybrid lighting, fixed CLim |
| `'solar'` | Solar Flare molten gradient, matte |
| `'phantom'` | Phantom Orchid silver-to-violet, hybrid lighting |
| `'radioactive'` | Neon green, matte |
| `'winter'` | MATLAB winter colormap, full lighting, fixed CLim |
| `'turbo'` | MATLAB turbo colormap, full lighting |

Set `scenePreset = 'custom'` to bypass presets and control everything manually via the Colormap and Lighting parameter sections.

## Colormaps

31 colormaps are available through `roseColormap('name')`, organized into two families.

**Real Rose Varieties** - modeled after actual cultivars: *Aobara* (Suntory Applause), *True Blue*, *Black Baccara*, *Classic Red*, *Juliet* (David Austin), *Amnesia*, *Quicksand*, *Sahara*, *Coral Reef*, *Hot Pink*, *Blush*, *Ocean Song*, *Golden Mustard*, *Ivory*, *Free Spirit*, *Burgundy*, *Rose Gold*, *White Mondial*, *Shocking Blue*, *Café Latte*, and *Mint Green*.

**Imaginary / Exotic** - artistic palettes, often best with a fixed `customCLim` like `[0 1.6]`: *Cyberwave*, *Solar Flare*, *Abyssal*, *Nebula*, *Molten Gold*, *Frozen*, *Radioactive*, *Obsidian Flame*, *Aurora Borealis*, and *Phantom Orchid*.

Any MATLAB built-in colormap also works: `roseColormap('turbo')`, `roseColormap('winter')`, etc.

## Colormap Modes

| Mode | Behavior |
|------|----------|
| `'static'` | Fixed 10-entry red colormap. Depth comes purely from Gouraud lighting. |
| `'dynamic'` | Distance-based vertex coloring through an evolving red ramp that starts nearly flat (hiding depth when closed) and progressively introduces dark values as the rose opens, creating fake shadow on top of the lights. |
| `'custom'` | User-selected colormap via `roseColormap('name')` with distance-based vertex coloring and a fixed palette (no evolution).

## Lighting Modes

| Mode | Rose | Stem / Sepals / Thorns |
|------|------|------------------------|
| `'full'` | Gouraud | Gouraud |
| `'hybrid'` | None (colormap only) | Gouraud |
| `'none'` | None | None - matte appearance |

The scene uses four lights: a headlight, two infinite white lights from different angles, and a dim fill light from below.

## Parameters

All parameters are defined at the top of the script and are exposed as interactive controls in both the GUI and the Live Script.

| Parameter | Description |
|-----------|-------------|
| `nFrames` | Animation frames (bud → full bloom) |
| `n` | Mesh resolution (n × n grid) |
| `A` | Petal height coefficient |
| `B` | Petal curl coefficient |
| `petalNum` | Petals per revolution |
| `stemLength` | Total stem length downward |
| `stemRadiusTop` | Radius near calyx |
| `stemRadiusBot` | Radius at base |
| `stemCurveX` | Lateral curve displacement |
| `stemCurveY` | Forward curve displacement |
| `nStemLen` | Segments along stem |
| `nStemCirc` | Segments around stem |
| `nSepals` | Number of sepals |
| `sepalLength` | Tip-to-base length |
| `sepalWidth` | Max width at midpoint |
| `sepalDroop` | Outward droop amount |
| `nThorns` | Number of thorns |
| `thornHeight` | Cone height |
| `thornRadius` | Cone base radius |

## Recording and Exporting

Set `recordFrames = true` to capture every frame during a single bloom pass. When the animation finishes, an export dialog appears with three options:

| Format | Notes |
|--------|-------|
| **MP4 Video** | Configurable FPS (default 60), Quality 95 |
| **Animated GIF** | Configurable FPS, optional dithering (on by default), global 256-color palette |
| **PNG Sequence** | Numbered frames, zero-padded filenames |

The dialog loops after each export - you can save the same recording in multiple formats before closing.

**Frame cropping** is controlled by `cropFrames`. Set to `true` for the default margins (15% left, 15% right, 10% top, 15% bottom), or provide a custom `[L R T B]` vector of fractions. Cropping is vectorized and runs once after all frames are captured.

A collection of pre-recorded animations showcasing various scene presets can be found in [gif](gif) and [Videos](Videos).

## Interactive GUI

```matlab
BloomingRoseGUI();
```

`BloomingRoseGUI` wraps the full animation in a `uifigure` with the 3D scene on the left and a collapsible accordion panel on the right. Every parameter — geometry, appearance, and playback — can be adjusted in real time through sliders, spinners, dropdowns, and color pickers, with the scene updating live as values change. The accordion is organized into six sections: **Playback**, **Appearance**, **Flower**, **Stem**, **Sepals**, and **Thorns**.

Scene presets, colormap modes, lighting modes, colormap limits, and background color are all accessible under Appearance. Recording and exporting work the same way as in the script, with dedicated Record and Export buttons and a crop toggle that applies at export time. The view can be rotated interactively while the animation runs.

### Controls

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `<` `>` | Step one frame backward / forward |
| `↑` `↓` | Speed ±0.5× |
| `L` | Toggle loop |
| `R` | Toggle recording |
| `P` | Save screenshot |
| `E` | Export recording |
| `C` | Toggle crop |
| `Home` / `End` | Jump to first / last frame |
| `q` / `x` / `Esc` | Quit |
| Mouse drag | Rotate view |

## Technical Details

### Rose Head

A 250×250 parametric surface mesh defined by three constants from Eric Ludlam's original (`A = 1.995653`, `B = 1.27689`, `petalNum = 3.6`). The petal envelope equation is:

```
x = 1 − ½ · ((5/4) · (1 − mod(petalNum·θ, 2π)/π)² − ¼)²
```

Bloom animation is driven by `openness` and `opencenter` curves over 120 frames, mapped from Eric Ludlam's 48-level scheme via `cospi`-based easing. These control `φ`, which governs how far each radial strip curls open.

### Stem

A cubic Bézier curve defines the spine as a gentle S-curve from the rose base downward. The spine is meshed into a tube by sweeping a circle along Frenet frames (tangent, normal, binormal from the Bézier derivative). The radius tapers from 0.055 (calyx) to 0.042 (base) with a Gaussian bulge at the calyx junction.

### Sepals

Five pointed leaf surfaces with a `sin(πu)^0.6` width profile, tapered by `(1 − u³)`. Placed at equal angular intervals around the stem top (offset from thorns by `π/10`), with inward cupping via `(1 − v²)` displacement.

### Thorns

Six cones with `(1 − u)^1.5` radius falloff, placed along 12%–85% of the stem. Each tilts 30° toward the stem tangent using a local frame built from the spine's Frenet vectors.

## Requirements

MATLAB R2020a or later (uses `vecnorm`, `ndgrid`, `cospi`). No toolboxes required for the animation itself. GIF export uses `rgb2ind` from the Image Processing Toolbox.

## File Structure

```
BloomingRose.m          - MATLAB Script: looping playback, export pipeline, keyboard controls
BloomingRoseGUI.m       - MATLAB App: interactive GUI with real-time parameter controls
BloomingRose_Live.mlx   - MATLAB Live Script: interactive sliders and dropdowns
index.html              - Web GUI: browser-based Three.js port (GitHub Pages live demo)
gif/                    - Animated GIFs of various scene presets
Videos/                 - MP4 recordings of various scene presets
```

## Acknowledgements

Rose head parametric equations by **[Eric Ludlam](https://www.mathworks.com/matlabcentral/profile/authors/869244)**, from "[Blooming Rose](https://uk.mathworks.com/matlabcentral/communitycontests/contests/6/entries/13857)" - [MATLAB Flipbook Mini Hack](https://uk.mathworks.com/matlabcentral/communitycontests/contests/6/entries) contest (2023). [Source code on GitHub](https://github.com/zappo2/digital-art-with-matlab/tree/master/flowers).

## Author

**[Vasilis Bellos](https://www.mathworks.com/matlabcentral/profile/authors/13754969)** - stem, sepals, thorns, colormap system, scene presets, export pipeline, lighting modes, interactive GUI & animation framework.

## License

[MIT](LICENSE)
