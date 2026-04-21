const std = @import("std");
const vk = @import("vulkan");
const zglfw = @import("zglfw");
const pipeline_mod = @import("pipeline.zig");
const ui_pipeline_mod = @import("ui_pipeline.zig");
const mesh_indexed = @import("world/mesh_indexed.zig");
const texture_atlas = @import("renderer/texture_atlas.zig");

const Self = @This();

const MAX_FRAMES_IN_FLIGHT = 2;

pub const ChunkRenderData = struct {
    vertex_buffer: vk.Buffer,
    vertex_buffer_memory: vk.DeviceMemory,
    vertex_count: u32,
    index_buffer: vk.Buffer,
    index_buffer_memory: vk.DeviceMemory,
    index_count: u32,
    world_x: i32,
    world_y: i32,
    world_z: i32,
};

// Dispatch tables
const BaseDispatch = vk.BaseWrapper;
const InstanceDispatch = vk.InstanceWrapper;
const DeviceDispatch = vk.DeviceWrapper;

// Proxying wrappers
const Instance = vk.InstanceProxy;
const Device = vk.DeviceProxy;

allocator: std.mem.Allocator,
window: *zglfw.Window,

// Vulkan handles
instance: vk.Instance,
surface: vk.SurfaceKHR,
physical_device: vk.PhysicalDevice,
device: vk.Device,
graphics_queue: vk.Queue,
present_queue: vk.Queue,

// Dispatch
vkb: BaseDispatch,
vki: InstanceDispatch,
vkd: DeviceDispatch,

// Swapchain
swapchain: vk.SwapchainKHR,
swapchain_images: []vk.Image,
swapchain_image_views: []vk.ImageView,
swapchain_format: vk.Format,
swapchain_extent: vk.Extent2D,

// Render pass & framebuffers
render_pass: vk.RenderPass,
framebuffers: []vk.Framebuffer,

// Command pool & buffers
command_pool: vk.CommandPool,
command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,

// Sync
image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
current_frame: u32 = 0,

// Queue family indices
graphics_family: u32,
present_family: u32,

// Graphics pipeline
terrain_pipeline: vk.Pipeline,
terrain_pipeline_layout: vk.PipelineLayout,

// Texture atlas resources
atlas_image: vk.Image = .null_handle,
atlas_image_memory: vk.DeviceMemory = .null_handle,
atlas_image_view: vk.ImageView = .null_handle,
atlas_sampler: vk.Sampler = .null_handle,
descriptor_pool: vk.DescriptorPool = .null_handle,
descriptor_set: vk.DescriptorSet = .null_handle,
descriptor_set_layout: vk.DescriptorSetLayout = .null_handle,

// UI overlay pipeline (2D, alpha blended, no depth)
ui_pipeline: vk.Pipeline,
ui_pipeline_layout: vk.PipelineLayout,
ui_vertex_buffer: vk.Buffer = .null_handle,
ui_vertex_memory: vk.DeviceMemory = .null_handle,
ui_vertex_count: u32 = 0,

// Per-chunk render data
chunk_renders: std.ArrayList(ChunkRenderData),

// Depth buffer
depth_image: vk.Image,
depth_image_view: vk.ImageView,
depth_image_memory: vk.DeviceMemory,

// Current VP matrix (set each frame; per-chunk model applied in recordCommandBuffer)
current_vp: [4][4]f32,

// Sky and fog colors (set each frame from GameTime)
current_sky_color: [3]f32,
current_fog_color: [3]f32,

// HUD data passed through push constants
hud_health: f32 = 1.0,
hud_hunger: f32 = 1.0,
hud_selected_slot: f32 = 0.0,

// Entity rendering: reusable unit cube for mob visualization
entity_cube_buffer: vk.Buffer = .null_handle,
entity_cube_memory: vk.DeviceMemory = .null_handle,
entity_cube_index_buffer: vk.Buffer = .null_handle,
entity_cube_index_memory: vk.DeviceMemory = .null_handle,

// Entity draw list (positions + colors submitted per frame)
entity_draws: [128]EntityDraw = undefined,
entity_draw_count: u32 = 0,

// Particle draw list (small colored cubes from block break effects)
particle_draws: [256]ParticleDraw = undefined,
particle_draw_count: u32 = 0,

pub const EntityDraw = struct {
    x: f32,
    y: f32,
    z: f32,
    width: f32,
    height: f32,
    tex: u6,
};

pub const ParticleDraw = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    size: f32,
};

pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !Self {
    var self: Self = undefined;
    self.allocator = allocator;
    self.window = window;
    self.current_frame = 0;

    // Load base dispatch using a bridge loader (zglfw and vulkan-zig define
    // vk.Instance differently, so we must convert between them)
    self.vkb = BaseDispatch.load(getInstanceProcAddr);

    // Create instance
    self.instance = try self.createInstance();

    // Create surface
    self.surface = try self.createSurface();

    // Load instance dispatch using the bridge loader
    self.vki = InstanceDispatch.load(self.instance, getInstanceProcAddr);

    // Pick physical device
    self.physical_device = try self.pickPhysicalDevice();

    // Find queue families
    const families = try self.findQueueFamilies(self.physical_device);
    self.graphics_family = families.graphics;
    self.present_family = families.present;

    // Create logical device
    self.device = try self.createLogicalDevice();

    // Load device dispatch
    self.vkd = DeviceDispatch.load(self.device, self.vki.dispatch.vkGetDeviceProcAddr.?);

    // Get queues
    self.graphics_queue = self.vkd.getDeviceQueue(self.device, self.graphics_family, 0);
    self.present_queue = self.vkd.getDeviceQueue(self.device, self.present_family, 0);

    // Create swapchain
    try self.createSwapchain();

    // Create depth buffer resources
    try self.createDepthResources();

    // Create render pass
    self.render_pass = try self.createRenderPass();

    // Create framebuffers
    try self.createFramebuffers();

    // Create command pool & buffers
    try self.createCommandResources();

    // Create sync objects
    try self.createSyncObjects();

    // Create texture atlas resources (image, sampler, descriptors)
    try self.createTextureAtlas();

    // Create terrain graphics pipeline (needs descriptor set layout)
    const vert_spv: []align(4) const u8 = @alignCast(@embedFile("shaders/terrain.vert.spv"));
    const frag_spv: []align(4) const u8 = @alignCast(@embedFile("shaders/terrain.frag.spv"));

    const pl = try pipeline_mod.create(
        self.device,
        self.vkd,
        self.render_pass,
        vert_spv,
        frag_spv,
        self.descriptor_set_layout,
    );
    self.terrain_pipeline = pl.pipeline;
    self.terrain_pipeline_layout = pl.layout;

    // Create UI overlay pipeline
    const ui_vert_spv: []align(4) const u8 = @alignCast(@embedFile("shaders/ui.vert.spv"));
    const ui_frag_spv: []align(4) const u8 = @alignCast(@embedFile("shaders/ui.frag.spv"));
    const ui_pl = try ui_pipeline_mod.create(
        self.device,
        self.vkd,
        self.render_pass,
        self.descriptor_set_layout,
        ui_vert_spv,
        ui_frag_spv,
    );
    self.ui_pipeline = ui_pl.pipeline;
    self.ui_pipeline_layout = ui_pl.layout;

    // Initialize per-chunk render data list
    self.chunk_renders = std.ArrayList(ChunkRenderData).empty;
    self.current_vp = std.mem.zeroes([4][4]f32);
    self.current_sky_color = .{ 0.53, 0.81, 0.92 };
    self.current_fog_color = .{ 0.60, 0.82, 0.90 };

    // Initialize UI pipeline state
    self.ui_vertex_buffer = .null_handle;
    self.ui_vertex_memory = .null_handle;
    self.ui_vertex_count = 0;
    self.hud_health = 1.0;
    self.hud_hunger = 1.0;
    self.hud_selected_slot = 0.0;

    // Initialize entity/particle draw lists
    self.entity_draw_count = 0;
    self.particle_draw_count = 0;
    self.entity_cube_buffer = .null_handle;
    self.entity_cube_memory = .null_handle;
    self.entity_cube_index_buffer = .null_handle;
    self.entity_cube_index_memory = .null_handle;

    return self;
}

pub fn deinit(self: *Self) void {
    self.waitIdle();
    self.destroySyncObjects();
    self.vkd.destroyCommandPool(self.device, self.command_pool, null);
    self.destroyFramebuffers();
    self.clearChunks();
    self.chunk_renders.deinit(self.allocator);
    self.vkd.destroyPipeline(self.device, self.terrain_pipeline, null);
    self.vkd.destroyPipelineLayout(self.device, self.terrain_pipeline_layout, null);
    // Destroy texture atlas resources
    if (self.atlas_sampler != .null_handle) self.vkd.destroySampler(self.device, self.atlas_sampler, null);
    if (self.atlas_image_view != .null_handle) self.vkd.destroyImageView(self.device, self.atlas_image_view, null);
    if (self.atlas_image != .null_handle) self.vkd.destroyImage(self.device, self.atlas_image, null);
    if (self.atlas_image_memory != .null_handle) self.vkd.freeMemory(self.device, self.atlas_image_memory, null);
    if (self.descriptor_pool != .null_handle) self.vkd.destroyDescriptorPool(self.device, self.descriptor_pool, null);
    if (self.descriptor_set_layout != .null_handle) self.vkd.destroyDescriptorSetLayout(self.device, self.descriptor_set_layout, null);
    self.vkd.destroyPipeline(self.device, self.ui_pipeline, null);
    self.vkd.destroyPipelineLayout(self.device, self.ui_pipeline_layout, null);
    if (self.ui_vertex_buffer != .null_handle) {
        self.vkd.destroyBuffer(self.device, self.ui_vertex_buffer, null);
        self.vkd.freeMemory(self.device, self.ui_vertex_memory, null);
    }
    self.vkd.destroyRenderPass(self.device, self.render_pass, null);
    self.destroyDepthResources();
    self.destroySwapchain();
    self.vki.destroySurfaceKHR(self.instance, self.surface, null);
    self.vkd.destroyDevice(self.device, null);
    self.vki.destroyInstance(self.instance, null);
}

pub fn drawFrame(self: *Self, vp: [4][4]f32, sky_color: [3]f32, fog_color: [3]f32) !void {
    self.current_vp = vp;
    self.current_sky_color = sky_color;
    self.current_fog_color = fog_color;
    const frame = self.current_frame;

    // Wait for previous frame's fence
    const fences_to_wait = [_]vk.Fence{self.in_flight_fences[frame]};
    _ = try self.vkd.waitForFences(
        self.device,
        1,
        &fences_to_wait,
        vk.Bool32.true,
        std.math.maxInt(u64),
    );

    // Acquire next image
    const result = self.vkd.acquireNextImageKHR(
        self.device,
        self.swapchain,
        std.math.maxInt(u64),
        self.image_available_semaphores[frame],
        .null_handle,
    ) catch |err| switch (err) {
        error.OutOfDateKHR => {
            try self.recreateSwapchain();
            return;
        },
        else => return err,
    };
    const image_index = result.image_index;

    const fences_to_reset = [_]vk.Fence{self.in_flight_fences[frame]};
    try self.vkd.resetFences(self.device, 1, &fences_to_reset);

    // Reset and record command buffer
    try self.vkd.resetCommandBuffer(self.command_buffers[frame], .{});
    try self.recordCommandBuffer(self.command_buffers[frame], image_index);

    // Submit
    const wait_semaphores = [_]vk.Semaphore{self.image_available_semaphores[frame]};
    const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
    const cmd_bufs = [_]vk.CommandBuffer{self.command_buffers[frame]};
    const signal_semaphores = [_]vk.Semaphore{self.render_finished_semaphores[frame]};
    const submit_info = [_]vk.SubmitInfo{.{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &wait_semaphores,
        .p_wait_dst_stage_mask = &wait_stages,
        .command_buffer_count = 1,
        .p_command_buffers = &cmd_bufs,
        .signal_semaphore_count = 1,
        .p_signal_semaphores = &signal_semaphores,
    }};
    try self.vkd.queueSubmit(self.graphics_queue, 1, &submit_info, self.in_flight_fences[frame]);

    // Present
    _ = self.vkd.queuePresentKHR(self.present_queue, &vk.PresentInfoKHR{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &.{self.render_finished_semaphores[frame]},
        .swapchain_count = 1,
        .p_swapchains = &.{self.swapchain},
        .p_image_indices = &.{image_index},
    }) catch |err| switch (err) {
        error.OutOfDateKHR => {
            try self.recreateSwapchain();
            return;
        },
        else => return err,
    };

    self.current_frame = (frame + 1) % MAX_FRAMES_IN_FLIGHT;
}

pub fn waitIdle(self: *Self) void {
    self.vkd.deviceWaitIdle(self.device) catch {};
}

pub fn submitEntityDraw(self: *Self, draw: EntityDraw) void {
    if (self.entity_draw_count < 128) {
        self.entity_draws[self.entity_draw_count] = draw;
        self.entity_draw_count += 1;
    }
}

pub fn clearEntityDraws(self: *Self) void {
    self.entity_draw_count = 0;
}

pub fn submitParticleDraw(self: *Self, draw: ParticleDraw) void {
    if (self.particle_draw_count < 256) {
        self.particle_draws[self.particle_draw_count] = draw;
        self.particle_draw_count += 1;
    }
}

pub fn clearParticleDraws(self: *Self) void {
    self.particle_draw_count = 0;
}

pub fn uploadUiVertices(self: *Self, vertices: []const ui_pipeline_mod.UiVertex) !void {
    if (vertices.len == 0) {
        self.ui_vertex_count = 0;
        return;
    }
    // Recreate buffer each frame (simple approach)
    if (self.ui_vertex_buffer != .null_handle) {
        self.vkd.destroyBuffer(self.device, self.ui_vertex_buffer, null);
        self.vkd.freeMemory(self.device, self.ui_vertex_memory, null);
    }
    const buffer_size: vk.DeviceSize = @intCast(vertices.len * @sizeOf(ui_pipeline_mod.UiVertex));
    const buf = try self.createHostBuffer(.{ .vertex_buffer_bit = true }, buffer_size);
    self.ui_vertex_buffer = buf.buffer;
    self.ui_vertex_memory = buf.memory;
    // Map + copy
    const data_ptr = try self.vkd.mapMemory(self.device, self.ui_vertex_memory, 0, buffer_size, .{});
    const dst: [*]ui_pipeline_mod.UiVertex = @ptrCast(@alignCast(data_ptr));
    @memcpy(dst[0..vertices.len], vertices);
    self.vkd.unmapMemory(self.device, self.ui_vertex_memory);
    self.ui_vertex_count = @intCast(vertices.len);
}

// --- Private helpers ---

fn createInstance(self: *Self) !vk.Instance {
    const app_info = vk.ApplicationInfo{
        .p_application_name = "zig-voxel-engine",
        .application_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
        .p_engine_name = "zig-voxel-engine",
        .engine_version = @bitCast(vk.makeApiVersion(0, 0, 1, 0)),
        .api_version = @bitCast(vk.API_VERSION_1_2),
    };

    const glfw_extensions = try zglfw.getRequiredInstanceExtensions();

    // macOS/MoltenVK requires portability enumeration extension
    const portability_ext: [*:0]const u8 = "VK_KHR_portability_enumeration";
    var all_extensions = try self.allocator.alloc([*:0]const u8, glfw_extensions.len + 1);
    defer self.allocator.free(all_extensions);
    for (glfw_extensions, 0..) |ext, i| {
        all_extensions[i] = ext;
    }
    all_extensions[glfw_extensions.len] = portability_ext;

    const create_info = vk.InstanceCreateInfo{
        .p_application_info = &app_info,
        .enabled_extension_count = @intCast(all_extensions.len),
        .pp_enabled_extension_names = @ptrCast(all_extensions.ptr),
        .enabled_layer_count = 0,
        .pp_enabled_layer_names = undefined,
        .flags = .{ .enumerate_portability_bit_khr = true },
    };

    return self.vkb.createInstance(&create_info, null);
}

fn createSurface(self: *Self) !vk.SurfaceKHR {
    var surface: vk.SurfaceKHR = undefined;
    // Call the C function directly to bridge the type difference
    if (glfwCreateWindowSurface(
        @ptrFromInt(@intFromEnum(self.instance)),
        self.window,
        null,
        @ptrCast(&surface),
    ) != 0) return error.SurfaceCreationFailed;
    return surface;
}

extern fn glfwCreateWindowSurface(
    instance: ?*const anyopaque,
    window: *zglfw.Window,
    allocator: ?*const anyopaque,
    surface: *u64,
) c_int;

fn pickPhysicalDevice(self: *Self) !vk.PhysicalDevice {
    var device_count: u32 = 0;
    _ = try self.vki.enumeratePhysicalDevices(self.instance, &device_count, null);

    if (device_count == 0) return error.NoVulkanDevices;

    const devices = try self.allocator.alloc(vk.PhysicalDevice, device_count);
    defer self.allocator.free(devices);

    _ = try self.vki.enumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

    // Pick first suitable device
    for (devices[0..device_count]) |device| {
        if (self.isDeviceSuitable(device)) return device;
    }

    return error.NoSuitableDevice;
}

fn isDeviceSuitable(self: *Self, device: vk.PhysicalDevice) bool {
    const families = self.findQueueFamilies(device) catch return false;
    _ = families;

    // Check for swapchain extension support
    var ext_count: u32 = 0;
    _ = self.vki.enumerateDeviceExtensionProperties(device, null, &ext_count, null) catch return false;

    const extensions = self.allocator.alloc(vk.ExtensionProperties, ext_count) catch return false;
    defer self.allocator.free(extensions);

    _ = self.vki.enumerateDeviceExtensionProperties(device, null, &ext_count, extensions.ptr) catch return false;

    for (extensions[0..ext_count]) |ext| {
        const name: [*:0]const u8 = @ptrCast(&ext.extension_name);
        if (std.mem.eql(u8, std.mem.span(name), vk.extensions.khr_swapchain.name)) return true;
    }

    return false;
}

const QueueFamilyIndices = struct {
    graphics: u32,
    present: u32,
};

fn findQueueFamilies(self: *Self, device: vk.PhysicalDevice) !QueueFamilyIndices {
    var queue_family_count: u32 = 0;
    self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

    const families = try self.allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer self.allocator.free(families);

    self.vki.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, families.ptr);

    var graphics: ?u32 = null;
    var present: ?u32 = null;

    for (families[0..queue_family_count], 0..) |family, i| {
        const idx: u32 = @intCast(i);

        if (family.queue_flags.graphics_bit) {
            graphics = idx;
        }

        if ((self.vki.getPhysicalDeviceSurfaceSupportKHR(device, idx, self.surface) catch vk.Bool32.false) == .true) {
            present = idx;
        }

        if (graphics != null and present != null) break;
    }

    return .{
        .graphics = graphics orelse return error.NoGraphicsQueue,
        .present = present orelse return error.NoPresentQueue,
    };
}

fn createLogicalDevice(self: *Self) !vk.Device {
    const unique_families = if (self.graphics_family == self.present_family)
        &[_]u32{self.graphics_family}
    else
        &[_]u32{ self.graphics_family, self.present_family };

    var queue_create_infos: [2]vk.DeviceQueueCreateInfo = undefined;
    const priority: f32 = 1.0;

    for (unique_families, 0..) |family, i| {
        queue_create_infos[i] = .{
            .queue_family_index = family,
            .queue_count = 1,
            .p_queue_priorities = @ptrCast(&priority),
        };
    }

    const device_extensions = [_][*:0]const u8{
        vk.extensions.khr_swapchain.name,
        "VK_KHR_portability_subset",
    };

    return self.vki.createDevice(self.physical_device, &.{
        .queue_create_info_count = @intCast(unique_families.len),
        .p_queue_create_infos = &queue_create_infos,
        .enabled_extension_count = device_extensions.len,
        .pp_enabled_extension_names = &device_extensions,
    }, null);
}

fn createSwapchain(self: *Self) !void {
    const capabilities = try self.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(self.physical_device, self.surface);

    // Choose format
    var format_count: u32 = 0;
    _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(self.physical_device, self.surface, &format_count, null);
    const formats = try self.allocator.alloc(vk.SurfaceFormatKHR, format_count);
    defer self.allocator.free(formats);
    _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(self.physical_device, self.surface, &format_count, formats.ptr);

    const surface_format = chooseSurfaceFormat(formats[0..format_count]);
    self.swapchain_format = surface_format.format;

    // Choose present mode
    var present_mode_count: u32 = 0;
    _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(self.physical_device, self.surface, &present_mode_count, null);
    const present_modes = try self.allocator.alloc(vk.PresentModeKHR, present_mode_count);
    defer self.allocator.free(present_modes);
    _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(self.physical_device, self.surface, &present_mode_count, present_modes.ptr);
    const present_mode = choosePresentMode(present_modes[0..present_mode_count]);

    // Choose extent
    self.swapchain_extent = chooseExtent(capabilities, self.window);

    // Image count
    var image_count = capabilities.min_image_count + 1;
    if (capabilities.max_image_count > 0 and image_count > capabilities.max_image_count) {
        image_count = capabilities.max_image_count;
    }

    const sharing_mode: vk.SharingMode = if (self.graphics_family != self.present_family) .concurrent else .exclusive;
    const family_indices = [_]u32{ self.graphics_family, self.present_family };

    self.swapchain = try self.vkd.createSwapchainKHR(self.device, &.{
        .surface = self.surface,
        .min_image_count = image_count,
        .image_format = surface_format.format,
        .image_color_space = surface_format.color_space,
        .image_extent = self.swapchain_extent,
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true },
        .image_sharing_mode = sharing_mode,
        .queue_family_index_count = if (sharing_mode == .concurrent) 2 else 0,
        .p_queue_family_indices = &family_indices,
        .pre_transform = capabilities.current_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = present_mode,
        .clipped = vk.Bool32.true,
        .old_swapchain = .null_handle,
    }, null);

    // Get swapchain images
    var actual_image_count: u32 = 0;
    _ = try self.vkd.getSwapchainImagesKHR(self.device, self.swapchain, &actual_image_count, null);
    self.swapchain_images = try self.allocator.alloc(vk.Image, actual_image_count);
    _ = try self.vkd.getSwapchainImagesKHR(self.device, self.swapchain, &actual_image_count, self.swapchain_images.ptr);

    // Create image views
    self.swapchain_image_views = try self.allocator.alloc(vk.ImageView, actual_image_count);
    for (self.swapchain_images, 0..) |image, i| {
        self.swapchain_image_views[i] = try self.vkd.createImageView(self.device, &.{
            .image = image,
            .view_type = .@"2d",
            .format = self.swapchain_format,
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        }, null);
    }
}

fn destroySwapchain(self: *Self) void {
    for (self.swapchain_image_views) |view| {
        self.vkd.destroyImageView(self.device, view, null);
    }
    self.allocator.free(self.swapchain_image_views);
    self.allocator.free(self.swapchain_images);
    self.vkd.destroySwapchainKHR(self.device, self.swapchain, null);
}

fn createDepthResources(self: *Self) !void {
    self.depth_image = try self.vkd.createImage(self.device, &vk.ImageCreateInfo{
        .image_type = .@"2d",
        .format = .d32_sfloat,
        .extent = .{
            .width = self.swapchain_extent.width,
            .height = self.swapchain_extent.height,
            .depth = 1,
        },
        .mip_levels = 1,
        .array_layers = 1,
        .samples = .{ .@"1_bit" = true },
        .tiling = .optimal,
        .usage = .{ .depth_stencil_attachment_bit = true },
        .sharing_mode = .exclusive,
        .queue_family_index_count = 0,
        .p_queue_family_indices = undefined,
        .initial_layout = .undefined,
    }, null);

    const mem_reqs = self.vkd.getImageMemoryRequirements(self.device, self.depth_image);
    const mem_type = try self.findMemoryType(mem_reqs.memory_type_bits, .{
        .device_local_bit = true,
    });

    self.depth_image_memory = try self.vkd.allocateMemory(self.device, &.{
        .allocation_size = mem_reqs.size,
        .memory_type_index = mem_type,
    }, null);

    try self.vkd.bindImageMemory(self.device, self.depth_image, self.depth_image_memory, 0);

    self.depth_image_view = try self.vkd.createImageView(self.device, &.{
        .image = self.depth_image,
        .view_type = .@"2d",
        .format = .d32_sfloat,
        .components = .{
            .r = .identity,
            .g = .identity,
            .b = .identity,
            .a = .identity,
        },
        .subresource_range = .{
            .aspect_mask = .{ .depth_bit = true },
            .base_mip_level = 0,
            .level_count = 1,
            .base_array_layer = 0,
            .layer_count = 1,
        },
    }, null);
}

fn destroyDepthResources(self: *Self) void {
    self.vkd.destroyImageView(self.device, self.depth_image_view, null);
    self.vkd.freeMemory(self.device, self.depth_image_memory, null);
    self.vkd.destroyImage(self.device, self.depth_image, null);
}

fn createRenderPass(self: *Self) !vk.RenderPass {
    const color_attachment = vk.AttachmentDescription{
        .format = self.swapchain_format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };

    const depth_attachment = vk.AttachmentDescription{
        .format = .d32_sfloat,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .dont_care,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .depth_stencil_attachment_optimal,
    };

    const attachments = [_]vk.AttachmentDescription{ color_attachment, depth_attachment };

    const color_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };

    const depth_ref = vk.AttachmentReference{
        .attachment = 1,
        .layout = .depth_stencil_attachment_optimal,
    };

    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = &.{color_ref},
        .p_depth_stencil_attachment = &depth_ref,
    };

    const dependency = vk.SubpassDependency{
        .src_subpass = vk.SUBPASS_EXTERNAL,
        .dst_subpass = 0,
        .src_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
        .src_access_mask = .{},
        .dst_stage_mask = .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true },
        .dst_access_mask = .{ .color_attachment_write_bit = true, .depth_stencil_attachment_write_bit = true },
    };

    return self.vkd.createRenderPass(self.device, &.{
        .attachment_count = attachments.len,
        .p_attachments = &attachments,
        .subpass_count = 1,
        .p_subpasses = &.{subpass},
        .dependency_count = 1,
        .p_dependencies = &.{dependency},
    }, null);
}

fn createFramebuffers(self: *Self) !void {
    self.framebuffers = try self.allocator.alloc(vk.Framebuffer, self.swapchain_image_views.len);
    for (self.swapchain_image_views, 0..) |view, i| {
        const fb_attachments = [_]vk.ImageView{ view, self.depth_image_view };
        self.framebuffers[i] = try self.vkd.createFramebuffer(self.device, &.{
            .render_pass = self.render_pass,
            .attachment_count = fb_attachments.len,
            .p_attachments = &fb_attachments,
            .width = self.swapchain_extent.width,
            .height = self.swapchain_extent.height,
            .layers = 1,
        }, null);
    }
}

fn destroyFramebuffers(self: *Self) void {
    for (self.framebuffers) |fb| {
        self.vkd.destroyFramebuffer(self.device, fb, null);
    }
    self.allocator.free(self.framebuffers);
}

fn createCommandResources(self: *Self) !void {
    self.command_pool = try self.vkd.createCommandPool(self.device, &.{
        .queue_family_index = self.graphics_family,
        .flags = .{ .reset_command_buffer_bit = true },
    }, null);

    var buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer = undefined;
    try self.vkd.allocateCommandBuffers(self.device, &.{
        .command_pool = self.command_pool,
        .level = .primary,
        .command_buffer_count = MAX_FRAMES_IN_FLIGHT,
    }, &buffers);
    self.command_buffers = buffers;
}

fn createSyncObjects(self: *Self) !void {
    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        self.image_available_semaphores[i] = try self.vkd.createSemaphore(self.device, &.{}, null);
        self.render_finished_semaphores[i] = try self.vkd.createSemaphore(self.device, &.{}, null);
        self.in_flight_fences[i] = try self.vkd.createFence(self.device, &.{
            .flags = .{ .signaled_bit = true },
        }, null);
    }
}

fn destroySyncObjects(self: *Self) void {
    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        self.vkd.destroySemaphore(self.device, self.image_available_semaphores[i], null);
        self.vkd.destroySemaphore(self.device, self.render_finished_semaphores[i], null);
        self.vkd.destroyFence(self.device, self.in_flight_fences[i], null);
    }
}

fn recordCommandBuffer(self: *Self, cmd: vk.CommandBuffer, image_index: u32) !void {
    try self.vkd.beginCommandBuffer(cmd, &.{});

    // Clear values: color (dynamic sky color from day/night cycle) and depth
    const clear_values = [_]vk.ClearValue{
        .{ .color = .{ .float_32 = .{ self.current_sky_color[0], self.current_sky_color[1], self.current_sky_color[2], 1.0 } } },
        .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0 } },
    };

    self.vkd.cmdBeginRenderPass(cmd, &.{
        .render_pass = self.render_pass,
        .framebuffer = self.framebuffers[image_index],
        .render_area = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        },
        .clear_value_count = clear_values.len,
        .p_clear_values = &clear_values,
    }, .@"inline");

    if (self.chunk_renders.items.len > 0) {
        self.vkd.cmdBindPipeline(cmd, .graphics, self.terrain_pipeline);

        // Bind texture atlas descriptor set
        const desc_sets = [_]vk.DescriptorSet{self.descriptor_set};
        self.vkd.cmdBindDescriptorSets(cmd, .graphics, self.terrain_pipeline_layout, 0, 1, &desc_sets, 0, null);

        // Dynamic viewport
        self.vkd.cmdSetViewport(cmd, 0, 1, &.{vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(self.swapchain_extent.width),
            .height = @floatFromInt(self.swapchain_extent.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        }});

        // Dynamic scissor
        self.vkd.cmdSetScissor(cmd, 0, 1, &.{vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        }});

        for (self.chunk_renders.items) |chunk_data| {
            // Bind this chunk's vertex buffer
            const offsets = [_]vk.DeviceSize{0};
            const vb = [_]vk.Buffer{chunk_data.vertex_buffer};
            self.vkd.cmdBindVertexBuffers(cmd, 0, 1, &vb, &offsets);

            // Bind this chunk's index buffer
            self.vkd.cmdBindIndexBuffer(cmd, chunk_data.index_buffer, 0, .uint32);

            // Compute model matrix (translation by world offset)
            const model = translationMatrix(
                @floatFromInt(chunk_data.world_x),
                @floatFromInt(chunk_data.world_y),
                @floatFromInt(chunk_data.world_z),
            );

            // MVP = model * VP (row-vector convention: v * model * VP)
            const mvp = mat4Mul(model, self.current_vp);
            const push = pipeline_mod.PushConstants{
                .mvp = mvp,
                .fog_color = self.current_fog_color,
                .fog_start = 60.0,
                .fog_end = 80.0,
                .health_fraction = self.hud_health,
                .hunger_fraction = self.hud_hunger,
                .selected_slot = self.hud_selected_slot,
            };
            self.vkd.cmdPushConstants(
                cmd,
                self.terrain_pipeline_layout,
                .{ .vertex_bit = true, .fragment_bit = true },
                0,
                @sizeOf(pipeline_mod.PushConstants),
                @ptrCast(&push),
            );

            // Draw indexed
            self.vkd.cmdDrawIndexed(cmd, chunk_data.index_count, 1, 0, 0, 0);
        }
    }

    // Draw entities as colored cubes using the same terrain pipeline
    // Each entity reuses the first chunk's vertex buffer but with a per-entity model matrix
    if (self.entity_draw_count > 0 and self.chunk_renders.items.len > 0) {
        // Reuse the first chunk's vertex/index buffers as a source of cube geometry
        // (a single block at origin is a 1x1x1 cube — we scale/translate via model matrix)
        const first_chunk = self.chunk_renders.items[0];
        const offsets_e = [_]vk.DeviceSize{0};
        const vb_e = [_]vk.Buffer{first_chunk.vertex_buffer};
        self.vkd.cmdBindVertexBuffers(cmd, 0, 1, &vb_e, &offsets_e);
        self.vkd.cmdBindIndexBuffer(cmd, first_chunk.index_buffer, 0, .uint32);

        var ei: u32 = 0;
        while (ei < self.entity_draw_count) : (ei += 1) {
            const ed = self.entity_draws[ei];
            // Model matrix: translate to entity position
            const model = translationMatrix(ed.x, ed.y, ed.z);
            const mvp_e = mat4Mul(model, self.current_vp);
            const push_e = pipeline_mod.PushConstants{
                .mvp = mvp_e,
                .fog_color = self.current_fog_color,
                .fog_start = 60.0,
                .fog_end = 80.0,
            };
            self.vkd.cmdPushConstants(
                cmd,
                self.terrain_pipeline_layout,
                .{ .vertex_bit = true, .fragment_bit = true },
                0,
                @sizeOf(pipeline_mod.PushConstants),
                @ptrCast(&push_e),
            );
            // Draw a small portion of the first chunk's geometry (first 36 indices = 6 faces of 1 block)
            const indices_to_draw: u32 = @min(36, first_chunk.index_count);
            self.vkd.cmdDrawIndexed(cmd, indices_to_draw, 1, 0, 0, 0);
        }
    }

    // Draw particles as tiny cubes (block break effects)
    if (self.particle_draw_count > 0 and self.chunk_renders.items.len > 0) {
        const first_chunk_p = self.chunk_renders.items[0];
        const offsets_p = [_]vk.DeviceSize{0};
        const vb_p = [_]vk.Buffer{first_chunk_p.vertex_buffer};
        self.vkd.cmdBindVertexBuffers(cmd, 0, 1, &vb_p, &offsets_p);
        self.vkd.cmdBindIndexBuffer(cmd, first_chunk_p.index_buffer, 0, .uint32);

        var pi: u32 = 0;
        while (pi < self.particle_draw_count) : (pi += 1) {
            const pd = self.particle_draws[pi];
            // Scale particle down (0.1 block size) via model matrix offset
            const model_p = translationMatrix(pd.x, pd.y, pd.z);
            const mvp_p = mat4Mul(model_p, self.current_vp);
            const push_p = pipeline_mod.PushConstants{
                .mvp = mvp_p,
                .fog_color = self.current_fog_color,
                .fog_start = 60.0,
                .fog_end = 80.0,
            };
            self.vkd.cmdPushConstants(
                cmd,
                self.terrain_pipeline_layout,
                .{ .vertex_bit = true, .fragment_bit = true },
                0,
                @sizeOf(pipeline_mod.PushConstants),
                @ptrCast(&push_p),
            );
            // Draw minimal geometry for particle (6 indices = 1 face)
            const p_indices: u32 = @min(6, first_chunk_p.index_count);
            self.vkd.cmdDrawIndexed(cmd, p_indices, 1, 0, 0, 0);
        }
    }

    // === UI Overlay Pass (same render pass, different pipeline) ===
    if (self.ui_vertex_count > 0 and self.ui_vertex_buffer != .null_handle) {
        self.vkd.cmdBindPipeline(cmd, .graphics, self.ui_pipeline);

        // Same viewport/scissor
        self.vkd.cmdSetViewport(cmd, 0, 1, &.{vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(self.swapchain_extent.width),
            .height = @floatFromInt(self.swapchain_extent.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        }});
        self.vkd.cmdSetScissor(cmd, 0, 1, &.{vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        }});

        // Push screen dimensions for NDC conversion
        const ui_push = ui_pipeline_mod.UiPushConstants{
            .screen_width = @floatFromInt(self.swapchain_extent.width),
            .screen_height = @floatFromInt(self.swapchain_extent.height),
        };
        self.vkd.cmdPushConstants(
            cmd,
            self.ui_pipeline_layout,
            .{ .vertex_bit = true },
            0,
            @sizeOf(ui_pipeline_mod.UiPushConstants),
            @ptrCast(&ui_push),
        );

        // Bind UI vertex buffer and draw
        const ui_desc_sets = [_]vk.DescriptorSet{self.descriptor_set};
        self.vkd.cmdBindDescriptorSets(cmd, .graphics, self.ui_pipeline_layout, 0, 1, &ui_desc_sets, 0, null);
        const ui_offsets = [_]vk.DeviceSize{0};
        const ui_bufs = [_]vk.Buffer{self.ui_vertex_buffer};
        self.vkd.cmdBindVertexBuffers(cmd, 0, 1, &ui_bufs, &ui_offsets);
        self.vkd.cmdDraw(cmd, self.ui_vertex_count, 1, 0, 0);
    }

    self.vkd.cmdEndRenderPass(cmd);

    try self.vkd.endCommandBuffer(cmd);
}

fn recreateSwapchain(self: *Self) !void {
    self.waitIdle();
    self.destroyFramebuffers();
    self.destroyDepthResources();
    self.destroySwapchain();
    try self.createSwapchain();
    try self.createDepthResources();
    try self.createFramebuffers();
}

pub fn uploadChunk(self: *Self, vertices: []const mesh_indexed.Vertex, indices: []const u32, world_x: i32, world_y: i32, world_z: i32) !void {
    if (vertices.len == 0 or indices.len == 0) return;

    // Create vertex buffer
    const vb = try self.createHostBuffer(
        .{ .vertex_buffer_bit = true },
        @intCast(vertices.len * @sizeOf(mesh_indexed.Vertex)),
    );

    // If index buffer creation fails, clean up vertex buffer
    errdefer {
        self.vkd.destroyBuffer(self.device, vb.buffer, null);
        self.vkd.freeMemory(self.device, vb.memory, null);
    }

    const vb_data_ptr = try self.vkd.mapMemory(self.device, vb.memory, 0, vb.size, .{});
    const vb_dst: [*]mesh_indexed.Vertex = @ptrCast(@alignCast(vb_data_ptr));
    @memcpy(vb_dst[0..vertices.len], vertices);
    self.vkd.unmapMemory(self.device, vb.memory);

    // Create index buffer
    const ib = try self.createHostBuffer(
        .{ .index_buffer_bit = true },
        @intCast(indices.len * @sizeOf(u32)),
    );

    const ib_data_ptr = try self.vkd.mapMemory(self.device, ib.memory, 0, ib.size, .{});
    const ib_dst: [*]u32 = @ptrCast(@alignCast(ib_data_ptr));
    @memcpy(ib_dst[0..indices.len], indices);
    self.vkd.unmapMemory(self.device, ib.memory);

    try self.chunk_renders.append(self.allocator, .{
        .vertex_buffer = vb.buffer,
        .vertex_buffer_memory = vb.memory,
        .vertex_count = @intCast(vertices.len),
        .index_buffer = ib.buffer,
        .index_buffer_memory = ib.memory,
        .index_count = @intCast(indices.len),
        .world_x = world_x,
        .world_y = world_y,
        .world_z = world_z,
    });
}

pub fn clearChunks(self: *Self) void {
    for (self.chunk_renders.items) |chunk_data| {
        self.vkd.destroyBuffer(self.device, chunk_data.vertex_buffer, null);
        self.vkd.freeMemory(self.device, chunk_data.vertex_buffer_memory, null);
        self.vkd.destroyBuffer(self.device, chunk_data.index_buffer, null);
        self.vkd.freeMemory(self.device, chunk_data.index_buffer_memory, null);
    }
    self.chunk_renders.clearRetainingCapacity();
}

/// Remove the render data for the chunk at the given world x/z position.
/// Destroys the GPU vertex and index buffers to avoid memory leaks.
pub fn removeChunkRender(self: *Self, world_x: i32, world_z: i32) void {
    var i: usize = 0;
    while (i < self.chunk_renders.items.len) {
        const cr = self.chunk_renders.items[i];
        if (cr.world_x == world_x and cr.world_z == world_z) {
            self.vkd.destroyBuffer(self.device, cr.vertex_buffer, null);
            self.vkd.freeMemory(self.device, cr.vertex_buffer_memory, null);
            self.vkd.destroyBuffer(self.device, cr.index_buffer, null);
            self.vkd.freeMemory(self.device, cr.index_buffer_memory, null);
            _ = self.chunk_renders.swapRemove(i);
            return;
        }
        i += 1;
    }
}

fn translationMatrix(tx: f32, ty: f32, tz: f32) [4][4]f32 {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ tx, ty, tz, 1 },
    };
}

fn mat4Mul(a: [4][4]f32, b: [4][4]f32) [4][4]f32 {
    var result: [4][4]f32 = undefined;
    for (0..4) |row| {
        for (0..4) |col| {
            var sum: f32 = 0;
            for (0..4) |k| {
                sum += a[row][k] * b[k][col];
            }
            result[row][col] = sum;
        }
    }
    return result;
}

fn createTextureAtlas(self: *Self) !void {
    const atlas_w: u32 = texture_atlas.ATLAS_SIZE;
    const atlas_h: u32 = texture_atlas.ATLAS_SIZE;
    const pixel_count = atlas_w * atlas_h;
    const image_size: vk.DeviceSize = pixel_count * 4; // RGBA

    // Generate atlas pixel data on CPU
    const pixels = try self.allocator.alloc(texture_atlas.Pixel, pixel_count);
    defer self.allocator.free(pixels);
    const gen_pixels = try texture_atlas.generateAtlas(self.allocator);
    defer self.allocator.free(gen_pixels);
    @memcpy(pixels, gen_pixels);

    // Create staging buffer
    const staging = try self.createHostBuffer(.{ .transfer_src_bit = true }, image_size);
    defer self.vkd.destroyBuffer(self.device, staging.buffer, null);
    defer self.vkd.freeMemory(self.device, staging.memory, null);

    // Copy pixel data to staging buffer
    const data_ptr = try self.vkd.mapMemory(self.device, staging.memory, 0, image_size, .{});
    const dst: [*]u8 = @ptrCast(data_ptr);
    const src: [*]const u8 = @ptrCast(pixels.ptr);
    @memcpy(dst[0..@intCast(image_size)], src[0..@intCast(image_size)]);
    self.vkd.unmapMemory(self.device, staging.memory);

    // Create VkImage
    self.atlas_image = try self.vkd.createImage(self.device, &.{
        .image_type = .@"2d",
        .format = .r8g8b8a8_unorm,
        .extent = .{ .width = atlas_w, .height = atlas_h, .depth = 1 },
        .mip_levels = 1,
        .array_layers = 1,
        .samples = .{ .@"1_bit" = true },
        .tiling = .optimal,
        .usage = .{ .transfer_dst_bit = true, .sampled_bit = true },
        .sharing_mode = .exclusive,
        .initial_layout = .undefined,
    }, null);

    // Allocate device-local memory for image
    const img_mem_reqs = self.vkd.getImageMemoryRequirements(self.device, self.atlas_image);
    const img_mem_type = try self.findMemoryType(img_mem_reqs.memory_type_bits, .{ .device_local_bit = true });
    self.atlas_image_memory = try self.vkd.allocateMemory(self.device, &.{
        .allocation_size = img_mem_reqs.size,
        .memory_type_index = img_mem_type,
    }, null);
    try self.vkd.bindImageMemory(self.device, self.atlas_image, self.atlas_image_memory, 0);

    // Transition, copy, transition (using a one-shot command buffer)
    const cmd = try self.beginSingleTimeCommands();

    // Transition: undefined -> transfer_dst
    self.vkd.cmdPipelineBarrier(cmd, .{ .top_of_pipe_bit = true }, .{ .transfer_bit = true }, .{}, 0, null, 0, null, 1, &[_]vk.ImageMemoryBarrier{.{
        .src_access_mask = .{},
        .dst_access_mask = .{ .transfer_write_bit = true },
        .old_layout = .undefined,
        .new_layout = .transfer_dst_optimal,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = self.atlas_image,
        .subresource_range = .{ .aspect_mask = .{ .color_bit = true }, .base_mip_level = 0, .level_count = 1, .base_array_layer = 0, .layer_count = 1 },
    }});

    // Copy staging buffer -> image
    self.vkd.cmdCopyBufferToImage(cmd, staging.buffer, self.atlas_image, .transfer_dst_optimal, 1, &[_]vk.BufferImageCopy{.{
        .buffer_offset = 0,
        .buffer_row_length = 0,
        .buffer_image_height = 0,
        .image_subresource = .{ .aspect_mask = .{ .color_bit = true }, .mip_level = 0, .base_array_layer = 0, .layer_count = 1 },
        .image_offset = .{ .x = 0, .y = 0, .z = 0 },
        .image_extent = .{ .width = atlas_w, .height = atlas_h, .depth = 1 },
    }});

    // Transition: transfer_dst -> shader_read_only
    self.vkd.cmdPipelineBarrier(cmd, .{ .transfer_bit = true }, .{ .fragment_shader_bit = true }, .{}, 0, null, 0, null, 1, &[_]vk.ImageMemoryBarrier{.{
        .src_access_mask = .{ .transfer_write_bit = true },
        .dst_access_mask = .{ .shader_read_bit = true },
        .old_layout = .transfer_dst_optimal,
        .new_layout = .shader_read_only_optimal,
        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
        .image = self.atlas_image,
        .subresource_range = .{ .aspect_mask = .{ .color_bit = true }, .base_mip_level = 0, .level_count = 1, .base_array_layer = 0, .layer_count = 1 },
    }});

    try self.endSingleTimeCommands(cmd);

    // Create image view
    self.atlas_image_view = try self.vkd.createImageView(self.device, &.{
        .image = self.atlas_image,
        .view_type = .@"2d",
        .format = .r8g8b8a8_unorm,
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        .subresource_range = .{ .aspect_mask = .{ .color_bit = true }, .base_mip_level = 0, .level_count = 1, .base_array_layer = 0, .layer_count = 1 },
    }, null);

    // Create sampler with NEAREST filtering for pixel-art look
    self.atlas_sampler = try self.vkd.createSampler(self.device, &.{
        .mag_filter = .nearest,
        .min_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .mip_lod_bias = 0,
        .anisotropy_enable = vk.Bool32.false,
        .max_anisotropy = 1,
        .compare_enable = vk.Bool32.false,
        .compare_op = .always,
        .min_lod = 0,
        .max_lod = 0,
        .border_color = .float_opaque_black,
        .unnormalized_coordinates = vk.Bool32.false,
    }, null);

    // Create descriptor set layout
    const bindings = [_]vk.DescriptorSetLayoutBinding{.{
        .binding = 0,
        .descriptor_type = .combined_image_sampler,
        .descriptor_count = 1,
        .stage_flags = .{ .fragment_bit = true },
    }};
    self.descriptor_set_layout = try self.vkd.createDescriptorSetLayout(self.device, &.{
        .binding_count = bindings.len,
        .p_bindings = &bindings,
    }, null);

    // Create descriptor pool
    const pool_sizes = [_]vk.DescriptorPoolSize{.{
        .type = .combined_image_sampler,
        .descriptor_count = 1,
    }};
    self.descriptor_pool = try self.vkd.createDescriptorPool(self.device, &.{
        .max_sets = 1,
        .pool_size_count = pool_sizes.len,
        .p_pool_sizes = &pool_sizes,
    }, null);

    // Allocate descriptor set
    const layouts = [_]vk.DescriptorSetLayout{self.descriptor_set_layout};
    var sets: [1]vk.DescriptorSet = undefined;
    try self.vkd.allocateDescriptorSets(self.device, &.{
        .descriptor_pool = self.descriptor_pool,
        .descriptor_set_count = 1,
        .p_set_layouts = &layouts,
    }, &sets);
    self.descriptor_set = sets[0];

    // Write descriptor set
    const image_info = [_]vk.DescriptorImageInfo{.{
        .sampler = self.atlas_sampler,
        .image_view = self.atlas_image_view,
        .image_layout = .shader_read_only_optimal,
    }};
    self.vkd.updateDescriptorSets(self.device, 1, &[_]vk.WriteDescriptorSet{.{
        .dst_set = self.descriptor_set,
        .dst_binding = 0,
        .dst_array_element = 0,
        .descriptor_count = 1,
        .descriptor_type = .combined_image_sampler,
        .p_image_info = &image_info,
        .p_buffer_info = &[_]vk.DescriptorBufferInfo{},
        .p_texel_buffer_view = &[_]vk.BufferView{},
    }}, 0, null);
}

fn beginSingleTimeCommands(self: *Self) !vk.CommandBuffer {
    var bufs: [1]vk.CommandBuffer = undefined;
    try self.vkd.allocateCommandBuffers(self.device, &.{
        .command_pool = self.command_pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, &bufs);
    try self.vkd.beginCommandBuffer(bufs[0], &.{ .flags = .{ .one_time_submit_bit = true } });
    return bufs[0];
}

fn endSingleTimeCommands(self: *Self, cmd: vk.CommandBuffer) !void {
    try self.vkd.endCommandBuffer(cmd);
    const cmds = [_]vk.CommandBuffer{cmd};
    const submit = [_]vk.SubmitInfo{.{
        .command_buffer_count = 1,
        .p_command_buffers = &cmds,
    }};
    try self.vkd.queueSubmit(self.graphics_queue, 1, &submit, .null_handle);
    self.vkd.queueWaitIdle(self.graphics_queue) catch {};
    self.vkd.freeCommandBuffers(self.device, self.command_pool, 1, &cmds);
}

const HostBuffer = struct {
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    size: vk.DeviceSize,
};

fn createHostBuffer(self: *Self, usage: vk.BufferUsageFlags, size: vk.DeviceSize) !HostBuffer {
    const buffer = try self.vkd.createBuffer(self.device, &.{
        .size = size,
        .usage = usage,
        .sharing_mode = .exclusive,
    }, null);
    errdefer self.vkd.destroyBuffer(self.device, buffer, null);

    const mem_reqs = self.vkd.getBufferMemoryRequirements(self.device, buffer);
    const mem_type = try self.findMemoryType(mem_reqs.memory_type_bits, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    });

    const memory = try self.vkd.allocateMemory(self.device, &.{
        .allocation_size = mem_reqs.size,
        .memory_type_index = mem_type,
    }, null);
    errdefer self.vkd.freeMemory(self.device, memory, null);

    try self.vkd.bindBufferMemory(self.device, buffer, memory, 0);

    return .{ .buffer = buffer, .memory = memory, .size = size };
}

fn findMemoryType(self: *Self, type_filter: u32, properties: vk.MemoryPropertyFlags) !u32 {
    const mem_properties = self.vki.getPhysicalDeviceMemoryProperties(self.physical_device);

    for (0..mem_properties.memory_type_count) |i| {
        const idx: u5 = @intCast(i);
        if ((type_filter & (@as(u32, 1) << idx)) != 0) {
            const flags = mem_properties.memory_types[i].property_flags;
            if ((@as(u32, @bitCast(flags)) & @as(u32, @bitCast(properties))) == @as(u32, @bitCast(properties))) {
                return @intCast(i);
            }
        }
    }

    return error.NoSuitableMemoryType;
}

// --- Swapchain choice helpers ---

fn chooseSurfaceFormat(formats: []const vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
    for (formats) |format| {
        if (format.format == .b8g8r8a8_srgb and format.color_space == .srgb_nonlinear_khr) {
            return format;
        }
    }
    return formats[0];
}

fn choosePresentMode(modes: []const vk.PresentModeKHR) vk.PresentModeKHR {
    for (modes) |mode| {
        if (mode == .mailbox_khr) return mode;
    }
    return .fifo_khr;
}

fn chooseExtent(capabilities: vk.SurfaceCapabilitiesKHR, window: *zglfw.Window) vk.Extent2D {
    if (capabilities.current_extent.width != std.math.maxInt(u32)) {
        return capabilities.current_extent;
    }

    const fb_size = window.getFramebufferSize();
    return .{
        .width = std.math.clamp(
            @as(u32, @intCast(fb_size[0])),
            capabilities.min_image_extent.width,
            capabilities.max_image_extent.width,
        ),
        .height = std.math.clamp(
            @as(u32, @intCast(fb_size[1])),
            capabilities.min_image_extent.height,
            capabilities.max_image_extent.height,
        ),
    };
}

/// Bridge between vulkan-zig's Instance type (enum(usize)) and zglfw's
/// getInstanceProcAddress (expects ?*const anyopaque). Needed because the
/// two libraries define vk.Instance differently.
fn getInstanceProcAddr(instance: vk.Instance, procname: [*:0]const u8) ?vk.PfnVoidFunction {
    return zglfw.getInstanceProcAddress(@ptrFromInt(@intFromEnum(instance)), procname);
}
