const Allocator = @import("std").mem.Allocator;

const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const map = @import("../../map.zig");
const ui = @import("../ui.zig");

const sc = @import("../controllers/screen_controller.zig");
const NineSlice = ui.NineSliceImageData;

const button_container_width = 420;
const button_container_height = 190;

const new_container_width = 325;
const new_container_height = 175;

pub const MapEditorScreen = struct {
    _allocator: Allocator,
    inited: bool = false,

    map_size_64: bool = false,
    map_size_128: bool = true,
    map_size_256: bool = false,

    size_text_visual_64: *ui.UiText = undefined,
    size_text_visual_128: *ui.UiText = undefined,
    size_text_visual_256: *ui.UiText = undefined,

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
    }

    fn mapState128Changed(_: *ui.Toggle) void {
        const screen = sc.current_screen.editor;
        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = true;
        screen.size_text_visual_256.visible = false;

        screen.map_size_64 = false;
        screen.map_size_128 = true;
        screen.map_size_256 = false;
    }

    fn mapState256Changed(_: *ui.Toggle) void {
        const screen = sc.current_screen.editor;
        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = false;
        screen.size_text_visual_256.visible = true;

        screen.map_size_64 = false;
        screen.map_size_128 = false;
        screen.map_size_256 = true;
    }

    fn newCallback() void {
        const screen = sc.current_screen.editor;

        screen.new_container.visible = true;
        screen.buttons_container.visible = false;
    }

    fn newCreateCallback() void {
        const screen = sc.current_screen.editor;
        screen.reset();
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

    fn exitCallback() void {
        sc.switchScreen(.main_menu);
    }

    fn reset(screen: *MapEditorScreen) void {
        screen.buttons_container.visible = true;
        screen.new_container.visible = false;

        screen.size_text_visual_64.visible = false;
        screen.size_text_visual_128.visible = true;
        screen.size_text_visual_256.visible = false;

        screen.map_size_64 = false;
        screen.map_size_128 = true;
        screen.map_size_256 = false;
    }

    pub fn deinit(self: *MapEditorScreen) void {
        self.reset();

        self.new_container.destroy();
        self.buttons_container.destroy();

        self._allocator.destroy(self);
    }

    pub fn resize(self: *MapEditorScreen, width: f32, height: f32) void {
        self.new_container.x = (width - self.new_container.height) / 2;
        self.new_container.y = (height - self.new_container.height) / 2;
        self.buttons_container.x = 0;
        self.buttons_container.y = height - self.buttons_container.height;
    }

    pub fn update(_: *MapEditorScreen, _: i64, _: f32) !void {}
};
