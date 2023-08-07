const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
const settings = @import("settings.zig");
const requests = @import("requests.zig");
const network = @import("network.zig");
const builtin = @import("builtin");
const xml = @import("xml.zig");

pub const ServerData = struct {
    name: []const u8 = "",
    dns: []const u8 = "",
    port: u16,
    max_players: u16,
    admin_only: bool,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ServerData {
        return ServerData {
            .name = node.getValueAlloc("Name", allocator, "Unknown"),
            .dns = node.getValueAlloc("DNS", allocator, "127.0.0.1"),
            .port = node.getValueInt("Port", u16, 2050),
            .max_players = node.getValueInt("MaxPlayers", u16, 0),
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
    equipment: []u16 = &std.mem.zeroes([20]u16),

    // zig fmt: off
    pub fn parse(allocator: std.mem.Allocator, node: xml.Node, id: u32) !CharacterData {
        _ = allocator;
        const objType = node.getValueInt("ObjectType", u16, 0);
        const charData = CharacterData {
            .id = id,
            .obj_type = objType,
            .tex1 = node.getValueInt("Tex1", u32, 0),
            .tex2 = node.getValueInt("Tex2", u32, 0),
            .texture = node.getValueInt("Texture", u16, 0),
            .health_pots = node.getValueInt("HealthStackCount", i8, 0),
            .magic_pots = node.getValueInt("MagicStackCount", i8, 0),
            .has_backpack = node.getValueInt("HasBackpack", i8, 0) > 0,
            .name = assets.obj_type_to_name.get(objType) orelse "Unknown Class",
        };
        return charData;
    }
    // zig fmt: on
};

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

pub fn main() !void {
    const is_debug = builtin.mode == .Debug;
    var gpa = if (is_debug) std.heap.GeneralPurposeAllocator(.{}){} else {};
    defer _ = if (is_debug) gpa.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        .ReleaseSafe => std.heap.c_allocator,
        .ReleaseFast, .ReleaseSmall => std.heap.raw_c_allocator,
    };

    try assets.init(allocator);
    defer assets.deinit(allocator);

    settings.init();
    defer settings.save();

    requests.init(allocator);
    defer requests.deinit();

    var buf: [65536]u8 = undefined;
    fba = std.heap.FixedBufferAllocator.init(&buf);
    stack_allocator = fba.allocator();

    // parse char list later
    server = network.Server.init("127.0.0.1", 2050);

    try gk.run(.{ .init = init, .update = update, .render = render, .shutdown = shutdown, .update_rate = 10000, .window = .{
        .disable_vsync = true,
        .width = 1280,
        .height = 720,
    } });
}

fn login(allocator: std.mem.Allocator, email: []const u8, password: []const u8) void {
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
        current_account.guild_name = guild_node.?.getValueAlloc("Name", allocator, "");
        current_account.guild_rank = guild_node.?.getValueInt("Rank", u8, 0);

        const list_response = try requests.sendCharList(email, password);
        const list_doc = try xml.Doc.fromMemory(list_response);
        defer list_doc.deinit();
        const list_root = try list_doc.getRootElement();
        next_char_id = list_root.getAttributeInt("nextCharId", u8, 0);
        max_chars = list_root.getAttributeInt("maxNumChars", u8, 0);

        var char_list = std.ArrayList(CharacterData).init(allocator);
        defer char_list.deinit();

        var char_iter = list_root.iterate(&.{}, "Char");
        while (char_iter.next()) |node|
            try char_list.append(try CharacterData.parse(allocator, node, node.getAttributeInt("id", i32, 0)));

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

fn init() !void {}

fn update() !void {
    if (@mod(gk.time.frames(), 10000) == 0)
        std.log.debug("FPS: {d}\n", .{gk.time.fps()});
}

fn render() !void {}

fn shutdown() !void {}
