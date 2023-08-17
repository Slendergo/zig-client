@group(0) @binding(0) var defaultSampler: sampler;
@group(0) @binding(1) var light_tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>, 
  @location(3) intensity: f32, 
}

struct VertexOutput {
  @builtin(position) position : vec4<f32>,
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>, 
  @location(3) intensity: f32, 
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    out.intensity = in.intensity;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {  
  var pixel = textureSample(light_tex, defaultSampler, in.uv);
  if pixel.a == 0.0 {
    discard;
  }

  return vec4(in.color, pixel.a * in.intensity);
}