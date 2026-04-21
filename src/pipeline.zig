/// Vulkan graphics pipeline for terrain rendering.
const std = @import("std");
const vk = @import("vulkan");

pub const PushConstants = extern struct {
    mvp: [4][4]f32,
    fog_color: [3]f32,
    fog_start: f32,
    fog_end: f32,
    health_fraction: f32 = 0.0,
    hunger_fraction: f32 = 0.0,
    selected_slot: f32 = 0.0,
};

pub fn create(
    device: vk.Device,
    vkd: anytype,
    render_pass: vk.RenderPass,
    vert_spv: []align(4) const u8,
    frag_spv: []align(4) const u8,
    descriptor_set_layout: vk.DescriptorSetLayout,
) !struct { pipeline: vk.Pipeline, layout: vk.PipelineLayout } {
    const vert_module = try vkd.createShaderModule(device, &.{
        .code_size = vert_spv.len,
        .p_code = @ptrCast(vert_spv.ptr),
    }, null);
    defer vkd.destroyShaderModule(device, vert_module, null);

    const frag_module = try vkd.createShaderModule(device, &.{
        .code_size = frag_spv.len,
        .p_code = @ptrCast(frag_spv.ptr),
    }, null);
    defer vkd.destroyShaderModule(device, frag_module, null);

    const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
        .{ .stage = .{ .vertex_bit = true }, .module = vert_module, .p_name = "main" },
        .{ .stage = .{ .fragment_bit = true }, .module = frag_module, .p_name = "main" },
    };

    // Two-attribute vertex: pos_data (u32) + tex_data (u32) = 8 bytes stride
    const binding_desc = [_]vk.VertexInputBindingDescription{.{
        .binding = 0,
        .stride = 8,
        .input_rate = .vertex,
    }};

    const attr_desc = [_]vk.VertexInputAttributeDescription{
        .{ .binding = 0, .location = 0, .format = .r32_uint, .offset = 0 },
        .{ .binding = 0, .location = 1, .format = .r32_uint, .offset = 4 },
    };

    const vertex_input = vk.PipelineVertexInputStateCreateInfo{
        .vertex_binding_description_count = binding_desc.len,
        .p_vertex_binding_descriptions = &binding_desc,
        .vertex_attribute_description_count = attr_desc.len,
        .p_vertex_attribute_descriptions = &attr_desc,
    };

    const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
        .topology = .triangle_list,
        .primitive_restart_enable = vk.Bool32.false,
    };

    const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };
    const dynamic_state = vk.PipelineDynamicStateCreateInfo{
        .dynamic_state_count = dynamic_states.len,
        .p_dynamic_states = &dynamic_states,
    };

    const viewport_state = vk.PipelineViewportStateCreateInfo{
        .viewport_count = 1,
        .scissor_count = 1,
    };

    const rasterizer = vk.PipelineRasterizationStateCreateInfo{
        .depth_clamp_enable = vk.Bool32.false,
        .rasterizer_discard_enable = vk.Bool32.false,
        .polygon_mode = .fill,
        .line_width = 1.0,
        .cull_mode = .{ .back_bit = true },
        .front_face = .counter_clockwise,
        .depth_bias_enable = vk.Bool32.false,
        .depth_bias_constant_factor = 0.0,
        .depth_bias_clamp = 0.0,
        .depth_bias_slope_factor = 0.0,
    };

    const multisampling = vk.PipelineMultisampleStateCreateInfo{
        .sample_shading_enable = vk.Bool32.false,
        .rasterization_samples = .{ .@"1_bit" = true },
        .min_sample_shading = 1.0,
        .alpha_to_coverage_enable = vk.Bool32.false,
        .alpha_to_one_enable = vk.Bool32.false,
    };

    const blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
        .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        .blend_enable = vk.Bool32.false,
        .src_color_blend_factor = .one,
        .dst_color_blend_factor = .zero,
        .color_blend_op = .add,
        .src_alpha_blend_factor = .one,
        .dst_alpha_blend_factor = .zero,
        .alpha_blend_op = .add,
    }};

    const color_blending = vk.PipelineColorBlendStateCreateInfo{
        .logic_op_enable = vk.Bool32.false,
        .logic_op = .copy,
        .attachment_count = blend_attachment.len,
        .p_attachments = &blend_attachment,
        .blend_constants = .{ 0.0, 0.0, 0.0, 0.0 },
    };

    const push_range = [_]vk.PushConstantRange{.{
        .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
        .offset = 0,
        .size = @sizeOf(PushConstants),
    }};

    const set_layouts = [_]vk.DescriptorSetLayout{descriptor_set_layout};
    const layout = try vkd.createPipelineLayout(device, &.{
        .set_layout_count = set_layouts.len,
        .p_set_layouts = &set_layouts,
        .push_constant_range_count = push_range.len,
        .p_push_constant_ranges = &push_range,
    }, null);

    var pipelines: [1]vk.Pipeline = undefined;
    _ = try vkd.createGraphicsPipelines(
        device,
        .null_handle,
        1,
        &[_]vk.GraphicsPipelineCreateInfo{.{
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = &vk.PipelineDepthStencilStateCreateInfo{
                .depth_test_enable = vk.Bool32.true,
                .depth_write_enable = vk.Bool32.true,
                .depth_compare_op = .less_or_equal,
                .depth_bounds_test_enable = vk.Bool32.false,
                .stencil_test_enable = vk.Bool32.false,
                .front = std.mem.zeroes(vk.StencilOpState),
                .back = std.mem.zeroes(vk.StencilOpState),
                .min_depth_bounds = 0.0,
                .max_depth_bounds = 1.0,
            },
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = layout,
            .render_pass = render_pass,
            .subpass = 0,
            .base_pipeline_index = -1,
        }},
        null,
        &pipelines,
    );

    return .{ .pipeline = pipelines[0], .layout = layout };
}
