@group(0) @binding(0) var default_sampler: sampler;
@group(0) @binding(1) var tex: texture_2d<f32>;

struct VertexInput {
  @location(0) pos: vec2<f32>, 
  @location(1) uv: vec2<f32>, 
  @location(2) texel_size: vec2<f32>, 
  @location(3) flash_color: vec3<f32>,
  @location(4) flash_strength: f32,
  @location(5) glow_color: vec3<f32>,
  @location(6) alpha_mult: f32,
}

struct VertexOutput {
  @builtin(position) position : vec4<f32>,
  @location(0) uv : vec2<f32>,
  @location(1) texel_size: vec2<f32>,
  @location(2) flash_color: vec3<f32>,
  @location(3) flash_strength: f32,
  @location(4) glow_color: vec3<f32>,
  @location(5) alpha_mult: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.uv = in.uv;
    out.texel_size = in.texel_size;
    out.flash_color = in.flash_color;
    out.glow_color = in.glow_color;
    out.flash_strength = in.flash_strength;
    out.alpha_mult = in.alpha_mult;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
  let dx = dpdx(in.uv);
  let dy = dpdy(in.uv);
  var pixel = textureSampleGrad(tex, default_sampler, in.uv, dx, dy);

  if pixel.a == 0.0 {
    if in.texel_size.x != 0.0 {
      var alpha = textureSampleGrad(tex, default_sampler, in.uv - in.texel_size, dx, dy).a;
      alpha += textureSampleGrad(tex, default_sampler, vec2(in.uv.x - in.texel_size.x, in.uv.y + in.texel_size.y), dx, dy).a;
      alpha += textureSampleGrad(tex, default_sampler, vec2(in.uv.x + in.texel_size.x, in.uv.y - in.texel_size.y), dx, dy).a;
      alpha += textureSampleGrad(tex, default_sampler, in.uv + in.texel_size, dx, dy).a;

      if alpha > 0.0 {
        pixel = vec4(in.glow_color, 1.0);
      } else {
        discard;
      }
    } 
  } else {
    if in.flash_color.r >= 0.0 {
      let flash_strength_inv = 1.0 - in.flash_strength;
      pixel = vec4(in.flash_color.r * in.flash_strength + pixel.r * flash_strength_inv,
                  in.flash_color.g * in.flash_strength + pixel.g * flash_strength_inv, 
                  in.flash_color.b * in.flash_strength + pixel.b * flash_strength_inv, pixel.a);
    }
  }

  if in.alpha_mult >= 0.0 {
    pixel.a *= in.alpha_mult;
  }

  return pixel;
}