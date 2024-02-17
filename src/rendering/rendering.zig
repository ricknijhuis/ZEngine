const std = @import("std");
const platform = @import("../platform/platform.zig");
const Window = platform.Window;

pub const Extend2D = struct {
    width: u32,
    height: u32,
};

pub const Renderer = struct {
    pub const VSyncMode = enum {
        none,
        double,
        tripple,
    };

    pub const CreateInfo = struct {
        allocator: std.mem.Allocator,
        vsync: VSyncMode,
        window_extend: Extend2D,
        window_events: Window.Events,
    };
};
