const Vec = @import("vec.zig").Vec;
const types = @import("types.zig");

// column major with column vector storage
pub fn Mat(comptime Scalar: type, comptime row_count: u32, comptime column_count: u32) type {
    return extern struct {
        mat: [column_count]VecT,

        pub const columns = column_count;
        pub const rows = row_count;

        const VecT = Vec(Scalar, row_count);

        const Self = @This();

        pub usingnamespace switch (Self) {
            inline types.Mat4 => struct {
                pub inline fn init(c0: VecT, c1: VecT, c2: VecT, c3: VecT) Self {
                    return .{ .mat = .{ c0, c1, c2, c3 } };
                }

                pub inline fn identity() Self {
                    return .{
                        .mat = .{
                            VecT.init(1.0, 0.0, 0.0, 0.0),
                            VecT.init(0.0, 1.0, 0.0, 0.0),
                            VecT.init(0.0, 0.0, 1.0, 0.0),
                            VecT.init(0.0, 0.0, 0.0, 1.0),
                        },
                    };
                }
            },
            else => {
                @compileError("Dimension not supported");
            },
        };
    };
}
