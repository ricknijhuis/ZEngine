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

    const engine = addZEngineModule(b, target, optimize);
    const exe = addSandboxExe(engine, b, target, optimize);
    _ = exe; // autofix

    //addBuildAssetsSteps(b);

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

fn addSandboxExe(engine: *std.Build.Module, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "SurvivalConcept",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("engine", engine);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    return exe;
}

fn addBuildAssetsSteps(b: *std.Build) void {
    const build_step = b.step("Build assets", "Builds all assets to a temporary dir");
    build_step.makeFn = buildAssets;

    b.getInstallStep().dependOn(build_step);
}

fn addZEngineModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.addModule("ZEngine", .{
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (b.graph.env_map.get("VK_SDK_PATH")) |path| {
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
    _ = node; // autofix

    const b = step.owner;
    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const assets_dir_name = "assets";
    const assets_dir = b.build_root.handle.openDir("assets", .{ .iterate = true }) catch |err| {
        // no assets to process
        if (err == error.FileNotFound)
            return;

        return err;
    };

    const destination_path = try std.fs.path.join(allocator, &[_][]const u8{ "zig-out", "bin" });

    var walker = try assets_dir.walk(allocator);

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const extension = std.fs.path.extension(entry.basename);
            const source_file_name = entry.basename[0 .. entry.basename.len - extension.len];
            const source_dir_name = entry.path[0 .. entry.path.len - entry.basename.len];
            const source_path = try std.fs.path.join(allocator, &[_][]const u8{ assets_dir_name, source_dir_name });

            std.log.debug("{s}", .{extension});
            std.log.debug("{s}", .{source_file_name});
            std.log.debug("{s}", .{source_dir_name});
            std.log.debug("{s}", .{source_path});

            if (std.mem.eql(u8, ".glsl", extension)) {
                try buildGLSL(allocator, destination_path, source_path, entry.basename, source_file_name);
            }
        }
    }

    walker.deinit();
}

fn buildGLSL(allocator: std.mem.Allocator, destination_dir: []const u8, source_dir: []const u8, source_fullname: []const u8, source_name: []const u8) !void {
    const source = try std.fs.path.join(allocator, &[_][]const u8{ source_dir, source_fullname });
    const filename = try std.fmt.allocPrint(allocator, "{s}.spv", .{source_name});
    const destination = try std.fs.path.join(allocator, &[_][]const u8{ destination_dir, filename });

    var cmd = std.ChildProcess.init(&.{ "glslangValidator", "-V", source, "-o", destination }, allocator);

    try cmd.spawn();

    const term = try cmd.wait();

    switch (term) {
        .Exited => |exit_status| {
            if (exit_status != 0) {
                std.debug.print("Command failed with exit status: {}\n", .{exit_status});
            } else {
                std.debug.print("Command completed successfully.\n", .{});
            }
        },
        else => {},
    }
}
