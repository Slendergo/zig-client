const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const requests = @import("../requests.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");

pub const AccountRegisterScreen = struct {
    username_text: *ui.UiText = undefined,
    username_input: *ui.InputField = undefined,

    email_text: *ui.UiText = undefined,
    email_input: *ui.InputField = undefined,

    password_text: *ui.UiText = undefined,
    password_input: *ui.InputField = undefined,

    password_repeat_text: *ui.UiText = undefined,
    password_repeat_input: *ui.InputField = undefined,

    confirm_button: *ui.Button = undefined,
    back_button: *ui.Button = undefined,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !AccountRegisterScreen {
        var screen = AccountRegisterScreen{
            ._allocator = allocator,
        };

        const input_w = 300;
        const input_h = 50;

        const input_data_base = assets.getUiData("textInputBase", 0);
        const input_data_hover = assets.getUiData("textInputHover", 0);
        const input_data_press = assets.getUiData("textInputPress", 0);

        const NineSlice = ui.NineSliceImageData;

        const x_offset: f32 = (camera.screen_width - input_w) / 2;
        var y_offset: f32 = 100.0;

        screen.username_text = try ui.UiText.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_data = .{
                .text = @constCast("Username"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
                .max_width = input_w,
                .max_height = input_h,
            },
        });

        y_offset += 50;

        screen.username_input = try ui.InputField.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 256),
                .handle_special_chars = false,
            },
            .allocator = allocator,
        });

        y_offset += 50;

        screen.email_text = try ui.UiText.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
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

        y_offset += 50;

        screen.email_input = try ui.InputField.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .text_data = .{
                .text = "",
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 256),
                .handle_special_chars = false,
            },
            .allocator = allocator,
        });

        y_offset += 50;

        screen.password_text = try ui.UiText.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
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

        y_offset += 50;

        screen.password_input = try ui.InputField.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
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

        y_offset += 50;

        screen.password_repeat_text = try ui.UiText.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_data = .{
                .text = @constCast("Confirm Password"),
                .size = 20,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
                .hori_align = .middle,
                .vert_align = .middle,
                .max_width = input_w,
                .max_height = input_h,
            },
        });

        y_offset += 50;

        screen.password_repeat_input = try ui.InputField.create(allocator, .{
            .x = x_offset,
            .y = y_offset,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
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

        y_offset += 75;

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);
        const button_width = 100;
        const button_height = 35;

        screen.confirm_button = try ui.Button.create(allocator, .{
            .x = x_offset + (input_w - (button_width * 2)) / 2 - 12.5,
            .y = y_offset,
            .base_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .hover_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .press_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .text_data = .{
                .text = @constCast("Confirm"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = registerCallback,
        });

        screen.back_button = try ui.Button.create(allocator, .{
            .x = screen.confirm_button.x + button_width + 25,
            .y = y_offset,
            .base_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .hover_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .press_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            .text_data = .{
                .text = @constCast("Back"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = backCallback,
        });

        return screen;
    }

    pub fn deinit(self: *AccountRegisterScreen) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.username_text.destroy();
        self.username_input.destroy();
        self.email_text.destroy();
        self.email_input.destroy();
        self.password_text.destroy();
        self.password_input.destroy();
        self.password_repeat_input.destroy();
        self.password_repeat_text.destroy();
        self.confirm_button.destroy();
        self.back_button.destroy();
    }

    pub fn toggle(self: *AccountRegisterScreen, state: bool) void {
        self.username_text.visible = state;
        self.username_input.visible = state;
        self.email_text.visible = state;
        self.email_input.visible = state;
        self.password_text.visible = state;
        self.password_input.visible = state;
        self.password_repeat_input.visible = state;
        self.password_repeat_text.visible = state;
        self.confirm_button.visible = state;
        self.back_button.visible = state;
    }

    pub fn resize(self: *AccountRegisterScreen, w: f32, h: f32) void {
        _ = h;
        _ = w;
        _ = self;
    }

    pub fn update(self: *AccountRegisterScreen, ms_time: i64, ms_dt: f32) !void {
        _ = self;
        _ = ms_dt;
        _ = ms_time;
    }

    fn register(email: []const u8, password: []const u8, username: []const u8) !bool {
        const response = try requests.sendAccountRegister(email, password, username);
        if (std.mem.eql(u8, response, "<Error />")) {
            std.log.err("Register failed: {s}", .{response});
            return false;
        }

        return true;
    }
    
    fn registerCallback() void {

        _ = register(
            ui.account_register_screen.email_input.text_data.text,
            ui.account_register_screen.password_input.text_data.text,
            ui.account_register_screen.username_input.text_data.text,
        ) catch |e| {
            std.log.err("Register failed: {any}", .{e});
        };

        ui.switchScreen(.main_menu);
    }

    fn backCallback() void {
        ui.switchScreen(.main_menu);
    }
};

pub const AccountScreen = struct {
    email_text: *ui.UiText = undefined,
    email_input: *ui.InputField = undefined,
    password_text: *ui.UiText = undefined,
    password_input: *ui.InputField = undefined,
    login_button: *ui.Button = undefined,
    confirm_button: *ui.Button = undefined,

    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !AccountScreen {
        var screen = AccountScreen{
            ._allocator = allocator,
        };

        const input_w = 300;
        const input_h = 50;
        const input_data_base = assets.getUiData("textInputBase", 0);
        const input_data_hover = assets.getUiData("textInputHover", 0);
        const input_data_press = assets.getUiData("textInputPress", 0);

        const NineSlice = ui.NineSliceImageData;

        screen.email_input = try ui.InputField.create(allocator, .{
            .x = (camera.screen_width - input_w) / 2,
            .y = 200,
            .text_inlay_x = 9,
            .text_inlay_y = 8,
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
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
            .base_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_base, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .hover_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_hover, input_w, input_h, 8, 8, 32, 32, 1.0) },
            .press_decor_data = .{ .nine_slice = NineSlice.fromAtlasData(input_data_press, input_w, input_h, 8, 8, 32, 32, 1.0) },
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

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        screen.login_button = try ui.Button.create(allocator, .{
            .x = screen.password_input.x + (input_w - 200) / 2 - 12.5,
            .y = 450,
            .base_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 100, 35, 6, 6, 7, 7, 1.0) },
            .hover_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, 100, 35, 6, 6, 7, 7, 1.0) },
            .press_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, 100, 35, 6, 6, 7, 7, 1.0) },
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
            .y = 450,
            .base_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, 100, 35, 6, 6, 7, 7, 1.0) },
            .hover_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, 100, 35, 6, 6, 7, 7, 1.0) },
            .press_image_data = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, 100, 35, 6, 6, 7, 7, 1.0) },
            .text_data = .{
                .text = @constCast("Register"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = registerCallback,
        });

        return screen;
    }

    pub fn deinit(self: *AccountScreen) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.email_text.destroy();
        self.email_input.destroy();
        self.password_text.destroy();
        self.password_input.destroy();
        self.login_button.destroy();
        self.confirm_button.destroy();
    }

    pub fn toggle(self: *AccountScreen, state: bool) void {
        self.email_text.visible = state;
        self.email_input.visible = state;
        self.password_text.visible = state;
        self.password_input.visible = state;
        self.login_button.visible = state;
        self.confirm_button.visible = state;
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

    fn registerCallback() void {
        ui.switchScreen(.register);
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
