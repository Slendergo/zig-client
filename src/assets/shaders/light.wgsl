@group(0) @binding(0) var default_sampler: sampler;
@group(0) @binding(1) var light_tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos_uv: vec4<f32>,
  @location(1) color_and_intensity: vec4<f32>,
}

struct VertexOutput {
  @builtin(position) position : vec4<f32>,
  @location(0) pos_uv: vec4<f32>,
  @location(1) color_and_intensity: vec4<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos_uv.xy, 0.0, 1.0);
    out.pos_uv = in.pos_uv;
    out.color_and_intensity = in.color_and_intensity;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {  
  var pixel = textureSample(light_tex, default_sampler, in.pos_uv.zw);
  if pixel.a == 0.0 {
    discard;
  }

  return vec4(in.color_and_intensity.rgb, pixel.a * in.color_and_intensity.a);
}