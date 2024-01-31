const std = @import("std");

const c = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
});

const HWND = *opaque {};
const HWND_TOPMOST = typedConst(HWND, @as(i32, -1));

extern fn SetWindowPos(
    hWnd: c.HWND,
    hWndInsertAfter: HWND,
    x: c_int,
    y: c_int,
    cx: c_int,
    cy: c_int,
    flags: c.UINT,
) callconv(std.os.windows.WINAPI) c.BOOL;

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeWithNull;
const window = @import("../window_internal.zig");
const engine = @import("../../root.zig");

const Self = @This();

pub const Mode = window.Mode;
pub const Extend = window.Extend;
pub const InitParams = window.InitParams;

const WindowProperties = struct {
    instance: c.HINSTANCE,
    hwnd: c.HWND,
    application: *engine.Application,
    extend: Extend,
    mode: Mode,
    close_event_writer: engine.WindowCloseEventQueue.Writer,
    resize_event_writer: engine.WindowResizeEventQueue.Writer,
    minimize_event_writer: engine.WindowMinEventQueue.Writer,
    maximize_event_writer: engine.WindowMaxEventQueue.Writer,
};

const atom_name = utf8ToUtf16Lit("SurvivalConcept");

allocator: std.mem.Allocator,
properties: *WindowProperties,

pub fn init(params: InitParams) !Self {
    var self = Self{
        .allocator = params.allocator,
        .properties = undefined,
    };

    self.properties = try self.allocator.create(@TypeOf(self.properties.*));
    self.properties.instance = c.GetModuleHandleW(null);
    self.properties.hwnd = null;
    self.properties.application = params.application;
    self.properties.extend = params.extend;
    self.properties.mode = params.mode;
    self.properties.close_event_writer = params.close_event_writer;
    self.properties.resize_event_writer = params.resize_event_writer;
    self.properties.minimize_event_writer = params.minimize_event_writer;
    self.properties.maximize_event_writer = params.maximize_event_writer;

    const class = c.WNDCLASSEXW{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
        .lpfnWndProc = windowProcedure,
        .hInstance = self.properties.instance,
        .hCursor = null,
        .hIcon = null,
        .lpszClassName = atom_name,
        .lpszMenuName = null,
        .hbrBackground = null,
        .hIconSm = null,
    };

    try checkResult(c.RegisterClassExW(&class) != 0);

    const title = try utf8ToUtf16(self.allocator, params.application.title);
    defer params.allocator.free(title);

    const style = getWindowStyle(params.mode);
    const style_ex = getWindowStyleEx(params.mode);

    var window_rect = try getPrimaryMonitorRect();
    const monitor_width = window_rect.right - window_rect.left;
    const monitor_height = window_rect.bottom - window_rect.top;
    const width = @as(c_long, @intCast(self.properties.extend.width));
    const height = @as(c_long, @intCast(self.properties.extend.height));
    const denominator: c_long = 2;

    if (self.properties.mode == Mode.windowed) {
        window_rect.left = @divExact(monitor_width, denominator) - @divExact(width, denominator);
        window_rect.top = @divExact(monitor_height, denominator) - @divExact(height, denominator);
        window_rect.right = window_rect.left + width;
        window_rect.bottom = window_rect.top + height;

        try checkResult(c.AdjustWindowRectEx(&window_rect, style, c.FALSE, style_ex) == c.TRUE);
    }

    std.log.debug("x: {}, y: {}, width: {}, height: {}", .{ window_rect.left, window_rect.top, window_rect.right - window_rect.left, window_rect.bottom - window_rect.top });

    self.properties.hwnd = c.CreateWindowExW(
        style_ex,
        atom_name,
        title,
        style,
        window_rect.left,
        window_rect.top,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
        null,
        null,
        self.properties.instance,
        null,
    );

    try checkResult(self.properties.hwnd != null);
    try checkResult(c.SetPropW(self.properties.hwnd, atom_name, self.properties) != 0);

    _ = c.ShowWindow(self.properties.hwnd, c.SW_SHOWNA);
    _ = c.BringWindowToTop(self.properties.hwnd);
    _ = c.SetForegroundWindow(self.properties.hwnd);
    _ = c.SetFocus(self.properties.hwnd);

    return self;
}

pub fn deinit(self: Self) void {
    _ = self; // autofix
}

pub fn pollEvents(self: Self) void {
    _ = self;
    var msg: c.MSG = undefined;
    while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
        switch (msg.message) {
            else => {
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageW(&msg);
            },
        }
    }
}

pub fn getSize(self: Self) Extend {
    var rect: c.RECT = undefined;
    _ = c.GetClientRect(self.properties.hwnd, &rect);

    return Extend{
        .width = @intCast(rect.right - rect.left),
        .height = @intCast(rect.bottom - rect.top),
    };
}

pub fn setSize(self: Self) void {
    _ = self; // autofix

}

pub fn setMode(self: Self, mode: Mode) !void {
    _ = self; // autofix
    _ = mode; // autofix
}

fn getPrimaryMonitorRect() !c.RECT {
    const ptZero = c.POINT{ .x = 0, .y = 0 };
    const monitor = c.MonitorFromPoint(ptZero, c.MONITOR_DEFAULTTONEAREST);
    var monitor_info = c.MONITORINFO{
        .cbSize = @sizeOf(c.MONITORINFO),
        .dwFlags = undefined,
        .rcMonitor = undefined,
        .rcWork = undefined,
    };

    try checkResult(c.GetMonitorInfoW(monitor, &monitor_info) != 0);

    return monitor_info.rcMonitor;
}

fn fitToMonitor(self: Self) !void {
    const rect = try getPrimaryMonitorRect();
    try checkResult(SetWindowPos(
        self.properties.hwnd,
        HWND_TOPMOST,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        c.SWP_NOZORDER | c.SWP_NOACTIVATE | c.SWP_NOCOPYBITS,
    ) == c.TRUE);
}

fn windowProcedure(hwnd: c.HWND, uMsg: u32, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) isize {
    var window_prop: *WindowProperties = undefined;

    if (c.GetPropW(hwnd, atom_name)) |prop| {
        window_prop = @ptrCast(@alignCast(prop));
    } else return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);

    switch (uMsg) {
        c.WM_SIZE => {
            const width: u32 = @intCast(lParam & 0xFFFF);
            const height: u32 = @intCast((lParam >> 16) & 0xFFFF);
            window_prop.resize_event_writer.send(.{
                .width = width,
                .height = height,
            }) catch return 0;
            return 0;
        },
        c.WM_SETFOCUS => {
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
        c.WM_KILLFOCUS => {
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
        c.WM_CLOSE => {
            window_prop.close_event_writer.send(.{}) catch return 0;
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
        c.WM_INPUT => {
            var input: c.RAWINPUT = .{};
            var input_size: c_uint = @sizeOf(@TypeOf(input));
            _ = c.GetRawInputData(lParam, c.RID_INPUT, &input, &input_size, @as(c_uint, @sizeOf(c.RAWINPUTHEADER)));

            if (input.header.dwType == c.RIM_TYPEKEYBOARD) {
                var pressed = false;
                const ignore = 0;
                _ = ignore;
                var scancode = input.data.keyboard.MakeCode;
                const flags: c_int = input.data.keyboard.Flags;

                if ((flags & c.RI_KEY_BREAK) == 0)
                    pressed = true;

                if (flags & c.RI_KEY_E0 != 0) {
                    scancode |= 0xE000;
                } else if (flags & c.RI_KEY_E1 != 0)
                    scancode |= 0xE100;

                if (scancode == 0xE11D or scancode == 0xE02A or scancode == 0xE0AA or scancode == 0xE0B6 or scancode == 0xE036)
                    return 0;

                std.log.debug("scancode: {}, pressed: {}", .{ scancode, pressed });

                // internal_set_keyboard_key(engine, ae_platform_get_key_code_index(scancode), pressed);
                // break;
            }

            return 0;
        },
        else => {
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
    }
}

fn getWindowStyle(mode: Mode) c_ulong {
    switch (mode) {
        .windowed => {
            return c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN | c.WS_SYSMENU | c.WS_THICKFRAME | c.WS_OVERLAPPED;
        },
        .borderless, .fullscreen => {
            return c.WS_POPUP;
        },
    }
    return 0;
}

fn getWindowStyleEx(mode: Mode) c_ulong {
    if (mode == Mode.fullscreen or mode == Mode.borderless) {
        return c.WS_EX_APPWINDOW | c.WS_EX_TOPMOST;
    } else {
        return c.WS_EX_APPWINDOW;
    }
    return 0;
}

fn checkResult(ok: bool) std.os.UnexpectedError!void {
    if (ok) return;

    const err = c.GetLastError();
    if (std.os.unexpected_error_tracing) {
        // 614 is the length of the longest windows error description
        var buf_wstr: [614:0]u16 = undefined;
        var buf_utf8: [614:0]u8 = undefined;
        const len = c.FormatMessageW(
            c.FORMAT_MESSAGE_FROM_SYSTEM | c.FORMAT_MESSAGE_IGNORE_INSERTS,
            null,
            err,
            c.MAKELANGID(c.LANG_NEUTRAL, c.SUBLANG_DEFAULT),
            &buf_wstr,
            buf_wstr.len,
            null,
        );
        _ = std.unicode.utf16leToUtf8(&buf_utf8, buf_wstr[0..len]) catch unreachable;
        std.debug.print("error.Unexpected: GetLastError({}): {s}\n", .{ err, buf_utf8[0..len] });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}

pub fn typedConst(comptime T: type, comptime value: anytype) T {
    return typedConst2(T, T, value);
}

pub fn typedConst2(comptime ReturnType: type, comptime SwitchType: type, comptime value: anytype) ReturnType {
    const target_type_error = @as([]const u8, "typedConst cannot convert to " ++ @typeName(ReturnType));
    const value_type_error = @as([]const u8, "typedConst cannot convert " ++ @typeName(@TypeOf(value)) ++ " to " ++ @typeName(ReturnType));

    switch (@typeInfo(SwitchType)) {
        .Int => |target_type_info| {
            if (value >= std.math.maxInt(SwitchType)) {
                if (target_type_info.signedness == .signed) {
                    const UnsignedT = @Type(std.builtin.Type{ .Int = .{ .signedness = .unsigned, .bits = target_type_info.bits } });
                    return @as(SwitchType, @bitCast(@as(UnsignedT, value)));
                }
            }
            return value;
        },
        .Pointer => |target_type_info| switch (target_type_info.size) {
            .One, .Many, .C => {
                switch (@typeInfo(@TypeOf(value))) {
                    .ComptimeInt, .Int => {
                        const usize_value = if (value >= 0) value else @as(usize, @bitCast(@as(isize, value)));
                        return @as(ReturnType, @ptrFromInt(usize_value));
                    },
                    else => @compileError(value_type_error),
                }
            },
            else => target_type_error,
        },
        .Optional => |target_type_info| switch (@typeInfo(target_type_info.child)) {
            .Pointer => return typedConst2(ReturnType, target_type_info.child, value),
            else => target_type_error,
        },
        .Enum => |_| switch (@typeInfo(@TypeOf(value))) {
            .Int => return @as(ReturnType, @enumFromInt(value)),
            else => target_type_error,
        },
        else => @compileError(target_type_error),
    }
}
