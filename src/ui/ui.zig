const std = @import("std");
const camera = @import("../camera.zig");
const assets = @import("../assets.zig");
const map = @import("../map.zig");
const utils = @import("../utils.zig");
const input = @import("../input.zig");
const main = @import("../main.zig");
const game_data = @import("../game_data.zig");
const network = @import("../network.zig");
const zglfw = @import("zglfw");
const AccountScreen = @import("account.zig").AccountScreen;
const InGameScreen = @import("in_game.zig").InGameScreen;
const CharSelectScreen = @import("char_select.zig").CharSelectScreen;
const CharCreateScreen = @import("char_create.zig").CharCreateScreen;

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
    allow_chat_history: bool = false,
    _index: u32 = 0,
    _disposed: bool = false,

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

    pub inline fn clear(self: *InputField) void {
        self.text_data.text = "";
        self._index = 0;
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
    _disposed: bool = false,

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
    _disposed: bool = false,

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
    // hack
    is_minimap_decor: bool = false,
    minimap_offset_x: f32 = 0.0,
    minimap_offset_y: f32 = 0.0,
    minimap_width: f32 = 0.0,
    minimap_height: f32 = 0.0,
    _disposed: bool = false,

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
    _disposed: bool = false,

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
    _disposed: bool = false,

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
    _disposed: bool = false,

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
    _disposed: bool = false,
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
    _disposed: bool = false,

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

pub const TextAlignmentHori = enum(u8) {
    left = 0,
    middle = 1,
    right = 2,
};

pub const TextAlignmentVert = enum(u8) {
    top = 0,
    middle = 1,
    bottom = 2,
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
    shadow_texel_offset_mult: f32 = 0.0,
    outline_color: i32 = 0x000000,
    outline_width: f32 = 1.2, // 0.5 for off
    password: bool = false,
    // alignments other than default need max width/height defined respectively
    // no support for multi-line alignment currently
    hori_align: TextAlignmentHori = .left,
    vert_align: TextAlignmentVert = .top,
    max_width: f32 = @as(f32, std.math.maxInt(u32)),
    max_height: f32 = @as(f32, std.math.maxInt(u32)),

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

pub const DisplayContainer = struct {
    x: f32,
    y: f32,
    elements: utils.DynSlice(*UiElement) = undefined,
    _disposed: bool = false,
};

pub const ScreenType = enum(u8) {
    main_menu,
    char_select,
    char_creation,
    map_editor,
    in_game,
};

pub const UiElement = union(enum) {
    image: *Image,
    item: *Item,
    bar: *Bar,
    input_field: *InputField,
    button: *Button,
    text: *UiText,
    char_box: *CharacterBox,
    container: *DisplayContainer,
    // pointers on these would imply allocation, which is pointless and wasteful
    balloon: SpeechBalloon,
    status: StatusText,
};

pub var status_dispose_lock: std.Thread.Mutex = .{};
pub var balloon_dispose_lock: std.Thread.Mutex = .{};
pub var elements: utils.DynSlice(UiElement) = undefined;
pub var elements_to_remove: utils.DynSlice(usize) = undefined;
pub var current_screen = ScreenType.main_menu;

var menu_background: *Image = undefined;

pub var account_screen: AccountScreen = undefined;
pub var char_select_screen: CharSelectScreen = undefined;
pub var char_create_screen: CharCreateScreen = undefined;
pub var in_game_screen: InGameScreen = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    elements = try utils.DynSlice(UiElement).init(64, allocator);
    elements_to_remove = try utils.DynSlice(usize).init(64, allocator);

    menu_background = try allocator.create(Image);
    var menu_bg_data = assets.getUiSingle("menuBackground");
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
    try elements.add(.{ .image = menu_background });

    account_screen = try AccountScreen.init(allocator);
    char_select_screen = try CharSelectScreen.init(allocator);
    char_create_screen = try CharCreateScreen.init(allocator);
    in_game_screen = try InGameScreen.init(allocator);
}

pub fn disposeElement(elem: *UiElement, allocator: std.mem.Allocator) void {
    switch (elem.*) {
        .bar => |bar| {
            if (bar._disposed)
                return;

            bar._disposed = true;
            allocator.free(bar.text_data.backing_buffer);
        },
        .input_field => |input_field| {
            if (input_field._disposed)
                return;

            input_field._disposed = true;
            allocator.free(input_field.text_data.backing_buffer);
        },
        .button => |button| {
            if (button._disposed)
                return;

            button._disposed = true;

            if (button.text_data) |text_data| {
                allocator.free(text_data.backing_buffer);
            }
        },
        .char_box => |box| {
            if (box._disposed)
                return;

            box._disposed = true;

            if (box.text_data) |text_data| {
                allocator.free(text_data.backing_buffer);
            }
        },
        .text => |text| {
            if (text._disposed)
                return;

            text._disposed = true;
            allocator.free(text.text_data.backing_buffer);
        },
        .item => |item| {
            if (item._disposed)
                return;

            item._disposed = true;

            if (item.tier_text) |ui_text| {
                allocator.free(ui_text.text_data.backing_buffer);
            }
        },
        .balloon => |*balloon| {
            if (balloon._disposed)
                return;

            balloon._disposed = true;
            allocator.free(balloon.text_data.text);
        },
        .status => |*status| {
            if (status._disposed)
                return;

            status._disposed = true;
            allocator.free(status.text_data.text);
        },
        else => {},
    }
}

pub fn deinit(allocator: std.mem.Allocator) void {
    char_select_screen.deinit(allocator); // hack todo

    for (elements.items()) |*elem| {
        disposeElement(elem, allocator);
    }
    elements.deinit();

    account_screen.deinit(allocator);
    in_game_screen.deinit(allocator);
    char_create_screen.deinit(allocator);

    elements_to_remove.deinit();

    allocator.destroy(menu_background);
}

pub fn resize(w: f32, h: f32) void {
    menu_background.image_data.normal.scale_x = camera.screen_width / menu_background.image_data.normal.atlas_data.texWRaw();
    menu_background.image_data.normal.scale_y = camera.screen_height / menu_background.image_data.normal.atlas_data.texHRaw();

    account_screen.resize(w, h);
    in_game_screen.resize(w, h);
    char_select_screen.resize(w, h);
    char_create_screen.resize(w, h);
}

pub fn switchScreen(screen_type: ScreenType) void {
    current_screen = screen_type;

    menu_background.visible = screen_type != .in_game;
    account_screen.toggle(screen_type == .main_menu);
    in_game_screen.toggle(screen_type == .in_game);
    char_select_screen.toggle(screen_type == .char_select);
    char_create_screen.toggle(screen_type == .char_creation);
}

pub fn removeAttachedUi(obj_id: i32, allocator: std.mem.Allocator) void {
    for (elements.items()) |*elem| {
        switch (elem.*) {
            .status => |text| if (text.obj_id == obj_id) {
                disposeElement(elem, allocator);
                continue;
            },
            .balloon => |balloon| if (balloon.target_id == obj_id) {
                disposeElement(elem, allocator);
                continue;
            },
            else => {},
        }
    }
}

pub fn mouseMove(x: f32, y: f32) void {
    for (elements.items()) |elem| {
        switch (elem) {
            .item => |item| {
                if (!item.visible or !item._is_dragging)
                    continue;

                item.x = x + item._drag_offset_x;
                item.y = y + item._drag_offset_y;
            },
            .button => |button| {
                if (!button.visible)
                    continue;

                if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                    button.state = .hovered;
                } else {
                    button.state = .none;
                }
            },
            .char_box => |box| {
                if (!box.visible)
                    continue;

                if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                    box.state = .hovered;
                } else {
                    box.state = .none;
                }
            },
            .input_field => |input_field| {
                if (!input_field.visible)
                    continue;

                if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                    input_field.state = .hovered;
                } else {
                    input_field.state = .none;
                }
            },
            else => {},
        }
    }
}

pub fn mousePress(x: f32, y: f32, mods: zglfw.Mods) bool {
    input.selected_input_field = null;

    for (elements.items()) |elem| {
        switch (elem) {
            .item => |item| {
                if (!item.visible or !item.draggable)
                    continue;

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
                    continue;

                if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                    button.state = .pressed;
                    button.press_callback();
                    assets.playSfx("button_click");
                    return true;
                }
            },
            .char_box => |box| {
                if (!box.visible)
                    continue;

                if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                    box.state = .pressed;
                    box.press_callback(box);
                    return true;
                }
            },
            .input_field => |input_field| {
                if (!input_field.visible)
                    continue;

                if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                    input.selected_input_field = input_field;
                    input_field.state = .pressed;
                    return true;
                }
            },
            else => {},
        }
    }

    return false;
}

pub fn mouseRelease(x: f32, y: f32) void {
    for (elements.items()) |elem| {
        switch (elem) {
            .item => |item| {
                if (!item._is_dragging)
                    continue;

                item._is_dragging = false;
                item.drag_end_callback(item);
            },
            .button => |button| {
                if (!button.visible)
                    continue;

                if (utils.isInBounds(x, y, button.x, button.y, button.width(), button.height())) {
                    button.state = .none;
                }
            },
            .char_box => |box| {
                if (!box.visible)
                    continue;

                if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                    box.state = .none;
                }
            },
            .input_field => |input_field| {
                if (!input_field.visible)
                    continue;

                if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                    input_field.state = .none;
                }
            },
            else => {},
        }
    }
}

pub fn update(time: i64, dt: i64, allocator: std.mem.Allocator) !void {
    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    const ms_time = @divFloor(time, std.time.us_per_ms);
    const ms_dt: f32 = @as(f32, @floatFromInt(dt)) / std.time.us_per_ms;

    switch (current_screen) {
        .main_menu => try account_screen.update(ms_time, ms_dt),
        .char_select => try char_select_screen.update(ms_time, ms_dt),
        .in_game => try in_game_screen.update(ms_time, ms_dt),
        .char_creation => try char_create_screen.update(ms_time, ms_dt),
        else => {},
    }

    for (elements.items(), 0..) |*elem, i| {
        switch (elem.*) {
            .status => |*status_text| {
                const elapsed = ms_time - status_text.start_time;
                if (elapsed > status_text.lifetime) {
                    elements_to_remove.add(i) catch |e| {
                        std.log.err("Status text disposing failed: {any}", .{e});
                    };
                    continue;
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
            },
            .balloon => |*speech_balloon| {
                const elapsed = ms_time - speech_balloon.start_time;
                const lifetime = 5000;
                if (elapsed > lifetime) {
                    elements_to_remove.add(i) catch |e| {
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
                        inline else => |obj| {
                            speech_balloon._screen_x = obj.screen_x - speech_balloon.width() / 2;
                            speech_balloon._screen_y = obj.screen_y - speech_balloon.height();
                        },
                    }
                }
            },
            else => {},
        }
    }

    const removed_elements = elements_to_remove.items();
    const elements_len = removed_elements.len;
    for (0..elements_len) |i| {
        disposeElement(elements.removePtr(removed_elements[elements_len - 1 - i]), allocator);
    }

    elements_to_remove.clear();
}
