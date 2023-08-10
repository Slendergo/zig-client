const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");

const Position = extern struct { x: f32, y: f32 };

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
                .account_list => handleAccountList(&self.reader),
                .ally_shoot => handleAllyShoot(&self.reader),
                .aoe => handleAoe(&self.reader),
                .buy_result => handleBuyResult(&self.reader),
                // .client_stat => handleClientStat(&self.reader),
                .create_success => handleCreateSuccess(&self.reader),
                .damage => handleDamage(&self.reader),
                .death => handleDeath(&self.reader),
                .enemy_shoot => handleEnemyShoot(&self.reader),
                .failure => handleFailure(&self.reader),
                // .file => handleFile(&self.reader),
                .global_notification => handleGlobalNotification(&self.reader),
                .goto => handleGoto(&self.reader),
                .invited_to_guild => handleInvitedToGuild(&self.reader),
                .inv_result => handleInvResult(&self.reader),
                .map_info => handleMapInfo(&self.reader),
                .name_result => handleNameResult(&self.reader),
                .new_tick => handleNewTick(&self.reader),
                .notification => handleNotification(&self.reader),
                // .pic => handlePic(&self.reader),
                .ping => handlePing(&self.reader),
                .play_sound => handlePlaySound(&self.reader),
                .quest_obj_id => handleQuestObjId(&self.reader),
                //.reconnect => handleReconnect(&self.reader),
                .server_player_shoot => handleServerPlayerShoot(&self.reader),
                //.show_effect => handleShowEffect(&self.reader),
                .text => handleText(&self.reader),
                .trade_accepted => handleTradeAccepted(&self.reader),
                .trade_changed => handleTradeChanged(&self.reader),
                .trade_done => handleTradeDone(&self.reader),
                .trade_requested => handleTradeRequested(&self.reader),
                .trade_start => handleTradeStart(&self.reader),
                .update => handleUpdate(&self.reader),
                else => {
                    std.log.err("Unknown S2CPacketId: id={d}, size={d}, len={d}", .{ byte_id, self.buffer_idx, self.message_len });
                    self.buffer_idx = 0;
                    return;
                },
            }

            self.reader.index = next_packet_idx;
            self.message_len = 65535;
        }

        main.fba.reset();
        self.buffer_idx = 0;
    }

    inline fn handleAccountList(reader: *utils.PacketReader) void {
        const account_list_id = reader.read(i32);
        const account_ids = reader.read([]i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - AccountList: account_list_id={d}, account_ids={d}", .{ account_list_id, account_ids });
    }

    inline fn handleAllyShoot(reader: *utils.PacketReader) void {
        const bullet_id = reader.read(i8);
        const owner_id = reader.read(i32);
        const container_type = reader.read(u16);
        const angle = reader.read(f32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - AllyShoot: bullet_id={d}, owner_id={d}, container_type={d}, angle={e}", .{ bullet_id, owner_id, container_type, angle });
    }

    inline fn handleAoe(reader: *utils.PacketReader) void {
        const position = reader.read(Position);
        const radius = reader.read(f32);
        const damage = reader.read(i16);
        const condition_effect = 0; // handle cond effect
        const duration = reader.read(f32);
        const orig_type = reader.read(u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - Aoe: x={e}, y={e}, radius={e}, damage={d}, condition_effect={d}, duration={e}, orig_type={d}", .{ position.x, position.y, radius, damage, condition_effect, duration, orig_type });
    }

    inline fn handleBuyResult(reader: *utils.PacketReader) void {
        const result = reader.read(i32);
        const message = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - BuyResult: result={d}, message={s}", .{ result, message });
    }

    inline fn handleCreateSuccess(reader: *utils.PacketReader) void {
        map.local_player_id = reader.read(i32);
        const char_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - CreateSuccess: player_id={d}, char_id={d}", .{ map.local_player_id, char_id });
    }

    inline fn handleDamage(reader: *utils.PacketReader) void {
        const target_id = reader.read(i32);
        const effects = 0; // handle cond effect
        const damage_amount = reader.read(u16);
        const kill = reader.read(bool);
        const bullet_id = reader.read(i8);
        const object_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - Damage: target_id={d}, effects={d}, damage_amount={d}, kill={d}, bullet_id={d}, object_id={d}", .{ target_id, effects, damage_amount, kill, bullet_id, object_id });
    }

    inline fn handleDeath(reader: *utils.PacketReader) void {
        const account_id = reader.read(i32);
        const char_id = reader.read(i32);
        const killed_by = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Death: account_id={d}, char_id={d}, killed_by={s}", .{ account_id, char_id, killed_by });
    }

    inline fn handleEnemyShoot(reader: *utils.PacketReader) void {
        const bullet_id = reader.read(i8);
        const owner_id = reader.read(i32);
        const bullet_type = reader.read(u8);
        const starting_pos = reader.read(Position);
        const angle = reader.read(f32);
        const damage = reader.read(u16);
        const num_shots = reader.read(u8);
        const angle_inc = reader.read(f32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - EnemyShoot: bullet_id={d}, owner_id={d}, bullet_type={d}, x={e}, y={e}, angle={e}, damage={d}, num_shots={d}, angle_inc={e}", .{ bullet_id, owner_id, bullet_type, starting_pos.x, starting_pos.y, angle, damage, num_shots, angle_inc });
    }

    inline fn handleFailure(reader: *utils.PacketReader) void {
        const error_id = reader.read(i32);
        const error_description = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Failure: error_id={d}, error_description={s}", .{ error_id, error_description });
    }

    inline fn handleGlobalNotification(reader: *utils.PacketReader) void {
        const notif_type = reader.read(i32);
        const text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - GlobalNotification: type={d}, text={s}", .{ notif_type, text });
    }

    inline fn handleGoto(reader: *utils.PacketReader) void {
        const object_id = reader.read(i32);
        const position = reader.read(Position);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Goto: object_id={d}, x={e}, y={e}", .{ object_id, position.x, position.y });
    }

    inline fn handleGuildResult(reader: *utils.PacketReader) void {
        const success = reader.read(bool);
        const error_text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - GuildResult: success={d}, error_text={s}", .{ success, error_text });
    }

    inline fn handleInvitedToGuild(reader: *utils.PacketReader) void {
        const guild_name = reader.read([]u8);
        const name = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - InvitedToGuild: guild_name={s}, name={s}", .{ guild_name, name });
    }

    inline fn handleInvResult(reader: *utils.PacketReader) void {
        const result = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - InvResult: result={d}", .{result});
    }

    inline fn handleMapInfo(reader: *utils.PacketReader) void {
        const width = reader.read(i32);
        const height = reader.read(i32);
        const name = reader.read([]u8);
        const display_name = reader.read([]u8);
        const difficulty = reader.read(i32);
        const seed = reader.read(u32);
        const background = reader.read(i32);
        const allow_player_teleport = reader.read(bool);
        const show_displays = reader.read(bool);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - MapInfo: width={d}, height={d}, name={s}, display_name={s}, difficulty={d}, seed={d}, background={d}, allow_player_teleport={d}, show_displays={d}", .{ width, height, name, display_name, difficulty, seed, background, allow_player_teleport, show_displays });
    }

    inline fn handleNameResult(reader: *utils.PacketReader) void {
        const success = reader.read(bool);
        const error_text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - NameResult: success={d}, error_text={s}", .{ success, error_text });
    }

    inline fn handleNewTick(reader: *utils.PacketReader) void {
        const tick_id = reader.read(i32);
        const tick_time = reader.read(i32);
        const statuses = 0; // handle statuses

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
            std.log.debug("Recv - NewTick: tick_id={d}, tick_time={d}, statuses={v}", .{ tick_id, tick_time, statuses });
    }

    inline fn handleNotification(reader: *utils.PacketReader) void {
        const object_id = reader.read(i32);
        const message = reader.read([]u8);
        const color = 0; // handle color

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Notification: object_id={d}, message={s}, color={d}", .{ object_id, message, color });
    }

    inline fn handlePing(reader: *utils.PacketReader) void {
        const serial = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
            std.log.debug("Recv - Ping: serial={d}", .{serial});
    }

    inline fn handlePlaySound(reader: *utils.PacketReader) void {
        const owner_id = reader.read(i32);
        const sound_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - PlaySound: owner_id={d}, sound_id={d}", .{ owner_id, sound_id });
    }

    inline fn handleQuestObjId(reader: *utils.PacketReader) void {
        const object_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - QuestObjId: object_id={d}", .{object_id});
    }

    inline fn handleServerPlayerShoot(reader: *utils.PacketReader) void {
        const bullet_id = reader.read(u8);
        const owner_id = reader.read(i32);
        const container_type = reader.read(i32);
        const starting_pos = reader.read(Position);
        const angle = reader.read(f32);
        const damage = reader.read(i16);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - ServerPlayerShoot: bullet_id={d}, owner_id={d}, container_type={d}, x={e}, y={e}, angle={e}, damage={d}", .{ bullet_id, owner_id, container_type, starting_pos.x, starting_pos.y, angle, damage });
    }

    inline fn handleShowEffect(reader: *utils.PacketReader) void {
        const effect_type = 0; // handle effect type
        const target_object_id = reader.read(i32);
        const pos1 = reader.read(Position);
        const pos2 = reader.read(Position);
        const color = 0; // handle color

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - ShowEffect: effect_type={d}, target_object_id={d}, x1={e}, y1={e}, x2={e}, y2={e}, color={d}", .{ effect_type, target_object_id, pos1.x, pos1.y, pos2.x, pos2.y, color });
    }

    inline fn handleText(reader: *utils.PacketReader) void {
        const name = reader.read([]u8);
        const object_id = reader.read(i32);
        const num_stars = reader.read(i32);
        const bubble_time = reader.read(u8);
        const recipient = reader.read([]u8);
        const text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Text: name={s}, object_id={d}, num_stars={d}, bubble_time={d}, recipient={s}, text={s}", .{ name, object_id, num_stars, bubble_time, recipient, text });
    }

    inline fn handleTradeAccepted(reader: *utils.PacketReader) void {
        const my_offer = reader.read([]bool);
        const your_offer = reader.read([]bool);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeAccepted: my_offer={v}, your_offer={v}", .{ my_offer, your_offer });
    }

    inline fn handleTradeChanged(reader: *utils.PacketReader) void {
        const offer = reader.read([]bool);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeChanged: offer={v}", .{offer});
    }

    inline fn handleTradeDone(reader: *utils.PacketReader) void {
        const code = reader.read(i32);
        const description = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeDone: code={d}, description={s}", .{ code, description });
    }

    inline fn handleTradeRequested(reader: *utils.PacketReader) void {
        const name = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeRequested: name={s}", .{name});
    }

    inline fn handleTradeStart(reader: *utils.PacketReader) void {
        const my_items = 0; // handle trade items
        const your_name = reader.read([]u8);
        const your_items = 0; // handle trade items

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeStart: my_items={v}, your_name={s}, your_items={v}", .{ my_items, your_name, your_items });
    }

    inline fn handleUpdate(reader: *utils.PacketReader) void {
        const tiles = 0; // handle tile data
        const new_objects = 0; // handle new objects
        const pos = reader.read([]i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
            std.log.debug("Recv - Update: tiles={v}, new_objects={v}, pos={v}", .{ tiles, new_objects, pos });
    }

    pub fn hello(self: *Server, build_ver: []const u8, gameId: i32, email: []const u8, password: []const u8, char_id: i16, create_char: bool, class_type: u16, skin_type: u16) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Hello: build_ver={s}, game_id={d}, email={s}, password={s}, char_id={d}, create_char={any}, class_type={d}, skin_type={d}", .{ build_ver, gameId, email, password, char_id, create_char, class_type, skin_type });

        self.writer.writeLength();
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
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn playerText(self: *Server, text: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - PlayerText: text={s}", .{text});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.player_text));
        self.writer.write(text);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }
};
