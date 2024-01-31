const Self = @This();

const engine = @import("root.zig");

pub const InitParams = struct {
    title: [:0]const u8,
    version: [:0]const u8,
    close_event_reader: engine.WindowCloseEventQueue.Reader,
};

is_running: bool,
title: [:0]const u8,
version: [:0]const u8,
close_event_reader: engine.WindowCloseEventQueue.Reader,

pub fn init(params: InitParams) Self {
    return Self{
        .is_running = true,
        .title = params.title,
        .version = params.version,
        .close_event_reader = params.close_event_reader,
    };
}

pub fn on_update(self: *Self) void {
    if (self.close_event_reader.receive() != null) {
        self.is_running = false;
    }
}
