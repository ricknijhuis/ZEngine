const types = @import("types.zig");
const math = @import("std").math;

pub const Vec4F = types.Vec4F;
pub const Vec3F = types.Vec3F;
pub const Vec2F = types.Vec2F;
pub const Mat4 = types.Mat4;

test {
    @import("std").testing.refAllDecls(@This());
}
