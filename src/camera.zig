const pad = @import("assets.zig").padding;
const rotate_speed = @import("settings.zig").rotate_speed;
const std = @import("std");
const map = @import("map.zig");
const math = @import("std").math;
const utils = @import("utils.zig");

pub const px_per_tile: i16 = 88;
pub const size_mult: f32 = 8.0;

pub var x = std.atomic.Atomic(f32).init(0.0);
pub var y = std.atomic.Atomic(f32).init(0.0);
pub var z = std.atomic.Atomic(f32).init(0.0);

pub var minimap_zoom: f32 = 4.0;
pub var quake = false;
pub var quake_amount: f32 = 0.0;

pub var pad_x_cos: f32 = 0.0;
pub var pad_y_cos: f32 = 0.0;
pub var pad_x_sin: f32 = 0.0;
pub var pad_y_sin: f32 = 0.0;
pub var cos: f32 = 0.0;
pub var sin: f32 = 0.0;
pub var x_cos: f32 = 0.0;
pub var y_cos: f32 = 0.0;
pub var x_sin: f32 = 0.0;
pub var y_sin: f32 = 0.0;
pub var clip_x: f32 = 0.0;
pub var clip_y: f32 = 0.0;

pub var angle: f32 = 0.0;
pub var angle_unbound: f32 = 0.0;
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

pub fn update(target_x: f32, target_y: f32, dt: f32, rotate: i8) void {
    var tx: f32 = target_x;
    var ty: f32 = target_y;
    if (quake) {
        const max_quake = 0.5;
        const quake_buildup_ms = 10000;
        quake_amount += dt * max_quake / quake_buildup_ms;
        if (quake_amount > max_quake)
            quake_amount = max_quake;
        tx += utils.plusMinus(quake_amount);
        ty += utils.plusMinus(quake_amount);
    }

    x.store(tx, .Release);
    y.store(ty, .Release);

    if (rotate != 0) {
        const float_rotate: f32 = @floatFromInt(rotate);
        angle = @mod(angle + dt * rotate_speed * float_rotate, math.tau);
        angle_unbound += dt * rotate_speed * float_rotate;
    }

    const cos_angle = @cos(angle);
    const sin_angle = @sin(angle);

    const pad_cos = cos_angle * (px_per_tile + 1) * scale;
    const pad_sin = sin_angle * (px_per_tile + 1) * scale;
    pad_x_cos = pad_cos * clip_scale_x * 0.5;
    pad_y_cos = pad_cos * clip_scale_y * 0.5;
    pad_x_sin = pad_sin * clip_scale_x * 0.5;
    pad_y_sin = pad_sin * clip_scale_y * 0.5;

    cos = cos_angle * px_per_tile * scale;
    sin = sin_angle * px_per_tile * scale;
    x_cos = cos * clip_scale_x * 0.5;
    y_cos = cos * clip_scale_y * 0.5;
    x_sin = sin * clip_scale_x * 0.5;
    y_sin = sin * clip_scale_y * 0.5;
    clip_x = (tx * cos_angle + ty * sin_angle) * -px_per_tile * scale;
    clip_y = (tx * -sin_angle + ty * cos_angle) * -px_per_tile * scale;

    const w_half = screen_width / (2 * px_per_tile * scale);
    const h_half = screen_height / (2 * px_per_tile * scale);
    const max_dist = @ceil(@sqrt(w_half * w_half + h_half * h_half));
    max_dist_sq = max_dist * max_dist;

    const min_x_dt = tx - max_dist;
    min_x = if (min_x_dt < 0) 0 else @intFromFloat(min_x_dt);
    min_x = @max(0, min_x);
    max_x = @intFromFloat(tx + max_dist);
    max_x = @min(@as(u32, @intCast(map.width - 1)), max_x);

    const min_y_dt = ty - max_dist;
    min_y = if (min_y_dt < 0) 0 else @intFromFloat(min_y_dt);
    min_y = @max(0, min_y);
    max_y = @intFromFloat(ty + max_dist);
    max_y = @min(@as(u32, @intCast(map.height - 1)), max_y);
}

pub inline fn rotateAroundCameraClip(x_in: f32, y_in: f32) utils.Point {
    return utils.Point{
        .x = x_in * cos + y_in * sin + clip_x,
        .y = x_in * -sin + y_in * cos + clip_y,
    };
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

pub fn screenToWorld(x_in: f32, y_in: f32) utils.Point {
    const cos_angle = @cos(angle);
    const sin_angle = @sin(angle);
    const x_div = (x_in - screen_width / 2.0) / px_per_tile * scale;
    const y_div = (y_in - screen_height / 2.0) / px_per_tile * scale;
    return utils.Point{
        .x = x.load(.Acquire) + x_div * cos_angle - y_div * sin_angle,
        .y = y.load(.Acquire) + x_div * sin_angle + y_div * cos_angle,
    };
}
