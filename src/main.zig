const std = @import("std");
const engine = @import("engine");
const Application = engine.core.Application;
const Window = engine.platform.Window;
const VSyncMode = engine.rendering.Renderer.VSyncMode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const create_info = Application.CreateInfo{
        .allocator = allocator,
        .name = "test",
        .version = .{
            .major = 1.0,
            .minor = 0.0,
            .patch = 0.0,
        },
        .settings = .{
            .path = "settings.json",
            .display = .{
                .width = 1280,
                .height = 720,
                .mode = Window.Mode.windowed,
            },
            .graphics = .{
                .vsync = VSyncMode.double,
            },
        },
    };

    var app: Application = undefined;

    try Application.init(create_info, &app);
    defer app.deinit();

    app.run();
}
