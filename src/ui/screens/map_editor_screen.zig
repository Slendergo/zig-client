const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const zglfw = @import("zglfw");
const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const main = @import("../../main.zig");
const input = @import("../../input.zig");
const map = @import("../../map.zig");
const ui = @import("../ui.zig");

const sc = @import("../controllers/screen_controller.zig");
const NineSlice = ui.NineSliceImageData;

const button_container_width = 420;
const button_container_height = 190;

const new_container_width = 325;
const new_container_height = 175;

const MapEditorTile = struct {
    object_type: i32 = -1, // some other todo to make this look neater xD
    ground_type: u16 = 0xFFFC, // void tile
    region_type: i32 = -1, // todo make enum struct
};

const EditorAction = enum(u8) { none = 0, place = 1, erase = 2, place_random = 3, erase_random = 4 };

pub const MapEditorScreen = struct {
    _allocator: Allocator,
    inited: bool = false,

    map_size: u32 = 128,
    map_size_64: bool = false,
    map_size_128: bool = true,
    map_size_256: bool = false,
    map_tile_data: []MapEditorTile = &[0]MapEditorTile{},
    action: EditorAction = .none,

    size_text_visual_64: *ui.UiText = undefined,
    size_text_visual_128: *ui.UiText = undefined,
    size_text_visual_256: *ui.UiText = undefined,

    text_statistics: *ui.UiText = undefined,

    new_container: *ui.DisplayContainer = undefined,

    buttons_container: *ui.DisplayContainer = undefined,

    pub fn init(allocator: Allocator) !*MapEditorScreen {
        var screen = try allocator.create(MapEditorScreen);
        screen.* = .{ ._allocator = allocator };

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        const background_data_base = assets.getUiData("textInputBase", 0);

        const check_box_base_on = assets.getUiData("checkedBoxBase", 0);
        const check_box_hover_on = assets.getUiData("checkedBoxHover", 0);
        const check_box_press_on = assets.getUiData("checkedBoxPress", 0);
        const check_box_base_off = assets.getUiData("uncheckedBoxBase", 0);
        const check_box_hover_off = assets.getUiData("uncheckedBoxHover", 0);
        const check_box_press_off = assets.getUiData("uncheckedBoxPress", 0);

        const button_width: f32 = 100;
        const button_height: f32 = 35.0;
        const button_padding: f32 = 10.0;

        screen.text_statistics = try ui.UiText.create(allocator, .{
            .x = 16,
            .y = 16,
            .text_data = .{
                .text = "",
                .size = 12,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 512),
            },
        });

        // buttons container (bottom left)

        screen.buttons_container = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = camera.screen_height - button_container_height,
            .width = button_container_width,
            .height = button_container_height,
        });

        _ = try screen.buttons_container.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .image_data = .{ .nine_slice = NineSlice.fromAtlasData(background_data_base, button_container_width, button_container_height, 8, 8, 32, 32, 1.0) },
        });

        var button_offset: f32 = button_padding;

        _ = try screen.buttons_container.createElement(ui.Button, .{
            .x = button_padding,
            .y = button_offset,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("New"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = newCallback,
        });

        button_offset += button_height + button_padding;

        _ = try screen.buttons_container.createElement(ui.Button, .{
            .x = button_padding,
            .y = button_offset,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Open"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = openCallback,
        });

        button_offset += button_height + button_padding;

        _ = try screen.buttons_container.createElement(ui.Button, .{
            .x = button_padding,
            .y = button_offset,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Save"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = saveCallback,
        });

        button_offset += button_height + button_padding;

        _ = try screen.buttons_container.createElement(ui.Button, .{
            .x = button_padding,
            .y = button_offset,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Exit"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = exitCallback,
        });

        // new container (center)

        screen.new_container = try ui.DisplayContainer.create(allocator, .{
            .x = (camera.screen_width - new_container_width) / 2,
            .y = (camera.screen_height - new_container_height) / 2,
            .width = new_container_width,
            .height = new_container_height,
            .visible = false,
        });

        _ = try screen.new_container.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .image_data = .{ .nine_slice = NineSlice.fromAtlasData(background_data_base, new_container_width, new_container_height, 8, 8, 32, 32, 1.0) },
        });

        var text_size_64: ui.UiText = .{
            .x = new_container_width / 2,
            .y = 32,
            .text_data = .{
                .text = @constCast("64x64"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
            },
            .visible = false,
        };
        text_size_64.x -= text_size_64.text_data.width() / 2;
        text_size_64.y -= text_size_64.text_data.height() / 2;

        var text_size_128: ui.UiText = .{
            .x = new_container_width / 2,
            .y = 32,
            .text_data = .{
                .text = @constCast("128x128"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
            },
            .visible = true,
        };
        text_size_128.x -= text_size_128.text_data.width() / 2;
        text_size_128.y -= text_size_128.text_data.height() / 2;

        var text_size_256: ui.UiText = .{
            .x = new_container_width / 2,
            .y = 32,
            .text_data = .{
                .text = @constCast("256x256"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
            },
            .visible = false,
        };
        text_size_256.x -= text_size_256.text_data.width() / 2;
        text_size_256.y -= text_size_256.text_data.height() / 2;

        const check_padding: f32 = 5;

        const size_64: ui.Toggle = .{
            .x = (new_container_width / 2) - ((check_padding + check_box_base_on.texHRaw()) / 2) * 3,
            .y = (new_container_height - check_box_base_on.texHRaw()) / 2 - check_padding,
            .off_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_off } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_off } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_off } },
            },
            .on_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_on } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_on } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_on } },
            },
            .toggled = &screen.map_size_64,
            .state_change = mapState64Changed,
        };

        const size_128: ui.Toggle = .{
            .x = size_64.x + size_64.width() + 5,
            .y = size_64.y,
            .off_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_off } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_off } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_off } },
            },
            .on_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_on } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_on } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_on } },
            },
            .toggled = &screen.map_size_128,
            .state_change = mapState128Changed,
        };

        const size_256: ui.Toggle = .{
            .x = size_128.x + size_128.width() + 5,
            .y = size_128.y,
            .off_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_off } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_off } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_off } },
            },
            .on_image_data = .{
                .base = .{ .normal = .{ .atlas_data = check_box_base_on } },
                .hover = .{ .normal = .{ .atlas_data = check_box_hover_on } },
                .press = .{ .normal = .{ .atlas_data = check_box_press_on } },
            },
            .toggled = &screen.map_size_256,
            .state_change = mapState256Changed,
        };

        const login_button: ui.Button = .{
            .x = (screen.new_container.width - (button_width * 2)) / 2 - (button_padding / 2),
            .y = (new_container_height - button_height - (button_padding * 2)),
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Create"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = newCreateCallback,
        };

        const cancel_button: ui.Button = .{
            .x = login_button.x + login_button.width() + (button_padding / 2),
            .y = login_button.y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Cancel"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = newCloseCallback,
        };

        screen.size_text_visual_64 = try screen.new_container.createElement(ui.UiText, text_size_64);
        screen.size_text_visual_128 = try screen.new_container.createElement(ui.UiText, text_size_128);
        screen.size_text_visual_256 = try screen.new_container.createElement(ui.UiText, text_size_256);

        _ = try screen.new_container.createElement(ui.Toggle, size_64);
        _ = try screen.new_container.createElement(ui.Toggle, size_128);
        _ = try screen.new_container.createElement(ui.Toggle, size_256);

        _ = try screen.new_container.createElement(ui.Button, login_button);
        _ = try screen.new_container.createElement(ui.Button, cancel_button);

        screen.inited = true;
        return screen;
    }

    fn mapState64Changed(_: *ui.Toggle) void {
        const screen = sc.current_screen.editor;
        screen.size_text_visual_64.visible = true;
        screen.size_text_visual_128.visible = false;
        screen.size_text_visual_256.visible = false;
        screen.map_size_64 = true;
        screen.map_size_128 = false;
        screen.map_size_256 = false;
        screen.map_size = 64;
    }

    fn mapState128Changed(_: *ui.Toggle) void {
        const screen = sc.current_screen.editor;
        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = true;
        screen.size_text_visual_256.visible = false;
        screen.map_size_64 = false;
        screen.map_size_128 = true;
        screen.map_size_256 = false;
        screen.map_size = 128;
    }

    fn mapState256Changed(_: *ui.Toggle) void {
        const screen = sc.current_screen.editor;
        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = false;
        screen.size_text_visual_256.visible = true;
        screen.map_size_64 = false;
        screen.map_size_128 = false;
        screen.map_size_256 = true;
        screen.map_size = 256;
    }

    fn newCallback() void {
        const screen = sc.current_screen.editor;
        screen.new_container.visible = true;
        screen.buttons_container.visible = false;
    }

    fn newCreateCallback() void {
        const screen = sc.current_screen.editor;

        screen.buttons_container.visible = true;
        screen.new_container.visible = false;

        // todo differently

        map.setWH(screen.map_size, screen.map_size, screen._allocator);

        if (screen.map_tile_data.len == 0) {
            screen.map_tile_data = screen._allocator.alloc(MapEditorTile, screen.map_size * screen.map_size) catch return;
        } else {
            screen.map_tile_data = screen._allocator.realloc(screen.map_tile_data, screen.map_size * screen.map_size) catch return;
        }

        map.local_player_id = 0xFFFC; // special editor tile

        const center = @as(f32, @floatFromInt(screen.map_size)) / 2.0 + 0.5;

        // set every tile in map
        // for (0..screen.map_size) |y| {
        //     for (0..screen.map_size) |x| {
        //         const index = y * screen.map_size + x;
        //         const t: u16 = if (((x) + (y)) & 16 == 0) 0x36 else 0x35;
        //         screen.map_tile_data[index] = MapEditorTile{
        //             .ground_type = t,
        //         };
        //         map.setSquare(@as(u32, @intCast(x)), @as(u32, @intCast(y)), t);
        //     }
        // }

        for (0..screen.map_size) |y| {
            for (0..screen.map_size) |x| {
                const index = y * screen.map_size + x;
                screen.map_tile_data[index] = MapEditorTile{};
                map.setSquare(@as(u32, @intCast(x)), @as(u32, @intCast(y)), screen.map_tile_data[index].ground_type);
            }
        }

        // wizard
        var player = map.Player{
            .x = center,
            .y = center,
            .obj_id = map.local_player_id,
            .obj_type = 0x030e,
            .size = 100,
            // .speed = 75,
            .speed = 300,
        };

        player.addToMap(screen._allocator);

        // temp

        // pirate

        var obj = map.GameObject{
            .x = center,
            .y = center,
            .obj_id = 0,
            .obj_type = 0x600,
            .size = 100,
        };

        obj.addToMap(screen._allocator);

        // pirate

        var wall = map.GameObject{
            .x = center + 1,
            .y = center,
            .obj_id = 0,
            .obj_type = 0x01c5,
            // .size = 100,
        };

        wall.addToMap(screen._allocator);

        // end of temp

        main.editing_map = true;

        sc.menu_background.visible = false; // hack
    }

    fn newCloseCallback() void {
        const screen = sc.current_screen.editor;
        screen.reset();
    }

    fn openCallback() void {
        // todo c FileDialog stuff
    }

    fn saveCallback() void {
        // todo c FileDialog stuff
    }

    pub fn exitCallback() void {
        sc.switchScreen(.main_menu);
    }

    fn reset(screen: *MapEditorScreen) void {
        screen.buttons_container.visible = true;
        screen.new_container.visible = false;

        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = true;
        screen.size_text_visual_256.visible = false;

        screen.map_size = 128;
        screen.map_size_64 = false;
        screen.map_size_128 = true;
        screen.map_size_256 = false;

        sc.menu_background.visible = true; // hack
    }

    pub fn deinit(self: *MapEditorScreen) void {
        sc.menu_background.visible = true; // hack
        self.reset();

        self.text_statistics.destroy();
        self.new_container.destroy();
        self.buttons_container.destroy();

        if (self.map_tile_data.len > 0) {
            self._allocator.free(self.map_tile_data);
        }

        if (main.editing_map) {
            main.editing_map = false;
            map.dispose(self._allocator);
        }

        self._allocator.destroy(self);
    }

    pub fn resize(self: *MapEditorScreen, width: f32, height: f32) void {
        self.new_container.x = (width - self.new_container.height) / 2;
        self.new_container.y = (height - self.new_container.height) / 2;
        self.buttons_container.x = 0;
        self.buttons_container.y = height - self.buttons_container.height;
    }

    pub fn onMousePress(self: *MapEditorScreen, x: f64, y: f64, mods: zglfw.Mods, button: zglfw.MouseButton) void {
        _ = y;
        _ = x;
        _ = mods;

        self.action = if (button == .left) .place else if (button == .right) .erase else .none;
    }

    pub fn onMouseRelease(self: *MapEditorScreen, x: f64, y: f64, mods: zglfw.Mods, button: zglfw.MouseButton) void {
        _ = button;
        _ = mods;
        _ = y;
        _ = x;

        self.action = .none;
    }

    fn placeTile(self: *MapEditorScreen, x: u32, y: u32, value: u16) void {
        const index = y * self.map_size + x;
        self.map_tile_data[index].ground_type = value;
        map.setSquare(x, y, value);
    }

    fn removeTile(self: *MapEditorScreen, x: u32, y: u32) void {
        const index = y * self.map_size + x;
        self.map_tile_data[index].ground_type = 0xFFFC;
        map.setSquare(x, y, 0xFFFC);
    }

    pub fn update(self: *MapEditorScreen, time: i64, dt: f32) !void {
        _ = dt;
        _ = time;

        // update statistics

        // todo unwackify it

        const cam_x = camera.x.load(.Acquire);
        const cam_y = camera.y.load(.Acquire);

        const x: f32 = @floatCast(input.mouse_x);
        const y: f32 = @floatCast(input.mouse_y);

        var world_point = camera.screenToWorld(x, y);
        world_point.x = @max(0, @min(world_point.x, @as(f32, @floatFromInt(self.map_size - 1))));
        world_point.y = @max(0, @min(world_point.y, @as(f32, @floatFromInt(self.map_size - 1))));

        const floor_x: u32 = @intFromFloat(@floor(world_point.x));
        const floor_y: u32 = @intFromFloat(@floor(world_point.y));

        switch (self.action) {
            .none => {},
            .place => {
                self.placeTile(floor_x, floor_y, 0x48);
            },
            .erase => {
                self.removeTile(floor_x, floor_y);
            },
            else => {},
        }

        const index = floor_y * self.map_size + floor_x;
        const data = self.map_tile_data[index];

        self.text_statistics.text_data.text = try std.fmt.bufPrint(self.text_statistics.text_data.backing_buffer, "Size: ({d}x{d})\nFloor: ({d}, {d}),\nObject Type: {d}\nGround Type: {d},\nRegion Type: {d}\n\nPosition ({d:.1}, {d:.1}),\nWorld Coordinate ({d:.1}, {d:.1})", .{ self.map_size, self.map_size, floor_x, floor_y, data.object_type, data.ground_type, data.region_type, cam_x, cam_y, world_point.x, world_point.y });
    }
};
