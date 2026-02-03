#!/bin/bash

# Rust Voxel Game Setup Script
# This script creates the complete project structure

echo "Creating Rust Voxel Game project..."

# Create project directory
PROJECT_DIR="$HOME/voxel_game"
mkdir -p "$PROJECT_DIR/src"

# Create Cargo.toml
cat > "$PROJECT_DIR/Cargo.toml" << 'EOF'
[package]
name = "voxel_game"
version = "0.1.0"
edition = "2021"

[dependencies]
bevy = "0.13"
bevy_flycam = "0.13"
noise = "0.8"
EOF

# Create src/main.rs
cat > "$PROJECT_DIR/src/main.rs" << 'EOF'
use bevy::prelude::*;
use bevy_flycam::{FlyCam, NoCameraPlayerPlugin};
use noise::{NoiseFn, Perlin};
use std::collections::HashMap;

const CHUNK_SIZE: i32 = 16;
const CHUNK_HEIGHT: i32 = 64;
const RENDER_DISTANCE: i32 = 3;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
enum BlockType {
    Air,
    Grass,
    Dirt,
    Stone,
    Wood,
    Sand,
}

impl BlockType {
    fn color(&self) -> Color {
        match self {
            BlockType::Air => Color::NONE,
            BlockType::Grass => Color::rgb(0.36, 0.73, 0.28),
            BlockType::Dirt => Color::rgb(0.55, 0.27, 0.07),
            BlockType::Stone => Color::rgb(0.5, 0.5, 0.5),
            BlockType::Wood => Color::rgb(0.63, 0.32, 0.18),
            BlockType::Sand => Color::rgb(0.96, 0.64, 0.38),
        }
    }
}

#[derive(Component)]
struct Block {
    block_type: BlockType,
    position: IVec3,
}

#[derive(Resource)]
struct World {
    blocks: HashMap<IVec3, BlockType>,
    perlin: Perlin,
}

impl World {
    fn new() -> Self {
        Self {
            blocks: HashMap::new(),
            perlin: Perlin::new(42),
        }
    }

    fn get_block(&self, pos: IVec3) -> BlockType {
        *self.blocks.get(&pos).unwrap_or(&BlockType::Air)
    }

    fn set_block(&mut self, pos: IVec3, block_type: BlockType) {
        if block_type == BlockType::Air {
            self.blocks.remove(&pos);
        } else {
            self.blocks.insert(pos, block_type);
        }
    }

    fn generate_terrain(&mut self, chunk_x: i32, chunk_z: i32) {
        for x in 0..CHUNK_SIZE {
            for z in 0..CHUNK_SIZE {
                let world_x = chunk_x * CHUNK_SIZE + x;
                let world_z = chunk_z * CHUNK_SIZE + z;

                let height = self.perlin.get([world_x as f64 * 0.05, world_z as f64 * 0.05]);
                let height = ((height + 1.0) * 0.5 * 15.0) as i32 + 5;

                for y in 0..=height {
                    let block_type = if y == height {
                        BlockType::Grass
                    } else if y >= height - 3 {
                        BlockType::Dirt
                    } else {
                        BlockType::Stone
                    };

                    self.set_block(IVec3::new(world_x, y, world_z), block_type);
                }
            }
        }
    }
}

#[derive(Resource)]
struct SelectedBlock(BlockType);

#[derive(Resource)]
struct LoadedChunks(HashMap<(i32, i32), bool>);

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Rust Voxel Game - Minecraft Style".to_string(),
                resolution: (1280., 720.).into(),
                ..default()
            }),
            ..default()
        }))
        .add_plugins(NoCameraPlayerPlugin)
        .insert_resource(World::new())
        .insert_resource(SelectedBlock(BlockType::Grass))
        .insert_resource(LoadedChunks(HashMap::new()))
        .add_systems(Startup, setup)
        .add_systems(Update, (
            load_chunks_around_player,
            block_interaction,
            update_selected_block,
            render_blocks,
        ))
        .run();
}

fn setup(
    mut commands: Commands,
    mut world: ResMut<World>,
    mut loaded_chunks: ResMut<LoadedChunks>,
) {
    for chunk_x in -RENDER_DISTANCE..=RENDER_DISTANCE {
        for chunk_z in -RENDER_DISTANCE..=RENDER_DISTANCE {
            world.generate_terrain(chunk_x, chunk_z);
            loaded_chunks.0.insert((chunk_x, chunk_z), true);
        }
    }

    commands.spawn((
        Camera3dBundle {
            transform: Transform::from_xyz(8.0, 20.0, 8.0)
                .looking_at(Vec3::new(0.0, 10.0, 0.0), Vec3::Y),
            ..default()
        },
        FlyCam,
    ));

    commands.spawn(DirectionalLightBundle {
        directional_light: DirectionalLight {
            illuminance: 10000.0,
            shadows_enabled: true,
            ..default()
        },
        transform: Transform::from_xyz(50.0, 100.0, 50.0)
            .looking_at(Vec3::ZERO, Vec3::Y),
        ..default()
    });

    commands.insert_resource(AmbientLight {
        color: Color::WHITE,
        brightness: 0.3,
    });
}

fn load_chunks_around_player(
    camera_query: Query<&Transform, With<FlyCam>>,
    mut world: ResMut<World>,
    mut loaded_chunks: ResMut<LoadedChunks>,
) {
    if let Ok(transform) = camera_query.get_single() {
        let player_chunk_x = (transform.translation.x / CHUNK_SIZE as f32).floor() as i32;
        let player_chunk_z = (transform.translation.z / CHUNK_SIZE as f32).floor() as i32;

        for chunk_x in (player_chunk_x - RENDER_DISTANCE)..=(player_chunk_x + RENDER_DISTANCE) {
            for chunk_z in (player_chunk_z - RENDER_DISTANCE)..=(player_chunk_z + RENDER_DISTANCE) {
                if !loaded_chunks.0.contains_key(&(chunk_x, chunk_z)) {
                    world.generate_terrain(chunk_x, chunk_z);
                    loaded_chunks.0.insert((chunk_x, chunk_z), true);
                }
            }
        }
    }
}

fn render_blocks(
    mut commands: Commands,
    world: Res<World>,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    block_query: Query<(Entity, &Block)>,
    camera_query: Query<&Transform, With<FlyCam>>,
) {
    if !world.is_changed() {
        return;
    }

    for (entity, _) in block_query.iter() {
        commands.entity(entity).despawn();
    }

    let camera_pos = camera_query
        .get_single()
        .map(|t| t.translation)
        .unwrap_or(Vec3::ZERO);

    for (&pos, &block_type) in world.blocks.iter() {
        if block_type == BlockType::Air {
            continue;
        }

        let block_world_pos = Vec3::new(pos.x as f32, pos.y as f32, pos.z as f32);
        if block_world_pos.distance(camera_pos) > (RENDER_DISTANCE * CHUNK_SIZE) as f32 {
            continue;
        }

        let neighbors = [
            IVec3::new(pos.x + 1, pos.y, pos.z),
            IVec3::new(pos.x - 1, pos.y, pos.z),
            IVec3::new(pos.x, pos.y + 1, pos.z),
            IVec3::new(pos.x, pos.y - 1, pos.z),
            IVec3::new(pos.x, pos.y, pos.z + 1),
            IVec3::new(pos.x, pos.y, pos.z - 1),
        ];

        let is_exposed = neighbors.iter().any(|&neighbor_pos| {
            world.get_block(neighbor_pos) == BlockType::Air
        });

        if !is_exposed {
            continue;
        }

        commands.spawn((
            PbrBundle {
                mesh: meshes.add(Cuboid::new(1.0, 1.0, 1.0)),
                material: materials.add(StandardMaterial {
                    base_color: block_type.color(),
                    ..default()
                }),
                transform: Transform::from_xyz(
                    pos.x as f32,
                    pos.y as f32,
                    pos.z as f32,
                ),
                ..default()
            },
            Block {
                block_type,
                position: pos,
            },
        ));
    }
}

fn block_interaction(
    mut world: ResMut<World>,
    selected_block: Res<SelectedBlock>,
    mouse_input: Res<ButtonInput<MouseButton>>,
    camera_query: Query<&Transform, With<FlyCam>>,
) {
    if let Ok(camera_transform) = camera_query.get_single() {
        let forward = camera_transform.forward();
        let start = camera_transform.translation;

        for distance in 1..=10 {
            let point = start + forward * distance as f32;
            let block_pos = IVec3::new(
                point.x.round() as i32,
                point.y.round() as i32,
                point.z.round() as i32,
            );

            let current_block = world.get_block(block_pos);

            if mouse_input.just_pressed(MouseButton::Left) && current_block != BlockType::Air {
                world.set_block(block_pos, BlockType::Air);
                break;
            }

            if mouse_input.just_pressed(MouseButton::Right) && current_block == BlockType::Air {
                for check_distance in 1..distance {
                    let check_point = start + forward * check_distance as f32;
                    let check_pos = IVec3::new(
                        check_point.x.round() as i32,
                        check_point.y.round() as i32,
                        check_point.z.round() as i32,
                    );
                    
                    if world.get_block(check_pos) != BlockType::Air {
                        world.set_block(block_pos, selected_block.0);
                        break;
                    }
                }
                break;
            }

            if current_block != BlockType::Air {
                break;
            }
        }
    }
}

fn update_selected_block(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut selected_block: ResMut<SelectedBlock>,
) {
    if keyboard_input.just_pressed(KeyCode::Digit1) {
        selected_block.0 = BlockType::Grass;
        println!("Selected: Grass");
    } else if keyboard_input.just_pressed(KeyCode::Digit2) {
        selected_block.0 = BlockType::Dirt;
        println!("Selected: Dirt");
    } else if keyboard_input.just_pressed(KeyCode::Digit3) {
        selected_block.0 = BlockType::Stone;
        println!("Selected: Stone");
    } else if keyboard_input.just_pressed(KeyCode::Digit4) {
        selected_block.0 = BlockType::Wood;
        println!("Selected: Wood");
    } else if keyboard_input.just_pressed(KeyCode::Digit5) {
        selected_block.0 = BlockType::Sand;
        println!("Selected: Sand");
    }
}
EOF

echo ""
echo "✅ Project created successfully at: $PROJECT_DIR"
echo ""
echo "To run the game:"
echo "  cd $PROJECT_DIR"
echo "  cargo run --release"
echo ""
echo "Note: First compilation will take 5-10 minutes."
