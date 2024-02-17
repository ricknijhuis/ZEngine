const std = @import("std");
const core = @import("core.zig");
const platform = @import("../platform/platform.zig");
const rendering = @import("../rendering/rendering.zig");

const Window = platform.Window;
const Time = core.Time;
const Input = core.Input;
const Events = core.Events;
const VSyncMode = rendering.Renderer.VSyncMode;

pub const Settings = struct {
    pub const Display = struct {
        width: u32,
        height: u32,
        mode: platform.Window.Mode,
    };

    pub const Graphics = struct {
        vsync: VSyncMode,
    };

    path: []const u8,
    display: Display,
    graphics: Graphics,
};

pub const CreateInfo = struct {
    name: []const u8,
    version: std.SemanticVersion,
    allocator: std.mem.Allocator,
    settings: Settings,
};

const Application = @This();

name: []const u8,
version: std.SemanticVersion,
allocator: std.mem.Allocator,
time: Time,
window: Window,
events: Events,
input: Input,
close: bool,

pub fn init(create_info: CreateInfo, application: *Application) !void {
    const name = try create_info.allocator.alloc(u8, create_info.name.len);
    @memcpy(name, create_info.name);

    application.name = name;
    application.version = create_info.version;
    application.allocator = create_info.allocator;
    application.close = false;

    try Time.init(&application.time);

    const input_create_info = Input.CreateInfo{
        .allocator = create_info.allocator,
    };

    try Input.init(input_create_info, &application.input);

    const events_create_info = Events.CreateInfo{
        .allocator = create_info.allocator,
    };

    try Events.init(events_create_info, &application.events);
    try application.events.registerEventType(Window.CloseEvent);
    try application.events.registerEventType(Window.ResizeEvent);
    try application.events.registerEventCallback(Window.CloseEvent, application, onWindowClose);

    const window_create_info = Window.CreateInfo{
        .title = create_info.name,
        .width = create_info.settings.display.width,
        .height = create_info.settings.display.height,
        .mode = create_info.settings.display.mode,
        .allocator = create_info.allocator,
        .events = &application.events,
    };

    try Window.init(window_create_info, &application.window);
}

pub fn run(self: *Application) void {
    while (!self.close) {
        self.time.update();
        self.window.pollEvents();
    }
}

pub fn deinit(self: *Application) void {
    self.allocator.free(self.name);
}

fn onWindowClose(cxt: ?*anyopaque, event: *const Window.CloseEvent) bool {
    _ = event; // autofix
    if (cxt) |context| {
        const self: *Application = @alignCast(@ptrCast(context));
        self.close = true;

        return true;
    }
    return false;
}

test "Application can init" {
    const testing = std.testing;

    const app_create_info = Application.CreateInfo{
        .allocator = testing.allocator,
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
                .vsync = Settings.Graphics.VSyncMode.double,
            },
        },
    };

    const app: Application = undefined;

    try Application.init(app_create_info, &app);
    defer app.deinit();

    app.run();
}
