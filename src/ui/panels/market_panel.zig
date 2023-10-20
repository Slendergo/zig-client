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
const ScreenController = @import("../controllers/screen_controller.zig").ScreenController;
const NineSlice = ui.NineSliceImageData;

pub const MarketPanel = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,
    visible: bool = false,
    cont: *ui.DisplayContainer = undefined,
    item_cont: *ui.DisplayContainer = undefined,
    items: std.ArrayList(*ui.Item) = undefined,

    pub fn init(allocator: std.mem.Allocator, data: MarketPanel) !*MarketPanel {
        var screen = try allocator.create(MarketPanel);
        screen.* = .{ ._allocator = allocator };
        screen.* = data;

        var width: f32 = camera.screen_width;
        var height: f32 = camera.screen_height;
        var half_width: f32 = width / 2;
        var half_height: f32 = height / 2;

        var valid_items_count: usize = 0;

        var item_iter = game_data.item_type_to_props.iterator();

        while (item_iter.next()) |entry| {
            var props = @as(game_data.ItemProps, entry.value_ptr.*);

            if (props.consumable)
                continue;

            //how tf do i strcmp in zig
            //if(props.tier != "UT")
            //  continue;

            valid_items_count += 1;
        }

        const container_data = assets.getUiData("containerView", 0);
        screen.cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 0,
            .visible = false,
        });

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        var actual_width = container_data.texWRaw() - 10;
        var actual_height = container_data.texHRaw() - 10;

        _ = try screen.cont.createElement(ui.Button, .{
            .x = half_width,
            .y = half_height,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Close"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = closeCallback,
        });

        item_iter = game_data.item_type_to_props.iterator();
        screen.items = std.ArrayList(*ui.Item).init(allocator);
        try screen.items.ensureTotalCapacity(valid_items_count);

        var x_pos: f32 = -40;
        var y_pos: f32 = -40;
        const x_increase = 45;
        const y_increase = 45;
        const items_per_row = 8;
        var counter: f32 = 0;

        screen.item_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
            .draggable = true,
            .visible = false,
            ._clamp_x = true,
            ._clamp_to_screen = true,
        });

        const bg_img = try screen.item_cont.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .visible = true,
            .image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 200, camera.screen_height, 6, 6, 7, 7, 1.0) },
        });

        while (item_iter.next()) |entry| {
            var item_type = @as(u16, entry.key_ptr.*);
            var props = @as(game_data.ItemProps, entry.value_ptr.*);

            if (props.consumable)
                continue;

            //how tf do i strcmp in zig
            //if(props.tier != "UT")
            //  continue;
            if (assets.ui_atlas_data.get(props.texture_data.sheet)) |ss_data| {
                if (@mod(counter, items_per_row) == 0) {
                    y_pos += y_increase;
                    x_pos = -40;
                } else {
                    x_pos += x_increase;
                }

                const item = try screen.item_cont.createElement(ui.Item, .{
                    .x = x_pos + (assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
                    .y = y_pos + (assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
                    .image_data = .{ .normal = .{ .scale_x = 4.0, .scale_y = 4.0, .atlas_data = ss_data[props.texture_data.index] } },
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
                    ._item = item_type,
                    .visible = true,
                    .draggable = false,
                    .drag_end_callback = itemCallback,
                    .double_click_callback = itemCallback,
                    .shift_click_callback = itemCallback,
                });

                screen.item_cont.width = @max(screen.item_cont.width, item.x + 20);
                screen.item_cont.height = @max(screen.item_cont.height, item.y + 20);
                screen.items.append(item) catch return screen;
                counter += 1;
            }
        }

        bg_img.image_data.nine_slice.w = screen.item_cont.width;
        bg_img.image_data.nine_slice.h = screen.item_cont.height;
        std.log.info("Market Init successful", .{});

        screen.inited = true;
        return screen;
    }

    fn itemCallback(_: *ui.Item) void {}

    pub fn setVisible(self: *MarketPanel, val: bool) void {
        self.cont.visible = val;
    }

    pub fn deinit(self: *MarketPanel) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.cont.destroy();

        self._allocator.destroy(self);
    }

    fn closeCallback() void {
        ui.current_screen.game.screen_controller.hideScreens();
    }

    pub fn resize(_: *MarketPanel, _: f32, _: f32) void {}
};
