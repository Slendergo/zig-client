@group(0) @binding(0) var defaultSampler: sampler;
@group(0) @binding(1) var medium_tex: texture_2d<f32>;
@group(0) @binding(2) var medium_italic_tex: texture_2d<f32>;
@group(0) @binding(3) var bold_tex: texture_2d<f32>;
@group(0) @binding(4) var bold_italic_tex: texture_2d<f32>;

const mediumTextType = 0.0;
const mediumItalicTextType = 1.0;
const boldTextType = 2.0;
const boldItalicTextType = 3.0;

struct VertexInput {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>,
  @location(3) textType: f32,
  @location(4) alphaMult: f32,
}

struct VertexOutput {
  @builtin(position) position: vec4<f32>,
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) color: vec3<f32>,
  @location(3) textType: f32,
  @location(4) alphaMult: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.position = vec4(in.pos, 1.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    out.textType = in.textType;
    out.alphaMult = in.alphaMult;
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
    var unitRange = vec2(2.0, 2.0);
    if in.textType == mediumTextType {
        tex = textureSampleGrad(medium_tex, defaultSampler, in.uv, dx, dy);
        unitRange /= vec2<f32>(textureDimensions(medium_tex, 0));
    } else if in.textType == mediumItalicTextType {
        tex = textureSampleGrad(medium_italic_tex, defaultSampler, in.uv, dx, dy);
        unitRange /= vec2<f32>(textureDimensions(medium_italic_tex, 0));
    } else if in.textType == boldTextType {
        tex = textureSampleGrad(bold_tex, defaultSampler, in.uv, dx, dy);
        unitRange /= vec2<f32>(textureDimensions(bold_tex, 0));
    } else if in.textType == boldItalicTextType {
        tex = textureSampleGrad(bold_italic_tex, defaultSampler, in.uv, dx, dy);
        unitRange /= vec2<f32>(textureDimensions(bold_italic_tex, 0));
    }

    let screenTexSize = vec2(1.0, 1.0) / fwidth(in.uv);
    let screenPxDist = max(0.5 * dot(unitRange, screenTexSize), 1.0) * (median(tex.r, tex.g, tex.b) - 0.5);
    let opacity = clamp(screenPxDist + 0.5, 0.0, 1.0) * in.alphaMult;
    return vec4(in.color, opacity);
    //return mix(vec4(0.0, 0.0, 0.0, 1.0), vec4(in.color, 1.0), opacity);
}