const std = @import("std");
const engine = @import("engine");

const Application = engine.Application;
const Window = engine.Window;
const Vulkan = engine.Vulkan;
const WindowCloseEventQueue = engine.WindowCloseEventQueue;
const WindowMaxEventQueue = engine.WindowMaxEventQueue;
const WindowMinEventQueue = engine.WindowMinEventQueue;
const WindowResizeEventQueue = engine.WindowResizeEventQueue;
const WindowResizeEvent = engine.WindowResizeEvent;
const WindowMaximizeEvent = engine.WindowMaximizeEvent;
const WindowMinimizeEvent = engine.WindowMinimizeEvent;
const WindowCloseEvent = engine.WindowCloseEvent;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const title = "test";

    var close_event_queue = try WindowCloseEventQueue.init(allocator);
    var resize_event_queue = try WindowResizeEventQueue.init(allocator);
    var maximize_event_queue = try WindowMaxEventQueue.init(allocator);
    var minimize_event_queue = try WindowMinEventQueue.init(allocator);

    var application: Application = undefined;
    {
        const init_params = Application.InitParams{
            .title = title,
            .version = "0.0.0",
            .close_event_reader = close_event_queue.getReader(),
        };
        application = Application.init(init_params);
    }

    var window: Window = undefined;
    {
        const init_params = Window.InitParams{
            .allocator = allocator,
            .application = &application,
            .close_event_writer = close_event_queue.getWriter(),
            .resize_event_writer = resize_event_queue.getWriter(),
            .minimize_event_writer = minimize_event_queue.getWriter(),
            .maximize_event_writer = maximize_event_queue.getWriter(),
            .mode = Window.Mode.windowed,
            .extend = .{ .width = 800, .height = 600 },
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
            .resize_event_reader = resize_event_queue.getReader(),
            .inflight_count = 2,
        };

        vulkan = try Vulkan.init(init_params);
    }
    defer vulkan.deinit();

    while (application.is_running) {
        window.pollEvents();

        application.on_update();
        vulkan.draw() catch {};

        minimize_event_queue.swap();
        maximize_event_queue.swap();
        close_event_queue.swap();
        resize_event_queue.swap();
    }
}

test "simple test" {}
