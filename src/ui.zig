const std = @import("std");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const map = @import("map.zig");
const utils = @import("utils.zig");
const input = @import("input.zig");
const main = @import("main.zig");
const game_data = @import("game_data.zig");
const network = @import("network.zig");
const zglfw = @import("zglfw");

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
    text_data: TextData,
    allocator: std.mem.Allocator,
    enter_callback: ?*const fn ([]u8) void = null,
    state: InteractableState = .none,
    hover_decor_data: ?ImageData = null,
    press_decor_data: ?ImageData = null,
    visible: bool = true,
    _index: u32 = 0,

    pub inline fn imageData(self: InputField) ImageData {
        switch (self.state) {
            .none => return self.base_decor_data,
            .pressed => return self.press_decor_data orelse self.base_decor_data,
            .hovered => return self.hover_decor_data orelse self.base_decor_data,
        }
    }

    pub inline fn width(self: InputField) f32 {
        return @max(self.text_data.width(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub inline fn height(self: InputField) f32 {
        return @max(self.text_data.height(), switch (self.imageData()) {
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
    text_data: ?TextData = null,
    visible: bool = true,

    pub inline fn imageData(self: Button) ImageData {
        switch (self.state) {
            .none => return self.base_image_data,
            .pressed => return self.press_image_data orelse self.base_image_data,
            .hovered => return self.hover_image_data orelse self.base_image_data,
        }
    }

    pub inline fn width(self: Button) f32 {
        if (self.text_data) |text| {
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
        if (self.text_data) |text| {
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

pub const CharacterBox = struct {
    x: f32,
    y: f32,
    id: u32,
    base_image_data: ImageData,
    press_callback: *const fn (*CharacterBox) void,
    state: InteractableState = .none,
    hover_image_data: ?ImageData = null,
    press_image_data: ?ImageData = null,
    text_data: ?TextData = null,
    visible: bool = true,

    pub inline fn imageData(self: CharacterBox) ImageData {
        switch (self.state) {
            .none => return self.base_image_data,
            .pressed => return self.press_image_data orelse self.base_image_data,
            .hovered => return self.hover_image_data orelse self.base_image_data,
        }
    }

    pub inline fn width(self: CharacterBox) f32 {
        if (self.text_data) |text| {
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

    pub inline fn height(self: CharacterBox) f32 {
        if (self.text_data) |text| {
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

pub const Item = struct {
    x: f32,
    y: f32,
    image_data: ImageData,
    drag_end_callback: *const fn (*Item) void,
    double_click_callback: *const fn (*Item) void,
    shift_click_callback: *const fn (*Item) void,
    tier_text: ?UiText = null, // ui text because the text is offset
    visible: bool = true,
    draggable: bool = false,
    _is_dragging: bool = false,
    _drag_start_x: f32 = 0,
    _drag_start_y: f32 = 0,
    _drag_offset_x: f32 = 0,
    _drag_offset_y: f32 = 0,
    _last_click_time: i64 = 0,
    _item: i32 = -1,

    pub inline fn width(self: Item) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub inline fn height(self: Item) f32 {
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
    text_data: TextData,

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
    text_data: TextData,
    target_id: i32,
    start_time: i64,
    visible: bool = true,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: SpeechBalloon) f32 {
        return @max(self.text_data.width(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub inline fn height(self: SpeechBalloon) f32 {
        return @max(self.text_data.height(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }
};

pub const UiText = struct {
    x: f32,
    y: f32,
    text_data: TextData,
    visible: bool = true,
};

pub const StatusText = struct {
    text_data: TextData,
    initial_size: f32,
    lifetime: i64 = 500,
    start_time: i64 = 0,
    obj_id: i32 = -1,
    visible: bool = true,
    // the texts' internal x/y, don't touch outside of ui.update()
    _screen_x: f32 = 0.0,
    _screen_y: f32 = 0.0,

    pub inline fn width(self: StatusText) f32 {
        return self.text_data.width();
    }

    pub inline fn height(self: StatusText) f32 {
        return self.text_data.height();
    }
};

pub const TextType = enum(u32) {
    medium = 0,
    medium_italic = 1,
    bold = 2,
    bold_italic = 3,
};

pub const TextData = struct {
    text: []u8,
    size: f32,
    backing_buffer: []u8,
    text_type: TextType = .medium,
    color: i32 = 0xFFFFFF,
    alpha: f32 = 1.0,
    shadow_color: i32 = 0x000000,
    shadow_alpha_mult: f32 = 0.5,
    shadow_texel_offset_mult: f32 = 6.0,
    max_width: f32 = @as(f32, std.math.maxInt(u32)),

    pub fn width(self: TextData) f32 {
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

    pub fn height(self: TextData) f32 {
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

pub const Slot = struct {
    idx: u8,
    is_container: bool = false,

    fn findInvSlotId(x: f32, y: f32) u8 {
        for (0..20) |i| {
            const data = inventory_pos_data[i];
            if (utils.isInBounds(
                x,
                y,
                inventory_decor.x + data.x - data.w_pad,
                inventory_decor.y + data.y - data.h_pad,
                data.w + data.w_pad * 2,
                data.h + data.h_pad * 2,
            )) {
                return @intCast(i);
            }
        }

        return 255;
    }

    fn findContainerSlotId(x: f32, y: f32) u8 {
        if (!container_visible)
            return 255;

        for (0..8) |i| {
            const data = container_pos_data[i];
            if (utils.isInBounds(
                x,
                y,
                container_decor.x + data.x - data.w_pad,
                container_decor.y + data.y - data.h_pad,
                data.w + data.w_pad * 2,
                data.h + data.h_pad * 2,
            )) {
                return @intCast(i);
            }
        }

        return 255;
    }

    pub fn findSlotId(x: f32, y: f32) Slot {
        const inv_slot = findInvSlotId(x, y);
        if (inv_slot != 255) {
            return Slot{ .idx = inv_slot };
        }

        const container_slot = findContainerSlotId(x, y);
        if (container_slot != 255) {
            return Slot{ .idx = container_slot, .is_container = true };
        }

        return Slot{ .idx = 255 };
    }

    pub fn nextEquippableSlot(slot_types: [20]i8, base_slot_type: i8) Slot {
        for (0..20) |idx| {
            if (slot_types[idx] > 0 and game_data.ItemType.slotsMatch(slot_types[idx], base_slot_type))
                return Slot{ .idx = @intCast(idx) };
        }
        return Slot{ .idx = 255 };
    }

    pub fn nextAvailableSlot() Slot {
        for (0..20) |idx| {
            if (inventory_items[idx]._item == -1)
                return Slot{ .idx = @intCast(idx) };
        }
        return Slot{ .idx = 255 };
    }
};

pub const ScreenType = enum(u8) {
    main_menu,
    char_select,
    char_creation,
    map_editor,
    in_game,
};

pub var items: utils.DynSlice(*Item) = undefined;
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
pub var character_boxes: utils.DynSlice(*CharacterBox) = undefined;
pub var current_screen = ScreenType.main_menu;

// shared
var menu_background: *Image = undefined;
// account screen
var email_text: *UiText = undefined;
var email_input: *InputField = undefined;
var password_text: *UiText = undefined;
var password_input: *InputField = undefined;
var username_text: *UiText = undefined;
var username_input: *InputField = undefined;
var password_repeat_text: *UiText = undefined;
var password_repeat_input: *InputField = undefined;
var login_button: *Button = undefined;
var register_button: *Button = undefined;
// in game
pub var fps_text: *UiText = undefined;
pub var chat_input: *InputField = undefined;
var chat_decor: *Image = undefined;
var bars_decor: *Image = undefined;
var stats_button: *Button = undefined;
var level_text: *UiText = undefined;
var xp_bar: *Bar = undefined;
var fame_bar: *Bar = undefined;
var health_bar: *Bar = undefined;
var mana_bar: *Bar = undefined;
var inventory_decor: *Image = undefined;
var inventory_items: [20]Item = undefined;
var health_potion: *Image = undefined;
var health_potion_text: *UiText = undefined;
var magic_potion: *Image = undefined;
var magic_potion_text: *UiText = undefined;
var container_decor: *Image = undefined;
var container_name: *UiText = undefined;
var container_items: [8]Item = undefined;
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
pub var container_visible = false;
pub var container_id: i32 = -1;

var _allocator: std.mem.Allocator = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    _allocator = allocator;

    parseItemRects();

    items = try utils.DynSlice(*Item).init(16, allocator);
    bars = try utils.DynSlice(*Bar).init(8, allocator);
    input_fields = try utils.DynSlice(*InputField).init(8, allocator);
    buttons = try utils.DynSlice(*Button).init(8, allocator);
    ui_images = try utils.DynSlice(*Image).init(8, allocator);
    ui_texts = try utils.DynSlice(*UiText).init(8, allocator);
    speech_balloons = try utils.DynSlice(SpeechBalloon).init(16, allocator);
    speech_balloons_to_remove = try utils.DynSlice(usize).init(16, allocator);
    status_texts = try utils.DynSlice(StatusText).init(32, allocator);
    status_texts_to_remove = try utils.DynSlice(usize).init(32, allocator);
    obj_ids_to_remove = try utils.DynSlice(i32).init(64, allocator);
    character_boxes = try utils.DynSlice(*CharacterBox).init(16, allocator);

    menu_background = try allocator.create(Image);
    var menu_bg_data = (assets.ui_atlas_data.get("menuBackground") orelse @panic("Could not find menuBackground in ui atlas"))[0];
    menu_bg_data.removePadding();
    menu_background.* = Image{
        .x = 0,
        .y = 0,
        .image_data = .{ .normal = .{
            .scale_x = camera.screen_width / menu_bg_data.texWRaw(),
            .scale_y = camera.screen_height / menu_bg_data.texHRaw(),
            .atlas_data = menu_bg_data,
        } },
    };
    try ui_images.add(menu_background);

    email_input = try allocator.create(InputField);
    const input_data_base = (assets.ui_atlas_data.get("textInputBase") orelse @panic("Could not find textInputBase in ui atlas"))[0];
    const input_data_hover = (assets.ui_atlas_data.get("textInputHover") orelse @panic("Could not find textInputHover in ui atlas"))[0];
    const input_data_press = (assets.ui_atlas_data.get("textInputPress") orelse @panic("Could not find textInputPress in ui atlas"))[0];
    email_input.* = InputField{
        .x = (camera.screen_width - input_data_base.texWRaw()) / 2,
        .y = 200,
        .text_inlay_x = 9,
        .text_inlay_y = 8,
        .base_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_base,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .hover_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_hover,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .press_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_press,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 256),
        },
        .allocator = allocator,
    };
    try input_fields.add(email_input);

    email_text = try allocator.create(UiText);
    const email_text_data = TextData{
        .text = @constCast("E-mail"),
        .size = 16,
        .text_type = .bold,
        .backing_buffer = try allocator.alloc(u8, 8),
    };
    email_text.* = UiText{
        .x = (camera.screen_width - email_text_data.width()) / 2,
        .y = 150,
        .text_data = email_text_data,
    };
    try ui_texts.add(email_text);

    password_input = try allocator.create(InputField);
    password_input.* = InputField{
        .x = (camera.screen_width - input_data_base.texWRaw()) / 2,
        .y = 350,
        .text_inlay_x = 9,
        .text_inlay_y = 8,
        .base_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_base,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .hover_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_hover,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .press_decor_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            input_data_press,
            200,
            50,
            8,
            8,
            32,
            32,
            1.0,
        ) },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 256),
        },
        .allocator = allocator,
    };
    try input_fields.add(password_input);

    password_text = try allocator.create(UiText);
    const password_text_data = TextData{
        .text = @constCast("Password"),
        .size = 16,
        .text_type = .bold,
        .backing_buffer = try allocator.alloc(u8, 8),
    };
    password_text.* = UiText{
        .x = (camera.screen_width - password_text_data.width()) / 2,
        .y = 300,
        .text_data = password_text_data,
    };
    try ui_texts.add(password_text);

    login_button = try allocator.create(Button);
    const button_data_base = (assets.ui_atlas_data.get("buttonBase") orelse @panic("Could not find buttonBase in ui atlas"))[0];
    const button_data_hover = (assets.ui_atlas_data.get("buttonHover") orelse @panic("Could not find buttonHover in ui atlas"))[0];
    const button_data_press = (assets.ui_atlas_data.get("buttonPress") orelse @panic("Could not find buttonPress in ui atlas"))[0];
    login_button.* = Button{
        .x = (camera.screen_width - button_data_base.texWRaw()) / 2,
        .y = 400,
        .base_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            button_data_base,
            150,
            75,
            6,
            6,
            7,
            7,
            1.0,
        ) },
        .hover_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            button_data_hover,
            150,
            75,
            6,
            6,
            7,
            7,
            1.0,
        ) },
        .press_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
            button_data_press,
            150,
            75,
            6,
            6,
            7,
            7,
            1.0,
        ) },
        .text_data = TextData{
            .text = @constCast("Login"),
            .size = 16,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        },
        .press_callback = loginCallback,
    };
    try buttons.add(login_button);

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
        inventory_items[i] = Item{
            .x = inventory_decor.x + inventory_pos_data[i].x + (inventory_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
            .y = inventory_decor.y + inventory_pos_data[i].y + (inventory_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
            .image_data = .{ .normal = .{
                .scale_x = 4.0,
                .scale_y = 4.0,
                .atlas_data = assets.ui_error_data,
            } },
            .tier_text = .{
                .text_data = .{
                    .text = "",
                    .size = 10,
                    .text_type = .bold,
                    .backing_buffer = try allocator.alloc(u8, 8),
                },
                .visible = false,
                .x = 0,
                .y = 0,
            },
            .visible = false,
            .draggable = true,
            .drag_end_callback = itemDragEndCallback,
            .double_click_callback = itemDoubleClickCallback,
            .shift_click_callback = itemShiftClickCallback,
        };
        try items.add(&inventory_items[i]);
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

    for (0..8) |i| {
        container_items[i] = Item{
            .x = container_decor.x + container_pos_data[i].x + (container_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
            .y = container_decor.y + container_pos_data[i].y + (container_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
            .image_data = .{ .normal = .{
                .scale_x = 4.0,
                .scale_y = 4.0,
                .atlas_data = assets.ui_error_data,
            } },
            .tier_text = .{
                .text_data = .{
                    .text = "",
                    .size = 10,
                    .text_type = .bold,
                    .backing_buffer = try allocator.alloc(u8, 8),
                },
                .visible = false,
                .x = 0,
                .y = 0,
            },
            .visible = false,
            .draggable = true,
            .drag_end_callback = itemDragEndCallback,
            .double_click_callback = itemDoubleClickCallback,
            .shift_click_callback = itemShiftClickCallback,
        };
        try items.add(&container_items[i]);
    }

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
    const level_text_data = TextData{
        .text = "",
        .size = 12,
        .text_type = .bold,
        .backing_buffer = try allocator.alloc(u8, 8),
    };
    level_text.* = UiText{
        .x = bars_decor.x + 181,
        .y = bars_decor.y + 13,
        .text_data = level_text_data,
    };
    try ui_texts.add(level_text);

    xp_bar = try allocator.create(Bar);
    const xp_bar_data = (assets.ui_atlas_data.get("playerStatusBarXp") orelse @panic("Could not find playerStatusBarXp in ui atlas"))[0];
    xp_bar.* = Bar{
        .x = bars_decor.x + 42,
        .y = bars_decor.y + 12,
        .image_data = .{ .normal = .{ .atlas_data = xp_bar_data } },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold_italic,
            .backing_buffer = try allocator.alloc(u8, 64),
        },
    };
    try bars.add(xp_bar);

    fame_bar = try allocator.create(Bar);
    const fame_bar_data = (assets.ui_atlas_data.get("playerStatusBarFame") orelse @panic("Could not find playerStatusBarFame in ui atlas"))[0];
    fame_bar.* = Bar{
        .x = bars_decor.x + 42,
        .y = bars_decor.y + 12,
        .image_data = .{ .normal = .{ .atlas_data = fame_bar_data } },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold_italic,
            .backing_buffer = try allocator.alloc(u8, 64),
        },
    };
    try bars.add(fame_bar);

    health_bar = try allocator.create(Bar);
    const health_bar_data = (assets.ui_atlas_data.get("playerStatusBarHealth") orelse @panic("Could not find playerStatusBarHealth in ui atlas"))[0];
    health_bar.* = Bar{
        .x = bars_decor.x + 8,
        .y = bars_decor.y + 47,
        .image_data = .{ .normal = .{ .atlas_data = health_bar_data } },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold_italic,
            .backing_buffer = try allocator.alloc(u8, 32),
        },
    };
    try bars.add(health_bar);

    mana_bar = try allocator.create(Bar);
    const mana_bar_data = (assets.ui_atlas_data.get("playerStatusBarMana") orelse @panic("Could not find playerStatusBarMana in ui atlas"))[0];
    mana_bar.* = Bar{
        .x = bars_decor.x + 8,
        .y = bars_decor.y + 73,
        .image_data = .{ .normal = .{ .atlas_data = mana_bar_data } },
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold_italic,
            .backing_buffer = try allocator.alloc(u8, 32),
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
        .text_data = .{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 256),
        },
        .allocator = allocator,
        .enter_callback = chatCallback,
    };
    try input_fields.add(chat_input);

    fps_text = try allocator.create(UiText);
    const fps_text_data = TextData{
        .text = "",
        .size = 12,
        .text_type = .bold,
        .backing_buffer = try allocator.alloc(u8, 32),
    };
    fps_text.* = UiText{
        .x = camera.screen_width - fps_text_data.width() - 10,
        .y = minimap_decor.y + minimap_decor.height() + 10,
        .text_data = fps_text_data,
    };
    try ui_texts.add(fps_text);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    for (bars.items()) |bar| {
        allocator.free(bar.text_data.backing_buffer);
    }
    bars.deinit();
    for (input_fields.items()) |input_field| {
        allocator.free(input_field.text_data.backing_buffer);
    }
    input_fields.deinit();
    for (buttons.items()) |button| {
        if (button.text_data) |text_data| {
            allocator.free(text_data.backing_buffer);
        }
    }
    buttons.deinit();
    ui_images.deinit();
    for (ui_texts.items()) |ui_text| {
        allocator.free(ui_text.text_data.backing_buffer);
    }
    ui_texts.deinit();
    for (speech_balloons.items()) |speech_balloon| {
        allocator.free(speech_balloon.text_data.backing_buffer);
    }
    speech_balloons.deinit();
    speech_balloons_to_remove.deinit();
    for (status_texts.items()) |status_text| {
        allocator.free(status_text.text_data.backing_buffer);
    }
    status_texts.deinit();
    status_texts_to_remove.deinit();
    obj_ids_to_remove.deinit();

    allocator.destroy(minimap_decor);
    allocator.destroy(inventory_decor);
    allocator.destroy(container_decor);
    allocator.destroy(bars_decor);
    allocator.destroy(stats_button);
    allocator.destroy(level_text);
    allocator.destroy(xp_bar);
    allocator.destroy(fame_bar);
    allocator.destroy(health_bar);
    allocator.destroy(mana_bar);
    allocator.destroy(chat_decor);
    allocator.destroy(chat_input);
    allocator.destroy(fps_text);
}

pub fn resize(w: f32, h: f32) void {
    menu_background.image_data.normal.scale_x = camera.screen_width / menu_background.image_data.normal.atlas_data.texWRaw();
    menu_background.image_data.normal.scale_y = camera.screen_height / menu_background.image_data.normal.atlas_data.texHRaw();

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

    for (0..20) |idx| {
        inventory_items[idx].x = inventory_decor.x + inventory_pos_data[idx].x + (inventory_pos_data[idx].w - inventory_items[idx].width() + assets.padding * 2) / 2;
        inventory_items[idx].y = inventory_decor.y + inventory_pos_data[idx].y + (inventory_pos_data[idx].h - inventory_items[idx].height() + assets.padding * 2) / 2;
    }

    for (0..8) |idx| {
        container_items[idx].x = container_decor.x + container_pos_data[idx].x + (container_pos_data[idx].w - container_items[idx].width() + assets.padding * 2) / 2;
        container_items[idx].y = container_decor.y + container_pos_data[idx].y + (container_pos_data[idx].h - container_items[idx].height() + assets.padding * 2) / 2;
    }
}

pub fn switchScreen(screen_type: ScreenType) void {
    current_screen = screen_type;

    menu_background.visible = false;

    email_text.visible = false;
    email_input.visible = false;
    password_text.visible = false;
    password_input.visible = false;
    // password_repeat_input.visible = false;
    // password_repeat_text.visible = false;
    login_button.visible = false;
    // register_button.visible = false;

    character_boxes.clear();

    last_level = -1;
    last_xp = -1;
    last_xp_goal = -1;
    last_fame = -1;
    last_fame_goal = -1;
    last_hp = -1;
    last_max_hp = -1;
    last_mp = -1;
    last_max_mp = -1;
    container_visible = false;
    container_id = -1;

    fps_text.visible = false;
    chat_input.visible = false;
    chat_decor.visible = false;
    bars_decor.visible = false;
    stats_button.visible = false;
    level_text.visible = false;
    xp_bar.visible = false;
    fame_bar.visible = false;
    health_bar.visible = false;
    mana_bar.visible = false;
    inventory_decor.visible = false;
    for (&inventory_items) |*item| {
        item.visible = false;
    }
    // health_potion.visible = false;
    // health_potion_text.visible = false;
    // magic_potion.visible = false;
    // magic_potion_text.visible = false;
    container_decor.visible = false;
    // container_name.visible = false;
    for (&container_items) |*item| {
        item.visible = false;
    }
    minimap_decor.visible = false;

    switch (screen_type) {
        .main_menu => {
            menu_background.visible = true;
            email_text.visible = true;
            email_input.visible = true;
            password_text.visible = true;
            password_input.visible = true;
            // password_repeat_input.visible = true;
            // password_repeat_text.visible = true;
            login_button.visible = true;
            // register_button.visible = true;
        },
        .char_select => {
            menu_background.visible = true;

            const button_data_base = (assets.ui_atlas_data.get("buttonBase") orelse @panic("Could not find buttonBase in ui atlas"))[0];
            const button_data_hover = (assets.ui_atlas_data.get("buttonHover") orelse @panic("Could not find buttonHover in ui atlas"))[0];
            const button_data_press = (assets.ui_atlas_data.get("buttonPress") orelse @panic("Could not find buttonPress in ui atlas"))[0];

            for (main.character_list, 0..) |char, i| {
                const box = _allocator.create(CharacterBox) catch return;
                box.* = CharacterBox{
                    .x = (camera.screen_width - button_data_base.texWRaw()) / 2,
                    .y = @floatFromInt(50 * i),
                    .id = char.id,
                    .base_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
                        button_data_base,
                        100,
                        40,
                        6,
                        6,
                        7,
                        7,
                        1.0,
                    ) },
                    .hover_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
                        button_data_hover,
                        100,
                        40,
                        6,
                        6,
                        7,
                        7,
                        1.0,
                    ) },
                    .press_image_data = .{ .nine_slice = NineSliceImageData.fromAtlasData(
                        button_data_press,
                        100,
                        40,
                        6,
                        6,
                        7,
                        7,
                        1.0,
                    ) },
                    .text_data = TextData{
                        .text = @constCast(char.name[0..]),
                        .backing_buffer = _allocator.alloc(u8, 1) catch return,
                        .size = 16,
                        .text_type = .bold,
                    },
                    .press_callback = boxClickCallback,
                };
                character_boxes.add(box) catch return;
            }
        },
        .char_creation => {
            menu_background.visible = true;
        },
        .map_editor => {},
        .in_game => {
            fps_text.visible = true;
            chat_input.visible = true;
            chat_decor.visible = true;
            bars_decor.visible = true;
            stats_button.visible = true;
            level_text.visible = true;
            health_bar.visible = true;
            mana_bar.visible = true;
            inventory_decor.visible = true;
            // health_potion.visible = true;
            // health_potion_text.visible = true;
            // magic_potion.visible = true;
            // magic_potion_text.visible = true;
            container_decor.visible = true;
            // container_name.visible = true;
            minimap_decor.visible = true;
        },
    }
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
                .w_pad = 2,
                .h_pad = 13,
            };
        } else {
            inventory_pos_data[i] = utils.Rect{
                .x = 5 + hori_idx * 44,
                .y = 63 + (vert_idx - 1) * 44,
                .w = 40,
                .h = 40,
                .w_pad = 2,
                .h_pad = 2,
            };
        }
    }

    for (0..8) |i| {
        const hori_idx: f32 = @floatFromInt(@mod(i, 4));
        const vert_idx: f32 = @floatFromInt(@divFloor(i, 4));
        container_pos_data[i] = utils.Rect{
            .x = 5 + hori_idx * 44,
            .y = 8 + vert_idx * 44,
            .w = 40,
            .h = 40,
            .w_pad = 2,
            .h_pad = 2,
        };
    }
}

fn swapSlots(start_slot: Slot, end_slot: Slot) void {
    const int_id = map.interactive_id.load(.Acquire);

    if (end_slot.idx == 255) {
        if (start_slot.is_container) {
            setContainerItem(-1, start_slot.idx);
            network.sendInvDrop(.{
                .object_id = int_id,
                .slot_id = start_slot.idx,
                .object_type = container_items[start_slot.idx]._item,
            });
        } else {
            setInvItem(-1, start_slot.idx);
            network.sendInvDrop(.{
                .object_id = map.local_player_id,
                .slot_id = start_slot.idx,
                .object_type = inventory_items[start_slot.idx]._item,
            });
        }
    } else {
        while (!map.object_lock.tryLockShared()) {}
        defer map.object_lock.unlockShared();

        if (map.localPlayerConst()) |local_player| {
            const start_item = if (start_slot.is_container)
                container_items[start_slot.idx]._item
            else
                inventory_items[start_slot.idx]._item;

            if (end_slot.idx >= 12 and !local_player.has_backpack) {
                if (start_slot.is_container) {
                    setContainerItem(start_item, start_slot.idx);
                } else {
                    setInvItem(start_item, start_slot.idx);
                }
                return;
            }

            const end_item = if (end_slot.is_container)
                container_items[end_slot.idx]._item
            else
                inventory_items[end_slot.idx]._item;

            if (start_slot.is_container) {
                setContainerItem(end_item, start_slot.idx);
            } else {
                setInvItem(end_item, start_slot.idx);
            }

            if (end_slot.is_container) {
                setContainerItem(start_item, end_slot.idx);
            } else {
                setInvItem(start_item, end_slot.idx);
            }

            network.sendInvSwap(
                main.current_time,
                .{ .x = local_player.x, .y = local_player.y },
                .{
                    .object_id = if (start_slot.is_container) int_id else map.local_player_id,
                    .slot_id = start_slot.idx,
                    .object_type = start_item,
                },
                .{
                    .object_id = if (end_slot.is_container) int_id else map.local_player_id,
                    .slot_id = end_slot.idx,
                    .object_type = end_item,
                },
            );
        }
    }
}

fn loginCallback() void {
    _ = main.login(_allocator, email_input.text_data.text, password_input.text_data.text) catch |e| {
        std.log.err("Login failed: {any}", .{e});
    };
}

fn boxClickCallback(box: *CharacterBox) void {
    main.selected_char_id = box.id;
    if (main.server_list) |server_list| {
        main.selected_server = server_list[0];
    } else {
        std.log.err("No servers found", .{});
    }
    switchScreen(.in_game);
}

fn itemDragEndCallback(item: *Item) void {
    const start_slot = Slot.findSlotId(item._drag_start_x + 4, item._drag_start_y + 4);
    const end_slot = Slot.findSlotId(item.x - item._drag_offset_x, item.y - item._drag_offset_y);
    if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
        item.x = item._drag_start_x;
        item.y = item._drag_start_y;
        return;
    }

    swapSlots(start_slot, end_slot);
}

fn itemShiftClickCallback(item: *Item) void {
    if (item._item < 0)
        return;

    const slot = Slot.findSlotId(item.x + 4, item.y + 4);

    if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
        if (props.consumable) {
            while (!map.object_lock.tryLockShared()) {}
            defer map.object_lock.unlockShared();

            if (map.localPlayerConst()) |local_player| {
                network.sendUseItem(
                    main.current_time,
                    .{
                        .object_id = if (slot.is_container) container_id else map.local_player_id,
                        .slot_id = slot.idx,
                        .object_type = item._item,
                    },
                    .{
                        .x = local_player.x,
                        .y = local_player.y,
                    },
                    0,
                );
            }

            return;
        }
    }
}

pub fn useItem(idx: u8) void {
    itemDoubleClickCallback(&inventory_items[idx]);
}

fn itemDoubleClickCallback(item: *Item) void {
    if (item._item < 0)
        return;

    const start_slot = Slot.findSlotId(item.x + 4, item.y + 4);
    if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
        if (props.consumable and !start_slot.is_container) {
            while (!map.object_lock.tryLockShared()) {}
            defer map.object_lock.unlockShared();

            if (map.localPlayerConst()) |local_player| {
                network.sendUseItem(
                    main.current_time,
                    .{
                        .object_id = map.local_player_id,
                        .slot_id = start_slot.idx,
                        .object_type = item._item,
                    },
                    .{
                        .x = local_player.x,
                        .y = local_player.y,
                    },
                    0,
                );
            }

            return;
        }
    }

    if (start_slot.is_container) {
        const end_slot = Slot.nextAvailableSlot();
        if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
            item.x = item._drag_start_x;
            item.y = item._drag_start_y;
            return;
        }

        swapSlots(start_slot, end_slot);
    } else {
        if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
            while (!map.object_lock.tryLockShared()) {}
            defer map.object_lock.unlockShared();

            if (map.localPlayerConst()) |local_player| {
                const end_slot = Slot.nextEquippableSlot(local_player.slot_types, props.slot_type);
                if (end_slot.idx == 255 or // we don't want to drop
                    start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container)
                {
                    item.x = item._drag_start_x;
                    item.y = item._drag_start_y;
                    return;
                }

                swapSlots(start_slot, end_slot);
            }
        }
    }
}

fn statsCallback() void {
    std.log.debug("stats pressed", .{});
}

fn chatCallback(input_text: []u8) void {
    network.sendPlayerText(input_text);
}

pub inline fn setContainerVisible(visible: bool) void {
    container_visible = visible;
    container_decor.visible = visible;
}

pub fn setContainerItem(item: i32, idx: u8) void {
    if (item == -1) {
        container_items[idx]._item = -1;
        container_items[idx].visible = false;
        return;
    }

    container_items[idx].visible = true;

    if (game_data.item_type_to_props.get(@intCast(item))) |props| {
        if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
            const atlas_data = data[props.texture_data.index];
            const base_x = container_decor.x + container_pos_data[idx].x;
            const base_y = container_decor.y + container_pos_data[idx].y;
            const pos_w = container_pos_data[idx].w;
            const pos_h = container_pos_data[idx].h;

            container_items[idx]._item = item;
            container_items[idx].image_data.normal.atlas_data = atlas_data;
            container_items[idx].x = base_x + (pos_w - container_items[idx].width() + assets.padding * 2) / 2;
            container_items[idx].y = base_y + (pos_h - container_items[idx].height() + assets.padding * 2) / 2;

            if (container_items[idx].tier_text) |*tier_text| {
                var tier_base: []u8 = &[0]u8{};
                if (std.mem.eql(u8, props.tier, "UT")) {
                    tier_base = @constCast(props.tier);
                    tier_text.text_data.color = 0x8A2BE2;
                } else {
                    tier_base = std.fmt.bufPrint(tier_text.text_data.backing_buffer, "T{s}", .{props.tier}) catch @panic("Out of memory, tier alloc failed");
                    tier_text.text_data.color = 0xFFFFFF;
                }

                tier_text.text_data.text = tier_base;

                // the positioning is relative to parent
                tier_text.x = pos_w - tier_text.text_data.width();
                tier_text.y = pos_h - tier_text.text_data.height() + 4;
                tier_text.visible = true;
            }

            return;
        } else {
            std.log.err("Could not find ui sheet {s} for item with type 0x{x}, index {d}", .{ props.texture_data.sheet, item, idx });
        }
    } else {
        std.log.err("Attempted to populate inventory index {d} with item 0x{x}, but props was not found", .{ idx, item });
    }

    const atlas_data = assets.ui_error_data;
    container_items[idx]._item = -1;
    container_items[idx].image_data.normal.atlas_data = atlas_data;
    container_items[idx].x = container_decor.x + container_pos_data[idx].x + (container_pos_data[idx].w - container_items[idx].width() + assets.padding * 2) / 2;
    container_items[idx].y = container_decor.y + container_pos_data[idx].y + (container_pos_data[idx].h - container_items[idx].height() + assets.padding * 2) / 2;
}

pub fn setInvItem(item: i32, idx: u8) void {
    if (item == -1) {
        inventory_items[idx]._item = -1;
        inventory_items[idx].visible = false;
        return;
    }

    inventory_items[idx].visible = true;

    if (game_data.item_type_to_props.get(@intCast(item))) |props| {
        if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
            const atlas_data = data[props.texture_data.index];
            const base_x = inventory_decor.x + inventory_pos_data[idx].x;
            const base_y = inventory_decor.y + inventory_pos_data[idx].y;
            const pos_w = inventory_pos_data[idx].w;
            const pos_h = inventory_pos_data[idx].h;

            inventory_items[idx]._item = item;
            inventory_items[idx].image_data.normal.atlas_data = atlas_data;
            inventory_items[idx].x = base_x + (pos_w - inventory_items[idx].width() + assets.padding * 2) / 2;
            inventory_items[idx].y = base_y + (pos_h - inventory_items[idx].height() + assets.padding * 2) / 2;

            if (inventory_items[idx].tier_text) |*tier_text| {
                var tier_base: []u8 = &[0]u8{};
                if (std.mem.eql(u8, props.tier, "UT")) {
                    tier_base = @constCast(props.tier);
                    tier_text.text_data.color = 0x8A2BE2;
                } else {
                    tier_base = std.fmt.bufPrint(tier_text.text_data.backing_buffer, "T{s}", .{props.tier}) catch @panic("Out of memory, tier alloc failed");
                    tier_text.text_data.color = 0xFFFFFF;
                }

                tier_text.text_data.text = tier_base;

                // the positioning is relative to parent
                tier_text.x = pos_w - tier_text.text_data.width();
                tier_text.y = pos_h - tier_text.text_data.height() + 4;
                tier_text.visible = true;
            }
            return;
        } else {
            std.log.err("Could not find ui sheet {s} for item with type 0x{x}, index {d}", .{ props.texture_data.sheet, item, idx });
        }
    } else {
        std.log.err("Attempted to populate inventory index {d} with item 0x{x}, but props was not found", .{ idx, item });
    }

    const atlas_data = assets.ui_error_data;
    inventory_items[idx]._item = -1;
    inventory_items[idx].image_data.normal.atlas_data = atlas_data;
    inventory_items[idx].x = inventory_decor.x + inventory_pos_data[idx].x + (inventory_pos_data[idx].w - inventory_items[idx].width() + assets.padding * 2) / 2;
    inventory_items[idx].y = inventory_decor.y + inventory_pos_data[idx].y + (inventory_pos_data[idx].h - inventory_items[idx].height() + assets.padding * 2) / 2;
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
    for (items.items()) |item| {
        if (!item.visible or !item._is_dragging)
            continue;

        item.x = x + item._drag_offset_x;
        item.y = y + item._drag_offset_y;
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

    for (character_boxes.items()) |box| {
        if (!box.visible)
            continue;

        if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
            box.state = .hovered;
        } else {
            box.state = .none;
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

pub fn mousePress(x: f32, y: f32, mods: zglfw.Mods) bool {
    for (items.items()) |item| {
        if (!item.visible or !item.draggable)
            continue;

        if (utils.isInBounds(x, y, item.x, item.y, item.width(), item.height())) {
            if (mods.shift) {
                item.shift_click_callback(item);
                return true;
            }

            if (item._last_click_time + @divFloor(333, std.time.us_per_ms) > main.current_time) {
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

    for (character_boxes.items()) |box| {
        if (!box.visible)
            continue;

        if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
            box.press_callback(box);
            box.state = .pressed;
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
    for (items.items()) |item| {
        if (!item._is_dragging)
            continue;

        item._is_dragging = false;
        item.drag_end_callback(item);
    }

    for (buttons.items()) |button| {
        if (!button.visible)
            continue;

        if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
            button.state = .none;
        }
    }

    for (character_boxes.items()) |box| {
        if (!box.visible)
            continue;

        if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
            box.state = .none;
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

pub fn update(time: i64, dt: i64, allocator: std.mem.Allocator) !void {
    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    const ms_time = @divFloor(time, std.time.us_per_ms);
    const ms_dt: f32 = @as(f32, @floatFromInt(dt)) / std.time.us_per_ms;
    _ = ms_dt;

    if (map.localPlayerConst()) |local_player| {
        if (last_level != local_player.level) {
            level_text.text_data.text = try std.fmt.bufPrint(level_text.text_data.backing_buffer, "{d}", .{local_player.level});

            last_level = local_player.level;
        }

        const max_level = local_player.level >= 20;
        if (max_level) {
            if (last_fame != local_player.fame or last_fame_goal != local_player.fame_goal) {
                fame_bar.visible = true;
                xp_bar.visible = false;
                const fame_perc = @as(f32, @floatFromInt(local_player.fame)) / @as(f32, @floatFromInt(local_player.fame_goal));
                fame_bar.max_width = fame_bar.width() * fame_perc;
                fame_bar.text_data.text = try std.fmt.bufPrint(fame_bar.text_data.backing_buffer, "{d}/{d} Fame", .{ local_player.fame, local_player.fame_goal });

                last_fame = local_player.fame;
                last_fame_goal = local_player.fame_goal;
            }
        } else {
            if (last_xp != local_player.exp or last_xp_goal != local_player.exp_goal) {
                xp_bar.visible = true;
                fame_bar.visible = false;
                const exp_perc = @as(f32, @floatFromInt(local_player.exp)) / @as(f32, @floatFromInt(local_player.exp_goal));
                xp_bar.max_width = xp_bar.width() * exp_perc;
                xp_bar.text_data.text = try std.fmt.bufPrint(xp_bar.text_data.backing_buffer, "{d}/{d} XP", .{ local_player.exp, local_player.exp_goal });

                last_xp = local_player.exp;
                last_xp_goal = local_player.exp_goal;
            }
        }

        if (last_hp != local_player.hp or last_max_hp != local_player.max_hp) {
            const hp_perc = @as(f32, @floatFromInt(local_player.hp)) / @as(f32, @floatFromInt(local_player.max_hp));
            health_bar.max_width = health_bar.width() * hp_perc;
            health_bar.text_data.text = try std.fmt.bufPrint(health_bar.text_data.backing_buffer, "{d}/{d} HP", .{ local_player.hp, local_player.max_hp });

            last_hp = local_player.hp;
            last_max_hp = local_player.max_hp;
        }

        if (last_mp != local_player.mp or last_max_mp != local_player.max_mp) {
            const mp_perc = @as(f32, @floatFromInt(local_player.mp)) / @as(f32, @floatFromInt(local_player.max_mp));
            mana_bar.max_width = mana_bar.width() * mp_perc;
            mana_bar.text_data.text = try std.fmt.bufPrint(mana_bar.text_data.backing_buffer, "{d}/{d} MP", .{ local_player.mp, local_player.max_mp });

            last_mp = local_player.mp;
            last_max_mp = local_player.max_mp;
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

        const elapsed = ms_time - status_text.start_time;
        if (elapsed > status_text.lifetime) {
            status_texts_to_remove.add(i) catch |e| {
                std.log.err("Status text disposing failed: {any}", .{e});
            };
            continue :textUpdate;
        }

        const frac = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(status_text.lifetime));
        status_text.text_data.size = status_text.initial_size * @min(1.0, @max(0.7, 1.0 - frac * 0.3 + 0.075));
        status_text.text_data.alpha = 1.0 - frac + 0.33;
        if (map.findEntityConst(status_text.obj_id)) |en| {
            switch (en) {
                inline else => |obj| {
                    status_text._screen_x = obj.screen_x - status_text.text_data.width() / 2;
                    status_text._screen_y = obj.screen_y - status_text.text_data.height() - frac * 40;
                },
            }
        }
    }

    std.mem.reverse(usize, status_texts_to_remove.items());

    for (status_texts_to_remove.items()) |idx| {
        allocator.free(status_texts.remove(idx).text_data.text);
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

        const elapsed = ms_time - speech_balloon.start_time;
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
        speech_balloon.text_data.alpha = alpha;
        if (map.findEntityConst(speech_balloon.target_id)) |en| {
            switch (en) {
                inline else => |obj| {
                    speech_balloon._screen_x = obj.screen_x - speech_balloon.width() / 2;
                    speech_balloon._screen_y = obj.screen_y - speech_balloon.height();
                },
            }
        }
    }

    std.mem.reverse(usize, speech_balloons_to_remove.items());

    for (speech_balloons_to_remove.items()) |idx| {
        allocator.free(speech_balloons.remove(idx).text_data.text);
    }

    speech_balloons_to_remove.clear();

    obj_ids_to_remove.clear();
}
