struct Uniforms {
  leftTopMaskUv: vec4<f32>,
  rightBottomMaskUv: vec4<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var defaultSampler: sampler;
@group(0) @binding(2) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) baseUv: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) leftBlendUv: vec2<f32>,
  @location(3) topBlendUv: vec2<f32>,
  @location(4) rightBlendUv: vec2<f32>,
  @location(5) bottomBlendUv: vec2<f32>,
  @location(6) pos: vec2<f32>,
}

struct VertexOutput {
  @builtin(position) position: vec4<f32>,
  @location(0) baseUv: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) leftBlendUv: vec2<f32>,
  @location(3) topBlendUv: vec2<f32>,
  @location(4) rightBlendUv: vec2<f32>,
  @location(5) bottomBlendUv: vec2<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.baseUv = in.baseUv;
    out.uv = in.uv;
    out.leftBlendUv = in.leftBlendUv;
    out.topBlendUv = in.topBlendUv;
    out.rightBlendUv = in.rightBlendUv;
    out.bottomBlendUv = in.bottomBlendUv;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
  let dx = dpdx(in.uv);
  let dy = dpdy(in.uv);
  if in.leftBlendUv.x >= 0.0 && textureSampleGrad(tex, defaultSampler, uniforms.leftTopMaskUv.xy + in.uv, dx, dy).a == 1.0 {
    return textureSampleGrad(tex, defaultSampler, in.leftBlendUv + in.uv, dx, dy);
  }

  if in.topBlendUv.x >= 0.0 && textureSampleGrad(tex, defaultSampler, uniforms.leftTopMaskUv.zw + in.uv, dx, dy).a == 1.0 {
    return textureSampleGrad(tex, defaultSampler, in.topBlendUv + in.uv, dx, dy);
  }

  if in.rightBlendUv.x >= 0.0 && textureSampleGrad(tex, defaultSampler, uniforms.rightBottomMaskUv.xy + in.uv, dx, dy).a == 1.0 {
    return textureSampleGrad(tex, defaultSampler, in.rightBlendUv + in.uv, dx, dy);
  }

  if in.bottomBlendUv.x >= 0.0 && textureSampleGrad(tex, defaultSampler, uniforms.rightBottomMaskUv.zw + in.uv, dx, dy).a == 1.0 {
    return textureSampleGrad(tex, defaultSampler, in.bottomBlendUv + in.uv, dx, dy);
  }

  return textureSampleGrad(tex, defaultSampler, in.uv + in.baseUv, dx, dy);
}