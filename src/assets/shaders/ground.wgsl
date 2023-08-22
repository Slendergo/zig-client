struct Uniforms {
  left_top_mask_uv: vec4<f32>,
  right_bottom_mask_uv: vec4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var default_sampler: sampler;
@group(0) @binding(2) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) base_uv: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) left_blend_uv: vec2<f32>,
  @location(3) top_blend_uv: vec2<f32>,
  @location(4) right_blend_uv: vec2<f32>,
  @location(5) bottom_blend_uv: vec2<f32>,
  @location(6) pos: vec2<f32>,
  @location(7) uv_offsets: vec2<f32>,
}

struct VertexOutput {
  @builtin(position) position: vec4<f32>,
  @location(0) base_uv: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) left_blend_uv: vec2<f32>,
  @location(3) top_blend_uv: vec2<f32>,
  @location(4) right_blend_uv: vec2<f32>,
  @location(5) bottom_blend_uv: vec2<f32>,
  @location(6) uv_offsets: vec2<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.base_uv = in.base_uv;
    out.uv = in.uv;
    out.left_blend_uv = in.left_blend_uv;
    out.top_blend_uv = in.top_blend_uv;
    out.right_blend_uv = in.right_blend_uv;
    out.bottom_blend_uv = in.bottom_blend_uv;
    out.uv_offsets = in.uv_offsets;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let dx = dpdx(in.uv);
    let dy = dpdy(in.uv);

    if in.left_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.left_top_mask_uv.xy + in.uv, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.left_blend_uv + in.uv, dx, dy);
    }

    if in.top_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.left_top_mask_uv.zw + in.uv, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.top_blend_uv + in.uv, dx, dy);
    }

    if in.right_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.right_bottom_mask_uv.xy + in.uv, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.right_blend_uv + in.uv, dx, dy);
    }

    if in.bottom_blend_uv.x >= 0.0 && textureSampleGrad(tex, default_sampler, uniforms.right_bottom_mask_uv.zw + in.uv, dx, dy).a == 1.0 {
        return textureSampleGrad(tex, default_sampler, in.bottom_blend_uv + in.uv, dx, dy);
    }

    const dims = vec2<f32>(8.0 / 4096.0, 8.0 / 4096.0);
    let uv = (in.uv + in.uv_offsets + dims) % dims;
    return textureSampleGrad(tex, default_sampler, uv + in.base_uv, dx, dy);
}