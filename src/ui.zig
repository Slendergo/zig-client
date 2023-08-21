const std = @import("std");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const map = @import("map.zig");

pub const StatusText = struct {
    // the texts' internal x/y
    screen_x: f32 = 0.0,
    screen_y: f32 = 0.0,
    size: f32 = 22.0,
    initial_size: f32 = 22.0,
    lifetime: i32 = 500,
    color: u32 = 0xFFFFFF,
    start_time: i32 = 0,
    alpha: f32 = 1.0,
    text: []u8 = &[0]u8{},
    obj_id: i32 = -1,
};

pub const medium_text_type = 0.0;
pub const medium_italic_text_type = 1.0;
pub const bold_text_type = 2.0;
pub const bold_italic_text_type = 3.0;

pub var status_texts: std.ArrayList(StatusText) = undefined;
pub var status_texts_to_remove: std.ArrayList(usize) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    status_texts = std.ArrayList(StatusText).init(allocator);
    status_texts_to_remove = std.ArrayList(usize).init(allocator);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    for (status_texts.items) |text| {
        allocator.free(text.text);
    }
    status_texts.deinit();
    status_texts_to_remove.deinit();
}

pub fn removeStatusText(obj_id: i32) void {
    for (status_texts.items, 0..) |text, i| {
        if (text.obj_id == obj_id) {
            status_texts_to_remove.append(i) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue;
        }
    }
}

pub fn update(time: i32, dt: i32, allocator: std.mem.Allocator) void {
    _ = dt;

    if (status_texts_to_remove.items.len > 0) {
        std.mem.reverse(usize, status_texts_to_remove.items);

        for (status_texts_to_remove.items) |idx| {
            allocator.free(status_texts.orderedRemove(idx).text);
        }

        status_texts_to_remove.clearRetainingCapacity();
    }

    for (status_texts.items, 0..) |*text, i| {
        const elapsed = time - text.start_time;
        if (elapsed > text.lifetime) {
            status_texts_to_remove.append(i) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue;
        }

        const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(text.lifetime));
        text.size = text.initial_size * @min(1.0, @max(0.7, 1.0 - frac * 0.3 + 0.075));
        text.alpha = 1.0 - frac + 0.33;
        if (map.findEntity(text.obj_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                inline else => |obj| {
                    text.screen_x = obj.screen_x - textWidth(text.size, text.text, bold_text_type) / 2;
                    text.screen_y = obj.screen_y - (frac * 40 + 20);
                },
            }
        }
    }

    std.mem.reverse(usize, status_texts_to_remove.items);

    for (status_texts_to_remove.items) |idx| {
        allocator.free(status_texts.orderedRemove(idx).text);
    }

    status_texts_to_remove.clearRetainingCapacity();
}

pub inline fn textWidth(size: f32, text: []const u8, text_type: f32) f32 {
    const size_scale = size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;

    var x_pointer: f32 = 0.0;
    for (text) |char| {
        const char_data = switch (@as(u32, @intFromFloat(text_type))) {
            0.0 => assets.medium_chars[char],
            1.0 => assets.medium_italic_chars[char],
            2.0 => assets.bold_chars[char],
            3.0 => assets.bold_italic_chars[char],
            else => unreachable,
        };

        x_pointer += char_data.x_advance * size_scale;
    }

    return x_pointer;
}
