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
}
