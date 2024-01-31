const std = @import("std");

pub fn Vec(comptime Scalar: type, dimensions: u32) type {
    return extern struct {
        vec: @Vector(dimensions, Scalar),

        pub const n = n;

        const Self = @This();

        pub usingnamespace switch (dimensions) {
            inline 2 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar) Self {
                    return .{ .vec = .{ xs, ys } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.vec[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.vec[1];
                }
            },
            inline 3 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar) Self {
                    return .{ .vec = .{ xs, ys, zs } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.vec[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.vec[1];
                }

                pub inline fn z(self: Self) Scalar {
                    return self.vec[2];
                }
            },
            inline 4 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar, ws: Scalar) Self {
                    return .{ .vec = .{ xs, ys, zs, ws } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.vec[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.vec[1];
                }

                pub inline fn z(self: Self) Scalar {
                    return self.vec[2];
                }

                pub inline fn w(self: Self) Scalar {
                    return self.vec[3];
                }
            },
            else => {
                @compileError("Dimension not supported");
            },
        };

        pub inline fn splat(value: Scalar) Self {
            return .{ .vec = @splat(value) };
        }

        pub inline fn magnitude(self: Self) Scalar {
            return std.math.sqrt(@reduce(.Add, self.vec * self.vec));
        }

        pub inline fn normalize(self: Self) Self {
            return self.div(Self.splat(self.magnitude()));
        }

        pub inline fn add(self: Self, other: Self) Self {
            return .{ .vec = self.vec + other.vec };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return .{ .vec = self.vec - other.vec };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return .{ .vec = self.vec * other.vec };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return .{ .vec = self.vec / other.vec };
        }

        pub inline fn dot(self: Self, other: Self) Scalar {
            return @reduce(.Add, self.mul(other).vec);
        }

        pub inline fn cross(self: Self, other: Self) Self {
            return switch (dimensions) {
                inline 3 => .{ .vec = (@shuffle(Scalar, self.vec, undefined, [3]i32{ 1, 2, 0 }) * @shuffle(Scalar, other.vec, undefined, [3]i32{ 2, 0, 1 })) -
                    (@shuffle(Scalar, self.vec, undefined, [3]i32{ 2, 0, 1 }) * @shuffle(Scalar, other.vec, undefined, [3]i32{ 1, 2, 0 })) },
                else => {
                    @compileError("Dimension not supported for cross product");
                },
            };
        }
    };
}

pub const Vec4F = Vec(f32, 4);
pub const Vec3F = Vec(f32, 3);
pub const Vec2F = Vec(f32, 2);

// Vec2F tests
test "Vec2 can init" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 2.0);
}

test "Vec2 can splat" {
    const testing = std.testing;

    const vec = Vec2F.splat(1.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 1.0);
}

test "Vec2 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectEqual(result, 2.82842712474619);
}

test "Vec2 add returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);
    const other = Vec2F.init(2.0, 3.0);
    const result = vec.add(other);

    try testing.expectEqual(result.x(), 3.0);
    try testing.expectEqual(result.y(), 5.0);
}

test "Vec2 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);
    const other = Vec2F.init(2.0, 3.0);
    const result = vec.sub(other);

    try testing.expectEqual(result.x(), -1.0);
    try testing.expectEqual(result.y(), -1.0);
}

test "Vec2 mul returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);
    const other = Vec2F.init(2.0, 3.0);
    const result = vec.mul(other);

    try testing.expectEqual(result.x(), 2.0);
    try testing.expectEqual(result.y(), 6.0);
}

test "Vec2 div returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);
    const other = Vec2F.init(2.0, 3.0);
    const result = vec.div(other);

    try testing.expectEqual(result.x(), 0.5);
    try testing.expectEqual(result.y(), 0.66666666666666666666666666666667);
}

test "Vec2 dot returns correct value" {
    const testing = std.testing;

    const vec = Vec2F.init(1.0, 2.0);
    const other = Vec2F.init(2.0, 3.0);
    const result = vec.dot(other);

    try testing.expectEqual(result, 8.0);
}

// Vec3F tests
test "Vec3 can init" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 2.0);
    try testing.expectEqual(vec.z(), 3.0);
}

test "Vec3 can splat" {
    const testing = std.testing;

    const vec = Vec3F.splat(1.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 1.0);
    try testing.expectEqual(vec.z(), 1.0);
}

test "Vec3 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(2.0, 2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectEqual(result, 3.464101615137755);
}

test "Vec3 add returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.add(other);
    try testing.expectEqual(result.x(), 4.0);
    try testing.expectEqual(result.y(), 6.0);
    try testing.expectEqual(result.z(), 8.0);
}

test "Vec3 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.sub(other);

    try testing.expectEqual(result.x(), -2.0);
    try testing.expectEqual(result.y(), -2.0);
    try testing.expectEqual(result.z(), -2.0);
}

test "Vec3 mul returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.mul(other);

    try testing.expectEqual(result.x(), 3.0);
    try testing.expectEqual(result.y(), 8.0);
    try testing.expectEqual(result.z(), 15.0);
}

test "Vec3 div returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.div(other);

    try testing.expectEqual(result.x(), 0.33333333333333333333333333333333);
    try testing.expectEqual(result.y(), 0.5);
    try testing.expectEqual(result.z(), 0.6);
}

test "Vec3 dot returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.dot(other);

    try testing.expectEqual(result, 26.0);
}

test "Vec3 cross returns correct value" {
    const testing = std.testing;

    const vec = Vec3F.init(1.0, 2.0, 3.0);
    const other = Vec3F.init(3.0, 4.0, 5.0);
    const result = vec.cross(other);

    try testing.expectEqual(result.x(), -2.0);
    try testing.expectEqual(result.y(), 4.0);
    try testing.expectEqual(result.z(), -2.0);
}

// Vec4F tests
test "Vec4 can init" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 2.0);
    try testing.expectEqual(vec.z(), 3.0);
    try testing.expectEqual(vec.w(), 4.0);
}

test "Vec4 can splat" {
    const testing = std.testing;

    const vec = Vec4F.splat(1.0);

    try testing.expectEqual(vec.x(), 1.0);
    try testing.expectEqual(vec.y(), 1.0);
    try testing.expectEqual(vec.z(), 1.0);
    try testing.expectEqual(vec.w(), 1.0);
}

test "Vec4 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(2.0, 2.0, 2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectEqual(result, 4.0);
}

test "Vec4 add returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vec4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.add(other);
    try testing.expectEqual(result.x(), 5.0);
    try testing.expectEqual(result.y(), 7.0);
    try testing.expectEqual(result.z(), 9.0);
    try testing.expectEqual(result.w(), 11.0);
}

test "Vec4 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vec4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.sub(other);

    try testing.expectEqual(result.x(), -3.0);
    try testing.expectEqual(result.y(), -3.0);
    try testing.expectEqual(result.z(), -3.0);
    try testing.expectEqual(result.w(), -3.0);
}

test "Vec4 mul returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vec4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.mul(other);

    try testing.expectEqual(result.x(), 4.0);
    try testing.expectEqual(result.y(), 10.0);
    try testing.expectEqual(result.z(), 18.0);
    try testing.expectEqual(result.w(), 28.0);
}

test "Vec4 div returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vec4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.div(other);

    try testing.expectEqual(result.x(), 0.25);
    try testing.expectEqual(result.y(), 0.4);
    try testing.expectEqual(result.z(), 0.5);
    try testing.expectEqual(result.w(), 0.57142857142857142857142857142857);
}

test "Vec4 dot returns correct value" {
    const testing = std.testing;

    const vec = Vec4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vec4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.dot(other);

    try testing.expectEqual(result, 60.0);
}

// examples
test "Get scalar projection" {
    // a = (x = 1.0, y = 1.0)
    // b = (x = 2.0, y = 4.0)
    //          y
    //          |
    //          |       b
    //          | a
    //  --------|--------- x
    //          |
    //          |
    //          |
    const testing = std.testing;
    const a = Vec2F.init(1.0, 1.0);
    const b = Vec2F.init(2.0, 4.0);

    const a_normalized = a.normalize();
    const scalar = a_normalized.dot(b);

    try testing.expectEqual(scalar, 4.242640687119285);
}

test "Get scalar projection" {
    // a = (x = 1.0, y = 1.0)
    // b = (x = 2.0, y = 4.0)
    //          y
    //          |
    //          |       b
    //          | a
    //  --------|--------- x
    //          |
    //          |
    //          |
    const testing = std.testing;
    const a = Vec2F.init(0.0, 1.0);
    const b = Vec2F.init(4.0, 0.0);

    const a_normalized = a.normalize();
    const scalar = a_normalized.dot(b);

    try testing.expectEqual(scalar, 4.242640687119285);
}