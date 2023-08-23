const std = @import("std");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const map = @import("map.zig");

pub const StatusText = struct {
    text: Text,
    // the texts' internal x/y
    screen_x: f32 = 0.0,
    screen_y: f32 = 0.0,
    initial_size: f32 = 22.0,
    lifetime: i32 = 500,
    start_time: i32 = 0,
    obj_id: i32 = -1,
};

pub const TextType = enum(u32) {
    medium = 0,
    medium_italic = 1,
    bold = 2,
    bold_italic = 3,
};

pub const Text = struct {
    text: []u8,
    size: f32,
    text_type: TextType = .medium,
    color: u32 = 0xFFFFFF,
    alpha: f32 = 1.0,
    shadow_color: u32 = 0x000000,
    shadow_alpha_mult: f32 = 0.5,
    shadow_texel_offset_mult: f32 = 6.0,

    pub fn width(self: Text) f32 {
        const size_scale = self.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;

        var x_pointer: f32 = 0.0;
        for (self.text) |char| {
            const char_data = switch (self.text_type) {
                .medium => assets.medium_chars[char],
                .medium_italic => assets.medium_italic_chars[char],
                .bold => assets.bold_chars[char],
                .bold_italic => assets.bold_italic_chars[char],
            };

            x_pointer += char_data.x_advance * size_scale;
        }

        return x_pointer;
    }

    pub fn height(self: Text) f32 {
        const size_scale = self.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
        const line_height = assets.CharacterData.line_height * assets.CharacterData.size * size_scale;
        return line_height;
    }
};

pub var status_texts: std.ArrayList(StatusText) = undefined;
pub var status_texts_to_remove: std.ArrayList(usize) = undefined;
pub var obj_ids_to_remove: std.ArrayList(i32) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    status_texts = std.ArrayList(StatusText).init(allocator);
    status_texts_to_remove = std.ArrayList(usize).init(allocator);
    obj_ids_to_remove = std.ArrayList(i32).init(allocator);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    for (status_texts.items) |status_text| {
        allocator.free(status_text.text.text);
    }
    status_texts.deinit();
    status_texts_to_remove.deinit();
    obj_ids_to_remove.deinit();
}

pub fn removeStatusText(obj_id: i32) void {
    for (status_texts.items) |text| {
        if (text.obj_id == obj_id) {
            obj_ids_to_remove.append(obj_id) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue;
        }
    }
}

pub fn update(time: i32, dt: i32, allocator: std.mem.Allocator) void {
    _ = dt;

    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    textUpdate: for (status_texts.items, 0..) |*status_text, i| {
        for (obj_ids_to_remove.items) |obj_id| {
            if (obj_id == status_text.obj_id) {
                status_texts_to_remove.append(i) catch |e| {
                    std.log.err("Status text disposing failed: {any}", .{e});
                };
                continue :textUpdate;
            }
        }

        const elapsed = time - status_text.start_time;
        if (elapsed > status_text.lifetime) {
            status_texts_to_remove.append(i) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue;
        }

        const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(status_text.lifetime));
        status_text.text.size = status_text.initial_size * @min(1.0, @max(0.7, 1.0 - frac * 0.3 + 0.075));
        status_text.text.alpha = 1.0 - frac + 0.33;
        if (map.findEntity(status_text.obj_id)) |en| {
            switch (en.*) {
                inline else => |obj| {
                    status_text.screen_x = obj.screen_x - status_text.text.width() / 2;
                    status_text.screen_y = obj.screen_y - (frac * 40 + 20);
                },
            }
        }
    }

    std.mem.reverse(usize, status_texts_to_remove.items);

    for (status_texts_to_remove.items) |idx| {
        allocator.free(status_texts.orderedRemove(idx).text.text);
    }

    obj_ids_to_remove.clearRetainingCapacity();
    status_texts_to_remove.clearRetainingCapacity();
}
