const zglfw = @import("zglfw");
const settings = @import("settings.zig");
const std = @import("std");
const map = @import("map.zig");
const main = @import("main.zig");
const zgui = @import("zgui");
const camera = @import("camera.zig");
const ui = @import("ui/ui.zig");
const assets = @import("assets.zig");
const network = @import("network.zig");

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

pub var selected_input_field: ?*ui.InputField = null;

pub fn reset() void {
    move_up = 0.0;
    move_down = 0.0;
    move_left = 0.0;
    move_right = 0.0;
    rotate_left = 0;
    rotate_right = 0;
    rotate = 0;
    attacking = false;
}

fn keyPress(window: *zglfw.Window, key: zglfw.Key, mods: zglfw.Mods) void {
    if (ui.current_screen != .in_game)
        return;

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
        network.sendEscape();
    } else if (key == settings.interact.getKey()) {
        const int_id = map.interactive_id.load(.Acquire);
        if (int_id != -1) {
            switch (map.interactive_type.load(.Acquire)) {
                .portal => network.sendUsePortal(int_id),
                else => {},
            }
        }
    } else if (key == settings.ability.getKey()) {
        useAbility();
    } else if (key == settings.chat.getKey()) {
        selected_input_field = ui.in_game_screen.chat_input;
    } else if (key == settings.chat_cmd.getKey()) {
        charEvent(window, .slash);
        selected_input_field = ui.in_game_screen.chat_input;
    } else if (key == settings.inv_0.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 4 + 8 else 4);
    } else if (key == settings.inv_1.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 5 + 8 else 5);
    } else if (key == settings.inv_2.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 6 + 8 else 6);
    } else if (key == settings.inv_3.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 7 + 8 else 7);
    } else if (key == settings.inv_4.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 8 + 8 else 8);
    } else if (key == settings.inv_5.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 9 + 8 else 9);
    } else if (key == settings.inv_6.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 10 + 8 else 10);
    } else if (key == settings.inv_7.getKey()) {
        ui.in_game_screen.useItem(if (mods.control) 11 + 8 else 11);
    }
}

fn keyRelease(key: zglfw.Key) void {
    if (ui.current_screen != .in_game)
        return;

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

fn mousePress(window: *zglfw.Window, button: zglfw.MouseButton, mods: zglfw.Mods) void {
    if (ui.current_screen != .in_game)
        return;

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
        network.sendEscape();
    } else if (button == settings.interact.getMouse()) {
        const int_id = map.interactive_id.load(.Acquire);
        if (int_id != -1) {
            switch (map.interactive_type.load(.Acquire)) {
                .portal => network.sendUsePortal(int_id),
                else => {},
            }
        }
    } else if (button == settings.ability.getMouse()) {
        useAbility();
    } else if (button == settings.chat.getMouse()) {
        selected_input_field = ui.in_game_screen.chat_input;
    } else if (button == settings.chat_cmd.getMouse()) {
        charEvent(window, .slash);
        selected_input_field = ui.in_game_screen.chat_input;
    } else if (button == settings.inv_0.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 4 + 8 else 4);
    } else if (button == settings.inv_1.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 5 + 8 else 5);
    } else if (button == settings.inv_2.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 6 + 8 else 6);
    } else if (button == settings.inv_3.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 7 + 8 else 7);
    } else if (button == settings.inv_4.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 8 + 8 else 8);
    } else if (button == settings.inv_5.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 9 + 8 else 9);
    } else if (button == settings.inv_6.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 10 + 8 else 10);
    } else if (button == settings.inv_7.getMouse()) {
        ui.in_game_screen.useItem(if (mods.control) 11 + 8 else 11);
    }
}

fn mouseRelease(button: zglfw.MouseButton) void {
    if (ui.current_screen != .in_game)
        return;

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

pub fn charEvent(window: *zglfw.Window, char: zglfw.Char) callconv(.C) void {
    _ = window;
    if (selected_input_field) |input_field| {
        const char_code = @intFromEnum(char);
        if (char_code > std.math.maxInt(u8) or char_code < std.math.minInt(u8)) {
            return;
        }

        const byte_code: u8 = @intCast(char_code);
        if (!std.ascii.isASCII(byte_code) or input_field._index >= 256)
            return;

        input_field.text_data.backing_buffer[input_field._index] = byte_code;
        input_field._index += 1;
        input_field.text_data.text = input_field.text_data.backing_buffer[0..input_field._index];
        return;
    }
}

pub fn keyEvent(window: *zglfw.Window, key: zglfw.Key, scancode: i32, action: zglfw.Action, mods: zglfw.Mods) callconv(.C) void {
    _ = scancode;

    if (action == .press or action == .repeat) {
        if (selected_input_field) |input_field| {
            if (mods.control) {
                switch (key) {
                    .c => {
                        const old = input_field.text_data.text;
                        input_field.text_data.backing_buffer[input_field._index] = 0;
                        window.setClipboardString(input_field.text_data.backing_buffer[0..input_field._index :0]);
                        input_field.text_data.text = old;
                    },
                    .v => {
                        if (window.getClipboardString()) |clip_str| {
                            const clip_len = clip_str.len;
                            @memcpy(input_field.text_data.backing_buffer[input_field._index .. input_field._index + clip_len], clip_str);
                            input_field._index += @intCast(clip_len);
                            input_field.text_data.text = input_field.text_data.backing_buffer[0..input_field._index];
                            return;
                        }
                    },
                    .x => {
                        input_field.text_data.backing_buffer[input_field._index] = 0;
                        window.setClipboardString(input_field.text_data.backing_buffer[0..input_field._index :0]);
                        input_field.clear();
                    },
                    else => {},
                }
            }

            if (key == .enter) {
                if (input_field.enter_callback) |enter_cb| {
                    enter_cb(input_field.text_data.text);
                    input_field.clear();
                    selected_input_field = null;
                }

                return;
            }

            if (key == .backspace and input_field._index > 0) {
                input_field._index -= 1;
                input_field.text_data.text = input_field.text_data.backing_buffer[0..input_field._index];
                return;
            }

            return;
        }
    }

    if (action == .press) {
        keyPress(window, key, mods);
    } else if (action == .release) {
        keyRelease(key);
    }

    updateState();
}

pub fn mouseEvent(window: *zglfw.Window, button: zglfw.MouseButton, action: zglfw.Action, mods: zglfw.Mods) callconv(.C) void {
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

    if (action == .press) {
        if (!ui.mousePress(@floatCast(mouse_x), @floatCast(mouse_y), mods))
            mousePress(window, button, mods);
    } else if (action == .release) {
        ui.mouseRelease(@floatCast(mouse_x), @floatCast(mouse_y));
        mouseRelease(button);
    }

    updateState();
}

pub fn updateState() void {
    rotate = rotate_right - rotate_left;

    // need a writer lock for shooting
    while (!map.object_lock.tryLock()) {}
    defer map.object_lock.unlock();

    if (map.localPlayerRef()) |local_player| {
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
    }
}

pub fn mouseMoveEvent(window: *zglfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    _ = window;
    mouse_x = xpos;
    mouse_y = ypos;

    ui.mouseMove(@floatCast(mouse_x), @floatCast(mouse_y));
}

fn useAbility() void {
    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    if (map.localPlayerConst()) |local_player| {
        const world_pos = camera.screenToWorld(@floatCast(mouse_x), @floatCast(mouse_y));

        network.sendUseItem(main.current_time, .{
            .object_id = local_player.obj_id,
            .slot_id = 1,
            .object_type = local_player.inventory[1],
        }, .{ .x = world_pos.x, .y = world_pos.y }, 0);
    }
}
