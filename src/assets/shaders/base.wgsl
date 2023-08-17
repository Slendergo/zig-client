@group(0) @binding(0) var defaultSampler: sampler;
@group(0) @binding(1) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos: vec2<f32>, 
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
    out.position = vec4(in.pos, 0.0, 1.0);
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
      } else if in.alphaMult != -2.0 { // turbo hacky
          var sum = 0.0;
          for (var i = 0.0; i < 7.0; i += 1.0) {
              let uvY = in.uv.y + in.texelSize.y * (i - 3.5);
              let texX2 = in.texelSize.x * 2.0;
              let texX3 = in.texelSize.x * 3.0;
              let texX4 = in.texelSize.x * 4.0;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x - texX4, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x - texX3, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x - texX2, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x - in.texelSize.x, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x + in.texelSize.x, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x + texX2, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x + texX3, uvY), dx, dy).a;
              sum += textureSampleGrad(tex, defaultSampler, vec2(in.uv.x + texX4, uvY), dx, dy).a;
          }
      
          if sum == 0.0 {
            discard;
          } else {
            pixel = vec4(in.glowColor, sum / 81.0);
          }
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