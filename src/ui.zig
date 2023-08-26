const std = @import("std");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const map = @import("map.zig");
const utils = @import("utils.zig");

pub const RGBF32 = extern struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn fromValues(r: f32, g: f32, b: f32) RGBF32 {
        return RGBF32{ .r = r, .g = g, .b = b };
    }

    pub fn fromInt(int: i32) RGBF32 {
        return RGBF32{
            .r = @as(f32, @floatFromInt((int & 0x00FF0000) >> 16)) / 255.0,
            .g = @as(f32, @floatFromInt((int & 0x0000FF00) >> 8)) / 255.0,
            .b = @as(f32, @floatFromInt((int & 0x000000FF) >> 0)) / 255.0,
        };
    }
};

pub const ButtonState = enum(u8) {
    none = 0,
    pressed = 1,
    hovered = 2,
};
pub const Button = struct {
    x: f32,
    y: f32,
    base_image_data: ImageData,
    press_callback: *const fn () void,
    state: ButtonState = .none,
    hover_image_data: ?ImageData = null,
    press_image_data: ?ImageData = null,
    text: ?Text = null,

    pub inline fn imageData(self: Button) ImageData {
        switch (self.state) {
            .none => return self.base_image_data,
            .pressed => return self.press_image_data orelse self.base_image_data,
            .hovered => return self.hover_image_data orelse self.base_image_data,
        }
    }

    pub inline fn width(self: Button) f32 {
        if (self.text) |text| {
            return @max(self.imageData().width(), text.width());
        } else {
            return self.imageData().width();
        }
    }

    pub inline fn height(self: Button) f32 {
        if (self.text) |text| {
            return @max(self.imageData().height(), text.height());
        } else {
            return self.imageData().width();
        }
    }
};

pub const ImageData = struct {
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    alpha: f32 = 1.0,
    atlas_data: assets.AtlasData,

    pub inline fn width(self: ImageData) f32 {
        return self.atlas_data.texWRaw() * self.scale_x;
    }

    pub inline fn height(self: ImageData) f32 {
        return self.atlas_data.texHRaw() * self.scale_y;
    }
};

pub const Image = struct {
    x: f32,
    y: f32,
    image_data: ImageData,
};

pub const SpeechBalloon = struct {
    image_data: ImageData,
    text: Text,
    target_id: i32,
    start_time: i32,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: SpeechBalloon) f32 {
        return @max(self.image_data.width(), self.text.width());
    }

    pub inline fn height(self: SpeechBalloon) f32 {
        return @max(self.image_data.height(), self.text.height());
    }
};

pub const UiText = struct {
    x: f32,
    y: f32,
    text: Text,
};

pub const StatusText = struct {
    text: Text,
    initial_size: f32,
    lifetime: i32 = 500,
    start_time: i32 = 0,
    obj_id: i32 = -1,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: StatusText) f32 {
        return self.image.width();
    }

    pub inline fn height(self: StatusText) f32 {
        return self.image.height();
    }
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
    color: i32 = 0xFFFFFF,
    alpha: f32 = 1.0,
    shadow_color: i32 = 0x000000,
    shadow_alpha_mult: f32 = 0.5,
    shadow_texel_offset_mult: f32 = 6.0,
    max_width: f32 = @as(f32, std.math.maxInt(u32)),

    pub fn width(self: Text) f32 {
        const size_scale = self.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;

        var x_max: f32 = 0.0;
        var x_pointer: f32 = 0.0;
        for (self.text) |char| {
            if (char == '\n') {
                x_pointer = 0;
                continue;
            }

            const char_data = switch (self.text_type) {
                .medium => assets.medium_chars[char],
                .medium_italic => assets.medium_italic_chars[char],
                .bold => assets.bold_chars[char],
                .bold_italic => assets.bold_italic_chars[char],
            };

            x_pointer += char_data.x_advance * size_scale;
            if (x_pointer > x_max)
                x_max = x_pointer;
        }

        return @min(x_max, self.max_width);
    }

    pub fn height(self: Text) f32 {
        const size_scale = self.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
        const line_height = assets.CharacterData.line_height * assets.CharacterData.size * size_scale;

        var x_pointer: f32 = 0.0;
        var y_pointer: f32 = line_height;
        for (self.text) |char| {
            const char_data = switch (self.text_type) {
                .medium => assets.medium_chars[char],
                .medium_italic => assets.medium_italic_chars[char],
                .bold => assets.bold_chars[char],
                .bold_italic => assets.bold_italic_chars[char],
            };

            const next_x_pointer = x_pointer + char_data.x_advance * size_scale;
            if (char == '\n' or next_x_pointer > self.max_width) {
                x_pointer = 0.0;
                y_pointer += line_height;
                continue;
            }

            x_pointer = next_x_pointer;
        }

        return y_pointer;
    }
};

pub var buttons: utils.DynSlice(Button) = undefined;
pub var ui_images: utils.DynSlice(Image) = undefined;
pub var speech_balloons: utils.DynSlice(SpeechBalloon) = undefined;
pub var speech_balloons_to_remove: utils.DynSlice(usize) = undefined;
pub var status_texts: utils.DynSlice(StatusText) = undefined;
pub var status_texts_to_remove: utils.DynSlice(usize) = undefined;
pub var obj_ids_to_remove: utils.DynSlice(i32) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    buttons = try utils.DynSlice(Button).init(10, allocator);
    ui_images = try utils.DynSlice(Image).init(10, allocator);
    speech_balloons = try utils.DynSlice(SpeechBalloon).init(10, allocator);
    speech_balloons_to_remove = try utils.DynSlice(usize).init(10, allocator);
    status_texts = try utils.DynSlice(StatusText).init(30, allocator);
    status_texts_to_remove = try utils.DynSlice(usize).init(30, allocator);
    obj_ids_to_remove = try utils.DynSlice(i32).init(40, allocator);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    buttons.deinit();
    ui_images.deinit();
    speech_balloons.deinit();
    speech_balloons_to_remove.deinit();
    for (status_texts.items()) |status_text| {
        allocator.free(status_text.text.text);
    }
    status_texts.deinit();
    status_texts_to_remove.deinit();
    obj_ids_to_remove.deinit();
}

pub fn removeAttachedUi(obj_id: i32) void {
    for (status_texts.items()) |text| {
        if (text.obj_id == obj_id) {
            obj_ids_to_remove.add(obj_id) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue;
        }
    }

    for (speech_balloons.items()) |balloon| {
        if (balloon.target_id == obj_id) {
            obj_ids_to_remove.add(obj_id) catch |e| {
                std.log.err("Speech balloon disposing failed: {any}", .{e});
            };
            continue;
        }
    }
}

pub fn mouseMove(x: f32, y: f32) void {
    for (buttons.items()) |*button| {
        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.state = .hovered;
        } else {
            button.state = .none;
        }
    }
}

pub fn mousePress(x: f32, y: f32) void {
    for (buttons.items()) |*button| {
        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.press_callback();
            button.state = .pressed;
        }
    }
}

pub fn mouseRelease(x: f32, y: f32) void {
    for (buttons.items()) |*button| {
        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.state = .none;
        }
    }
}

pub fn update(time: i32, dt: i32, allocator: std.mem.Allocator) void {
    _ = dt;

    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    textUpdate: for (status_texts.items(), 0..) |*status_text, i| {
        for (obj_ids_to_remove.items()) |obj_id| {
            if (obj_id == status_text.obj_id) {
                status_texts_to_remove.add(i) catch |e| {
                    std.log.err("Status text disposing failed: {any}", .{e});
                };
                continue :textUpdate;
            }
        }

        const elapsed = time - status_text.start_time;
        if (elapsed > status_text.lifetime) {
            status_texts_to_remove.add(i) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue :textUpdate;
        }

        const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(status_text.lifetime));
        status_text.text.size = status_text.initial_size * @min(1.0, @max(0.7, 1.0 - frac * 0.3 + 0.075));
        status_text.text.alpha = 1.0 - frac + 0.33;
        if (map.findEntity(status_text.obj_id)) |en| {
            switch (en.*) {
                inline else => |obj| {
                    status_text._screen_x = obj.screen_x - status_text.text.width() / 2;
                    status_text._screen_y = obj.screen_y - status_text.text.height() - frac * 40;
                },
            }
        }
    }

    std.mem.reverse(usize, status_texts_to_remove.items());

    for (status_texts_to_remove.items()) |idx| {
        allocator.free(status_texts.remove(idx).text.text);
    }

    status_texts_to_remove.clear();

    balloonUpdate: for (speech_balloons.items(), 0..) |*speech_balloon, i| {
        for (obj_ids_to_remove.items()) |obj_id| {
            if (obj_id == speech_balloon.target_id) {
                speech_balloons_to_remove.add(i) catch |e| {
                    std.log.err("Speech balloon disposing failed: {any}", .{e});
                };
                continue :balloonUpdate;
            }
        }

        const elapsed = time - speech_balloon.start_time;
        const lifetime = 5000;
        if (elapsed > lifetime) {
            speech_balloons_to_remove.add(i) catch |e| {
                std.log.err("Speech balloon disposing failed: {any}", .{e});
            };
            continue :balloonUpdate;
        }

        const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, lifetime);
        const alpha = 1.0 - frac * 2.0 + 0.9;
        speech_balloon.image_data.alpha = alpha;
        speech_balloon.text.alpha = alpha;
        if (map.findEntity(speech_balloon.target_id)) |en| {
            switch (en.*) {
                inline else => |obj| {
                    speech_balloon._screen_x = obj.screen_x - speech_balloon.width() / 2;
                    speech_balloon._screen_y = obj.screen_y + speech_balloon.height() / 2 - 25;
                },
            }
        }
    }

    std.mem.reverse(usize, speech_balloons_to_remove.items());

    for (speech_balloons_to_remove.items()) |idx| {
        allocator.free(speech_balloons.remove(idx).text.text);
    }

    speech_balloons_to_remove.clear();

    obj_ids_to_remove.clear();
}
