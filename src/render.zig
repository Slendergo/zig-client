const std = @import("std");
const map = @import("map.zig");
const game_data = @import("game_data.zig");
const assets = @import("assets.zig");
const camera = @import("camera.zig");
const settings = @import("settings.zig");
const zgpu = @import("zgpu");
const utils = @import("utils.zig");
const zstbrp = @import("zstbrp");
const zstbi = @import("zstbi");
const ui = @import("ui.zig");

pub const attack_period: u32 = 300;

pub const BaseVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    texel_size: [2]f32,
    flash_color: [3]f32,
    flash_strength: f32,
    glow_color: [3]f32,
    alpha_mult: f32,
};

pub const GroundVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    left_blend_uv: [2]f32,
    top_blend_uv: [2]f32,
    right_blend_uv: [2]f32,
    bottom_blend_uv: [2]f32,
    base_uv: [2]f32,
};

pub const TextVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    color: [3]f32,
    text_type: f32,
    alpha_mult: f32,
    shadow_color: [3]f32,
    shadow_alpha_mult: f32,
    shadow_texel_offset: [2]f32,
    distance_factor: f32,
};

pub const LightVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    color: [3]f32,
    intensity: f32,
};

// must be multiples of 16 bytes. be mindful
pub const GroundUniformData = extern struct {
    left_top_mask_uv: [4]f32,
    right_bottom_mask_uv: [4]f32,
};

pub var base_pipeline: zgpu.RenderPipelineHandle = .{};
pub var base_bind_group: zgpu.BindGroupHandle = undefined;
pub var ground_pipeline: zgpu.RenderPipelineHandle = .{};
pub var ground_bind_group: zgpu.BindGroupHandle = undefined;
pub var text_pipeline: zgpu.RenderPipelineHandle = .{};
pub var text_bind_group: zgpu.BindGroupHandle = undefined;
pub var light_pipeline: zgpu.RenderPipelineHandle = .{};
pub var light_bind_group: zgpu.BindGroupHandle = undefined;

pub var base_vb: zgpu.BufferHandle = undefined;
pub var ground_vb: zgpu.BufferHandle = undefined;
pub var text_vb: zgpu.BufferHandle = undefined;
pub var light_vb: zgpu.BufferHandle = undefined;

pub var index_buffer: zgpu.BufferHandle = undefined;

pub var base_vert_data: [4000]BaseVertexData = undefined;
pub var ground_vert_data: [4000]GroundVertexData = undefined;
// no nice way of having multiple batches
pub var text_vert_data: [40000]TextVertexData = undefined;
pub var light_vert_data: [8000]LightVertexData = undefined;

pub var bold_text_texture: zgpu.TextureHandle = undefined;
pub var bold_text_texture_view: zgpu.TextureViewHandle = undefined;
pub var bold_italic_text_texture: zgpu.TextureHandle = undefined;
pub var bold_italic_text_texture_view: zgpu.TextureViewHandle = undefined;
pub var medium_text_texture: zgpu.TextureHandle = undefined;
pub var medium_text_texture_view: zgpu.TextureViewHandle = undefined;
pub var medium_italic_text_texture: zgpu.TextureHandle = undefined;
pub var medium_italic_text_texture_view: zgpu.TextureViewHandle = undefined;
pub var texture: zgpu.TextureHandle = undefined;
pub var texture_view: zgpu.TextureViewHandle = undefined;
pub var light_texture: zgpu.TextureHandle = undefined;
pub var light_texture_view: zgpu.TextureViewHandle = undefined;

pub var sampler: zgpu.SamplerHandle = undefined;
pub var linear_sampler: zgpu.SamplerHandle = undefined;

inline fn createVertexBuffer(gctx: *zgpu.GraphicsContext, comptime T: type, vb_handle: *zgpu.BufferHandle, vb: []const T) void {
    vb_handle.* = gctx.createBuffer(.{
        .usage = .{ .copy_dst = true, .vertex = true },
        .size = vb.len * @sizeOf(T),
    });
    gctx.queue.writeBuffer(gctx.lookupResource(vb_handle.*).?, 0, T, vb);
}

inline fn createTexture(gctx: *zgpu.GraphicsContext, tex: *zgpu.TextureHandle, view: *zgpu.TextureViewHandle, img: zstbi.Image) void {
    tex.* = gctx.createTexture(.{
        .usage = .{ .texture_binding = true, .copy_dst = true },
        .size = .{
            .width = img.width,
            .height = img.height,
            .depth_or_array_layers = 1,
        },
        .format = zgpu.imageInfoToTextureFormat(
            img.num_components,
            img.bytes_per_component,
            img.is_hdr,
        ),
        .mip_level_count = 1,
    });
    view.* = gctx.createTextureView(tex.*, .{});

    gctx.queue.writeTexture(
        .{ .texture = gctx.lookupResource(tex.*).? },
        .{
            .bytes_per_row = img.bytes_per_row,
            .rows_per_image = img.height,
        },
        .{ .width = img.width, .height = img.height },
        u8,
        img.data,
    );
}

pub fn init(gctx: *zgpu.GraphicsContext, allocator: std.mem.Allocator) void {
    createVertexBuffer(gctx, BaseVertexData, &base_vb, base_vert_data[0..]);
    createVertexBuffer(gctx, GroundVertexData, &ground_vb, ground_vert_data[0..]);
    createVertexBuffer(gctx, TextVertexData, &text_vb, text_vert_data[0..]);
    createVertexBuffer(gctx, LightVertexData, &light_vb, light_vert_data[0..]);

    @setEvalBranchQuota(1100);
    comptime var index_data: [6000]u16 = undefined;
    comptime {
        for (0..1000) |i| {
            const actual_i: u16 = @intCast(i * 6);
            const i_4: u16 = @intCast(i * 4);
            index_data[actual_i] = 0 + i_4;
            index_data[actual_i + 1] = 1 + i_4;
            index_data[actual_i + 2] = 3 + i_4;
            index_data[actual_i + 3] = 1 + i_4;
            index_data[actual_i + 4] = 2 + i_4;
            index_data[actual_i + 5] = 3 + i_4;
        }
    }

    index_buffer = gctx.createBuffer(.{
        .usage = .{ .copy_dst = true, .index = true },
        .size = index_data.len * @sizeOf(u16),
    });
    gctx.queue.writeBuffer(gctx.lookupResource(index_buffer).?, 0, u16, index_data[0..]);

    createTexture(gctx, &medium_text_texture, &medium_text_texture_view, assets.medium_atlas);
    createTexture(gctx, &medium_italic_text_texture, &medium_italic_text_texture_view, assets.medium_italic_atlas);
    createTexture(gctx, &bold_text_texture, &bold_text_texture_view, assets.bold_atlas);
    createTexture(gctx, &bold_italic_text_texture, &bold_italic_text_texture_view, assets.bold_italic_atlas);
    createTexture(gctx, &texture, &texture_view, assets.atlas);
    createTexture(gctx, &light_texture, &light_texture_view, assets.light_tex);

    sampler = gctx.createSampler(.{});
    linear_sampler = gctx.createSampler(.{ .min_filter = .linear, .mag_filter = .linear });

    const base_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.samplerEntry(0, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(base_bind_group_layout);
    base_bind_group = gctx.createBindGroup(base_bind_group_layout, &.{
        .{ .binding = 0, .sampler_handle = sampler },
        .{ .binding = 1, .texture_view_handle = texture_view },
    });

    const ground_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
        zgpu.samplerEntry(1, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(2, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(ground_bind_group_layout);
    ground_bind_group = gctx.createBindGroup(ground_bind_group_layout, &.{
        .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(GroundUniformData) },
        .{ .binding = 1, .sampler_handle = sampler },
        .{ .binding = 2, .texture_view_handle = texture_view },
    });

    const text_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.samplerEntry(0, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(2, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(4, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(text_bind_group_layout);
    text_bind_group = gctx.createBindGroup(text_bind_group_layout, &.{
        .{ .binding = 0, .sampler_handle = linear_sampler },
        .{ .binding = 1, .texture_view_handle = medium_text_texture_view },
        .{ .binding = 2, .texture_view_handle = medium_italic_text_texture_view },
        .{ .binding = 3, .texture_view_handle = bold_text_texture_view },
        .{ .binding = 4, .texture_view_handle = bold_italic_text_texture_view },
    });

    const light_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.samplerEntry(0, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(light_bind_group_layout);
    light_bind_group = gctx.createBindGroup(light_bind_group_layout, &.{
        .{ .binding = 0, .sampler_handle = linear_sampler },
        .{ .binding = 1, .texture_view_handle = light_texture_view },
    });

    // create normal pipeline
    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            base_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/base.wgsl"), null);
        defer s_mod.release();

        // zig fmt: off
        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{ 
                .format = zgpu.GraphicsContext.swapchain_format, 
                .blend = &zgpu.wgpu.BlendState{ 
                    .color = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha }, 
                    .alpha = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha } 
                } 
        }};
        // zig fmt: on

        const vertex_attributes = [_]zgpu.wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "pos"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "uv"), .shader_location = 1 },
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "texel_size"), .shader_location = 2 },
            .{ .format = .float32x3, .offset = @offsetOf(BaseVertexData, "flash_color"), .shader_location = 3 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "flash_strength"), .shader_location = 4 },
            .{ .format = .float32x3, .offset = @offsetOf(BaseVertexData, "glow_color"), .shader_location = 5 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "alpha_mult"), .shader_location = 6 },
        };
        const vertex_buffers = [_]zgpu.wgpu.VertexBufferLayout{.{
            .array_stride = @sizeOf(BaseVertexData),
            .attribute_count = vertex_attributes.len,
            .attributes = &vertex_attributes,
        }};

        const pipeline_descriptor = zgpu.wgpu.RenderPipelineDescriptor{
            .vertex = zgpu.wgpu.VertexState{
                .module = s_mod,
                .entry_point = "vs_main",
                .buffer_count = vertex_buffers.len,
                .buffers = &vertex_buffers,
            },
            .primitive = zgpu.wgpu.PrimitiveState{
                .front_face = .cw,
                .cull_mode = .none,
                .topology = .triangle_list,
            },
            .fragment = &zgpu.wgpu.FragmentState{
                .module = s_mod,
                .entry_point = "fs_main",
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
        };
        gctx.createRenderPipelineAsync(allocator, pipeline_layout, pipeline_descriptor, &base_pipeline);
    }

    // create ground pipeline
    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            ground_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/ground.wgsl"), null);
        defer s_mod.release();

        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{
            .format = zgpu.GraphicsContext.swapchain_format,
        }};

        const vertex_attributes = [_]zgpu.wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "base_uv"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "uv"), .shader_location = 1 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "left_blend_uv"), .shader_location = 2 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "top_blend_uv"), .shader_location = 3 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "right_blend_uv"), .shader_location = 4 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "bottom_blend_uv"), .shader_location = 5 },
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "pos"), .shader_location = 6 },
        };
        const vertex_buffers = [_]zgpu.wgpu.VertexBufferLayout{.{
            .array_stride = @sizeOf(GroundVertexData),
            .attribute_count = vertex_attributes.len,
            .attributes = &vertex_attributes,
        }};

        const pipeline_descriptor = zgpu.wgpu.RenderPipelineDescriptor{
            .vertex = zgpu.wgpu.VertexState{
                .module = s_mod,
                .entry_point = "vs_main",
                .buffer_count = vertex_buffers.len,
                .buffers = &vertex_buffers,
            },
            .primitive = zgpu.wgpu.PrimitiveState{
                .front_face = .cw,
                .cull_mode = .none,
                .topology = .triangle_list,
            },
            .fragment = &zgpu.wgpu.FragmentState{
                .module = s_mod,
                .entry_point = "fs_main",
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
        };
        gctx.createRenderPipelineAsync(allocator, pipeline_layout, pipeline_descriptor, &ground_pipeline);
    }

    // create text pipeline
    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            text_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/text.wgsl"), null);
        defer s_mod.release();

        // zig fmt: off
        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{ 
            .format = zgpu.GraphicsContext.swapchain_format,
            .blend = &zgpu.wgpu.BlendState{ 
                .color = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha }, 
                .alpha = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha } 
            } 
        }};
        // zig fmt: on
        const vertex_attributes = [_]zgpu.wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = @offsetOf(TextVertexData, "pos"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(TextVertexData, "uv"), .shader_location = 1 },
            .{ .format = .float32x3, .offset = @offsetOf(TextVertexData, "color"), .shader_location = 2 },
            .{ .format = .float32, .offset = @offsetOf(TextVertexData, "text_type"), .shader_location = 3 },
            .{ .format = .float32, .offset = @offsetOf(TextVertexData, "alpha_mult"), .shader_location = 4 },
            .{ .format = .float32x3, .offset = @offsetOf(TextVertexData, "shadow_color"), .shader_location = 5 },
            .{ .format = .float32, .offset = @offsetOf(TextVertexData, "shadow_alpha_mult"), .shader_location = 6 },
            .{ .format = .float32x2, .offset = @offsetOf(TextVertexData, "shadow_texel_offset"), .shader_location = 7 },
            .{ .format = .float32, .offset = @offsetOf(TextVertexData, "distance_factor"), .shader_location = 8 },
        };
        const vertex_buffers = [_]zgpu.wgpu.VertexBufferLayout{.{
            .array_stride = @sizeOf(TextVertexData),
            .attribute_count = vertex_attributes.len,
            .attributes = &vertex_attributes,
        }};

        const pipeline_descriptor = zgpu.wgpu.RenderPipelineDescriptor{
            .vertex = zgpu.wgpu.VertexState{
                .module = s_mod,
                .entry_point = "vs_main",
                .buffer_count = vertex_buffers.len,
                .buffers = &vertex_buffers,
            },
            .primitive = zgpu.wgpu.PrimitiveState{
                .front_face = .cw,
                .cull_mode = .none,
                .topology = .triangle_list,
            },
            .fragment = &zgpu.wgpu.FragmentState{
                .module = s_mod,
                .entry_point = "fs_main",
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
        };
        gctx.createRenderPipelineAsync(allocator, pipeline_layout, pipeline_descriptor, &text_pipeline);
    }

    // create light pipeline
    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            light_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/light.wgsl"), null);
        defer s_mod.release();

        // zig fmt: off
        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{ 
            .format = zgpu.GraphicsContext.swapchain_format, 
            .blend = &zgpu.wgpu.BlendState{
                .color = .{ .src_factor = .src_alpha, .dst_factor = .one }, 
                .alpha = .{ .src_factor = .zero, .dst_factor = .zero } 
            } 
        }};
        // zig fmt: on
        const vertex_attributes = [_]zgpu.wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = @offsetOf(LightVertexData, "pos"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(LightVertexData, "uv"), .shader_location = 1 },
            .{ .format = .float32x3, .offset = @offsetOf(LightVertexData, "color"), .shader_location = 2 },
            .{ .format = .float32, .offset = @offsetOf(LightVertexData, "intensity"), .shader_location = 3 },
        };
        const vertex_buffers = [_]zgpu.wgpu.VertexBufferLayout{.{
            .array_stride = @sizeOf(LightVertexData),
            .attribute_count = vertex_attributes.len,
            .attributes = &vertex_attributes,
        }};

        const pipeline_descriptor = zgpu.wgpu.RenderPipelineDescriptor{
            .vertex = zgpu.wgpu.VertexState{
                .module = s_mod,
                .entry_point = "vs_main",
                .buffer_count = vertex_buffers.len,
                .buffers = &vertex_buffers,
            },
            .primitive = zgpu.wgpu.PrimitiveState{
                .front_face = .cw,
                .cull_mode = .none,
                .topology = .triangle_list,
            },
            .fragment = &zgpu.wgpu.FragmentState{
                .module = s_mod,
                .entry_point = "fs_main",
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
        };
        gctx.createRenderPipelineAsync(allocator, pipeline_layout, pipeline_descriptor, &light_pipeline);
    }
}

inline fn drawWall(idx: u16, x: f32, y: f32, u: f32, v: f32, top_u: f32, top_v: f32) u16 {
    var idx_new: u16 = 0;
    const size = 8 * assets.base_texel_w;
    const x_base = (x * camera.cos + y * camera.sin + camera.clip_x) * camera.clip_scale_x;
    const y_base = -(x * -camera.sin + y * camera.cos + camera.clip_y) * camera.clip_scale_y;
    const y_base_top = -(x * -camera.sin + y * camera.cos + camera.clip_y - camera.px_per_tile * camera.scale) * camera.clip_scale_y;

    const x1 = camera.x_cos + camera.x_sin + x_base;
    const x2 = -camera.x_cos + camera.x_sin + x_base;
    const x3 = -camera.x_cos - camera.x_sin + x_base;
    const x4 = camera.x_cos - camera.x_sin + x_base;

    const y1 = camera.y_sin - camera.y_cos + y_base;
    const y2 = -camera.y_sin - camera.y_cos + y_base;
    const y3 = -camera.y_sin + camera.y_cos + y_base;
    const y4 = camera.y_sin + camera.y_cos + y_base;

    const top_y1 = camera.y_sin - camera.y_cos + y_base_top;
    const top_y2 = -camera.y_sin - camera.y_cos + y_base_top;
    const top_y3 = -camera.y_sin + camera.y_cos + y_base_top;
    const top_y4 = camera.y_sin + camera.y_cos + y_base_top;

    const floor_y: u32 = @intFromFloat(@floor(y));
    const floor_x: u32 = @intFromFloat(@floor(x));

    const bound_angle = utils.halfBound(camera.angle);
    const pi_div_2 = std.math.pi / 2.0;
    topSide: {
        if (bound_angle >= pi_div_2 and bound_angle <= std.math.pi or bound_angle >= -std.math.pi and bound_angle <= -pi_div_2) {
            var new_u: f32 = 0.0;
            var new_v: f32 = 0.0;

            if (!map.validPos(@intCast(floor_x), @intCast(floor_y - 1))) {
                new_u = assets.wall_backface_uv[0];
                new_v = assets.wall_backface_uv[1];
            } else {
                const top_sq = map.squares[(floor_y - 1) * @as(u32, @intCast(map.width)) + floor_x];
                if (top_sq.has_wall)
                    break :topSide;

                if (top_sq.tile_type == 0xFFFF or top_sq.tile_type == 0xFF) {
                    new_u = assets.wall_backface_uv[0];
                    new_v = assets.wall_backface_uv[1];
                } else {
                    new_u = u;
                    new_v = v;
                }
            }

            // zig fmt: off
            drawQuadVerts(idx + idx_new, x3, top_y3, x4, top_y4, x4, y4, x3, y3,
                new_u, new_v, size, size, 0, 0, 
                0, 0.25, -1.0);
            // zig fmt: on
            idx_new += 4;
        }
    }

    bottomSide: {
        if (bound_angle <= pi_div_2 and bound_angle >= -pi_div_2) {
            var new_u: f32 = 0.0;
            var new_v: f32 = 0.0;

            if (!map.validPos(@intCast(floor_x), @intCast(floor_y + 1))) {
                new_u = assets.wall_backface_uv[0];
                new_v = assets.wall_backface_uv[1];
            } else {
                const bottom_sq = map.squares[(floor_y + 1) * @as(u32, @intCast(map.width)) + floor_x];
                if (bottom_sq.has_wall)
                    break :bottomSide;

                if (bottom_sq.tile_type == 0xFFFF or bottom_sq.tile_type == 0xFF) {
                    new_u = assets.wall_backface_uv[0];
                    new_v = assets.wall_backface_uv[1];
                } else {
                    new_u = u;
                    new_v = v;
                }
            }

            // zig fmt: off
            drawQuadVerts(idx + idx_new, x1, top_y1, x2, top_y2, x2, y2, x1, y1,
                new_u, new_v, size, size, 0, 0, 
                0, 0.25, -1.0);
            // zig fmt: on
            idx_new += 4;
        }
    }

    leftSide: {
        if (bound_angle >= 0 and bound_angle <= std.math.pi) {
            var new_u: f32 = 0.0;
            var new_v: f32 = 0.0;

            if (!map.validPos(@intCast(floor_x - 1), @intCast(floor_y))) {
                new_u = assets.wall_backface_uv[0];
                new_v = assets.wall_backface_uv[1];
            } else {
                const left_sq = map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x - 1];
                if (left_sq.has_wall)
                    break :leftSide;

                if (left_sq.tile_type == 0xFFFF or left_sq.tile_type == 0xFF) {
                    new_u = assets.wall_backface_uv[0];
                    new_v = assets.wall_backface_uv[1];
                } else {
                    new_u = u;
                    new_v = v;
                }
            }

            // zig fmt: off
            drawQuadVerts(idx + idx_new, x3, top_y3, x2, top_y2, x2, y2, x3, y3,
                new_u, new_v, size, size, 0, 0, 
                0, 0.25, -1.0);
            // zig fmt: on
            idx_new += 4;
        }
    }

    rightSide: {
        if (bound_angle <= 0 and bound_angle >= -std.math.pi) {
            var new_u: f32 = 0.0;
            var new_v: f32 = 0.0;

            if (!map.validPos(@intCast(floor_x + 1), @intCast(floor_y))) {
                new_u = assets.wall_backface_uv[0];
                new_v = assets.wall_backface_uv[1];
            } else {
                const right_sq = map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x + 1];
                if (right_sq.has_wall)
                    break :rightSide;

                if (right_sq.tile_type == 0xFFFF or right_sq.tile_type == 0xFF) {
                    new_u = assets.wall_backface_uv[0];
                    new_v = assets.wall_backface_uv[1];
                } else {
                    new_u = u;
                    new_v = v;
                }
            }

            // zig fmt: off
            drawQuadVerts(idx + idx_new, x4, top_y4, x1, top_y1, x1, y1, x4, y4,
                new_u, new_v, size, size, 0, 0, 
                0, 0.25, -1.0);
            // zig fmt: on
            idx_new += 4;
        }
    }

    // zig fmt: off
    drawQuadVerts(idx + idx_new, 
        x1, top_y1, x2, top_y2, x3, top_y3, x4, top_y4,
        top_u, top_v, size, size, 
        0, 0, 0, 0.1, -1.0);
    // zig fmt: on
    idx_new += 4;

    return idx_new;
}

const QuadOptions = struct {
    rotation: f32 = 0.0,
    texel_mult: f32 = 0.0,
    glow_color: i32 = -1,
    flash_color: i32 = -1,
    flash_strength: f32 = 0.0,
    alpha_mult: f32 = -1.0,
};

inline fn drawQuad(
    idx: u16,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    tex_u: f32,
    tex_v: f32,
    tex_w: f32,
    tex_h: f32,
    opts: QuadOptions,
) void {
    var flash_rgb = [3]f32{ -1.0, -1.0, -1.0 };
    if (opts.flash_color != -1) {
        flash_rgb[0] = @as(f32, @floatFromInt((opts.flash_color >> 16) & 0xFF)) / 255.0;
        flash_rgb[1] = @as(f32, @floatFromInt((opts.flash_color >> 8) & 0xFF)) / 255.0;
        flash_rgb[2] = @as(f32, @floatFromInt(opts.flash_color & 0xFF)) / 255.0;
    }

    var glow_rgb = [3]f32{ 0.0, 0.0, 0.0 };
    if (opts.glow_color != -1) {
        glow_rgb[0] = @as(f32, @floatFromInt((opts.glow_color >> 16) & 0xFF)) / 255.0;
        glow_rgb[1] = @as(f32, @floatFromInt((opts.glow_color >> 8) & 0xFF)) / 255.0;
        glow_rgb[2] = @as(f32, @floatFromInt(opts.glow_color & 0xFF)) / 255.0;
    }

    const texel_w = assets.base_texel_w * opts.texel_mult;
    const texel_h = assets.base_texel_h * opts.texel_mult;

    const scaled_w = w * camera.clip_scale_x;
    const scaled_h = h * camera.clip_scale_y;
    // todo hack fiesta
    const scaled_x = (x - camera.screen_width / 2.0 + w / 2.0) * camera.clip_scale_x;
    const scaled_y = -(y - camera.screen_height / 2.0 + h / 2.0) * camera.clip_scale_y;

    const cos_angle = @cos(opts.rotation);
    const sin_angle = @sin(opts.rotation);
    const x_cos = cos_angle * scaled_w * 0.5;
    const x_sin = sin_angle * scaled_w * 0.5;
    const y_cos = cos_angle * scaled_h * 0.5;
    const y_sin = sin_angle * scaled_h * 0.5;

    base_vert_data[idx] = BaseVertexData{
        .pos = [2]f32{ -x_cos + x_sin + scaled_x, -y_sin - y_cos + scaled_y },
        .uv = [2]f32{ tex_u, tex_v + tex_h },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = opts.flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = opts.alpha_mult,
    };

    base_vert_data[idx + 1] = BaseVertexData{
        .pos = [2]f32{ x_cos + x_sin + scaled_x, y_sin - y_cos + scaled_y },
        .uv = [2]f32{ tex_u + tex_w, tex_v + tex_h },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = opts.flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = opts.alpha_mult,
    };

    base_vert_data[idx + 2] = BaseVertexData{
        .pos = [2]f32{ x_cos - x_sin + scaled_x, y_sin + y_cos + scaled_y },
        .uv = [2]f32{ tex_u + tex_w, tex_v },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = opts.flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = opts.alpha_mult,
    };

    base_vert_data[idx + 3] = BaseVertexData{
        .pos = [2]f32{ -x_cos - x_sin + scaled_x, -y_sin + y_cos + scaled_y },
        .uv = [2]f32{ tex_u, tex_v },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = opts.flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = opts.alpha_mult,
    };
}

inline fn drawQuadVerts(
    idx: u16,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    x3: f32,
    y3: f32,
    x4: f32,
    y4: f32,
    tex_u: f32,
    tex_v: f32,
    tex_w: f32,
    tex_h: f32,
    texel_mult: f32,
    glow_color: i32,
    flash_color: i32,
    flash_strength: f32,
    alpha_mult: f32,
) void {
    var flash_rgb = [3]f32{ -1.0, -1.0, -1.0 };
    if (flash_color != -1) {
        flash_rgb[0] = @as(f32, @floatFromInt((flash_color >> 16) & 0xFF)) / 255.0;
        flash_rgb[1] = @as(f32, @floatFromInt((flash_color >> 8) & 0xFF)) / 255.0;
        flash_rgb[2] = @as(f32, @floatFromInt(flash_color & 0xFF)) / 255.0;
    }

    var glow_rgb = [3]f32{ 0.0, 0.0, 0.0 };
    if (glow_color != -1) {
        glow_rgb[0] = @as(f32, @floatFromInt((glow_color >> 16) & 0xFF)) / 255.0;
        glow_rgb[1] = @as(f32, @floatFromInt((glow_color >> 8) & 0xFF)) / 255.0;
        glow_rgb[2] = @as(f32, @floatFromInt(glow_color & 0xFF)) / 255.0;
    }

    const texel_w = assets.base_texel_w * texel_mult;
    const texel_h = assets.base_texel_h * texel_mult;

    base_vert_data[idx] = BaseVertexData{
        .pos = [2]f32{ x1, y1 },
        .uv = [2]f32{ tex_u, tex_v },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = alpha_mult,
    };

    base_vert_data[idx + 1] = BaseVertexData{
        .pos = [2]f32{ x2, y2 },
        .uv = [2]f32{ tex_u + tex_w, tex_v },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = alpha_mult,
    };

    base_vert_data[idx + 2] = BaseVertexData{
        .pos = [2]f32{ x3, y3 },
        .uv = [2]f32{ tex_u + tex_w, tex_v + tex_h },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = alpha_mult,
    };

    base_vert_data[idx + 3] = BaseVertexData{
        .pos = [2]f32{ x4, y4 },
        .uv = [2]f32{ tex_u, tex_v + tex_h },
        .texel_size = [2]f32{ texel_w, texel_h },
        .flash_color = flash_rgb,
        .flash_strength = flash_strength,
        .glow_color = glow_rgb,
        .alpha_mult = alpha_mult,
    };
}

inline fn drawSquare(
    idx: u16,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    x3: f32,
    y3: f32,
    x4: f32,
    y4: f32,
    tex_u: f32,
    tex_v: f32,
    tex_w: f32,
    tex_h: f32,
    left_blend_u: f32,
    left_blend_v: f32,
    top_blend_u: f32,
    top_blend_v: f32,
    right_blend_u: f32,
    right_blend_v: f32,
    bottom_blend_u: f32,
    bottom_blend_v: f32,
) void {
    ground_vert_data[idx] = GroundVertexData{
        .pos = [2]f32{ x1, y1 },
        .uv = [2]f32{ tex_w, tex_h },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ tex_u, tex_v },
    };

    ground_vert_data[idx + 1] = GroundVertexData{
        .pos = [2]f32{ x2, y2 },
        .uv = [2]f32{ 0, tex_h },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ tex_u, tex_v },
    };

    ground_vert_data[idx + 2] = GroundVertexData{
        .pos = [2]f32{ x3, y3 },
        .uv = [2]f32{ 0, 0 },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ tex_u, tex_v },
    };

    ground_vert_data[idx + 3] = GroundVertexData{
        .pos = [2]f32{ x4, y4 },
        .uv = [2]f32{ tex_w, 0 },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ tex_u, tex_v },
    };
}

const TextOptions = struct {
    shadow_color: u32 = 0x000000,
    shadow_alpha_mult: f32 = 0.5,
    shadow_texel_offset_mult: f32 = 6.0,
};

inline fn drawText(idx: u16, x: f32, y: f32, size: f32, text: []const u8, color: u32, alpha_mult: f32, text_type: f32, opts: TextOptions) u16 {
    const r: f32 = @as(f32, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
    const g: f32 = @as(f32, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
    const b: f32 = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;
    const rgb = [3]f32{ r, g, b };

    const shadow_r: f32 = @as(f32, @floatFromInt((opts.shadow_color >> 16) & 0xFF)) / 255.0;
    const shadow_g: f32 = @as(f32, @floatFromInt((opts.shadow_color >> 8) & 0xFF)) / 255.0;
    const shadow_b: f32 = @as(f32, @floatFromInt(opts.shadow_color & 0xFF)) / 255.0;
    const shadow_rgb = [3]f32{ shadow_r, shadow_g, shadow_b };

    const shadow_texel_size = [2]f32{ opts.shadow_texel_offset_mult / assets.CharacterData.atlas_w, opts.shadow_texel_offset_mult / assets.CharacterData.atlas_h };

    const size_scale = size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
    const line_height = assets.CharacterData.line_height * assets.CharacterData.size * size_scale;

    var idx_new = idx;
    var x_pointer = x - camera.screen_width / 2.0;
    const offset_y = y - camera.screen_height / 2.0;
    for (text) |char| {
        const char_data = switch (@as(u32, @intFromFloat(text_type))) {
            0.0 => assets.medium_chars[char],
            1.0 => assets.medium_italic_chars[char],
            2.0 => assets.bold_chars[char],
            3.0 => assets.bold_italic_chars[char],
            else => unreachable,
        };

        if (char_data.tex_w <= 0) {
            x_pointer += char_data.x_advance * size_scale;
            continue;
        }

        const w = char_data.width * size_scale;
        const h = char_data.height * size_scale;
        const scaled_x = (x_pointer + char_data.x_offset * size_scale + w / 2) * camera.clip_scale_x;
        const scaled_y = -(offset_y - char_data.y_offset * size_scale - h / 2 + line_height) * camera.clip_scale_y;
        const scaled_w = w * camera.clip_scale_x;
        const scaled_h = h * camera.clip_scale_y;

        const px_range = 2.0 * assets.CharacterData.padding_mult;

        // zig fmt: off
        text_vert_data[idx_new] = TextVertexData{
            .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_h * 0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u, char_data.tex_v },
            .color = rgb,
            .text_type = text_type,
            .alpha_mult = alpha_mult,
            .shadow_color = shadow_rgb,
            .shadow_alpha_mult = opts.shadow_alpha_mult,
            .shadow_texel_offset = shadow_texel_size,
            .distance_factor = size_scale * px_range
        };

        text_vert_data[idx_new + 1] = TextVertexData{
            .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * 0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u + char_data.tex_w, char_data.tex_v },
            .color = rgb,
            .text_type = text_type,
            .alpha_mult = alpha_mult,
            .shadow_color = shadow_rgb,
            .shadow_alpha_mult = opts.shadow_alpha_mult,
            .shadow_texel_offset = shadow_texel_size,
            .distance_factor = size_scale * px_range
        };

        text_vert_data[idx_new + 2] = TextVertexData{
            .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u + char_data.tex_w, char_data.tex_v + char_data.tex_h },
            .color = rgb,
            .text_type = text_type,
            .alpha_mult = alpha_mult,
            .shadow_color = shadow_rgb,
            .shadow_alpha_mult = opts.shadow_alpha_mult,
            .shadow_texel_offset = shadow_texel_size,
            .distance_factor = size_scale * px_range
        };

        text_vert_data[idx_new + 3] = TextVertexData{
            .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u, char_data.tex_v + char_data.tex_h },
            .color = rgb,
            .text_type = text_type,
            .alpha_mult = alpha_mult,
            .shadow_color = shadow_rgb,
            .shadow_alpha_mult = opts.shadow_alpha_mult,
            .shadow_texel_offset = shadow_texel_size,
            .distance_factor = size_scale * px_range
        };
        // zig fmt: on
        idx_new += 4;

        x_pointer += char_data.x_advance * size_scale;
    }

    return idx_new - idx;
}

inline fn drawLight(idx: u16, w: f32, h: f32, x: f32, y: f32, color: i32, intensity: f32) void {
    const r: f32 = @as(f32, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
    const g: f32 = @as(f32, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
    const b: f32 = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;
    const rgb = [3]f32{ r, g, b };

    // 2x given size
    const scaled_w = w * 4 * camera.clip_scale_x * camera.scale;
    const scaled_h = h * 4 * camera.clip_scale_y * camera.scale;
    const scaled_x = (x - camera.screen_width / 2.0) * camera.clip_scale_x;
    const scaled_y = -(y - camera.screen_height / 2.0) * camera.clip_scale_y; // todo

    light_vert_data[idx] = LightVertexData{
        .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_w * 0.5 + scaled_y },
        .uv = [2]f32{ 1, 1 },
        .color = rgb,
        .intensity = intensity,
    };

    light_vert_data[idx + 1] = LightVertexData{
        .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * 0.5 + scaled_y },
        .uv = [2]f32{ 0, 1 },
        .color = rgb,
        .intensity = intensity,
    };

    light_vert_data[idx + 2] = LightVertexData{
        .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
        .uv = [2]f32{ 0, 0 },
        .color = rgb,
        .intensity = intensity,
    };

    light_vert_data[idx + 3] = LightVertexData{
        .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
        .uv = [2]f32{ 1, 0 },
        .color = rgb,
        .intensity = intensity,
    };
}

inline fn endDraw(
    encoder: zgpu.wgpu.CommandEncoder,
    render_pass_info: zgpu.wgpu.RenderPassDescriptor,
    vb_info: zgpu.BufferInfo,
    ib_info: zgpu.BufferInfo,
    pipeline: zgpu.wgpu.RenderPipeline,
    bind_group: zgpu.wgpu.BindGroup,
    indices: u32,
    offsets: ?[]const u32,
) void {
    const pass = encoder.beginRenderPass(render_pass_info);
    pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
    pass.setIndexBuffer(ib_info.gpuobj.?, .uint16, 0, ib_info.size);
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bind_group, offsets);
    pass.drawIndexed(indices, 1, 0, 0, 0);
    pass.end();
    pass.release();
}

pub fn draw(time: i32, gctx: *zgpu.GraphicsContext, back_buffer: zgpu.wgpu.TextureView, encoder: zgpu.wgpu.CommandEncoder) void {
    if (!map.validPos(@intFromFloat(camera.x), @intFromFloat(camera.y)))
        return;

    const ib_info = gctx.lookupResourceInfo(index_buffer) orelse return;

    var light_idx: u16 = 0;
    var text_idx: u16 = 0;

    groundPass: {
        const vb_info = gctx.lookupResourceInfo(ground_vb) orelse break :groundPass;
        const pipeline = gctx.lookupResource(ground_pipeline) orelse break :groundPass;
        const bind_group = gctx.lookupResource(ground_bind_group) orelse break :groundPass;
        const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
            .view = back_buffer,
            .load_op = .clear,
            .store_op = .store,
        }};
        const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
        };

        const mem = gctx.uniformsAllocate(GroundUniformData, 1);
        mem.slice[0] = .{
            .left_top_mask_uv = assets.left_top_mask_uv,
            .right_bottom_mask_uv = assets.right_bottom_mask_uv,
        };

        var square_idx: u16 = 0;
        for (camera.min_y..camera.max_y) |y| {
            for (camera.min_x..camera.max_x) |x| {
                const dx = camera.x - @as(f32, @floatFromInt(x)) - 0.5;
                const dy = camera.y - @as(f32, @floatFromInt(y)) - 0.5;
                if (dx * dx + dy * dy > camera.max_dist_sq)
                    continue;

                const map_square_idx = x + y * @as(usize, @intCast(map.width));
                const square = map.squares[map_square_idx];
                if (square.tile_type == 0xFFFF)
                    continue;

                const screen_pos = camera.rotateAroundCamera(square.x, square.y);
                const screen_x = screen_pos.x - camera.screen_width / 2.0;
                const screen_y = -(screen_pos.y - camera.screen_height / 2.0);

                if (square.light_color > 0) {
                    // zig fmt: off
                    drawLight(light_idx,
                        camera.px_per_tile * square.light_radius, 
                        camera.px_per_tile * square.light_radius,
                        screen_pos.x, screen_pos.y, square.light_color, square.light_intensity);
                    // zig fmt: on
                    light_idx += 4;
                }

                const cos_half = camera.cos / 2.0;
                const sin_half = camera.sin / 2.0;
                // zig fmt: off
                drawSquare(square_idx, 
                    (cos_half + sin_half + screen_x) * camera.clip_scale_x, (sin_half - cos_half + screen_y) * camera.clip_scale_y,
                    (-cos_half + sin_half + screen_x) * camera.clip_scale_x, (-sin_half - cos_half + screen_y) * camera.clip_scale_y,
                    (-cos_half - sin_half + screen_x) * camera.clip_scale_x, (-sin_half + cos_half + screen_y) * camera.clip_scale_y,
                    (cos_half - sin_half + screen_x) * camera.clip_scale_x, (sin_half + cos_half + screen_y) * camera.clip_scale_y,
                    square.tex_u, square.tex_v, square.tex_w, square.tex_h,
                    square.left_blend_u, square.left_blend_v, 
                    square.top_blend_u, square.top_blend_v,
                    square.right_blend_u, square.right_blend_v,
                    square.bottom_blend_u, square.bottom_blend_v);
                // zig fmt: on
                square_idx += 4;
            }
        }

        if (square_idx > 0) {
            encoder.writeBuffer(gctx.lookupResource(ground_vb).?, 0, GroundVertexData, ground_vert_data[0..square_idx]);
            endDraw(encoder, render_pass_info, vb_info, ib_info, pipeline, bind_group, @divFloor(square_idx, 4) * 6, &.{mem.offset});
        }
    }

    normalPass: {
        if (map.entities.items.len <= 0)
            break :normalPass;

        while (!map.object_lock.tryLock()) {}
        defer map.object_lock.unlock();

        const vb_info = gctx.lookupResourceInfo(base_vb) orelse break :normalPass;
        const pipeline = gctx.lookupResource(base_pipeline) orelse break :normalPass;
        const bind_group = gctx.lookupResource(base_bind_group) orelse break :normalPass;
        const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
            .view = back_buffer,
            .load_op = .load,
            .store_op = .store,
        }};
        const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
        };

        var idx: u16 = 0;
        for (map.entities.items) |*en| {
            switch (en.*) {
                .player => |*player| {
                    if (!camera.visibleInCamera(player.x, player.y)) {
                        continue;
                    }

                    const size = camera.size_mult * camera.scale * player.size;

                    var rect = player.anim_data.walk_anims[player.dir][0];
                    var x_offset: f32 = 0.0;

                    if (!std.math.isNan(player.visual_move_angle)) {
                        player.dir = @intFromFloat(@mod(@divFloor(player.visual_move_angle - std.math.pi / 4.0, std.math.pi / 2.0) + 1.0, 4.0));
                        // bad hack todo
                        if (player.dir == assets.down_dir) {
                            player.dir = assets.left_dir;
                        } else if (player.dir == assets.left_dir) {
                            player.dir = assets.down_dir;
                        }

                        const time_dt: f32 = @floatFromInt(time);
                        const float_period: f32 = 3.5 / player.moveSpeedMultiplier();
                        const anim_idx: usize = @intFromFloat(@round(@mod(time_dt, float_period) / float_period));
                        rect = player.anim_data.walk_anims[player.dir][anim_idx];
                    }

                    if (time < player.attack_start + player.attack_period) {
                        player.dir = @intFromFloat(@mod(@divFloor(player.attack_angle - std.math.pi / 4.0, std.math.pi / 2.0) + 1.0, 4.0));
                        // bad hack
                        if (player.dir == assets.down_dir) {
                            player.dir = assets.left_dir;
                        } else if (player.dir == assets.left_dir) {
                            player.dir = assets.down_dir;
                        }

                        const time_dt: f32 = @floatFromInt(time - player.attack_start);
                        const float_period: f32 = @floatFromInt(player.attack_period);
                        const anim_idx: usize = @intFromFloat(@round(@mod(time_dt, float_period) / float_period));
                        rect = player.anim_data.attack_anims[player.dir][anim_idx];

                        if (anim_idx != 0) {
                            const w = @as(f32, @floatFromInt(rect.w)) * size;

                            if (player.dir == assets.left_dir) {
                                x_offset = -assets.padding * size;
                            } else {
                                x_offset = w / 4.0;
                            }
                        }
                    }

                    const square = player.getSquare();
                    var sink: f32 = 1.0;
                    if (square.tile_type != 0xFFFF) {
                        sink += square.sink;
                    }

                    const w = @as(f32, @floatFromInt(rect.w)) * size;
                    const h = @as(f32, @floatFromInt(rect.h)) * size / sink;

                    var screen_pos = camera.rotateAroundCamera(player.x, player.y);
                    screen_pos.x += x_offset;
                    screen_pos.y += player.z * -camera.px_per_tile - (h - size * assets.padding);

                    player.h = h;
                    player.screen_y = screen_pos.y - 30; // account for name
                    player.screen_x = screen_pos.x - x_offset;

                    if (player.light_color > 0) {
                        // zig fmt: off
                        drawLight(light_idx, w * player.light_radius, h * player.light_radius, 
                            screen_pos.x, screen_pos.y, player.light_color, player.light_intensity);
                        // zig fmt: on
                        light_idx += 4;
                    }

                    const name = if (player.name_override.len > 0) player.name_override else player.name;
                    if (name.len > 0) {
                        const text_width = ui.textWidth(16, name, ui.medium_text_type);
                        // zig fmt: off
                        text_idx += drawText(text_idx, 
                            screen_pos.x - x_offset - text_width / 2,
                            screen_pos.y - 16 * assets.CharacterData.padding_mult, 
                            16, name, 0xFCDF00, 1.0, ui.medium_text_type, .{});
                        // zig fmt: on
                    }

                    // zig fmt: off
                    drawQuad(idx, screen_pos.x - w / 2.0, screen_pos.y, w, h,
                        @as(f32, @floatFromInt(rect.x)) * assets.base_texel_w, 
                        @as(f32, @floatFromInt(rect.y)) * assets.base_texel_h, 
                        @as(f32, @floatFromInt(rect.w)) * assets.base_texel_w, 
                        @as(f32, @floatFromInt(rect.h)) * assets.base_texel_h / sink,
                        .{ .texel_mult = 2.0 / size });
                    // zig fmt: on
                    idx += 4;

                    var y_pos: f32 = 5.0 + if (sink != 0) @as(f32, 5.0) else @as(f32, 0.0);

                    // this should be the server's job...
                    if (player.hp > player.max_hp)
                        player.max_hp = player.hp;

                    if (player.hp >= 0 and player.hp < player.max_hp) {
                        const hp_bar_w = assets.hp_bar_rect.w * assets.atlas_width * 2 * camera.scale;
                        const hp_bar_h = assets.hp_bar_rect.h * assets.atlas_height * 2 * camera.scale;
                        const hp_bar_y = screen_pos.y + h + y_pos;

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - hp_bar_w / 2.0, hp_bar_y, hp_bar_w, hp_bar_h,
                            assets.empty_bar_rect.x, 
                            assets.empty_bar_rect.y, 
                            assets.empty_bar_rect.w, 
                            assets.empty_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        const float_hp: f32 = @floatFromInt(player.hp);
                        const float_max_hp: f32 = @floatFromInt(player.max_hp);
                        const hp_perc = 1.0 / (float_hp / float_max_hp);

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - hp_bar_w / 2.0, hp_bar_y, hp_bar_w / hp_perc, hp_bar_h,
                            assets.hp_bar_rect.x, 
                            assets.hp_bar_rect.y, 
                            assets.hp_bar_rect.w / hp_perc, 
                            assets.hp_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        y_pos += 20.0;
                    }

                    if (player.mp >= 0 and player.mp < player.max_mp) {
                        const mp_bar_w = assets.mp_bar_rect.w * assets.atlas_width * 2 * camera.scale;
                        const mp_bar_h = assets.mp_bar_rect.h * assets.atlas_height * 2 * camera.scale;
                        const mp_bar_y = screen_pos.y + h + y_pos;

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - mp_bar_w / 2.0, mp_bar_y, mp_bar_w, mp_bar_h,
                            assets.empty_bar_rect.x, 
                            assets.empty_bar_rect.y, 
                            assets.empty_bar_rect.w, 
                            assets.empty_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        const float_mp: f32 = @floatFromInt(player.mp);
                        const float_max_mp: f32 = @floatFromInt(player.max_mp);
                        const mp_perc = 1.0 / (float_mp / float_max_mp);

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - mp_bar_w / 2.0, mp_bar_y, mp_bar_w / mp_perc, mp_bar_h,
                            assets.mp_bar_rect.x, 
                            assets.mp_bar_rect.y, 
                            assets.mp_bar_rect.w / mp_perc, 
                            assets.mp_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        y_pos += 20.0;
                    }
                },
                .object => |*bo| {
                    if (!camera.visibleInCamera(bo.x, bo.y)) {
                        continue;
                    }

                    var tex_u = bo.tex_u;
                    var tex_v = bo.tex_v;
                    var tex_w = bo.tex_w;
                    var tex_h = bo.tex_h;
                    var screen_pos = camera.rotateAroundCamera(bo.x, bo.y);
                    const size = camera.size_mult * camera.scale * bo.size;

                    const square = bo.getSquare();
                    if (bo.draw_on_ground) {
                        // zig fmt: off
                        drawQuad(
                            idx, screen_pos.x - camera.px_per_tile / 2 * camera.scale,
                            screen_pos.y - camera.px_per_tile / 2 * camera.scale, 
                            camera.px_per_tile * camera.scale, camera.px_per_tile * camera.scale,
                            tex_u * assets.base_texel_w,
                            tex_v * assets.base_texel_h,
                            tex_w * assets.base_texel_w,
                            tex_h * assets.base_texel_h,
                            .{ .rotation = camera.angle });
                        // zig fmt: on
                        idx += 4;
                        continue;
                    }

                    if (bo.is_wall) {
                        idx += drawWall(idx, bo.x, bo.y, bo.tex_u, bo.tex_v, bo.top_tex_u, bo.top_tex_v);
                        continue;
                    }

                    var x_offset: f32 = 0.0;
                    if (bo.anim_data) |anim_data| {
                        var rect = anim_data.walk_anims[bo.dir][0];

                        if (!std.math.isNan(bo.visual_move_angle)) {
                            bo.dir = @intFromFloat(@mod(@divFloor(bo.visual_move_angle - std.math.pi / 4.0, std.math.pi / 2.0) + 1.0, 2.0));
                            const anim_idx: usize = @intCast(@divFloor(@mod(time, 500), 250));
                            rect = anim_data.walk_anims[bo.dir][anim_idx];
                        }

                        if (time < bo.attack_start + attack_period) {
                            bo.dir = @intFromFloat(@mod(@divFloor(bo.attack_angle - std.math.pi / 4.0, std.math.pi / 2.0) + 1.0, 2.0));
                            const anim_idx: usize = @intCast(@divFloor(@mod(time - bo.attack_start, 300), 150));
                            rect = anim_data.attack_anims[bo.dir][anim_idx];

                            if (anim_idx != 0) {
                                const w = @as(f32, @floatFromInt(rect.w)) * size;

                                if (bo.dir == assets.left_dir) {
                                    x_offset = -assets.padding * size;
                                } else {
                                    x_offset = w / 4.0;
                                }
                            }
                        }

                        tex_u = @floatFromInt(rect.x);
                        tex_v = @floatFromInt(rect.y);
                        tex_w = @floatFromInt(rect.w);
                        tex_h = @floatFromInt(rect.h);
                    }

                    var sink: f32 = 1.0;
                    if (square.tile_type != 0xFFFF) {
                        sink += square.sink;
                    }

                    const w = tex_w * size;
                    const h = tex_h * size / sink;

                    screen_pos.x += x_offset;
                    screen_pos.y += bo.z * -camera.px_per_tile - (h - size * assets.padding);

                    bo.h = h;
                    bo.screen_y = screen_pos.y - 10;
                    bo.screen_x = screen_pos.x - x_offset;

                    if (bo.light_color > 0) {
                        // zig fmt: off
                        drawLight(light_idx, w * bo.light_radius, h * bo.light_radius,
                            screen_pos.x, screen_pos.y + h / 2.0, bo.light_color, bo.light_intensity);
                        // zig fmt: on
                        light_idx += 4;
                    }

                    const is_portal = bo.class == .portal;
                    const name = if (bo.name_override.len > 0) bo.name_override else bo.name;
                    if (name.len > 0 and (bo.show_name or is_portal)) {
                        const text_width = ui.textWidth(16, name, ui.medium_text_type);
                        // zig fmt: off
                        text_idx += drawText(text_idx,
                            screen_pos.x - x_offset - text_width / 2,
                            screen_pos.y - 15,
                            16, name, 0xFFFFFF, 1.0, ui.medium_text_type, .{});
                        // zig fmt: on

                        if (is_portal and map.interactive_id == bo.obj_id) {
                            const enter_text_width = ui.textWidth(16, "Enter", ui.medium_text_type);
                            // zig fmt: off
                            text_idx += drawText(text_idx,
                                screen_pos.x - x_offset - enter_text_width / 2,
                                screen_pos.y + h + 5,
                                16, "Enter", 0xFFFFFF, 1.0, ui.medium_text_type, .{});
                            // zig fmt: on
                        }
                    }

                    // zig fmt: off
                    drawQuad(idx, screen_pos.x - w / 2.0, screen_pos.y, w, h,
                        tex_u * assets.base_texel_w,
                        tex_v * assets.base_texel_h,
                        tex_w * assets.base_texel_w,
                        tex_h * assets.base_texel_h / sink,
                        .{ .texel_mult = 2.0 / size });
                    // zig fmt: on
                    idx += 4;

                    if (!bo.is_enemy)
                        continue;

                    var y_pos: f32 = 5.0 + if (sink != 0) @as(f32, 5.0) else @as(f32, 0.0);

                    // this should be the server's job...
                    if (bo.hp > bo.max_hp)
                        bo.max_hp = bo.hp;

                    if (bo.hp >= 0 and bo.hp < bo.max_hp) {
                        const hp_bar_w = assets.hp_bar_rect.w * assets.atlas_width * 2 * camera.scale;
                        const hp_bar_h = assets.hp_bar_rect.h * assets.atlas_height * 2 * camera.scale;
                        const hp_bar_y = screen_pos.y + h + y_pos;

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - hp_bar_w / 2.0, hp_bar_y, hp_bar_w, hp_bar_h,
                            assets.empty_bar_rect.x, 
                            assets.empty_bar_rect.y, 
                            assets.empty_bar_rect.w, 
                            assets.empty_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        const float_hp: f32 = @floatFromInt(bo.hp);
                        const float_max_hp: f32 = @floatFromInt(bo.max_hp);
                        const hp_perc = 1.0 / (float_hp / float_max_hp);

                        // zig fmt: off
                        drawQuad(idx, screen_pos.x - x_offset - hp_bar_w / 2.0, hp_bar_y, hp_bar_w / hp_perc, hp_bar_h,
                            assets.hp_bar_rect.x, 
                            assets.hp_bar_rect.y, 
                            assets.hp_bar_rect.w / hp_perc, 
                            assets.hp_bar_rect.h,
                            .{ .texel_mult = 0.5 });
                        // zig fmt: on
                        idx += 4;

                        y_pos += 20.0;
                    }
                },
                .projectile => |proj| {
                    if (!camera.visibleInCamera(proj.x, proj.y)) {
                        continue;
                    }

                    const size = camera.size_mult * camera.scale * proj.props.size;
                    const w = proj.tex_w * assets.atlas_width * size;
                    const h = proj.tex_h * assets.atlas_height * size;
                    var screen_pos = camera.rotateAroundCamera(proj.x, proj.y);
                    screen_pos.y += proj.z * -camera.px_per_tile - (h - size * assets.padding);
                    const rotation = proj.props.rotation;
                    // zig fmt: off
                    const angle = -(proj.visual_angle + proj.props.angle_correction + 
                        (if (rotation == 0) 0 else @as(f32, @floatFromInt(time)) / rotation) - camera.angle);

                    drawQuad(idx, screen_pos.x - w / 2.0, screen_pos.y, w, h,
                        proj.tex_u, proj.tex_v, proj.tex_w, proj.tex_h,
                        .{ .texel_mult = 2.0 / size, .rotation = angle });
                    // zig fmt: on
                    idx += 4;
                },
            }
        }

        // zig fmt: off
        // horrible hack for bg light
        drawQuad(idx, 0, 0, camera.screen_width, camera.screen_height,
            assets.wall_backface_uv[0], 
            assets.wall_backface_uv[1], 
            8.0 * assets.base_texel_w,
            8.0 * assets.base_texel_h,
            .{ .flash_color = map.bg_light_color, .flash_strength = 1.0, .alpha_mult = map.getLightIntensity(time) });
        // zig fmt: on
        idx += 4;

        encoder.writeBuffer(gctx.lookupResource(base_vb).?, 0, BaseVertexData, base_vert_data[0..idx]);
        endDraw(encoder, render_pass_info, vb_info, ib_info, pipeline, bind_group, @divFloor(idx, 4) * 6, null);
    }

    if (text_idx != 0) {
        textPass: {
            const vb_info = gctx.lookupResourceInfo(text_vb) orelse break :textPass;
            const pipeline = gctx.lookupResource(text_pipeline) orelse break :textPass;
            const bind_group = gctx.lookupResource(text_bind_group) orelse break :textPass;
            const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
                .view = back_buffer,
                .load_op = .load,
                .store_op = .store,
            }};
            const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            for (ui.status_texts.items) |text| {
                // zig fmt: off
                text_idx += drawText(text_idx, text.screen_x, text.screen_y, 
                    text.size, text.text, text.color, text.alpha, ui.bold_text_type, .{});
                // zig fmt: on
            }

            encoder.writeBuffer(gctx.lookupResource(text_vb).?, 0, TextVertexData, text_vert_data[0..text_idx]);
            endDraw(encoder, render_pass_info, vb_info, ib_info, pipeline, bind_group, @divFloor(text_idx, 4) * 6, null);
        }
    }

    if (light_idx != 0) {
        lightPass: {
            const vb_info = gctx.lookupResourceInfo(light_vb) orelse break :lightPass;
            const pipeline = gctx.lookupResource(light_pipeline) orelse break :lightPass;
            const bind_group = gctx.lookupResource(light_bind_group) orelse break :lightPass;
            const color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
                .view = back_buffer,
                .load_op = .load,
                .store_op = .store,
            }};
            const render_pass_info = zgpu.wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
            };

            encoder.writeBuffer(gctx.lookupResource(light_vb).?, 0, LightVertexData, light_vert_data[0..light_idx]);
            endDraw(encoder, render_pass_info, vb_info, ib_info, pipeline, bind_group, @divFloor(light_idx, 4) * 6, null);
        }
    }
}
