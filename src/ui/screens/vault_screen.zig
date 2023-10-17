const std = @import("std");
const ui = @import("../ui.zig");
const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const network = @import("../../network.zig");
const xml = @import("../../xml.zig");
const main = @import("../../main.zig");
const utils = @import("../../utils.zig");
const game_data = @import("../../game_data.zig");
const map = @import("../../map.zig");
const input = @import("../../input.zig");
const screen_controller = @import("screen_controller.zig").ScreenController;
const NineSlice = ui.NineSliceImageData;

var pre_width_x: f32 = 0;
var pre_height_y: f32 = 0;
var current_page: u8 = 1;
var max_pages: u8 = 9;

pub const VaultScreen = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,
    visible: bool = false,
    cont: *ui.DisplayContainer = undefined,
    number_text: *ui.UiText = undefined,

    pub fn init(allocator: std.mem.Allocator, data: VaultScreen) !*VaultScreen {
        var screen = try allocator.create(VaultScreen);
        screen.* = .{ ._allocator = allocator };
        screen.* = data;

        current_page = 1;

        var cam_width: f32 = camera.screen_width;
        var cam_height: f32 = camera.screen_height;

        const player_inventory = assets.getUiData("playerInventory", 0);
        const item_row = assets.getUiData("itemRow", 0);
        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        const items_width = item_row.texWRaw() * 2;
        const rows: f32 = 10;

        const item_height_offset: f32 = 30;
        const items_height = @min((item_row.texHRaw() * rows) + 100 + item_height_offset, cam_height);

        pre_width_x = -(player_inventory.texWRaw() + items_width + 20);
        pre_height_y = -(items_height + 10);

        const x = cam_width + pre_width_x;
        const y = cam_height + pre_height_y;
        const total_width = items_width + 10;
        var actual_half_width: f32 = total_width / 2;
        screen.cont = try ui.DisplayContainer.create(allocator, .{
            .x = x,
            .y = y,
            .visible = screen.visible,
        });
        _ = try screen.cont.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, total_width, items_height, 6, 6, 7, 7, 1.0) },
        });

        const text_x = actual_half_width - (32 * 2.5);
        _ = try screen.cont.createElement(ui.UiText, .{ .x = text_x, .y = -6, .text_data = .{
            .text = @constCast("Vault"),
            .size = 32,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        _ = try screen.cont.createElement(ui.UiText, .{ .x = text_x + 32, .y = 40, .text_data = .{
            .text = @constCast("Page"),
            .size = 16,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        screen.number_text = try screen.cont.createElement(ui.UiText, .{ .x = text_x + (16 * 5), .y = 40, .text_data = .{
            .text = @constCast("1"),
            .size = 16,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 16),
        } });

        const row_x = 5;
        const row_y = 40 + item_row.texHRaw();
        for (0..rows) |i| {
            var f: f32 = @floatFromInt(i);

            //item slots
            //0 - 3
            _ = try screen.cont.createElement(ui.Image, .{
                .x = row_x,
                .y = row_y + (f * item_row.texHRaw()),
                .image_data = .{ .normal = .{ .atlas_data = item_row } },
            });
            //4 - 7
            _ = try screen.cont.createElement(ui.Image, .{
                .x = row_x + item_row.texWRaw(),
                .y = row_y + (f * item_row.texHRaw()),
                .image_data = .{ .normal = .{ .atlas_data = item_row } },
            });
        }

        const button_width = 100;
        const button_height = 30;

        _ = try screen.cont.createElement(ui.Button, .{
            .x = actual_half_width - (button_width / 2),
            .y = items_height - button_height - (button_height / 2),
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Close"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = closeCallback,
        });

        _ = try screen.cont.createElement(ui.Button, .{
            .x = total_width - button_width - 10,
            .y = 40,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Next Page"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = nextCallback,
        });

        _ = try screen.cont.createElement(ui.Button, .{
            .x = 10,
            .y = 40,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Prev Page"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = prevCallback,
        });

        screen.inited = true;
        return screen;
    }

    pub fn setVisible(self: *VaultScreen, val: bool) void {
        self.cont.visible = val;
    }

    pub fn deinit(self: *VaultScreen) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.cont.destroy();
        self.number_text = undefined;
        self._allocator.destroy(self);
    }

    fn closeCallback() void {
        ui.current_screen.in_game.screen_controller.hideScreens();
    }
    fn nextCallback() void {
        current_page += 1;

        if (current_page == max_pages)
            current_page = 9;

        ui.current_screen.in_game.screen_controller.vault.updatePageText();
    }
    fn prevCallback() void {
        current_page -= 1;

        if (current_page == 0)
            current_page = 1;

        ui.current_screen.in_game.screen_controller.vault.updatePageText();
    }

    fn updatePageText(_: *VaultScreen) void {
        //idk update page number somehow
        //self.number_text.text = current_page?
    }

    pub fn resize(self: *VaultScreen, w: f32, h: f32) void {
        var x = w + pre_width_x;
        var y = h + pre_height_y;

        self.cont.x = x;
        self.cont.y = y;
    }
};
