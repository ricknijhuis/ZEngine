const std = @import("std");
const engine = @import("../root.zig");

const Self = @This();

pub const Mode = enum {
    windowed,
    borderless,
    fullscreen,
};

pub const Extend = struct {
    width: u32,
    height: u32,
};

pub const InitParams = struct {
    allocator: std.mem.Allocator,
    application: *engine.Application,
    mode: Mode,
    extend: Extend,
    close_event_writer: engine.WindowCloseEventQueue.Writer,
    resize_event_writer: engine.WindowResizeEventQueue.Writer,
    minimize_event_writer: engine.WindowMinEventQueue.Writer,
    maximize_event_writer: engine.WindowMaxEventQueue.Writer,
};
