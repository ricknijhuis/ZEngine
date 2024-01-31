const Vec = @import("vec.zig").Vec;
const Mat = @import("mat.zig").Mat;

pub const Vec4F = Vec(f32, 4);
pub const Vec3F = Vec(f32, 3);
pub const Vec2F = Vec(f32, 2);
pub const Mat4 = Mat(f32, 4, 4);
