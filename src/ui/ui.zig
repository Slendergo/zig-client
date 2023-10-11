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
const AccountRegisterScreen = @import("account.zig").AccountRegisterScreen;
const InGameScreen = @import("in_game.zig").InGameScreen;
const CharSelectScreen = @import("char_select.zig").CharSelectScreen;
const CharCreateScreen = @import("char_create.zig").CharCreateScreen;
const EmptyScreen = @import("empty_screen.zig").EmptyScreen;
const OptionsUi = @import("options_ui.zig").OptionsUi;
const settings = @import("../settings.zig");

// Assumes ARGB because flash scuff. Change later
pub const RGBF32 = extern struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn fromValues(r: f32, g: f32, b: f32) RGBF32 {
        return RGBF32{ .r = r, .g = g, .b = b };
    }

    pub fn fromInt(int: u32) RGBF32 {
        return RGBF32{
            .r = @as(f32, @floatFromInt((int & 0x00FF0000) >> 16)) / 255.0,
            .g = @as(f32, @floatFromInt((int & 0x0000FF00) >> 8)) / 255.0,
            .b = @as(f32, @floatFromInt((int & 0x000000FF) >> 0)) / 255.0,
        };
    }
};

pub const InteractableState = enum {
    none,
    pressed,
    hovered,
};

pub const InteractableImageData = struct {
    base: ImageData,
    hover: ?ImageData = null,
    press: ?ImageData = null,

    pub fn current(self: InteractableImageData, state: InteractableState) ImageData {
        switch (state) {
            .none => return self.base,
            .pressed => return self.press orelse self.base,
            .hovered => return self.hover orelse self.base,
        }
    }
};

// Scissor positions are relative to the element it's attached to
pub const ScissorRect = extern struct {
    pub const dont_scissor = -1.0;

    min_x: f32 = dont_scissor,
    max_x: f32 = dont_scissor,
    min_y: f32 = dont_scissor,
    max_y: f32 = dont_scissor,

    // hack
    pub fn isDefault(self: ScissorRect) bool {
        return @as(u128, @bitCast(self)) == @as(u128, @bitCast(ScissorRect{}));
    }
};

pub const InputField = struct {
    x: f32,
    y: f32,
    text_inlay_x: f32,
    text_inlay_y: f32,
    image_data: InteractableImageData,
    cursor_image_data: ImageData,
    text_data: TextData,
    allocator: std.mem.Allocator,
    enter_callback: ?*const fn ([]u8) void = null,
    state: InteractableState = .none,
    visible: bool = true,
    is_chat: bool = false,
    // -1 means not selected
    _last_input: i64 = -1,
    _x_offset: f32 = 0.0,
    _index: u32 = 0,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: InputField) !*InputField {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(InputField);
        elem.* = data;
        elem._allocator = allocator;

        if (data.text_data.scissor.isDefault()) {
            elem.text_data.scissor = .{
                .min_x = 0,
                .min_y = 0,
                .max_x = elem.width() - elem.text_inlay_x * 2,
                .max_y = elem.height() - elem.text_inlay_y * 2,
            };
        }

        switch (elem.cursor_image_data) {
            .nine_slice => |*nine_slice| nine_slice.h = data.text_data.height(),
            .normal => |*image_data| image_data.scale_y = data.text_data.height() / image_data.height(),
        }

        try elements.add(.{ .input_field = elem });
        return elem;
    }

    pub fn imageData(self: InputField) ImageData {
        return self.image_data.current(self.state);
    }

    pub fn width(self: InputField) f32 {
        return @max(self.text_data.width(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub fn height(self: InputField) f32 {
        return @max(self.text_data.height(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }

    pub fn clear(self: *InputField) void {
        self.text_data.text = "";
        self._index = 0;
        self.inputUpdate();
    }

    pub fn inputUpdate(self: *InputField) void {
        self._last_input = main.current_time;

        const cursor_width = switch (self.cursor_image_data) {
            .nine_slice => |nine_slice| if (nine_slice.alpha > 0) nine_slice.w else 0.0,
            .normal => |image_data| if (image_data.alpha > 0) image_data.width() else 0.0,
        };

        const img_width = switch (self.imageData()) {
            .nine_slice => |nine_slice| nine_slice.w,
            .normal => |image_data| image_data.width(),
        } - self.text_inlay_x * 2 - cursor_width;
        const offset = @max(0, self.text_data.width() - img_width);
        self._x_offset = -offset;
        self.text_data.scissor.min_x = offset;
        self.text_data.scissor.max_x = offset + img_width;
    }

    pub fn destroy(self: *InputField) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .input_field and element.input_field == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.free(self.text_data.backing_buffer);
        self._allocator.destroy(self);
    }
};

pub const Button = struct {
    x: f32,
    y: f32,
    press_callback: *const fn () void,
    image_data: InteractableImageData,
    state: InteractableState = .none,
    text_data: ?TextData = null,
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: Button) !*Button {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(Button);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .button = elem });
        return elem;
    }

    pub fn imageData(self: Button) ImageData {
        return self.image_data.current(self.state);
    }

    pub fn width(self: Button) f32 {
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

    pub fn height(self: Button) f32 {
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

    pub fn destroy(self: *Button) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .button and element.button == self) {
                _ = elements.remove(i);
                break;
            }
        }

        if (self.text_data) |text_data| {
            self._allocator.free(text_data.backing_buffer);
        }

        self._allocator.destroy(self);
    }
};

pub const KeyMapper = struct {
    x: f32,
    y: f32,
    //press_callback: *const fn () void,
    set_key_callback: *const fn (*KeyMapper) void,
    image_data: InteractableImageData,
    text_data: TextData,
    settings_button: *settings.Button,
    key: zglfw.Key = zglfw.Key.unknown,
    title_text_data: ?TextData = null,
    state: InteractableState = .none,
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: KeyMapper) !*KeyMapper {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(KeyMapper);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .key_mapper = elem });
        return elem;
    }

    pub fn imageData(self: KeyMapper) ImageData {
        return self.image_data.current(self.state);
    }

    pub fn width(self: KeyMapper) f32 {
        return @max(self.text_data.width(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub fn height(self: KeyMapper) f32 {
        return @max(self.text_data.height(), switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }

    pub fn destroy(self: *KeyMapper) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .key_mapper and element.key_mapper == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.free(self.text_data.backing_buffer);

        self._allocator.destroy(self);
    }
};

pub const CharacterBox = struct {
    x: f32,
    y: f32,
    id: u32,
    obj_type: u16, //added so I don't have to make a NewCharacterBox struct rn
    press_callback: *const fn (*CharacterBox) void,
    image_data: InteractableImageData,
    state: InteractableState = .none,
    text_data: ?TextData = null,
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: CharacterBox) !*CharacterBox {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(CharacterBox);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .char_box = elem });
        return elem;
    }

    pub fn imageData(self: CharacterBox) ImageData {
        return self.image_data.current(self.state);
    }

    pub fn width(self: CharacterBox) f32 {
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

    pub fn height(self: CharacterBox) f32 {
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

    pub fn destroy(self: *CharacterBox) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .char_box and element.char_box == self) {
                _ = elements.remove(i);
                break;
            }
        }

        if (self.text_data) |text_data| {
            self._allocator.free(text_data.backing_buffer);
        }

        self._allocator.destroy(self);
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
    scissor: ScissorRect = .{},

    pub fn fromAtlasData(data: assets.AtlasData, w: f32, h: f32, slice_x: f32, slice_y: f32, slice_w: f32, slice_h: f32, alpha: f32) NineSliceImageData {
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

    pub fn topLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_left_idx];
    }

    pub fn topCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_center_idx];
    }

    pub fn topRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[top_right_idx];
    }

    pub fn middleLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_left_idx];
    }

    pub fn middleCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_center_idx];
    }

    pub fn middleRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[middle_right_idx];
    }

    pub fn bottomLeft(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_left_idx];
    }

    pub fn bottomCenter(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_center_idx];
    }

    pub fn bottomRight(self: NineSliceImageData) assets.AtlasData {
        return self.atlas_data[bottom_right_idx];
    }
};

pub const NormalImageData = struct {
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    alpha: f32 = 1.0,
    atlas_data: assets.AtlasData,
    scissor: ScissorRect = .{},

    pub fn width(self: NormalImageData) f32 {
        return self.atlas_data.texWRaw() * self.scale_x;
    }

    pub fn height(self: NormalImageData) f32 {
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
    visible: bool = true,
    // hack
    is_minimap_decor: bool = false,
    minimap_offset_x: f32 = 0.0,
    minimap_offset_y: f32 = 0.0,
    minimap_width: f32 = 0.0,
    minimap_height: f32 = 0.0,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: Image) !*Image {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(Image);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .image = elem });
        return elem;
    }

    pub fn width(self: Image) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub fn height(self: Image) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }

    pub fn destroy(self: *Image) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .image and element.image == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.destroy(self);
    }
};

pub const MenuBackground = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    scissor: ScissorRect = .{},
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: MenuBackground) !*MenuBackground {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(MenuBackground);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .menu_bg = elem });
        return elem;
    }

    pub fn destroy(self: *MenuBackground) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .menu_bg and element.menu_bg == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.destroy(self);
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
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: Item) !*Item {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(Item);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .item = elem });
        return elem;
    }

    pub fn width(self: Item) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub fn height(self: Item) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }

    pub fn destroy(self: *Item) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .item and element.item == self) {
                _ = elements.remove(i);
                break;
            }
        }

        if (self.tier_text) |text| {
            self._allocator.free(text.text_data.backing_buffer);
        }
        self._allocator.destroy(self);
    }
};

pub const Bar = struct {
    x: f32,
    y: f32,
    image_data: ImageData,
    visible: bool = true,
    text_data: TextData,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: Bar) !*Bar {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(Bar);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .bar = elem });
        return elem;
    }

    pub fn width(self: Bar) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub fn height(self: Bar) f32 {
        switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }

    pub fn destroy(self: *Bar) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .bar and element.bar == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.free(self.text_data.backing_buffer);
        self._allocator.destroy(self);
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

    pub fn add(data: SpeechBalloon) !void {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        try elements.add(.{ .balloon = data });
    }

    pub fn width(self: SpeechBalloon) f32 {
        return @max(self.text_data.width(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        });
    }

    pub fn height(self: SpeechBalloon) f32 {
        return @max(self.text_data.height(), switch (self.image_data) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        });
    }

    pub fn destroy(self: *SpeechBalloon, allocator: std.mem.Allocator) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .balloon and &element.balloon == self) {
                _ = elements.remove(i);
                break;
            }
        }

        allocator.free(self.text_data.text);
    }
};

pub const UiText = struct {
    x: f32,
    y: f32,
    text_data: TextData,
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: UiText) !*UiText {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(UiText);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .text = elem });
        return elem;
    }

    pub fn destroy(self: *UiText) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .text and element.text == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.free(self.text_data.backing_buffer);
        self._allocator.destroy(self);
    }
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

    pub fn add(data: StatusText) !void {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        try elements.add(.{ .status = data });
    }

    pub fn width(self: StatusText) f32 {
        return self.text_data.width();
    }

    pub fn height(self: StatusText) f32 {
        return self.text_data.height();
    }

    pub fn destroy(self: *StatusText, allocator: std.mem.Allocator) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .status and &element.status == self) {
                _ = elements.remove(i);
                break;
            }
        }

        allocator.free(self.text_data.text);
    }
};

pub const TextType = enum(u32) {
    medium = 0,
    medium_italic = 1,
    bold = 2,
    bold_italic = 3,
};

pub const AlignHori = enum(u8) {
    left = 0,
    middle = 1,
    right = 2,
};

pub const AlignVert = enum(u8) {
    top = 0,
    middle = 1,
    bottom = 2,
};

pub const TextData = struct {
    text: []u8,
    size: f32,
    backing_buffer: []u8,
    text_type: TextType = .medium,
    color: u32 = 0xFFFFFFFF,
    alpha: f32 = 1.0,
    shadow_color: u32 = 0xFF000000,
    shadow_alpha_mult: f32 = 0.5,
    shadow_texel_offset_mult: f32 = 0.0,
    outline_color: u32 = 0xFF000000,
    outline_width: f32 = 1.2, // 0.5 for off
    password: bool = false,
    handle_special_chars: bool = true,
    disable_subpixel: bool = false,
    scissor: ScissorRect = .{},
    // alignments other than default need max width/height defined respectively
    // no support for multi-line alignment currently
    hori_align: AlignHori = .left,
    vert_align: AlignVert = .top,
    max_width: f32 = @as(f32, std.math.maxInt(u32)),
    max_height: f32 = @as(f32, std.math.maxInt(u32)),

    pub fn width(self: TextData) f32 {
        const size_scale = self.size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;

        var x_max: f32 = 0.0;
        var x_pointer: f32 = 0.0;
        var current_size = size_scale;
        var current_type = self.text_type;
        var index_offset: u8 = 0;
        for (0..self.text.len) |i| {
            if (i + index_offset >= self.text.len)
                return @min(x_max, self.max_width);

            const char = self.text[i + index_offset];
            specialChar: {
                if (!self.handle_special_chars)
                    break :specialChar;

                if (char == '&') {
                    const start_idx = i + index_offset + 3;
                    if (self.text.len <= start_idx or self.text[start_idx - 1] != '=')
                        break :specialChar;

                    switch (self.text[start_idx - 2]) {
                        'c' => {
                            if (self.text.len <= start_idx + 6)
                                break :specialChar;

                            index_offset += 8;
                            continue;
                        },
                        's' => {
                            var size_len: u8 = 0;
                            while (start_idx + size_len < self.text.len and std.ascii.isDigit(self.text[start_idx + size_len])) {
                                size_len += 1;
                            }

                            if (size_len == 0)
                                break :specialChar;

                            const size = std.fmt.parseFloat(f32, self.text[start_idx .. start_idx + size_len]) catch 16.0;
                            current_size = size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
                            index_offset += 2 + size_len;
                            continue;
                        },
                        't' => {
                            switch (self.text[start_idx]) {
                                'm' => current_type = .medium,
                                'i' => current_type = .medium_italic,
                                'b' => current_type = .bold,
                                // this has no reason to be 'c', just a hack...
                                'c' => current_type = .bold_italic,
                                else => {},
                            }

                            index_offset += 3;
                            continue;
                        },
                        else => {},
                    }
                }
            }

            if (char == '\n') {
                x_pointer = 0;
                continue;
            }

            const mod_char = if (self.password) '*' else char;

            const char_data = switch (current_type) {
                .medium => assets.medium_chars[mod_char],
                .medium_italic => assets.medium_italic_chars[mod_char],
                .bold => assets.bold_chars[mod_char],
                .bold_italic => assets.bold_italic_chars[mod_char],
            };

            x_pointer += char_data.x_advance * current_size;
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
        var current_size = size_scale;
        var current_type = self.text_type;
        var index_offset: u8 = 0;
        for (0..self.text.len) |i| {
            if (i + index_offset >= self.text.len)
                return y_pointer;

            const char = self.text[i + index_offset];
            specialChar: {
                if (!self.handle_special_chars)
                    break :specialChar;

                if (char == '&') {
                    const start_idx = i + index_offset + 3;
                    if (self.text.len <= start_idx or self.text[start_idx - 1] != '=')
                        break :specialChar;

                    switch (self.text[start_idx - 2]) {
                        'c' => {
                            if (self.text.len <= start_idx + 6)
                                break :specialChar;

                            index_offset += 8;
                            continue;
                        },
                        's' => {
                            var size_len: u8 = 0;
                            while (start_idx + size_len < self.text.len and std.ascii.isDigit(self.text[start_idx + size_len])) {
                                size_len += 1;
                            }

                            if (size_len == 0)
                                break :specialChar;

                            const size = std.fmt.parseFloat(f32, self.text[start_idx .. start_idx + size_len]) catch 16.0;
                            current_size = size / assets.CharacterData.size * camera.scale * assets.CharacterData.padding_mult;
                            index_offset += 2 + size_len;
                            continue;
                        },
                        't' => {
                            switch (self.text[start_idx]) {
                                'm' => current_type = .medium,
                                'i' => current_type = .medium_italic,
                                'b' => current_type = .bold,
                                // this has no reason to be 'c', just a hack...
                                'c' => current_type = .bold_italic,
                                else => {},
                            }

                            index_offset += 3;
                            continue;
                        },
                        else => {},
                    }
                }
            }

            const mod_char = if (self.password) '*' else char;

            const char_data = switch (self.text_type) {
                .medium => assets.medium_chars[mod_char],
                .medium_italic => assets.medium_italic_chars[mod_char],
                .bold => assets.bold_chars[mod_char],
                .bold_italic => assets.bold_italic_chars[mod_char],
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
    visible: bool = true,
    _elements: utils.DynSlice(UiElement) = undefined,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: DisplayContainer) !*DisplayContainer {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(DisplayContainer);
        elem.* = data;
        elem._allocator = allocator;
        elem._elements = try utils.DynSlice(UiElement).init(8, allocator);
        try elements.add(.{ .container = elem });
        return elem;
    }

    pub fn createElement(self: *DisplayContainer, comptime data: anytype) !*@TypeOf(data) {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        const data_type = @TypeOf(data);
        var elem = try self._allocator.create(data_type);
        elem.* = data;
        switch (data_type) {
            Image => try self._elements.add(.{ .image = elem }),
            Item => try self._elements.add(.{ .item = elem }),
            Bar => try self._elements.add(.{ .bar = elem }),
            InputField => try self._elements.add(.{ .input_field = elem }),
            Button => try self._elements.add(.{ .button = elem }),
            UiText => try self._elements.add(.{ .text = elem }),
            CharacterBox => try self._elements.add(.{ .char_box = elem }),
            DisplayContainer => try self._elements.add(.{ .container = elem }),
            MenuBackground => try self._elements.add(.{ .menu_bg = elem }),
            Toggle => try self._elements.add(.{ .toggle = elem }),
            else => @compileError("Element type not supported"),
        }
        return elem;
    }

    pub fn destroy(self: *DisplayContainer) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .container and element.container == self) {
                _ = elements.remove(i);
                break;
            }
        }

        for (self._elements.items()) |*elem| {
            switch (elem.*) {
                .container => |container| container.destroy(),
                .bar => |bar| bar.destroy(),
                .input_field => |input_field| input_field.destroy(),
                .button => |button| button.destroy(),
                .char_box => |box| box.destroy(),
                .text => |text| text.destroy(),
                .item => |item| item.destroy(),
                .image => |image| image.destroy(),
                .menu_bg => |menu_bg| menu_bg.destroy(),
                .toggle => |toggle| toggle.destroy(),
                else => {},
            }
        }
        self._elements.deinit();
    }
};

pub const Toggle = struct {
    x: f32,
    y: f32,
    off_image_data: InteractableImageData,
    on_image_data: InteractableImageData,
    state: InteractableState = .none,
    toggled: bool = false,
    state_change: ?*const fn (*Toggle) void,
    visible: bool = true,
    _disposed: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn create(allocator: std.mem.Allocator, data: Toggle) !*Toggle {
        const should_lock = elements.isFull();
        if (should_lock) {
            while (!ui_lock.tryLock()) {}
        }
        defer if (should_lock) ui_lock.unlock();

        var elem = try allocator.create(Toggle);
        elem.* = data;
        elem._allocator = allocator;
        try elements.add(.{ .toggle = elem });
        return elem;
    }

    pub fn imageData(self: Toggle) ImageData {
        return if (self.toggled)
            self.on_image_data.current(self.state)
        else
            self.off_image_data.current(self.state);
    }

    pub fn width(self: Toggle) f32 {
        switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.w,
            .normal => |image_data| return image_data.width(),
        }
    }

    pub fn height(self: Toggle) f32 {
        switch (self.imageData()) {
            .nine_slice => |nine_slice| return nine_slice.h,
            .normal => |image_data| return image_data.height(),
        }
    }

    pub fn destroy(self: *Toggle) void {
        if (self._disposed)
            return;

        self._disposed = true;

        for (elements.items(), 0..) |element, i| {
            if (element == .toggle and element.toggle == self) {
                _ = elements.remove(i);
                break;
            }
        }

        self._allocator.destroy(self);
    }
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
    menu_bg: *MenuBackground,
    toggle: *Toggle,
    key_mapper: *KeyMapper,
    // pointers on these would imply allocation, which is pointless and wasteful
    balloon: SpeechBalloon,
    status: StatusText,
};

pub const ScreenType = enum {
    empty,
    main_menu,
    register,
    char_select,
    char_create,
    in_game,
};

pub const Screen = union(ScreenType) {
    empty: *EmptyScreen,
    main_menu: *AccountScreen,
    register: *AccountRegisterScreen,
    char_select: *CharSelectScreen,
    char_create: *CharCreateScreen,
    in_game: *InGameScreen,
};

pub var ui_lock: std.Thread.Mutex = .{};
pub var elements: utils.DynSlice(UiElement) = undefined;
pub var elements_to_remove: utils.DynSlice(*UiElement) = undefined;
pub var current_screen: Screen = undefined;

var menu_background: *MenuBackground = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    elements = try utils.DynSlice(UiElement).init(64, allocator);
    elements_to_remove = try utils.DynSlice(*UiElement).init(32, allocator);

    menu_background = try MenuBackground.create(allocator, .{
        .x = 0,
        .y = 0,
        .w = camera.screen_width,
        .h = camera.screen_height,
    });

    current_screen = .{ .empty = try EmptyScreen.init(allocator) };
}

pub fn deinit() void {
    menu_background.destroy();

    switch (current_screen) {
        inline else => |screen| screen.deinit(),
    }

    elements.deinit();
    elements_to_remove.deinit();
}

pub fn resize(w: f32, h: f32) void {
    menu_background.w = camera.screen_width;
    menu_background.h = camera.screen_height;

    switch (current_screen) {
        inline else => |screen| screen.resize(w, h),
    }
}

pub fn switchScreen(screen_type: ScreenType) void {
    menu_background.visible = screen_type != .in_game;
    input.selected_key_mapper = null;

    switch (current_screen) {
        inline else => |screen| if (screen.inited) screen.deinit(),
    }

    // should probably figure out some comptime magic to avoid all this... todo
    switch (screen_type) {
        .empty => current_screen = .{ .empty = EmptyScreen.init(main._allocator) catch unreachable },
        .main_menu => {
            current_screen = .{ .main_menu = AccountScreen.init(main._allocator) catch |e| {
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
        .in_game => {
            current_screen = .{ .in_game = InGameScreen.init(main._allocator) catch |e| {
                std.log.err("Initializing in game screen failed: {any}", .{e});
                return;
            } };
        },
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
            .toggle => |toggle| {
                if (!toggle.visible)
                    continue;

                if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                    toggle.state = .hovered;
                } else {
                    toggle.state = .none;
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
            .key_mapper => |key_mapper| {
                if (!key_mapper.visible)
                    continue;

                if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                    key_mapper.state = .hovered;
                } else {
                    key_mapper.state = .none;
                }
            },
            else => {},
        }
    }
}

pub fn mousePress(x: f32, y: f32, mods: zglfw.Mods) bool {
    if (input.selected_input_field) |input_field| {
        input_field._last_input = -1;
        input.selected_input_field = null;
    }

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
                    assets.playSfx("ButtonClick");
                    return true;
                }
            },
            .toggle => |toggle| {
                if (!toggle.visible)
                    continue;

                if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                    toggle.state = .pressed;
                    toggle.toggled = !toggle.toggled;
                    if (toggle.state_change) |callback| {
                        callback(toggle);
                    }
                    assets.playSfx("ButtonClick");
                    return true;
                }
            },
            .char_box => |box| {
                if (!box.visible)
                    continue;

                if (utils.isInBounds(x, y, box.x, box.y, box.width(), box.height())) {
                    box.state = .pressed;
                    box.press_callback(box);
                    assets.playSfx("ButtonClick");
                    return true;
                }
            },
            .input_field => |input_field| {
                if (!input_field.visible)
                    continue;

                if (utils.isInBounds(x, y, input_field.x, input_field.y, input_field.width(), input_field.height())) {
                    input.selected_input_field = input_field;
                    input_field._last_input = 0;
                    input_field.state = .pressed;
                    return true;
                }
            },
            .key_mapper => |key_mapper| {
                if (!key_mapper.visible)
                    continue;

                if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                    key_mapper.state = .pressed;
                    input.selected_key_mapper = key_mapper;

                    //Not needed at the moment
                    //key_mapper.press_callback();

                    assets.playSfx("ButtonClick");
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
            .toggle => |toggle| {
                if (!toggle.visible)
                    continue;

                if (utils.isInBounds(x, y, toggle.x, toggle.y, toggle.width(), toggle.height())) {
                    toggle.state = .none;
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
            .key_mapper => |key_mapper| {
                if (!key_mapper.visible)
                    continue;

                if (utils.isInBounds(x, y, key_mapper.x, key_mapper.y, key_mapper.width(), key_mapper.height())) {
                    key_mapper.state = .none;
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

var options_opened: bool = false;
var options: *OptionsUi = undefined;

pub fn hideOptions() void {
    input.disable_input = false;
    options_opened = false;
    options.deinit();
}

pub fn showOptions() void {
    if (options_opened) {
        //Maybe remove this if we want
        //to use ESC to remove key binds
        hideOptions();
        return;
    }

    input.disable_input = true;

    options_opened = true;

    options = OptionsUi.init(main._allocator, .{ .visible = true }) catch |e| {
        std.log.err("Initializing in options failed: {any}", .{e});
        return;
    };
}

pub fn switchOptionsTab(tab: OptionsUi.Tabs) void {
    options.switchTab(tab);
}
