@group(0) @binding(0) var defaultSampler: sampler;
@group(0) @binding(1) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos: vec3<f32>, 
  @location(1) uv: vec2<f32>, 
  @location(2) texelSize: vec2<f32>, 
  @location(3) flashColor: vec3<f32>,
  @location(4) flashStrength: f32,
  @location(5) glowColor: vec3<f32>,
  @location(6) alphaMult: f32,
}

struct VertexOutput {
  @builtin(position) position : vec4<f32>,
  @location(0) uv : vec2<f32>,
  @location(1) texelSize: vec2<f32>,
  @location(2) flashColor: vec3<f32>,
  @location(3) flashStrength: f32,
  @location(4) glowColor: vec3<f32>,
  @location(5) alphaMult: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 1.0);
    out.uv = in.uv;
    out.texelSize = in.texelSize;
    out.flashColor = in.flashColor;
    out.glowColor = in.glowColor;
    out.flashStrength = in.flashStrength;
    out.alphaMult = in.alphaMult;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
  let dx = dpdx(in.uv);
  let dy = dpdy(in.uv);
  var pixel = textureSampleGrad(tex, defaultSampler, in.uv, dx, dy);
  if in.alphaMult >= 0.0 {
    pixel.a *= in.alphaMult;
  }

  if pixel.a == 0.0 {
    if in.texelSize.x != 0.0 {
      var alpha = textureSampleGrad(tex, defaultSampler, in.uv - in.texelSize, dx, dy).a;
      alpha += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x - in.texelSize.x, in.uv.y + in.texelSize.y), dx, dy).a;
      alpha += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x + in.texelSize.x, in.uv.y - in.texelSize.y), dx, dy).a;
      alpha += textureSampleGrad(tex, defaultSampler, in.uv + in.texelSize, dx, dy).a;

      if alpha > 0.0 {
        pixel = vec4(in.glowColor, 1.0);
      } else {
        discard;
      }
    } 
  } else {
    if in.flashColor.r >= 0.0 {
      let flashStrengthInv = 1.0 - in.flashStrength;
      pixel = vec4(in.flashColor.r * in.flashStrength + pixel.r * flashStrengthInv,
                  in.flashColor.g * in.flashStrength + pixel.g * flashStrengthInv, 
                  in.flashColor.b * in.flashStrength + pixel.b * flashStrengthInv, pixel.a);
    }
  }

  return pixel;
}