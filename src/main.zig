const std = @import("std");
const engine = @import("engine");

const Application = engine.Application;
const Window = engine.Window;
const Vulkan = engine.Vulkan;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const title = "test";

    var application = Application{
        .is_running = true,
        .title = title,
        .version = "0.0.0",
    };

    var window: Window = undefined;
    {
        const init_params = Window.InitParams{
            .allocator = allocator,
            .application = &application,
            .height = 600,
            .width = 800,
            .mode = Window.Mode.windowed,
        };

        window = try Window.init(init_params);
    }
    defer window.deinit();

    var vulkan: Vulkan = undefined;
    {
        const init_params = Vulkan.InitParams{
            .allocator = allocator,
            .application = &application,
            .window = &window,
            .inflight_count = 2,
        };

        vulkan = try Vulkan.init(init_params);
    }
    defer vulkan.deinit();

    while (application.is_running) {
        window.pollEvents();
        try vulkan.draw();
    }
}

test "simple test" {}
