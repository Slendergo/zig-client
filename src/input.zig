const zglfw = @import("zglfw");
const settings = @import("settings.zig");
const std = @import("std");
const map = @import("map.zig");
const main = @import("main.zig");
const zgui = @import("zgui");
const camera = @import("camera.zig");
const ui = @import("ui.zig");
const assets = @import("assets.zig");

var move_up: f32 = 0.0;
var move_down: f32 = 0.0;
var move_left: f32 = 0.0;
var move_right: f32 = 0.0;
var rotate_left: i8 = 0;
var rotate_right: i8 = 0;

pub var attacking: bool = false;
pub var walking_speed_multiplier: f32 = 1.0;
pub var rotate: i8 = 0;
pub var mouse_x: f64 = 0.0;
pub var mouse_y: f64 = 0.0;

pub fn reset() void {
    move_up = 0.0;
    move_down = 0.0;
    move_left = 0.0;
    move_right = 0.0;
    rotate_left = 0;
    rotate_right = 0;
    rotate = 0;
}

inline fn keyPress(key: zglfw.Key) void {
    if (key == settings.move_up.getKey()) {
        move_up = 1.0;
    } else if (key == settings.move_down.getKey()) {
        move_down = 1.0;
    } else if (key == settings.move_left.getKey()) {
        move_left = 1.0;
    } else if (key == settings.move_right.getKey()) {
        move_right = 1.0;
    } else if (key == settings.rotate_left.getKey()) {
        rotate_left = 1;
    } else if (key == settings.rotate_right.getKey()) {
        rotate_right = 1;
    } else if (key == settings.walk.getKey()) {
        walking_speed_multiplier = 0.5;
    } else if (key == settings.reset_camera.getKey()) {
        camera.angle = 0;
        camera.angle_unbound = 0;
    } else if (key == settings.shoot.getKey()) {
        attacking = true;
    } else if (key == settings.options.getKey()) {
        main.disconnect();
    } else if (key == settings.escape.getKey()) {
        if (main.server) |*server|
            server.sendEscape();
    } else if (key == settings.interact.getKey()) {
        const int_id = map.interactive_id.load(.Acquire);
        if (int_id != -1) {
            if (main.server) |*server|
                server.sendUsePortal(int_id);
        }
    } else if (key == settings.ability.getKey()) {
        useAbility();
    }
}

inline fn keyRelease(key: zglfw.Key) void {
    if (key == settings.move_up.getKey()) {
        move_up = 0.0;
    } else if (key == settings.move_down.getKey()) {
        move_down = 0.0;
    } else if (key == settings.move_left.getKey()) {
        move_left = 0.0;
    } else if (key == settings.move_right.getKey()) {
        move_right = 0.0;
    } else if (key == settings.rotate_left.getKey()) {
        rotate_left = 0;
    } else if (key == settings.rotate_right.getKey()) {
        rotate_right = 0;
    } else if (key == settings.walk.getKey()) {
        walking_speed_multiplier = 1.0;
    } else if (key == settings.shoot.getKey()) {
        attacking = false;
    }
}

inline fn mousePress(button: zglfw.MouseButton) void {
    if (button == settings.move_up.getMouse()) {
        move_up = 1.0;
    } else if (button == settings.move_down.getMouse()) {
        move_down = 1.0;
    } else if (button == settings.move_left.getMouse()) {
        move_left = 1.0;
    } else if (button == settings.move_right.getMouse()) {
        move_right = 1.0;
    } else if (button == settings.rotate_left.getMouse()) {
        rotate_left = 1;
    } else if (button == settings.rotate_right.getMouse()) {
        rotate_right = 1;
    } else if (button == settings.walk.getMouse()) {
        walking_speed_multiplier = 0.5;
    } else if (button == settings.reset_camera.getMouse()) {
        camera.angle = 0;
        camera.angle_unbound = 0;
    } else if (button == settings.shoot.getMouse()) {
        attacking = true;
    } else if (button == settings.options.getMouse()) {
        main.disconnect();
    } else if (button == settings.escape.getMouse()) {
        if (main.server) |*server|
            server.sendEscape();
    } else if (button == settings.interact.getMouse()) {
        const int_id = map.interactive_id.load(.Acquire);
        if (int_id != -1) {
            if (main.server) |*server|
                server.sendUsePortal(int_id);
        }
    } else if (button == settings.ability.getMouse()) {
        useAbility();
    }
}

inline fn mouseRelease(button: zglfw.MouseButton) void {
    if (button == settings.move_up.getMouse()) {
        move_up = 0.0;
    } else if (button == settings.move_down.getMouse()) {
        move_down = 0.0;
    } else if (button == settings.move_left.getMouse()) {
        move_left = 0.0;
    } else if (button == settings.move_right.getMouse()) {
        move_right = 0.0;
    } else if (button == settings.rotate_left.getMouse()) {
        rotate_left = 0;
    } else if (button == settings.rotate_right.getMouse()) {
        rotate_right = 0;
    } else if (button == settings.walk.getMouse()) {
        walking_speed_multiplier = 1.0;
    } else if (button == settings.shoot.getMouse()) {
        attacking = false;
    }
}

pub fn keyEvent(window: *zglfw.Window, key: zglfw.Key, scancode: i32, action: zglfw.Action, mods: zglfw.Mods) callconv(.C) void {
    _ = window;
    _ = scancode;
    _ = mods;

    if (main.current_screen != .in_game)
        return;

    if (action == .press) {
        keyPress(key);
    } else if (action == .release) {
        keyRelease(key);
    }

    updateState();
}

pub fn mouseEvent(window: *zglfw.Window, button: zglfw.MouseButton, action: zglfw.Action, mods: zglfw.Mods) callconv(.C) void {
    _ = mods;

    if (action == .press) {
        window.setCursor(switch (settings.selected_cursor) {
            .basic => assets.default_cursor_pressed,
            .royal => assets.royal_cursor_pressed,
            .ranger => assets.ranger_cursor_pressed,
            .aztec => assets.aztec_cursor_pressed,
            .fiery => assets.fiery_cursor_pressed,
            .target_enemy => assets.target_enemy_cursor_pressed,
            .target_ally => assets.target_ally_cursor_pressed,
        });
    } else if (action == .release) {
        window.setCursor(switch (settings.selected_cursor) {
            .basic => assets.default_cursor,
            .royal => assets.royal_cursor,
            .ranger => assets.ranger_cursor,
            .aztec => assets.aztec_cursor,
            .fiery => assets.fiery_cursor,
            .target_enemy => assets.target_enemy_cursor,
            .target_ally => assets.target_ally_cursor,
        });
    }

    if (main.current_screen != .in_game)
        return;

    if (action == .press) {
        mousePress(button);
        ui.mousePress(@floatCast(mouse_x), @floatCast(mouse_y));
    } else if (action == .release) {
        mouseRelease(button);
        ui.mouseRelease(@floatCast(mouse_x), @floatCast(mouse_y));
    }

    updateState();
}

pub fn updateState() void {
    rotate = rotate_right - rotate_left;

    // need a writer lock for shooting
    while (!map.object_lock.tryLock()) {}
    defer map.object_lock.unlock();

    if (map.findEntity(map.local_player_id)) |en| {
        switch (en.*) {
            .player => |*local_player| {
                const y_dt = move_down - move_up;
                const x_dt = move_right - move_left;
                local_player.move_angle = if (y_dt == 0 and x_dt == 0) std.math.nan(f32) else std.math.atan2(f32, y_dt, x_dt);
                local_player.walk_speed_multiplier = walking_speed_multiplier;

                if (attacking) {
                    const y: f32 = @floatCast(mouse_y);
                    const x: f32 = @floatCast(mouse_x);
                    const shoot_angle = std.math.atan2(f32, y - camera.screen_height / 2.0, x - camera.screen_width / 2.0) + camera.angle;
                    local_player.shoot(shoot_angle, main.current_time);
                }
            },
            else => {},
        }
    }
}

pub fn mouseMoveEvent(window: *zglfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    mouse_x = xpos;
    mouse_y = ypos;

    ui.mouseMove(@floatCast(mouse_x), @floatCast(mouse_y));
}

inline fn useAbility() void {
    if (main.server) |*server| {
        while (!map.object_lock.tryLockShared()) {}
        defer map.object_lock.unlockShared();

        if (map.findEntity(map.local_player_id)) |en| {
            switch (en.*) {
                .player => |local_player| {
                    const world_pos = camera.screenToWorld(@floatCast(mouse_x), @floatCast(mouse_y));

                    server.sendUseItem(main.current_time, .{
                        .object_id = local_player.obj_id,
                        .slot_id = 1,
                        .object_type = @intCast(local_player.inventory[1]),
                    }, .{ .x = world_pos.x, .y = world_pos.y }, 0);
                },
                else => {},
            }
        }
    }
}
