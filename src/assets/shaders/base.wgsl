@group(0) @binding(0) var default_sampler: sampler;
@group(0) @binding(1) var linear_sampler: sampler;
@group(0) @binding(2) var base_tex: texture_2d<f32>;
@group(0) @binding(3) var ui_tex: texture_2d<f32>;
@group(0) @binding(4) var medium_tex: texture_2d<f32>;
@group(0) @binding(5) var medium_italic_tex: texture_2d<f32>;
@group(0) @binding(6) var bold_tex: texture_2d<f32>;
@group(0) @binding(7) var bold_italic_tex: texture_2d<f32>;

const medium_text_type = 0.0;
const medium_italic_text_type = 1.0;
const bold_text_type = 2.0;
const bold_italic_text_type = 3.0;

const quad_render_type = 0.0;
const ui_quad_render_type = 1.0;
const quad_glow_off_render_type = 2.0;
const ui_quad_glow_off_render_type = 3.0;
const text_normal_render_type = 4.0;
const text_drop_shadow_render_type = 5.0;
const text_normal_no_subpixel_render_type = 6.0;
const text_drop_shadow_no_subpixel_render_type = 7.0;

struct VertexInput {
    @location(0) pos: vec2<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) base_color: vec3<f32>,
    @location(3) base_color_intensity: f32,
    @location(4) alpha_mult: f32,
    @location(5) shadow_color: vec3<f32>,
    @location(6) shadow_texel: vec2<f32>,
    @location(7) text_type: f32,
    @location(8) distance_factor: f32,
    @location(9) render_type: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) base_color: vec3<f32>,
    @location(3) base_color_intensity: f32,
    @location(4) alpha_mult: f32,
    @location(5) shadow_color: vec3<f32>,
    @location(6) shadow_texel: vec2<f32>,
    @location(7) text_type: f32,
    @location(8) distance_factor: f32,
    @location(9) render_type: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 0.0, 1.0);
    out.uv = in.uv;
    out.base_color = in.base_color;
    out.base_color_intensity = in.base_color_intensity;
    out.alpha_mult = in.alpha_mult;
    out.shadow_color = in.shadow_color;
    out.shadow_texel = in.shadow_texel;
    out.text_type = in.text_type;
    out.distance_factor = in.distance_factor;
    out.render_type = in.render_type;
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
    let dx = dpdx(in.uv);
    let dy = dpdy(in.uv);

    if in.render_type == quad_render_type {
        var pixel = textureSampleGrad(base_tex, default_sampler, in.uv, dx, dy);
        if pixel.a == 0.0 {
            if in.shadow_texel.x != 0.0 {
                var alpha = textureSampleGrad(base_tex, default_sampler, in.uv - in.shadow_texel, dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, in.uv.y + in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, in.uv.y - in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, in.uv + in.shadow_texel, dx, dy).a;

                if alpha > 0.0 {
                    pixel = vec4(in.shadow_color, 1.0);
                } else {
                    var sum = 0.0;
                    for (var i = 0.0; i < 7.0; i += 1.0) {
                        let uv_y = in.uv.y + in.shadow_texel.y * (i - 3.5);
                        let tex_x_2 = in.shadow_texel.x * 2.0;
                        let tex_x_3 = in.shadow_texel.x * 3.0;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x - tex_x_3, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x - tex_x_2, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x + tex_x_2, uv_y), dx, dy).a;
                        sum += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x + tex_x_3, uv_y), dx, dy).a;
                    }

                    if sum == 0.0 {
                        discard;
                    } else {
                        pixel = vec4(in.shadow_color, sum / 49.0);
                    }
                }
            }
        } else {
            return vec4(mix(pixel.rgb, in.base_color, in.base_color_intensity), pixel.a * in.alpha_mult);
        }

        return vec4(pixel.rgb, pixel.a * in.alpha_mult);
    } else if in.render_type == ui_quad_render_type {
        var pixel = textureSampleGrad(ui_tex, default_sampler, in.uv, dx, dy);
        if pixel.a == 0.0 {
            if in.shadow_texel.x != 0.0 {
                var alpha = textureSampleGrad(ui_tex, default_sampler, in.uv - in.shadow_texel, dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, in.uv.y + in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, in.uv.y - in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, in.uv + in.shadow_texel, dx, dy).a;

                if alpha > 0.0 {
                    pixel = vec4(in.shadow_color, 1.0);
                } else {
                    var sum = 0.0;
                    for (var i = 0.0; i < 7.0; i += 1.0) {
                        let uv_y = in.uv.y + in.shadow_texel.y * (i - 3.5);
                        let tex_x_2 = in.shadow_texel.x * 2.0;
                        let tex_x_3 = in.shadow_texel.x * 3.0;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x - tex_x_3, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x - tex_x_2, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x + tex_x_2, uv_y), dx, dy).a;
                        sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x + tex_x_3, uv_y), dx, dy).a;
                    }

                    if sum == 0.0 {
                        discard;
                    } else {
                        pixel = vec4(in.shadow_color, sum / 49.0);
                    }
                }
            }
        } else {
            return vec4(mix(pixel.rgb, in.base_color, in.base_color_intensity), pixel.a * in.alpha_mult);
        }

        return vec4(pixel.rgb, pixel.a * in.alpha_mult);
    } else if in.render_type == quad_glow_off_render_type {
        var pixel = textureSampleGrad(base_tex, default_sampler, in.uv, dx, dy);
        if pixel.a == 0.0 {
            if in.shadow_texel.x != 0.0 {
                var alpha = textureSampleGrad(base_tex, default_sampler, in.uv - in.shadow_texel, dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, in.uv.y + in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, in.uv.y - in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(base_tex, default_sampler, in.uv + in.shadow_texel, dx, dy).a;

                if alpha > 0.0 {
                    pixel = vec4(in.shadow_color, 1.0);
                } else {
                    discard;
                }
            }
        } else {
            return vec4(mix(pixel.rgb, in.base_color, in.base_color_intensity), pixel.a * in.alpha_mult);
        }

        return vec4(pixel.rgb, pixel.a * in.alpha_mult);
    } else if in.render_type == ui_quad_glow_off_render_type {
        var pixel = textureSampleGrad(ui_tex, default_sampler, in.uv, dx, dy);
        if pixel.a == 0.0 {
            if in.shadow_texel.x != 0.0 {
                var alpha = textureSampleGrad(ui_tex, default_sampler, in.uv - in.shadow_texel, dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x - in.shadow_texel.x, in.uv.y + in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, vec2(in.uv.x + in.shadow_texel.x, in.uv.y - in.shadow_texel.y), dx, dy).a;
                alpha += textureSampleGrad(ui_tex, default_sampler, in.uv + in.shadow_texel, dx, dy).a;

                if alpha > 0.0 {
                    pixel = vec4(in.shadow_color, 1.0);
                } else {
                    discard;
                }
            }
        } else {
            return vec4(mix(pixel.rgb, in.base_color, in.base_color_intensity), pixel.a * in.alpha_mult);
        }

        return vec4(pixel.rgb, pixel.a * in.alpha_mult);
    } else if in.render_type == text_normal_render_type {
        const subpixel = 1.0 / 3.0;
        let subpixel_width = (abs(dx.x) + abs(dy.x)) * subpixel; // this is just fwidth(in.uv).x * subpixel

        var red_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var green_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var blue_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
        if in.text_type == medium_text_type {
            red_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(medium_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        } else if in.text_type == medium_italic_text_type {
            red_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        } else if in.text_type == bold_text_type {
            red_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(bold_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        } else if in.text_type == bold_italic_text_type {
            red_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
        }

        let red = sample_msdf(red_tex, in.distance_factor, in.alpha_mult);
        let green = sample_msdf(green_tex, in.distance_factor, in.alpha_mult);
        let blue = sample_msdf(blue_tex, in.distance_factor, in.alpha_mult);

        let alpha = clamp((red + green + blue) / 3.0, 0.0, 1.0);
        let base_pixel = vec4(red * in.base_color.r, green * in.base_color.g, blue * in.base_color.b, alpha);

        return base_pixel;
    } else if in.render_type == text_drop_shadow_render_type {
        const subpixel = 1.0 / 3.0;
        let subpixel_width = (abs(dx.x) + abs(dy.x)) * subpixel; // this is just fwidth(in.uv).x * subpixel

        var red_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var green_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var blue_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
        if in.text_type == medium_text_type {
            red_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(medium_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
            tex_offset = textureSampleGrad(medium_tex, linear_sampler, in.uv - in.shadow_texel, dx, dy);
        } else if in.text_type == medium_italic_text_type {
            red_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
            tex_offset = textureSampleGrad(medium_italic_tex, linear_sampler, in.uv - in.shadow_texel, dx, dy);
        } else if in.text_type == bold_text_type {
            red_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(bold_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
            tex_offset = textureSampleGrad(bold_tex, linear_sampler, in.uv - in.shadow_texel, dx, dy);
        } else if in.text_type == bold_italic_text_type {
            red_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.uv.x - subpixel_width, in.uv.y), dx, dy);
            green_tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.uv, dx, dy);
            blue_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.uv.x + subpixel_width, in.uv.y), dx, dy);
            tex_offset = textureSampleGrad(bold_italic_tex, linear_sampler, in.uv - in.shadow_texel, dx, dy);
        }

        let red = sample_msdf(red_tex, in.distance_factor, in.alpha_mult);
        let green = sample_msdf(green_tex, in.distance_factor, in.alpha_mult);
        let blue = sample_msdf(blue_tex, in.distance_factor, in.alpha_mult);

        let alpha = clamp((red + green + blue) / 3.0, 0.0, 1.0);
        let base_pixel = vec4(red * in.base_color.r, green * in.base_color.g, blue * in.base_color.b, alpha);

        // don't subpixel aa the offset, it's supposed to be a shadow
        let offset_opacity = sample_msdf(tex_offset, in.distance_factor, in.alpha_mult * 0.5);
        let offset_pixel = vec4(in.shadow_color, offset_opacity);

        return mix(offset_pixel, base_pixel, alpha);
    }

    return vec4(0.0, 0.0, 0.0, 0.0);
}