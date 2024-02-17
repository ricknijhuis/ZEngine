const std = @import("std");
const Time = @This();

const miliseconds_per_second = 1000;
const microseconds_per_second = 1000000;
const nanoseconds_per_second = 1000000000;
const nanoseconds_per_milisecond = 1000000;
const nanoseconds_per_microsecond = 1000;

timer: std.time.Timer,
last_frame_sec: f32,
delta_time_sec: f32,

pub fn init(time: *Time) !void {
    time.timer = try std.time.Timer.start();
    time.delta_time_sec = 0;
}

pub fn update(self: *Time) void {
    self.delta_time_sec = nanoSecondsToSeconds(self.timer.lap());
}

pub inline fn nanoSecondsToSeconds(value: usize) f32 {
    return @as(f32, @floatFromInt(value)) / nanoseconds_per_second;
}
