const pad = @import("assets.zig").padding;
const rotate_speed = @import("settings.zig").rotate_speed;
const map = @import("map.zig");
const math = @import("std").math;
const utils = @import("utils.zig");

pub const px_per_tile: i16 = 88;
pub const size_mult: f32 = 80.0 / (8.0 + @as(f32, @floatFromInt(pad)));

pub var x: f32 = 0.0;
pub var y: f32 = 0.0;
pub var z: f32 = 0.0;

pub var cos: f32 = 0.0;
pub var sin: f32 = 0.0;
pub var x_cos: f32 = 0.0;
pub var y_cos: f32 = 0.0;
pub var x_sin: f32 = 0.0;
pub var y_sin: f32 = 0.0;
pub var clip_x: f32 = 0.0;
pub var clip_y: f32 = 0.0;

pub var angle: f32 = 0.0;
pub var min_x: u32 = 0;
pub var min_y: u32 = 0;
pub var max_x: u32 = 0;
pub var max_y: u32 = 0;
pub var max_dist_sq: f32 = 0.0;

pub var screen_width: f32 = 1280.0;
pub var screen_height: f32 = 720.0;
pub var clip_scale_x: f32 = 2.0 / 1280.0;
pub var clip_scale_y: f32 = 2.0 / 720.0;

pub var scale: f32 = 1.0;

pub fn update(target_x: f32, target_y: f32, dt: i32, rotate: i8) void {
    x = target_x;
    y = target_y;

    if (rotate != 0) {
        const float_dt: f32 = @floatFromInt(dt);
        const float_rotate: f32 = @floatFromInt(rotate);
        angle = @mod(angle + float_dt * rotate_speed * float_rotate, math.tau);
    }

    const cos_angle = @cos(angle);
    const sin_angle = @sin(angle);

    cos = cos_angle * px_per_tile * scale;
    sin = sin_angle * px_per_tile * scale;
    x_cos = cos * clip_scale_x * 0.5;
    y_cos = cos * clip_scale_y * 0.5;
    x_sin = sin * clip_scale_x * 0.5;
    y_sin = sin * clip_scale_y * 0.5;
    clip_x = (target_x * cos_angle + target_y * sin_angle) * -px_per_tile * scale;
    clip_y = (target_x * -sin_angle + target_y * cos_angle) * -px_per_tile * scale;

    const w_half = screen_width / (2 * px_per_tile * scale);
    const h_half = screen_height / (2 * px_per_tile * scale);
    const max_dist = @ceil(@sqrt(w_half * w_half + h_half * h_half));
    max_dist_sq = max_dist * max_dist;

    const min_x_dt = target_x - max_dist;
    min_x = if (min_x_dt < 0) 0 else @intFromFloat(min_x_dt);
    max_x = @intFromFloat(target_x + max_dist);

    const min_y_dt = target_y - max_dist;
    min_y = if (min_y_dt < 0) 0 else @intFromFloat(min_y_dt);
    max_y = @intFromFloat(target_y + max_dist);
}

pub inline fn rotateAroundCamera(x_in: f32, y_in: f32) utils.Point {
    return utils.Point{
        .x = x_in * cos + y_in * sin + clip_x + screen_width / 2.0,
        .y = x_in * -sin + y_in * cos + clip_y + screen_height / 2.0,
    };
}

pub inline fn visibleInCamera(x_in: f32, y_in: f32) bool {
    if (x_in < 0 or y_in < 0)
        return false;
        
    const floor_x: u32 = @intFromFloat(@floor(x_in));
    const floor_y: u32 = @intFromFloat(@floor(y_in));
    return !(floor_x < min_x or floor_x > max_x or floor_y < min_y or floor_y > max_y);
}

pub inline fn screenToWorld(x_in: f32, y_in: f32) utils.Point {
    const cos_angle = @cos(angle);
    const sin_angle = @sin(angle);
    const x_div = x_in / px_per_tile * scale;
    const y_div = y_in / px_per_tile * scale;
    return utils.Point{
        .x = x_div * cos_angle + y_div * sin_angle,
        .y = x_div * -sin_angle + y_div * cos_angle,
    };
}
