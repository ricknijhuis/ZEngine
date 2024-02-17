const std = @import("std");

const Input = @This();

pub const CreateInfo = struct {
    allocator: std.mem.Allocator,
};

pub fn init(create_info: CreateInfo, input: *Input) !void {
    _ = create_info; // autofix
    _ = input; // autofix
}

const KeyboardKeys = enum {
    none,
    escape,
    toprow_1,
    toprow_2,
    toprow_3,
    toprow_4,
    toprow_5,
    toprow_6,
    toprow_7,
    toprow_8,
    toprow_9,
    toprow_0,
    minus,
    equals,
    backspace,
    tab,
    q,
    w,
    e,
    r,
    t,
    y,
    u,
    i,
    o,
    p,
    bracket_left,
    bracket_right,
    enter,
    ctrl_left,
    a,
    s,
    d,
    f,
    g,
    h,
    j,
    k,
    l,
    semicolon,
    apostrophe,
    grave,
    shift_left,
    backslash,
    z,
    x,
    c,
    v,
    b,
    n,
    m,
    comma,
    period,
    slash,
    shift_right,
    numpad_multiply,
    alt_left,
    space,
    capslock,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    numlock,
    scrolllock,
    numpad_7,
    numpad_8,
    numpad_9,
    numpad_minus,
    numpad_4,
    numpad_5,
    numpad_6,
    numpad_plus,
    numpad_1,
    numpad_2,
    numpad_3,
    numpad_0,
    numpad_period,
    alt_printscreen, // alt + print screen. mapvirtualkeyex( vk_snapshot, mapvk_vk_to_vsc_ex, 0 ) returns scancode 0x54.
    bracketangle, // key between the left shift and z.
    f11,
    f12,
    oem_1, // vk_oem_wsctrl
    oem_2, // vk_oem_finish
    oem_3, // vk_oem_jump
    eraseeof,
    oem_4, // vk_oem_backtab
    oem_5, // vk_oem_auto
    zoom,
    help,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    oem_6, // vk_oem_pa3
    katakana,
    oem_7, // input vk_oem_reset
    f24,
    sbcschar,
    convert,
    nonconvert, // vk_oem_pa1
    media_previous,
    media_next,
    numpad_enter,
    ctrl_right,
    volume_mute,
    launch_app2,
    media_play,
    media_stop,
    volume_down,
    volume_up,
    browser_home,
    numpad_divide,
    printscreen,
    alt_right,
    cancel,
    home,
    arrow_up,
    page_up,
    arrow_left,
    arrow_right,
    end,
    arrow_down,
    paged_own,
    insert,
    delete,
    meta_left,
    meta_right,
    application,
    power,
    sleep,
    wake,
    browser_search,
    browser_favorites,
    browser_refresh,
    browser_stop,
    browser_forward,
    browser_back,
    launch_app1,
    launch_email,
    launch_media,
    pause,
    all,
};
