// const std = @import("std");

// const c = @cImport({
//     @cDefine("WIN32_LEAN_AND_MEAN", "1");
//     @cInclude("windows.h");
// });

// const utf8ToUtf16Lit = std.unicode.utf8ToUtf16LeStringLiteral;
// const utf8ToUtf16 = std.unicode.utf8ToUtf16LeWithNull;
// const engine = @import("../../root.zig");

// const Application = engine.Application;
// const WindowEventQueue = engine.WindowEventQueue;
// const WindowEventType = engine.WindowEventType;
// const WindowEvent = engine.WindowEvent;
// const WindowResizeEvent = engine.WindowResizeEvent;
// const WindowMaximizeEvent = engine.WindowMaximizeEvent;
// const WindowMinimizeEvent = engine.WindowMinimizeEvent;
// const WindowCloseEvent = engine.WindowCloseEvent;

// const Self = @This();

// pub const Mode = enum(i32) {
//     windowed,
//     borderless,
//     fullscreen,
// };

// pub const Extend = struct {
//     width: u32,
//     heigt: u32,
// };

// pub const InitParams = struct {
//     allocator: std.mem.Allocator,
//     application: *Application,
//     event_writer: WindowEventQueue.Writer,
//     mode: Mode = Mode.fullscreen,
//     width: u32,
//     height: u32,
// };

// const WindowProp = struct {
//     application: *Application,

// };

// const atom_name = utf8ToUtf16Lit("TarkovV2");

// allocator: std.mem.Allocator,
// handle: c.HWND,
// instance: c.HINSTANCE,

// pub fn init(
//     params: InitParams,
// ) !Self {
//     var self = Self{
//         .allocator = params.allocator,
//         .handle = undefined,
//         .instance = c.GetModuleHandleW(null),
//         .width = params.width,
//         .height = params.height,
//     };
//     const class = c.WNDCLASSEXW{
//         .cbSize = @sizeOf(c.WNDCLASSEXW),
//         .cbClsExtra = 0,
//         .cbWndExtra = 0,
//         .style = c.CS_HREDRAW | c.CS_VREDRAW | c.CS_OWNDC,
//         .lpfnWndProc = windowProcedure,
//         .hInstance = self.instance,
//         .hCursor = null,
//         .hIcon = null,
//         .lpszClassName = atom_name,
//         .lpszMenuName = null,
//         .hbrBackground = null,
//         .hIconSm = null,
//     };
//     _ = c.RegisterClassExW(&class);

//     const title = try utf8ToUtf16(self.allocator, params.application.title);
//     defer params.allocator.free(title);

//     const style = getWindowStyle(params.mode);
//     const style_ex = getWindowStyleEx(params.mode);

//     var position = c.RECT{
//         .left = 0,
//         .top = 0,
//         .right = @intCast(params.width),
//         .bottom = @intCast(params.height),
//     };

//     if (params.mode == Mode.fullscreen or params.mode == Mode.borderless) {
//         if (getPrimaryMonitorRect()) |rect| {
//             position = rect;
//         }
//     }

//     self.handle = c.CreateWindowExW(
//         style_ex,
//         atom_name,
//         title,
//         style,
//         position.left,
//         position.top,
//         position.right - position.left,
//         position.bottom - position.top,
//         null,
//         null,
//         self.instance,
//         null,
//     );

//     const prop: *WindowProp = try self.allocator.create(WindowProp);

//     prop.application = params.application;
//     prop.event_writer = params.event_writer;

//     _ = c.SetPropW(self.handle, atom_name, prop);
//     _ = c.ShowWindow(self.handle, c.SW_SHOW);

//     var rawInputDevice = c.RAWINPUTDEVICE{ .dwFlags = 0, .hwndTarget = 0, .usUsage = 0x06, .usUsagePage = 0x01 };
//     rawInputDevice.usUsagePage = 0x01;
//     rawInputDevice.usUsage = 0x06;
//     rawInputDevice.dwFlags = 0;
//     rawInputDevice.hwndTarget = 0;
//     _ = c.RegisterRawInputDevices(&rawInputDevice, 1, @sizeOf(@TypeOf(rawInputDevice)));

//     return self;
// }

// pub fn deinit(self: Self) void {
//     if (c.GetPropW(self.handle, atom_name)) |prop| {
//         self.allocator.destroy(@as(*WindowProp, @alignCast(@ptrCast(prop))));
//     }

//     _ = c.DestroyWindow(self.handle);
// }

// pub fn pollEvents(self: *const Self) void {
//     _ = self;
//     var msg: c.MSG = undefined;
//     while (c.PeekMessageW(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
//         switch (msg.message) {
//             else => {
//                 _ = c.TranslateMessage(&msg);
//                 _ = c.DispatchMessageW(&msg);
//             },
//         }
//     }
// }

// pub fn getSize() fn getPrimaryMonitorRect() ?c.RECT {
//     const ptZero = c.POINT{ .x = 0, .y = 0 };
//     const monitor = c.MonitorFromPoint(ptZero, c.MONITOR_DEFAULTTONEAREST);
//     var monitor_info = c.MONITORINFO{
//         .cbSize = @sizeOf(c.MONITORINFO),
//         .dwFlags = undefined,
//         .rcMonitor = undefined,
//         .rcWork = undefined,
//     };
//     if (c.GetMonitorInfoW(monitor, &monitor_info) != 0) {
//         return monitor_info.rcMonitor;
//     }
//     return null;
// }

// fn getWindowStyle(mode: Mode) c_ulong {
//     switch (mode) {
//         .windowed => {
//             return c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN | c.WS_OVERLAPPED;
//         },
//         .borderless => {
//             return c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN | c.WS_SYSMENU | c.WS_MINIMIZE | c.WS_POPUP;
//         },
//         .fullscreen => {
//             return c.WS_CLIPSIBLINGS | c.WS_CLIPCHILDREN | c.WS_OVERLAPPED | c.WS_POPUP;
//         },
//     }
//     return 0;
// }

// fn getWindowStyleEx(mode: Mode) c_ulong {
//     if (mode == Mode.fullscreen or mode == Mode.borderless) {
//         return c.WS_EX_APPWINDOW | c.WS_EX_TOPMOST;
//     } else {
//         return c.WS_EX_APPWINDOW;
//     }
//     return 0;
// }

// fn windowProcedure(hwnd: c.HWND, uMsg: u32, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.C) isize {
//     var window_prop: *WindowProp = undefined;

//     if (c.GetPropW(hwnd, atom_name)) |prop| {
//         window_prop = @ptrCast(@alignCast(prop));
//     } else return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);

//     switch (uMsg) {
//         c.WM_SIZE => {
//             const width: u32 = @intCast(lParam & 0xFFFF);
//             const height: u32 = @intCast((lParam >> 16) & 0xFFFF);
//             window_prop.event_writer.send(.{
//                 .window_resize = .{
//                     .width = width,
//                     .height = height,
//                 },
//             }) catch return 0;
//             return 0;
//         },
//         c.WM_SETFOCUS => {
//             return 0;
//         },
//         c.WM_KILLFOCUS => {
//             //engine.window.minimize();
//             return 0;
//         },
//         c.WM_CLOSE => {
//             window_prop.application.is_running = false;
//             return 0;
//         },
//         c.WM_INPUT => {
//             var input: c.RAWINPUT = .{};
//             var input_size: c_uint = @sizeOf(@TypeOf(input));
//             _ = c.GetRawInputData(lParam, c.RID_INPUT, &input, &input_size, @as(c_uint, @sizeOf(c.RAWINPUTHEADER)));

//             if (input.header.dwType == c.RIM_TYPEKEYBOARD) {
//                 var pressed = false;
//                 const ignore = 0;
//                 _ = ignore;
//                 var scancode = input.data.keyboard.MakeCode;
//                 const flags: c_int = input.data.keyboard.Flags;

//                 if ((flags & c.RI_KEY_BREAK) == 0)
//                     pressed = true;

//                 if (flags & c.RI_KEY_E0 != 0) {
//                     scancode |= 0xE000;
//                 } else if (flags & c.RI_KEY_E1 != 0)
//                     scancode |= 0xE100;

//                 if (scancode == 0xE11D or scancode == 0xE02A or scancode == 0xE0AA or scancode == 0xE0B6 or scancode == 0xE036)
//                     return 0;

//                 std.log.debug("scancode: {}, pressed: {}", .{ scancode, pressed });

//                 // internal_set_keyboard_key(engine, ae_platform_get_key_code_index(scancode), pressed);
//                 // break;
//             }

//             return 0;
//         },
//         else => {
//             return c.DefWindowProcW(hwnd, uMsg, wParam, lParam);
//         },
//     }
// }
