const std = @import("std");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const map = @import("map.zig");
const utils = @import("utils.zig");
const input = @import("input.zig");
const main = @import("main.zig");
const game_data = @import("game_data.zig");

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

pub const InteractableState = enum(u8) {
    none = 0,
    pressed = 1,
    hovered = 2,
};

pub const InputField = struct {
    x: f32,
    y: f32,
    text_inlay_x: f32,
    text_inlay_y: f32,
    base_decor_data: ImageData,
    text: Text,
    allocator: std.mem.Allocator,
    enter_callback: *const fn ([]u8) void,
    state: InteractableState = .none,
    hover_decor_data: ?ImageData = null,
    press_decor_data: ?ImageData = null,
    visible: bool = true,

    pub inline fn imageData(self: InputField) ImageData {
        switch (self.state) {
            .none => return self.base_decor_data,
            .pressed => return self.press_decor_data orelse self.base_decor_data,
            .hovered => return self.hover_decor_data orelse self.base_decor_data,
        }
    }

    pub inline fn width(self: InputField) f32 {
        return @max(self.text.width(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub inline fn height(self: InputField) f32 {
        return @max(self.text.height(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }
};

pub const Button = struct {
    x: f32,
    y: f32,
    base_image_data: ImageData,
    press_callback: *const fn () void,
    state: InteractableState = .none,
    hover_image_data: ?ImageData = null,
    press_image_data: ?ImageData = null,
    text: ?Text = null,
    visible: bool = true,

    pub inline fn imageData(self: Button) ImageData {
        switch (self.state) {
            .none => return self.base_image_data,
            .pressed => return self.press_image_data orelse self.base_image_data,
            .hovered => return self.hover_image_data orelse self.base_image_data,
        }
    }

    pub inline fn width(self: Button) f32 {
        if (self.text) |text| {
            return @max(text.width(), switch (self.imageData()) {
                .nine_slice => |nine_slice| return nine_slice.w,
                .normal => |image_data| return image_data.width(),
            });
        } else {
            return switch (self.imageData()) {
                .nine_slice => |nine_slice| return nine_slice.w,
                .normal => |image_data| return image_data.width(),
            };
        }
    }

    pub inline fn height(self: Button) f32 {
        if (self.text) |text| {
            return @max(text.height(), switch (self.imageData()) {
                .nine_slice => |nine_slice| return nine_slice.h,
                .normal => |image_data| return image_data.height(),
            });
        } else {
            return switch (self.imageData()) {
                .nine_slice => |nine_slice| return nine_slice.h,
                .normal => |image_data| return image_data.height(),
            };
        }
    }
};

pub const NineSliceImageData = struct {
    const top_left_idx = 0;
    const top_center_idx = 1;
    const top_right_idx = 2;
    const middle_left_idx = 3;
    const middle_center_idx = 4;
    const middle_right_idx = 5;
    const bottom_left_idx = 6;
    const bottom_center_idx = 7;
    const bottom_right_idx = 8;

    w: f32,
    h: f32,
    alpha: f32 = 1.0,
    atlas_data: [9]assets.AtlasData,

    pub inline fn fromAtlasData(data: assets.AtlasData, w: f32, h: f32, slice_x: f32, slice_y: f32, slice_w: f32, slice_h: f32, alpha: f32) NineSliceImageData {
        const base_u = data.texURaw() + assets.padding;
        const base_v = data.texVRaw() + assets.padding;
        const base_w = data.texWRaw() - assets.padding * 2;
        const base_h = data.texHRaw() - assets.padding * 2;
        return NineSliceImageData{
            .w = w,
            .h = h,
            .alpha = alpha,
            .atlas_data = [9]assets.AtlasData{
                assets.AtlasData.fromRawF32(base_u, base_v, slice_x, slice_y),
                assets.AtlasData.fromRawF32(base_u + slice_x, base_v, slice_w, slice_y),
                assets.AtlasData.fromRawF32(base_u + slice_x + slice_w, base_v, base_w - slice_w - slice_x, slice_y),
                assets.AtlasData.fromRawF32(base_u, base_v + slice_y, slice_x, slice_h),
                assets.AtlasData.fromRawF32(base_u + slice_x, base_v + slice_y, slice_w, slice_h),
                assets.AtlasData.fromRawF32(base_u + slice_x + slice_w, base_v + slice_y, base_w - slice_w - slice_x, slice_h),
                assets.AtlasData.fromRawF32(base_u, base_v + slice_y + slice_h, slice_x, base_h - slice_h - slice_y),
                assets.AtlasData.fromRawF32(base_u + slice_x, base_v + slice_y + slice_h, slice_w, base_h - slice_h - slice_y),
                assets.AtlasData.fromRawF32(base_u + slice_x + slice_w, base_v + slice_y + slice_h, base_w - slice_w - slice_x, base_h - slice_h - slice_y),
            },
        };
    }

    pub inline fn topLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_left_idx];
    }

    pub inline fn topCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_center_idx];
    }

    pub inline fn topRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_right_idx];
    }

    pub inline fn middleLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_left_idx];
    }

    pub inline fn middleCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_center_idx];
    }

    pub inline fn middleRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_right_idx];
    }

    pub inline fn bottomLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_left_idx];
    }

    pub inline fn bottomCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_center_idx];
    }

    pub inline fn bottomRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_right_idx];
    }
};

pub const NormalImageData = struct {
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    alpha: f32 = 1.0,
    atlas_data: assets.AtlasData,

    pub inline fn width(self: NormalImageData) f32 {
        return self.atlas_data.texWRaw() * self.scale_x;
    }

    pub inline fn height(self: NormalImageData) f32 {
        return self.atlas_data.texHRaw() * self.scale_y;
    }
};

pub const ImageData = union(enum) {
    nine_slice: NineSliceImageData,
    normal: NormalImageData,
};

pub const Image = struct {
    x: f32,
    y: f32,
    image_data: ImageData,
    max_width: f32 = std.math.maxInt(u32),
    visible: bool = true,
    draggable: bool = false,
    drag_end_callback: ?*const fn (*Image) void = null,
    _is_dragging: bool = false,
    _drag_start_x: f32 = 0,
    _drag_start_y: f32 = 0,
    _drag_offset_x: f32 = 0,
    _drag_offset_y: f32 = 0,

    pub inline fn width(self: Image) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub inline fn height(self: Image) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }
};

pub const Bar = struct {
    x: f32,
    y: f32,
    image_data: ImageData,
    max_width: f32 = std.math.maxInt(u32),
    visible: bool = true,
    text: Text,

    pub inline fn width(self: Bar) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub inline fn height(self: Bar) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }
};

pub const SpeechBalloon = struct {
    image_data: ImageData,
    text: Text,
    target_id: i32,
    start_time: i32,
    visible: bool = true,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: SpeechBalloon) f32 {
        return @max(self.text.width(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub inline fn height(self: SpeechBalloon) f32 {
        return @max(self.text.height(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }
};

pub const UiText = struct {
    x: f32,
    y: f32,
    text: Text,
    visible: bool = true,
};

pub const StatusText = struct {
    text: Text,
    initial_size: f32,
    lifetime: i32 = 500,
    start_time: i32 = 0,
    obj_id: i32 = -1,
    visible: bool = true,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: StatusText) f32 {
        return self.text.width();
    }

    pub inline fn height(self: StatusText) f32 {
        return self.text.height();
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

pub var bars: utils.DynSlice(*Bar) = undefined;
pub var input_fields: utils.DynSlice(*InputField) = undefined;
pub var buttons: utils.DynSlice(*Button) = undefined;
pub var ui_images: utils.DynSlice(*Image) = undefined;
pub var ui_texts: utils.DynSlice(*UiText) = undefined;
pub var speech_balloons: utils.DynSlice(SpeechBalloon) = undefined;
pub var speech_balloons_to_remove: utils.DynSlice(usize) = undefined;
pub var status_texts: utils.DynSlice(StatusText) = undefined;
pub var status_texts_to_remove: utils.DynSlice(usize) = undefined;
pub var obj_ids_to_remove: utils.DynSlice(i32) = undefined;

pub var fps_text: *UiText = undefined;
var chat_input: *InputField = undefined;
var chat_decor: *Image = undefined;
var bars_decor: *Image = undefined;
var stats_button: *Button = undefined;
var level_text: *UiText = undefined;
var xp_bar: *Bar = undefined;
var fame_bar: *Bar = undefined;
var health_bar: *Bar = undefined;
var mana_bar: *Bar = undefined;
var inventory_decor: *Image = undefined;
var inventory_items: [20]Image = undefined;
var container_decor: *Image = undefined;
var container_name: *UiText = undefined;
var container_items: [8]Image = undefined;
var minimap_decor: *Image = undefined;

var inventory_pos_data: [20]utils.Rect = undefined;
var container_pos_data: [8]utils.Rect = undefined;

var last_level: i32 = -1;
var last_xp: i32 = -1;
var last_xp_goal: i32 = -1;
var last_fame: i32 = -1;
var last_fame_goal: i32 = -1;
var last_hp: i32 = -1;
var last_max_hp: i32 = -1;
var last_mp: i32 = -1;
var last_max_mp: i32 = -1;

var _allocator: std.mem.Allocator = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    _allocator = allocator;

    parseItemRects();

    bars = try utils.DynSlice(*Bar).init(10, allocator);
    input_fields = try utils.DynSlice(*InputField).init(10, allocator);
    buttons = try utils.DynSlice(*Button).init(10, allocator);
    ui_images = try utils.DynSlice(*Image).init(10, allocator);
    ui_texts = try utils.DynSlice(*UiText).init(10, allocator);
    speech_balloons = try utils.DynSlice(SpeechBalloon).init(10, allocator);
    speech_balloons_to_remove = try utils.DynSlice(usize).init(10, allocator);
    status_texts = try utils.DynSlice(StatusText).init(30, allocator);
    status_texts_to_remove = try utils.DynSlice(usize).init(30, allocator);
    obj_ids_to_remove = try utils.DynSlice(i32).init(40, allocator);

    minimap_decor = try allocator.create(Image);
    const minimap_data = (assets.ui_atlas_data.get("minimap") orelse @panic("Could not find minimap in ui atlas"))[0];
    minimap_decor.* = Image{
        .x = camera.screen_width - minimap_data.texWRaw() - 10,
        .y = 10,
        .image_data = .{ .normal = .{ .atlas_data = minimap_data } },
    };
    try ui_images.add(minimap_decor);

    inventory_decor = try allocator.create(Image);
    const inventory_data = (assets.ui_atlas_data.get("playerInventory") orelse @panic("Could not find playerInventory in ui atlas"))[0];
    inventory_decor.* = Image{
        .x = camera.screen_width - inventory_data.texWRaw() - 10,
        .y = camera.screen_height - inventory_data.texHRaw() - 10,
        .image_data = .{ .normal = .{ .atlas_data = inventory_data } },
    };
    try ui_images.add(inventory_decor);

    for (0..20) |i| {
        inventory_items[i] = Image{
            .x = inventory_decor.x + inventory_pos_data[i].x + (inventory_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
            .y = inventory_decor.y + inventory_pos_data[i].y + (inventory_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
            .image_data = .{ .normal = .{
                .scale_x = 4.0,
                .scale_y = 4.0,
                .atlas_data = assets.ui_error_data,
            } },
            .visible = true,
            .draggable = true,
            .drag_end_callback = itemDragEndCallback,
        };
        try ui_images.add(&inventory_items[i]);
    }

    container_decor = try allocator.create(Image);
    const container_data = (assets.ui_atlas_data.get("containerView") orelse @panic("Could not find containerView in ui atlas"))[0];
    container_decor.* = Image{
        .x = inventory_decor.x - container_data.texWRaw() - 10,
        .y = camera.screen_height - container_data.texHRaw() - 10,
        .image_data = .{ .normal = .{ .atlas_data = container_data } },
        .visible = false,
    };
    try ui_images.add(container_decor);

    bars_decor = try allocator.create(Image);
    const bars_data = (assets.ui_atlas_data.get("playerStatusBarsDecor") orelse @panic("Could not find playerStatusBarsDecor in ui atlas"))[0];
    bars_decor.* = Image{
        .x = (camera.screen_width - bars_data.texWRaw()) / 2,
        .y = camera.screen_height - bars_data.texHRaw() - 10,
        .image_data = .{ .normal = .{ .atlas_data = bars_data } },
    };
    try ui_images.add(bars_decor);

    stats_button = try allocator.create(Button);
    const stats_data = (assets.ui_atlas_data.get("playerStatusBarStatIcon") orelse @panic("Could not find playerStatusBarStatIcon in ui atlas"))[0];
    stats_button.* = Button{
        .x = bars_decor.x + 7,
        .y = bars_decor.y + 8,
        .base_image_data = .{ .normal = .{ .atlas_data = stats_data } },
        .press_callback = statsCallback,
    };
    try buttons.add(stats_button);

    level_text = try allocator.create(UiText);
    const level = Text{
        .text = "",
        .size = 12,
        .text_type = .bold,
    };
    level_text.* = UiText{
        .x = bars_decor.x + 181,
        .y = bars_decor.y + 13,
        .text = level,
    };
    try ui_texts.add(level_text);

    xp_bar = try allocator.create(Bar);
    const xp_bar_data = (assets.ui_atlas_data.get("playerStatusBarXp") orelse @panic("Could not find playerStatusBarXp in ui atlas"))[0];
    xp_bar.* = Bar{
        .x = bars_decor.x + 42,
        .y = bars_decor.y + 12,
        .image_data = .{ .normal = .{ .atlas_data = xp_bar_data } },
        .text = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
        },
    };
    try bars.add(xp_bar);

    fame_bar = try allocator.create(Bar);
    const fame_bar_data = (assets.ui_atlas_data.get("playerStatusBarFame") orelse @panic("Could not find playerStatusBarFame in ui atlas"))[0];
    fame_bar.* = Bar{
        .x = bars_decor.x + 42,
        .y = bars_decor.y + 12,
        .image_data = .{ .normal = .{ .atlas_data = fame_bar_data } },
        .text = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
        },
    };
    try bars.add(fame_bar);

    health_bar = try allocator.create(Bar);
    const health_bar_data = (assets.ui_atlas_data.get("playerStatusBarHealth") orelse @panic("Could not find playerStatusBarHealth in ui atlas"))[0];
    health_bar.* = Bar{
        .x = bars_decor.x + 8,
        .y = bars_decor.y + 47,
        .image_data = .{ .normal = .{ .atlas_data = health_bar_data } },
        .text = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
        },
    };
    try bars.add(health_bar);

    mana_bar = try allocator.create(Bar);
    const mana_bar_data = (assets.ui_atlas_data.get("playerStatusBarMana") orelse @panic("Could not find playerStatusBarMana in ui atlas"))[0];
    mana_bar.* = Bar{
        .x = bars_decor.x + 8,
        .y = bars_decor.y + 73,
        .image_data = .{ .normal = .{ .atlas_data = mana_bar_data } },
        .text = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
        },
    };
    try bars.add(mana_bar);

    chat_decor = try allocator.create(Image);
    const chat_data = (assets.ui_atlas_data.get("chatboxBackground") orelse @panic("Could not find chatboxBackground in ui atlas"))[0];
    const input_data = (assets.ui_atlas_data.get("chatboxInput") orelse @panic("Could not find chatboxInput in ui atlas"))[0];
    chat_decor.* = Image{
        .x = 10,
        .y = camera.screen_height - chat_data.texHRaw() - input_data.texHRaw() - 10,
        .image_data = .{ .normal = .{ .atlas_data = chat_data } },
    };
    try ui_images.add(chat_decor);

    chat_input = try allocator.create(InputField);
    chat_input.* = InputField{
        .x = chat_decor.x,
        .y = chat_decor.y + chat_decor.height(),
        .text_inlay_x = 9,
        .text_inlay_y = 8,
        .base_decor_data = .{ .normal = .{ .atlas_data = input_data } },
        .text = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
        },
        .allocator = allocator,
        .enter_callback = chatCallback,
    };
    try input_fields.add(chat_input);

    fps_text = try allocator.create(UiText);
    const text = Text{
        .text = "",
        .size = 12,
        .text_type = .bold,
    };
    fps_text.* = UiText{
        .x = camera.screen_width - text.width() - 10,
        .y = minimap_decor.y + minimap_decor.height() + 10,
        .text = text,
    };
    try ui_texts.add(fps_text);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    allocator.destroy(minimap_decor);
    allocator.destroy(inventory_decor);
    allocator.destroy(container_decor);
    allocator.destroy(bars_decor);
    allocator.destroy(stats_button);
    if (level_text.text.text.len > 0)
        allocator.free(level_text.text.text);
    allocator.destroy(level_text);
    if (xp_bar.text.text.len > 0)
        allocator.free(xp_bar.text.text);
    allocator.destroy(xp_bar);
    if (fame_bar.text.text.len > 0)
        allocator.free(fame_bar.text.text);
    allocator.destroy(fame_bar);
    if (health_bar.text.text.len > 0)
        allocator.free(health_bar.text.text);
    allocator.destroy(health_bar);
    if (mana_bar.text.text.len > 0)
        allocator.free(mana_bar.text.text);
    allocator.destroy(mana_bar);
    allocator.destroy(chat_decor);
    allocator.destroy(chat_input);
    if (fps_text.text.text.len > 0)
        allocator.free(fps_text.text.text);
    allocator.destroy(fps_text);

    bars.deinit();
    input_fields.deinit();
    buttons.deinit();
    ui_images.deinit();
    ui_texts.deinit();
    speech_balloons.deinit();
    speech_balloons_to_remove.deinit();
    for (status_texts.items()) |status_text| {
        allocator.free(status_text.text.text);
    }
    status_texts.deinit();
    status_texts_to_remove.deinit();
    obj_ids_to_remove.deinit();
}

pub fn resize(w: f32, h: f32) void {
    minimap_decor.x = w - minimap_decor.width() - 10;
    inventory_decor.x = w - inventory_decor.width() - 10;
    inventory_decor.y = h - inventory_decor.height() - 10;
    container_decor.x = inventory_decor.x - container_decor.width() - 10;
    container_decor.y = h - container_decor.height() - 10;
    bars_decor.x = (w - bars_decor.width()) / 2;
    bars_decor.y = h - bars_decor.height() - 10;
    stats_button.x = bars_decor.x + 7;
    stats_button.y = bars_decor.y + 8;
    level_text.x = bars_decor.x + 181;
    level_text.y = bars_decor.y + 13;
    xp_bar.x = bars_decor.x + 42;
    xp_bar.y = bars_decor.y + 12;
    fame_bar.x = bars_decor.x + 42;
    fame_bar.y = bars_decor.y + 12;
    health_bar.x = bars_decor.x + 8;
    health_bar.y = bars_decor.y + 47;
    mana_bar.x = bars_decor.x + 8;
    mana_bar.y = bars_decor.y + 73;
    const chat_decor_h = chat_decor.height();
    chat_decor.y = h - chat_decor_h - chat_input.imageData().normal.height() - 10;
    chat_input.y = chat_decor.y + chat_decor_h;
    fps_text.y = minimap_decor.y + minimap_decor.height() + 10;
}

fn parseItemRects() void {
    for (0..20) |i| {
        const hori_idx: f32 = @floatFromInt(@mod(i, 4));
        const vert_idx: f32 = @floatFromInt(@divFloor(i, 4));
        if (i < 4) {
            inventory_pos_data[i] = utils.Rect{
                .x = 5 + hori_idx * 44,
                .y = 8,
                .w = 40,
                .h = 40,
            };
        } else {
            inventory_pos_data[i] = utils.Rect{
                .x = 5 + hori_idx * 44,
                .y = 63 + (vert_idx - 1) * 44,
                .w = 40,
                .h = 40,
            };
        }
    }

    for (0..8) |i| {
        _ = i;
        //container_pos_data[i] = utils.Rect{};
    }
}

fn findSlotId(x: f32, y: f32) u8 {
    for (0..20) |i| {
        if (utils.isInBounds(
            x,
            y,
            inventory_decor.x + inventory_pos_data[i].x,
            inventory_decor.y + inventory_pos_data[i].y,
            inventory_pos_data[i].w,
            inventory_pos_data[i].h,
        )) {
            return @intCast(i);
        }
    }

    return 255;
}

fn itemDragEndCallback(img: *Image) void {
    if (main.server) |*srv| {
        if (map.findEntity(map.local_player_id)) |en| {
            switch (en.*) {
                .player => |local_player| {
                    const start_slot_id = findSlotId(img._drag_start_x + 4, img._drag_start_y + 4); // trollart
                    const end_slot_id = findSlotId(img.x - img._drag_offset_x, img.y - img._drag_offset_y);
                    if (end_slot_id == 255) {
                        setInvItem(-1, start_slot_id);
                        srv.sendInvDrop(.{
                            .object_id = map.local_player_id,
                            .slot_id = start_slot_id,
                            .object_type = local_player.inventory[start_slot_id],
                        });
                    } else {
                        const start_item = local_player.inventory[start_slot_id];
                        if (end_slot_id >= 12 and !local_player.has_backpack) {
                            setInvItem(start_item, start_slot_id);
                            return;
                        }

                        const end_item = local_player.inventory[end_slot_id];
                        setInvItem(end_item, start_slot_id);
                        setInvItem(start_item, end_slot_id);
                        srv.sendInvSwap(
                            main.current_time,
                            .{ .x = local_player.x, .y = local_player.y },
                            .{
                                .object_id = map.local_player_id,
                                .slot_id = start_slot_id,
                                .object_type = start_item,
                            },
                            .{
                                .object_id = map.local_player_id,
                                .slot_id = end_slot_id,
                                .object_type = end_item,
                            },
                        );
                    }
                },
                else => {},
            }
        }
    }
}

fn statsCallback() void {
    std.log.debug("stats pressed", .{});
}

fn chatCallback(input_text: []u8) void {
    if (main.server) |*srv| {
        srv.sendPlayerText(input_text);
    }
}

pub fn setInvItem(item: i32, idx: u8) void {
    if (item == -1) {
        inventory_items[idx].visible = false;
        return;
    }

    inventory_items[idx].visible = true;

    if (game_data.item_type_to_props.get(@intCast(item))) |props| {
        if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
            const atlas_data = data[props.texture_data.index];
            inventory_items[idx].image_data.normal.atlas_data = atlas_data;
            inventory_items[idx].x = inventory_decor.x + inventory_pos_data[idx].x + (inventory_pos_data[idx].w - inventory_items[idx].width() + assets.padding * 2) / 2;
            inventory_items[idx].y = inventory_decor.y + inventory_pos_data[idx].y + (inventory_pos_data[idx].h - inventory_items[idx].height() + assets.padding * 2) / 2;
        } else {
            std.log.err("Could not find ui sheet {s} for item with type {x}, index {d}", .{ props.texture_data.sheet, item, idx });
            const atlas_data = assets.ui_error_data;
            inventory_items[idx].image_data.normal.atlas_data = atlas_data;
            inventory_items[idx].x = inventory_decor.x + inventory_pos_data[idx].x + (inventory_pos_data[idx].w - inventory_items[idx].width() + assets.padding * 2) / 2;
            inventory_items[idx].y = inventory_decor.y + inventory_pos_data[idx].y + (inventory_pos_data[idx].h - inventory_items[idx].height() + assets.padding * 2) / 2;
        }
    } else {
        std.log.err("Attempted to populate inventory index {d} with item {x}, but props was not found", .{ idx, item });
        const atlas_data = assets.ui_error_data;
        inventory_items[idx].image_data.normal.atlas_data = atlas_data;
        inventory_items[idx].x = inventory_decor.x + inventory_pos_data[idx].x + (inventory_pos_data[idx].w - inventory_items[idx].width() + assets.padding * 2) / 2;
        inventory_items[idx].y = inventory_decor.y + inventory_pos_data[idx].y + (inventory_pos_data[idx].h - inventory_items[idx].height() + assets.padding * 2) / 2;
    }
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
    for (ui_images.items()) |image| {
        if (!image.visible or !image._is_dragging)
            continue;

        image.x = x + image._drag_offset_x;
        image.y = y + image._drag_offset_y;
    }

    for (buttons.items()) |button| {
        if (!button.visible)
            continue;

        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.state = .hovered;
        } else {
            button.state = .none;
        }
    }

    for (input_fields.items()) |input_field| {
        if (!input_field.visible)
            continue;

        if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
            input_field.state = .hovered;
        } else {
            input_field.state = .none;
        }
    }
}

pub fn mousePress(x: f32, y: f32) bool {
    for (ui_images.items()) |image| {
        if (!image.visible or !image.draggable)
            continue;

        if (utils.isInBounds(x, y, image.x, image.y, image.width(), image.height())) {
            image._is_dragging = true;
            image._drag_start_x = image.x;
            image._drag_start_y = image.y;
            image._drag_offset_x = image.x - x;
            image._drag_offset_y = image.y - y;
            return true;
        }
    }

    for (buttons.items()) |button| {
        if (!button.visible)
            continue;

        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.press_callback();
            button.state = .pressed;
            return true;
        }
    }

    input.selected_input_field = null;
    for (input_fields.items()) |input_field| {
        if (!input_field.visible)
            continue;

        if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
            input.selected_input_field = input_field;
            input_field.state = .pressed;
            return true;
        }
    }

    return false;
}

pub fn mouseRelease(x: f32, y: f32) void {
    for (ui_images.items()) |image| {
        if (!image._is_dragging)
            continue;

        image._is_dragging = false;
        if (image.drag_end_callback) |cb| {
            cb(image);
        }
    }

    for (buttons.items()) |button| {
        if (!button.visible)
            continue;

        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.state = .none;
        }
    }

    for (input_fields.items()) |input_field| {
        if (!input_field.visible)
            continue;

        if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
            input_field.state = .none;
        }
    }
}

pub fn update(time: i32, dt: i32, allocator: std.mem.Allocator) !void {
    _ = dt;

    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    if (map.findEntity(map.local_player_id)) |en| {
        switch (en.*) {
            .player => |local_player| {
                if (last_level != local_player.level) {
                    if (level_text.text.text.len > 0)
                        _allocator.free(level_text.text.text);
                    level_text.text.text = try std.fmt.allocPrint(_allocator, "{d}", .{local_player.level});

                    last_level = local_player.level;
                }

                const max_level = local_player.level >= 20;
                if (max_level) {
                    if (last_fame != local_player.fame or last_fame_goal != local_player.fame_goal) {
                        fame_bar.visible = true;
                        xp_bar.visible = false;
                        const fame_perc = @as(f32, @floatFromInt(local_player.fame)) / @as(f32, @floatFromInt(local_player.fame_goal));
                        fame_bar.max_width = fame_bar.width() * fame_perc;
                        if (fame_bar.text.text.len > 0)
                            _allocator.free(fame_bar.text.text);
                        fame_bar.text.text = try std.fmt.allocPrint(_allocator, "{d}/{d} Fame", .{ local_player.fame, local_player.fame_goal });

                        last_fame = local_player.fame;
                        last_fame_goal = local_player.fame_goal;
                    }
                } else {
                    if (last_xp != local_player.exp or last_xp_goal != local_player.exp_goal) {
                        xp_bar.visible = true;
                        fame_bar.visible = false;
                        const exp_perc = @as(f32, @floatFromInt(local_player.exp)) / @as(f32, @floatFromInt(local_player.exp_goal));
                        xp_bar.max_width = xp_bar.width() * exp_perc;
                        if (xp_bar.text.text.len > 0)
                            _allocator.free(xp_bar.text.text);
                        xp_bar.text.text = try std.fmt.allocPrint(_allocator, "{d}/{d} XP", .{ local_player.exp, local_player.exp_goal });

                        last_xp = local_player.exp;
                        last_xp_goal = local_player.exp_goal;
                    }
                }

                if (last_hp != local_player.hp or last_max_hp != local_player.max_hp) {
                    const hp_perc = @as(f32, @floatFromInt(local_player.hp)) / @as(f32, @floatFromInt(local_player.max_hp));
                    health_bar.max_width = health_bar.width() * hp_perc;
                    if (health_bar.text.text.len > 0)
                        _allocator.free(health_bar.text.text);
                    health_bar.text.text = try std.fmt.allocPrint(_allocator, "{d}/{d} HP", .{ local_player.hp, local_player.max_hp });

                    last_hp = local_player.hp;
                    last_max_hp = local_player.max_hp;
                }

                if (last_mp != local_player.mp or last_max_mp != local_player.max_mp) {
                    const mp_perc = @as(f32, @floatFromInt(local_player.mp)) / @as(f32, @floatFromInt(local_player.max_mp));
                    mana_bar.max_width = mana_bar.width() * mp_perc;
                    if (mana_bar.text.text.len > 0)
                        _allocator.free(mana_bar.text.text);
                    mana_bar.text.text = try std.fmt.allocPrint(_allocator, "{d}/{d} MP", .{ local_player.mp, local_player.max_mp });

                    last_mp = local_player.mp;
                    last_max_mp = local_player.max_mp;
                }
            },
            else => {},
        }
    }

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
        speech_balloon.image_data.normal.alpha = alpha; // assume no 9 slice
        speech_balloon.text.alpha = alpha;
        if (map.findEntity(speech_balloon.target_id)) |en| {
            switch (en.*) {
                inline else => |obj| {
                    speech_balloon._screen_x = obj.screen_x - speech_balloon.width() / 2;
                    speech_balloon._screen_y = obj.screen_y - speech_balloon.height();
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
