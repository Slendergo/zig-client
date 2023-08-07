const pad = @import("assets.zig").padding;
const rotate_speed = @import("settings.zig").rotate_speed;
const map = @import("map.zig");
const tau = @import("std").math.tau;

pub const px_per_tile: i16 = 56;
pub const size_mult: f32 = 48.0 / (8.0 + @as(f32, @floatFromInt(pad)));

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

var last_angle: f32 = -100.0;

pub fn update(target_x: f32, target_y: f32, dt: i32, rotate: i8) void {
    x = target_x;
    y = target_y;

    if (rotate != 0) {
        const float_dt: f32 = @floatFromInt(dt);
        const float_rotate: f32 = @floatFromInt(rotate);
        angle = @mod((angle + float_dt) * rotate_speed * float_rotate, tau);
    }

    const cos_angle = @cos(angle);
    const sin_angle = @sin(angle);

    cos = cos_angle * px_per_tile;
    sin = sin_angle * px_per_tile;
    x_cos = cos * clip_scale_x * 0.5;
    y_cos = cos * clip_scale_y * 0.5;
    x_sin = sin * clip_scale_x * 0.5;
    y_sin = sin * clip_scale_y * 0.5;
    clip_x = (target_x * cos_angle + target_y * sin_angle) * -px_per_tile;
    clip_y = (target_x * -sin_angle + target_y * cos_angle) * -px_per_tile;

    const w_half = screen_width / (2 * px_per_tile);
    const h_half = screen_height / (2 * px_per_tile);
    const max_dist = @ceil(@sqrt(w_half * w_half + h_half * h_half));
    max_dist_sq = max_dist * max_dist;

    const min_x_dt = target_x - max_dist;
    min_x = if (min_x_dt < 0) 0 else @intFromFloat(min_x_dt);
    max_x = @intFromFloat(target_x + max_dist);

    const min_y_dt = target_y - max_dist;
    min_y = if (min_y_dt < 0) 0 else @intFromFloat(min_y_dt);
    max_y = @intFromFloat(target_y + max_dist);
}
