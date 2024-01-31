const std = @import("std");
const builtin = @import("builtin");
const vulkan = @import("../platform/vulkan.zig").vulkan;
const c = vulkan.c;
const engine = @import("../root.zig");
const math = engine.math;

const Camera = @import("Camera.zig");

pub const InitParams = struct {
    allocator: std.mem.Allocator,
    application: *engine.Application,
    window: *engine.Window,
    resize_event_reader: engine.WindowResizeEventQueue.Reader,
    inflight_count: u32,
};

pub const Vertex = struct {
    position: math.Vec3F,
    color: math.Vec4F,

    const input_description: c.VkVertexInputBindingDescription = .{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
    };

    const attribute_description: [2]c.VkVertexInputAttributeDescription = .{
        .{
            .binding = 0,
            .location = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "position"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = c.VK_FORMAT_R32G32B32A32_SFLOAT,
            .offset = @offsetOf(Vertex, "color"),
        },
    };
};

const Self = @This();

var framenumber: u32 = 0;

const vertices = [_]Vertex{
    Vertex{
        .position = math.Vec3F.init(-0.5, -0.5, 0.0),
        .color = math.Vec4F.init(1.0, 0.0, 0.0, 1.0),
    },
    Vertex{
        .position = math.Vec3F.init(0.5, -0.5, 0.0),
        .color = math.Vec4F.init(0.0, 1.0, 0.0, 1.0),
    },
    Vertex{
        .position = math.Vec3F.init(0.5, 0.5, 0.0),
        .color = math.Vec4F.init(0.0, 0.0, 1.0, 1.0),
    },
    Vertex{
        .position = math.Vec3F.init(-0.5, 0.5, 0.0),
        .color = math.Vec4F.init(1.0, 1.0, 1.0, 1.0),
    },
};

const indices = [_]u16{ 0, 1, 2, 2, 3, 0 };

framebuffer_width: u32,
framebuffer_height: u32,

in_flight_frame_count: u32,

allocator: std.mem.Allocator,

camera: Camera = undefined,

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
command_buffers: []c.VkCommandBuffer = undefined,

render_pass: c.VkRenderPass = undefined,

fences: []c.VkFence = undefined,
render_semaphores: []c.VkSemaphore = undefined,
present_semaphores: []c.VkSemaphore = undefined,

vertex_shader: c.VkShaderModule = undefined,
fragment_shader: c.VkShaderModule = undefined,

descriptor_layout: c.VkDescriptorSetLayout = undefined,

pipeline_layout: c.VkPipelineLayout = undefined,
pipeline: c.VkPipeline = undefined,

vertex_buffer: c.VkBuffer = undefined,
vertex_buffer_mem: c.VkDeviceMemory = undefined,

index_buffer: c.VkBuffer = undefined,
index_buffer_mem: c.VkDeviceMemory = undefined,

staging_buffer: c.VkBuffer = undefined,
staging_buffer_mem: c.VkDeviceMemory = undefined,

uniform_buffers: []c.VkBuffer = undefined,
uniform_buffers_mem: []c.VkDeviceMemory = undefined,
uniform_buffers_mapped: []*anyopaque = undefined,

debug_msgr: c.VkDebugUtilsMessengerEXT = undefined,
resize_event_reader: engine.WindowResizeEventQueue.Reader,
resize_requested: bool = false,

pub fn init(params: InitParams) !Self {
    const extend = params.window.getSize();

    var self = Self{
        .allocator = params.allocator,
        .in_flight_frame_count = params.inflight_count,
        .framebuffer_width = extend.width,
        .framebuffer_height = extend.height,
        .resize_event_reader = params.resize_event_reader,
    };

    try self.initVkInstance(params);
    try self.initVkDebugMessenger();
    try self.initVkSurface(params);
    try self.initVkPhysicalDevice();
    try self.initVkLogicalDevice();
    try self.initVkSwapChain();
    try self.initVkImageViews();
    try self.initVkRenderPass();
    try self.initVkShaderModule("zig-out/bin/triangle.vert.spv", &self.vertex_shader);
    try self.initVkShaderModule("zig-out/bin/triangle.frag.spv", &self.fragment_shader);
    try self.initVkDescriptorLayout();
    try self.initVkPipeline();
    try self.initVkCommandPool();
    try self.initVertexBuffer();
    try self.initIndexBuffer();
    try self.initVkCommandBuffer();
    try self.initVkFrameBuffers();
    try self.initVkSemaphoresAndFences();

    return self;
}

fn initVkDescriptorLayout(self: *Self) !void {
    const layout_binding = c.VkDescriptorSetLayoutBinding{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
        .pImmutableSamplers = null,
    };

    const layout_create_info = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &layout_binding,
    };

    var layout: c.VkDescriptorSetLayout = undefined;
    try checkResult(c.vkCreateDescriptorSetLayout(self.device, &layout_create_info, null, &layout));
    self.descriptor_layout = layout;
}

fn createBuffer(self: Self, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, buffer_memory: *c.VkDeviceMemory) !void {
    const buffer_create_info = c.VkBufferCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    try checkResult(c.vkCreateBuffer(self.device, &buffer_create_info, null, buffer));

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(self.device, buffer.*, &mem_requirements);

    const mem_type_index = try self.findMemoryIndex(mem_requirements.memoryTypeBits, properties);
    var alloc_info = c.VkMemoryAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = mem_type_index,
    };

    try checkResult(c.vkAllocateMemory(self.device, &alloc_info, null, buffer_memory));
    try checkResult(c.vkBindBufferMemory(self.device, buffer.*, buffer_memory.*, 0));
}

fn recreateSwapChain(self: *Self) !void {
    try checkResult(c.vkDeviceWaitIdle(self.device));

    self.deinitVkSwapchain();

    while (self.resize_event_reader.receive()) |event| {
        self.framebuffer_width = event.width;
        self.framebuffer_height = event.height;
        std.log.debug("handled event: {}, {}", .{ self.framebuffer_width, self.framebuffer_height });
    }

    try self.initVkSwapChain();
    try self.initVkImageViews();
    try self.initVkFrameBuffers();
}

fn deinitVkSwapchain(self: Self) void {
    for (self.framebuffers) |framebuffer| {
        c.vkDestroyFramebuffer(self.device, framebuffer, null);
    }
    self.allocator.free(self.framebuffers);

    for (self.swapchain_image_views) |image_view| {
        c.vkDestroyImageView(self.device, image_view, null);
    }
    self.allocator.free(self.swapchain_image_views);

    c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
}

fn initVertexBuffer(self: *Self) !void {
    const size = @sizeOf(@TypeOf(vertices[0])) * vertices.len;
    try self.createBuffer(
        size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &self.staging_buffer,
        &self.staging_buffer_mem,
    );

    try self.mapBuffer(Vertex, vertices[0..], self.staging_buffer_mem);

    try self.createBuffer(
        size,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &self.vertex_buffer,
        &self.vertex_buffer_mem,
    );

    try self.copyBuffer(self.staging_buffer, self.vertex_buffer, size);

    c.vkDestroyBuffer(self.device, self.staging_buffer, null);
    c.vkFreeMemory(self.device, self.staging_buffer_mem, null);
}

fn initIndexBuffer(self: *Self) !void {
    const size = @sizeOf(@TypeOf(indices[0])) * indices.len;
    try self.createBuffer(
        size,
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        &self.staging_buffer,
        &self.staging_buffer_mem,
    );

    try self.mapBuffer(u16, indices[0..], self.staging_buffer_mem);

    try self.createBuffer(
        size,
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
        c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        &self.index_buffer,
        &self.index_buffer_mem,
    );

    try self.copyBuffer(self.staging_buffer, self.index_buffer, size);

    c.vkDestroyBuffer(self.device, self.staging_buffer, null);
    c.vkFreeMemory(self.device, self.staging_buffer_mem, null);
}

fn initUniformBuffers(self: *Self) !void {
    const size: c.VkDeviceSize = @sizeOf(@TypeOf(self.camera));

    self.uniform_buffers = try self.allocator.alloc(c.VkBuffer, self.in_flight_frame_count);
    self.uniform_buffers_mem = try self.allocator.alloc(c.VkDeviceMemory, self.in_flight_frame_count);
    self.uniform_buffers_mapped = try self.allocator.alloc(*anyopaque, self.in_flight_frame_count);

    for (self.uniform_buffers, self.uniform_buffers_mem, self.uniform_buffers_mapped) |*buf, *mem, *map| {
        try self.createBuffer(
            size,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            buf,
            mem,
        );

        try checkResult(c.vkMapMemory(self.device, mem, 0, size, @ptrCast(&map)));
    }
}

fn copyBuffer(self: Self, source: c.VkBuffer, destination: c.VkBuffer, size: c.VkDeviceSize) !void {
    const alloc_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = self.command_pool,
        .commandBufferCount = 1,
    };
    var command_buffer: c.VkCommandBuffer = undefined;
    try checkResult(c.vkAllocateCommandBuffers(self.device, &alloc_info, &command_buffer));

    const begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    try checkResult(c.vkBeginCommandBuffer(command_buffer, &begin_info));

    const copy_slice = c.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    c.vkCmdCopyBuffer(command_buffer, source, destination, 1, &copy_slice);

    try checkResult(c.vkEndCommandBuffer(command_buffer));

    const submit_info = c.VkSubmitInfo{ .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &command_buffer };

    try checkResult(c.vkQueueSubmit(self.graphics_queue, 1, &submit_info, null));
    try checkResult(c.vkQueueWaitIdle(self.graphics_queue));

    c.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
}

fn mapBuffer(self: Self, comptime T: type, source: []const T, buffer_memory: c.VkDeviceMemory) !void {
    var data: *anyopaque = undefined;
    try checkResult(c.vkMapMemory(self.device, buffer_memory, 0, @sizeOf(@TypeOf(source[0])) * source.len, 0, @ptrCast(&data)));
    const destination: []T = @as([*]T, @alignCast(@ptrCast(data)))[0..source.len];
    @memcpy(destination, source);
    c.vkUnmapMemory(self.device, buffer_memory);
}

fn findMemoryIndex(self: Self, filter: u32, flags: u32) !u32 {
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &memProperties);

    var i: u32 = 0;
    const one: u32 = 1;
    while (i < memProperties.memoryTypeCount) : (i += 1) {
        if ((filter & (one << @intCast(i))) != 0 and (memProperties.memoryTypes[i].propertyFlags & flags) == flags) {
            return i;
        }
    }

    return error.NoSuitableMemoryTypeFound;
}

fn initVkPipeline(self: *Self) !void {
    const shader_stages_create_info = [_]c.VkPipelineShaderStageCreateInfo{
        c.VkPipelineShaderStageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
            .module = self.vertex_shader,
            .pName = "main",
        },
        c.VkPipelineShaderStageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = self.fragment_shader,
            .pName = "main",
        },
    };

    const dynamic_states = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamic_state_create_info = c.VkPipelineDynamicStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamic_states.len,
        .pDynamicStates = &dynamic_states[0],
    };

    const vertex_input_create_info = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &Vertex.input_description,
        .vertexAttributeDescriptionCount = Vertex.attribute_description.len,
        .pVertexAttributeDescriptions = &Vertex.attribute_description[0],
    };

    const input_assembly_create_info = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    const viewport_state_create_info = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .scissorCount = 1,
    };

    const rasterizer_create_info = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
    };

    const multisampling_create_info = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
    };

    const color_blend_attachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const color_blend_create_info = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
    };

    const pipeline_layout_create_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &self.descriptor_layout,
    };

    var pipeline_layout: c.VkPipelineLayout = undefined;
    try checkResult(c.vkCreatePipelineLayout(self.device, &pipeline_layout_create_info, null, &pipeline_layout));

    self.pipeline_layout = pipeline_layout;

    const pipeline_create_info = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shader_stages_create_info[0],
        .pVertexInputState = &vertex_input_create_info,
        .pInputAssemblyState = &input_assembly_create_info,
        .pViewportState = &viewport_state_create_info,
        .pRasterizationState = &rasterizer_create_info,
        .pMultisampleState = &multisampling_create_info,
        .pColorBlendState = &color_blend_create_info,
        .pDynamicState = &dynamic_state_create_info,
        .layout = self.pipeline_layout,
        .renderPass = self.render_pass,
        .subpass = 0,
        .basePipelineHandle = @ptrCast(c.VK_NULL_HANDLE),
    };

    var pipeline: c.VkPipeline = undefined;
    try checkResult(c.vkCreateGraphicsPipelines(self.device, @ptrCast(c.VK_NULL_HANDLE), 1, &pipeline_create_info, null, &pipeline));

    self.pipeline = pipeline;

    c.vkDestroyShaderModule(self.device, self.fragment_shader, null);
    c.vkDestroyShaderModule(self.device, self.vertex_shader, null);
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
        .codeSize = file_size,
        .pCode = @as([*]const u32, @alignCast(@ptrCast(buffer))),
    };

    try checkResult(c.vkCreateShaderModule(self.device, &module_create_info, null, module));
}

pub fn deinit(self: Self) void {
    for (self.render_semaphores, self.present_semaphores, self.fences) |render_semaphore, present_semaphore, fence| {
        c.vkDestroySemaphore(self.device, render_semaphore, null);
        c.vkDestroySemaphore(self.device, present_semaphore, null);
        c.vkDestroyFence(self.device, fence, null);
    }
    c.vkDestroyCommandPool(self.device, self.command_pool, null);

    self.deinitVkSwapchain();

    c.vkDestroyDescriptorSetLayout(self.device, self.descriptor_layout, null);

    c.vkDestroyBuffer(self.device, self.vertex_buffer, null);
    c.vkFreeMemory(self.device, self.vertex_buffer_mem, null);

    c.vkDestroyBuffer(self.device, self.index_buffer, null);
    c.vkFreeMemory(self.device, self.index_buffer_mem, null);

    for (self.uniform_buffers, self.uniform_buffers_mem) |buf, mem| {
        c.vkDestroyBuffer(self.device, buf, null);
        c.vkFreeMemory(self.device, mem, null);
    }

    c.vkDestroyPipeline(self.device, self.pipeline, null);
    c.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
    c.vkDestroyRenderPass(self.device, self.render_pass, null);

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

pub fn updateUniforms() !void {
    const StartTime = struct {
        const time = std.time.milliTimestamp();
    };
    _ = StartTime; // autofix

    // var current_time = std.time.milliTimestamp();
    // var time: f32 = @floatFromInt(current_time - StartTime.time);
    // _ = time; // autofix

    // var camera = Camera{
    //     .model =
    // }
}

pub fn draw(self: *Self) !void {
    if (self.resize_requested) {
        try self.recreateSwapChain();
        self.resize_requested = false;
    }

    try checkResult(c.vkWaitForFences(self.device, 1, &self.fences[framenumber], c.VK_TRUE, std.math.maxInt(u64)));

    try checkResult(c.vkResetFences(self.device, 1, &self.fences[framenumber]));

    var swapchain_image_index: u32 = 0;

    checkResult(c.vkAcquireNextImageKHR(self.device, self.swapchain, 100000, self.present_semaphores[framenumber], null, &swapchain_image_index)) catch |err| {
        switch (err) {
            error.VkSuboptimalKhr, error.VkErrorOutOfDateKhr => {
                std.log.debug("Error 3 {}", .{err});
                self.resize_requested = true;
                return;
            },
            else => {
                std.log.debug("Error 4 {}", .{err});
                return err;
            },
        }
    };

    try checkResult(c.vkResetCommandBuffer(self.command_buffers[framenumber], 0));

    const cmd_buffer_begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    };

    const clear_color = c.VkClearValue{
        .color = .{
            .float32 = .{ 0.0, 0.0, 0.0, 1.0 },
        },
    };

    const renderpass_begin_info = c.VkRenderPassBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = self.render_pass,
        .framebuffer = self.framebuffers[swapchain_image_index],
        .renderArea = .{
            .offset = .{
                .x = 0,
                .y = 0,
            },
            .extent = self.extend,
        },
        .clearValueCount = 1,
        .pClearValues = &clear_color,
    };

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @floatFromInt(self.extend.width),
        .height = @floatFromInt(self.extend.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor = c.VkRect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = self.extend,
    };

    try checkResult(c.vkBeginCommandBuffer(self.command_buffers[framenumber], &cmd_buffer_begin_info));

    c.vkCmdBeginRenderPass(self.command_buffers[framenumber], &renderpass_begin_info, c.VK_SUBPASS_CONTENTS_INLINE);

    c.vkCmdBindPipeline(self.command_buffers[framenumber], c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline);

    c.vkCmdSetViewport(self.command_buffers[framenumber], 0, 1, &viewport);
    c.vkCmdSetScissor(self.command_buffers[framenumber], 0, 1, &scissor);

    const vertex_buffers = [_]c.VkBuffer{self.vertex_buffer};
    const offsets = [_]u64{0};
    c.vkCmdBindVertexBuffers(self.command_buffers[framenumber], 0, 1, &vertex_buffers[0], &offsets[0]);
    c.vkCmdBindIndexBuffer(self.command_buffers[framenumber], self.index_buffer, 0, c.VK_INDEX_TYPE_UINT16);
    // c.vkCmdDraw(self.command_buffers[framenumber], @intCast(vertices.len), 1, 0, 0);
    c.vkCmdDrawIndexed(self.command_buffers[framenumber], @intCast(indices.len), 1, 0, 0, 0);
    c.vkCmdEndRenderPass(self.command_buffers[framenumber]);

    try checkResult(c.vkEndCommandBuffer(self.command_buffers[framenumber]));

    const wait_semaphores = [_]c.VkSemaphore{self.present_semaphores[framenumber]};
    const signal_semaphores = [_]c.VkSemaphore{self.render_semaphores[framenumber]};

    const wait_stages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    const submit_info = c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = wait_semaphores.len,
        .pWaitSemaphores = &wait_semaphores[0],
        .pWaitDstStageMask = &wait_stages[0],
        .commandBufferCount = 1,
        .pCommandBuffers = &self.command_buffers[framenumber],
        .signalSemaphoreCount = signal_semaphores.len,
        .pSignalSemaphores = &signal_semaphores[0],
    };

    try checkResult(c.vkQueueSubmit(self.graphics_queue, 1, &submit_info, self.fences[framenumber]));

    const swapchains = [_]c.VkSwapchainKHR{self.swapchain};
    const present_info = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signal_semaphores[0],
        .swapchainCount = 1,
        .pSwapchains = &swapchains[0],
        .pImageIndices = &swapchain_image_index,
    };

    checkResult(c.vkQueuePresentKHR(self.present_queue, &present_info)) catch |err| {
        switch (err) {
            error.VkSuboptimalKhr, error.VkErrorOutOfDateKhr => {
                self.resize_requested = true;
            },
            else => {
                std.log.debug("Error 2 {}", .{err});
                return err;
            },
        }
    };

    framenumber = (framenumber + 1) % self.in_flight_frame_count;
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
    try checkResult(vulkan.createSurface(self.instance, &self.surface, params.window.*));
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
    c.vkGetDeviceQueue(self.device, self.present_queue_index, 0, &self.present_queue);
}

fn initVkSwapChain(self: *Self) !void {
    var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
    try checkResult(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physical_device, self.surface, &surface_capabilities));
    self.physical_device_surface_capabilities = surface_capabilities;

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
        .width = std.math.clamp(self.framebuffer_width, self.physical_device_surface_capabilities.minImageExtent.width, self.physical_device_surface_capabilities.maxImageExtent.width),
        .height = std.math.clamp(self.framebuffer_height, self.physical_device_surface_capabilities.minImageExtent.height, self.physical_device_surface_capabilities.maxImageExtent.height),
    };

    std.log.debug("Creating extend, width: {}, height: {}", .{ self.extend.width, self.extend.height });

    const surface_format = self.physical_device_surface_formats[self.physical_device_surface_format];
    const queue_indices = [_]u32{ self.graphics_queue_index, self.present_queue_index };

    var swapchain_create_info = c.VkSwapchainCreateInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageExtent = self.extend,
        .minImageCount = self.physical_device_surface_capabilities.minImageCount + 1,
        .preTransform = self.physical_device_surface_capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = self.physical_device_present_modes[self.physical_device_present_mode],
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
        .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .surface = self.surface,
    };

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
    self.command_buffers = try self.allocator.alloc(c.VkCommandBuffer, self.in_flight_frame_count);

    const cmd_buffer_create_info = c.VkCommandBufferAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = self.command_pool,
        .commandBufferCount = @intCast(self.command_buffers.len),
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
    };

    try checkResult(c.vkAllocateCommandBuffers(self.device, &cmd_buffer_create_info, &self.command_buffers[0]));
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

    const subpass_description = c.VkSubpassDescription{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
    };

    const subpass_dependency = c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    };

    const render_pass_create_info = c.VkRenderPassCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass_description,
        .dependencyCount = 1,
        .pDependencies = &subpass_dependency,
    };

    var render_pass: c.VkRenderPass = undefined;
    try checkResult(c.vkCreateRenderPass(self.device, &render_pass_create_info, null, &render_pass));

    self.render_pass = render_pass;
}

fn initVkFrameBuffers(self: *Self) !void {
    var framebuffer_create_info = c.VkFramebufferCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .renderPass = self.render_pass,
        .attachmentCount = 1,
        .width = self.extend.width,
        .height = self.extend.height,
        .layers = 1,
    };

    const framebuffers: []c.VkFramebuffer = try self.allocator.alloc(c.VkFramebuffer, self.swapchain_image_views.len);
    errdefer self.allocator.free(framebuffers);

    for (self.swapchain_image_views, framebuffers) |*image_view, *framebuffer| {
        framebuffer_create_info.pAttachments = image_view;
        try checkResult(c.vkCreateFramebuffer(self.device, &framebuffer_create_info, null, framebuffer));
    }

    self.framebuffers = framebuffers;
}

fn initVkSemaphoresAndFences(self: *Self) !void {
    const fence_create_info = c.VkFenceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    const semaphore_create_info = c.VkSemaphoreCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };

    self.fences = try self.allocator.alloc(c.VkFence, self.in_flight_frame_count);
    self.render_semaphores = try self.allocator.alloc(c.VkSemaphore, self.in_flight_frame_count);
    self.present_semaphores = try self.allocator.alloc(c.VkSemaphore, self.in_flight_frame_count);

    for (self.render_semaphores, self.present_semaphores, self.fences) |*render_semaphore, *present_semaphore, *fence| {
        try checkResult(c.vkCreateSemaphore(self.device, &semaphore_create_info, null, render_semaphore));
        try checkResult(c.vkCreateSemaphore(self.device, &semaphore_create_info, null, present_semaphore));
        try checkResult(c.vkCreateFence(self.device, &fence_create_info, null, fence));
    }
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

    extensions = extensions ++ vulkan.platform_instance_extensions;

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
