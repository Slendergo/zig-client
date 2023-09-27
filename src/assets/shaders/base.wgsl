@group(0) @binding(0) var default_sampler: sampler;
@group(0) @binding(1) var linear_sampler: sampler;
@group(0) @binding(2) var base_tex: texture_2d<f32>;
@group(0) @binding(3) var ui_tex: texture_2d<f32>;
@group(0) @binding(4) var medium_tex: texture_2d<f32>;
@group(0) @binding(5) var medium_italic_tex: texture_2d<f32>;
@group(0) @binding(6) var bold_tex: texture_2d<f32>;
@group(0) @binding(7) var bold_italic_tex: texture_2d<f32>;
@group(0) @binding(8) var minimap_tex: texture_2d<f32>;
@group(0) @binding(9) var menu_bg_tex: texture_2d<f32>;

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
const minimap_render_type = 8.0;
const menu_bg_render_type = 9.0;

struct VertexInput {
    @location(0) pos_uv: vec4<f32>,
    @location(1) base_color_and_intensity: vec4<f32>,
    @location(2) alpha_and_shadow_color: vec4<f32>,
    @location(3) texel_and_text_data: vec4<f32>,
    @location(4) outline_color_and_w: vec4<f32>,
    @location(5) render_type: f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) pos_uv: vec4<f32>,
    @location(1) base_color_and_intensity: vec4<f32>,
    @location(2) alpha_and_shadow_color: vec4<f32>,
    @location(3) texel_and_text_data: vec4<f32>,
    @location(4) outline_color_and_w: vec4<f32>,
    @location(5) render_type: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos_uv.xy, 0.0, 1.0);
    out.pos_uv = in.pos_uv;
    out.base_color_and_intensity = in.base_color_and_intensity;
    out.alpha_and_shadow_color = in.alpha_and_shadow_color;
    out.texel_and_text_data = in.texel_and_text_data;
    out.outline_color_and_w = in.outline_color_and_w;
    out.render_type = in.render_type;
    return out;
}

fn median(r: f32, g: f32, b: f32) -> f32 {
    return max(min(r, g), min(max(r, g), b));
}

fn sample_msdf(tex: vec4<f32>, dist_factor: f32, alpha_mult: f32, width: f32) -> f32 {
    return clamp((median(tex.r, tex.g, tex.b) - 0.5) * dist_factor + width, 0.0, 1.0) * alpha_mult;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let dx = dpdx(in.pos_uv.zw);
    let dy = dpdy(in.pos_uv.zw);

    if in.render_type == quad_render_type {
        let pixel = textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw, dx, dy);
        if pixel.a == 0.0 {
            let alpha = textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, in.pos_uv.w + in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, in.pos_uv.w - in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw + in.texel_and_text_data.xy, dx, dy).a;

            if alpha > 0.0 {
                return vec4(in.alpha_and_shadow_color.yzw, in.alpha_and_shadow_color.x);
            }

            var sum = 0.0;
            for (var i = 0.0; i < 7.0; i += 1.0) {
                let uv_y = in.pos_uv.w + in.texel_and_text_data.y * (i - 3.5);
                let tex_x_2 = in.texel_and_text_data.x * 2.0;
                let tex_x_3 = in.texel_and_text_data.x * 3.0;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z - tex_x_3, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z - tex_x_2, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z + tex_x_2, uv_y), dx, dy).a;
                sum += textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z + tex_x_3, uv_y), dx, dy).a;
            }

            if sum == 0.0 {
                discard;
            }

            return vec4(in.alpha_and_shadow_color.yzw, sum / 49.0 * in.alpha_and_shadow_color.x);
        }

        return vec4(mix(pixel.rgb, in.base_color_and_intensity.rgb, in.base_color_and_intensity.a), pixel.a * in.alpha_and_shadow_color.x);
    } else if in.render_type == ui_quad_render_type {
        let pixel = textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw, dx, dy);
        if pixel.a == 0.0 {
            let alpha = textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, in.pos_uv.w + in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, in.pos_uv.w - in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw + in.texel_and_text_data.xy, dx, dy).a;

            if alpha > 0.0 {
                return vec4(in.alpha_and_shadow_color.yzw, in.alpha_and_shadow_color.x);
            }

            var sum = 0.0;
            for (var i = 0.0; i < 7.0; i += 1.0) {
                let uv_y = in.pos_uv.w + in.texel_and_text_data.y * (i - 3.5);
                let tex_x_2 = in.texel_and_text_data.x * 2.0;
                let tex_x_3 = in.texel_and_text_data.x * 3.0;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z - tex_x_3, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z - tex_x_2, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z + tex_x_2, uv_y), dx, dy).a;
                sum += textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z + tex_x_3, uv_y), dx, dy).a;
            }

            if sum == 0.0 {
                discard;
            }

            return vec4(in.alpha_and_shadow_color.yzw, sum / 49.0 * in.alpha_and_shadow_color.x);
        }

        return vec4(mix(pixel.rgb, in.base_color_and_intensity.rgb, in.base_color_and_intensity.a), pixel.a * in.alpha_and_shadow_color.x);
    } else if in.render_type == quad_glow_off_render_type {
        let pixel = textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw, dx, dy);
        if pixel.a == 0.0 {
            let alpha = textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, in.pos_uv.w + in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, in.pos_uv.w - in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(base_tex, default_sampler, in.pos_uv.zw + in.texel_and_text_data.xy, dx, dy).a;

            if alpha > 0.0 {
                return vec4(in.alpha_and_shadow_color.yzw, in.alpha_and_shadow_color.x);
            }

            discard;
        }

        return vec4(mix(pixel.rgb, in.base_color_and_intensity.rgb, in.base_color_and_intensity.a), pixel.a * in.alpha_and_shadow_color.x);
    } else if in.render_type == ui_quad_glow_off_render_type {
        let pixel = textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw, dx, dy);
        if pixel.a == 0.0 {
            let alpha = textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z - in.texel_and_text_data.x, in.pos_uv.w + in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, vec2(in.pos_uv.z + in.texel_and_text_data.x, in.pos_uv.w - in.texel_and_text_data.y), dx, dy).a +
                textureSampleGrad(ui_tex, default_sampler, in.pos_uv.zw + in.texel_and_text_data.xy, dx, dy).a;

            if alpha > 0.0 {
                return vec4(in.alpha_and_shadow_color.yzw, in.alpha_and_shadow_color.x);
            }

            discard;
        }

        return vec4(mix(pixel.rgb, in.base_color_and_intensity.rgb, in.base_color_and_intensity.a), pixel.a * in.alpha_and_shadow_color.x);
    } else if in.render_type == text_normal_render_type {
        const subpixel = 1.0 / 3.0;
        let subpixel_width = (abs(dx.x) + abs(dy.x)) * subpixel; // this is just fwidth(in.uv).x * subpixel

        var red_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var green_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var blue_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
        if in.texel_and_text_data.w == medium_text_type {
            red_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
        } else if in.texel_and_text_data.w == medium_italic_text_type {
            red_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
        } else if in.texel_and_text_data.w == bold_text_type {
            red_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
        } else if in.texel_and_text_data.w == bold_italic_text_type {
            red_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
        }

        let red = sample_msdf(red_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let green = sample_msdf(green_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let blue = sample_msdf(blue_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);

        let alpha = clamp((red + green + blue) / 3.0, 0.0, 1.0);
        let base_pixel = vec4(red * in.base_color_and_intensity.r, green * in.base_color_and_intensity.g, blue * in.base_color_and_intensity.b, alpha);

        let outline_alpha = sample_msdf(green_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let outlined_pixel = mix(vec4(in.outline_color_and_w.rgb, outline_alpha), base_pixel, alpha);

        return outlined_pixel;
    } else if in.render_type == text_normal_no_subpixel_render_type {
        var tex = vec4(0.0, 0.0, 0.0, 0.0);
        if in.texel_and_text_data.w == medium_text_type {
            tex = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw, dx, dy);
        } else if in.texel_and_text_data.w == medium_italic_text_type {
            tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
        } else if in.texel_and_text_data.w == bold_text_type {
            tex = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw, dx, dy);
        } else if in.texel_and_text_data.w == bold_italic_text_type {
            tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
        }

        let alpha = sample_msdf(tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let base_pixel = vec4(in.base_color_and_intensity.rgb, alpha);

        let outline_alpha = sample_msdf(tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let outlined_pixel = mix(vec4(in.outline_color_and_w.rgb, outline_alpha), base_pixel, alpha);

        return outlined_pixel;
    } else if in.render_type == text_drop_shadow_render_type {
        const subpixel = 1.0 / 3.0;
        let subpixel_width = (abs(dx.x) + abs(dy.x)) * subpixel; // this is just fwidth(in.uv).x * subpixel

        var red_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var green_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var blue_tex = vec4(0.0, 0.0, 0.0, 0.0);
        var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
        if in.texel_and_text_data.w == medium_text_type {
            red_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(medium_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
            tex_offset = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == medium_italic_text_type {
            red_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(medium_italic_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
            tex_offset = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == bold_text_type {
            red_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(bold_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
            tex_offset = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == bold_italic_text_type {
            red_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.pos_uv.z - subpixel_width, in.pos_uv.w), dx, dy);
            green_tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            blue_tex = textureSampleGrad(bold_italic_tex, linear_sampler, vec2(in.pos_uv.z + subpixel_width, in.pos_uv.w), dx, dy);
            tex_offset = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        }

        let red = sample_msdf(red_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let green = sample_msdf(green_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let blue = sample_msdf(blue_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);

        let alpha = clamp((red + green + blue) / 3.0, 0.0, 1.0);
        let base_pixel = vec4(red * in.base_color_and_intensity.r, green * in.base_color_and_intensity.g, blue * in.base_color_and_intensity.b, alpha);

        let outline_alpha = sample_msdf(green_tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let outlined_pixel = mix(vec4(in.outline_color_and_w.rgb, outline_alpha), base_pixel, alpha);

        // don't subpixel aa the offset, it's supposed to be a shadow
        let offset_opacity = sample_msdf(tex_offset, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let offset_pixel = vec4(in.alpha_and_shadow_color.yzw, offset_opacity);

        return mix(offset_pixel, base_pixel, outline_alpha);
    } else if in.render_type == text_drop_shadow_no_subpixel_render_type {
        var tex = vec4(0.0, 0.0, 0.0, 0.0);
        var tex_offset = vec4(0.0, 0.0, 0.0, 0.0);
        if in.texel_and_text_data.w == medium_text_type {
            tex = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            tex_offset = textureSampleGrad(medium_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == medium_italic_text_type {
            tex = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            tex_offset = textureSampleGrad(medium_italic_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == bold_text_type {
            tex = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            tex_offset = textureSampleGrad(bold_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        } else if in.texel_and_text_data.w == bold_italic_text_type {
            tex = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw, dx, dy);
            tex_offset = textureSampleGrad(bold_italic_tex, linear_sampler, in.pos_uv.zw - in.texel_and_text_data.xy, dx, dy);
        }

        let alpha = sample_msdf(tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, 0.5);
        let base_pixel = vec4(in.base_color_and_intensity.rgb, alpha);

        let outline_alpha = sample_msdf(tex, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let outlined_pixel = mix(vec4(in.outline_color_and_w.rgb, outline_alpha), base_pixel, alpha);

        let offset_opacity = sample_msdf(tex_offset, in.texel_and_text_data.z, in.alpha_and_shadow_color.x, in.outline_color_and_w.w);
        let offset_pixel = vec4(in.alpha_and_shadow_color.yzw, offset_opacity);

        return mix(offset_pixel, base_pixel, outline_alpha);
    } else if in.render_type == minimap_render_type {
        return textureSampleGrad(minimap_tex, default_sampler, in.pos_uv.zw, dx, dy);
    } else if in.render_type == menu_bg_render_type {
        return textureSampleGrad(menu_bg_tex, linear_sampler, in.pos_uv.zw, dx, dy);
    }

    return vec4(0.0, 0.0, 0.0, 0.0);
}