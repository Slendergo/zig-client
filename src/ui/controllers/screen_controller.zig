const std = @import("std");
const ui = @import("../ui.zig");
const input = @import("../../input.zig");
const game_data = @import("../../game_data.zig");
const camera = @import("../../camera.zig");
const utils = @import("../../utils.zig");
const main = @import("../../main.zig");
const map = @import("../../map.zig");
const assets = @import("../../assets.zig");
const zglfw = @import("zglfw");

const AccountLoginScreen = @import("../screens/account/account_login_screen.zig").AccountLoginScreen;
const AccountRegisterScreen = @import("../screens/account/account_register_screen.zig").AccountRegisterScreen;
const CharCreateScreen = @import("../screens/character/char_create_screen.zig").CharCreateScreen;
const CharSelectScreen = @import("../screens/character/char_select_screen.zig").CharSelectScreen;
const MapEditorScreen = @import("../screens/map_editor_screen.zig").MapEditorScreen;
const GameScreen = @import("../screens/game_screen.zig").GameScreen;
const EmptyScreen = @import("../screens/empty_screen.zig").EmptyScreen;

pub const ScreenType = enum {
    empty,
    main_menu,
    register,
    char_select,
    char_create,
    game,
    editor,
};

pub const Screen = union(ScreenType) {
    empty: *EmptyScreen,
    main_menu: *AccountLoginScreen,
    register: *AccountRegisterScreen,
    char_select: *CharSelectScreen,
    char_create: *CharCreateScreen,
    game: *GameScreen,
    editor: *MapEditorScreen,
};

pub var ui_lock: std.Thread.Mutex = .{};
pub var elements: utils.DynSlice(ui.UiElement) = undefined;
pub var elements_to_remove: utils.DynSlice(*ui.UiElement) = undefined;
pub var current_screen: Screen = undefined;

var menu_background: *ui.MenuBackground = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    elements = try utils.DynSlice(ui.UiElement).init(64, allocator);
    elements_to_remove = try utils.DynSlice(*ui.UiElement).init(32, allocator);

    menu_background = try ui.MenuBackground.create(allocator, .{
        .x = 0,
        .y = 0,
        .w = camera.screen_width,
        .h = camera.screen_height,
    });

    current_screen = .{ .empty = try EmptyScreen.init(allocator) };
}

pub fn deinit() void {
    while (!ui_lock.tryLock()) {}
    defer ui_lock.unlock();

    menu_background.destroy();

    switch (current_screen) {
        inline else => |screen| screen.deinit(),
    }

    elements.deinit();
    elements_to_remove.deinit();
}

pub fn switchScreen(screen_type: ScreenType) void {
    menu_background.visible = screen_type != .game; // and screen_type != .editor;
    input.selected_key_mapper = null;

    switch (current_screen) {
        inline else => |screen| if (screen.inited) screen.deinit(),
    }

    // should probably figure out some comptime magic to avoid all this... todo
    switch (screen_type) {
        .empty => current_screen = .{ .empty = EmptyScreen.init(main._allocator) catch unreachable },
        .main_menu => {
            current_screen = .{ .main_menu = AccountLoginScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing login screen failed: {any}", .{e});
                return;
            } };
        },
        .register => {
            current_screen = .{ .register = AccountRegisterScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing register screen failed: {any}", .{e});
                return;
            } };
        },
        .char_select => {
            current_screen = .{ .char_select = CharSelectScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing char select screen failed: {any}", .{e});
                return;
            } };
        },
        .char_create => {
            current_screen = .{ .char_create = CharCreateScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing char create screen failed: {any}", .{e});
                return;
            } };
        },
        .game => {
            current_screen = .{ .game = GameScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing in game screen failed: {any}", .{e});
                return;
            } };
        },
        .editor => {
            current_screen = .{ .editor = MapEditorScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing in editor screen failed: {any}", .{e});
                return;
            } };
        },
    }
}

pub fn resize(w: f32, h: f32) void {
    menu_background.w = camera.screen_width;
    menu_background.h = camera.screen_height;

    switch (current_screen) {
        inline else => |screen| screen.resize(w, h),
    }
}

pub fn removeAttachedUi(obj_id: i32, allocator: std.mem.Allocator) void {
    while (!ui_lock.tryLock()) {}
    defer ui_lock.unlock();

    for (elements.items()) |*elem| {
        switch (elem.*) {
            .status => |*status| if (status.obj_id == obj_id) {
                status.destroy(allocator);
                continue;
            },
            .balloon => |*balloon| if (balloon.target_id == obj_id) {
                balloon.destroy(allocator);
                continue;
            },
            else => {},
        }
    }
}

fn elemMove(elem: ui.UiElement, x: f32, y: f32) void {
    switch (elem) {
        .container => |container| {
            if (!container.visible)
                return;

            if (container._is_dragging) {
                if (!container._clamp_x) {
                    container.x = x + container._drag_offset_x;
                    if (container._clamp_to_screen) {
                        if (container.x > 0) {
                            container.x = 0;
                        }
                        const bottom_x = container.x + container.width;
                        if (bottom_x < camera.screen_width) {
                            container.x = container.width;
                        }
                    }
                }
                if (!container._clamp_y) {
                    container.y = y + container._drag_offset_y;
                    if (container._clamp_to_screen) {
                        if (container.y > 0) {
                            container.y = 0;
                        }

                        const bottom_y = container.y + container.height;
                        if (bottom_y < camera.screen_height) {
                            container.y = bottom_y;
                        }
                    }
                }
            }

            for (container._elements.items()) |container_elem| {
                elemMove(container_elem, x - container.x, y - container.y);
            }
        },
        .item => |item| {
            if (!item.visible or !item._is_dragging)
                return;

            item.x = x + item._drag_offset_x;
            item.y = y + item._drag_offset_y;
        },
        .button => |button| {
            if (!button.visible)
                return;

            if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                button.state = .hovered;
            } else {
                button.state = .none;
            }
        },
        .toggle => |toggle| {
            if (!toggle.visible)
                return;

            if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                toggle.state = .hovered;
            } else {
                toggle.state = .none;
            }
        },
        .char_box => |box| {
            if (!box.visible)
                return;

            if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                box.state = .hovered;
            } else {
                box.state = .none;
            }
        },
        .input_field => |input_field| {
            if (!input_field.visible)
                return;

            if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                input_field.state = .hovered;
            } else {
                input_field.state = .none;
            }
        },
        .key_mapper => |key_mapper| {
            if (!key_mapper.visible)
                return;

            if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                key_mapper.state = .hovered;
            } else {
                key_mapper.state = .none;
            }
        },
        else => {},
    }
}

pub fn mouseMove(x: f32, y: f32) void {
    for (elements.items()) |elem| {
        elemMove(elem, x, y);
    }
}

fn elemPress(elem: ui.UiElement, x: f32, y: f32, mods: zglfw.Mods) bool {
    switch (elem) {
        .container => |container| {
            if (!container.visible)
                return false;

            var cont_iter = std.mem.reverseIterator(container._elements.items());
            while (cont_iter.next()) |container_elem| {
                if (elemPress(container_elem, x - container.x, y - container.y, mods))
                    return true;
            }

            if (container.draggable and utils.isInBounds(x, y, container.x, container.y, container.width, container.height)) {
                container._is_dragging = true;
                container._drag_start_x = container.x;
                container._drag_start_y = container.y;
                container._drag_offset_x = container.x - x;
                container._drag_offset_y = container.y - y;
            }
        },
        .item => |item| {
            if (!item.visible or !item.draggable)
                return false;

            if (utils.isInBounds(x, y, item.x, item.y, item.width(), item.height())) {
                if (mods.shift) {
                    item.shift_click_callback(item);
                    return true;
                }

                if (item._last_click_time + 333 * std.time.us_per_ms > main.current_time) {
                    item.double_click_callback(item);
                    return true;
                }

                item._is_dragging = true;
                item._drag_start_x = item.x;
                item._drag_start_y = item.y;
                item._drag_offset_x = item.x - x;
                item._drag_offset_y = item.y - y;
                item._last_click_time = main.current_time;
                return true;
            }
        },
        .button => |button| {
            if (!button.visible)
                return false;

            if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                button.state = .pressed;
                button.press_callback();
                assets.playSfx("ButtonClick");
                return true;
            }
        },
        .toggle => |toggle| {
            if (!toggle.visible)
                return false;

            if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                toggle.state = .pressed;
                toggle.toggled.* = !toggle.toggled.*;
                if (toggle.state_change) |callback| {
                    callback(toggle);
                }
                assets.playSfx("ButtonClick");
                return true;
            }
        },
        .char_box => |box| {
            if (!box.visible)
                return false;

            if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                box.state = .pressed;
                box.press_callback(box);
                assets.playSfx("ButtonClick");
                return true;
            }
        },
        .input_field => |input_field| {
            if (!input_field.visible)
                return false;

            if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                input.selected_input_field = input_field;
                input_field._last_input = 0;
                input_field.state = .pressed;
                return true;
            }
        },
        .key_mapper => |key_mapper| {
            if (!key_mapper.visible)
                return false;

            if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                key_mapper.state = .pressed;

                if (input.selected_key_mapper == null) {
                    key_mapper.listening = true;
                    input.selected_key_mapper = key_mapper;
                }

                assets.playSfx("ButtonClick");
                return true;
            }
        },
        else => {},
    }

    return false;
}

pub fn mousePress(x: f32, y: f32, mods: zglfw.Mods, button: zglfw.MouseButton) bool {
    if (input.selected_input_field) |input_field| {
        input_field._last_input = -1;
        input.selected_input_field = null;
    }

    if (input.selected_key_mapper) |key_mapper| {
        key_mapper.key = .unknown;
        key_mapper.mouse = button;
        key_mapper.listening = false;
        key_mapper.set_key_callback(key_mapper);
        input.selected_key_mapper = null;
    }

    var elem_iter = std.mem.reverseIterator(elements.items());
    while (elem_iter.next()) |elem| {
        if (elemPress(elem, x, y, mods))
            return true;
    }

    return false;
}

fn elemRelease(elem: ui.UiElement, x: f32, y: f32) void {
    switch (elem) {
        .container => |container| {
            if (!container.visible)
                return;

            if (container._is_dragging)
                container._is_dragging = false;

            for (container._elements.items()) |container_elem| {
                elemRelease(container_elem, x - container.x, y - container.y);
            }
        },
        .item => |item| {
            if (!item._is_dragging)
                return;

            item._is_dragging = false;
            item.drag_end_callback(item);
        },
        .button => |button| {
            if (!button.visible)
                return;

            if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                button.state = .none;
            }
        },
        .toggle => |toggle| {
            if (!toggle.visible)
                return;

            if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                toggle.state = .none;
            }
        },
        .char_box => |box| {
            if (!box.visible)
                return;

            if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                box.state = .none;
            }
        },
        .input_field => |input_field| {
            if (!input_field.visible)
                return;

            if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                input_field.state = .none;
            }
        },
        .key_mapper => |key_mapper| {
            if (!key_mapper.visible)
                return;

            if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                key_mapper.state = .none;
            }
        },
        else => {},
    }
}

pub fn mouseRelease(x: f32, y: f32) void {
    for (elements.items()) |elem| {
        elemRelease(elem, x, y);
    }
}

pub fn update(time: i64, dt: i64, allocator: std.mem.Allocator) !void {
    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    const ms_time = @divFloor(time, std.time.us_per_ms);
    const ms_dt = @as(f32, @floatFromInt(dt)) / std.time.us_per_ms;

    switch (current_screen) {
        inline else => |screen| try screen.update(ms_time, ms_dt),
    }

    for (elements.items()) |*elem| {
        switch (elem.*) {
            .status => |*status_text| {
                const elapsed = ms_time - status_text.start_time;
                if (elapsed > status_text.lifetime) {
                    elements_to_remove.add(elem) catch |e| {
                        std.log.err("Status text disposing failed: {any}", .{e});
                    };
                    continue;
                }

                const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(status_text.lifetime));
                status_text.text_data.size = status_text.initial_size * @min(1.0, @max(0.7, 1.0 - frac * 0.3 + 0.075));
                status_text.text_data.alpha = 1.0 - frac + 0.33;
                if (map.findEntityConst(status_text.obj_id)) |en| {
                    switch (en) {
                        .particle, .particle_effect, .projectile => {},
                        inline else => |obj| {
                            if (obj.dead) {
                                elements_to_remove.add(elem) catch |e| {
                                    std.log.err("Status text disposing failed: {any}", .{e});
                                };
                                continue;
                            }
                            status_text._screen_x = obj.screen_x - status_text.text_data.width() / 2;
                            status_text._screen_y = obj.screen_y - status_text.text_data.height() - frac * 40;
                        },
                    }
                }
            },
            .balloon => |*speech_balloon| {
                const elapsed = ms_time - speech_balloon.start_time;
                const lifetime = 5000;
                if (elapsed > lifetime) {
                    elements_to_remove.add(elem) catch |e| {
                        std.log.err("Speech balloon disposing failed: {any}", .{e});
                    };
                    continue;
                }

                const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, lifetime);
                const alpha = 1.0 - frac * 2.0 + 0.9;
                speech_balloon.image_data.normal.alpha = alpha; // assume no 9 slice
                speech_balloon.text_data.alpha = alpha;
                if (map.findEntityConst(speech_balloon.target_id)) |en| {
                    switch (en) {
                        .particle, .particle_effect, .projectile => {},
                        inline else => |obj| {
                            if (obj.dead) {
                                elements_to_remove.add(elem) catch |e| {
                                    std.log.err("Speech balloon disposing failed: {any}", .{e});
                                };
                                continue;
                            }
                            speech_balloon._screen_x = obj.screen_x - speech_balloon.width() / 2;
                            speech_balloon._screen_y = obj.screen_y - speech_balloon.height();
                        },
                    }
                }
            },
            else => {},
        }
    }

    while (!ui_lock.tryLock()) {}
    defer ui_lock.unlock();

    for (elements_to_remove.items()) |elem| {
        switch (elem.*) {
            .balloon => |*balloon| balloon.destroy(allocator),
            .status => |*status| status.destroy(allocator),
            else => {},
        }
    }

    elements_to_remove.clear();
}
