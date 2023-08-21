const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");
const game_data = @import("game_data.zig");
const ui = @import("ui.zig");
const camera = @import("camera.zig");

// zig fmt: off
pub const ObjectSlot = extern struct { 
    object_id: i32 align(1),
    slot_id: u8 align(1), 
    object_type: u16 align(1),
};

pub const Position = extern struct { 
    x: f32, 
    y: f32 
};

pub const TimedPosition = extern struct { 
    time: i32, 
    position: Position 
};

pub const TileData = extern struct { 
    x: i16, 
    y: i16, 
    tile_type: u16 
};

pub const TradeItem = extern struct { 
    item: i32 align(1), 
    slot_type: i32 align(1), 
    tradeable: bool align(1),
    included: bool align(1), 
};

pub const ARGB = packed struct(u32) { 
    a: u8, 
    r: u8, 
    g: u8, 
    b: u8
};
// zig fmt: on

const EffectType = enum(u8) {
    unknown = 0,
    potion = 1,
    teleport = 2,
    stream = 3,
    throw = 4,
    area_blast = 5,
    dead = 6,
    trail = 7,
    diffuse = 8,
    flow = 9,
    trap = 10,
    lightning = 11,
    concentrate = 12,
    blast_wave = 13,
    earthquake = 14,
    flashing = 15,
    beach_ball = 16,
};

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
                .create_success => handleCreateSuccess(&self.reader),
                .damage => handleDamage(&self.reader),
                .death => handleDeath(&self.reader),
                .enemy_shoot => handleEnemyShoot(self),
                .failure => handleFailure(&self.reader),
                .global_notification => handleGlobalNotification(&self.reader),
                .goto => handleGoto(self),
                .invited_to_guild => handleInvitedToGuild(&self.reader),
                .inv_result => handleInvResult(&self.reader),
                .map_info => handleMapInfo(&self.reader, allocator),
                .name_result => handleNameResult(&self.reader),
                .new_tick => handleNewTick(self, allocator),
                .notification => handleNotification(&self.reader, allocator),
                .ping => handlePing(self),
                .play_sound => handlePlaySound(&self.reader),
                .quest_obj_id => handleQuestObjId(&self.reader),
                .server_player_shoot => handleServerPlayerShoot(self),
                .show_effect => handleShowEffect(&self.reader),
                .text => handleText(&self.reader),
                .trade_accepted => handleTradeAccepted(&self.reader),
                .trade_changed => handleTradeChanged(&self.reader),
                .trade_done => handleTradeDone(&self.reader),
                .trade_requested => handleTradeRequested(&self.reader),
                .trade_start => handleTradeStart(&self.reader),
                .update => handleUpdate(self, allocator),
                else => {
                    std.log.err("Unknown S2CPacketId: id={any}, size={d}, len={d}", .{ packet_id, self.buffer_idx, self.message_len });
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

        if (map.findEntity(owner_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .player => |*player| {
                    const weapon = player.inventory[0];
                    const item_props = game_data.item_type_to_props.get(@intCast(weapon));
                    const proj_props = item_props.?.projectile.?;
                    const projs_len = item_props.?.num_projectiles;
                    for (0..projs_len) |_| {
                        var proj = map.Projectile{
                            .x = player.x,
                            .y = player.y,
                            .props = proj_props,
                            .angle = angle,
                            .start_time = main.current_time,
                            .bullet_id = @intCast(bullet_id),
                            .owner_id = player.obj_id,
                        };
                        proj.addToMap(true);
                    }
                    player.attack_angle = angle - camera.angle;
                    player.attack_start = main.current_time;
                },
                else => {},
            }
        }

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - AllyShoot: bullet_id={d}, owner_id={d}, container_type={d}, angle={e}", .{ bullet_id, owner_id, container_type, angle });
    }

    inline fn handleAoe(reader: *utils.PacketReader) void {
        const position = reader.read(Position);
        const radius = reader.read(f32);
        const damage = reader.read(i16);
        const condition_effect = reader.read(u64);
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
        const effects = reader.read(u64);
        const damage_amount = reader.read(u16);
        const kill = reader.read(bool);
        const bullet_id = reader.read(i8);
        const object_id = reader.read(i32);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - Damage: target_id={d}, effects={d}, damage_amount={d}, kill={any}, bullet_id={d}, object_id={d}", .{ target_id, effects, damage_amount, kill, bullet_id, object_id });
    }

    inline fn handleDeath(reader: *utils.PacketReader) void {
        const account_id = reader.read(i32);
        const char_id = reader.read(i32);
        const killed_by = reader.read([]u8);

        main.disconnect();

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Death: account_id={d}, char_id={d}, killed_by={s}", .{ account_id, char_id, killed_by });
    }

    inline fn handleEnemyShoot(self: *Server) void {
        var reader = self.reader;
        const bullet_id = reader.read(u8);
        const owner_id = reader.read(i32);
        const bullet_type = reader.read(u8);
        const starting_pos = reader.read(Position);
        const angle = reader.read(f32);
        const damage = reader.read(i16);
        const num_shots = reader.read(u8);
        const angle_inc = reader.read(f32);

        // why?
        if (num_shots == 0)
            return;

        var owner: ?map.GameObject = null;
        if (map.findEntity(owner_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .object => |object| owner = object,
                else => {},
            }
        }

        if (owner == null)
            return;

        const owner_props = game_data.obj_type_to_props.get(owner.?.obj_type);
        if (owner_props == null)
            return;

        const total_angle = angle_inc * @as(f32, @floatFromInt(num_shots - 1));
        var current_angle = angle - total_angle / 2.0;
        const proj_props = owner_props.?.projectiles[bullet_type];
        for (0..num_shots) |i| {
            // zig fmt: off
            var proj = map.Projectile{ 
                .x = starting_pos.x,
                .y = starting_pos.y,
                .damage = damage,
                .props = proj_props,
                .angle = current_angle,
                .start_time = main.current_time,
                .bullet_id = bullet_id +% @as(u8, @intCast(i)),
                .owner_id = owner_id,
                .damage_players = true,
            };
            // zig fmt: on
            proj.addToMap(true);

            current_angle += angle_inc;
        }

        owner.?.attack_angle = angle;
        owner.?.attack_start = main.current_time;

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Recv - EnemyShoot: bullet_id={d}, owner_id={d}, bullet_type={d}, x={e}, y={e}, angle={e}, damage={d}, num_shots={d}, angle_inc={e}", .{ bullet_id, owner_id, bullet_type, starting_pos.x, starting_pos.y, angle, damage, num_shots, angle_inc });

        self.sendShootAck(main.current_time) catch |e| {
            std.log.err("Could not send ShootAck: {any}", .{e});
        };
    }

    inline fn handleFailure(reader: *utils.PacketReader) void {
        const error_id = reader.read(i32);
        const error_description = reader.read([]u8);

        main.disconnect();

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Failure: error_id={d}, error_description={s}", .{ error_id, error_description });
    }

    inline fn handleGlobalNotification(reader: *utils.PacketReader) void {
        const notif_type = reader.read(i32);
        const text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - GlobalNotification: type={d}, text={s}", .{ notif_type, text });
    }

    inline fn handleGoto(self: *Server) void {
        var reader = &self.reader;
        const object_id = reader.read(i32);
        const position = reader.read(Position);

        if (map.findEntity(object_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .player => |*player| {
                    if (object_id == map.local_player_id) {
                        player.x = position.x;
                        player.y = position.y;
                    } else {
                        player.target_x = position.x;
                        player.target_y = position.y;
                        player.tick_x = player.x;
                        player.tick_y = player.y;
                    }
                },
                else => {},
            }
        } else {
            std.log.err("Object id {d} not found while attempting to goto to pos {any}", .{ object_id, position });
        }

        self.sendGotoAck(main.last_update) catch |e| {
            std.log.err("Could not send GotoAck: {any}", .{e});
        };

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Goto: object_id={d}, x={e}, y={e}", .{ object_id, position.x, position.y });
    }

    inline fn handleGuildResult(reader: *utils.PacketReader) void {
        const success = reader.read(bool);
        const error_text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - GuildResult: success={any}, error_text={s}", .{ success, error_text });
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

    inline fn handleMapInfo(reader: *utils.PacketReader, allocator: std.mem.Allocator) void {
        const width: isize = @intCast(reader.read(i32));
        const height: isize = @intCast(reader.read(i32));
        map.setWH(width, height, allocator);
        map.name = reader.read([]u8);
        const display_name = reader.read([]u8);
        map.seed = reader.read(u32);
        const difficulty = reader.read(i32);
        const background = reader.read(i32);
        const allow_player_teleport = reader.read(bool);
        const show_displays = reader.read(bool);

        map.bg_light_color = reader.read(i32);
        map.bg_light_intensity = reader.read(f32);
        const uses_day_night = reader.read(bool);
        if (uses_day_night) {
            map.day_light_intensity = reader.read(f32);
            map.night_light_intensity = reader.read(f32);
            map.server_time_offset = reader.read(i32) - main.current_time;
        }
        map.random = utils.Random{ .seed = map.seed };

        main.clear();
        main.tick_frame = true;

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - MapInfo: width={d}, height={d}, name={s}, display_name={s}, seed={d}, difficulty={d}, background={d}, allow_player_teleport={any}, show_displays={any}, bg_light_color={d}, bg_light_intensity={e}, day_and_night={any}", .{ width, height, map.name, display_name, map.seed, difficulty, background, allow_player_teleport, show_displays, map.bg_light_color, map.bg_light_intensity, uses_day_night });
    }

    inline fn handleNameResult(reader: *utils.PacketReader) void {
        const success = reader.read(bool);
        const error_text = reader.read([]u8);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - NameResult: success={any}, error_text={s}", .{ success, error_text });
    }

    inline fn handleNewTick(self: *Server, allocator: std.mem.Allocator) void {
        var reader = &self.reader;
        const tick_id = reader.read(i32);
        const tick_time = reader.read(i32);

        defer {
            if (main.tick_frame) {
                if (map.findEntity(map.local_player_id)) |en| {
                    switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                        .player => |player| {
                            self.sendMove(tick_id, main.last_update, player.x, player.y, map.move_records.items) catch |e| {
                                std.log.err("Could not send Move: {any}", .{e});
                            };
                        },
                        else => {},
                    }
                }
            }
        }

        const statuses_len = reader.read(u16);
        for (0..statuses_len) |_| {
            const obj_id = reader.read(i32);
            const position = reader.read(Position);

            const stats_len = reader.read(u16);
            if (map.findEntity(obj_id)) |en| {
                switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                    .player => |*player| {
                        if (player.obj_id != map.local_player_id) {
                            player.target_x = position.x;
                            player.target_y = position.y;
                            player.tick_x = player.x;
                            player.tick_y = player.y;
                            const y_dt = position.y - player.y;
                            const x_dt = position.x - player.x;
                            player.move_angle = if (y_dt <= 0 and x_dt <= 0) std.math.nan(f32) else std.math.atan2(f32, y_dt, x_dt);
                        }

                        for (0..stats_len) |_| {
                            const stat_id = reader.read(u8);
                            const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                                std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                                return;
                            };
                            if (!parsePlrStatData(reader, &player.*, stat, allocator))
                                return;
                        }

                        continue;
                    },
                    .object => |*object| {
                        object.target_x = position.x;
                        object.target_y = position.y;
                        object.tick_x = object.x;
                        object.tick_y = object.y;
                        const y_dt = position.y - object.y;
                        const x_dt = position.x - object.x;
                        object.move_angle = if (y_dt == 0 and x_dt == 0) std.math.nan(f32) else std.math.atan2(f32, y_dt, x_dt);
                        for (0..stats_len) |_| {
                            const stat_id = reader.read(u8);
                            const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                                std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                                return;
                            };
                            if (!parseObjStatData(reader, &object.*, stat, allocator))
                                return;
                        }

                        continue;
                    },
                    else => {},
                }
            }

            std.log.err("Could not find object in NewTick (obj_id={d}, x={d}, y={d})", .{ obj_id, position.x, position.y });
            return;
        }

        map.last_tick_time = main.current_time;

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
            std.log.debug("Recv - NewTick: tick_id={d}, tick_time={d}, statuses_len={d}", .{ tick_id, tick_time, statuses_len });
    }

    inline fn handleNotification(reader: *utils.PacketReader, allocator: std.mem.Allocator) void {
        const object_id = reader.read(i32);
        const message = reader.read([]u8);
        const color = @byteSwap(@as(u32, @bitCast(reader.read(ARGB))));

        // zig fmt: off
        if (map.findEntity(object_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .player => |*player| {
                     ui.status_texts.append(ui.StatusText{
                        .obj_id = player.obj_id,
                        .start_time = main.current_time,
                        .color = color,
                        .lifetime = 2000,
                        .text = allocator.dupe(u8, message) catch unreachable, // not really unreachable is it now?
                    }) catch unreachable; 
                },
                .object => |*obj| {
                    ui.status_texts.append(ui.StatusText{
                        .obj_id = obj.obj_id,
                        .start_time = main.current_time,
                        .color = color,
                        .lifetime = 2000,
                        .text = allocator.dupe(u8, message) catch unreachable,
                    }) catch unreachable;
                },
                else => {},
            }
        }
        // zig fmt: on

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - Notification: object_id={d}, message={s}, color={any}", .{ object_id, message, color });
    }

    inline fn handlePing(self: *Server) void {
        var reader = &self.reader;
        const serial = reader.read(i32);

        self.sendPong(serial, main.current_time) catch |e| {
            std.log.err("Could not send Pong: {any}", .{e});
        };

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

    inline fn handleServerPlayerShoot(self: *Server) void {
        var reader = &self.reader;
        const bullet_id = reader.read(u8);
        const owner_id = reader.read(i32);
        const container_type = reader.read(u16);
        const starting_pos = reader.read(Position);
        const angle = reader.read(f32);
        const damage = reader.read(i16);
        const num_shots = 1; // todo
        const angle_inc = 0.0;

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - ServerPlayerShoot: bullet_id={d}, owner_id={d}, container_type={d}, x={e}, y={e}, angle={e}, damage={d}", .{ bullet_id, owner_id, container_type, starting_pos.x, starting_pos.y, angle, damage });

        const needs_ack = owner_id == map.local_player_id;
        if (map.findEntity(owner_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .player => {
                    const item_props = game_data.item_type_to_props.get(@intCast(container_type));
                    if (item_props == null or item_props.?.projectile == null)
                        return;

                    const proj_props = item_props.?.projectile.?;
                    const total_angle = angle_inc * @as(f32, @floatFromInt(num_shots - 1));
                    var current_angle = angle - total_angle / 2.0;
                    for (0..num_shots) |i| {
                        // zig fmt: off
                        var proj = map.Projectile{ 
                            .x = starting_pos.x,
                            .y = starting_pos.y,
                            .damage = damage,
                            .props = proj_props,
                            .angle = current_angle,
                            .start_time = main.current_time,
                            .bullet_id = bullet_id +% @as(u8, @intCast(i)), // this is wrong but whatever
                            .owner_id = owner_id,
                        };
                        // zig fmt: on
                        proj.addToMap(true);

                        current_angle += angle_inc;
                    }

                    if (needs_ack) {
                        self.sendShootAck(main.current_time) catch |e| {
                            std.log.err("Could not send ShootAck: {any}", .{e});
                        };
                    }
                },
                else => {
                    if (needs_ack) {
                        self.sendShootAck(-1) catch |e| {
                            std.log.err("Could not send ShootAck: {any}", .{e});
                        };
                    }
                },
            }
        }
    }

    inline fn handleShowEffect(reader: *utils.PacketReader) void {
        const effect_type = @as(EffectType, @enumFromInt(reader.read(u8)));
        const target_object_id = reader.read(i32);
        const pos1 = reader.read(Position);
        const pos2 = reader.read(Position);
        const color = @byteSwap(@as(u32, @bitCast(reader.read(ARGB))));

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - ShowEffect: effect_type={any}, target_object_id={d}, x1={e}, y1={e}, x2={e}, y2={e}, color={any}", .{ effect_type, target_object_id, pos1.x, pos1.y, pos2.x, pos2.y, color });
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
            std.log.debug("Recv - TradeAccepted: my_offer={any}, your_offer={any}", .{ my_offer, your_offer });
    }

    inline fn handleTradeChanged(reader: *utils.PacketReader) void {
        const offer = reader.read([]bool);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeChanged: offer={any}", .{offer});
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
        const my_items = reader.read([]TradeItem);
        const your_name = reader.read([]u8);
        const your_items = reader.read([]TradeItem);

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
            std.log.debug("Recv - TradeStart: my_items={any}, your_name={s}, your_items={any}", .{ my_items, your_name, your_items });
    }

    inline fn handleUpdate(self: *Server, allocator: std.mem.Allocator) void {
        defer {
            if (main.tick_frame)
                self.sendUpdateAck() catch |e| {
                    std.log.err("Could not send UpdateAck: {any}", .{e});
                };
        }

        var reader = &self.reader;
        const tiles = reader.read([]TileData);
        for (tiles) |tile| {
            map.setSquare(tile.x, tile.y, tile.tile_type);
        }

        const drops = reader.read([]i32);
        for (drops) |drop| {
            if (map.removeEntity(drop)) |en| {
                switch (en) {
                    .object => |obj| {
                        if (game_data.obj_type_to_class.get(obj.obj_type)) |class_props| {
                            if (class_props == .wall) {
                                const floor_y: u32 = @intFromFloat(@floor(obj.y));
                                const floor_x: u32 = @intFromFloat(@floor(obj.x));
                                if (map.validPos(floor_x, floor_y)) {
                                    map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x].has_wall = false;
                                    map.squares[floor_y * @as(u32, @intCast(map.width)) + floor_x].blocking = false;
                                }
                            }
                        }

                        ui.removeStatusText(obj.obj_id);

                        allocator.free(obj.name_override);
                        continue;
                    },
                    .player => |player| {
                        ui.removeStatusText(player.obj_id);

                        allocator.free(player.name_override);
                        allocator.free(player.guild);
                        continue;
                    },
                    else => {},
                }
            }

            std.log.err("Could not remove object with id {d}\n", .{drop});
        }

        const new_objs_len = reader.read(u16);
        for (0..new_objs_len) |_| {
            const obj_type = reader.read(u16);
            const obj_id = reader.read(i32);
            const position = reader.read(Position);

            const stats_len = reader.read(u16);
            const class = game_data.obj_type_to_class.get(obj_type) orelse game_data.ClassType.game_object;

            switch (class) {
                .player => {
                    var player = map.Player{ .x = position.x, .y = position.y, .obj_id = obj_id, .obj_type = obj_type };
                    for (0..stats_len) |_| {
                        const stat_id = reader.read(u8);
                        const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                            std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                            return;
                        };
                        if (!parsePlrStatData(reader, &player, stat, allocator))
                            return;
                    }

                    player.addToMap();
                },
                inline else => {
                    var obj = map.GameObject{ .x = position.x, .y = position.y, .obj_id = obj_id, .obj_type = obj_type };
                    for (0..stats_len) |_| {
                        const stat_id = reader.read(u8);
                        const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                            std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                            return;
                        };
                        if (!parseObjStatData(reader, &obj, stat, allocator)) {
                            return;
                        }
                    }

                    obj.addToMap();
                },
            }
        }

        if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
            std.log.debug("Recv - Update: tiles_len={d}, new_objs_len={d}, drops_len={d}", .{ tiles.len, new_objs_len, drops.len });
    }

    inline fn parsePlrStatData(reader: *utils.PacketReader, plr: *map.Player, stat_type: game_data.StatType, allocator: std.mem.Allocator) bool {
        @setEvalBranchQuota(5000);
        switch (stat_type) {
            .max_hp => plr.max_hp = reader.read(i32),
            .hp => plr.hp = reader.read(i32),
            .size => plr.size = @as(f32, @floatFromInt(reader.read(i32))) / 100.0,
            .max_mp => plr.max_mp = reader.read(i32),
            .mp => plr.mp = reader.read(i32),
            .exp_goal => plr.exp_goal = reader.read(i32),
            .exp => plr.exp = reader.read(i32),
            .level => plr.level = reader.read(i32),
            .attack => plr.attack = reader.read(i32),
            .defense => plr.defense = reader.read(i32),
            .speed => plr.speed = reader.read(i32),
            .dexterity => plr.dexterity = reader.read(i32),
            .vitality => plr.vitality = reader.read(i32),
            .wisdom => plr.wisdom = reader.read(i32),
            .condition => plr.condition = reader.read(game_data.Condition),
            .inv_0, .inv_1, .inv_2, .inv_3, .inv_4, .inv_5, .inv_6, .inv_7, .inv_8, .inv_9, .inv_10, .inv_11 => {
                const inv_idx = @intFromEnum(stat_type) - @intFromEnum(game_data.StatType.inv_0);
                plr.inventory[inv_idx] = reader.read(i32);
            },
            .stars => plr.stars = reader.read(i32),
            .name => plr.name_override = allocator.dupe(u8, reader.read([]u8)) catch &[0]u8{},
            .tex_1 => plr.tex_1 = reader.read(i32),
            .tex_2 => plr.tex_2 = reader.read(i32),
            .credits => plr.credits = reader.read(i32),
            .account_id => plr.account_id = reader.read(i32),
            .current_fame => plr.current_fame = reader.read(i32),
            .hp_boost => plr.hp_boost = reader.read(i32),
            .mp_boost => plr.mp_boost = reader.read(i32),
            .attack_bonus => plr.attack_bonus = reader.read(i32),
            .defense_bonus => plr.defense_bonus = reader.read(i32),
            .speed_bonus => plr.speed_bonus = reader.read(i32),
            .vitality_bonus => plr.vitality_bonus = reader.read(i32),
            .wisdom_bonus => plr.wisdom_bonus = reader.read(i32),
            .dexterity_bonus => plr.dexterity_bonus = reader.read(i32),
            .name_chosen => plr.name_chosen = reader.read(bool),
            .fame => plr.fame = reader.read(i32),
            .fame_goal => plr.fame_goal = reader.read(i32),
            .glow => plr.glow = reader.read(i32),
            .sink_level => plr.sink_level = reader.read(u16),
            .guild => plr.guild = allocator.dupe(u8, reader.read([]u8)) catch &[0]u8{},
            .guild_rank => plr.guild_rank = reader.read(i32),
            .oxygen_bar => plr.oxygen_bar = reader.read(i32),
            .health_stack_count => plr.health_stack_count = reader.read(i32),
            .magic_stack_count => plr.magic_stack_count = reader.read(i32),
            .backpack_0, .backpack_1, .backpack_2, .backpack_3, .backpack_4, .backpack_5, .backpack_6, .backpack_7 => {
                const backpack_idx = @intFromEnum(stat_type) - @intFromEnum(game_data.StatType.backpack_0) + 12;
                plr.inventory[backpack_idx] = reader.read(i32);
            },
            .has_backpack => plr.has_backpack = reader.read(bool),
            .skin => plr.skin = reader.read(i32),
            inline else => {
                std.log.err("Unknown player stat type: {any}", .{stat_type});
                return false;
            },
        }

        return true;
    }

    inline fn parseObjStatData(reader: *utils.PacketReader, obj: *map.GameObject, stat_type: game_data.StatType, allocator: std.mem.Allocator) bool {
        @setEvalBranchQuota(5000);
        switch (stat_type) {
            .max_hp => obj.max_hp = reader.read(i32),
            .hp => obj.hp = reader.read(i32),
            .size => obj.size = @as(f32, @floatFromInt(reader.read(i32))) / 100.0,
            .level => obj.level = reader.read(i32),
            .defense => obj.defense = reader.read(i32),
            .condition => obj.condition = reader.read(game_data.Condition),
            .inv_0, .inv_1, .inv_2, .inv_3, .inv_4, .inv_5, .inv_6, .inv_7, .inv_8, .inv_9, .inv_10, .inv_11 => {
                const inv_idx = @intFromEnum(stat_type) - @intFromEnum(game_data.StatType.inv_0);
                obj.inventory[inv_idx] = reader.read(i32);
            },
            .name => obj.name_override = allocator.dupe(u8, reader.read([]u8)) catch &[0]u8{},
            .tex_1 => obj.tex_1 = reader.read(i32),
            .tex_2 => obj.tex_2 = reader.read(i32),
            .merchant_merch_type => obj.merchant_obj_type = reader.read(u16),
            .merchant_rem_count => obj.merchant_rem_count = reader.read(i32),
            .merchant_rem_minute => obj.merchant_rem_minute = reader.read(i32),
            .sellable_price => obj.sellable_price = reader.read(i32),
            .sellable_currency => obj.sellable_currency = @enumFromInt(reader.read(u8)),
            .sellable_rank_req => obj.sellable_rank_req = reader.read(i32),
            .merchant_discount => obj.merchant_discount = reader.read(u8),
            .portal_active => obj.portal_active = reader.read(bool),
            .object_connection => obj.object_connection = reader.read(i32),
            .owner_acc_id => obj.owner_acc_id = reader.read(i32),
            .rank_required => obj.rank_required = reader.read(i32),
            .alt_texture_index => obj.alt_texture_index = reader.read(i32),
            inline else => {
                std.log.err("Unknown entity stat type: {any}", .{stat_type});
                return false;
            },
        }

        return true;
    }

    pub fn sendAcceptTrade(self: *Server, my_offer: []bool, your_offer: []bool) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - AcceptTrade: my_offer={any} your_offer={any}", .{ my_offer, your_offer });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.accept_trade));
        self.writer.write(my_offer);
        self.writer.write(your_offer);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendAoeAck(self: *Server, time: u32, position: Position) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - AoeAck: time={d} position={any}", .{ time, position });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.aoe_ack));
        self.writer.write(time);
        self.writer.write(position);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendBuy(self: *Server, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Buy: object_id={d}", .{object_id});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.buy));
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendCancelTrade(self: *Server) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - CancelTrade", .{});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.cancel_trade));
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendChangeGuildRank(self: *Server, name: []const u8, guild_rank: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - ChangeGuildRank: name={s} guild_rank={}", .{ name, guild_rank });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.change_guild_rank));
        self.writer.write(name);
        self.writer.write(guild_rank);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendChangeTrade(self: *Server, offer: []bool) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - ChangeTrade: offer={any}", .{offer});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.change_trade));
        self.writer.write(offer);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendCheckCredits(self: *Server) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - CheckCredits", .{});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.check_credits));
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendChooseName(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - ChooseName: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.choose_name));
        self.writer.write(name);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendCreate(self: *Server, class_type: u16, skin_type: u16) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Create: class_type={d} skin_type={d}", .{ class_type, skin_type });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.create));
        self.writer.write(class_type);
        self.writer.write(skin_type);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendCreateGuild(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - CreateGuild: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.create_guild));
        self.writer.write(name);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendEditAccountList(self: *Server, account_list_id: i32, add: bool, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - EditAccountList: account_list_id={d} add={any} object_id={d}", .{ account_list_id, add, object_id });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.edit_account_list));
        self.writer.write(account_list_id);
        self.writer.write(add);
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendEnemyHit(self: *Server, time: i32, bullet_id: u8, target_id: i32, killed: bool) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - EnemyHit: time={d} bullet_id={d} target_id={d} killed={any}", .{ time, bullet_id, target_id, killed });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.enemy_hit));
        self.writer.write(time);
        self.writer.write(bullet_id);
        self.writer.write(target_id);
        self.writer.write(killed);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendEscape(self: *Server) !void {

        // precheck to prevent client sided cleanup when already in nexus
        if (std.mem.eql(u8, map.name, "Nexus")) {
            return;
        }

        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Escape", .{});

        main.clear();
        main.tick_frame = false;

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.escape));
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendGotoAck(self: *Server, time: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - GotoAck: time={d}", .{time});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.goto_ack));
        self.writer.write(time);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendGroundDamage(self: *Server, time: i32, position: Position) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - GroundDamage: time={d} position={any}", .{ time, position });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.ground_damage));
        self.writer.write(time);
        self.writer.write(position);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendGuildInvite(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - GuildInvite: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.guild_invite));
        self.writer.write(name);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendGuildRemove(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - GuildRemove: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.guild_remove));
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendHello(self: *Server, build_ver: []const u8, gameId: i32, email: []const u8, password: []const u8, char_id: i16, create_char: bool, class_type: u16, skin_type: u16) !void {
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

    pub fn sendInvDrop(self: *Server, slot_object: ObjectSlot) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - InvDrop: slot_object={any}", .{slot_object});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.inv_drop));
        self.writer.write(slot_object);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendInvSwap(self: *Server, time: i32, position: Position, from_slot: ObjectSlot, to_slot: ObjectSlot) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - InvSwap: time={d} position={any} from_slot={any} to_slot={any}", .{ time, position, from_slot, to_slot });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.inv_swap));
        self.writer.write(time);
        self.writer.write(position);
        self.writer.write(from_slot);
        self.writer.write(to_slot);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendJoinGuild(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - JoinGuild: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.join_guild));
        self.writer.write(name);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendLoad(self: *Server, char_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Load: char_id={d}", .{char_id});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.load));
        self.writer.write(char_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendMove(self: *Server, tick_id: i32, time: i32, pos_x: f32, pos_y: f32, records: []const TimedPosition) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s)
            std.log.debug("Send - Move: tick_id={d} time={d} pos_x={d} pos_y={d} records={any}", .{ tick_id, time, pos_x, pos_y, records });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.move));
        self.writer.write(tick_id);
        self.writer.write(time);
        self.writer.write(pos_x);
        self.writer.write(pos_y);
        self.writer.write(records);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;

        if (map.findEntity(map.local_player_id)) |en| {
            switch (@atomicLoad(*map.Entity, &en, .Acquire).*) {
                .player => |*player| player.onMove(),
                else => {},
            }
        }
    }

    pub fn sendOtherHit(self: *Server, time: i32, bullet_id: u8, object_id: i32, target_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - OtherHit: time={d} bullet_id={d} object_id={d} target_id={d}", .{ time, bullet_id, object_id, target_id });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.other_hit));
        self.writer.write(time);
        self.writer.write(bullet_id);
        self.writer.write(object_id);
        self.writer.write(target_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendPlayerHit(self: *Server, bullet_id: u8, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - PlayerHit: bullet_id={d} object_id={d}", .{ bullet_id, object_id });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.player_hit));
        self.writer.write(bullet_id);
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendPlayerShoot(self: *Server, time: i32, bullet_id: u8, container_type: u16, starting_pos: Position, angle: f32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - PlayerShoot: time={d} bullet_id={d} container_type={d} staring_pos={any} angle={d}", .{ time, bullet_id, container_type, starting_pos, angle });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.player_shoot));
        self.writer.write(time);
        self.writer.write(bullet_id);
        self.writer.write(container_type);
        self.writer.write(starting_pos);
        self.writer.write(angle);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendPlayerText(self: *Server, text: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - PlayerText: text={s}", .{text});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.player_text));
        self.writer.write(text);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendPong(self: *Server, serial: i32, time: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Pong: serial={d} time={d}", .{ serial, time });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.pong));
        self.writer.write(serial);
        self.writer.write(time);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendRequestTrade(self: *Server, name: []const u8) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - RequestTrade: name={s}", .{name});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.request_trade));
        self.writer.write(name);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendReskin(self: *Server, skin_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Reskin: skin_id={d}", .{skin_id});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.reskin));
        self.writer.write(skin_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendSetCondition(self: *Server, condition_effect: i32, condition_duration: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - SetCondition: condition_effect={d} condition_duration={d}", .{ condition_effect, condition_duration });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.set_condition));
        self.writer.write(condition_effect);
        self.writer.write(condition_duration);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendShootAck(self: *Server, time: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - ShootAck: time={d}", .{time});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.shoot_ack));
        self.writer.write(time);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendSquareHit(self: *Server, time: i32, bullet_id: u8, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - SquareHit: time={d} bullet_id={d} object_id={d}", .{ time, bullet_id, object_id });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.square_hit));
        self.writer.write(time);
        self.writer.write(bullet_id);
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendTeleport(self: *Server, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - Teleport: object_id={d}", .{object_id});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.teleport));
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendUpdateAck(self: *Server) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s)
            std.log.debug("Send - UpdateAck", .{});

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.update_ack));
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendUseItem(
        self: *Server,
        time: i32,
        slot_object: ObjectSlot,
        use_position: Position,
        use_type: u8,
    ) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - UseItem: time={d} slot_object={any} use_position={any} use_type={d} ", .{ time, slot_object, use_position, use_type });

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.use_item));
        self.writer.write(time);
        self.writer.write(slot_object);
        self.writer.write(use_position);
        self.writer.write(use_type);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }

    pub fn sendUsePortal(self: *Server, object_id: i32) !void {
        if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
            std.log.debug("Send - UsePortal: object_id={d}", .{object_id});

        main.clear();
        main.tick_frame = false;

        self.writer.writeLength();
        self.writer.write(@intFromEnum(C2SPacketId.use_portal));
        self.writer.write(object_id);
        self.writer.updateLength();

        try self.stream.writer().writeAll(self.writer.buffer[0..self.writer.index]);
        self.writer.index = 0;
    }
};
