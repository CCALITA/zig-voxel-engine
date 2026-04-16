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
    const noise_mod = b.addModule("noise", .{
        .root_source_file = b.path("src/world/noise.zig"),
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

    // Physics collision tests — wire world modules via named imports.
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

    // Cave generation tests — wire world modules via named imports.
    const caves_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/world/worldgen/caves.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "block", .module = block_mod },
                .{ .name = "chunk", .module = chunk_mod },
                .{ .name = "noise", .module = noise_mod },
            },
        }),
    });
    const run_caves_tests = b.addRunArtifact(caves_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_engine_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_physics_collision_tests.step);
    test_step.dependOn(&run_caves_tests.step);
}
