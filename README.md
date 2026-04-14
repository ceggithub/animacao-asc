# 3D ASCII Animation Engine (Bash + AWK)

A minimalist 3D rendering engine built entirely with Bash and AWK. It uses mathematical projections to render 3D shapes (Torus and Sphere) directly in the terminal using ASCII characters.

## Features

- **Smooth 3D Rendering**: High-performance math handled by AWK.
- **Dynamic Shapes**: Toggle between a 3D Torus (Donut) and a 3D Sphere.
- **Color Modes**:
  - **Multicolor**: Depth-based lighting with 256-color ANSI gradients.
  - **Original**: Classic monochrome ASCII.
  - **Green Phosphor**: Retro terminal aesthetic.
- **Interactive Controls**: Real-time speed adjustment and shape/color toggling.
- **Responsive**: Automatically adjusts to terminal window resizing.

## Controls

| Key | Action |
|-----|--------|
| `Up Arrow` | Increase rotation speed |
| `Down Arrow` | Decrease rotation speed |
| `Space` / `F` | Toggle between Donut and Sphere |
| `C` | Cycle through color modes |
| `Q` | Quit and restore terminal |

## Requirements

- A POSIX-compatible shell (Bash recommended).
- `awk` (compatible with gawk, mawk, and nawk).
- A terminal supporting ANSI escape codes.

## How to Run

1. Make the script executable:
   ```bash
   chmod +x animacao_3d.sh
   ```
2. Run the animation:
   ```bash
   ./animacao_3d.sh
   ```

## Technical Details

The engine uses a parametric representation for shapes and a Z-buffer (depth buffer) implementation in AWK to handle overlapping surfaces correctly. Lighting is calculated based on the surface normal relative to a virtual light source, mapped to a set of ASCII characters `.,-~:;=!*#$@` representing luminance levels.
