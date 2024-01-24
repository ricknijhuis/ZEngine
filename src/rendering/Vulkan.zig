const std = @import("std");
const builtin = @import("builtin");
const algorithms = @import("../algorithms/find.zig");
const engine = @import("../root.zig");
const vulkan = @import("../platform/vulkan.zig").vulkan;
const c = vulkan.c;

const Application = engine.Application;
const Window = engine.Window;

pub const InitParams = struct {
    allocator: std.mem.Allocator,
    application: *Application,
    window: *Window,
};

const Self = @This();
var framenumber: u32 = 0;

allocator: std.mem.Allocator,
instance: c.VkInstance = undefined,
surface: c.VkSurfaceKHR = undefined,
device: c.VkDevice = undefined,
physical_device: c.VkPhysicalDevice = undefined,
physical_device_properties: c.VkPhysicalDeviceProperties = undefined,
physical_device_features: c.VkPhysicalDeviceFeatures = undefined,
physical_device_memory: c.VkPhysicalDeviceMemoryProperties = undefined,
physical_device_surface_formats: []c.VkSurfaceFormatKHR = undefined,
physical_device_surface_format: u32 = 0,
physical_device_surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined,
physical_device_present_modes: []c.VkPresentModeKHR = undefined,
physical_device_present_mode: u32 = 0,
graphics_queue: c.VkQueue = undefined,
graphics_queue_index: u32 = undefined,
present_queue: c.VkQueue = undefined,
present_queue_index: u32 = undefined,
transfer_queue: c.VkQueue = undefined,
transfer_queue_index: u32 = undefined,
compute_queue: c.VkQueue = undefined,
compute_queue_index: u32 = undefined,
extend: c.VkExtent2D = undefined,
swapchain: c.VkSwapchainKHR = undefined,
swapchain_images: []c.VkImage = undefined,
swapchain_image_views: []c.VkImageView = undefined,
framebuffers: []c.VkFramebuffer = undefined,
command_pool: c.VkCommandPool = undefined,
command_buffer: c.VkCommandBuffer = undefined,
render_pass: c.VkRenderPass = undefined,
fence: c.VkFence = undefined,
render_semaphore: c.VkSemaphore = undefined,
present_semaphore: c.VkSemaphore = undefined,
vertex_shader: c.VkShaderModule = undefined,
fragment_shader: c.VkShaderModule = undefined,
debug_msgr: c.VkDebugUtilsMessengerEXT = undefined,

pub fn init(params: InitParams) !Self {
    var self = Self{
        .allocator = params.allocator,
    };

    try self.initVkInstance(params);
    try self.initVkDebugMessenger();
    try self.initVkSurface(params);
    try self.initVkPhysicalDevice();
    try self.initVkLogicalDevice();
    try self.initVkSwapChain(params);
    try self.initVkImageViews();
    try self.initVkCommandPool();
    try self.initVkCommandBuffer();
    try self.initVkRenderPass();
    try self.initVkFrameBuffers();
    try self.initVkFence();
    try self.initVkSemaphores();
    try self.initVkShaderModule("triangle.vert.spv", &self.vertex_shader);
    try self.initVkShaderModule("triangle.frag.spv", &self.fragment_shader);

    return self;
}

fn initVkShaderModule(self: *Self, path: []const u8, module: *c.VkShaderModule) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    // Open the file.
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Get the file size.
    const file_size = (try file.stat()).size;

    // Allocate a buffer for the entire file.
    const buffer = try allocator.alloc(u8, file_size);

    // Read the entire file into the buffer.
    const n = try file.reader().readAll(buffer);
    std.debug.assert(n == file_size);

    const module_create_info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = file_size * @sizeOf(u32),
        .pCode = @alignCast(@ptrCast(buffer)),
    };

    var shader_module: c.VkShaderModule = undefined;
    try checkResult(c.vkCreateShaderModule(self.device, &module_create_info, null, &shader_module));

    module.* = shader_module;
}

pub fn deinit(self: Self) void {
    c.vkDestroySemaphore(self.device, self.render_semaphore, null);
    c.vkDestroySemaphore(self.device, self.present_semaphore, null);
    c.vkDestroyFence(self.device, self.fence, null);

    for (self.framebuffers) |framebuffer| {
        c.vkDestroyFramebuffer(self.device, framebuffer, null);
    }
    self.allocator.free(self.framebuffers);

    c.vkDestroyRenderPass(self.device, self.render_pass, null);
    c.vkDestroyCommandPool(self.device, self.command_pool, null);

    for (self.swapchain_image_views) |image_view| {
        c.vkDestroyImageView(self.device, image_view, null);
    }
    self.allocator.free(self.swapchain_image_views);

    c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
    c.vkDestroyDevice(self.device, null);
    c.vkDestroySurfaceKHR(self.instance, self.surface, null);

    if (builtin.mode == .Debug) {
        const destroyFn = self.getInstanceFunction(c.PFN_vkDestroyDebugUtilsMessengerEXT, "vkDestroyDebugUtilsMessengerEXT") catch unreachable;
        // if () |destroy_fn| {
        if (destroyFn) |vkDestroyDebugUtilsMessengerEXT| {
            vkDestroyDebugUtilsMessengerEXT(self.instance, self.debug_msgr, null);
        }
        // } else {}
    }
}

pub fn drawTriangle(self: Self) void {
    var result = c.vkWaitForFences(self.device, 1, &self.fence, c.VK_TRUE, 1000000000);
    if (result != c.VK_SUCCESS) return;

    result = c.vkResetFences(self.device, 1, &self.fence);
    if (result != c.VK_SUCCESS) return;

    var swapchain_image_index: u32 = 0;
    result = c.vkAcquireNextImageKHR(self.device, self.swapchain, 1000000000, self.present_semaphore, null, &swapchain_image_index);
    if (result != c.VK_SUCCESS) return;

    result = c.vkResetCommandBuffer(self.command_buffer, 0);
    if (result != c.VK_SUCCESS) return;

    const cmd_buffer_begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    result = c.vkBeginCommandBuffer(self.command_buffer, &cmd_buffer_begin_info);
    if (result != c.VK_SUCCESS) return;

    const flash = @abs(@as(f32, @floatFromInt(framenumber)) / 120.0);
    const clear_value = c.VkClearValue{ .color = .{ .float32 = .{ 0.0, 0.0, flash, 1.0 } } };
    const renderpass_begin_info = c.VkRenderPassBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = self.render_pass,
        .renderArea = .{
            .offset = .{
                .x = 0,
                .y = 0,
            },
            .extent = self.extend,
        },
        .framebuffer = self.framebuffers[swapchain_image_index],
        .clearValueCount = 1,
        .pClearValues = &clear_value,
    };

    c.vkCmdBeginRenderPass(self.command_buffer, &renderpass_begin_info, c.VK_SUBPASS_CONTENTS_INLINE);
    c.vkCmdEndRenderPass(self.command_buffer);

    result = c.vkEndCommandBuffer(self.command_buffer);

    const stage_flags: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    const submit_info = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pWaitDstStageMask = &stage_flags,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &self.present_semaphore,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &self.render_semaphore,
        .commandBufferCount = 1,
        .pCommandBuffers = &self.command_buffer,
    };

    result = c.vkQueueSubmit(self.graphics_queue, 1, &submit_info, self.fence);
    if (result != c.VK_SUCCESS) return;

    const present_info = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .swapchainCount = 1,
        .pSwapchains = &self.swapchain,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &self.render_semaphore,
        .pImageIndices = &swapchain_image_index,
    };

    result = c.vkQueuePresentKHR(self.graphics_queue, &present_info);
    framenumber += 1;
}

fn initVkInstance(self: *Self, params: InitParams) !void {
    std.log.debug("Creating vulkan instance", .{});
    var arena_allocator = std.heap.ArenaAllocator.init(self.allocator);
    defer arena_allocator.deinit();

    var allocator = arena_allocator.allocator();

    var extension_count: u32 = undefined;
    var extensions: []c.VkExtensionProperties = undefined;
    try checkResult(c.vkEnumerateInstanceExtensionProperties(0, &extension_count, null));

    extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
    try checkResult(c.vkEnumerateInstanceExtensionProperties(0, &extension_count, extensions.ptr));

    const required_extensions = comptime getRequiredInstanceExtensions();
    try hasRequiredExtensions(required_extensions, extensions);

    var layer_count: u32 = undefined;
    var layers: []c.VkLayerProperties = undefined;
    try checkResult(c.vkEnumerateInstanceLayerProperties(&layer_count, null));

    layers = try allocator.alloc(c.VkLayerProperties, layer_count);
    try checkResult(c.vkEnumerateInstanceLayerProperties(&layer_count, layers.ptr));

    const required_layers = getRequiredInstanceValidationLayers();
    try hasRequiredValidationLayers(required_layers, layers);

    const app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .apiVersion = c.VK_API_VERSION_1_3,
        .pApplicationName = params.application.title,
        .applicationVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .pEngineName = params.application.title,
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
    };

    const instance_create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @as(u32, @intCast(required_extensions.len)),
        .ppEnabledExtensionNames = &required_extensions[0],
        .enabledLayerCount = @as(u32, @intCast(required_layers.len)),
        .ppEnabledLayerNames = &required_layers[0],
    };

    try checkResult(c.vkCreateInstance(&instance_create_info, 0, &self.instance));
}

fn initVkSurface(self: *Self, params: InitParams) !void {
    try checkResult(vulkan.createSurface(self.instance, &self.surface, params.window));
}

fn initVkPhysicalDevice(self: *Self) !void {
    std.log.debug("Picking suitable GPU", .{});
    var arena_allocator = std.heap.ArenaAllocator.init(self.allocator);
    defer arena_allocator.deinit();

    var allocator = arena_allocator.allocator();

    var physical_device_count: u32 = 0;
    var physical_devices: []c.VkPhysicalDevice = undefined;
    try checkResult(c.vkEnumeratePhysicalDevices(self.instance, &physical_device_count, null));

    physical_devices = try allocator.alloc(c.VkPhysicalDevice, physical_device_count);
    try checkResult(c.vkEnumeratePhysicalDevices(self.instance, &physical_device_count, physical_devices.ptr));

    const required_extensions: []const [*c]const u8 = &.{
        "VK_KHR_swapchain",
    };

    var is_device_set = false;
    for (physical_devices) |physical_device| {
        var properties: c.VkPhysicalDeviceProperties = undefined;

        c.vkGetPhysicalDeviceProperties(physical_device, &properties);

        std.log.debug("Found GPU: {s}", .{properties.deviceName});

        var extensions: []c.VkExtensionProperties = undefined;
        var extension_count: u32 = undefined;
        try checkResult(c.vkEnumerateDeviceExtensionProperties(physical_device, 0, &extension_count, null));

        extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
        try checkResult(c.vkEnumerateDeviceExtensionProperties(physical_device, 0, &extension_count, extensions.ptr));

        hasRequiredExtensions(required_extensions, extensions) catch {
            std.log.debug("GPU: {s} is missing required extension. skipping...", .{properties.deviceName});
            continue;
        };

        var queue_properties: []c.VkQueueFamilyProperties = undefined;
        var queue_property_count: u32 = undefined;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_property_count, null);

        queue_properties = try allocator.alloc(c.VkQueueFamilyProperties, queue_property_count);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_property_count, queue_properties.ptr);

        var graphics_queue_index: i32 = -1;
        var present_queue_index: i32 = -1;
        var compute_queue_index: i32 = -1;
        var transfer_queue_index: i32 = -1;
        var support_present = c.VK_FALSE;
        var is_dedicated_transfer = false;

        for (queue_properties, 0..) |queue_property, i| {
            support_present = c.VK_FALSE;

            // graphics queue
            if (graphics_queue_index == -1 and queue_property.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_index = @intCast(i);

                try checkResult(c.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, @intCast(i), self.surface, &support_present));

                // also present?
                if (support_present != c.VK_FALSE)
                    present_queue_index = @intCast(i);
            }

            // compute
            if (queue_property.queueFlags & c.VK_QUEUE_COMPUTE_BIT != 0)
                compute_queue_index = @intCast(i);

            // dedicated transfer
            if (queue_property.queueFlags & c.VK_QUEUE_TRANSFER_BIT != 0) {
                if (queue_property.queueFlags & c.VK_QUEUE_GRAPHICS_BIT == 0 and queue_property.queueFlags & c.VK_QUEUE_COMPUTE_BIT == 0) {
                    transfer_queue_index = @intCast(i);
                    is_dedicated_transfer = true;
                } else if (!is_dedicated_transfer) {
                    transfer_queue_index = @intCast(i);
                }
            }
        }

        // if no dedicated present queue pick first available
        if (present_queue_index == -1) {
            for (0..queue_property_count) |i| {
                try checkResult(c.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, @intCast(i), self.surface, &support_present));

                if (support_present != c.VK_FALSE)
                    present_queue_index = @intCast(i);
            }
        }

        if (graphics_queue_index == -1 or present_queue_index == -1 or compute_queue_index == -1) {
            std.log.debug("GPU: {s} does not support required queues. skipping...", .{properties.deviceName});
            continue;
        }

        var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try checkResult(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, self.surface, &surface_capabilities));

        var surface_formats: []c.VkSurfaceFormatKHR = undefined;
        var surface_format_count: u32 = undefined;
        try checkResult(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, self.surface, &surface_format_count, null));

        // not allocated with arena as we want to keep this alive after this fn
        surface_formats = try self.allocator.alloc(c.VkSurfaceFormatKHR, surface_format_count);
        errdefer self.allocator.free(surface_formats);
        try checkResult(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, self.surface, &surface_format_count, surface_formats.ptr));

        var surface_present_modes: []c.VkPresentModeKHR = undefined;
        var surface_present_mode_count: u32 = undefined;
        try checkResult(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, self.surface, &surface_present_mode_count, null));

        // not allocated with arena as we want to keep this alive after this fn
        surface_present_modes = try self.allocator.alloc(c.VkPresentModeKHR, surface_present_mode_count);
        errdefer self.allocator.free(surface_present_modes);
        try checkResult(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, self.surface, &surface_present_mode_count, surface_present_modes.ptr));

        if (surface_format_count == 0 and surface_present_mode_count == 0) {
            std.log.debug("GPU: {s} does not support swapchain. skipping...", .{properties.deviceName});
            continue;
        }

        var features: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceFeatures(physical_device, &features);

        var memory_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(physical_device, &memory_properties);

        // device is valid, pick best gpu
        if (!is_device_set) {
            self.physical_device = physical_device;
            self.physical_device_features = features;
            self.physical_device_memory = memory_properties;
            self.physical_device_properties = properties;
            self.physical_device_present_modes = surface_present_modes;
            self.physical_device_surface_formats = surface_formats;
            self.physical_device_surface_capabilities = surface_capabilities;
            self.graphics_queue_index = @intCast(graphics_queue_index);
            self.present_queue_index = @intCast(present_queue_index);
            self.compute_queue_index = @intCast(compute_queue_index);
            self.transfer_queue_index = @intCast(transfer_queue_index);
            is_device_set = true;
        } else if (self.physical_device_properties.deviceType != c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU and
            properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
        {
            self.physical_device = physical_device;
            self.physical_device_features = features;
            self.physical_device_memory = memory_properties;
            self.physical_device_properties = properties;
            self.physical_device_present_modes = surface_present_modes;
            self.physical_device_surface_formats = surface_formats;
            self.physical_device_surface_capabilities = surface_capabilities;
            self.graphics_queue_index = @intCast(graphics_queue_index);
            self.present_queue_index = @intCast(present_queue_index);
            self.compute_queue_index = @intCast(compute_queue_index);
            self.transfer_queue_index = @intCast(transfer_queue_index);
        }
    }

    if (!is_device_set) {
        return error.NoSuitableGPUFound;
    }

    std.log.debug("Picked GPU: {s}", .{self.physical_device_properties.deviceName});
}

fn initVkLogicalDevice(self: *Self) !void {
    std.log.debug("Creating vulkan logical device", .{});

    const required_extensions: []const [*c]const u8 = &.{
        c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };

    const priority: f32 = 1.0;
    const queue_create_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = self.graphics_queue_index,
        .queueCount = 1,
        .pQueuePriorities = &priority,
    };
    const physical_device_features = std.mem.zeroes(c.VkPhysicalDeviceFeatures);

    const device_create_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_create_info,
        .enabledExtensionCount = required_extensions.len,
        .pEnabledFeatures = &physical_device_features,
        .ppEnabledExtensionNames = required_extensions.ptr,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
    };

    try checkResult(c.vkCreateDevice(self.physical_device, &device_create_info, null, &self.device));

    // for now only graphics queue
    c.vkGetDeviceQueue(self.device, self.graphics_queue_index, 0, &self.graphics_queue);
}

fn initVkSwapChain(self: *Self, params: InitParams) !void {

    // pick format
    var found = false;
    for (self.physical_device_surface_formats, 0..) |format, i| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            self.physical_device_surface_format = @intCast(i);
            found = true;
        }
    }

    if (!found)
        return error.NoValidVulkanSurfaceFormatFound;

    for (self.physical_device_present_modes, 0..) |mode, i| {
        if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            self.physical_device_present_mode = @intCast(i);
            found = true;
        }
    }

    self.extend = .{
        .width = std.math.clamp(params.window.width, self.physical_device_surface_capabilities.minImageExtent.width, self.physical_device_surface_capabilities.maxImageExtent.width),
        .height = std.math.clamp(params.window.height, self.physical_device_surface_capabilities.minImageExtent.height, self.physical_device_surface_capabilities.maxImageExtent.height),
    };

    const surface_format = self.physical_device_surface_formats[self.physical_device_surface_format];
    const queue_indices = [_]u32{ self.graphics_queue_index, self.present_queue_index };

    var swapchain_create_info = c.VkSwapchainCreateInfoKHR{ .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, .imageFormat = surface_format.format, .imageColorSpace = surface_format.colorSpace, .imageArrayLayers = 1, .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, .imageExtent = self.extend, .minImageCount = self.physical_device_surface_capabilities.minImageCount + 1, .preTransform = self.physical_device_surface_capabilities.currentTransform, .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, .presentMode = self.physical_device_present_modes[self.physical_device_present_mode], .clipped = c.VK_TRUE, .oldSwapchain = null, .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE, .queueFamilyIndexCount = 0, .pQueueFamilyIndices = null, .surface = self.surface };

    if (self.graphics_queue_index != self.present_queue_index) {
        swapchain_create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        swapchain_create_info.queueFamilyIndexCount = 2;
        swapchain_create_info.pQueueFamilyIndices = &queue_indices[0];
    }

    try checkResult(c.vkCreateSwapchainKHR(self.device, &swapchain_create_info, null, &self.swapchain));
}

fn initVkImageViews(self: *Self) !void {
    var image_count: u32 = undefined;
    var images: []c.VkImage = undefined;
    try checkResult(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, null));

    images = try self.allocator.alloc(c.VkImage, image_count);
    errdefer self.allocator.free(images);
    try checkResult(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, images.ptr));

    var image_views: []c.VkImageView = undefined;
    image_views = try self.allocator.alloc(c.VkImageView, image_count);
    errdefer self.allocator.free(images);

    var image_create_info = c.VkImageViewCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = self.physical_device_surface_formats[self.physical_device_surface_format].format,
        .components = .{
            .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    for (images, image_views) |image, *image_view| {
        image_create_info.image = image;
        try checkResult(c.vkCreateImageView(self.device, &image_create_info, null, image_view));
    }

    self.swapchain_images = images;
    self.swapchain_image_views = image_views;
}

fn initVkCommandPool(self: *Self) !void {
    const cmd_pool_create_info = c.VkCommandPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = self.graphics_queue_index,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
    };

    var cmd_pool: c.VkCommandPool = undefined;
    try checkResult(c.vkCreateCommandPool(self.device, &cmd_pool_create_info, null, &cmd_pool));

    self.command_pool = cmd_pool;
}

fn initVkCommandBuffer(self: *Self) !void {
    const cmd_buffer_create_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = self.command_pool,
        .commandBufferCount = 1,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    };

    var cmd_buffer: c.VkCommandBuffer = undefined;
    try checkResult(c.vkAllocateCommandBuffers(self.device, &cmd_buffer_create_info, &cmd_buffer));

    self.command_buffer = cmd_buffer;
}

fn initVkRenderPass(self: *Self) !void {
    const color_attachment = c.VkAttachmentDescription{
        .format = self.physical_device_surface_formats[self.physical_device_surface_format].format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    const color_attachment_ref = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass_description = c.VkSubpassDescription{ .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS, .colorAttachmentCount = 1, .pColorAttachments = &color_attachment_ref };

    const render_pass_create_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass_description,
    };

    var render_pass: c.VkRenderPass = undefined;
    try checkResult(c.vkCreateRenderPass(self.device, &render_pass_create_info, null, &render_pass));

    self.render_pass = render_pass;
}

fn initVkFrameBuffers(self: *Self) !void {
    var framebuffer_create_info = c.VkFramebufferCreateInfo{ .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, .renderPass = self.render_pass, .attachmentCount = 1, .width = self.extend.width, .height = self.extend.height, .layers = 1 };

    const framebuffers: []c.VkFramebuffer = try self.allocator.alloc(c.VkFramebuffer, self.swapchain_image_views.len);
    errdefer self.allocator.free(framebuffers);

    for (self.swapchain_image_views, framebuffers) |*image_view, *framebuffer| {
        framebuffer_create_info.pAttachments = image_view;
        try checkResult(c.vkCreateFramebuffer(self.device, &framebuffer_create_info, null, framebuffer));
    }

    self.framebuffers = framebuffers;
}

fn initVkFence(self: *Self) !void {
    const fence_create_info = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    var fence: c.VkFence = undefined;
    try checkResult(c.vkCreateFence(self.device, &fence_create_info, null, &fence));

    self.fence = fence;
}

fn initVkSemaphores(self: *Self) !void {
    const semaphore_create_info = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .flags = 0,
    };

    var semaphore: c.VkSemaphore = undefined;
    try checkResult(c.vkCreateSemaphore(self.device, &semaphore_create_info, null, &semaphore));
    self.render_semaphore = semaphore;

    try checkResult(c.vkCreateSemaphore(self.device, &semaphore_create_info, null, &semaphore));
    self.present_semaphore = semaphore;
}

fn initVkDebugMessenger(self: *Self) !void {
    const createFn = try self.getInstanceFunction(c.PFN_vkCreateDebugUtilsMessengerEXT, "vkCreateDebugUtilsMessengerEXT");

    if (createFn) |vkCreateDebugUtilsMessengerEXT| {
        const debug_create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT,
            .pfnUserCallback = debugCallback,
            .pUserData = null,
        };

        try checkResult(vkCreateDebugUtilsMessengerEXT(self.instance, &debug_create_info, null, &self.debug_msgr));
    }
}

fn getInstanceFunction(self: Self, comptime Fn: type, name: [*c]const u8) !Fn {
    if (c.vkGetInstanceProcAddr(self.instance, name)) |function| {
        return @ptrCast(function);
    }
    return error.vkGetInstanceProcAddrReturnedNull;
}

fn debugCallback(severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, msg_type: c.VkDebugUtilsMessageTypeFlagsEXT, callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT, user_data: ?*anyopaque) callconv(.C) c.VkBool32 {
    _ = msg_type; // autofix
    _ = user_data; // autofix

    if (callback_data) |data| {
        switch (severity) {
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => {
                std.log.debug("{s}", .{data.pMessage});
            },
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => {
                std.log.info("{s}", .{data.pMessage});
            },
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
                std.log.warn("{s}", .{data.pMessage});
            },
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
                std.log.err("{s}", .{data.pMessage});
            },
            else => {
                std.log.warn("{s}", .{data.pMessage});
            },
        }
    }

    return c.VK_FALSE;
}

fn getRequiredInstanceExtensions() []const [*c]const u8 {
    comptime var extensions: []const [*c]const u8 = &.{c.VK_KHR_SURFACE_EXTENSION_NAME};
    switch (builtin.os.tag) {
        .windows => {
            extensions = extensions ++ .{c.VK_KHR_WIN32_SURFACE_EXTENSION_NAME};
        },
        .linux => {
            extensions = extensions ++ .{c.VK_KHR_XCB_SURFACE_EXTENSION_NAME};
        },
        else => return error.PlatformNotSupported,
    }

    switch (builtin.mode) {
        .Debug => {
            extensions = extensions ++ .{c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME};
        },
        else => {},
    }

    return extensions;
}

fn getRequiredInstanceValidationLayers() []const [*c]const u8 {
    comptime var layers: []const [*c]const u8 = &.{};

    switch (builtin.mode) {
        .Debug => {
            layers = layers ++ .{"VK_LAYER_KHRONOS_validation"};
        },
        else => {},
    }

    return layers;
}

fn hasRequiredExtensions(required_extensions: []const [*c]const u8, extensions: []c.VkExtensionProperties) !void {
    for (required_extensions) |required_extension| {
        var hasExtension = false;
        for (extensions) |extension| {
            if (std.mem.eql(u8, std.mem.span(required_extension), std.mem.span(@as([*c]const u8, @ptrCast(extension.extensionName[0..]))))) {
                hasExtension = true;
                break;
            }
        }

        if (!hasExtension)
            return error.MissingRequiredVkInstanceExtension;
    }
}

fn hasRequiredValidationLayers(required_layers: []const [*c]const u8, layers: []c.VkLayerProperties) !void {
    for (required_layers) |required_layer| {
        var hasLayer = false;
        for (layers) |layer| {
            if (std.mem.eql(u8, std.mem.span(required_layer), std.mem.span(@as([*c]const u8, @ptrCast(layer.layerName[0..]))))) {
                hasLayer = true;
                break;
            }
        }

        if (!hasLayer)
            return error.MissingRequiredVkInstanceLayer;
    }
}

fn checkResult(result: c.VkResult) !void {
    return switch (result) {
        c.VK_SUCCESS => {},
        c.VK_NOT_READY => error.VkNotReady,
        c.VK_TIMEOUT => error.VkTimeout,
        c.VK_EVENT_SET => error.VkEventSet,
        c.VK_EVENT_RESET => error.VkEventReset,
        c.VK_INCOMPLETE => error.VkIncomplete,
        c.VK_ERROR_OUT_OF_HOST_MEMORY => error.VkErrorOutOfHostMemory,
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => error.VkErrorOutOfDeviceMemory,
        c.VK_ERROR_INITIALIZATION_FAILED => error.VkErrorInitializationFailed,
        c.VK_ERROR_DEVICE_LOST => error.VkErrorDeviceLost,
        c.VK_ERROR_MEMORY_MAP_FAILED => error.VkErrorMemoryMapFailed,
        c.VK_ERROR_LAYER_NOT_PRESENT => error.VkErrorLayerNotPresent,
        c.VK_ERROR_EXTENSION_NOT_PRESENT => error.VkErrorExtensionNotPresent,
        c.VK_ERROR_FEATURE_NOT_PRESENT => error.VkErrorFeatureNotPresent,
        c.VK_ERROR_INCOMPATIBLE_DRIVER => error.VkErrorIncompatibleDriver,
        c.VK_ERROR_TOO_MANY_OBJECTS => error.VkErrorTooManyObjects,
        c.VK_ERROR_FORMAT_NOT_SUPPORTED => error.VkErrorFormatNotSupported,
        c.VK_ERROR_FRAGMENTED_POOL => error.VkErrorFragmentedPool,
        c.VK_ERROR_UNKNOWN => error.VkErrorUnknown,
        c.VK_ERROR_OUT_OF_POOL_MEMORY => error.VkErrorOutOfPoolMemory,
        c.VK_ERROR_INVALID_EXTERNAL_HANDLE => error.VkErrorInvalidExternalHandle,
        c.VK_ERROR_FRAGMENTATION => error.VkErrorFragmentation,
        c.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS => error.VkErrorInvalidOpaqueCaptureAddress,
        c.VK_PIPELINE_COMPILE_REQUIRED => error.VkPipelineCompileRequired,
        c.VK_ERROR_SURFACE_LOST_KHR => error.VkErrorSurfaceLostKhr,
        c.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR => error.VkErrorNativeWindowInUseKhr,
        c.VK_SUBOPTIMAL_KHR => error.VkSuboptimalKhr,
        c.VK_ERROR_OUT_OF_DATE_KHR => error.VkErrorOutOfDateKhr,
        c.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR => error.VkErrorIncompatibleDisplayKhr,
        c.VK_ERROR_VALIDATION_FAILED_EXT => error.VkErrorValidationFailedExt,
        c.VK_ERROR_INVALID_SHADER_NV => error.VkErrorInvalidShaderNv,
        c.VK_ERROR_INVALID_DRM_FORMAT_MODIFIER_PLANE_LAYOUT_EXT => error.VkErrorInvalidDrmFormatModifierPlaneLayoutExt,
        c.VK_ERROR_NOT_PERMITTED_KHR => error.VkErrorNotPermittedKhr,
        c.VK_ERROR_FULL_SCREEN_EXCLUSIVE_MODE_LOST_EXT => error.VkErrorFullScreenExclusiveModeLostExt,
        c.VK_THREAD_IDLE_KHR => error.VkThreadIdleKhr,
        c.VK_THREAD_DONE_KHR => error.VkThreadDoneKhr,
        c.VK_OPERATION_DEFERRED_KHR => error.VkOperationDeferredKhr,
        c.VK_OPERATION_NOT_DEFERRED_KHR => error.VkOperationNotDeferredKhr,
        c.VK_ERROR_COMPRESSION_EXHAUSTED_EXT => error.VkErrorCompressionExhaustedExt,
        else => error.VkErrorUnknown,
    };
}
