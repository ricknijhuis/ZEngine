const std = @import("std");
const builtin = @import("builtin");
const core = @import("../../core/core.zig");

const Events = core.Events;

const c = switch (builtin.os.tag) {
    .windows => @cImport({
        @cDefine("WIN32_LEAN_AND_MEAN", "1");
        @cInclude("windows.h");
    }),
    else => @compileError("not supported"),
};

const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
const utf8ToUtf16 = std.unicode.utf8ToUtf16LeWithNull;

const Window = @import("../window.zig").WindowImpl(std.Target.Os.Tag.windows);

const atom_name = utf8ToUtf16Lit("zengine");

pub fn init(create_info: Window.CreateInfo, window: *Window) !void {
    window.handle = null;
    window.instance = c.GetModuleHandleW(null);
    window.width = create_info.width;
    window.height = create_info.height;

    const class = c.WNDCLASSEXW{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .cbClsExtra = 0,
        .cbWndExtra = @sizeOf(@TypeOf(create_info.events)),
        .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
        .lpfnWndProc = windowProcedure,
        .hInstance = window.instance,
        .hCursor = null,
        .hIcon = null,
        .lpszClassName = atom_name,
        .lpszMenuName = null,
        .hbrBackground = null,
        .hIconSm = null,
    };

    try checkResult(c.RegisterClassExW(&class) != 0);

    const title = try utf8ToUtf16(create_info.allocator, create_info.title);
    defer create_info.allocator.free(title);

    const style = getWindowStyle(create_info.mode);
    const style_ex = getWindowStyleEx(create_info.mode);

    var window_rect = try getPrimaryMonitorRect();
    const monitor_width = window_rect.right - window_rect.left;
    const monitor_height = window_rect.bottom - window_rect.top;
    const width = @as(c_long, @intCast(window.width));
    const height = @as(c_long, @intCast(window.height));
    const denominator: c_long = 2;

    if (create_info.mode == Window.Mode.windowed) {
        window_rect.left = @divExact(monitor_width, denominator) - @divExact(width, denominator);
        window_rect.top = @divExact(monitor_height, denominator) - @divExact(height, denominator);
        window_rect.right = window_rect.left + width;
        window_rect.bottom = window_rect.top + height;

        try checkResult(c.AdjustWindowRectEx(&window_rect, style, c.FALSE, style_ex) == c.TRUE);
    }

    window.handle = c.CreateWindowExW(
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
        window.instance,
        null,
    );

    try checkResult(window.handle != null);
    try checkResult(c.SetWindowLongPtrW(window.handle, 0, @intCast(@intFromPtr(create_info.events))) == 0);

    _ = c.ShowWindow(window.handle, c.SW_SHOWNA);
    _ = c.BringWindowToTop(window.handle);
    _ = c.SetForegroundWindow(window.handle);
    _ = c.SetFocus(window.handle);
}

pub fn pollEvents(self: Window) void {
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

fn getWindowStyle(mode: Window.Mode) c_ulong {
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

fn getWindowStyleEx(mode: Window.Mode) c_ulong {
    if (mode == Window.Mode.fullscreen or mode == Window.Mode.borderless) {
        return c.WS_EX_APPWINDOW | c.WS_EX_TOPMOST;
    } else {
        return c.WS_EX_APPWINDOW;
    }
    return 0;
}

fn windowProcedure(hwnd: c.HWND, uMsg: u32, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) isize {
    switch (uMsg) {
        c.WM_SIZE => {
            const events = ptrFromLongPtr(Events, c.GetWindowLongPtrW(hwnd, 0));
            const width: u32 = @intCast(lParam & 0xFFFF);
            const height: u32 = @intCast((lParam >> 16) & 0xFFFF);
            _ = events.fire(Window.ResizeEvent, &.{
                .width = width,
                .height = height,
            });
            return 0;
        },
        c.WM_SETFOCUS => {
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
        c.WM_KILLFOCUS => {
            return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
        },
        c.WM_CLOSE => {
            const events = ptrFromLongPtr(Events, c.GetWindowLongPtrW(hwnd, 0));
            _ = events.fire(Window.CloseEvent, &.{});

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

inline fn ptrFromLongPtr(comptime T: type, ptr: c.LONG_PTR) *T {
    return @as(*T, @ptrFromInt(@as(usize, @intCast(ptr))));
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
