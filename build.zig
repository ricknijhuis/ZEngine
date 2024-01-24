const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const module = addZEngineModule(b, target, optimize);
    addBuildAssetsSteps(b);
    _ = module; // autofix

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn addBuildAssetsSteps(b: *std.Build) void {
    const build_step = b.step("Build assets", "Builds all assets to a temporary dir");
    build_step.makeFn = buildAssets;

    const cleanup_step = b.step("Cleanup assets", "Cleans any leftover from 'Build assets' step");
    cleanup_step.makeFn = cleanupAssets;

    b.getInstallStep().dependOn(build_step);
    b.getUninstallStep().dependOn(cleanup_step);
}

fn addZEngineModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.addModule("ZEngine", .{
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.env_map.get("VK_SDK_PATH")) |path| {
        std.log.info("VK_SDK_PATH: {s}", .{path});
        module.addLibraryPath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/lib", .{path}) catch @panic("OOM") });
        module.addIncludePath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/include", .{path}) catch @panic("OOM") });
    } else {
        std.log.err("Vulkan SDK not found", .{});
        std.os.exit(1);
    }

    module.link_libc = true;

    switch (target.result.os.tag) {
        .windows => {
            module.linkSystemLibrary("gdi32", .{});
            module.linkSystemLibrary("user32", .{});
            module.linkSystemLibrary("shell32", .{});
            module.linkSystemLibrary("vulkan-1", .{});
        },
        else => {
            std.log.err("Platform not supported", .{});
            std.os.exit(1);
        },
    }

    return module;
}

fn buildAssets(step: *std.Build.Step, node: *std.Progress.Node) anyerror!void {
    _ = step; // autofix
    _ = node; // autofix
    std.log.debug("build", .{});
}

fn cleanupAssets(step: *std.Build.Step, node: *std.Progress.Node) anyerror!void {
    _ = step; // autofix
    _ = node; // autofix
    std.log.debug("clean", .{});
}
