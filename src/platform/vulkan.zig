const builtin = @import("builtin");

pub const vulkan = switch (builtin.os.tag) {
    .windows => @import("win32/vulkan.zig"),
    .linux => error.PlatformNotImplemented,
    else => error.PlatformNotSupported,
};
