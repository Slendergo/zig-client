const std = @import("std");
const ui = @import("../../ui.zig");
const assets = @import("../../../assets.zig");
const camera = @import("../../../camera.zig");
const requests = @import("../../../requests.zig");
const xml = @import("../../../xml.zig");
const main = @import("../../../main.zig");
const utils = @import("../../../utils.zig");
const settings = @import("../../../settings.zig");
const screen_controller = @import("../../controllers/screen_controller.zig");

pub const AccountLoginScreen = struct {
    email_text: *ui.UiText = undefined,
    email_input: *ui.InputField = undefined,
    password_text: *ui.UiText = undefined,
    password_input: *ui.InputField = undefined,
    login_button: *ui.Button = undefined,
    confirm_button: *ui.Button = undefined,
    save_email_text: *ui.UiText = undefined,
    save_email_toggle: *ui.Toggle = undefined,
    editor_button: *ui.Button = undefined,
    inited: bool = false,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !*AccountLoginScreen {
        var screen = try allocator.create(AccountLoginScreen);
        screen.* = .{ ._allocator = allocator };

        const input_w = 300;
        const input_h = 50;
        const input_data_base = assets.getUiData("textInputBase", 0);
        const input_data_hover = assets.getUiData("textInputHover", 0);
        const input_data_press = assets.getUiData("textInputPress", 0);

        const NineSlice = ui.NineSliceImageData;

        const cursor_data = assets.getUiData("chatboxCursor", 0);
        screen.email_input = try ui.InputField.create(allocator, .{
            .x = (camera.screen_width - input_w) / 2,
            .y = 200,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
            },
            .cursor_image_data = .{ .normal = .{ .atlas_data = cursor_data } },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 256),
                .handle_special_chars = false,
            },
            .allocator = allocator,
        });

        screen.email_text = try ui.UiText.create(allocator, .{
            .x = screen.email_input.x,
            .y = 150,
            .text_data = .{
                .text = @constCast("E-mail"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
                .max_width = input_w,
                .max_height = input_h,
            },
        });

        screen.password_input = try ui.InputField.create(allocator, .{
            .x = (camera.screen_width - input_w) / 2,
            .y = 350,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
            },
            .cursor_image_data = .{ .normal = .{ .atlas_data = cursor_data } },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .password = true,
                .backing_buffer = try allocator.alloc(u8, 256),
                .handle_special_chars = false,
            },
            .allocator = allocator,
        });

        screen.password_text = try ui.UiText.create(allocator, .{
            .x = screen.password_input.x,
            .y = 300,
            .text_data = .{
                .text = @constCast("Password"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
                .max_width = input_w,
                .max_height = input_h,
            },
        });

        const check_box_base_on = assets.getUiData("checkedBoxBase", 0);
        const check_box_hover_on = assets.getUiData("checkedBoxHover", 0);
        const check_box_press_on = assets.getUiData("checkedBoxPress", 0);
        const check_box_base_off = assets.getUiData("uncheckedBoxBase", 0);
        const check_box_hover_off = assets.getUiData("uncheckedBoxHover", 0);
        const check_box_press_off = assets.getUiData("uncheckedBoxPress", 0);

        const text_w = 150;

        screen.save_email_toggle = try ui.Toggle.create(allocator, .{
            .x = screen.password_input.x + (input_w - text_w - check_box_base_on.texWRaw()) / 2,
            .y = 400 + (100 - check_box_base_on.texHRaw()) / 2,
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
            .toggled = &settings.save_email,
        });

        screen.save_email_text = try ui.UiText.create(allocator, .{
            .x = screen.save_email_toggle.x + check_box_base_on.texWRaw(),
            .y = 400,
            .text_data = .{
                .text = @constCast("Save e-mail"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
                .max_width = text_w,
                .max_height = 100,
            },
        });

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        screen.login_button = try ui.Button.create(allocator, .{
            .x = screen.password_input.x + (input_w - 200) / 2 - 12.5,
            .y = 500,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 100, 35, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, 100, 35, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, 100, 35, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Login"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = loginCallback,
        });

        screen.confirm_button = try ui.Button.create(allocator, .{
            .x = screen.login_button.x + (input_w - 100) / 2 + 25,
            .y = 500,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 100, 35, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, 100, 35, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, 100, 35, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Register"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = registerCallback,
        });

        screen.editor_button = try ui.Button.create(allocator, .{
            .x = screen.password_input.x + (input_w - 200) / 2,
            .y = 550,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 200, 35, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, 200, 35, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, 200, 35, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Editor"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = enableEditorCallback,
        });
        screen.inited = true;
        return screen;
    }

    pub fn enableEditorCallback() void {
        screen_controller.switchScreen(.editor);
    }

    pub fn deinit(self: *AccountLoginScreen) void {
        while (!screen_controller.ui_lock.tryLock()) {}
        defer screen_controller.ui_lock.unlock();

        self.email_text.destroy();
        self.email_input.destroy();
        self.password_text.destroy();
        self.password_input.destroy();
        self.login_button.destroy();
        self.confirm_button.destroy();
        self.save_email_text.destroy();
        self.save_email_toggle.destroy();
        self.editor_button.destroy();

        self._allocator.destroy(self);
    }

    pub fn resize(_: *AccountLoginScreen, _: f32, _: f32) void {}

    pub fn update(_: *AccountLoginScreen, _: i64, _: f32) !void {}

    fn loginCallback() void {
        const current_screen = screen_controller.current_screen.main_menu;
        _ = login(
            current_screen._allocator,
            current_screen.email_input.text_data.text,
            current_screen.password_input.text_data.text,
        ) catch |e| {
            std.log.err("Login failed: {any}", .{e});
        };
    }

    fn registerCallback() void {
        screen_controller.switchScreen(.register);
    }
};

fn login(allocator: std.mem.Allocator, email: []const u8, password: []const u8) !bool {
    const response = try requests.sendAccountVerify(email, password);
    if (std.mem.eql(u8, response, "<Error />")) {
        std.log.err("Login failed: {s}", .{response});
        return false;
    }

    const verify_doc = try xml.Doc.fromMemory(response);
    defer verify_doc.deinit();
    const verify_root = try verify_doc.getRootElement();

    if (std.mem.eql(u8, verify_root.currentName().?, "Error")) {
        std.log.err("Login failed: {s}", .{verify_root.currentValue().?});
        return false;
    }

    main.current_account.name = try allocator.dupeZ(u8, verify_root.getValue("Name") orelse "Guest");
    main.current_account.email = try allocator.dupe(u8, email);
    main.current_account.password = try allocator.dupe(u8, password);
    main.current_account.admin = verify_root.elementExists("Admin");

    const guild_node = verify_root.findChild("Guild");
    main.current_account.guild_name = try guild_node.?.getValueAlloc("Name", allocator, "");
    main.current_account.guild_rank = try guild_node.?.getValueInt("Rank", u8, 0);

    const list_response = try requests.sendCharList(email, password);
    const list_doc = try xml.Doc.fromMemory(list_response);
    defer list_doc.deinit();
    const list_root = try list_doc.getRootElement();
    main.next_char_id = try list_root.getAttributeInt("nextCharId", u8, 0);
    main.max_chars = try list_root.getAttributeInt("maxNumChars", u8, 0);

    var char_list = try utils.DynSlice(main.CharacterData).init(4, allocator);
    defer char_list.deinit();

    var char_iter = list_root.iterate(&.{}, "Char");
    while (char_iter.next()) |node|
        try char_list.add(try main.CharacterData.parse(allocator, node, try node.getAttributeInt("id", u32, 0)));

    main.character_list = try allocator.dupe(main.CharacterData, char_list.items());

    const server_root = list_root.findChild("Servers");
    if (server_root) |srv_root| {
        var server_data_list = try utils.DynSlice(main.ServerData).init(4, allocator);
        defer server_data_list.deinit();

        var server_iter = srv_root.iterate(&.{}, "Server");
        while (server_iter.next()) |server_node|
            try server_data_list.add(try main.ServerData.parse(server_node, allocator));

        main.server_list = try allocator.dupe(main.ServerData, server_data_list.items());
    }

    if (main.character_list.len > 0) {
        screen_controller.switchScreen(.char_select);
    } else {
        screen_controller.switchScreen(.char_create);
    }

    return true;
}
