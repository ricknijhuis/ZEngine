const std = @import("std");

pub const Events = struct {
    pub const CreateInfo = struct {
        allocator: std.mem.Allocator,
    };

    pub fn CallbackFn(comptime Event: type) type {
        return *const fn (listener: ?*anyopaque, event: *const Event) bool;
    }

    const CallbackStorageFn = *const fn (?*anyopaque, *const anyopaque) bool;
    const CallbackStorage = struct {
        listener: ?*anyopaque,
        callback: CallbackStorageFn,
    };

    const Callbacks = struct {
        callbacks: std.ArrayListUnmanaged(CallbackStorage),
    };

    fn getCounter() *u32 {
        comptime {
            var id: u32 = 0;
            return &id;
        }
    }

    fn typeId(comptime T: type) u32 {
        _ = T; // autofix
        comptime {
            const counter = getCounter();
            const id = counter.*;
            counter.* += 1;
            return id;
        }
    }

    allocator: std.mem.Allocator,
    event_types: std.ArrayListUnmanaged(Callbacks),

    pub fn init(create_info: CreateInfo, events: *Events) !void {
        events.allocator = create_info.allocator;
        events.event_types = .{};
    }

    pub fn deinit(self: *Events) void {
        for (self.event_types.items) |*event| {
            event.callbacks.deinit(self.allocator);
        }

        self.event_types.deinit(self.allocator);
    }

    pub fn registerEventType(self: *Events, comptime Event: type) !void {
        const id = comptime typeId(Event);
        if (self.event_types.items.len <= id) {
            try self.event_types.resize(self.allocator, id + 1);
        }

        self.event_types.items[id].callbacks = .{};
    }

    pub fn registerEventCallback(self: *Events, comptime Event: type, listener: *anyopaque, callback: CallbackFn(Event)) !void {
        const id = comptime typeId(Event);
        const event_type = &self.event_types.items[@intCast(id)];

        const callback_fn = @as(CallbackStorageFn, @ptrCast(callback));

        for (event_type.callbacks.items) |item| {
            if (item.listener == listener or item.callback == callback_fn)
                return error.AlreadySubscribed;
        }

        try event_type.callbacks.append(self.allocator, .{ .callback = callback_fn, .listener = listener });
    }

    pub fn fire(self: *Events, comptime Event: type, event: *const Event) bool {
        const id = comptime typeId(Event);

        std.debug.assert(self.event_types.items.len > id);

        const event_type = &self.event_types.items[@intCast(id)];

        for (event_type.callbacks.items) |callback| {
            const callback_fn: CallbackFn(Event) = @ptrCast(callback.callback);
            if (callback_fn(callback.listener, event)) return true;
        }

        return false;
    }
};
