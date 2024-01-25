const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayListAligned = std.ArrayListAligned;
const Mutex = std.Thread.Mutex;

pub fn EventQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        const Buffer = ArrayListAligned(T, @alignOf(T));

        current_buffer: bool,
        buffers: [2]Buffer,
        mutex: Mutex,

        pub fn init(allocator: Allocator) !Self {
            const capacity = 8;
            const buffer1 = try Buffer.initCapacity(allocator, capacity);
            errdefer buffer1.deinit();

            const buffer2 = try Buffer.initCapacity(allocator, capacity);

            return .{
                .buffers = .{ buffer1, buffer2 },
                .mutex = Mutex{},
                .current_buffer = false,
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.buffers[0].deinit();
            self.buffers[1].deinit();
        }

        pub fn swap(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.buffers[@as(usize, @intFromBool(!self.current_buffer))].clearRetainingCapacity();
            self.current_buffer = !self.current_buffer;
        }

        pub fn getWriter(self: *Self) Writer {
            return .{ .system = self };
        }

        pub fn getReader(self: *Self) Reader {
            return .{ .system = self, .position = 0 };
        }

        pub const Writer = struct {
            const WriterSelf = @This();

            system: *Self,

            pub fn send(self: *WriterSelf, event: T) !void {
                self.system.mutex.lock();
                defer self.system.mutex.unlock();

                try self.system.buffers[@as(usize, @intFromBool(self.system.current_buffer))].append(event);
            }
        };

        pub const Reader = struct {
            const ReaderSelf = @This();

            system: *Self,
            position: usize,

            pub fn receive(self: *ReaderSelf) ?T {
                const buffer = self.system.buffers[@as(usize, @intFromBool(!self.system.current_buffer))];
                if (self.position < buffer.items.len) {
                    const value = buffer.items[self.position];
                    self.position += 1;
                    return value;
                } else {
                    return null;
                }
            }
        };
    };
}

test "event system can init to valid state" {
    const Event = struct {
        id: i32,
    };

    var event_queue = try EventQueue(Event)
        .init(std.testing.allocator);

    defer event_queue.deinit();

    try std.testing.expectEqual(event_queue.buffers[0].capacity, 8);
    try std.testing.expectEqual(event_queue.buffers[1].capacity, 8);
    try std.testing.expectEqual(event_queue.current_buffer, false);
}

test "event system writer can send events less than given capacity" {
    const Event = struct {
        id: i32,
    };

    var event_queue = try EventQueue(Event)
        .init(std.testing.allocator);

    defer event_queue.deinit();

    var event_writer = event_queue.getWriter();
    try event_writer.send(Event{ .id = 2 });
}

test "event system reader cannot read events before swap" {
    const Event = struct {
        id: i32,
    };

    var event_queue = try EventQueue(Event)
        .init(std.testing.allocator);

    defer event_queue.deinit();

    var event_writer = event_queue.getWriter();
    try event_writer.send(Event{ .id = 2 });

    var event_reader = event_queue.getReader();

    try std.testing.expect(event_reader.receive() == null);
}

test "event system reader can read events after swap" {
    const Event = struct {
        id: i32,
    };

    var event_queue = try EventQueue(Event)
        .init(std.testing.allocator);

    defer event_queue.deinit();

    var event_writer = event_queue.getWriter();
    try event_writer.send(Event{ .id = 2 });

    var event_reader = event_queue.getReader();

    event_queue.swap();

    if (event_reader.receive()) |event| {
        try std.testing.expectEqual(@as(i32, 2), event.id);
    } else {
        try std.testing.expect(false);
    }
}

test "event system reader can read all messages and returns null at last" {
    const Event = struct {
        id: i32,
    };

    var event_queue = try EventQueue(Event)
        .init(std.testing.allocator);

    defer event_queue.deinit();

    var event_writer = event_queue.getWriter();
    try event_writer.send(Event{ .id = 1 });
    try event_writer.send(Event{ .id = 2 });
    try event_writer.send(Event{ .id = 3 });

    event_queue.swap();

    var event_reader = event_queue.getReader();

    var i: i32 = 0;
    while (event_reader.receive()) |event| : (i += 1) {
        try std.testing.expect(event.id == i + 1);
    }

    try std.testing.expect(event_reader.receive() == null);
}
