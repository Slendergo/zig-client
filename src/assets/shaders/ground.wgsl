struct Uniforms {
  left_top_mask_uv: vec4<f32>,
  right_bottom_mask_uv: vec4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var default_sampler: sampler;
@group(0) @binding(2) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos_uv: vec4<f32>,
  @location(1) left_top_blend_uv: vec4<f32>,
  @location(2) right_bottom_blend_uv: vec4<f32>,
  @location(3) base_and_offset_uv: vec4<f32>,
}

struct VertexOutput {
  @builtin(position) position: vec4<f32>,
  @location(0) @interpolate(linear) pos_uv: vec4<f32>,
  @location(1) @interpolate(flat) left_top_blend_uv: vec4<f32>,
  @location(2) @interpolate(flat) right_bottom_blend_uv: vec4<f32>,
  @location(3) @interpolate(flat) base_and_offset_uv: vec4<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos_uv.xy, 0.0, 1.0);
    out.pos_uv = in.pos_uv;
    out.left_top_blend_uv = in.left_top_blend_uv;
    out.right_bottom_blend_uv = in.right_bottom_blend_uv;
    out.base_and_offset_uv = in.base_and_offset_uv;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let dx = dpdx(in.pos_uv.zw);
    let dy = dpdy(in.pos_uv.zw);

    if in.left_top_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.left_top_mask_uv.xy + in.pos_uv.zw, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.left_top_blend_uv.xy + in.pos_uv.zw, dx, dy);
    }

    if in.left_top_blend_uv.z >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.left_top_mask_uv.zw + in.pos_uv.zw, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.left_top_blend_uv.zw + in.pos_uv.zw, dx, dy);
    }

    if in.right_bottom_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.right_bottom_mask_uv.xy + in.pos_uv.zw, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.right_bottom_blend_uv.xy + in.pos_uv.zw, dx, dy);
    }

    if in.right_bottom_blend_uv.z >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.right_bottom_mask_uv.zw + in.pos_uv.zw, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.right_bottom_blend_uv.zw + in.pos_uv.zw, dx, dy);
    }

    const atlas_w = 4096.0;
    const atlas_h = 4096.0;
    const pad_w = 1.0 / atlas_w / 8.0;
    const pad_h = 1.0 / atlas_h / 8.0;
    const dims = vec2<f32>(8.0 / atlas_w - pad_w, 8.0 / atlas_h - pad_h);
    let uv = abs((in.pos_uv.zw + in.base_and_offset_uv.zw + dims) % dims);
    return textureSampleGrad(tex, default_sampler, uv + in.base_and_offset_uv.xy, dx, dy);
}