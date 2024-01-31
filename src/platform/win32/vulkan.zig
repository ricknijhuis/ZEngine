const std = @import("std");
const builtin = @import("builtin");
const Window = @import("Window.zig");

pub const c = @cImport({
    @cDefine("VK_USE_PLATFORM_WIN32_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

pub const platform_instance_extensions: []const [*c]const u8 = &.{c.VK_KHR_WIN32_SURFACE_EXTENSION_NAME};

pub fn createSurface(instance: c.VkInstance, surface: *c.VkSurfaceKHR, window: Window) c.VkResult {
    const surface_create_info = c.VkWin32SurfaceCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        .hinstance = @ptrCast(window.properties.instance),
        .hwnd = @ptrCast(window.properties.hwnd),
    };

    return c.vkCreateWin32SurfaceKHR(instance, &surface_create_info, null, surface);
}
