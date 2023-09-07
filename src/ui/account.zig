const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const requests = @import("../requests.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");

pub const AccountScreen = struct {
    email_text: *ui.UiText = undefined,
    email_input: *ui.InputField = undefined,
    password_text: *ui.UiText = undefined,
    password_input: *ui.InputField = undefined,
    username_text: *ui.UiText = undefined,
    username_input: *ui.InputField = undefined,
    password_repeat_text: *ui.UiText = undefined,
    password_repeat_input: *ui.InputField = undefined,
    login_button: *ui.Button = undefined,
    register_button: *ui.Button = undefined,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !AccountScreen {
        var screen = AccountScreen{
            ._allocator = allocator,
        };

        const input_w = 200;
        const input_h = 50;

        screen.email_input = try allocator.create(ui.InputField);
        const input_data_base = assets.getUiSingle("textInputBase");
        const input_data_hover = assets.getUiSingle("textInputHover");
        const input_data_press = assets.getUiSingle("textInputPress");
        screen.email_input.* = ui.InputField{
            .x = (camera.screen_width - input_w) / 2,
            .y = 200,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_base,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .hover_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_hover,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .press_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_press,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 256),
            },
            .allocator = allocator,
        };
        try ui.elements.add(.{ .input_field = screen.email_input });

        screen.email_text = try allocator.create(ui.UiText);
        const email_text_data = ui.TextData{
            .text = @constCast("E-mail"),
            .size = 20,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
            .hori_align = .middle,
            .vert_align = .middle,
            .max_width = input_w,
            .max_height = input_h,
        };
        screen.email_text.* = ui.UiText{
            .x = screen.email_input.x,
            .y = 150,
            .text_data = email_text_data,
        };
        try ui.elements.add(.{ .text = screen.email_text });

        screen.password_input = try allocator.create(ui.InputField);
        screen.password_input.* = ui.InputField{
            .x = (camera.screen_width - input_w) / 2,
            .y = 350,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_base,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .hover_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_hover,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .press_decor_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                input_data_press,
                input_w,
                input_h,
                8,
                8,
                32,
                32,
                1.0,
            ) },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .password = true,
                .backing_buffer = try allocator.alloc(u8, 256),
            },
            .allocator = allocator,
        };
        try ui.elements.add(.{ .input_field = screen.password_input });

        screen.password_text = try allocator.create(ui.UiText);
        const password_text_data = ui.TextData{
            .text = @constCast("Password"),
            .size = 20,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
            .hori_align = .middle,
            .vert_align = .middle,
            .max_width = input_w,
            .max_height = input_h,
        };
        screen.password_text.* = ui.UiText{
            .x = screen.password_input.x,
            .y = 300,
            .text_data = password_text_data,
        };
        try ui.elements.add(.{ .text = screen.password_text });

        screen.login_button = try allocator.create(ui.Button);
        const button_data_base = assets.getUiSingle("buttonBase");
        const button_data_hover = assets.getUiSingle("buttonHover");
        const button_data_press = assets.getUiSingle("buttonPress");
        screen.login_button.* = ui.Button{
            .x = screen.password_input.x + (input_w - 100) / 2,
            .y = 450,
            .base_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                button_data_base,
                100,
                35,
                6,
                6,
                7,
                7,
                1.0,
            ) },
            .hover_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                button_data_hover,
                100,
                35,
                6,
                6,
                7,
                7,
                1.0,
            ) },
            .press_image_data = .{ .nine_slice = ui.NineSliceImageData.fromAtlasData(
                button_data_press,
                100,
                35,
                6,
                6,
                7,
                7,
                1.0,
            ) },
            .text_data = ui.TextData{
                .text = @constCast("Login"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = loginCallback,
        };
        try ui.elements.add(.{ .button = screen.login_button });

        return screen;
    }

    pub fn deinit(self: *AccountScreen, allocator: std.mem.Allocator) void {
        allocator.destroy(self.email_text);
        allocator.destroy(self.email_input);
        allocator.destroy(self.password_text);
        allocator.destroy(self.password_input);
        // allocator.destroy(self.password_repeat_input);
        // allocator.destroy(self.password_repeat_text);
        allocator.destroy(self.login_button);
        // allocator.destroy(self.register_button);
    }

    pub fn toggle(self: *AccountScreen, state: bool) void {
        self.email_text.visible = state;
        self.email_input.visible = state;
        self.password_text.visible = state;
        self.password_input.visible = state;
        // self.password_repeat_input.visible = state;
        // self.password_repeat_text.visible = state;
        self.login_button.visible = state;
        // self.register_button.visible = state;
    }

    pub fn resize(self: *AccountScreen, w: f32, h: f32) void {
        _ = h;
        _ = w;
        _ = self;
    }

    pub fn update(self: *AccountScreen, ms_time: i64, ms_dt: f32) !void {
        _ = self;
        _ = ms_dt;
        _ = ms_time;
    }

    fn loginCallback() void {
        _ = login(
            ui.account_screen._allocator,
            ui.account_screen.email_input.text_data.text,
            ui.account_screen.password_input.text_data.text,
        ) catch |e| {
            std.log.err("Login failed: {any}", .{e});
        };
    }

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

        main.current_account.name = allocator.dupeZ(u8, verify_root.getValue("Name") orelse "Guest") catch |e| {
            std.log.err("Could not dupe current account name: {any}", .{e});
            return false;
        };

        main.current_account.email = email;
        main.current_account.password = password;
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
            ui.switchScreen(.char_select);
        } else {
            ui.switchScreen(.char_creation);
        }

        return true;
    }
};
