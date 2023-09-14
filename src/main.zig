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
const zstbi = @import("zstbi");
const input = @import("input.zig");
const utils = @import("utils.zig");
const camera = @import("camera.zig");
const map = @import("map.zig");
const ui = @import("ui/ui.zig");
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
            .name = try allocator.dupe(u8, game_data.obj_type_to_name.get(obj_type) orelse "Unknown Class"),
        };
    }
};

const embedded_font_data = @embedFile(asset_dir ++ "fonts/Ubuntu-Medium.ttf");

pub var gctx: *zgpu.GraphicsContext = undefined;
pub var fba: std.heap.FixedBufferAllocator = undefined;
pub var stack_allocator: std.mem.Allocator = undefined;
pub var stack_minimap_allocator: std.mem.Allocator = undefined;
pub var current_account = AccountData{};
pub var character_list: []CharacterData = undefined;
pub var server_list: ?[]ServerData = null;
pub var selected_char_id: u32 = 65535;
pub var char_create_type: u16 = 0;
pub var char_create_skin_type: u16 = 0;
pub var selected_server: ?ServerData = null;
pub var next_char_id: u32 = 0;
pub var max_chars: u32 = 0;
pub var current_time: i64 = 0;
pub var last_update: i64 = 0;
pub var network_thread: std.Thread = undefined;
pub var tick_network = true;
pub var render_thread: std.Thread = undefined;
pub var tick_render = true;
pub var tick_frame = false;
pub var sent_hello = false;
pub var need_minimap_update = false;
pub var need_force_update = false;
pub var minimap_update_min_x: u32 = 4096;
pub var minimap_update_max_x: u32 = 0;
pub var minimap_update_min_y: u32 = 4096;
pub var minimap_update_max_y: u32 = 0;
pub var chat_history: std.ArrayList([]const u8) = undefined;
pub var chat_history_idx: u16 = 65535;
pub var _allocator: std.mem.Allocator = undefined;

fn onResize(window: *zglfw.Window, w: i32, h: i32) callconv(.C) void {
    _ = window;

    const float_w: f32 = @floatFromInt(w);
    const float_h: f32 = @floatFromInt(h);

    camera.screen_width = float_w;
    camera.screen_height = float_h;
    camera.clip_scale_x = 2.0 / float_w;
    camera.clip_scale_y = 2.0 / float_h;

    ui.resize(float_w, float_h);
}

fn networkTick(allocator: std.mem.Allocator) void {
    while (tick_network) {
        std.time.sleep(100 * std.time.ns_per_ms);

        if (selected_server) |sel_srv| {
            if (!network.connected)
                network.init(sel_srv.dns, sel_srv.port);

            if (network.connected) {
                if (selected_char_id != 65535 and !sent_hello) {
                    network.sendHello(
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

                network.accept(allocator);
            }
        }
    }
}

fn renderTick(allocator: std.mem.Allocator) !void {
    _ = allocator;
    while (tick_render) {
        const back_buffer = gctx.swapchain.getCurrentTextureView();
        const encoder = gctx.device.createCommandEncoder(null);

        render.draw(current_time, gctx, back_buffer, encoder);

        const commands = encoder.finish(null);
        gctx.submit(&.{commands});
        _ = gctx.present();

        back_buffer.release();
        encoder.release();
        commands.release();

        // this has to be updated on render thread to avoid headaches (gctx sharing)
        try ui.in_game_screen.updateFpsText(gctx.stats.fps, try utils.currentMemoryUse());

        if (need_minimap_update) {
            const w = minimap_update_max_x - minimap_update_min_x;
            const h = minimap_update_max_y - minimap_update_min_y;
            const comp_len = map.minimap.num_components * map.minimap.bytes_per_component;
            var copy = stack_minimap_allocator.alloc(u8, w * h * comp_len) catch @panic("Minimap alloc failed");
            defer stack_minimap_allocator.free(copy);

            var idx: u32 = 0;
            for (minimap_update_min_y..minimap_update_max_y) |y| {
                const base_map_idx = y * map.minimap.width * comp_len + minimap_update_min_x * comp_len;
                @memcpy(
                    copy[idx * w * comp_len .. (idx + 1) * w * comp_len],
                    map.minimap.data[base_map_idx .. base_map_idx + w * comp_len],
                );
                idx += 1;
            }

            gctx.queue.writeTexture(
                .{
                    .texture = gctx.lookupResource(render.minimap_texture).?,
                    .origin = .{
                        .x = minimap_update_min_x,
                        .y = minimap_update_min_y,
                    },
                },
                .{
                    .bytes_per_row = comp_len * w,
                    .rows_per_image = h,
                },
                .{
                    .width = w,
                    .height = h,
                },
                u8,
                copy,
            );

            need_minimap_update = false;
            minimap_update_min_x = 4096;
            minimap_update_max_x = 0;
            minimap_update_min_y = 4096;
            minimap_update_max_y = 0;
        } else if (need_force_update) {
            gctx.queue.writeTexture(
                .{
                    .texture = gctx.lookupResource(render.minimap_texture).?,
                },
                .{
                    .bytes_per_row = map.minimap.bytes_per_row,
                    .rows_per_image = map.minimap.height,
                },
                .{
                    .width = map.minimap.width,
                    .height = map.minimap.height,
                },
                u8,
                map.minimap.data,
            );
            need_force_update = false;
        }
    }
}

pub fn clear() void {
    map.dispose(_allocator);
    need_force_update = true;
}

pub fn disconnect() void {
    if (network.connected) {
        network.deinit();
        selected_server = null;
        sent_hello = false;
    }

    clear();
    input.reset();

    ui.switchScreen(.char_select);
}

pub fn main() !void {
    if (settings.enable_tracy) {
        // needed for tracy to register
        const main_zone = ztracy.ZoneNC(@src(), "Main Zone", 0x00FF0000);
        defer main_zone.End();
    }

    const start_time = std.time.microTimestamp();
    utils.rng.seed(@as(u64, @intCast(start_time)));

    const is_debug = builtin.mode == .Debug;
    var gpa = if (is_debug) std.heap.GeneralPurposeAllocator(.{}){} else {};
    defer _ = if (is_debug) gpa.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        .ReleaseSafe => std.heap.c_allocator,
        .ReleaseFast, .ReleaseSmall => std.heap.raw_c_allocator,
    };
    _allocator = allocator;

    var buf: [std.math.maxInt(u16)]u8 = undefined;
    fba = std.heap.FixedBufferAllocator.init(&buf);
    stack_allocator = fba.allocator();

    var buf_minimap: [40 * 40 * 4]u8 = undefined;
    var fba_minimap = std.heap.FixedBufferAllocator.init(&buf_minimap);
    stack_minimap_allocator = fba_minimap.allocator();

    chat_history = std.ArrayList([]const u8).init(allocator);

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

    ui.switchScreen(.main_menu);

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

    gctx = zgpu.GraphicsContext.create(
        allocator,
        window,
        .{ .present_mode = if (settings.enable_vsync) .fifo else .immediate },
    ) catch |e| {
        std.log.err("Failed to create graphics context: {any}", .{e});
        return;
    };
    defer gctx.destroy(allocator);

    _ = window.setKeyCallback(input.keyEvent);
    _ = window.setCharCallback(input.charEvent);
    _ = window.setCursorPosCallback(input.mouseMoveEvent);
    _ = window.setMouseButtonCallback(input.mouseEvent);
    _ = window.setScrollCallback(input.scrollEvent);
    _ = window.setFramebufferSizeCallback(onResize);

    render.init(gctx, allocator);
    defer render.deinit(allocator);

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
        current_time = std.time.microTimestamp() - start_time;
        if (current_time - last_update >= 7 * std.time.us_per_ms) {
            zglfw.pollEvents();

            if (tick_frame) {
                const dt = current_time - last_update;
                map.update(current_time, dt, allocator);
                try ui.update(current_time, dt, allocator);
            }

            last_update = current_time;
        }
    }

    if (!std.mem.eql(u8, current_account.name, "")) {
        defer allocator.free(current_account.name);
    }

    if (network.connected) {
        defer network.deinit();
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

    defer {
        for (chat_history.items) |msg| {
            allocator.free(msg);
        }
        chat_history.deinit();
    }
}
