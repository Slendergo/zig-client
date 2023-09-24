const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const network = @import("../network.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");
const game_data = @import("../game_data.zig");
const map = @import("../map.zig");
const input = @import("../input.zig");

pub const InGameScreen = struct {
    pub const Slot = struct {
        idx: u8,
        is_container: bool = false,

        fn findInvSlotId(screen: InGameScreen, x: f32, y: f32) u8 {
            for (0..20) |i| {
                const data = screen.inventory_pos_data[i];
                if (utils.isInBounds(
                    x,
                    y,
                    screen.inventory_decor.x + data.x - data.w_pad,
                    screen.inventory_decor.y + data.y - data.h_pad,
                    data.w + data.w_pad * 2,
                    data.h + data.h_pad * 2,
                )) {
                    return @intCast(i);
                }
            }

            return 255;
        }

        fn findContainerSlotId(screen: InGameScreen, x: f32, y: f32) u8 {
            if (!ui.in_game_screen.container_visible)
                return 255;

            for (0..8) |i| {
                const data = screen.container_pos_data[i];
                if (utils.isInBounds(
                    x,
                    y,
                    screen.container_decor.x + data.x - data.w_pad,
                    screen.container_decor.y + data.y - data.h_pad,
                    data.w + data.w_pad * 2,
                    data.h + data.h_pad * 2,
                )) {
                    return @intCast(i);
                }
            }

            return 255;
        }

        pub fn findSlotId(screen: InGameScreen, x: f32, y: f32) Slot {
            const inv_slot = findInvSlotId(screen, x, y);
            if (inv_slot != 255) {
                return Slot{ .idx = inv_slot };
            }

            const container_slot = findContainerSlotId(screen, x, y);
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

        pub fn nextAvailableSlot(screen: InGameScreen) Slot {
            for (0..20) |idx| {
                if (screen.inventory_items[idx]._item == -1)
                    return Slot{ .idx = @intCast(idx) };
            }
            return Slot{ .idx = 255 };
        }
    };

    last_level: i32 = -1,
    last_xp: i32 = -1,
    last_xp_goal: i32 = -1,
    last_fame: i32 = -1,
    last_fame_goal: i32 = -1,
    last_hp: i32 = -1,
    last_max_hp: i32 = -1,
    last_mp: i32 = -1,
    last_max_mp: i32 = -1,
    container_visible: bool = false,
    container_id: i32 = -1,

    fps_text: *ui.UiText = undefined,
    chat_input: *ui.InputField = undefined,
    chat_decor: *ui.Image = undefined,
    bars_decor: *ui.Image = undefined,
    stats_button: *ui.Button = undefined,
    level_text: *ui.UiText = undefined,
    xp_bar: *ui.Bar = undefined,
    fame_bar: *ui.Bar = undefined,
    health_bar: *ui.Bar = undefined,
    mana_bar: *ui.Bar = undefined,
    inventory_decor: *ui.Image = undefined,
    inventory_items: [20]*ui.Item = undefined,
    health_potion: *ui.Image = undefined,
    health_potion_text: *ui.UiText = undefined,
    magic_potion: *ui.Image = undefined,
    magic_potion_text: *ui.UiText = undefined,
    container_decor: *ui.Image = undefined,
    container_name: *ui.UiText = undefined,
    container_items: [8]*ui.Item = undefined,
    minimap_decor: *ui.Image = undefined,

    inventory_pos_data: [20]utils.Rect = undefined,
    container_pos_data: [8]utils.Rect = undefined,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !InGameScreen {
        var screen = InGameScreen{
            ._allocator = allocator,
        };

        screen.parseItemRects();

        screen.minimap_decor = try allocator.create(ui.Image);
        const minimap_data = assets.getUi("minimap", 0);
        screen.minimap_decor.* = ui.Image{
            .x = camera.screen_width - minimap_data.texWRaw() - 10,
            .y = 10,
            .image_data = .{ .normal = .{ .atlas_data = minimap_data } },
            .is_minimap_decor = true,
            .minimap_offset_x = 7.0,
            .minimap_offset_y = 10.0,
            .minimap_width = 172.0,
            .minimap_height = 172.0,
        };
        try ui.elements.add(.{ .image = screen.minimap_decor });

        screen.inventory_decor = try allocator.create(ui.Image);
        const inventory_data = assets.getUi("playerInventory", 0);
        screen.inventory_decor.* = ui.Image{
            .x = camera.screen_width - inventory_data.texWRaw() - 10,
            .y = camera.screen_height - inventory_data.texHRaw() - 10,
            .image_data = .{ .normal = .{ .atlas_data = inventory_data } },
        };
        try ui.elements.add(.{ .image = screen.inventory_decor });

        for (0..20) |i| {
            screen.inventory_items[i] = try allocator.create(ui.Item);
            screen.inventory_items[i].* = ui.Item{
                .x = screen.inventory_decor.x + screen.inventory_pos_data[i].x + (screen.inventory_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
                .y = screen.inventory_decor.y + screen.inventory_pos_data[i].y + (screen.inventory_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
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
            try ui.elements.add(.{ .item = screen.inventory_items[i] });
        }

        screen.container_decor = try allocator.create(ui.Image);
        const container_data = assets.getUi("containerView", 0);
        screen.container_decor.* = ui.Image{
            .x = screen.inventory_decor.x - container_data.texWRaw() - 10,
            .y = camera.screen_height - container_data.texHRaw() - 10,
            .image_data = .{ .normal = .{ .atlas_data = container_data } },
            .visible = false,
        };
        try ui.elements.add(.{ .image = screen.container_decor });

        for (0..8) |i| {
            screen.container_items[i] = try allocator.create(ui.Item);
            screen.container_items[i].* = ui.Item{
                .x = screen.container_decor.x + screen.container_pos_data[i].x + (screen.container_pos_data[i].w - assets.ui_error_data.texWRaw() * 4.0 + assets.padding * 2) / 2,
                .y = screen.container_decor.y + screen.container_pos_data[i].y + (screen.container_pos_data[i].h - assets.ui_error_data.texHRaw() * 4.0 + assets.padding * 2) / 2,
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
            try ui.elements.add(.{ .item = screen.container_items[i] });
        }

        screen.bars_decor = try allocator.create(ui.Image);
        const bars_data = assets.getUi("playerStatusBarsDecor", 0);
        screen.bars_decor.* = ui.Image{
            .x = (camera.screen_width - bars_data.texWRaw()) / 2,
            .y = camera.screen_height - bars_data.texHRaw() - 10,
            .image_data = .{ .normal = .{ .atlas_data = bars_data } },
        };
        try ui.elements.add(.{ .image = screen.bars_decor });

        screen.stats_button = try allocator.create(ui.Button);
        const stats_data = assets.getUi("playerStatusBarStatIcon", 0);
        screen.stats_button.* = ui.Button{
            .x = screen.bars_decor.x + 7,
            .y = screen.bars_decor.y + 8,
            .base_image_data = .{ .normal = .{ .atlas_data = stats_data } },
            .press_callback = statsCallback,
        };
        try ui.elements.add(.{ .button = screen.stats_button });

        screen.level_text = try allocator.create(ui.UiText);
        const level_text_data = ui.TextData{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
            .max_width = 24,
            .max_height = 24,
            .vert_align = .middle,
            .hori_align = .middle,
        };
        screen.level_text.* = ui.UiText{
            .x = screen.bars_decor.x + 178,
            .y = screen.bars_decor.y + 9,
            .text_data = level_text_data,
        };
        try ui.elements.add(.{ .text = screen.level_text });

        screen.xp_bar = try allocator.create(ui.Bar);
        const xp_bar_data = assets.getUi("playerStatusBarXp", 0);
        screen.xp_bar.* = ui.Bar{
            .x = screen.bars_decor.x + 42,
            .y = screen.bars_decor.y + 12,
            .image_data = .{ .normal = .{ .atlas_data = xp_bar_data } },
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold_italic,
                .backing_buffer = try allocator.alloc(u8, 64),
            },
        };
        try ui.elements.add(.{ .bar = screen.xp_bar });

        screen.fame_bar = try allocator.create(ui.Bar);
        const fame_bar_data = assets.getUi("playerStatusBarFame", 0);
        screen.fame_bar.* = ui.Bar{
            .x = screen.bars_decor.x + 42,
            .y = screen.bars_decor.y + 12,
            .image_data = .{ .normal = .{ .atlas_data = fame_bar_data } },
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold_italic,
                .backing_buffer = try allocator.alloc(u8, 64),
            },
        };
        try ui.elements.add(.{ .bar = screen.fame_bar });

        screen.health_bar = try allocator.create(ui.Bar);
        const health_bar_data = assets.getUi("playerStatusBarHealth", 0);
        screen.health_bar.* = ui.Bar{
            .x = screen.bars_decor.x + 8,
            .y = screen.bars_decor.y + 47,
            .image_data = .{ .normal = .{ .atlas_data = health_bar_data } },
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold_italic,
                .backing_buffer = try allocator.alloc(u8, 32),
            },
        };
        try ui.elements.add(.{ .bar = screen.health_bar });

        screen.mana_bar = try allocator.create(ui.Bar);
        const mana_bar_data = assets.getUi("playerStatusBarMana", 0);
        screen.mana_bar.* = ui.Bar{
            .x = screen.bars_decor.x + 8,
            .y = screen.bars_decor.y + 73,
            .image_data = .{ .normal = .{ .atlas_data = mana_bar_data } },
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold_italic,
                .backing_buffer = try allocator.alloc(u8, 32),
            },
        };
        try ui.elements.add(.{ .bar = screen.mana_bar });

        screen.chat_decor = try allocator.create(ui.Image);
        const chat_data = assets.getUi("chatboxBackground", 0);
        const input_data = assets.getUi("chatboxInput", 0);
        screen.chat_decor.* = ui.Image{
            .x = 10,
            .y = camera.screen_height - chat_data.texHRaw() - input_data.texHRaw() - 10,
            .image_data = .{ .normal = .{ .atlas_data = chat_data } },
        };
        try ui.elements.add(.{ .image = screen.chat_decor });

        screen.chat_input = try allocator.create(ui.InputField);
        screen.chat_input.* = ui.InputField{
            .x = screen.chat_decor.x,
            .y = screen.chat_decor.y + screen.chat_decor.height(),
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .normal = .{ .atlas_data = input_data } },
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 256),
                .handle_special_chars = false,
            },
            .allocator = allocator,
            .enter_callback = chatCallback,
            .allow_chat_history = true,
        };
        try ui.elements.add(.{ .input_field = screen.chat_input });

        screen.fps_text = try allocator.create(ui.UiText);
        const fps_text_data = ui.TextData{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        };
        screen.fps_text.* = ui.UiText{
            .x = camera.screen_width - fps_text_data.width() - 10,
            .y = screen.minimap_decor.y + screen.minimap_decor.height() + 10,
            .text_data = fps_text_data,
        };
        try ui.elements.add(.{ .text = screen.fps_text });

        return screen;
    }

    pub fn deinit(self: *InGameScreen, allocator: std.mem.Allocator) void {
        allocator.destroy(self.minimap_decor);
        allocator.destroy(self.inventory_decor);
        allocator.destroy(self.container_decor);
        allocator.destroy(self.bars_decor);
        allocator.destroy(self.stats_button);
        allocator.destroy(self.level_text);
        allocator.destroy(self.xp_bar);
        allocator.destroy(self.fame_bar);
        allocator.destroy(self.health_bar);
        allocator.destroy(self.mana_bar);
        allocator.destroy(self.chat_decor);
        allocator.destroy(self.chat_input);
        allocator.destroy(self.fps_text);

        for (self.inventory_items) |item| {
            allocator.destroy(item);
        }

        for (self.container_items) |item| {
            allocator.destroy(item);
        }
    }

    pub fn toggle(self: *InGameScreen, state: bool) void {
        self.last_level = -1;
        self.last_xp = -1;
        self.last_xp_goal = -1;
        self.last_fame = -1;
        self.last_fame_goal = -1;
        self.last_hp = -1;
        self.last_max_hp = -1;
        self.last_mp = -1;
        self.last_max_mp = -1;
        self.container_visible = false;
        self.container_id = -1;

        self.fps_text.visible = state;
        self.chat_input.visible = state;
        self.chat_decor.visible = state;
        self.bars_decor.visible = state;
        self.stats_button.visible = state;
        self.level_text.visible = state;
        self.xp_bar.visible = state;
        self.fame_bar.visible = state;
        self.health_bar.visible = state;
        self.mana_bar.visible = state;
        self.inventory_decor.visible = state;
        for (&self.inventory_items) |item| {
            item.visible = if (item._item == -1) false else state;
        }
        // self.health_potion.visible = state;
        // self.health_potion_text.visible = state;
        // self.magic_potion.visible = state;
        // self.magic_potion_text.visible = state;
        self.container_decor.visible = state;
        // self.container_name.visible = state;
        for (&self.container_items) |item| {
            item.visible = if (item._item == -1) false else state;
        }
        self.minimap_decor.visible = state;
    }

    pub fn resize(self: *InGameScreen, w: f32, h: f32) void {
        self.minimap_decor.x = w - self.minimap_decor.width() - 10;
        self.inventory_decor.x = w - self.inventory_decor.width() - 10;
        self.inventory_decor.y = h - self.inventory_decor.height() - 10;
        self.container_decor.x = self.inventory_decor.x - self.container_decor.width() - 10;
        self.container_decor.y = h - self.container_decor.height() - 10;
        self.bars_decor.x = (w - self.bars_decor.width()) / 2;
        self.bars_decor.y = h - self.bars_decor.height() - 10;
        self.stats_button.x = self.bars_decor.x + 7;
        self.stats_button.y = self.bars_decor.y + 8;
        self.level_text.x = self.bars_decor.x + 178;
        self.level_text.y = self.bars_decor.y + 9;
        self.xp_bar.x = self.bars_decor.x + 42;
        self.xp_bar.y = self.bars_decor.y + 12;
        self.fame_bar.x = self.bars_decor.x + 42;
        self.fame_bar.y = self.bars_decor.y + 12;
        self.health_bar.x = self.bars_decor.x + 8;
        self.health_bar.y = self.bars_decor.y + 47;
        self.mana_bar.x = self.bars_decor.x + 8;
        self.mana_bar.y = self.bars_decor.y + 73;
        const chat_decor_h = self.chat_decor.height();
        self.chat_decor.y = h - chat_decor_h - self.chat_input.imageData().normal.height() - 10;
        self.chat_input.y = self.chat_decor.y + chat_decor_h;
        self.fps_text.y = self.minimap_decor.y + self.minimap_decor.height() + 10;

        for (0..20) |idx| {
            self.inventory_items[idx].x = self.inventory_decor.x + ui.in_game_screen.inventory_pos_data[idx].x + (ui.in_game_screen.inventory_pos_data[idx].w - self.inventory_items[idx].width() + assets.padding * 2) / 2;
            self.inventory_items[idx].y = self.inventory_decor.y + ui.in_game_screen.inventory_pos_data[idx].y + (ui.in_game_screen.inventory_pos_data[idx].h - self.inventory_items[idx].height() + assets.padding * 2) / 2;
        }

        for (0..8) |idx| {
            self.container_items[idx].x = self.container_decor.x + ui.in_game_screen.container_pos_data[idx].x + (ui.in_game_screen.container_pos_data[idx].w - self.container_items[idx].width() + assets.padding * 2) / 2;
            self.container_items[idx].y = self.container_decor.y + ui.in_game_screen.container_pos_data[idx].y + (ui.in_game_screen.container_pos_data[idx].h - self.container_items[idx].height() + assets.padding * 2) / 2;
        }
    }

    pub fn update(self: *InGameScreen, ms_time: i64, ms_dt: f32) !void {
        _ = ms_dt;
        _ = ms_time;
        if (map.localPlayerConst()) |local_player| {
            if (self.last_level != local_player.level) {
                self.level_text.text_data.text = try std.fmt.bufPrint(self.level_text.text_data.backing_buffer, "{d}", .{local_player.level});

                self.last_level = local_player.level;
            }

            const max_level = local_player.level >= 20;
            if (max_level) {
                if (self.last_fame != local_player.fame or self.last_fame_goal != local_player.fame_goal) {
                    self.fame_bar.visible = true;
                    self.xp_bar.visible = false;
                    const fame_perc = @as(f32, @floatFromInt(local_player.fame)) / @as(f32, @floatFromInt(local_player.fame_goal));
                    self.fame_bar.max_width = self.fame_bar.width() * fame_perc;
                    self.fame_bar.text_data.text = try std.fmt.bufPrint(self.fame_bar.text_data.backing_buffer, "{d}/{d} Fame", .{ local_player.fame, local_player.fame_goal });

                    self.last_fame = local_player.fame;
                    self.last_fame_goal = local_player.fame_goal;
                }
            } else {
                if (self.last_xp != local_player.exp or self.last_xp_goal != local_player.exp_goal) {
                    self.xp_bar.visible = true;
                    self.fame_bar.visible = false;
                    const exp_perc = @as(f32, @floatFromInt(local_player.exp)) / @as(f32, @floatFromInt(local_player.exp_goal));
                    self.xp_bar.max_width = self.xp_bar.width() * exp_perc;
                    self.xp_bar.text_data.text = try std.fmt.bufPrint(self.xp_bar.text_data.backing_buffer, "{d}/{d} XP", .{ local_player.exp, local_player.exp_goal });

                    self.last_xp = local_player.exp;
                    self.last_xp_goal = local_player.exp_goal;
                }
            }

            if (self.last_hp != local_player.hp or self.last_max_hp != local_player.max_hp) {
                const hp_perc = @as(f32, @floatFromInt(local_player.hp)) / @as(f32, @floatFromInt(local_player.max_hp));
                self.health_bar.max_width = self.health_bar.width() * hp_perc;
                self.health_bar.text_data.text = try std.fmt.bufPrint(self.health_bar.text_data.backing_buffer, "{d}/{d} HP", .{ local_player.hp, local_player.max_hp });

                self.last_hp = local_player.hp;
                self.last_max_hp = local_player.max_hp;
            }

            if (self.last_mp != local_player.mp or self.last_max_mp != local_player.max_mp) {
                const mp_perc = @as(f32, @floatFromInt(local_player.mp)) / @as(f32, @floatFromInt(local_player.max_mp));
                self.mana_bar.max_width = self.mana_bar.width() * mp_perc;
                self.mana_bar.text_data.text = try std.fmt.bufPrint(self.mana_bar.text_data.backing_buffer, "{d}/{d} MP", .{ local_player.mp, local_player.max_mp });

                self.last_mp = local_player.mp;
                self.last_max_mp = local_player.max_mp;
            }
        }
    }

    pub fn updateFpsText(self: *InGameScreen, fps: f64, mem: f32) !void {
        self.fps_text.text_data.text = try std.fmt.bufPrint(self.fps_text.text_data.backing_buffer, "FPS: {d:.1}\nMemory: {d:.1} MB", .{ fps, mem });
        self.fps_text.x = camera.screen_width - self.fps_text.text_data.width() - 10;
    }

    fn parseItemRects(self: *InGameScreen) void {
        for (0..20) |i| {
            const hori_idx: f32 = @floatFromInt(@mod(i, 4));
            const vert_idx: f32 = @floatFromInt(@divFloor(i, 4));
            if (i < 4) {
                self.inventory_pos_data[i] = utils.Rect{
                    .x = 5 + hori_idx * 44,
                    .y = 8,
                    .w = 40,
                    .h = 40,
                    .w_pad = 2,
                    .h_pad = 13,
                };
            } else {
                self.inventory_pos_data[i] = utils.Rect{
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
            self.container_pos_data[i] = utils.Rect{
                .x = 5 + hori_idx * 44,
                .y = 8 + vert_idx * 44,
                .w = 40,
                .h = 40,
                .w_pad = 2,
                .h_pad = 2,
            };
        }
    }

    fn swapSlots(self: *InGameScreen, start_slot: Slot, end_slot: Slot) void {
        const int_id = map.interactive_id.load(.Acquire);

        if (end_slot.idx == 255) {
            if (start_slot.is_container) {
                self.setContainerItem(-1, start_slot.idx);
                network.queuePacket(.{ .inv_drop = .{ .slot_object = .{
                    .object_id = int_id,
                    .slot_id = start_slot.idx,
                    .object_type = self.container_items[start_slot.idx]._item,
                } } });
            } else {
                self.setInvItem(-1, start_slot.idx);
                network.queuePacket(.{ .inv_drop = .{ .slot_object = .{
                    .object_id = map.local_player_id,
                    .slot_id = start_slot.idx,
                    .object_type = self.inventory_items[start_slot.idx]._item,
                } } });
            }
        } else {
            while (!map.object_lock.tryLockShared()) {}
            defer map.object_lock.unlockShared();

            if (map.localPlayerConst()) |local_player| {
                const start_item = if (start_slot.is_container)
                    self.container_items[start_slot.idx]._item
                else
                    self.inventory_items[start_slot.idx]._item;

                if (end_slot.idx >= 12 and !local_player.has_backpack) {
                    if (start_slot.is_container) {
                        self.setContainerItem(start_item, start_slot.idx);
                    } else {
                        self.setInvItem(start_item, start_slot.idx);
                    }

                    assets.playSfx("error");
                    return;
                }

                const end_item = if (end_slot.is_container)
                    self.container_items[end_slot.idx]._item
                else
                    self.inventory_items[end_slot.idx]._item;

                if (start_slot.is_container) {
                    self.setContainerItem(end_item, start_slot.idx);
                } else {
                    self.setInvItem(end_item, start_slot.idx);
                }

                if (end_slot.is_container) {
                    self.setContainerItem(start_item, end_slot.idx);
                } else {
                    self.setInvItem(start_item, end_slot.idx);
                }

                network.queuePacket(.{ .inv_swap = .{
                    .time = main.current_time,
                    .position = .{ .x = local_player.x, .y = local_player.y },
                    .from_slot = .{
                        .object_id = if (start_slot.is_container) int_id else map.local_player_id,
                        .slot_id = start_slot.idx,
                        .object_type = start_item,
                    },
                    .to_slot = .{
                        .object_id = if (end_slot.is_container) int_id else map.local_player_id,
                        .slot_id = end_slot.idx,
                        .object_type = end_item,
                    },
                } });

                assets.playSfx("inventory_move_item");
            }
        }
    }

    fn itemDoubleClickCallback(item: *ui.Item) void {
        if (item._item < 0)
            return;

        const start_slot = Slot.findSlotId(ui.in_game_screen, item.x + 4, item.y + 4);
        if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
            if (props.consumable and !start_slot.is_container) {
                while (!map.object_lock.tryLockShared()) {}
                defer map.object_lock.unlockShared();

                if (map.localPlayerConst()) |local_player| {
                    network.queuePacket(.{ .use_item = .{
                        .slot_object = .{
                            .object_id = map.local_player_id,
                            .slot_id = start_slot.idx,
                            .object_type = item._item,
                        },
                        .use_position = .{ .x = local_player.x, .y = local_player.y },
                        .time = main.current_time,
                        .use_type = game_data.UseType.default,
                    } });
                    assets.playSfx("use_potion");
                }

                return;
            }
        }

        if (start_slot.is_container) {
            const end_slot = Slot.nextAvailableSlot(ui.in_game_screen);
            if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
                item.x = item._drag_start_x;
                item.y = item._drag_start_y;
                return;
            }

            ui.in_game_screen.swapSlots(start_slot, end_slot);
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

                    ui.in_game_screen.swapSlots(start_slot, end_slot);
                }
            }
        }
    }

    fn statsCallback() void {
        std.log.debug("stats pressed", .{});
    }

    fn chatCallback(input_text: []u8) void {
        if (input_text.len > 0) {
            network.queuePacket(.{ .player_text = .{ .text = input_text } });

            const msg_d = ui.in_game_screen._allocator.dupe(u8, input_text) catch unreachable;
            input.input_history.append(msg_d) catch unreachable;
            input.input_history_idx = @intCast(input.input_history.items.len);
        }
    }

    fn itemDragEndCallback(item: *ui.Item) void {
        const start_slot = Slot.findSlotId(ui.in_game_screen, item._drag_start_x + 4, item._drag_start_y + 4);
        const end_slot = Slot.findSlotId(ui.in_game_screen, item.x - item._drag_offset_x, item.y - item._drag_offset_y);
        if (start_slot.idx == end_slot.idx and start_slot.is_container == end_slot.is_container) {
            item.x = item._drag_start_x;
            item.y = item._drag_start_y;
            return;
        }

        ui.in_game_screen.swapSlots(start_slot, end_slot);
    }

    fn itemShiftClickCallback(item: *ui.Item) void {
        if (item._item < 0)
            return;

        const slot = Slot.findSlotId(ui.in_game_screen, item.x + 4, item.y + 4);

        if (game_data.item_type_to_props.get(@intCast(item._item))) |props| {
            if (props.consumable) {
                while (!map.object_lock.tryLockShared()) {}
                defer map.object_lock.unlockShared();

                if (map.localPlayerConst()) |local_player| {
                    network.queuePacket(.{ .use_item = .{
                        .slot_object = .{
                            .object_id = if (slot.is_container) ui.in_game_screen.container_id else map.local_player_id,
                            .slot_id = slot.idx,
                            .object_type = item._item,
                        },
                        .use_position = .{ .x = local_player.x, .y = local_player.y },
                        .time = main.current_time,
                        .use_type = game_data.UseType.default,
                    } });
                    assets.playSfx("use_potion");
                }

                return;
            }
        }
    }

    pub fn useItem(self: *InGameScreen, idx: u8) void {
        itemDoubleClickCallback(self.inventory_items[idx]);
    }

    pub fn setContainerItem(self: *InGameScreen, item: i32, idx: u8) void {
        if (item == -1) {
            self.container_items[idx]._item = -1;
            self.container_items[idx].visible = false;
            return;
        }

        self.container_items[idx].visible = true;

        if (game_data.item_type_to_props.get(@intCast(item))) |props| {
            if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
                const atlas_data = data[props.texture_data.index];
                const base_x = self.container_decor.x + self.container_pos_data[idx].x;
                const base_y = self.container_decor.y + self.container_pos_data[idx].y;
                const pos_w = self.container_pos_data[idx].w;
                const pos_h = self.container_pos_data[idx].h;

                self.container_items[idx]._item = item;
                self.container_items[idx].image_data.normal.atlas_data = atlas_data;
                self.container_items[idx].x = base_x + (pos_w - self.container_items[idx].width() + assets.padding * 2) / 2;
                self.container_items[idx].y = base_y + (pos_h - self.container_items[idx].height() + assets.padding * 2) / 2;

                if (self.container_items[idx].tier_text) |*tier_text| {
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
        self.container_items[idx]._item = -1;
        self.container_items[idx].image_data.normal.atlas_data = atlas_data;
        self.container_items[idx].x = self.container_decor.x + self.container_pos_data[idx].x + (self.container_pos_data[idx].w - self.container_items[idx].width() + assets.padding * 2) / 2;
        self.container_items[idx].y = self.container_decor.y + self.container_pos_data[idx].y + (self.container_pos_data[idx].h - self.container_items[idx].height() + assets.padding * 2) / 2;
    }

    pub fn setInvItem(self: *InGameScreen, item: i32, idx: u8) void {
        if (item == -1) {
            self.inventory_items[idx]._item = -1;
            self.inventory_items[idx].visible = false;
            return;
        }

        self.inventory_items[idx].visible = true;

        if (game_data.item_type_to_props.get(@intCast(item))) |props| {
            if (assets.ui_atlas_data.get(props.texture_data.sheet)) |data| {
                const atlas_data = data[props.texture_data.index];
                const base_x = self.inventory_decor.x + self.inventory_pos_data[idx].x;
                const base_y = self.inventory_decor.y + self.inventory_pos_data[idx].y;
                const pos_w = self.inventory_pos_data[idx].w;
                const pos_h = self.inventory_pos_data[idx].h;

                self.inventory_items[idx]._item = item;
                self.inventory_items[idx].image_data.normal.atlas_data = atlas_data;
                self.inventory_items[idx].x = base_x + (pos_w - self.inventory_items[idx].width() + assets.padding * 2) / 2;
                self.inventory_items[idx].y = base_y + (pos_h - self.inventory_items[idx].height() + assets.padding * 2) / 2;

                if (self.inventory_items[idx].tier_text) |*tier_text| {
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
        self.inventory_items[idx]._item = -1;
        self.inventory_items[idx].image_data.normal.atlas_data = atlas_data;
        self.inventory_items[idx].x = self.inventory_decor.x + self.inventory_pos_data[idx].x + (self.inventory_pos_data[idx].w - self.inventory_items[idx].width() + assets.padding * 2) / 2;
        self.inventory_items[idx].y = self.inventory_decor.y + self.inventory_pos_data[idx].y + (self.inventory_pos_data[idx].h - self.inventory_items[idx].height() + assets.padding * 2) / 2;
    }

    pub inline fn setContainerVisible(self: *InGameScreen, visible: bool) void {
        self.container_visible = visible;
        self.container_decor.visible = visible;
    }
};
