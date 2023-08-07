const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
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
const ztracy = @import("ztracy");
const input = @import("input.zig");
const utils = @import("utils.zig");
const camera = @import("camera.zig");

pub const ServerData = struct {
    name: []const u8 = "",
    dns: []const u8 = "",
    port: u16,
    max_players: u16,
    admin_only: bool,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ServerData {
        return ServerData {
            .name = try node.getValueAlloc("Name", allocator, "Unknown"),
            .dns = try node.getValueAlloc("DNS", allocator, "127.0.0.1"),
            .port = try node.getValueInt("Port", u16, 2050),
            .max_players = try node.getValueInt("MaxPlayers", u16, 0),
            .admin_only = node.elementExists("AdminOnly") and std.mem.eql(u8, node.getValue("AdminOnly").?, "true")
        };
    }
    // zig fmt: on
};

pub const AccountData = struct {
    name: []const u8 = "Guest",
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
    name: []const u8 = "",
    health: u16 = 100,
    mana: u16 = 0,
    tex1: u32 = 0,
    tex2: u32 = 0,
    texture: u16 = 0,
    health_pots: i8 = 0,
    magic_pots: i8 = 0,
    has_backpack: bool = false,
    equipment: [20]u16 = std.mem.zeroes([20]u16),

    // zig fmt: off
    pub fn parse(allocator: std.mem.Allocator, node: xml.Node, id: u32) !CharacterData {
        _ = allocator;
        const objType = try node.getValueInt("ObjectType", u16, 0);
        const charData = CharacterData {
            .id = id,
            .obj_type = objType,
            .tex1 = try node.getValueInt("Tex1", u32, 0),
            .tex2 = try node.getValueInt("Tex2", u32, 0),
            .texture = try node.getValueInt("Texture", u16, 0),
            .health_pots = try node.getValueInt("HealthStackCount", i8, 0),
            .magic_pots = try node.getValueInt("MagicStackCount", i8, 0),
            .has_backpack = try node.getValueInt("HasBackpack", i8, 0) > 0,
            .name = assets.obj_type_to_name.get(objType) orelse "Unknown Class",
        };
        return charData;
    }
    // zig fmt: on
};

pub const ScreenType = enum(u8) { main_menu, char_select, map_editor, in_game };

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
pub var selected_server: ?ServerData = null;
pub var next_char_id: u32 = 0;
pub var max_chars: u32 = 0;
pub var current_time: i32 = 0;
pub var last_update: i32 = 0;
pub var network_thread: std.Thread = undefined;
pub var network_lock: std.Thread.Mutex = .{};
pub var tick_network = true;
pub var render_thread: std.Thread = undefined;
pub var tick_render = true;
pub var tick_frame = false;
pub var sent_hello = false;

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !void {
    gctx = try zgpu.GraphicsContext.create(allocator, window, .{ .present_mode = .immediate });
    _ = window.setKeyCallback(input.keyEvent);
    _ = window.setCursorPosCallback(input.mouseMoveEvent);
    _ = window.setMouseButtonCallback(input.mouseEvent);

    zgui.init(allocator);
    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const font_size = 16.0 * scale_factor;
    const font_large = zgui.io.addFontFromMemory(embedded_font_data, @floor(font_size * 1.1));
    const font_normal = zgui.io.addFontFromFile(asset_dir ++ "fonts/Ubuntu-Bold.ttf", @floor(font_size));
    std.debug.assert(zgui.io.getFont(0) == font_large);
    std.debug.assert(zgui.io.getFont(1) == font_normal);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.initWithConfig(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        .{ .texture_filter_mode = .linear, .pipeline_multisample_count = 1 },
    );

    // This call is optional. Initially, zgui.io.getFont(0) is a default font.
    zgui.io.setDefaultFont(font_normal);

    // You can directly manipulate zgui.Style *before* `newFrame()` call.
    // Once frame is started (after `newFrame()` call) you have to use
    // zgui.pushStyleColor*()/zgui.pushStyleVar*() functions.
    const style = zgui.getStyle();

    style.anti_aliased_fill = true;
    style.anti_aliased_lines = true;
    style.window_min_size = .{ 500.0, 200.0 };
    style.window_border_size = 2.0;
    style.scrollbar_size = 8.0;
    {
        var color = style.getColor(.scrollbar_grab);
        color[1] = 0.8;
        style.setColor(.scrollbar_grab, color);
    }
    style.scaleAllSizes(scale_factor);

    // To reset zgui.Style with default values:
    //zgui.getStyle().* = zgui.Style.init();
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
            if (zgui.begin("Login Window", .{})) {
                const static = struct {
                    var email_buf: [128]u8 = undefined;
                    var password_buf: [128]u8 = undefined;
                };

                _ = zgui.inputText("E-mail", .{ .buf = static.email_buf[0..] });
                _ = zgui.inputText("Password", .{ .buf = static.password_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });
                if (zgui.button("Login", .{ .w = 150.0 })) {
                    const email = static.email_buf[0..utils.strlen(static.email_buf[0..])];
                    const password = static.password_buf[0..utils.strlen(static.password_buf[0..])];
                    try login(allocator, email, password);
                }
            }
            zgui.end();

            if (zgui.begin("Register Window", .{})) {
                const static = struct {
                    var username_buf: [128]u8 = undefined;
                    var email_buf: [128]u8 = undefined;
                    var password_buf: [128]u8 = undefined;
                    var confirm_pw_buf: [128]u8 = undefined;
                };

                _ = zgui.inputText("Name", .{ .buf = static.username_buf[0..] });
                _ = zgui.inputText("E-mail", .{ .buf = static.email_buf[0..] });
                _ = zgui.inputText("Password", .{ .buf = static.password_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });
                _ = zgui.inputText("Confirm Password", .{ .buf = static.confirm_pw_buf[0..], .flags = zgui.InputTextFlags{ .password = true } });

                if (zgui.button("Register", .{ .w = 150.0 })) {
                    const name = static.username_buf[0..utils.strlen(static.username_buf[0..])];
                    const email = static.email_buf[0..utils.strlen(static.email_buf[0..])];
                    const password = static.password_buf[0..utils.strlen(static.password_buf[0..])];
                    const response = try requests.sendAccountRegister(email, password, name);
                    if (std.mem.indexOf(u8, "<Success />", response) != null) {
                        try login(allocator, email, password);
                    }
                }
            }
            zgui.end();
        },
        ScreenType.char_select => {
            if (zgui.begin("Character Select", .{})) {
                const static = struct {
                    var char_index: u32 = 0;
                    var server_index: u32 = 0;
                };

                zgui.text("Logged in as [{s}]", .{current_account.name});
                if (zgui.beginListBox("Character", .{})) {
                    for (character_list, 0..) |char, index| {
                        const i: u32 = @intCast(index);
                        if (zgui.selectable(char.name[0.. :0], .{ .selected = static.char_index == i }))
                            static.char_index = i;
                    }
                    zgui.endListBox();
                }

                if (server_list == null) {
                    zgui.text("No servers available", .{});
                } else if (zgui.beginListBox("Server", .{})) {
                    for (server_list.?, 0..) |serverData, index| {
                        const i: u32 = @intCast(index);
                        if (zgui.selectable(serverData.name[0.. :0], .{ .selected = static.server_index == i }))
                            static.server_index = i;
                    }
                    zgui.endListBox();
                }

                if (zgui.button("Play", .{ .w = 150.0 })) {
                    current_screen = ScreenType.in_game;
                    selected_char_id = character_list[static.char_index].id;
                    if (server_list != null)
                        selected_server = server_list.?[static.server_index];
                }
            }
            zgui.end();
        },
        ScreenType.map_editor => {},
        ScreenType.in_game => {
            if (zgui.begin("Debug", .{})) {
                zgui.bulletText(
                    "{d:.3} ms/frame ({d:.1} fps)\n",
                    .{ gctx.stats.average_cpu_time, gctx.stats.fps },
                );

                const static = struct {
                    var text_buf: [128]u8 = std.mem.zeroes([128]u8);
                };

                _ = zgui.inputText("Text", .{ .buf = static.text_buf[0..] });

                if (zgui.button("Send message", .{ .w = 150.0 })) {
                    // if (server != null) {
                    //     server.?.playerText(static.text_buf[0..utils.strlen(static.text_buf[0..])]) catch |e| {
                    //         std.log.err("Can't send player text: {any}", .{e});
                    //     };
                    // }
                    static.text_buf = std.mem.zeroes([128]u8);
                }
            }
            zgui.end();
        },
    }
}

inline fn draw() void {
    const back_buffer = gctx.swapchain.getCurrentTextureView();
    const encoder = gctx.device.createCommandEncoder(null);

    // if (current_screen == .in_game and tick_frame) {
    //     render.draw(current_time, gctx, back_buffer, encoder);
    // }

    const ui_draw_zone = ztracy.ZoneNC(@src(), "Drawing UI", 0x00FF0000);
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
    ui_draw_zone.End();

    const command_submit_zone = ztracy.ZoneNC(@src(), "Submitting Commands", 0x00FF0000);
    const commands = encoder.finish(null);
    gctx.submit(&.{commands});
    if (gctx.present() == .swap_chain_resized) {
        const float_w: f32 = @floatFromInt(gctx.swapchain_descriptor.width);
        const float_h: f32 = @floatFromInt(gctx.swapchain_descriptor.height);
        camera.screen_width = float_w;
        camera.screen_height = float_h;
        camera.clip_scale_x = 2.0 / float_w;
        camera.clip_scale_y = 2.0 / float_h;
    }
    command_submit_zone.End();

    back_buffer.release();
    encoder.release();
    commands.release();
}

fn networkTick(allocator: std.mem.Allocator) void {
    while (tick_network) {
        std.time.sleep(101 * std.time.ns_per_ms);

        if (selected_server != null) {
            network_lock.lock();
            defer network_lock.unlock();

            if (server == null)
                server = network.Server.init(selected_server.?.dns, selected_server.?.port); // dialog maybe

            if (server != null) {
                if (selected_char_id != 65535 and !sent_hello) {
                    server.?.hello(settings.build_version, -2, current_account.email, current_account.password, @as(i16, @intCast(selected_char_id)), false, 0, 0) catch |e| {
                        std.log.err("Could not send Hello: {any}", .{e});
                    };
                    sent_hello = true;
                }

                server.?.accept(allocator) catch |e| {
                    std.log.err("Error while accepting server packets: {any}\n", .{e});
                };
            }
        }
    }
}

fn renderTick(allocator: std.mem.Allocator) void {
    while (tick_render) {
        const ui_update_zone = ztracy.ZoneNC(@src(), "UI Update", 0x00FF0000);
        updateUi(allocator) catch |e| {
            std.log.err("UI update failed: {any}", .{e});
        };
        ui_update_zone.End();

        const draw_zone = ztracy.ZoneNC(@src(), "Draw", 0x00FF0000);
        draw();
        draw_zone.End();
    }
}

pub fn main() !void {
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

    zstbi.init(allocator);
    defer zstbi.deinit();

    try assets.init(allocator);
    defer assets.deinit(allocator);

    settings.init();
    defer settings.save();

    requests.init(allocator);
    defer requests.deinit();

    var buf: [65536]u8 = undefined;
    fba = std.heap.FixedBufferAllocator.init(&buf);
    stack_allocator = fba.allocator();

    zglfw.init() catch |e| {
        std.log.err("Failed to initialize GLFW library: {any}", .{e});
        return;
    };
    defer zglfw.terminate();

    const window = zglfw.Window.create(1280, 720, "Client", null) catch |e| {
        std.log.err("Failed to create window: {any}", .{e});
        return;
    };
    defer window.destroy();
    window.setSizeLimits(1280, 720, -1, -1);

    create(allocator, window) catch |e| {
        std.log.err("Failed to create state: {any}", .{e});
        return;
    };

    if (!std.mem.eql(u8, "Guest", current_account.name)) {
        defer allocator.free(current_account.name);
    }

    network_thread = try std.Thread.spawn(.{}, networkTick, .{allocator});
    defer {
        tick_network = false;
        network_thread.join();
        if (server != null) {
            server.?.deinit();
        }
    }

    render_thread = try std.Thread.spawn(.{}, renderTick, .{allocator});
    defer {
        tick_render = false;
        render_thread.join();

        if (character_list.len > 0) {
            for (character_list) |char| {
                allocator.free(char.name);
            }
            allocator.free(character_list);
        }

        if (server_list != null) {
            for (server_list.?) |srv| {
                allocator.free(srv.name);
                allocator.free(srv.dns);
            }
            allocator.free(server_list.?);
        }
    }

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const update_zone = ztracy.ZoneNC(@src(), "Map Update", 0x00FF0000);
        if (tick_frame) {
            current_time = @intCast(std.time.milliTimestamp() - start_time);
            const dt = current_time - last_update;
            _ = dt;
            // map.update(current_time, dt, allocator);
            // ui.update(current_time, dt, allocator);
            last_update = current_time;
        }
        update_zone.End();
    }
}

fn login(allocator: std.mem.Allocator, email: []const u8, password: []const u8) !void {
    const response = try requests.sendAccountVerify(email, password);

    const verify_doc = try xml.Doc.fromMemory(response);
    defer verify_doc.deinit();
    const verify_root = try verify_doc.getRootElement();

    current_account.name = allocator.dupe(u8, verify_root.getValue("Name") orelse "Guest") catch |e| {
        std.debug.print("Could not dupe current account name: {any}", .{e});
        return;
    };

    if (!std.mem.eql(u8, current_account.name, "Guest")) {
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

        var char_list = std.ArrayList(CharacterData).init(allocator);
        defer char_list.deinit();

        var char_iter = list_root.iterate(&.{}, "Char");
        while (char_iter.next()) |node|
            try char_list.append(try CharacterData.parse(allocator, node, try node.getAttributeInt("id", u32, 0)));

        character_list = try allocator.dupe(CharacterData, char_list.items);

        const server_root = list_root.findChild("Servers");
        if (server_root != null) {
            var server_data_list = std.ArrayList(ServerData).init(allocator);
            defer server_data_list.deinit();

            var server_iter = server_root.?.iterate(&.{}, "Server");
            while (server_iter.next()) |server_node|
                try server_data_list.append(try ServerData.parse(server_node, allocator));

            server_list = try allocator.dupe(ServerData, server_data_list.items);
        }
    }
}
