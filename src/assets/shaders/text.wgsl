@group(0) @binding(0) var default_sampler: sampler;
@group(0) @binding(1) var medium_tex: texture_2d<f32>;
@group(0) @binding(2) var medium_italic_tex: texture_2d<f32>;
@group(0) @binding(3) var bold_tex: texture_2d<f32>;
@group(0) @binding(4) var bold_italic_tex: texture_2d<f32>;

const medium_text_type = 0.0;
const medium_italic_text_type = 1.0;
const bold_text_type = 2.0;
const bold_italic_text_type = 3.0;

struct VertexInput {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>,
  @location(3) text_type: f32,
  @location(4) alpha_mult: f32,
  @location(5) shadow_color: vec3<f32>,
  @location(6) shadow_alpha_mult: f32,
  @location(7) shadow_texel_offset: vec2<f32>,
  @location(8) distance_factor: f32,
}

struct VertexOutput {
  @builtin(position) position: vec4<f32>,
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>,
  @location(3) text_type: f32,
  @location(4) alpha_mult: f32,
  @location(5) shadow_color: vec3<f32>,
  @location(6) shadow_alpha_mult: f32,
  @location(7) shadow_texel_offset: vec2<f32>,
  @location(8) distance_factor: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    out.text_type = in.text_type;
    out.alpha_mult = in.alpha_mult;
    out.shadow_color = in.shadow_color;
    out.shadow_alpha_mult = in.shadow_alpha_mult;
    out.shadow_texel_offset = in.shadow_texel_offset;
    out.distance_factor = in.distance_factor;
    return out;
}

fn median(r: f32, g: f32, b: f32) -> f32 {
    return max(min(r, g), min(max(r, g), b));
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let dx = dpdx(in.uv);
    let dy = dpdy(in.uv);

    var tex = vec4(0.0, 0.0, 0.0, 0.0);
    var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
    if in.text_type == medium_text_type {
        tex = textureSampleGrad(medium_tex, default_sampler, in.uv, dx, dy);
        tex_offset = textureSampleGrad(medium_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
    } else if in.text_type == medium_italic_text_type {
        tex = textureSampleGrad(medium_italic_tex, default_sampler, in.uv, dx, dy);
        tex_offset = textureSampleGrad(medium_italic_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
    } else if in.text_type == bold_text_type {
        tex = textureSampleGrad(bold_tex, default_sampler, in.uv, dx, dy);
        tex_offset = textureSampleGrad(bold_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
    } else if in.text_type == bold_italic_text_type {
        tex = textureSampleGrad(bold_italic_tex, default_sampler, in.uv, dx, dy);
        tex_offset = textureSampleGrad(bold_italic_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
    }

    let sig_dist = median(tex.r, tex.g, tex.b) - 0.5;
    let opacity = clamp(sig_dist * in.distance_factor + 0.5, 0.0, 1.0) * in.alpha_mult;
    
    let offset_sig_dist = median(tex_offset.r, tex_offset.g, tex_offset.b) - 0.5;
    let offset_opacity = clamp(offset_sig_dist * in.distance_factor + 0.5, 0.0, 1.0) * in.shadow_alpha_mult * in.alpha_mult;

    return mix(vec4(in.shadow_color, offset_opacity), vec4(in.color, opacity), opacity);
}