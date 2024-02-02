const std = @import("std");
const events = @import("platform/events.zig");

pub const math = @import("math/math.zig");

pub const Application = @import("Application.zig");
pub const Window = @import("platform/window.zig").Window;
pub const Vulkan = @import("rendering/Vulkan.zig");

pub const EventQueue = @import("EventQueue.zig").EventQueue;
pub const WindowResizeEventQueue = EventQueue(WindowResizeEvent);
pub const WindowCloseEventQueue = EventQueue(WindowCloseEvent);
pub const WindowMinEventQueue = EventQueue(WindowMinimizeEvent);
pub const WindowMaxEventQueue = EventQueue(WindowMaximizeEvent);
pub const WindowResizeEvent = events.WindowResizeEvent;
pub const WindowMaximizeEvent = events.WindowMaximizeEvent;
pub const WindowMinimizeEvent = events.WindowMinimizeEvent;
pub const WindowCloseEvent = events.WindowCloseEvent;

test {
    @import("std").testing.refAllDecls(@This());
}
