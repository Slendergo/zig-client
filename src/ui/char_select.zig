const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const requests = @import("../requests.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");

pub const CharSelectScreen = struct {
    boxes: std.ArrayList(*ui.CharacterBox) = undefined,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !CharSelectScreen {
        var screen = CharSelectScreen{
            ._allocator = allocator,
        };

        screen.boxes = std.ArrayList(*ui.CharacterBox).init(allocator);
        try screen.boxes.ensureTotalCapacity(8);

        return screen;
    }

    pub fn deinit(self: *CharSelectScreen, allocator: std.mem.Allocator) void {
        for (self.boxes.items) |box| {
            for (ui.elements.items(), 0..) |element, i| {
                if (element == .char_box and element.char_box == box) {
                    ui.disposeElement(ui.elements.removePtr(i), allocator);
                }
            }
            allocator.destroy(box);
        }

        self.boxes.clearAndFree();
    }

    pub fn toggle(self: *CharSelectScreen, state: bool) void {
        while (!ui.dispose_lock.tryLock()) {}
        for (self.boxes.items) |box| {
            for (ui.elements.items(), 0..) |element, i| {
                if (element == .char_box and element.char_box == box) {
                    ui.disposeElement(ui.elements.removePtr(i), self._allocator);
                }
            }
            self._allocator.destroy(box);
        }
        ui.dispose_lock.unlock();

        self.boxes.clearAndFree();

        if (!state)
            return;

        const button_data_base = assets.getUi("buttonBase", 0);
        const button_data_hover = assets.getUi("buttonHover", 0);
        const button_data_press = assets.getUi("buttonPress", 0);

        for (main.character_list, 0..) |char, i| {
            const box = self._allocator.create(ui.CharacterBox) catch return;
            box.* = ui.CharacterBox{
                .x = (camera.screen_width - button_data_base.texWRaw()) / 2,
                .y = @floatFromInt(50 * i),
                .id = char.id,
                .base_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                    button_data_base,
                    100,
                    40,
                    6,
                    6,
                    7,
                    7,
                    1.0,
                ) },
                .hover_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                    button_data_hover,
                    100,
                    40,
                    6,
                    6,
                    7,
                    7,
                    1.0,
                ) },
                .press_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                    button_data_press,
                    100,
                    40,
                    6,
                    6,
                    7,
                    7,
                    1.0,
                ) },
                .text_data = ui.TextData{
                    .text = @constCast(char.name[0..]),
                    .backing_buffer = self._allocator.alloc(u8, 1) catch return,
                    .size = 16,
                    .text_type = .bold,
                },
                .press_callback = boxClickCallback,
            };
            self.boxes.append(box) catch return;
            ui.elements.add(.{ .char_box = box }) catch return;
        }
    }

    pub fn resize(self: *CharSelectScreen, w: f32, h: f32) void {
        _ = h;
        _ = w;
        _ = self;
    }

    pub fn update(self: *CharSelectScreen, ms_time: i64, ms_dt: f32) !void {
        _ = self;
        _ = ms_dt;
        _ = ms_time;
    }

    fn boxClickCallback(box: *ui.CharacterBox) void {
        main.selected_char_id = box.id;
        if (main.server_list) |server_list| {
            main.selected_server = server_list[0];
        } else {
            std.log.err("No servers found", .{});
        }
        ui.switchScreen(.in_game);
    }
};
