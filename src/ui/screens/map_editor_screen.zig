const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const zglfw = @import("zglfw");
const nfd = @import("nfd");
const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const main = @import("../../main.zig");
const input = @import("../../input.zig");
const utils = @import("../../utils.zig");
const map = @import("../../map.zig");
const ui = @import("../ui.zig");
const game_data = @import("../../game_data.zig");
const settings = @import("../../settings.zig");

const sc = @import("../controllers/screen_controller.zig");
const NineSlice = ui.NineSliceImageData;

const button_container_width = 420;
const button_container_height = 190;

const new_container_width = 345;
const new_container_height = 175;

// 0xFFFF is -1 in unsigned for those who dont know
// 0xFFFC is Editor Specific Empty Tile

const MapEditorTile = struct {
    object_type: u16 = 0xFFFF,
    object_id: i32 = -1, // used to keep track of what entity exists on this tile, used for removing from world on erase
    ground_type: u16 = 0xFFFC, // void tile
    region_type: i32 = -1, // todo make enum struct
};

pub const EditorCommand = union(enum) {
    place_tile: EditorPlaceTileCommand,
    erase_tile: EditorEraseTileCommand,
    place_object: EditorPlaceObjectCommand,
    erase_object: EditorEraseObjectCommand,
};

const EditorAction = enum(u8) {
    none = 0,
    place = 1,
    erase = 2,
    place_random = 3,
    erase_random = 4,
    undo = 5,
    redo = 6,
    sample = 7,
};

const EditorLayer = enum(u8) {
    ground = 0,
    object = 1,
    region = 2,
};

const EditorPlaceTileCommand = struct {
    screen: *MapEditorScreen,
    x: u32,
    y: u32,
    new_type: u16,
    old_type: u16,

    pub fn execute(self: EditorPlaceTileCommand) void {
        self.screen.setTile(self.x, self.y, self.new_type);
    }

    pub fn unexecute(self: EditorPlaceTileCommand) void {
        self.screen.setTile(self.x, self.y, self.old_type);
    }
};

const EditorEraseTileCommand = struct {
    screen: *MapEditorScreen,
    x: u32,
    y: u32,
    old_type: u16,

    pub fn execute(self: EditorEraseTileCommand) void {
        self.screen.setTile(self.x, self.y, 0xFFFC);
    }

    pub fn unexecute(self: EditorEraseTileCommand) void {
        self.screen.setTile(self.x, self.y, self.old_type);
    }
};

const EditorPlaceObjectCommand = struct {
    screen: *MapEditorScreen,
    x: u32,
    y: u32,
    new_type: u16,
    old_type: u16,

    pub fn execute(self: EditorPlaceObjectCommand) void {
        self.screen.setObject(self.x, self.y, self.new_type);
    }

    pub fn unexecute(self: EditorPlaceObjectCommand) void {
        self.screen.setObject(self.x, self.y, self.old_type);
    }
};

const EditorEraseObjectCommand = struct {
    screen: *MapEditorScreen,
    x: u32,
    y: u32,
    old_type: u16,

    pub fn execute(self: EditorEraseObjectCommand) void {
        self.screen.setObject(self.x, self.y, 0xFFFF);
    }

    pub fn unexecute(self: EditorEraseObjectCommand) void {
        self.screen.setObject(self.x, self.y, self.old_type);
    }
};

const CommandQueue = struct {
    command_list: std.ArrayList(EditorCommand) = undefined,
    current_position: u32 = 0,

    pub fn init(self: *CommandQueue, allocator: Allocator) void {
        self.command_list = std.ArrayList(EditorCommand).init(allocator);
    }

    pub fn deinit(self: *CommandQueue) void {
        self.command_list.deinit();
    }

    // might be useful for multiple commands at once tool?
    // otherwise ill just make a command that executes the fill, of more than one object
    pub fn addCommandMultiple(self: *CommandQueue, commands: []EditorCommand) void {
        for (commands) |command| {
            self.addCommand(command);
        }
    }

    pub fn addCommand(self: *CommandQueue, command: EditorCommand) void {
        var i = self.command_list.items.len; // might be a better method for this
        while (i > self.current_position) {
            _ = self.command_list.pop();
            i -= 1;
        }

        switch (command) {
            inline else => |c| c.execute(),
        }

        self.command_list.append(command) catch return;
        self.current_position += 1;
    }

    pub fn undo(self: *CommandQueue) void {
        if (self.current_position == 0) {
            return;
        }

        self.current_position -= 1;

        const command = self.command_list.items[self.current_position];
        switch (command) {
            inline else => |c| c.unexecute(),
        }
    }

    pub fn redo(self: *CommandQueue) void {
        if (self.current_position == self.command_list.items.len) {
            return;
        }

        const command = self.command_list.items[self.current_position];
        switch (command) {
            inline else => |c| c.execute(),
        }

        self.current_position += 1;
    }
};

// Grounds
// 0xFFFC -> No Tile
// 0x48 -> Grass
// 0x36 -> Red Quad
// 0x35 -> Red Closed
// 0x74 -> White Floor
// 0x70 -> Lava
// 0x72 -> Water
// 0x1c -> Dirt
// 0x0c -> Brown Lines

// Objects
// 0xFFFF -> No Object
// 0x0600 -> Pirate

pub const MapEditorScreen = struct {
    _allocator: Allocator,
    inited: bool = false,

    selected_object_visual_id: i32 = -1,
    simulated_object_id_next: i32 = -1,

    map_size: u32 = 128,
    map_size_64: bool = false,
    map_size_128: bool = true,
    map_size_256: bool = false,
    map_tile_data: []MapEditorTile = &[0]MapEditorTile{},

    command_queue: CommandQueue = undefined,

    action: EditorAction = .none,
    layer: EditorLayer = .ground,
    object_type_to_place: [3]u16 = .{ 0x48, 0x600, 0 }, //0x600, 0 },

    // todo dynamic ui system to fetch from assets

    tile_list_index: u8 = 0,
    tile_list: [8]u16 = .{ 0x48, 0x36, 0x35, 0x74, 0x70, 0x72, 0x1c, 0x0c },

    object_list: [2]u16 = .{ 0x600, 0x01c5 },
    object_list_index: u8 = 0,

    // end todo here

    size_text_visual_64: *ui.UiText = undefined,
    size_text_visual_128: *ui.UiText = undefined,
    size_text_visual_256: *ui.UiText = undefined,

    text_statistics: *ui.UiText = undefined,
    fps_text: *ui.UiText = undefined,

    new_container: *ui.DisplayContainer = undefined,

    buttons_container: *ui.DisplayContainer = undefined,

    // static values might make it changable in options menu later on but for now there manually set
    // 11 keys atm
    // room for one more
    place_key_settings: settings.Button = .{ .mouse = .left },
    sample_key_settings: settings.Button = .{ .mouse = .middle },
    erase_key_settings: settings.Button = .{ .mouse = .right },
    random_key_setting: settings.Button = .{ .key = .t },

    undo_key_setting: settings.Button = .{ .key = .u },
    redo_key_setting: settings.Button = .{ .key = .r },

    ground_key_setting: settings.Button = .{ .key = .F1 },
    object_key_setting: settings.Button = .{ .key = .F2 },
    region_key_setting: settings.Button = .{ .key = .F3 },

    cycle_up_setting: settings.Button = .{ .key = .one },
    cycle_down_setting: settings.Button = .{ .key = .two },

    pub fn init(allocator: Allocator) !*MapEditorScreen {
        var screen = try allocator.create(MapEditorScreen);
        screen.* = .{ ._allocator = allocator };

        // might need redoing
        screen.command_queue = CommandQueue{};
        screen.command_queue.init(allocator);

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
                .color = 0x00FFFF00,
            },
        });

        const fps_text_data = ui.TextData{
            .text = "",
            .size = 12,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
            .color = 0x00FFFF00,
        };
        screen.fps_text = try ui.UiText.create(allocator, .{
            .x = camera.screen_width - fps_text_data.width() - 10,
            .y = 16,
            .text_data = fps_text_data,
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

        const new_button: ui.Button = .{
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
        };

        _ = try screen.buttons_container.createElement(ui.Button, new_button);

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

        //

        // try addKeyMap(screen.general_tab, &settings.move_up, "Move Up", "");
        // fn addKeyMap(target_tab: *ui.DisplayContainer, button: *settings.Button, title) !void {

        const place_key: ui.KeyMapper = .{
            .x = new_button.x + new_button.width() + button_padding,
            .y = new_button.y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Place"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.place_key_settings.getKey(),
            .mouse = screen.place_key_settings.getMouse(),
            .settings_button = &screen.place_key_settings,
            .set_key_callback = noAction,
        };

        const sample_key: ui.KeyMapper = .{
            .x = place_key.x,
            .y = place_key.y + new_button.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Sample"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.sample_key_settings.getKey(),
            .mouse = screen.sample_key_settings.getMouse(),
            .settings_button = &screen.sample_key_settings,
            .set_key_callback = noAction,
        };

        const erase_key: ui.KeyMapper = .{
            .x = sample_key.x,
            .y = sample_key.y + sample_key.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Erase"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.erase_key_settings.getKey(),
            .mouse = screen.erase_key_settings.getMouse(),
            .settings_button = &screen.erase_key_settings,
            .set_key_callback = noAction,
        };

        const random_key: ui.KeyMapper = .{
            .x = erase_key.x,
            .y = erase_key.y + erase_key.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Random"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.random_key_setting.getKey(),
            .mouse = screen.random_key_setting.getMouse(),
            .settings_button = &screen.random_key_setting,
            .set_key_callback = noAction,
        };

        const undo_key: ui.KeyMapper = .{
            .x = place_key.x + random_key.width() + button_padding, // random has longest text so we use that one as offset
            .y = place_key.y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Undo"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.undo_key_setting.getKey(),
            .mouse = screen.undo_key_setting.getMouse(),
            .settings_button = &screen.undo_key_setting,
            .set_key_callback = noAction,
        };

        const redo_key: ui.KeyMapper = .{
            .x = undo_key.x,
            .y = undo_key.y + undo_key.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Redo"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.redo_key_setting.getKey(),
            .mouse = screen.redo_key_setting.getMouse(),
            .settings_button = &screen.redo_key_setting,
            .set_key_callback = noAction,
        };

        const ground_layer: ui.KeyMapper = .{
            .x = redo_key.x,
            .y = redo_key.y + redo_key.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Ground"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.ground_key_setting.getKey(),
            .mouse = screen.ground_key_setting.getMouse(),
            .settings_button = &screen.ground_key_setting,
            .set_key_callback = noAction,
        };

        const object_layer: ui.KeyMapper = .{
            .x = ground_layer.x,
            .y = ground_layer.y + ground_layer.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Object"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.object_key_setting.getKey(),
            .mouse = screen.object_key_setting.getMouse(),
            .settings_button = &screen.object_key_setting,
            .set_key_callback = noAction,
        };

        const region_layer: ui.KeyMapper = .{
            .x = ground_layer.x + ground_layer.width() + button_padding,
            .y = undo_key.y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Region"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.region_key_setting.getKey(),
            .mouse = screen.region_key_setting.getMouse(),
            .settings_button = &screen.region_key_setting,
            .set_key_callback = noAction,
        };

        const cycle_next: ui.KeyMapper = .{
            .x = region_layer.x,
            .y = region_layer.y + region_layer.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Next"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.cycle_up_setting.getKey(),
            .mouse = screen.cycle_up_setting.getMouse(),
            .settings_button = &screen.cycle_up_setting,
            .set_key_callback = noAction,
        };

        const cycle_prev: ui.KeyMapper = .{
            .x = cycle_next.x,
            .y = cycle_next.y + cycle_next.height() + button_padding,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_height, button_height, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast("Prev"),
                .size = 12,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = screen.cycle_down_setting.getKey(),
            .mouse = screen.cycle_down_setting.getMouse(),
            .settings_button = &screen.cycle_down_setting,
            .set_key_callback = noAction,
        };

        _ = try screen.buttons_container.createElement(ui.KeyMapper, place_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, sample_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, erase_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, random_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, undo_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, redo_key);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, ground_layer);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, object_layer);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, region_layer);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, cycle_next);
        _ = try screen.buttons_container.createElement(ui.KeyMapper, cycle_prev);

        screen.inited = true;
        return screen;
    }

    fn noAction(_: *ui.KeyMapper) void {}

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

        map.setWH(screen.map_size, screen.map_size, screen._allocator);

        if (screen.map_tile_data.len == 0) {
            screen.map_tile_data = screen._allocator.alloc(MapEditorTile, screen.map_size * screen.map_size) catch return;
        } else {
            screen.map_tile_data = screen._allocator.realloc(screen.map_tile_data, screen.map_size * screen.map_size) catch return;
        }

        map.local_player_id = 0xFFFC;

        const center = @as(f32, @floatFromInt(screen.map_size)) / 2.0 + 0.5;

        for (0..screen.map_size) |y| {
            for (0..screen.map_size) |x| {
                const index = y * screen.map_size + x;
                screen.map_tile_data[index] = MapEditorTile{};
                map.setSquare(@as(u32, @intCast(x)), @as(u32, @intCast(y)), screen.map_tile_data[index].ground_type);
            }
        }

        // simulate wizard
        var player = map.Player{
            .x = center,
            .y = center,
            .obj_id = map.local_player_id,
            .obj_type = 0x030e,
            .size = 100,
            // .speed = 75,
            .speed = 300, // mabye make it so we can adjust speed locally like shift slows down
        };

        player.addToMap(screen._allocator);

        screen.modifySelectionObjectVisual();

        main.editing_map = true;

        sc.menu_background.visible = false; // hack
    }

    fn modifySelectionObjectVisual(self: *MapEditorScreen) void {
        // remove current object
        if (self.selected_object_visual_id != -1) {
            if (map.removeEntity(self.selected_object_visual_id)) |en| {
                map.disposeEntity(self._allocator, en);
            }
        }

        // make a new object

        self.simulated_object_id_next += 1;
        self.selected_object_visual_id = self.simulated_object_id_next;

        const place_type = self.object_type_to_place[@intFromEnum(self.layer)];

        const _x: f32 = @floatCast(input.mouse_x);
        const _y: f32 = @floatCast(input.mouse_y);

        var world_point = camera.screenToWorld(_x, _y);
        world_point.x = @max(0, @min(world_point.x, @as(f32, @floatFromInt(self.map_size - 1))));
        world_point.y = @max(0, @min(world_point.y, @as(f32, @floatFromInt(self.map_size - 1))));

        const floor_x: u32 = @intFromFloat(@floor(world_point.x));
        const floor_y: u32 = @intFromFloat(@floor(world_point.y));

        var obj = map.GameObject{
            .x = @as(f32, @floatFromInt(floor_x)) + 0.5,
            .y = @as(f32, @floatFromInt(floor_y)) + 0.5,
            .obj_id = self.selected_object_visual_id,
            .obj_type = place_type,
            .size = 100,
            .alpha = 0.6,
        };

        obj.addToMap(self._allocator);
    }

    fn newCloseCallback() void {
        const screen = sc.current_screen.editor;
        screen.reset();
    }

    fn openCallback() void {
        // if (main.editing_map) {} // maybe a popup to ask to save?

        const file_path = nfd.openFileDialog("pmap", null) catch return;
        if (file_path) |path| {
            defer nfd.freePath(path);
            std.debug.print("openFileDialog result: {s}\n", .{path});

            // todo: read map
            //const file = std.fs.openFileAbsolute(file_path) catch return;
        }
    }

    fn saveCallback() void {
        if (!main.editing_map) return;

        const file_path = nfd.saveFileDialog(".pmap", null) catch return;
        if (file_path) |path| {
            defer nfd.freePath(path);
            std.debug.print("saveFileDialog result: {s}\n", .{path});

            // todo: write map
        }
    }

    pub fn exitCallback() void {
        sc.switchScreen(.main_menu);
    }

    fn reset(screen: *MapEditorScreen) void {
        screen.selected_object_visual_id = -1;
        screen.simulated_object_id_next = -1;
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

        self.command_queue.deinit();

        self.reset();

        self.fps_text.destroy();
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
        _ = mods;

        self.action = if (button == self.place_key_settings.getMouse()) .place else if (button == self.erase_key_settings.getMouse()) .erase else .none;

        if (button == self.sample_key_settings.getMouse()) {
            // only used for visual naming on the statistics
            self.action = .sample;

            const _x: f32 = @floatCast(x);
            const _y: f32 = @floatCast(y);

            var world_point = camera.screenToWorld(_x, _y);
            world_point.x = @max(0, @min(world_point.x, @as(f32, @floatFromInt(self.map_size - 1))));
            world_point.y = @max(0, @min(world_point.y, @as(f32, @floatFromInt(self.map_size - 1))));

            const floor_x: u32 = @intFromFloat(@floor(world_point.x));
            const floor_y: u32 = @intFromFloat(@floor(world_point.y));

            const current_tile = self.map_tile_data[floor_y * self.map_size + floor_x];
            const layer = @intFromEnum(self.layer);

            // todo add region to the sample logic

            if (self.layer == .ground) {
                if (current_tile.ground_type != 0xFFFC) {
                    for (0..8) |i| {
                        if (self.tile_list[i] == current_tile.ground_type) {
                            self.tile_list_index = @as(u8, @intCast(i));
                            self.object_type_to_place[layer] = current_tile.ground_type;
                            break;
                        }
                    }
                }
            } else {
                if (current_tile.object_type != 0xFFFF) {
                    for (0..2) |i| {
                        if (self.object_list[i] == current_tile.object_type) {
                            self.object_list_index = @as(u8, @intCast(i));
                            self.object_type_to_place[layer] = current_tile.object_type;
                            break;
                        }
                    }
                }
            }
        }
    }

    pub fn onMouseRelease(self: *MapEditorScreen, _: f64, _: f64, _: zglfw.Mods, _: zglfw.MouseButton) void {
        self.action = .none;
    }

    pub fn onKeyPress(self: *MapEditorScreen, key: zglfw.Key, mods: zglfw.Mods) void {
        _ = mods;

        // could convert into as witch statement

        // switch (key) {
        //     self.cycle_down_setting => {},
        //     else => {},
        //     //etc
        // }

        if (key == self.cycle_down_setting.getKey()) {
            if (self.layer == .ground) {
                if (self.tile_list_index == 0) { // todo remove this garbage system of index checks xd
                    self.tile_list_index = 7;
                } else {
                    self.tile_list_index -= 1;
                }
                self.object_type_to_place[@intFromEnum(self.layer)] = self.tile_list[self.tile_list_index];
            } else {
                if (self.object_list_index == 0) {
                    self.object_list_index = 1; // 0, 1 so 2 is 1 confusing ik
                } else {
                    self.object_list_index -= 1;
                }
                self.object_type_to_place[@intFromEnum(self.layer)] = self.object_list[self.object_list_index];
            }
            self.modifySelectionObjectVisual();
        }

        if (key == self.cycle_up_setting.getKey()) {
            if (self.layer == .ground) {
                self.tile_list_index = (self.tile_list_index + 1) % 8;
                self.object_type_to_place[@intFromEnum(self.layer)] = self.tile_list[self.tile_list_index];
            } else {
                self.object_list_index = (self.object_list_index + 1) % 2; // hmmmm
                self.object_type_to_place[@intFromEnum(self.layer)] = self.object_list[self.object_list_index];
            }
            self.modifySelectionObjectVisual();
        }

        // redo undo | has a bug where it just stops when holding need to find out why but its not the end of the world if it happens
        if (key == self.undo_key_setting.getKey()) {
            self.action = .undo;
        }

        if (key == self.redo_key_setting.getKey()) {
            self.action = .redo;
        }

        if (key == self.ground_key_setting.getKey()) {
            self.layer = .ground;
            self.modifySelectionObjectVisual();
        }

        if (key == self.object_key_setting.getKey()) {
            self.layer = .object;
            self.modifySelectionObjectVisual();
        }

        if (key == self.region_key_setting.getKey()) {
            self.layer = .region;
            self.modifySelectionObjectVisual();
        }
    }

    pub fn onKeyRelease(self: *MapEditorScreen, key: zglfw.Key) void {
        _ = key;
        if (self.action == .redo or self.action == .undo) {
            self.action = .none;
        }
    }

    fn setTile(self: *MapEditorScreen, x: u32, y: u32, value: u16) void {
        const index = y * self.map_size + x;
        if (self.map_tile_data[index].ground_type == value) {
            return;
        }

        self.map_tile_data[index].ground_type = value;
        map.setSquare(x, y, value);
    }

    fn getTile(self: *MapEditorScreen, x: f32, y: f32) MapEditorTile {
        const floor_x: u32 = @intFromFloat(@floor(x));
        const floor_y: u32 = @intFromFloat(@floor(y));
        return self.map_tile_data[floor_y * self.map_size + floor_x];
    }

    fn setObject(self: *MapEditorScreen, x: u32, y: u32, value: u16) void {
        const index = y * self.map_size + x;

        if (self.map_tile_data[index].object_type == value) {
            return;
        }

        if (value == 0xFFFF) {
            if (map.removeEntity(self.map_tile_data[index].object_id)) |en| {
                map.disposeEntity(self._allocator, en);
            }

            self.map_tile_data[index].object_type = value;
            self.map_tile_data[index].object_id = value;
        } else {
            if (self.map_tile_data[index].object_id != -1) {
                if (map.removeEntity(self.map_tile_data[index].object_id)) |en| {
                    map.disposeEntity(self._allocator, en);
                }
            }

            self.simulated_object_id_next += 1;

            self.map_tile_data[index].object_type = value;
            self.map_tile_data[index].object_id = self.simulated_object_id_next;

            var obj = map.GameObject{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
                .obj_id = self.simulated_object_id_next,
                .obj_type = value,
                .size = 100,
                .alpha = 1.0,
            };

            obj.addToMap(self._allocator);
        }
    }

    fn setRegion(self: *MapEditorScreen, x: u32, y: u32, value: i32) void {
        const index = y * self.map_size + x;
        self.map_tile_data[index].region_type = value;
    }

    pub fn update(self: *MapEditorScreen, time: i64, dt: f32) !void {
        _ = dt;
        _ = time;
        // map.server_time_offset += @intFromFloat(dt * std.time.us_per_ms * 16);

        // map.day_light_intensity = 0.4;
        // map.night_light_intensity = 0.8;
        // map.bg_light_color = 0;
        // map.bg_light_intensity = 0.15;

        // todo unwackify it

        const cam_x = camera.x.load(.Acquire);
        const cam_y = camera.y.load(.Acquire);

        const x: f32 = @floatCast(input.mouse_x);
        const y: f32 = @floatCast(input.mouse_y);

        var world_point = camera.screenToWorld(x, y);
        world_point.x = @max(0, @min(world_point.x, @as(f32, @floatFromInt(self.map_size - 1))));
        world_point.y = @max(0, @min(world_point.y, @as(f32, @floatFromInt(self.map_size - 1))));

        // update visual

        const floor_x: u32 = @intFromFloat(@floor(world_point.x));
        const floor_y: u32 = @intFromFloat(@floor(world_point.y));

        if (self.selected_object_visual_id != -1) {
            if (map.findEntityRef(self.selected_object_visual_id)) |en| {
                switch (en.*) {
                    .object => |*object| {
                        object.x = @as(f32, @floatFromInt(floor_x)) + 0.5;
                        object.y = @as(f32, @floatFromInt(floor_y)) + 0.5;
                    },
                    else => {},
                }
            }
        }

        const current_tile = self.map_tile_data[floor_y * self.map_size + floor_x];
        const type_to_place = self.object_type_to_place[@intFromEnum(self.layer)];

        switch (self.action) {
            .none => {},
            .place => {
                switch (self.layer) {
                    .ground => {
                        if (current_tile.ground_type != type_to_place) {
                            self.command_queue.addCommand(.{ .place_tile = .{
                                .screen = self,
                                .x = floor_x,
                                .y = floor_y,
                                .new_type = type_to_place,
                                .old_type = current_tile.ground_type,
                            } });
                        }
                    },
                    .object => {
                        if (current_tile.object_type != type_to_place) {
                            self.command_queue.addCommand(.{ .place_object = .{
                                .screen = self,
                                .x = floor_x,
                                .y = floor_y,
                                .new_type = type_to_place,
                                .old_type = current_tile.object_type,
                            } });
                        }
                    },
                    .region => {
                        self.setRegion(floor_x, floor_y, type_to_place); // todo enum stuff},
                    },
                }
            },
            .erase => {
                switch (self.layer) {
                    .ground => {
                        if (current_tile.ground_type != 0xFFFC) {
                            self.command_queue.addCommand(.{ .erase_tile = .{
                                .screen = self,
                                .x = floor_x,
                                .y = floor_y,
                                .old_type = current_tile.ground_type,
                            } });
                        }
                    },
                    .object => {
                        if (current_tile.object_type != 0xFFFF) {
                            self.command_queue.addCommand(.{ .erase_object = .{
                                .screen = self,
                                .x = floor_x,
                                .y = floor_y,
                                .old_type = current_tile.object_type,
                            } });
                        }
                    },
                    .region => {
                        self.setRegion(floor_x, floor_y, 0); // .none);
                    },
                }
            },
            .undo => {
                self.command_queue.undo();
            },
            .redo => {
                self.command_queue.redo();
            },
            // todo rest
            else => {},
        }

        const index = floor_y * self.map_size + floor_x;
        const data = self.map_tile_data[index];

        var place_name: []const u8 = "Unknown";
        switch (self.layer) {
            .ground => {
                if (game_data.ground_type_to_props.getPtr(type_to_place)) |props| {
                    place_name = props.obj_id;
                }
            },
            .object => {
                if (game_data.obj_type_to_props.getPtr(type_to_place)) |props| {
                    place_name = props.obj_id;
                }
            },
            .region => {
                // todo
            },
        }

        var hover_ground_name: []const u8 = "(Empty)";
        if (game_data.ground_type_to_props.getPtr(data.ground_type)) |props| {
            hover_ground_name = props.obj_id;
        }

        var hover_obj_name: []const u8 = "(Empty)";
        if (game_data.obj_type_to_props.getPtr(data.object_type)) |props| {
            hover_obj_name = props.obj_id;
        }

        const layer_name = if (self.layer == .ground) "Ground" else if (self.layer == .object) "Object" else "Region";
        const mode = if (self.action == .none) "None" else if (self.action == .place) "Placing" else if (self.action == .erase) "Erasing" else if (self.action == .sample) "Sampling" else if (self.action == .undo) "Undoing" else if (self.action == .redo) "Redoing" else "Idle";

        self.text_statistics.text_data.text = try std.fmt.bufPrint(self.text_statistics.text_data.backing_buffer, "Size: ({d}x{d})\n\nLayer: {s}\nPlacing: {s}\n\nMode:{s}\n\nGround Type: {s}\nObject Type: {s}\nRegion Type: {d}\n\nPosition ({d:.1}, {d:.1}),\nFloor: ({d}, {d})\nWorld Coordinate ({d:.1}, {d:.1})", .{
            self.map_size,
            self.map_size,
            layer_name,
            place_name,
            mode,
            hover_ground_name,
            hover_obj_name,
            data.region_type, // todo enum stuff and assets xml stuff if not already done?
            cam_x,
            cam_y,
            floor_x,
            floor_y,
            world_point.x,
            world_point.y,
        });
    }

    pub fn updateFpsText(self: *MapEditorScreen, fps: f64, mem: f32) !void {
        self.fps_text.text_data.text = try std.fmt.bufPrint(self.fps_text.text_data.backing_buffer, "FPS: {d:.1}\nMemory: {d:.1} MB", .{ fps, mem });
        self.fps_text.x = camera.screen_width - self.fps_text.text_data.width() - 10;
    }
};
