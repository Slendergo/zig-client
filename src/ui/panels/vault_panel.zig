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
const GameScreen = @import("../screens/game_screen.zig").GameScreen;
const NineSlice = ui.NineSliceImageData;

var pre_width_x: f32 = 0;
var pre_height_y: f32 = 0;
var current_page: u8 = 1;
var max_pages: u8 = 9;

const items_per_page = rows_per_page * items_per_row;
const rows_per_page = 10;
const items_per_row = 8;
pub var vault_obj_id: i32 = -1;

pub const VaultPanel = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,
    visible: bool = false,
    cont: *ui.DisplayContainer = undefined,
    number_text: *ui.UiText = undefined,
    items: [items_per_page]*ui.Item = undefined,
    inventory_pos_data: [items_per_page]utils.Rect = undefined,

    pub fn init(allocator: std.mem.Allocator, data: VaultPanel) !*VaultPanel {
        var screen = try allocator.create(VaultPanel);
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
        const item_height_offset: f32 = 30;
        const items_height = @min((item_row.texHRaw() * rows_per_page) + 100 + item_height_offset, cam_height);

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
        for (0..rows_per_page) |i| {
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

        screen.parseItemRects(row_x + x, row_y + y);

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

        for (0..items_per_page) |i| {
            screen.items[i] = try ui.Item.create(allocator, .{
                .x = screen.inventory_pos_data[i].x + (screen.inventory_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
                .y = screen.inventory_pos_data[i].y + (screen.inventory_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
                .image_data = .{ .normal = .{ .scale_x = 4.0, .scale_y = 4.0, .atlas_data = assets.ui_error_data } },
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
                .visible = screen.visible,
                .draggable = true,
                .drag_end_callback = itemDragEndCallback,
                .double_click_callback = itemDoubleClickCallback,
                .shift_click_callback = itemShiftClickCallback,
            });

            screen.setVaultItem(0xa3c, @as(u8, @intCast(i)));
        }

        screen.inited = true;
        return screen;
    }

    pub fn setVisible(self: *VaultPanel, val: bool) void {
        self.visible = val;
        self.cont.visible = val;
        for (0..items_per_page) |i| {
            self.items[i].visible = val;
            self.setVaultItem(0xa3c, @as(u8, @intCast(i)));
        }
    }

    pub fn deinit(self: *VaultPanel) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.cont.destroy();
        self.number_text = undefined;

        for (self.items) |item| {
            item.destroy();
        }

        //dealloc rect array?
        //for(self.inventory_pos_data) |item|{
        //  how?
        //
        //}

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
        for (0..items_per_page) |i| {
            ui.current_screen.in_game.screen_controller.vault.setVaultItem(0xa3c, @as(u8, @intCast(i)));
        }
    }
    fn prevCallback() void {
        current_page -= 1;

        if (current_page == 0)
            current_page = 1;

        ui.current_screen.in_game.screen_controller.vault.updatePageText();
        for (0..items_per_page) |i| {
            ui.current_screen.in_game.screen_controller.vault.setVaultItem(0xa83, @as(u8, @intCast(i)));
        }
    }

    fn updatePageText(_: *VaultPanel) void {
        //idk update page number somehow
        //self.number_text.text = current_page?
    }

    pub fn resize(self: *VaultPanel, w: f32, h: f32) void {
        var x = w + pre_width_x;
        var y = h + pre_height_y;

        self.cont.x = x;
        self.cont.y = y;
    }

    fn parseItemRects(self: *VaultPanel, x: f32, y: f32) void {
        for (0..items_per_page) |i| {
            const hori_idx: f32 = @floatFromInt(@mod(i, items_per_row));
            const vert_idx: f32 = @floatFromInt(@divFloor(i, items_per_row));
            self.inventory_pos_data[i] = utils.Rect{
                .x = x + hori_idx * 44,
                .y = y + 44 + (vert_idx - 1) * 44,
                .w = 40,
                .h = 40,
                .w_pad = 2,
                .h_pad = 2,
            };
        }
    }

    pub fn setVaultItem(self: *VaultPanel, item: i32, idx: u8) void {
        if (item == -1) {
            self.items[idx]._item = -1;
            self.items[idx].visible = false;
            return;
        }

        self.items[idx].visible = self.visible;

        if (game_data.item_type_to_props.get(@intCast(item))) |props| {
            if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
                const atlas_data = data[props.texture_data.index];
                const base_x = self.inventory_pos_data[idx].x;
                const base_y = self.inventory_pos_data[idx].y;
                const pos_w = self.inventory_pos_data[idx].w;
                const pos_h = self.inventory_pos_data[idx].h;

                self.items[idx]._item = item;
                self.items[idx].image_data.normal.atlas_data = atlas_data;
                self.items[idx].x = base_x + (pos_w - self.items[idx].width() + assets.padding * 2) / 2;
                self.items[idx].y = base_y + (pos_h - self.items[idx].height() + assets.padding * 2) / 2;

                if (self.items[idx].tier_text) |*tier_text| {
                    if (props.consumable) {
                        tier_text.visible = false;
                    } else {
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
                }

                return;
            } else {
                std.log.err("Could not find ui sheet {s} for item with type 0x{x}, index {d}", .{ props.texture_data.sheet, item, idx });
            }
        } else {
            std.log.err("Attempted to populate inventory index {d} with item 0x{x}, but props was not found", .{ idx, item });
        }

        const atlas_data = assets.ui_error_data;
        self.items[idx]._item = -1;
        self.items[idx].image_data.normal.atlas_data = atlas_data;
        self.items[idx].x = self.inventory_pos_data[idx].x + (self.inventory_pos_data[idx].w - self.items[idx].width() + assets.padding * 2) / 2;
        self.items[idx].y = self.inventory_pos_data[idx].y + (self.inventory_pos_data[idx].h - self.items[idx].height() + assets.padding * 2) / 2;
    }

    fn itemDragEndCallback(item: *ui.Item) void {
        const current_screen = ui.current_screen.in_game.screen_controller.vault;
        const start_slot = findSlotId(current_screen.*, item._drag_start_x + 4, item._drag_start_y + 4);
        const end_slot = findSlotId(current_screen.*, item.x - item._drag_offset_x, item.y - item._drag_offset_y);

        if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
            item.x = item._drag_start_x;
            item.y = item._drag_start_y;
            return;
        }

        current_screen.swapSlots(start_slot, end_slot);
    }

    fn itemDoubleClickCallback(item: *ui.Item) void {
        if (item._item < 0)
            return;

        const start_slot = findSlotId(ui.current_screen.in_game.screen_controller.vault.*, item.x + 4, item.y + 4);
        if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
            if (props.consumable and !start_slot.is_container) {
                while (!map.object_lock.tryLockShared()) {}
                defer map.object_lock.unlockShared();

                if (map.localPlayerConst()) |local_player| {
                    network.queuePacket(.{ .use_item = .{
                        .obj_id = map.local_player_id,
                        .slot_id = start_slot.idx,
                        .obj_type = item._item,
                        .x = local_player.x,
                        .y = local_player.y,
                        .time = main.current_time,
                        .use_type = game_data.UseType.default,
                    } });
                    assets.playSfx("UsePotion");
                }

                return;
            }
        }

        if (start_slot.is_container) {
            const end_slot = nextAvailableSlot(ui.current_screen.in_game.screen_controller.vault.*);
            if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
                item.x = item._drag_start_x;
                item.y = item._drag_start_y;
                return;
            }

            ui.current_screen.in_game.screen_controller.vault.swapSlots(start_slot, end_slot);
        } else {
            if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
                while (!map.object_lock.tryLockShared()) {}
                defer map.object_lock.unlockShared();

                if (map.localPlayerConst()) |local_player| {
                    const end_slot = GameScreen.Slot.nextEquippableSlot(local_player.slot_types, props.slot_type);
                    if (end_slot.idx == 255 or // we don't want to drop
                        start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container)
                    {
                        item.x = item._drag_start_x;
                        item.y = item._drag_start_y;
                        return;
                    }

                    ui.current_screen.in_game.swapSlots(start_slot, end_slot);
                }
            }
        }
    }
    fn itemShiftClickCallback(item: *ui.Item) void {
        if (item._item < 0)
            return;

        const current_screen = ui.current_screen.in_game.screen_controller.vault;
        const slot = findSlotId(current_screen.*, item.x + 4, item.y + 4);

        if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
            if (props.consumable) {
                while (!map.object_lock.tryLockShared()) {}
                defer map.object_lock.unlockShared();

                if (map.localPlayerConst()) |local_player| {
                    network.queuePacket(.{ .use_item = .{
                        .obj_id = if (slot.is_container) vault_obj_id else map.local_player_id,
                        .slot_id = slot.idx,
                        .obj_type = item._item,
                        .x = local_player.x,
                        .y = local_player.y,
                        .time = main.current_time,
                        .use_type = game_data.UseType.default,
                    } });
                    assets.playSfx("UsePotion");
                }

                return;
            }
        }
    }

    pub fn swapSlots(self: *VaultPanel, start_slot: GameScreen.Slot, end_slot: GameScreen.Slot) void {
        const igs = ui.current_screen.in_game;

        if (end_slot.idx == 255) {
            if (start_slot.is_container) {
                self.setVaultItem(-1, start_slot.idx);
                network.queuePacket(.{ .inv_drop = .{
                    .obj_id = vault_obj_id,
                    .slot_id = start_slot.idx,
                    .obj_type = self.items[start_slot.idx]._item,
                } });
            } else {
                igs.setInvItem(-1, start_slot.idx);
                network.queuePacket(.{ .inv_drop = .{
                    .obj_id = map.local_player_id,
                    .slot_id = start_slot.idx,
                    .obj_type = igs.inventory_items[start_slot.idx]._item,
                } });
            }
        } else {
            while (!map.object_lock.tryLockShared()) {}
            defer map.object_lock.unlockShared();

            if (map.localPlayerConst()) |local_player| {
                const start_item = if (start_slot.is_container)
                    self.items[start_slot.idx]._item
                else
                    igs.inventory_items[start_slot.idx]._item;

                if (end_slot.idx >= 12 and !local_player.has_backpack) {
                    if (start_slot.is_container) {
                        self.setVaultItem(start_item, start_slot.idx);
                    } else {
                        //set player item
                        igs.setInvItem(start_item, start_slot.idx);
                    }

                    assets.playSfx("Error");
                    return;
                }

                const end_item = if (end_slot.is_container)
                    self.items[end_slot.idx]._item
                else
                    igs.inventory_items[end_slot.idx]._item;

                if (start_slot.is_container) {
                    self.setVaultItem(end_item, start_slot.idx);
                } else {
                    //set player item
                    igs.setInvItem(end_item, start_slot.idx);
                }

                if (end_slot.is_container) {
                    self.setVaultItem(start_item, end_slot.idx);
                } else {
                    //set player item
                    igs.setInvItem(start_item, end_slot.idx);
                }

                network.queuePacket(.{ .inv_swap = .{
                    .time = main.current_time,
                    .x = local_player.x,
                    .y = local_player.y,
                    .from_obj_id = if (start_slot.is_container) vault_obj_id else map.local_player_id,
                    .from_slot_id = start_slot.idx,
                    .from_obj_type = start_item,
                    .to_obj_id = if (end_slot.is_container) vault_obj_id else map.local_player_id,
                    .to_slot_id = end_slot.idx,
                    .to_obj_type = end_item,
                } });

                assets.playSfx("InventoryMoveItem");
            }
        }
    }
    pub fn nextAvailableSlot(screen: VaultPanel) GameScreen.Slot {
        for (0..items_per_page) |idx| {
            if (screen.items[idx]._item == -1)
                return GameScreen.Slot{ .idx = @intCast(idx) };
        }
        return GameScreen.Slot{ .idx = 255 };
    }

    fn findInvSlotId(screen: VaultPanel, x: f32, y: f32) u8 {
        for (0..items_per_page) |i| {
            const data = screen.inventory_pos_data[i];
            if (utils.isInBounds(
                x,
                y,
                data.x, //- data.w_pad,
                data.y, //- data.h_pad,
                data.w + data.w_pad * 2,
                data.h + data.h_pad * 2,
            )) {
                return @intCast(i);
            }
        }

        return 255;
    }
    pub fn findSlotId(screen: VaultPanel, x: f32, y: f32) GameScreen.Slot {
        const inv_slot = findInvSlotId(screen, x, y);

        if (inv_slot != 255) {
            return GameScreen.Slot{ .idx = inv_slot };
        }

        return GameScreen.Slot{ .idx = 255 };
    }
};
