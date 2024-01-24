const builtin = @import("builtin");

pub const Window = switch (builtin.os.tag) {
    .windows => @import("win32/Window.zig"),
    .linux => error.PlatformNotImplemented,
    else => error.PlatformNotSupported,
};
