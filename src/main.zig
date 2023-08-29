const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
const game_data = @import("game_data.zig");
const settings = @import("settings.zig");
const requests = @import("requests.zig");
const network = @import("network.zig");
const builtin = @import("builtin");
const xml = @import("xml.zig");
const asset_dir = @import("build_options").asset_dir;
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const input = @import("input.zig");
const utils = @import("utils.zig");
const camera = @import("camera.zig");
const map = @import("map.zig");
const ui = @import("ui.zig");
const render = @import("render.zig");
const ztracy = @import("ztracy");
const zaudio = @import("zaudio");

pub const ServerData = struct {
    name: [:0]const u8 = "",
    dns: [:0]const u8 = "",
    port: u16,
    max_players: u16,
    admin_only: bool,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ServerData {
        return ServerData{
            .name = try node.getValueAllocZ("Name", allocator, "Unknown"),
            .dns = try node.getValueAllocZ("DNS", allocator, "127.0.0.1"),
            .port = try node.getValueInt("Port", u16, 2050),
            .max_players = try node.getValueInt("MaxPlayers", u16, 0),
            .admin_only = node.elementExists("AdminOnly") and std.mem.eql(u8, node.getValue("AdminOnly").?, "true"),
        };
    }
};

pub const AccountData = struct {
    name: [:0]const u8 = "",
    email: []const u8 = "",
    password: []const u8 = "",
    admin: bool = false,
    guild_name: []const u8 = "",
    guild_rank: u8 = 0,
};

// todo nilly stats (def etc)
pub const CharacterData = struct {
    id: u32 = 0,
    tier: u8 = 1,
    obj_type: u16 = 0x00,
    name: [:0]const u8 = "",
    health: u16 = 100,
    mana: u16 = 0,
    tex1: u32 = 0,
    tex2: u32 = 0,
    texture: u16 = 0,
    health_pots: i8 = 0,
    magic_pots: i8 = 0,
    has_backpack: bool = false,
    equipment: [20]u16 = std.mem.zeroes([20]u16),

    pub fn parse(allocator: std.mem.Allocator, node: xml.Node, id: u32) !CharacterData {
        const obj_type = try node.getValueInt("ObjectType", u16, 0);
        return CharacterData{
            .id = id,
            .obj_type = obj_type,
            .tex1 = try node.getValueInt("Tex1", u32, 0),
            .tex2 = try node.getValueInt("Tex2", u32, 0),
            .texture = try node.getValueInt("Texture", u16, 0),
            .health_pots = try node.getValueInt("HealthStackCount", i8, 0),
            .magic_pots = try node.getValueInt("MagicStackCount", i8, 0),
            .has_backpack = try node.getValueInt("HasBackpack", i8, 0) > 0,
            .name = try allocator.dupeZ(u8, game_data.obj_type_to_name.get(obj_type) orelse "Unknown Class"),
        };
    }
};

pub const ScreenType = enum(u8) { main_menu, char_select, char_creation, map_editor, in_game };

const embedded_font_data = @embedFile(asset_dir ++ "fonts/Ubuntu-Medium.ttf");

pub var current_screen = ScreenType.main_menu;
pub var gctx: *zgpu.GraphicsContext = undefined;
pub var fba: std.heap.FixedBufferAllocator = undefined;
pub var stack_allocator: std.mem.Allocator = undefined;
pub var server: ?network.Server = undefined;
pub var current_account = AccountData{};
pub var character_list: []CharacterData = undefined;
pub var server_list: ?[]ServerData = null;
pub var selected_char_id: u32 = 65535;
pub var char_create_type: u16 = 0;
pub var char_create_skin_type: u16 = 0;
pub var selected_server: ?ServerData = null;
pub var next_char_id: u32 = 0;
pub var max_chars: u32 = 0;
pub var current_time: i32 = 0;
pub var last_update: i32 = 0;
pub var network_thread: std.Thread = undefined;
pub var tick_network = true;
pub var render_thread: std.Thread = undefined;
pub var tick_render = true;
pub var tick_frame = false;
pub var sent_hello = false;
var _allocator: std.mem.Allocator = undefined;

var chat_input: *ui.InputField = undefined;
var fps_text: *ui.UiText = undefined;
var chat_decor: *ui.Image = undefined;
var bars_decor: *ui.Image = undefined;
var inventory_decor: *ui.Image = undefined;
var minimap_decor: *ui.Image = undefined;

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !void {
    gctx = try zgpu.GraphicsContext.create(allocator, window, .{ .present_mode = if (settings.enable_vsync) .fifo else .immediate });
    _ = window.setKeyCallback(input.keyEvent);
    _ = window.setCharCallback(input.charEvent);
    _ = window.setCursorPosCallback(input.mouseMoveEvent);
    _ = window.setMouseButtonCallback(input.mouseEvent);

    zgui.init(allocator);
    const scale = window.getContentScale();
    const scale_factor = @max(scale[0], scale[1]);
    const font_size = 16.0 * scale_factor;
    const font_normal = zgui.io.addFontFromFile(asset_dir ++ "fonts/Ubuntu-Bold.ttf", @floor(font_size));

    zgui.backend.initWithConfig(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        .{ .texture_filter_mode = .linear, .pipeline_multisample_count = 1 },
    );
    zgui.io.setConfigFlags(.{ .no_mouse_cursor_change = true });
    zgui.io.setConfigWindowsMoveFromTitleBarOnly(true);
    zgui.io.setDefaultFont(font_normal);

    const style = zgui.getStyle();
    style.anti_aliased_fill = true;
    style.anti_aliased_lines = true;
    style.window_min_size = .{ 500.0, 200.0 };
    style.window_border_size = 2.0;
    style.scrollbar_size = 8.0;
    var color = style.getColor(.scrollbar_grab);
    color[1] = 0.8;
    style.setColor(.scrollbar_grab, color);
    style.scaleAllSizes(scale_factor);
}

fn updateUi(allocator: std.mem.Allocator) !void {
    zgui.backend.newFrame(
        gctx.swapchain_descriptor.width,
        gctx.swapchain_descriptor.height,
    );

    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

    zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 12.0 });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 20.0, 20.0 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    switch (current_screen) {
        ScreenType.main_menu => {
            if (zgui.begin("Main Menu", .{})) {
                {
                    const LoginStatic = struct {
                        var email_buf: [128]u8 = undefined;
                        var password_buf: [128]u8 = undefined;
                    };

                    _ = zgui.inputText("E-mail", .{ .buf = LoginStatic.email_buf[0..] });
                    _ = zgui.inputText("Password", .{ .buf = LoginStatic.password_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });
                    if (zgui.button("Login", .{ .w = 150.0 })) {
                        const email = LoginStatic.email_buf[0..utils.strlen(LoginStatic.email_buf[0..])];
                        const password = LoginStatic.password_buf[0..utils.strlen(LoginStatic.password_buf[0..])];
                        if (email.len > 0 and password.len > 0) {
                            const logged_in = try login(allocator, email, password);
                            if (logged_in) {
                                current_screen = ScreenType.char_select;
                            }
                        }
                    }
                }

                const RegisterStatic = struct {
                    var username_buf: [128]u8 = undefined;
                    var email_buf: [128]u8 = undefined;
                    var password_buf: [128]u8 = undefined;
                    var confirm_pw_buf: [128]u8 = undefined;
                };

                _ = zgui.inputText("Name", .{ .buf = RegisterStatic.username_buf[0..] });
                _ = zgui.inputText("E-mail##Register", .{ .buf = RegisterStatic.email_buf[0..] });
                _ = zgui.inputText("Password##Register", .{ .buf = RegisterStatic.password_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });
                _ = zgui.inputText("Confirm Password", .{ .buf = RegisterStatic.confirm_pw_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });

                if (zgui.button("Register", .{ .w = 150.0 })) {
                    const name = RegisterStatic.username_buf[0..utils.strlen(RegisterStatic.username_buf[0..])];
                    const email = RegisterStatic.email_buf[0..utils.strlen(RegisterStatic.email_buf[0..])];
                    const password = RegisterStatic.password_buf[0..utils.strlen(RegisterStatic.password_buf[0..])];
                    const response = try requests.sendAccountRegister(email, password, name);
                    if (std.mem.indexOf(u8, "<Success />", response) != null) {
                        const logged_in = try login(allocator, email, password);
                        if (logged_in) {
                            current_screen = ScreenType.char_select;
                        }
                    }
                }
            }
            zgui.end();
        },
        ScreenType.char_select => {
            if (zgui.begin("Character", .{})) {
                if (character_list.len < 1) {
                    current_screen = ScreenType.char_creation;
                }

                const static = struct {
                    var char_index: u32 = 0;
                    var server_index: u32 = 0;
                };

                zgui.text("Logged in as [{s}]", .{current_account.name});
                if (zgui.beginListBox("Character", .{})) {
                    for (character_list, 0..) |char, index| {
                        const i: u32 = @intCast(index);
                        if (zgui.selectable(char.name[0..], .{ .selected = static.char_index == i }))
                            static.char_index = i;
                    }
                    zgui.endListBox();
                }

                if (server_list == null or server_list.?.len == 0) {
                    zgui.text("No servers available", .{});
                    if (zgui.button("Return", .{})) {
                        current_screen = .main_menu;
                    }
                } else {
                    if (zgui.beginListBox("Server", .{})) {
                        if (server_list) |srv_list| {
                            for (srv_list, 0..) |server_data, index| {
                                const i: u32 = @intCast(index);
                                if (zgui.selectable(server_data.name[0..], .{ .selected = static.server_index == i }))
                                    static.server_index = i;
                            }
                            zgui.endListBox();
                        }
                    }

                    if (zgui.button("Play", .{ .w = 150.0 })) {
                        current_screen = ScreenType.in_game;
                        selected_char_id = character_list[static.char_index].id;
                        if (server_list) |srv_list| {
                            selected_server = srv_list[static.server_index];
                        }
                    }
                }
            }
            zgui.end();
        },
        ScreenType.char_creation => {
            if (zgui.begin("Character Creation", .{})) {
                const static = struct {
                    var server_index: u32 = 0;
                    var char_type: i32 = 0;
                    var skin_type: i32 = 0;
                };

                zgui.text("Logged in as [{s}]", .{current_account.name});

                _ = zgui.inputInt("Character Type", .{ .v = &static.char_type, .step = 1, .step_fast = 1 });
                _ = zgui.inputInt("Skin Type", .{ .v = &static.skin_type, .step = 1, .step_fast = 1 });

                if (server_list == null or server_list.?.len == 0) {
                    zgui.text("No servers available", .{});
                    if (zgui.button("Return", .{})) {
                        current_screen = .main_menu;
                    }
                } else {
                    if (zgui.beginListBox("Server", .{})) {
                        for (server_list.?, 0..) |server_data, index| {
                            const i: u32 = @intCast(index);
                            if (zgui.selectable(server_data.name[0.. :0], .{ .selected = static.server_index == i }))
                                static.server_index = i;
                        }
                        zgui.endListBox();
                    }

                    if (zgui.button("Create Character", .{ .w = 150.0 })) {
                        current_screen = ScreenType.in_game;
                        char_create_type = @as(u16, @intCast(static.char_type));
                        char_create_skin_type = @as(u16, @intCast(static.skin_type));
                        selected_char_id = next_char_id;
                        next_char_id += 1;

                        selected_server = server_list.?[static.server_index];
                    }
                }
            }
            zgui.end();
        },
        ScreenType.map_editor => {},
        ScreenType.in_game => {
            stack_allocator.free(fps_text.text.text);
            fps_text.text.text = try std.fmt.allocPrint(stack_allocator, "FPS: {d:.1}\nMemory: {d} MB", .{ gctx.stats.fps, -1 });
            fps_text.x = camera.screen_width - fps_text.text.width() - 10;
        },
    }
}

inline fn draw() void {
    const back_buffer = gctx.swapchain.getCurrentTextureView();
    const encoder = gctx.device.createCommandEncoder(null);

    if (current_screen == .in_game and tick_frame) {
        render.draw(current_time, gctx, back_buffer, encoder);
    }

    const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
        .view = back_buffer,
        .load_op = .load,
        .store_op = .store,
    }};
    const render_pass_info = wgpu.RenderPassDescriptor{
        .color_attachment_count = color_attachments.len,
        .color_attachments = &color_attachments,
    };
    const pass = encoder.beginRenderPass(render_pass_info);
    zgui.backend.draw(pass);
    pass.end();
    pass.release();

    const commands = encoder.finish(null);
    gctx.submit(&.{commands});
    if (gctx.present() == .swap_chain_resized) {
        onResize(@floatFromInt(gctx.swapchain_descriptor.width), @floatFromInt(gctx.swapchain_descriptor.height));
    }

    back_buffer.release();
    encoder.release();
    commands.release();
}

fn onResize(w: f32, h: f32) void {
    camera.screen_width = w;
    camera.screen_height = h;
    camera.clip_scale_x = 2.0 / w;
    camera.clip_scale_y = 2.0 / h;

    minimap_decor.x = camera.screen_width - minimap_decor.image_data.normal.width() - 10;
    inventory_decor.x = camera.screen_width - inventory_decor.image_data.normal.width() - 10;
    inventory_decor.y = camera.screen_height - inventory_decor.image_data.normal.height() - 10;
    bars_decor.x = (camera.screen_width - bars_decor.image_data.normal.width()) / 2;
    bars_decor.y = camera.screen_height - bars_decor.image_data.normal.height() - 10;
    const chat_decor_h = chat_decor.image_data.normal.height();
    chat_decor.y = camera.screen_height - chat_decor_h - chat_input.imageData().normal.height() - 10;
    chat_input.y = chat_decor.y + chat_decor_h;
    fps_text.y = minimap_decor.y + minimap_decor.image_data.normal.height() + 10;
}

fn networkTick(allocator: std.mem.Allocator) void {
    while (tick_network) {
        std.time.sleep(100 * std.time.ns_per_ms);

        if (selected_server) |sel_srv| {
            if (server == null)
                server = network.Server.init(sel_srv.dns, sel_srv.port); // dialog maybe

            if (server) |*srv| {
                if (selected_char_id != 65535 and !sent_hello) {
                    srv.sendHello(
                        settings.build_version,
                        -2,
                        current_account.email,
                        current_account.password,
                        @as(i16, @intCast(selected_char_id)),
                        char_create_type != 0,
                        char_create_type,
                        char_create_skin_type,
                    );
                    sent_hello = true;
                }

                srv.accept(allocator);
            }
        }
    }
}

fn renderTick(allocator: std.mem.Allocator) void {
    while (tick_render) {
        updateUi(allocator) catch |e| {
            std.log.err("UI update failed: {any}", .{e});
        };

        draw();
    }
}

pub fn clear() void {
    map.local_player_id = -1;
    map.interactive_id.store(-1, .Release);
    map.dispose(_allocator);
    map.entities.clear();
}

pub fn disconnect() void {
    if (server) |*srv| {
        srv.deinit();
        server = null;
        selected_server = null;
        sent_hello = false;
    }

    clear();
    input.reset();

    current_screen = .char_select;
}

fn initUi(allocator: std.mem.Allocator) !void {
    minimap_decor = try allocator.create(ui.Image);
    const minimap_data = (assets.ui_atlas_data.get("minimap") orelse @panic("Could not find minimap in ui atlas"))[0];
    minimap_decor.* = ui.Image{
        .x = camera.screen_width - minimap_data.texWRaw() - 10,
        .y = 10,
        .image_data = .{ .normal = .{
            .atlas_data = minimap_data,
        } },
    };
    try ui.ui_images.add(minimap_decor);

    inventory_decor = try allocator.create(ui.Image);
    const inventory_data = (assets.ui_atlas_data.get("playerInventory") orelse @panic("Could not find playerInventory in ui atlas"))[0];
    inventory_decor.* = ui.Image{
        .x = camera.screen_width - inventory_data.texWRaw() - 10,
        .y = camera.screen_height - inventory_data.texHRaw() - 10,
        .image_data = .{ .normal = .{
            .atlas_data = inventory_data,
        } },
    };
    try ui.ui_images.add(inventory_decor);

    bars_decor = try allocator.create(ui.Image);
    const bars_data = (assets.ui_atlas_data.get("playerStatusBarsDecor") orelse @panic("Could not find playerStatusBarsDecor in ui atlas"))[0];
    bars_decor.* = ui.Image{
        .x = (camera.screen_width - bars_data.texWRaw()) / 2,
        .y = camera.screen_height - bars_data.texHRaw() - 10,
        .image_data = .{ .normal = .{
            .atlas_data = bars_data,
        } },
    };
    try ui.ui_images.add(bars_decor);

    chat_decor = try allocator.create(ui.Image);
    const chat_data = (assets.ui_atlas_data.get("chatboxBackground") orelse @panic("Could not find chatboxBackground in ui atlas"))[0];
    const input_data = (assets.ui_atlas_data.get("chatboxInput") orelse @panic("Could not find chatboxInput in ui atlas"))[0];
    chat_decor.* = ui.Image{
        .x = 10,
        .y = camera.screen_height - chat_data.texHRaw() - input_data.texHRaw() - 10,
        .image_data = .{ .normal = .{
            .atlas_data = chat_data,
        } },
    };
    try ui.ui_images.add(chat_decor);

    chat_input = try allocator.create(ui.InputField);
    const input_text = ui.Text{
        .text = try std.fmt.allocPrint(allocator, "", .{}),
        .size = 12,
        .text_type = .bold,
    };
    chat_input.* = ui.InputField{
        .x = chat_decor.x,
        .y = chat_decor.y + chat_decor.image_data.normal.height(),
        .text_inlay_x = 9,
        .text_inlay_y = 8,
        .base_decor_data = .{ .normal = .{ .atlas_data = input_data } },
        .text = input_text,
        .allocator = allocator,
        .enter_callback = chatCallback,
    };
    try ui.input_fields.add(chat_input);

    fps_text = try allocator.create(ui.UiText);
    const text = ui.Text{
        .text = try std.fmt.allocPrint(stack_allocator, "FPS: {d:.1}\nMemory: {d} MB", .{ gctx.stats.fps, -1 }),
        .size = 12,
        .text_type = .bold,
    };
    fps_text.* = ui.UiText{
        .x = camera.screen_width - text.width() - 10,
        .y = minimap_decor.y + minimap_decor.image_data.normal.height() + 10,
        .text = text,
    };
    try ui.ui_texts.add(fps_text);
}

fn chatCallback(input_text: []u8) void {
    if (server) |*srv| {
        srv.sendPlayerText(input_text);
    }
}

fn deinitUi(allocator: std.mem.Allocator) void {
    allocator.destroy(minimap_decor);
    allocator.destroy(inventory_decor);
    allocator.destroy(bars_decor);
    allocator.destroy(chat_decor);
    allocator.destroy(chat_input);
    allocator.destroy(fps_text);
}

pub fn main() !void {
    if (settings.enable_tracy) {
        // needed for tracy to register
        const main_zone = ztracy.ZoneNC(@src(), "Main Zone", 0x00FF0000);
        defer main_zone.End();
    }

    const start_time = std.time.milliTimestamp();
    utils.rng.seed(@as(u64, @intCast(start_time)));

    const is_debug = builtin.mode == .Debug;
    var gpa = if (is_debug) std.heap.GeneralPurposeAllocator(.{}){} else {};
    defer _ = if (is_debug) gpa.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        .ReleaseSafe => std.heap.c_allocator,
        .ReleaseFast, .ReleaseSmall => std.heap.raw_c_allocator,
    };
    _allocator = allocator; // hack because passing it to input is convoluted

    var buf: [std.math.maxInt(u16)]u8 = undefined;
    fba = std.heap.FixedBufferAllocator.init(&buf);
    stack_allocator = fba.allocator();

    zglfw.init() catch |e| {
        std.log.err("Failed to initialize GLFW library: {any}", .{e});
        return;
    };
    defer zglfw.terminate();

    zstbi.init(allocator);
    defer zstbi.deinit();

    zaudio.init(allocator);
    defer zaudio.deinit();

    try assets.init(allocator);
    defer assets.deinit(allocator);

    try game_data.init(allocator);
    defer game_data.deinit(allocator);

    settings.init();
    defer settings.save();

    requests.init(allocator);
    defer requests.deinit();

    try map.init(allocator);
    defer map.deinit(allocator);

    try ui.init(allocator);
    defer ui.deinit(allocator);

    const window = zglfw.Window.create(1280, 720, "Client", null) catch |e| {
        std.log.err("Failed to create window: {any}", .{e});
        return;
    };
    defer window.destroy();
    window.setSizeLimits(1280, 720, -1, -1);
    window.setCursor(switch (settings.selected_cursor) {
        .basic => assets.default_cursor,
        .royal => assets.royal_cursor,
        .ranger => assets.ranger_cursor,
        .aztec => assets.aztec_cursor,
        .fiery => assets.fiery_cursor,
        .target_enemy => assets.target_enemy_cursor,
        .target_ally => assets.target_ally_cursor,
    });
    window.setInputMode(zglfw.InputMode.lock_key_mods, true);
    create(allocator, window) catch |e| {
        std.log.err("Failed to create state: {any}", .{e});
        return;
    };

    defer {
        zgui.backend.deinit();
        zgui.deinit();
        gctx.destroy(allocator);
    }

    render.init(gctx, allocator);

    try initUi(allocator);
    defer deinitUi(allocator);

    network_thread = try std.Thread.spawn(.{}, networkTick, .{allocator});
    defer {
        tick_network = false;
        network_thread.join();
    }

    render_thread = try std.Thread.spawn(.{}, renderTick, .{allocator});
    defer {
        tick_render = false;
        render_thread.join();
    }

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        if (tick_frame) {
            current_time = @intCast(std.time.milliTimestamp() - start_time);
            const dt = current_time - last_update;
            map.update(current_time, dt, allocator);
            ui.update(current_time, dt, allocator);
            last_update = current_time;
        }
    }

    if (!std.mem.eql(u8, current_account.name, "")) {
        defer allocator.free(current_account.name);
    }

    if (server) |*srv| {
        defer srv.deinit();
    }

    if (character_list.len > 0) {
        for (character_list) |char| {
            defer allocator.free(char.name);
        }
        defer allocator.free(character_list);
    }

    if (server_list) |srv_list| {
        for (srv_list) |srv| {
            defer allocator.free(srv.name);
            defer allocator.free(srv.dns);
        }
        defer allocator.free(srv_list);
    }
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

    current_account.name = allocator.dupeZ(u8, verify_root.getValue("Name") orelse "Guest") catch |e| {
        std.log.err("Could not dupe current account name: {any}", .{e});
        return false;
    };

    current_account.email = email;
    current_account.password = password;
    current_account.admin = verify_root.elementExists("Admin");

    const guild_node = verify_root.findChild("Guild");
    current_account.guild_name = try guild_node.?.getValueAlloc("Name", allocator, "");
    current_account.guild_rank = try guild_node.?.getValueInt("Rank", u8, 0);

    const list_response = try requests.sendCharList(email, password);
    const list_doc = try xml.Doc.fromMemory(list_response);
    defer list_doc.deinit();
    const list_root = try list_doc.getRootElement();
    next_char_id = try list_root.getAttributeInt("nextCharId", u8, 0);
    max_chars = try list_root.getAttributeInt("maxNumChars", u8, 0);

    var char_list = try utils.DynSlice(CharacterData).init(4, allocator);
    defer char_list.deinit();

    var char_iter = list_root.iterate(&.{}, "Char");
    while (char_iter.next()) |node|
        try char_list.add(try CharacterData.parse(allocator, node, try node.getAttributeInt("id", u32, 0)));

    character_list = try allocator.dupe(CharacterData, char_list.items());

    const server_root = list_root.findChild("Servers");
    if (server_root) |srv_root| {
        var server_data_list = try utils.DynSlice(ServerData).init(4, allocator);
        defer server_data_list.deinit();

        var server_iter = srv_root.iterate(&.{}, "Server");
        while (server_iter.next()) |server_node|
            try server_data_list.add(try ServerData.parse(server_node, allocator));

        server_list = try allocator.dupe(ServerData, server_data_list.items());
    }

    if (character_list.len > 0) {
        current_screen = ScreenType.char_select;
    } else {
        current_screen = ScreenType.char_creation;
    }

    return true;
}
