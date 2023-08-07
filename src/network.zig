const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");

const C2SPacketId = enum(u8) {
    player_shoot = 0,
    move = 1,
    player_text = 2,
    update_ack = 3,
    inv_swap = 4,
    use_item = 5,
    hello = 6,
    inv_drop = 7,
    pong = 8,
    teleport = 9,
    use_portal = 10,
    buy = 11,
    ground_damage = 12,
    player_hit = 13,
    enemy_hit = 14,
    aoe_ack = 15,
    shoot_ack = 16,
    other_hit = 17,
    square_hit = 18,
    goto_ack = 19,
    edit_account_list = 20,
    create_guild = 21,
    guild_remove = 22,
    guild_invite = 23,
    request_trade = 24,
    change_trade = 25,
    accept_trade = 26,
    cancel_trade = 27,
    escape = 28,
    join_guild = 29,
    change_guild_rank = 30,
    reskin = 31,
    map_hello = 32,
};

const S2CPacketId = enum(u8) {
    create_success = 0,
    text = 1,
    server_player_shoot = 2,
    damage = 3,
    update = 4,
    notification = 5,
    new_tick = 6,
    show_effect = 7,
    goto = 8,
    inv_result = 9,
    ping = 10,
    map_info = 11,
    death = 12,
    buy_result = 13,
    aoe = 14,
    account_list = 15,
    quest_obj_id = 16,
    guild_result = 17,
    ally_shoot = 18,
    enemy_shoot = 19,
    trade_requested = 20,
    trade_start = 21,
    trade_changed = 22,
    trade_done = 23,
    trade_accepted = 24,
    invited_to_guild = 25,
    play_sound = 26,
    failure = 27,
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
