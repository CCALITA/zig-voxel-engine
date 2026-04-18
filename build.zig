const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Dependencies ---

    // Vulkan bindings (generated from vk.xml at build time)
    const vk_dep = b.dependency("vulkan", .{
        .registry = b.path("deps/vk.xml"),
    });
    const vk_mod = vk_dep.module("vulkan-zig");

    // Math library
    const zmath_dep = b.dependency("zmath", .{});
    const zmath_mod = zmath_dep.module("root");

    // GLFW windowing
    const zglfw_dep = b.dependency("zglfw", .{});
    const zglfw_mod = zglfw_dep.module("root");

    // --- World modules (shared between engine and physics) ---
    const block_mod = b.addModule("block", .{
        .root_source_file = b.path("src/world/block.zig"),
        .target = target,
    });
    const chunk_mod = b.addModule("chunk", .{
        .root_source_file = b.path("src/world/chunk.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "block.zig", .module = block_mod },
        },
    });

    // --- Engine library module ---
    const engine_mod = b.addModule("engine", .{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vulkan", .module = vk_mod },
            .{ .name = "zmath", .module = zmath_mod },
            .{ .name = "zglfw", .module = zglfw_mod },
        },
    });
    engine_mod.linkLibrary(zglfw_dep.artifact("glfw"));

    // --- Main executable ---
    const exe = b.addExecutable(.{
        .name = "zig-voxel-engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "engine", .module = engine_mod },
                .{ .name = "vulkan", .module = vk_mod },
                .{ .name = "zglfw", .module = zglfw_mod },
            },
        }),
    });
    exe.root_module.linkLibrary(zglfw_dep.artifact("glfw"));

    b.installArtifact(exe);

    // Run step
    const run_step = b.step("run", "Run the voxel engine");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test step
    const engine_tests = b.addTest(.{
        .root_module = engine_mod,
    });
    const run_engine_tests = b.addRunArtifact(engine_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Physics collision tests
    const physics_collision_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/physics/collision.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "block", .module = block_mod },
                .{ .name = "chunk", .module = chunk_mod },
            },
        }),
    });
    const run_physics_collision_tests = b.addRunArtifact(physics_collision_tests);

    // Tree generation tests (rooted at src/world/ for relative import resolution)
    const tree_gen_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/trees_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tree_gen_tests = b.addRunArtifact(tree_gen_tests);

    // Cave generation tests (rooted at src/world/ for relative import resolution)
    const caves_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/caves_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_caves_tests = b.addRunArtifact(caves_tests);

    // Network protocol tests
    const network_protocol_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/network/protocol.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_network_protocol_tests = b.addRunArtifact(network_protocol_tests);

    // Network server tests
    const network_server_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/network/server.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_network_server_tests = b.addRunArtifact(network_server_tests);

    // Network client tests
    const network_client_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/network/client.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_network_client_tests = b.addRunArtifact(network_client_tests);

    // Redstone tests
    const redstone_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/redstone/redstone.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "block", .module = block_mod },
                .{ .name = "chunk", .module = chunk_mod },
            },
        }),
    });
    const run_redstone_tests = b.addRunArtifact(redstone_tests);

    // Redstone component tests
    const redstone_component_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/redstone/components.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_redstone_component_tests = b.addRunArtifact(redstone_component_tests);

    // Structure generation tests (rooted at src/world/ for relative import resolution)
    const structures_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/structures_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_structures_tests = b.addRunArtifact(structures_tests);

    // Experience system tests
    const experience_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/experience.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_experience_tests = b.addRunArtifact(experience_tests);

    // Gameplay game-mode tests
    const gamemode_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/gamemode.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_gamemode_tests = b.addRunArtifact(gamemode_tests);

    // Weather system tests
    const weather_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/weather.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_weather_tests = b.addRunArtifact(weather_tests);

    // Movement tests
    const movement_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/movement.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_movement_tests = b.addRunArtifact(movement_tests);

    // Farming tests
    const farming_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/farming.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_farming_tests = b.addRunArtifact(farming_tests);

    // Tile entity tests
    const tile_entity_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/tile_entity.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tile_entity_tests = b.addRunArtifact(tile_entity_tests);

    // Scoreboard tests
    const scoreboard_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/scoreboard.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_scoreboard_tests = b.addRunArtifact(scoreboard_tests);

    // Breeding system tests
    const breeding_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/breeding.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_breeding_tests = b.addRunArtifact(breeding_tests);

    // Command parser tests
    const commands_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/commands.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_commands_tests = b.addRunArtifact(commands_tests);

    // Block interaction tests
    const block_interact_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/block_interact.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_block_interact_tests = b.addRunArtifact(block_interact_tests);

    // End terrain generator tests
    const end_gen_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/end_gen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_end_gen_tests = b.addRunArtifact(end_gen_tests);

    // Ender Dragon entity tests
    const ender_dragon_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/ender_dragon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_ender_dragon_tests = b.addRunArtifact(ender_dragon_tests);

    // Fishing tests
    const fishing_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/fishing.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_fishing_tests = b.addRunArtifact(fishing_tests);

    // Food tests
    const food_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/food.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_food_tests = b.addRunArtifact(food_tests);

    // Vegetation generation tests (rooted at src/world/ for relative import resolution)
    const vegetation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/vegetation_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vegetation_tests = b.addRunArtifact(vegetation_tests);

    // Projectile system tests
    const projectiles_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/projectiles.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_projectiles_tests = b.addRunArtifact(projectiles_tests);

    // Hazards system tests
    const hazards_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/hazards.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_hazards_tests = b.addRunArtifact(hazards_tests);

    // Explosion system tests
    const explosion_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gameplay/explosion.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_explosion_tests = b.addRunArtifact(explosion_tests);

    // Villager entity tests
    const villager_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/villager.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_villager_tests = b.addRunArtifact(villager_tests);

    // Mob spawner tests
    const spawner_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/spawner.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_spawner_tests = b.addRunArtifact(spawner_tests);

    // Taming system tests
    const taming_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/taming.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_taming_tests = b.addRunArtifact(taming_tests);

    // Decoration entity tests
    const decorations_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/decorations.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_decorations_tests = b.addRunArtifact(decorations_tests);

    // Vehicle system tests
    const vehicles_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entity/vehicles.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vehicles_tests = b.addRunArtifact(vehicles_tests);

    // HUD data tests
    const hud_data_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ui/hud_data.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_hud_data_tests = b.addRunArtifact(hud_data_tests);

    // Transparent rendering pass tests
    const transparent_pass_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/renderer/transparent_pass.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "block", .module = block_mod },
                .{ .name = "chunk", .module = chunk_mod },
            },
        }),
    });
    const run_transparent_pass_tests = b.addRunArtifact(transparent_pass_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_engine_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_physics_collision_tests.step);
    test_step.dependOn(&run_tree_gen_tests.step);
    test_step.dependOn(&run_caves_tests.step);
    test_step.dependOn(&run_network_protocol_tests.step);
    test_step.dependOn(&run_network_server_tests.step);
    test_step.dependOn(&run_network_client_tests.step);
    test_step.dependOn(&run_redstone_tests.step);
    test_step.dependOn(&run_redstone_component_tests.step);
    test_step.dependOn(&run_structures_tests.step);
    test_step.dependOn(&run_experience_tests.step);
    test_step.dependOn(&run_gamemode_tests.step);
    test_step.dependOn(&run_weather_tests.step);
    test_step.dependOn(&run_movement_tests.step);
    test_step.dependOn(&run_farming_tests.step);
    test_step.dependOn(&run_tile_entity_tests.step);
    test_step.dependOn(&run_scoreboard_tests.step);
    test_step.dependOn(&run_breeding_tests.step);
    test_step.dependOn(&run_commands_tests.step);
    test_step.dependOn(&run_block_interact_tests.step);
    test_step.dependOn(&run_end_gen_tests.step);
    test_step.dependOn(&run_ender_dragon_tests.step);
    test_step.dependOn(&run_fishing_tests.step);
    test_step.dependOn(&run_food_tests.step);
    test_step.dependOn(&run_vegetation_tests.step);
    test_step.dependOn(&run_projectiles_tests.step);
    test_step.dependOn(&run_hazards_tests.step);
    test_step.dependOn(&run_explosion_tests.step);
    test_step.dependOn(&run_villager_tests.step);
    test_step.dependOn(&run_spawner_tests.step);
    test_step.dependOn(&run_taming_tests.step);
    test_step.dependOn(&run_decorations_tests.step);
    test_step.dependOn(&run_vehicles_tests.step);
    test_step.dependOn(&run_hud_data_tests.step);
    test_step.dependOn(&run_transparent_pass_tests.step);
}
