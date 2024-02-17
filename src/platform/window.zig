const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core/core.zig");

const Events = core.Events;

const c = switch (builtin.os.tag) {
    .windows => @cImport({
        @cDefine("WIN32_LEAN_AND_MEAN", "1");
        @cInclude("windows.h");
    }),
    else => @compileError("not supported"),
};

pub fn WindowImpl(comptime os: std.Target.Os.Tag) type {
    return switch (os) {
        inline .windows => struct {
            const Self = @This();

            pub const Mode = enum {
                fullscreen,
                borderless,
                windowed,
            };

            pub const ResizeEvent = struct {
                width: u32,
                height: u32,
            };

            pub const CloseEvent = struct {};

            pub const CreateInfo = struct {
                allocator: std.mem.Allocator,
                title: []const u8,
                width: u32,
                height: u32,
                mode: Mode,
                events: *Events,
            };

            handle: c.HWND,
            instance: c.HINSTANCE,
            width: u32,
            height: u32,

            pub usingnamespace @import("win32/window.zig");
        },
        else => {
            @compileError("Platform not supported");
        },
    };
}

pub const Window = WindowImpl(builtin.os.tag);
