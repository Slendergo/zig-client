const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");

const C2SPacketId = enum(u8) {
    unknown = 0,
    accept_trade = 1,
    aoe_ack = 2,
    buy = 3,
    cancel_trade = 4,
    change_guild_rank = 5,
    change_trade = 6,
    check_credits = 7,
    choose_name = 8,
    create = 9,
    create_guild = 10,
    edit_account_list = 11,
    enemy_hit = 12,
    escape = 13,
    goto_ack = 14,
    ground_damage = 15,
    guild_invite = 16,
    guild_remove = 17,
    hello = 18,
    inv_drop = 19,
    inv_swap = 20,
    join_guild = 21,
    load = 22,
    move = 23,
    other_hit = 24,
    player_hit = 25,
    player_shoot = 26,
    player_text = 27,
    pong = 28,
    request_trade = 29,
    reskin = 30,
    set_condition = 31,
    shoot_ack = 32,
    square_hit = 33,
    teleport = 34,
    update_ack = 35,
    use_item = 36,
    use_portal = 37,
};

const S2CPacketId = enum(u8) {
    unknown = 0,
    account_list = 1,
    ally_shoot = 2,
    aoe = 3,
    buy_result = 4,
    client_stat = 5,
    create_success = 6,
    damage = 7,
    death = 8,
    enemy_shoot = 9,
    failure = 10,
    file = 11,
    global_notification = 12,
    goto = 13,
    guild_result = 14,
    inv_result = 15,
    invited_to_guild = 16,
    map_info = 17,
    name_result = 18,
    new_tick = 19,
    notification = 20,
    pic = 21,
    ping = 22,
    play_sound = 23,
    quest_obj_id = 24,
    reconnect = 25,
    server_player_shoot = 26,
    show_effect = 27,
    text = 28,
    trade_accepted = 29,
    trade_changed = 30,
    trade_done = 31,
    trade_requested = 32,
    trade_start = 33,
    update = 34,
};

pub const Server = struct {
    message_len: u16 = 65535,
    buffer_idx: usize = 0,
    stream: std.net.Stream,
    reader: utils.PacketReader,
    writer: utils.PacketWriter,

    pub fn init(ip: []const u8, port: u16) ?Server {
        var stream = std.net.tcpConnectToAddress(std.net.Address.parseIp(ip, port) catch |address_error| {
            std.log.err("Could not parse address {s}:{d}: {any}\n", .{ ip, port, address_error });
            return null;
        }) catch |connect_error| {
            std.log.err("Could not connect to address {s}:{d}: {any}\n", .{ ip, port, connect_error });
            return null;
        };

        var reader = utils.PacketReader{};
        var writer = utils.PacketWriter{};
        return Server{ .stream = stream, .reader = reader, .writer = writer };
    }

    pub fn deinit(self: *Server) void {
        self.stream.close();
    }

    pub fn hello(self: *Server, build_ver: []const u8, gameId: i32, email: []const u8, password: []const u8, char_id: i16, create_char: bool, class_type: u16, skin_type: u16) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Hello: build_ver={s}, game_id={d}, email={s}, password={s}, char_id={d}, create_char={any}, class_type={d}, skin_type={d}", .{ build_ver, gameId, email, password, char_id, create_char, class_type, skin_type });

        self.writer.write(@intFromEnum(C2SPacketId.hello));
        self.writer.write(build_ver);
        self.writer.write(gameId);
        self.writer.write(email);
        self.writer.write(password);
        self.writer.write(char_id);
        self.writer.write(create_char);
        if (create_char) {
            self.writer.write(class_type);
            self.writer.write(skin_type);
        }

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn accept(self: *Server, allocator: std.mem.Allocator) !void {
        _ = allocator;
        const size = try self.stream.read(self.reader.buffer[self.buffer_idx..]);
        self.buffer_idx += size;

        if (size < 2)
            return;

        self.reader.index = 0;
        while (self.reader.index < self.buffer_idx) {
            if (self.message_len == 65535)
                self.message_len = self.reader.read(u16);

            if (self.message_len != 65535 and self.buffer_idx - self.reader.index < self.message_len)
                return;

            const next_packet_idx = self.reader.index + self.message_len;
            const byte_id = self.reader.read(u8);
            const packet_id = std.meta.intToEnum(S2CPacketId, byte_id) catch |e| {
                std.log.err("Error parsing S2CPacketId ({any}): id={d}, size={d}, len={d}", .{ e, byte_id, self.buffer_idx, self.message_len });
                self.buffer_idx = 0;
                return;
            };
            switch (packet_id) {
                .create_success => handleCreateSuccess(&self.reader),
                else => return,
                // .text => handleText(&self.reader),
                // .server_player_shoot => try handleServerPlayerShoot(self),
                // .damage => handleDamage(&self.reader),
                // .update => handleUpdate(self),
                // .notification => handleNotification(&self.reader),
                // .new_tick => handleNewTick(self),
                // .show_effect => handleShowEffect(&self.reader),
                // .goto => handleGoto(self),
                // .inv_result => handleInvResult(&self.reader),
                // .ping => handlePing(self),
                // .map_info => handleMapInfo(&self.reader, allocator),
                // .death => handleDeath(&self.reader),
                // .buy_result => handleBuyResult(&self.reader),
                // .aoe => handleAoe(self),
                // .account_list => handleAccountList(&self.reader),
                // .quest_obj_id => handleQuestObjId(&self.reader),
                // .guild_result => handleGuildResult(&self.reader),
                // .ally_shoot => handleAllyShoot(&self.reader),
                // .enemy_shoot => handleEnemyShoot(self),
                // .trade_requested => handleTradeRequested(&self.reader),
                // .trade_start => handleTradeStart(&self.reader),
                // .trade_changed => handleTradeChanged(&self.reader),
                // .trade_done => handleTradeDone(&self.reader),
                // .trade_accepted => handleTradeAccepted(&self.reader),
                // .invited_to_guild => handleInvitedToGuild(&self.reader),
                // .play_sound => handlePlaySound(&self.reader),
                // .failure => handleFailure(self),
            }

            self.reader.index = next_packet_idx;
            self.message_len = 65535;
        }

        main.fba.reset();
        self.buffer_idx = 0;
    }

    inline fn handleCreateSuccess(reader: *utils.PacketReader) void {
        map.local_player_id = reader.read(i32);
        const char_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - CreateSuccess: player_id={d}, char_id={d}", .{ map.local_player_id, char_id });
    }
};
