const vulkan = @import("vulkan.zig");
const Self = @This();

pub fn init() !Self {}

pub fn deinit(self: Self) void {
    _ = self; // autofix
}

pub fn startFrame(self: Self) !void {
    _ = self; // autofix
}

pub fn endFrame(self: Self) !void {
    _ = self; // autofix
}
