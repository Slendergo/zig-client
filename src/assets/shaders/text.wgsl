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

fn sample_msdf(tex: vec4<f32>, dist_factor: f32, alpha_mult: f32) -> f32 {
    return clamp((median(tex.r, tex.g, tex.b) - 0.5) * dist_factor + 0.5, 0.0, 1.0) * alpha_mult;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let use_shadow = in.shadow_texel_offset.x != 0.0 || in.shadow_texel_offset.y != 0.0;
    let dx = dpdx(in.uv);
    let dy = dpdy(in.uv);

    const subpixel = 1.0 / 3.0;
    let subpixel_width = (abs(dx.x) + abs(dy.x)) * subpixel; // this is just fwidth(in.uv).x * subpixel

    var red_tex = vec4(0.0, 0.0, 0.0, 0.0);
    var green_tex = vec4(0.0, 0.0, 0.0, 0.0);
    var blue_tex = vec4(0.0, 0.0, 0.0, 0.0);
    var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
    if in.text_type == medium_text_type {
        red_tex = textureSampleGrad(medium_tex, default_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
        green_tex = textureSampleGrad(medium_tex, default_sampler, in.uv, dx, dy);
        blue_tex = textureSampleGrad(medium_tex, default_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        if use_shadow {
            tex_offset = textureSampleGrad(medium_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
        }
    } else if in.text_type == medium_italic_text_type {
        red_tex = textureSampleGrad(medium_italic_tex, default_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
        green_tex = textureSampleGrad(medium_italic_tex, default_sampler, in.uv, dx, dy);
        blue_tex = textureSampleGrad(medium_italic_tex, default_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        if use_shadow {
            tex_offset = textureSampleGrad(medium_italic_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
        }
    } else if in.text_type == bold_text_type {
        red_tex = textureSampleGrad(bold_tex, default_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
        green_tex = textureSampleGrad(bold_tex, default_sampler, in.uv, dx, dy);
        blue_tex = textureSampleGrad(bold_tex, default_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        if use_shadow {
            tex_offset = textureSampleGrad(bold_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
        }
    } else if in.text_type == bold_italic_text_type {
        red_tex = textureSampleGrad(bold_italic_tex, default_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
        green_tex = textureSampleGrad(bold_italic_tex, default_sampler, in.uv, dx, dy);
        blue_tex = textureSampleGrad(bold_italic_tex, default_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        if use_shadow {
            tex_offset = textureSampleGrad(bold_italic_tex, default_sampler, in.uv - in.shadow_texel_offset, dx, dy);
        }
    }

    let red = sample_msdf(red_tex, in.distance_factor, in.alpha_mult);
    let green = sample_msdf(green_tex, in.distance_factor, in.alpha_mult);
    let blue = sample_msdf(blue_tex, in.distance_factor, in.alpha_mult);

    let alpha = clamp((red + green + blue) / 3.0, 0.0, 1.0);
    let base_pixel = vec4(red * in.color.r, green * in.color.g, blue * in.color.b, alpha);

    if use_shadow {
        // don't subpixel aa the offset, it's supposed to be a shadow
        let offset_opacity = sample_msdf(tex_offset, in.distance_factor, in.alpha_mult * in.shadow_alpha_mult);
        let offset_pixel = vec4(in.shadow_color, offset_opacity);

        return mix(offset_pixel, base_pixel, alpha);
    } else {
        return base_pixel;
    }
}