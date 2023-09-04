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
const ui = @import("ui/ui.zig");
const main = @import("main.zig");
const zgui = @import("zgui");

pub const object_attack_period: u32 = 300 * std.time.us_per_ms;

pub const BaseVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    base_color: ui.RGBF32 = ui.RGBF32.fromInt(0),
    base_color_intensity: f32 = 0.0,
    alpha_mult: f32 = 1.0,
    shadow_color: ui.RGBF32 = ui.RGBF32.fromInt(0),
    shadow_texel: [2]f32 = [2]f32{ 0.0, 0.0 },
    text_type: f32 = 0.0,
    distance_factor: f32 = 0.0,
    render_type: f32,
};

pub const GroundVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    left_blend_uv: [2]f32,
    top_blend_uv: [2]f32,
    right_blend_uv: [2]f32,
    bottom_blend_uv: [2]f32,
    base_uv: [2]f32,
    uv_offsets: [2]f32,
};

pub const LightVertexData = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    color: ui.RGBF32,
    intensity: f32,
};

// must be multiples of 16 bytes. be mindful
pub const GroundUniformData = extern struct {
    left_top_mask_uv: [4]f32,
    right_bottom_mask_uv: [4]f32,
};

const quad_render_type = 0.0;
const ui_quad_render_type = 1.0;
const quad_glow_off_render_type = 2.0;
const ui_quad_glow_off_render_type = 3.0;
const text_normal_render_type = 4.0;
const text_drop_shadow_render_type = 5.0;
const text_normal_no_subpixel_render_type = 6.0;
const text_drop_shadow_no_subpixel_render_type = 7.0;

pub var base_pipeline: zgpu.RenderPipelineHandle = .{};
pub var base_bind_group: zgpu.BindGroupHandle = undefined;
pub var ground_pipeline: zgpu.RenderPipelineHandle = .{};
pub var ground_bind_group: zgpu.BindGroupHandle = undefined;
pub var light_pipeline: zgpu.RenderPipelineHandle = .{};
pub var light_bind_group: zgpu.BindGroupHandle = undefined;

pub var base_vb: zgpu.BufferHandle = undefined;
pub var ground_vb: zgpu.BufferHandle = undefined;
pub var light_vb: zgpu.BufferHandle = undefined;

pub var index_buffer: zgpu.BufferHandle = undefined;

pub var base_vert_data: [40000]BaseVertexData = undefined;
pub var ground_vert_data: [40000]GroundVertexData = undefined;
// no nice way of having multiple batches for these
pub var light_vert_data: [80000]LightVertexData = undefined;

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
pub var ui_texture: zgpu.TextureHandle = undefined;
pub var ui_texture_view: zgpu.TextureViewHandle = undefined;
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

pub fn init(gctx: *zgpu.GraphicsContext) void {
    createVertexBuffer(gctx, BaseVertexData, &base_vb, base_vert_data[0..]);
    createVertexBuffer(gctx, GroundVertexData, &ground_vb, ground_vert_data[0..]);
    createVertexBuffer(gctx, LightVertexData, &light_vb, light_vert_data[0..]);

    var index_data: [6000]u16 = undefined;
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
    createTexture(gctx, &ui_texture, &ui_texture_view, assets.ui_atlas);
    createTexture(gctx, &light_texture, &light_texture_view, assets.light_tex);

    sampler = gctx.createSampler(.{});
    linear_sampler = gctx.createSampler(.{ .min_filter = .linear, .mag_filter = .linear });

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

    const light_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.samplerEntry(0, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(1, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(light_bind_group_layout);
    light_bind_group = gctx.createBindGroup(light_bind_group_layout, &.{
        .{ .binding = 0, .sampler_handle = linear_sampler },
        .{ .binding = 1, .texture_view_handle = light_texture_view },
    });

    const base_bind_group_layout = gctx.createBindGroupLayout(&.{
        zgpu.samplerEntry(0, .{ .fragment = true }, .filtering),
        zgpu.samplerEntry(1, .{ .fragment = true }, .filtering),
        zgpu.textureEntry(2, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(3, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(4, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(5, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(6, .{ .fragment = true }, .float, .tvdim_2d, false),
        zgpu.textureEntry(7, .{ .fragment = true }, .float, .tvdim_2d, false),
    });
    defer gctx.releaseResource(base_bind_group_layout);
    base_bind_group = gctx.createBindGroup(base_bind_group_layout, &.{
        .{ .binding = 0, .sampler_handle = sampler },
        .{ .binding = 1, .sampler_handle = linear_sampler },
        .{ .binding = 2, .texture_view_handle = texture_view },
        .{ .binding = 3, .texture_view_handle = ui_texture_view },
        .{ .binding = 4, .texture_view_handle = medium_text_texture_view },
        .{ .binding = 5, .texture_view_handle = medium_italic_text_texture_view },
        .{ .binding = 6, .texture_view_handle = bold_text_texture_view },
        .{ .binding = 7, .texture_view_handle = bold_italic_text_texture_view },
    });

    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            base_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/base.wgsl"), null);
        defer s_mod.release();

        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{
            .format = zgpu.GraphicsContext.swapchain_format,
            .blend = &zgpu.wgpu.BlendState{
                .color = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha },
                .alpha = .{ .src_factor = .src_alpha, .dst_factor = .one_minus_src_alpha },
            },
        }};

        const vertex_attributes = [_]zgpu.wgpu.VertexAttribute{
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "pos"), .shader_location = 0 },
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "uv"), .shader_location = 1 },
            .{ .format = .float32x3, .offset = @offsetOf(BaseVertexData, "base_color"), .shader_location = 2 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "base_color_intensity"), .shader_location = 3 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "alpha_mult"), .shader_location = 4 },
            .{ .format = .float32x3, .offset = @offsetOf(BaseVertexData, "shadow_color"), .shader_location = 5 },
            .{ .format = .float32x2, .offset = @offsetOf(BaseVertexData, "shadow_texel"), .shader_location = 6 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "text_type"), .shader_location = 7 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "distance_factor"), .shader_location = 8 },
            .{ .format = .float32, .offset = @offsetOf(BaseVertexData, "render_type"), .shader_location = 9 },
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
        base_pipeline = gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);
    }

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
            .{ .format = .float32x2, .offset = @offsetOf(GroundVertexData, "uv_offsets"), .shader_location = 7 },
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
        ground_pipeline = gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);
    }

    {
        const pipeline_layout = gctx.createPipelineLayout(&.{
            light_bind_group_layout,
        });
        defer gctx.releaseResource(pipeline_layout);

        const s_mod = zgpu.createWgslShaderModule(gctx.device, @embedFile("./assets/shaders/light.wgsl"), null);
        defer s_mod.release();

        const color_targets = [_]zgpu.wgpu.ColorTargetState{.{
            .format = zgpu.GraphicsContext.swapchain_format,
            .blend = &zgpu.wgpu.BlendState{
                .color = .{ .src_factor = .src_alpha, .dst_factor = .one },
                .alpha = .{ .src_factor = .zero, .dst_factor = .zero },
            },
        }};

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
        light_pipeline = gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);
    }
}

fn drawWall(idx: u16, x: f32, y: f32, atlas_data: assets.AtlasData, top_atlas_data: assets.AtlasData) u16 {
    var idx_new: u16 = 0;
    var atlas_data_new = atlas_data;

    const x_base = (x * camera.cos + y * camera.sin + camera.clip_x) * camera.clip_scale_x;
    const y_base = -(x * -camera.sin + y * camera.cos + camera.clip_y) * camera.clip_scale_y;
    const y_base_top = -(x * -camera.sin + y * camera.cos + camera.clip_y - camera.px_per_tile * camera.scale) * camera.clip_scale_y;

    const x1 = camera.pad_x_cos + camera.pad_x_sin + x_base;
    const x2 = -camera.pad_x_cos + camera.pad_x_sin + x_base;
    const x3 = -camera.pad_x_cos - camera.pad_x_sin + x_base;
    const x4 = camera.pad_x_cos - camera.pad_x_sin + x_base;

    const y1 = camera.pad_y_sin - camera.pad_y_cos + y_base;
    const y2 = -camera.pad_y_sin - camera.pad_y_cos + y_base;
    const y3 = -camera.pad_y_sin + camera.pad_y_cos + y_base;
    const y4 = camera.pad_y_sin + camera.pad_y_cos + y_base;

    const top_y1 = camera.pad_y_sin - camera.pad_y_cos + y_base_top;
    const top_y2 = -camera.pad_y_sin - camera.pad_y_cos + y_base_top;
    const top_y3 = -camera.pad_y_sin + camera.pad_y_cos + y_base_top;
    const top_y4 = camera.pad_y_sin + camera.pad_y_cos + y_base_top;

    const floor_y: u32 = @intFromFloat(@floor(y));
    const floor_x: u32 = @intFromFloat(@floor(x));

    const bound_angle = utils.halfBound(camera.angle);
    const pi_div_2 = std.math.pi / 2.0;
    topSide: {
        if (bound_angle >= pi_div_2 and bound_angle <= std.math.pi or bound_angle >= -std.math.pi and bound_angle <= -pi_div_2) {
            if (!map.validPos(@intCast(floor_x), @intCast(floor_y - 1))) {
                atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
            } else {
                const top_sq = map.squares[(floor_y - 1) * @as(u32, @intCast(map.width)) + floor_x];
                if (top_sq.has_wall)
                    break :topSide;

                if (top_sq.tile_type == 0xFFFF or top_sq.tile_type == 0xFF) {
                    atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                    atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
                }

                // no need to set back atlas_data_new here, nothing can override it prior to this
            }

            drawQuadVerts(
                idx + idx_new,
                x3,
                top_y3,
                x4,
                top_y4,
                x4,
                y4,
                x3,
                y3,
                atlas_data_new,
                .{ .base_color = 0x000000, .base_color_intensity = 0.25 },
            );
            idx_new += 4;
        }
    }

    bottomSide: {
        if (bound_angle <= pi_div_2 and bound_angle >= -pi_div_2) {
            if (!map.validPos(@intCast(floor_x), @intCast(floor_y + 1))) {
                atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
            } else {
                const bottom_sq = map.squares[(floor_y + 1) * @as(u32, @intCast(map.width)) + floor_x];
                if (bottom_sq.has_wall)
                    break :bottomSide;

                if (bottom_sq.tile_type == 0xFFFF or bottom_sq.tile_type == 0xFF) {
                    atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                    atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
                } else {
                    atlas_data_new.tex_u = atlas_data.tex_u;
                    atlas_data_new.tex_v = atlas_data.tex_v;
                }
            }

            drawQuadVerts(
                idx + idx_new,
                x1,
                top_y1,
                x2,
                top_y2,
                x2,
                y2,
                x1,
                y1,
                atlas_data_new,
                .{ .base_color = 0x000000, .base_color_intensity = 0.25 },
            );
            idx_new += 4;
        }
    }

    leftSide: {
        if (bound_angle >= 0 and bound_angle <= std.math.pi) {
            if (!map.validPos(@intCast(floor_x - 1), @intCast(floor_y))) {
                atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
            } else {
                const left_sq = map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x - 1];
                if (left_sq.has_wall)
                    break :leftSide;

                if (left_sq.tile_type == 0xFFFF or left_sq.tile_type == 0xFF) {
                    atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                    atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
                } else {
                    atlas_data_new.tex_u = atlas_data.tex_u;
                    atlas_data_new.tex_v = atlas_data.tex_v;
                }
            }

            drawQuadVerts(
                idx + idx_new,
                x3,
                top_y3,
                x2,
                top_y2,
                x2,
                y2,
                x3,
                y3,
                atlas_data_new,
                .{ .base_color = 0x000000, .base_color_intensity = 0.25 },
            );
            idx_new += 4;
        }
    }

    rightSide: {
        if (bound_angle <= 0 and bound_angle >= -std.math.pi) {
            if (!map.validPos(@intCast(floor_x + 1), @intCast(floor_y))) {
                atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
            } else {
                const right_sq = map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x + 1];
                if (right_sq.has_wall)
                    break :rightSide;

                if (right_sq.tile_type == 0xFFFF or right_sq.tile_type == 0xFF) {
                    atlas_data_new.tex_u = assets.wall_backface_data.tex_u;
                    atlas_data_new.tex_v = assets.wall_backface_data.tex_v;
                } else {
                    atlas_data_new.tex_u = atlas_data.tex_u;
                    atlas_data_new.tex_v = atlas_data.tex_v;
                }
            }

            drawQuadVerts(
                idx + idx_new,
                x4,
                top_y4,
                x1,
                top_y1,
                x1,
                y1,
                x4,
                y4,
                atlas_data_new,
                .{ .base_color = 0x000000, .base_color_intensity = 0.25 },
            );
            idx_new += 4;
        }
    }

    drawQuadVerts(
        idx + idx_new,
        x1,
        top_y1,
        x2,
        top_y2,
        x3,
        top_y3,
        x4,
        top_y4,
        top_atlas_data,
        .{ .base_color = 0x000000, .base_color_intensity = 0.1 },
    );
    idx_new += 4;

    return idx_new;
}

const QuadOptions = struct {
    rotation: f32 = 0.0,
    base_color: i32 = -1,
    base_color_intensity: f32 = 0.0,
    alpha_mult: f32 = 1.0,
    shadow_texel_mult: f32 = 0.0,
    shadow_color: i32 = -1,
    force_glow_off: bool = false,
    ui_quad: bool = false,
};

fn drawQuad(
    idx: u16,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    atlas_data: assets.AtlasData,
    opts: QuadOptions,
) void {
    var base_rgb = ui.RGBF32.fromValues(0.0, 0.0, 0.0);
    if (opts.base_color != -1)
        base_rgb = ui.RGBF32.fromInt(opts.base_color);

    var shadow_rgb = ui.RGBF32.fromValues(0.0, 0.0, 0.0);
    if (opts.shadow_color != -1)
        shadow_rgb = ui.RGBF32.fromInt(opts.shadow_color);

    const texel_w = assets.base_texel_w * opts.shadow_texel_mult;
    const texel_h = assets.base_texel_h * opts.shadow_texel_mult;
    const shadow_texel = [2]f32{ texel_w, texel_h };

    const scaled_w = w * camera.clip_scale_x;
    const scaled_h = h * camera.clip_scale_y;
    const scaled_x = (x - camera.screen_width / 2.0 + w / 2.0) * camera.clip_scale_x;
    const scaled_y = -(y - camera.screen_height / 2.0 + h / 2.0) * camera.clip_scale_y;

    const cos_angle = @cos(opts.rotation);
    const sin_angle = @sin(opts.rotation);
    const x_cos = cos_angle * scaled_w * 0.5;
    const x_sin = sin_angle * scaled_w * 0.5;
    const y_cos = cos_angle * scaled_h * 0.5;
    const y_sin = sin_angle * scaled_h * 0.5;

    var render_type: f32 = quad_render_type;

    if (settings.enable_glow and !opts.force_glow_off) {
        render_type = if (opts.ui_quad) ui_quad_render_type else quad_render_type;
    } else {
        render_type = if (opts.ui_quad) ui_quad_glow_off_render_type else quad_glow_off_render_type;
    }

    base_vert_data[idx] = BaseVertexData{
        .pos = [2]f32{ -x_cos + x_sin + scaled_x, -y_sin - y_cos + scaled_y },
        .uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v + atlas_data.tex_h },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 1] = BaseVertexData{
        .pos = [2]f32{ x_cos + x_sin + scaled_x, y_sin - y_cos + scaled_y },
        .uv = [2]f32{ atlas_data.tex_u + atlas_data.tex_w, atlas_data.tex_v + atlas_data.tex_h },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 2] = BaseVertexData{
        .pos = [2]f32{ x_cos - x_sin + scaled_x, y_sin + y_cos + scaled_y },
        .uv = [2]f32{ atlas_data.tex_u + atlas_data.tex_w, atlas_data.tex_v },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 3] = BaseVertexData{
        .pos = [2]f32{ -x_cos - x_sin + scaled_x, -y_sin + y_cos + scaled_y },
        .uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };
}

fn drawQuadVerts(
    idx: u16,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    x3: f32,
    y3: f32,
    x4: f32,
    y4: f32,
    atlas_data: assets.AtlasData,
    opts: QuadOptions,
) void {
    var base_rgb = ui.RGBF32.fromValues(-1.0, -1.0, -1.0);
    if (opts.base_color != -1)
        base_rgb = ui.RGBF32.fromInt(opts.base_color);

    var shadow_rgb = ui.RGBF32.fromValues(0.0, 0.0, 0.0);
    if (opts.shadow_color != -1)
        shadow_rgb = ui.RGBF32.fromInt(opts.shadow_color);

    const texel_w = assets.base_texel_w * opts.shadow_texel_mult;
    const texel_h = assets.base_texel_h * opts.shadow_texel_mult;
    const shadow_texel = [2]f32{ texel_w, texel_h };

    const render_type: f32 = if (settings.enable_glow)
        quad_render_type
    else
        quad_glow_off_render_type;

    base_vert_data[idx] = BaseVertexData{
        .pos = [2]f32{ x1, y1 },
        .uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 1] = BaseVertexData{
        .pos = [2]f32{ x2, y2 },
        .uv = [2]f32{ atlas_data.tex_u + atlas_data.tex_w, atlas_data.tex_v },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 2] = BaseVertexData{
        .pos = [2]f32{ x3, y3 },
        .uv = [2]f32{ atlas_data.tex_u + atlas_data.tex_w, atlas_data.tex_v + atlas_data.tex_h },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };

    base_vert_data[idx + 3] = BaseVertexData{
        .pos = [2]f32{ x4, y4 },
        .uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v + atlas_data.tex_h },
        .base_color = base_rgb,
        .base_color_intensity = opts.base_color_intensity,
        .alpha_mult = opts.alpha_mult,
        .shadow_color = shadow_rgb,
        .shadow_texel = shadow_texel,
        .render_type = render_type,
    };
}

fn drawSquare(
    idx: u16,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    x3: f32,
    y3: f32,
    x4: f32,
    y4: f32,
    atlas_data: assets.AtlasData,
    u_offset: f32,
    v_offset: f32,
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
        .uv = [2]f32{ atlas_data.tex_w, atlas_data.tex_h },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .uv_offsets = [2]f32{ u_offset, v_offset },
    };

    ground_vert_data[idx + 1] = GroundVertexData{
        .pos = [2]f32{ x2, y2 },
        .uv = [2]f32{ 0, atlas_data.tex_h },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .uv_offsets = [2]f32{ u_offset, v_offset },
    };

    ground_vert_data[idx + 2] = GroundVertexData{
        .pos = [2]f32{ x3, y3 },
        .uv = [2]f32{ 0, 0 },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .uv_offsets = [2]f32{ u_offset, v_offset },
    };

    ground_vert_data[idx + 3] = GroundVertexData{
        .pos = [2]f32{ x4, y4 },
        .uv = [2]f32{ atlas_data.tex_w, 0 },
        .left_blend_uv = [2]f32{ left_blend_u, left_blend_v },
        .top_blend_uv = [2]f32{ top_blend_u, top_blend_v },
        .right_blend_uv = [2]f32{ right_blend_u, right_blend_v },
        .bottom_blend_uv = [2]f32{ bottom_blend_u, bottom_blend_v },
        .base_uv = [2]f32{ atlas_data.tex_u, atlas_data.tex_v },
        .uv_offsets = [2]f32{ u_offset, v_offset },
    };
}

fn drawText(idx: u16, x: f32, y: f32, text_data: ui.TextData) u16 {
    const rgb = ui.RGBF32.fromInt(text_data.color);
    const shadow_rgb = ui.RGBF32.fromInt(text_data.shadow_color);

    const size_scale = text_data.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
    const line_height = assets.CharacterData.line_height * assets.CharacterData.size * size_scale;

    var idx_new = idx;
    const x_base = x - camera.screen_width / 2.0;
    var x_pointer = x_base;
    var y_pointer = y - camera.screen_height / 2.0 + line_height;
    for (text_data.text) |char| {
        const char_data = switch (text_data.text_type) {
            .medium => assets.medium_chars[char],
            .medium_italic => assets.medium_italic_chars[char],
            .bold => assets.bold_chars[char],
            .bold_italic => assets.bold_italic_chars[char],
        };

        const shadow_texel_size = [2]f32{
            text_data.shadow_texel_offset_mult / char_data.atlas_w,
            text_data.shadow_texel_offset_mult / char_data.atlas_h,
        };

        const next_x_pointer = x_pointer + char_data.x_advance * size_scale;
        if (char == '\n' or next_x_pointer - x_base > text_data.max_width) {
            x_pointer = x_base;
            y_pointer += line_height;
            continue;
        }

        if (char_data.tex_w <= 0) {
            x_pointer += char_data.x_advance * size_scale;
            continue;
        }

        const w = char_data.width * size_scale;
        const h = char_data.height * size_scale;
        const scaled_x = (x_pointer + char_data.x_offset * size_scale + w / 2) * camera.clip_scale_x;
        const scaled_y = -(y_pointer - char_data.y_offset * size_scale - h / 2) * camera.clip_scale_y;
        const scaled_w = w * camera.clip_scale_x;
        const scaled_h = h * camera.clip_scale_y;
        const px_range = assets.CharacterData.px_range / camera.scale;
        const text_type: f32 = @floatFromInt(@intFromEnum(text_data.text_type));
        const render_type: f32 = if (text_data.shadow_texel_offset_mult > 0.0)
            text_drop_shadow_render_type
        else
            text_normal_render_type;

        x_pointer = next_x_pointer;

        base_vert_data[idx_new] = BaseVertexData{
            .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_h * 0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u, char_data.tex_v },
            .base_color = rgb,
            .base_color_intensity = 1.0,
            .alpha_mult = text_data.alpha,
            .shadow_color = shadow_rgb,
            .shadow_texel = shadow_texel_size,
            .text_type = text_type,
            .distance_factor = size_scale * px_range,
            .render_type = render_type,
        };

        base_vert_data[idx_new + 1] = BaseVertexData{
            .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * 0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u + char_data.tex_w, char_data.tex_v },
            .base_color = rgb,
            .base_color_intensity = 1.0,
            .alpha_mult = text_data.alpha,
            .shadow_color = shadow_rgb,
            .shadow_texel = shadow_texel_size,
            .text_type = text_type,
            .distance_factor = size_scale * px_range,
            .render_type = render_type,
        };

        base_vert_data[idx_new + 2] = BaseVertexData{
            .pos = [2]f32{ scaled_w * 0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u + char_data.tex_w, char_data.tex_v + char_data.tex_h },
            .base_color = rgb,
            .base_color_intensity = 1.0,
            .alpha_mult = text_data.alpha,
            .shadow_color = shadow_rgb,
            .shadow_texel = shadow_texel_size,
            .text_type = text_type,
            .distance_factor = size_scale * px_range,
            .render_type = render_type,
        };

        base_vert_data[idx_new + 3] = BaseVertexData{
            .pos = [2]f32{ scaled_w * -0.5 + scaled_x, scaled_h * -0.5 + scaled_y },
            .uv = [2]f32{ char_data.tex_u, char_data.tex_v + char_data.tex_h },
            .base_color = rgb,
            .base_color_intensity = 1.0,
            .alpha_mult = text_data.alpha,
            .shadow_color = shadow_rgb,
            .shadow_texel = shadow_texel_size,
            .text_type = text_type,
            .distance_factor = size_scale * px_range,
            .render_type = render_type,
        };
        idx_new += 4;
    }

    return idx_new - idx;
}

fn drawNineSlice(
    idx: u16,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    image_data: ui.NineSliceImageData,
) void {
    const top_left = image_data.topLeft();
    const top_left_w = top_left.texWRaw();
    const top_left_h = top_left.texHRaw();
    drawQuad(
        idx,
        x,
        y,
        top_left_w,
        top_left_h,
        top_left,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const top_right = image_data.topRight();
    const top_right_w = top_right.texWRaw();
    drawQuad(
        idx + 4,
        x + (w - top_right_w),
        y,
        top_right_w,
        top_right.texHRaw(),
        top_right,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const bottom_left = image_data.bottomLeft();
    const bottom_left_w = bottom_left.texWRaw();
    const bottom_left_h = bottom_left.texHRaw();
    drawQuad(
        idx + 2 * 4,
        x,
        y + (h - bottom_left_h),
        bottom_left.texWRaw(),
        bottom_left_h,
        bottom_left,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const bottom_right = image_data.bottomRight();
    const bottom_right_w = bottom_right.texWRaw();
    const bottom_right_h = bottom_right.texHRaw();
    drawQuad(
        idx + 3 * 4,
        x + (w - bottom_right_w),
        y + (h - bottom_right_h),
        bottom_right_w,
        bottom_right_h,
        bottom_right,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const top_center = image_data.topCenter();
    drawQuad(
        idx + 4 * 4,
        x + top_left_w,
        y,
        w - top_left_w - top_right_w,
        top_center.texHRaw(),
        top_center,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const bottom_center = image_data.bottomCenter();
    const bottom_center_h = bottom_center.texHRaw();
    drawQuad(
        idx + 5 * 4,
        x + bottom_left_w,
        y + (h - bottom_center_h),
        w - bottom_left_w - bottom_right_w,
        bottom_center_h,
        bottom_center,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const middle_center = image_data.middleCenter();
    drawQuad(
        idx + 6 * 4,
        x + top_left_w,
        y + top_left_h,
        w - top_left_w - top_right_w,
        h - top_left_h - bottom_left_h,
        middle_center,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const middle_left = image_data.middleLeft();
    drawQuad(
        idx + 7 * 4,
        x,
        y + top_left_h,
        middle_left.texWRaw(),
        h - top_left_h - bottom_left_h,
        middle_left,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );

    const middle_right = image_data.middleRight();
    const middle_right_w = middle_right.texWRaw();
    drawQuad(
        idx + 8 * 4,
        x + (w - middle_right_w),
        y + top_left_h,
        middle_right_w,
        h - top_left_h - bottom_left_h,
        middle_right,
        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
    );
}

fn drawLight(idx: u16, w: f32, h: f32, x: f32, y: f32, color: i32, intensity: f32) void {
    const rgb = ui.RGBF32.fromInt(color);

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

inline fn endBaseDraw(
    gctx: *zgpu.GraphicsContext,
    load_render_pass_info: zgpu.wgpu.RenderPassDescriptor,
    encoder: zgpu.wgpu.CommandEncoder,
    vb_info: zgpu.BufferInfo,
    ib_info: zgpu.BufferInfo,
    pipeline: zgpu.wgpu.RenderPipeline,
    bind_group: zgpu.wgpu.BindGroup,
) void {
    encoder.writeBuffer(
        gctx.lookupResource(base_vb).?,
        0,
        BaseVertexData,
        base_vert_data[0..40000],
    );
    endDraw(
        encoder,
        load_render_pass_info,
        vb_info,
        ib_info,
        pipeline,
        bind_group,
        6000,
        null,
    );
}

pub fn draw(time: i64, gctx: *zgpu.GraphicsContext, back_buffer: zgpu.wgpu.TextureView, encoder: zgpu.wgpu.CommandEncoder) void {
    while (!map.object_lock.tryLock()) {}
    defer map.object_lock.unlock();

    const ib_info = gctx.lookupResourceInfo(index_buffer) orelse return;

    const clear_color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
        .view = back_buffer,
        .load_op = .clear,
        .store_op = .store,
    }};
    const clear_render_pass_info = zgpu.wgpu.RenderPassDescriptor{
        .color_attachment_count = clear_color_attachments.len,
        .color_attachments = &clear_color_attachments,
    };

    const load_color_attachments = [_]zgpu.wgpu.RenderPassColorAttachment{.{
        .view = back_buffer,
        .load_op = .load,
        .store_op = .store,
    }};
    const load_render_pass_info = zgpu.wgpu.RenderPassDescriptor{
        .color_attachment_count = load_color_attachments.len,
        .color_attachments = &load_color_attachments,
    };

    var light_idx: u16 = 0;

    const no_in_game_render = !main.tick_frame or !map.validPos(@intFromFloat(camera.x), @intFromFloat(camera.y));
    inGamePass: {
        if (no_in_game_render)
            break :inGamePass;

        groundPass: {
            const vb_info = gctx.lookupResourceInfo(ground_vb) orelse break :groundPass;
            const pipeline = gctx.lookupResource(ground_pipeline) orelse break :groundPass;
            const bind_group = gctx.lookupResource(ground_bind_group) orelse break :groundPass;

            const mem = gctx.uniformsAllocate(GroundUniformData, 1);
            mem.slice[0] = .{
                .left_top_mask_uv = assets.left_top_mask_uv,
                .right_bottom_mask_uv = assets.right_bottom_mask_uv,
            };

            var first: bool = false;
            var square_idx: u16 = 0;
            for (camera.min_y..camera.max_y) |y| {
                for (camera.min_x..camera.max_x) |x| {
                    if (square_idx == 40000) {
                        encoder.writeBuffer(
                            gctx.lookupResource(ground_vb).?,
                            0,
                            GroundVertexData,
                            ground_vert_data[0..40000],
                        );
                        endDraw(
                            encoder,
                            if (first) clear_render_pass_info else load_render_pass_info,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                            6000,
                            &.{mem.offset},
                        );
                        square_idx = 0;
                        first = false;
                    }

                    const dx = camera.x - @as(f32, @floatFromInt(x)) - 0.5;
                    const dy = camera.y - @as(f32, @floatFromInt(y)) - 0.5;
                    if (dx * dx + dy * dy > camera.max_dist_sq)
                        continue;

                    const map_square_idx = x + y * @as(usize, @intCast(map.width));
                    const square = map.squares[map_square_idx];
                    if (square.tile_type == 0xFFFF or square.tile_type == 0xFF)
                        continue;

                    const screen_pos = camera.rotateAroundCamera(square.x, square.y);
                    const screen_x = screen_pos.x - camera.screen_width / 2.0;
                    const screen_y = -(screen_pos.y - camera.screen_height / 2.0);

                    if (settings.enable_lights and square.light_color > 0) {
                        drawLight(
                            light_idx,
                            camera.px_per_tile * square.light_radius,
                            camera.px_per_tile * square.light_radius,
                            screen_pos.x,
                            screen_pos.y,
                            square.light_color,
                            square.light_intensity,
                        );
                        light_idx += 4;
                    }

                    var u_offset = square.u_offset;
                    var v_offset = square.v_offset;
                    const float_time_ms = @as(f32, @floatFromInt(time)) / std.time.us_per_ms;
                    switch (square.anim_type) {
                        .wave => {
                            u_offset += @sin(square.anim_dx * float_time_ms / 1000.0) * assets.base_texel_w;
                            v_offset += @sin(square.anim_dy * float_time_ms / 1000.0) * assets.base_texel_h;
                        },
                        .flow => {
                            u_offset += (square.anim_dx * float_time_ms / 1000.0) * assets.base_texel_w;
                            v_offset += (square.anim_dy * float_time_ms / 1000.0) * assets.base_texel_h;
                        },
                        else => {},
                    }

                    const x_cos = camera.pad_x_cos;
                    const x_sin = camera.pad_x_sin;
                    const y_cos = camera.pad_y_cos;
                    const y_sin = camera.pad_y_sin;
                    const clip_x = screen_x * camera.clip_scale_x;
                    const clip_y = screen_y * camera.clip_scale_y;
                    drawSquare(
                        square_idx,
                        x_cos + x_sin + clip_x,
                        y_sin - y_cos + clip_y,
                        -x_cos + x_sin + clip_x,
                        -y_sin - y_cos + clip_y,
                        -x_cos - x_sin + clip_x,
                        -y_sin + y_cos + clip_y,
                        x_cos - x_sin + clip_x,
                        y_sin + y_cos + clip_y,
                        square.atlas_data,
                        u_offset,
                        v_offset,
                        square.left_blend_u,
                        square.left_blend_v,
                        square.top_blend_u,
                        square.top_blend_v,
                        square.right_blend_u,
                        square.right_blend_v,
                        square.bottom_blend_u,
                        square.bottom_blend_v,
                    );
                    square_idx += 4;
                }
            }

            if (square_idx > 0) {
                encoder.writeBuffer(
                    gctx.lookupResource(ground_vb).?,
                    0,
                    GroundVertexData,
                    ground_vert_data[0..square_idx],
                );
                endDraw(
                    encoder,
                    if (first) clear_render_pass_info else load_render_pass_info,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                    @divFloor(square_idx, 4) * 6,
                    &.{mem.offset},
                );
            }
        }

        normalPass: {
            if (map.entities.capacity <= 0)
                break :normalPass;

            const vb_info = gctx.lookupResourceInfo(base_vb) orelse break :normalPass;
            const pipeline = gctx.lookupResource(base_pipeline) orelse break :normalPass;
            const bind_group = gctx.lookupResource(base_bind_group) orelse break :normalPass;

            var idx: u16 = 0;
            for (map.entities.items()) |*en| {
                switch (en.*) {
                    .player => |*player| {
                        if (!camera.visibleInCamera(player.x, player.y)) {
                            continue;
                        }

                        const size = camera.size_mult * camera.scale * player.size;

                        var action: u8 = assets.stand_action;
                        var float_period: f32 = 0.0;

                        if (time < player.attack_start + player.attack_period) {
                            player.facing = player.attack_angle_raw;
                            const time_dt: f32 = @floatFromInt(time - player.attack_start);
                            float_period = @as(f32, @floatFromInt(player.attack_period));
                            float_period = @mod(time_dt, float_period) / float_period;
                            action = assets.attack_action;
                        } else if (!std.math.isNan(player.move_angle)) {
                            const walk_period = 3.5 * std.time.us_per_ms / player.moveSpeedMultiplier();
                            const float_time: f32 = @floatFromInt(time);
                            float_period = @mod(float_time, walk_period) / walk_period;
                            player.facing = player.move_angle_camera_included;
                            action = assets.walk_action;
                        }

                        const angle = utils.halfBound(player.facing - camera.angle_unbound);
                        const pi_over_4 = std.math.pi / 4.0;
                        const angle_div = (angle / pi_over_4) + 4;

                        var sec: u8 = if (std.math.isNan(angle_div)) 0 else @as(u8, @intFromFloat(@round(angle_div))) % 8;

                        sec = switch (sec) {
                            0, 7 => assets.left_dir,
                            1, 2 => assets.up_dir,
                            3, 4 => assets.right_dir,
                            5, 6 => assets.down_dir,
                            else => unreachable,
                        };

                        const capped_period = @max(0, @min(0.99999, float_period)) * 2.0; // 2 walk cycle frames so * 2
                        const anim_idx: usize = @intFromFloat(capped_period);

                        var atlas_data = switch (action) {
                            assets.walk_action => player.anim_data.walk_anims[sec][1 + anim_idx], // offset by 1 to start at walk frame instead of idle
                            assets.attack_action => player.anim_data.attack_anims[sec][anim_idx],
                            assets.stand_action => player.anim_data.walk_anims[sec][0],
                            else => unreachable,
                        };

                        var x_offset: f32 = 0.0;
                        if (action == assets.attack_action and anim_idx == 1) {
                            const w = atlas_data.texWRaw() * size;
                            if (sec == assets.left_dir) {
                                x_offset = -assets.padding * size;
                            } else {
                                x_offset = w / 4.0;
                            }
                        }

                        const square = player.getSquare();
                        var sink: f32 = 1.0;
                        if (square.tile_type != 0xFFFF) {
                            sink += square.sink;
                        }

                        atlas_data.tex_h /= sink;

                        const w = atlas_data.texWRaw() * size;
                        const h = atlas_data.texHRaw() * size;

                        var screen_pos = camera.rotateAroundCamera(player.x, player.y);
                        screen_pos.x += x_offset;
                        screen_pos.y += player.z * -camera.px_per_tile - (h - size * assets.padding);

                        var alpha_mult: f32 = 1.0;
                        if (player.condition.invisible)
                            alpha_mult = 0.6;

                        player.screen_y = screen_pos.y - 30; // account for name
                        player.screen_x = screen_pos.x - x_offset;

                        if (settings.enable_lights and player.light_color > 0) {
                            drawLight(
                                light_idx,
                                w * player.light_radius,
                                h * player.light_radius,
                                screen_pos.x,
                                screen_pos.y,
                                player.light_color,
                                player.light_intensity,
                            );
                            light_idx += 4;
                        }

                        const name = if (player.name_override.len > 0) player.name_override else player.name;
                        if (name.len > 0) {
                            const text_data = ui.TextData{
                                .text = name,
                                .text_type = .bold,
                                .size = 16,
                                .color = 0xFCDF00,
                                .max_width = 200,
                                .backing_buffer = &[0]u8{},
                            };

                            idx += drawText(
                                idx,
                                screen_pos.x - x_offset - text_data.width() / 2,
                                screen_pos.y - text_data.height(),
                                text_data,
                            );
                        }

                        drawQuad(
                            idx,
                            screen_pos.x - w / 2.0,
                            screen_pos.y,
                            w,
                            h,
                            atlas_data,
                            .{ .shadow_texel_mult = 2.0 / size, .alpha_mult = alpha_mult },
                        );
                        idx += 4;

                        if (idx == 40000) {
                            endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                            idx = 0;
                        }

                        // todo make sink calculate actual values based on h, pad, etc
                        var y_pos: f32 = 5.0 + if (sink != 1.0) @as(f32, 15.0) else @as(f32, 0.0);

                        const pad_scale_obj = assets.padding * size * camera.scale;
                        const pad_scale_bar = assets.padding * 2 * camera.scale;
                        if (player.hp >= 0 and player.hp < player.max_hp) {
                            const hp_bar_w = assets.hp_bar_data.texWRaw() * 2 * camera.scale;
                            const hp_bar_h = assets.hp_bar_data.texHRaw() * 2 * camera.scale;
                            const hp_bar_y = screen_pos.y + h - pad_scale_obj + y_pos;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - hp_bar_w / 2.0,
                                hp_bar_y,
                                hp_bar_w,
                                hp_bar_h,
                                assets.empty_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            const float_hp: f32 = @floatFromInt(player.hp);
                            const float_max_hp: f32 = @floatFromInt(player.max_hp);
                            const hp_perc = 1.0 / (float_hp / float_max_hp);

                            var hp_bar_data = assets.hp_bar_data;
                            hp_bar_data.tex_w /= hp_perc;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - hp_bar_w / 2.0,
                                hp_bar_y,
                                hp_bar_w / hp_perc,
                                hp_bar_h,
                                hp_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            y_pos += hp_bar_h - pad_scale_bar;
                        }

                        if (player.mp >= 0 and player.mp < player.max_mp) {
                            const mp_bar_w = assets.mp_bar_data.texWRaw() * 2 * camera.scale;
                            const mp_bar_h = assets.mp_bar_data.texHRaw() * 2 * camera.scale;
                            const mp_bar_y = screen_pos.y + h - pad_scale_obj + y_pos;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - mp_bar_w / 2.0,
                                mp_bar_y,
                                mp_bar_w,
                                mp_bar_h,
                                assets.empty_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            const float_mp: f32 = @floatFromInt(player.mp);
                            const float_max_mp: f32 = @floatFromInt(player.max_mp);
                            const mp_perc = 1.0 / (float_mp / float_max_mp);

                            var mp_bar_data = assets.mp_bar_data;
                            mp_bar_data.tex_w /= mp_perc;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - mp_bar_w / 2.0,
                                mp_bar_y,
                                mp_bar_w / mp_perc,
                                mp_bar_h,
                                mp_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            y_pos += mp_bar_h - pad_scale_bar;
                        }
                    },
                    .object => |*bo| {
                        if (!camera.visibleInCamera(bo.x, bo.y)) {
                            continue;
                        }

                        var screen_pos = camera.rotateAroundCamera(bo.x, bo.y);
                        const size = camera.size_mult * camera.scale * bo.size;

                        const square = bo.getSquare();
                        if (bo.draw_on_ground) {
                            const tile_size = @as(f32, camera.px_per_tile) * camera.scale;
                            drawQuad(
                                idx,
                                screen_pos.x - tile_size / 2.0,
                                screen_pos.y - tile_size / 2.0,
                                tile_size,
                                tile_size,
                                bo.atlas_data,
                                .{ .rotation = camera.angle },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            continue;
                        }

                        if (bo.is_wall) {
                            idx += drawWall(idx, bo.x, bo.y, bo.atlas_data, bo.top_atlas_data);
                            continue;
                        }

                        var action: u8 = assets.stand_action;
                        var float_period: f32 = 0.0;

                        if (time < bo.attack_start + object_attack_period) {
                            // if(!bo.dont_face_attacks){
                            bo.facing = bo.attack_angle;
                            // }
                            const time_dt: f32 = @floatFromInt(time - bo.attack_start);
                            float_period = @mod(time_dt, object_attack_period) / object_attack_period;
                            action = assets.attack_action;
                        } else if (!std.math.isNan(bo.move_angle)) {
                            var move_period = 0.5 / utils.distSqr(bo.tick_x, bo.tick_y, bo.target_x, bo.target_y);
                            move_period += 400 - @mod(move_period, 400);
                            const float_time = @as(f32, @floatFromInt(time)) / std.time.us_per_ms;
                            float_period = @mod(float_time, move_period) / move_period;
                            // if(!bo.dont_face_attacks){
                            bo.facing = bo.move_angle;
                            // }
                            action = assets.walk_action;
                        }

                        const angle = utils.halfBound(bo.facing);
                        const pi_over_4 = std.math.pi / 4.0;
                        const angle_div = @divFloor(angle, pi_over_4);

                        var sec: u8 = if (std.math.isNan(angle_div)) 0 else @as(u8, @intFromFloat(angle_div + 4)) % 8;

                        sec = switch (sec) {
                            0, 1, 6, 7 => assets.left_dir,
                            2, 3, 4, 5 => assets.right_dir,
                            else => unreachable,
                        };

                        // 2 frames so multiply by 2
                        const capped_period = @max(0, @min(0.99999, float_period)) * 2.0; // 2 walk cycle frames so * 2
                        const anim_idx: usize = @intFromFloat(capped_period);

                        var atlas_data = bo.atlas_data;
                        var x_offset: f32 = 0.0;
                        if (bo.anim_data) |anim_data| {
                            atlas_data = switch (action) {
                                assets.walk_action => anim_data.walk_anims[sec][1 + anim_idx], // offset by 1 to start at walk frame instead of idle
                                assets.attack_action => anim_data.attack_anims[sec][anim_idx],
                                assets.stand_action => anim_data.walk_anims[sec][0],
                                else => unreachable,
                            };

                            if (action == assets.attack_action and anim_idx == 1) {
                                const w = atlas_data.texWRaw() * size;
                                if (sec == assets.left_dir) {
                                    x_offset = -assets.padding * size;
                                } else {
                                    x_offset = w / 4.0;
                                }
                            }
                        }

                        var sink: f32 = 1.0;
                        if (square.tile_type != 0xFFFF) {
                            sink += square.sink;
                        }

                        atlas_data.tex_h /= sink;

                        const w = atlas_data.texWRaw() * size;
                        const h = atlas_data.texHRaw() * size;

                        screen_pos.x += x_offset;
                        screen_pos.y += bo.z * -camera.px_per_tile - (h - size * assets.padding);

                        var alpha_mult: f32 = 1.0;
                        if (bo.condition.invisible)
                            alpha_mult = 0.6;

                        bo.screen_y = screen_pos.y - 10;
                        bo.screen_x = screen_pos.x - x_offset;

                        if (settings.enable_lights and bo.light_color > 0) {
                            drawLight(
                                light_idx,
                                w * bo.light_radius,
                                h * bo.light_radius,
                                screen_pos.x,
                                screen_pos.y + h / 2.0,
                                bo.light_color,
                                bo.light_intensity,
                            );
                            light_idx += 4;
                        }

                        const is_portal = bo.class == .portal;
                        const name = if (bo.name_override.len > 0) bo.name_override else bo.name;
                        if (name.len > 0 and (bo.show_name or is_portal)) {
                            const text_data = ui.TextData{
                                .text = name,
                                .text_type = .bold,
                                .size = 16,
                                .backing_buffer = &[0]u8{},
                            };

                            idx += drawText(
                                idx,
                                screen_pos.x - x_offset - text_data.width() / 2,
                                screen_pos.y - text_data.height(),
                                text_data,
                            );

                            if (is_portal and map.interactive_id.load(.Acquire) == bo.obj_id) {
                                const enter_text_data = ui.TextData{
                                    .text = @constCast("Enter"), // meh
                                    .text_type = .bold,
                                    .size = 16,
                                    .backing_buffer = &[0]u8{},
                                };

                                idx += drawText(
                                    idx,
                                    screen_pos.x - x_offset - enter_text_data.width() / 2,
                                    screen_pos.y + h + 5,
                                    enter_text_data,
                                );
                            }
                        }

                        drawQuad(
                            idx,
                            screen_pos.x - w / 2.0,
                            screen_pos.y,
                            w,
                            h,
                            atlas_data,
                            .{ .shadow_texel_mult = 2.0 / size, .alpha_mult = alpha_mult },
                        );
                        idx += 4;

                        if (idx == 40000) {
                            endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                            idx = 0;
                        }

                        if (!bo.is_enemy)
                            continue;

                        var y_pos: f32 = 5.0 + if (sink != 1.0) @as(f32, 15.0) else @as(f32, 0.0);

                        const pad_scale_obj = assets.padding * size * camera.scale;
                        const pad_scale_bar = assets.padding * 2 * camera.scale;
                        if (bo.hp >= 0 and bo.hp < bo.max_hp) {
                            const hp_bar_w = assets.hp_bar_data.texWRaw() * 2 * camera.scale;
                            const hp_bar_h = assets.hp_bar_data.texHRaw() * 2 * camera.scale;
                            const hp_bar_y = screen_pos.y + h - pad_scale_obj + y_pos;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - hp_bar_w / 2.0,
                                hp_bar_y,
                                hp_bar_w,
                                hp_bar_h,
                                assets.empty_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            const float_hp: f32 = @floatFromInt(bo.hp);
                            const float_max_hp: f32 = @floatFromInt(bo.max_hp);
                            const hp_perc = 1.0 / (float_hp / float_max_hp);
                            var hp_bar_data = assets.hp_bar_data;
                            hp_bar_data.tex_w /= hp_perc;

                            drawQuad(
                                idx,
                                screen_pos.x - x_offset - hp_bar_w / 2.0,
                                hp_bar_y,
                                hp_bar_w / hp_perc,
                                hp_bar_h,
                                hp_bar_data,
                                .{ .shadow_texel_mult = 0.5, .force_glow_off = true },
                            );
                            idx += 4;

                            if (idx == 40000) {
                                endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                                idx = 0;
                            }

                            y_pos += hp_bar_h - pad_scale_bar;
                        }
                    },
                    .projectile => |proj| {
                        if (!camera.visibleInCamera(proj.x, proj.y)) {
                            continue;
                        }

                        const size = camera.size_mult * camera.scale * proj.props.size;
                        const w = proj.atlas_data.texWRaw() * size;
                        const h = proj.atlas_data.texHRaw() * size;
                        var screen_pos = camera.rotateAroundCamera(proj.x, proj.y);
                        screen_pos.y += proj.z * -camera.px_per_tile - (h - size * assets.padding);
                        const rotation = proj.props.rotation;
                        const angle = -(proj.visual_angle + proj.props.angle_correction +
                            (if (rotation == 0) 0 else @as(f32, @floatFromInt(time)) / rotation) - camera.angle);

                        drawQuad(
                            idx,
                            screen_pos.x - w / 2.0,
                            screen_pos.y,
                            w,
                            h,
                            proj.atlas_data,
                            .{ .shadow_texel_mult = 2.0 / size, .rotation = angle, .force_glow_off = true },
                        );
                        idx += 4;

                        if (idx == 40000) {
                            endBaseDraw(gctx, load_render_pass_info, encoder, vb_info, ib_info, pipeline, bind_group);
                            idx = 0;
                        }
                    },
                }
            }

            if (settings.enable_lights) {
                drawQuad(
                    idx,
                    0,
                    0,
                    camera.screen_width,
                    camera.screen_height,
                    assets.wall_backface_data,
                    .{ .base_color = map.bg_light_color, .base_color_intensity = 1.0, .alpha_mult = map.getLightIntensity(time) },
                );
                idx += 4;
            }

            encoder.writeBuffer(
                gctx.lookupResource(base_vb).?,
                0,
                BaseVertexData,
                base_vert_data[0..idx],
            );
            endDraw(
                encoder,
                load_render_pass_info,
                vb_info,
                ib_info,
                pipeline,
                bind_group,
                @divFloor(idx, 4) * 6,
                null,
            );
        }

        if (settings.enable_lights and light_idx != 0) {
            lightPass: {
                const vb_info = gctx.lookupResourceInfo(light_vb) orelse break :lightPass;
                const pipeline = gctx.lookupResource(light_pipeline) orelse break :lightPass;
                const bind_group = gctx.lookupResource(light_bind_group) orelse break :lightPass;

                encoder.writeBuffer(
                    gctx.lookupResource(light_vb).?,
                    0,
                    LightVertexData,
                    light_vert_data[0..light_idx],
                );
                endDraw(
                    encoder,
                    load_render_pass_info,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                    @divFloor(light_idx, 4) * 6,
                    null,
                );
            }
        }
    }

    uiPass: {
        const vb_info = gctx.lookupResourceInfo(base_vb) orelse break :uiPass;
        const pipeline = gctx.lookupResource(base_pipeline) orelse break :uiPass;
        const bind_group = gctx.lookupResource(base_bind_group) orelse break :uiPass;

        var needs_clear = no_in_game_render;
        var ui_idx: u16 = 0;
        for (ui.status_texts.items()) |status_text| {
            if (!status_text.visible)
                continue;

            if (ui_idx >= 40000 - status_text.text_data.text.len * 4) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            ui_idx += drawText(
                ui_idx,
                status_text._screen_x,
                status_text._screen_y,
                status_text.text_data,
            );
        }

        for (ui.speech_balloons.items()) |balloon| {
            if (!balloon.visible)
                continue;

            const image_data = balloon.image_data.normal; // assume no 9 slice
            const w = image_data.width();
            const h = image_data.height();

            drawQuad(
                ui_idx,
                balloon._screen_x,
                balloon._screen_y,
                w,
                h,
                image_data.atlas_data,
                .{ .alpha_mult = image_data.alpha, .ui_quad = true },
            );
            ui_idx += 4;

            if (ui_idx == 40000) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            if (ui_idx >= 40000 - balloon.text_data.text.len * 4) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            const decor_offset = h / 10;
            ui_idx += drawText(
                ui_idx,
                balloon._screen_x + ((w - assets.padding * image_data.scale_x) - balloon.text_data.width()) / 2,
                balloon._screen_y + (h - balloon.text_data.height()) / 2 - decor_offset,
                balloon.text_data,
            );
        }

        for (ui.ui_images.items()) |image| {
            if (!image.visible)
                continue;

            switch (image.image_data) {
                .nine_slice => |nine_slice| {
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, image.x, image.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    var atlas_data = image_data.atlas_data;
                    var w = image_data.width();
                    if (w > image.max_width) {
                        const scale = image.max_width / w;
                        atlas_data.tex_w *= scale;
                        w *= scale;
                    }
                    drawQuad(
                        ui_idx,
                        image.x,
                        image.y,
                        w,
                        image_data.height(),
                        atlas_data,
                        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }
        }

        for (ui.items.items()) |item| {
            if (!item.visible)
                continue;

            switch (item.image_data) {
                .nine_slice => |nine_slice| {
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, item.x, item.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    drawQuad(
                        ui_idx,
                        item.x,
                        item.y,
                        image_data.width(),
                        image_data.height(),
                        image_data.atlas_data,
                        .{ .shadow_texel_mult = 2.0 / image_data.scale_x, .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }

            textDraw: {
                if (item.tier_text) |tier_text| {
                    const text_len = tier_text.text_data.text.len;
                    if (text_len <= 0)
                        break :textDraw;

                    if (ui_idx >= 40000 - text_len * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    ui_idx += drawText(
                        ui_idx,
                        item.x + tier_text.x,
                        item.y + tier_text.y,
                        tier_text.text_data,
                    );

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                }
            }
        }

        for (ui.bars.items()) |bar| {
            if (!bar.visible)
                continue;

            var w: f32 = 0;
            var h: f32 = 0;
            switch (bar.image_data) {
                .nine_slice => |nine_slice| {
                    w = nine_slice.w;
                    h = nine_slice.h;
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, bar.x, bar.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    w = image_data.width();
                    h = image_data.height();
                    var atlas_data = image_data.atlas_data;
                    var scale: f32 = 1.0;
                    if (w > bar.max_width) {
                        scale = bar.max_width / w;
                        atlas_data.tex_w *= scale;
                    }
                    drawQuad(
                        ui_idx,
                        bar.x,
                        bar.y,
                        w * scale,
                        image_data.height(),
                        atlas_data,
                        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }

            if (ui_idx >= 40000 - bar.text_data.text.len * 4) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            ui_idx += drawText(
                ui_idx,
                bar.x + (w - bar.text_data.width()) / 2,
                bar.y + (h - bar.text_data.height()) / 2,
                bar.text_data,
            );

            if (ui_idx == 40000) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }
        }

        for (ui.buttons.items()) |button| {
            if (!button.visible)
                continue;

            var w: f32 = 0;
            var h: f32 = 0;

            switch (button.imageData()) {
                .nine_slice => |nine_slice| {
                    w = nine_slice.w;
                    h = nine_slice.h;
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, button.x, button.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    w = image_data.width();
                    h = image_data.height();
                    drawQuad(
                        ui_idx,
                        button.x,
                        button.y,
                        image_data.width(),
                        image_data.height(),
                        image_data.atlas_data,
                        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }

            if (button.text_data) |text_data| {
                if (ui_idx >= 40000 - text_data.text.len * 4) {
                    endBaseDraw(
                        gctx,
                        if (needs_clear) clear_render_pass_info else load_render_pass_info,
                        encoder,
                        vb_info,
                        ib_info,
                        pipeline,
                        bind_group,
                    );
                    needs_clear = false;
                    ui_idx = 0;
                }

                ui_idx += drawText(
                    ui_idx,
                    button.x + (w - text_data.width()) / 2,
                    button.y + (h - text_data.height()) / 2,
                    text_data,
                );

                if (ui_idx == 40000) {
                    endBaseDraw(
                        gctx,
                        if (needs_clear) clear_render_pass_info else load_render_pass_info,
                        encoder,
                        vb_info,
                        ib_info,
                        pipeline,
                        bind_group,
                    );
                    needs_clear = false;
                    ui_idx = 0;
                }
            }
        }

        for (ui.character_boxes.items()) |char_box| {
            if (!char_box.visible)
                continue;

            var w: f32 = 0;
            var h: f32 = 0;

            switch (char_box.imageData()) {
                .nine_slice => |nine_slice| {
                    w = nine_slice.w;
                    h = nine_slice.h;
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, char_box.x, char_box.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    w = image_data.width();
                    h = image_data.height();
                    drawQuad(
                        ui_idx,
                        char_box.x,
                        char_box.y,
                        image_data.width(),
                        image_data.height(),
                        image_data.atlas_data,
                        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }

            if (char_box.text_data) |text_data| {
                if (ui_idx >= 40000 - text_data.text.len * 4) {
                    endBaseDraw(
                        gctx,
                        if (needs_clear) clear_render_pass_info else load_render_pass_info,
                        encoder,
                        vb_info,
                        ib_info,
                        pipeline,
                        bind_group,
                    );
                    needs_clear = false;
                    ui_idx = 0;
                }

                ui_idx += drawText(
                    ui_idx,
                    char_box.x + (w - text_data.width()) / 2,
                    char_box.y + (h - text_data.height()) / 2,
                    text_data,
                );

                if (ui_idx == 40000) {
                    endBaseDraw(
                        gctx,
                        if (needs_clear) clear_render_pass_info else load_render_pass_info,
                        encoder,
                        vb_info,
                        ib_info,
                        pipeline,
                        bind_group,
                    );
                    needs_clear = false;
                    ui_idx = 0;
                }
            }
        }

        for (ui.ui_texts.items()) |text| {
            if (!text.visible)
                continue;

            if (ui_idx >= 40000 - text.text_data.text.len * 4) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            ui_idx += drawText(
                ui_idx,
                text.x,
                text.y,
                text.text_data,
            );

            if (ui_idx == 40000) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }
        }

        for (ui.input_fields.items()) |input_field| {
            if (!input_field.visible)
                continue;

            var w: f32 = 0;
            var h: f32 = 0;

            switch (input_field.imageData()) {
                .nine_slice => |nine_slice| {
                    w = nine_slice.w;
                    h = nine_slice.h;
                    if (ui_idx >= 40000 - 9 * 4) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }

                    drawNineSlice(ui_idx, input_field.x, input_field.y, nine_slice.w, nine_slice.h, nine_slice);
                    ui_idx += 9 * 4;
                },
                .normal => |image_data| {
                    w = image_data.width();
                    h = image_data.height();
                    drawQuad(
                        ui_idx,
                        input_field.x,
                        input_field.y,
                        image_data.width(),
                        image_data.height(),
                        image_data.atlas_data,
                        .{ .alpha_mult = image_data.alpha, .ui_quad = true },
                    );
                    ui_idx += 4;

                    if (ui_idx == 40000) {
                        endBaseDraw(
                            gctx,
                            if (needs_clear) clear_render_pass_info else load_render_pass_info,
                            encoder,
                            vb_info,
                            ib_info,
                            pipeline,
                            bind_group,
                        );
                        needs_clear = false;
                        ui_idx = 0;
                    }
                },
            }

            if (ui_idx >= 40000 - input_field.text_data.text.len * 4) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }

            ui_idx += drawText(
                ui_idx,
                input_field.x + input_field.text_inlay_x,
                input_field.y + input_field.text_inlay_y,
                input_field.text_data,
            );

            if (ui_idx == 40000) {
                endBaseDraw(
                    gctx,
                    if (needs_clear) clear_render_pass_info else load_render_pass_info,
                    encoder,
                    vb_info,
                    ib_info,
                    pipeline,
                    bind_group,
                );
                needs_clear = false;
                ui_idx = 0;
            }
        }

        if (ui_idx != 0) {
            encoder.writeBuffer(
                gctx.lookupResource(base_vb).?,
                0,
                BaseVertexData,
                base_vert_data[0..ui_idx],
            );
            endDraw(
                encoder,
                if (needs_clear) clear_render_pass_info else load_render_pass_info,
                vb_info,
                ib_info,
                pipeline,
                bind_group,
                @divFloor(ui_idx, 4) * 6,
                null,
            );
        }
    }
}
