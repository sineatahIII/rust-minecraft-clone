# Rust Voxel Game - Minecraft Style

A Minecraft-inspired voxel game built with Rust and the Bevy game engine.

## Features

- **Procedurally generated terrain** using Perlin noise
- **5 block types**: Grass, Dirt, Stone, Wood, Sand
- **Break and place blocks** with mouse clicks
- **First-person flying camera** controls
- **Chunk-based world generation** with infinite terrain
- **Optimized rendering** (only visible blocks are rendered)
- **Dynamic chunk loading** as you explore

## Prerequisites

You need Rust installed on your system. If you don't have it:

### Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Or visit: https://rustup.rs/

## How to Run

1. Navigate to the project directory:
```bash
cd voxel_game
```

2. Run the game:
```bash
cargo run --release
```

The first build will take several minutes as it compiles Bevy and dependencies.

## Controls

### Movement
- **W/A/S/D** - Move forward/left/backward/right
- **Space** - Move up
- **Shift** - Move down
- **Mouse** - Look around

### Block Interaction
- **Left Click** - Break block
- **Right Click** - Place block
- **1** - Select Grass
- **2** - Select Dirt
- **3** - Select Stone
- **4** - Select Wood
- **5** - Select Sand

### Other
- **ESC** - Exit game

## Performance Tips

- The game runs in `--release` mode for better performance
- Render distance is set to 3 chunks (adjustable in code)
- Only exposed blocks are rendered (hidden blocks are culled)

## Project Structure

```
voxel_game/
├── Cargo.toml          # Dependencies and project config
├── src/
│   └── main.rs         # Main game code
└── README.md           # This file
```

## Technical Details

- **Engine**: Bevy 0.13 (ECS game engine)
- **Terrain Generation**: Perlin noise
- **Camera**: Fly camera with 6DOF movement
- **Rendering**: PBR materials with lighting and shadows
- **World**: HashMap-based chunk storage

## Customization

You can modify these constants in `main.rs`:

```rust
const CHUNK_SIZE: i32 = 16;        // Blocks per chunk
const CHUNK_HEIGHT: i32 = 64;      // Max world height
const RENDER_DISTANCE: i32 = 3;    // Chunks to render around player
```

## Troubleshooting

### Slow compilation
First compile takes 5-10 minutes. Use `--release` flag for better runtime performance.

### Low FPS
- Reduce RENDER_DISTANCE in code
- Make sure you're running with `--release` flag
- Close other applications

### Game doesn't start
- Make sure Rust is installed: `rustc --version`
- Check you're in the project directory
- Try `cargo clean` then `cargo run --release` again

## Future Improvements

- Add more block types
- Implement physics and collision
- Add block textures
- Implement proper chunk saving/loading
- Add inventory system
- Implement crafting
- Add day/night cycle
- Add mobs/entities

Enjoy building!
