const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");
const game_data = @import("game_data.zig");
const ui = @import("ui/ui.zig");
const camera = @import("camera.zig");
const assets = @import("assets.zig");

pub const ObjectSlot = extern struct {
    object_id: i32 align(1),
    slot_id: u8 align(1),
    object_type: i32 align(1),
};

pub const Position = extern struct {
    x: f32,
    y: f32,
};

pub const TimedPosition = extern struct {
    time: i64,
    position: Position,
};

pub const TileData = extern struct {
    x: i16,
    y: i16,
    tile_type: u16,
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
    b: u8,
};

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

pub var connected = false;
var message_len: u16 = 65535;
var buffer_idx: usize = 0;
var stream: std.net.Stream = undefined;
var reader = utils.PacketReader{};
var writer = utils.PacketWriter{};

pub fn init(ip: []const u8, port: u16) void {
    stream = std.net.tcpConnectToAddress(std.net.Address.parseIp(ip, port) catch |address_error| {
        std.log.err("Could not parse address {s}:{d}: {any}", .{ ip, port, address_error });
        return;
    }) catch |connect_error| {
        std.log.err("Could not connect to address {s}:{d}: {any}", .{ ip, port, connect_error });
        return;
    };

    connected = true;
}

pub fn deinit() void {
    stream.close();
    connected = false;
}

pub fn onError(e: anytype) void {
    std.log.err("Error while handling server packets: {any}", .{e});
    main.disconnect();
}

pub fn accept(allocator: std.mem.Allocator) void {
    const size = stream.read(reader.buffer[buffer_idx..]) catch |e| {
        onError(e);
        return;
    };
    buffer_idx += size;

    if (size < 2)
        return;

    while (reader.index < buffer_idx) {
        if (message_len == 65535)
            message_len = reader.read(u16);

        if (message_len != 65535 and buffer_idx - reader.index < message_len)
            return;

        const next_packet_idx = reader.index + message_len;
        const byte_id = reader.read(u8);
        const packet_id = std.meta.intToEnum(S2CPacketId, byte_id) catch |e| {
            std.log.err("Error parsing S2CPacketId ({any}): id={d}, size={d}, len={d}", .{ e, byte_id, buffer_idx, message_len });
            reader.index = 0;
            buffer_idx = 0;
            return;
        };

        switch (packet_id) {
            .account_list => handleAccountList(),
            .ally_shoot => handleAllyShoot(),
            .aoe => handleAoe(),
            .buy_result => handleBuyResult(),
            .create_success => handleCreateSuccess(),
            .damage => handleDamage(),
            .death => handleDeath(),
            .enemy_shoot => handleEnemyShoot(),
            .failure => handleFailure(),
            .global_notification => handleGlobalNotification(),
            .goto => handleGoto(),
            .invited_to_guild => handleInvitedToGuild(),
            .inv_result => handleInvResult(),
            .map_info => handleMapInfo(allocator),
            .name_result => handleNameResult(),
            .new_tick => handleNewTick(allocator),
            .notification => handleNotification(allocator),
            .ping => handlePing(),
            .play_sound => handlePlaySound(),
            .quest_obj_id => handleQuestObjId(),
            .server_player_shoot => handleServerPlayerShoot(),
            .show_effect => handleShowEffect(),
            .text => handleText(allocator),
            .trade_accepted => handleTradeAccepted(),
            .trade_changed => handleTradeChanged(),
            .trade_done => handleTradeDone(),
            .trade_requested => handleTradeRequested(),
            .trade_start => handleTradeStart(),
            .update => handleUpdate(allocator),
            else => {
                std.log.err("Unknown S2CPacketId: id={any}, size={d}, len={d}", .{ packet_id, buffer_idx, message_len });
                reader.index = 0;
                buffer_idx = 0;
                return;
            },
        }

        reader.index = next_packet_idx;
        message_len = 65535;
    }

    main.fba.reset();
    reader.index = 0;
    buffer_idx = 0;
}

fn handleAccountList() void {
    const account_list_id = reader.read(i32);
    const account_ids = reader.read([]i32);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - AccountList: account_list_id={d}, account_ids={d}", .{ account_list_id, account_ids });
}

fn handleAllyShoot() void {
    const bullet_id = reader.read(i8);
    const owner_id = reader.read(i32);
    const container_type = reader.read(u16);
    const angle = reader.read(f32);

    if (map.findEntityRef(owner_id)) |en| {
        if (en.* == .player) {
            const player = &en.player;
            const weapon = player.inventory[0];
            const item_props = game_data.item_type_to_props.getPtr(@intCast(weapon));
            const proj_props = &item_props.?.projectile.?;
            const projs_len = item_props.?.num_projectiles;
            for (0..projs_len) |_| {
                var proj = map.Projectile{
                    .x = player.x,
                    .y = player.y,
                    .props = proj_props,
                    .angle = angle,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .bullet_id = @intCast(bullet_id),
                    .owner_id = player.obj_id,
                };
                proj.addToMap(true);
            }

            // if this is too slow for ya in large crowds hardcode it to 100
            const attack_period: i32 = @intFromFloat((1.0 / player.attackFrequency()) * (1.0 / item_props.?.rate_of_fire));
            player.attack_period = attack_period;
            player.attack_angle = angle - camera.angle;
            player.attack_angle_raw = angle;
            player.attack_start = main.current_time;
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - AllyShoot: bullet_id={d}, owner_id={d}, container_type={d}, angle={e}", .{ bullet_id, owner_id, container_type, angle });
}

fn handleAoe() void {
    const position = reader.read(Position);
    const radius = reader.read(f32);
    const damage = reader.read(i16);
    const condition_effect = reader.read(utils.Condition);
    const duration = reader.read(f32);
    const orig_type = reader.read(u8);

    var effect = map.AoeEffect{
        .x = position.x,
        .y = position.y,
        .color = 0xFF0000,
        .radius = radius,
    };
    effect.addToMap();
    map.entities.add(.{ .particle_effect = .{ .aoe = effect } }) catch |e| {
        std.log.err("Out of memory: {any}", .{e});
    };

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - Aoe: x={e}, y={e}, radius={e}, damage={d}, condition_effect={d}, duration={e}, orig_type={d}", .{ position.x, position.y, radius, damage, condition_effect, duration, orig_type });
}

fn handleBuyResult() void {
    const result = reader.read(i32);
    const message = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - BuyResult: result={d}, message={s}", .{ result, message });
}

fn handleCreateSuccess() void {
    map.local_player_id = reader.read(i32);
    const char_id = reader.read(i32);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - CreateSuccess: player_id={d}, char_id={d}", .{ map.local_player_id, char_id });
}

fn handleDamage() void {
    const target_id = reader.read(i32);
    const effects = reader.read(u64);
    const damage_amount = reader.read(u16);
    const kill = reader.read(bool);
    const bullet_id = reader.read(i8);
    const object_id = reader.read(i32);

    // todo find entity and call object.takeDamage();

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - Damage: target_id={d}, effects={d}, damage_amount={d}, kill={any}, bullet_id={d}, object_id={d}", .{ target_id, effects, damage_amount, kill, bullet_id, object_id });
}

fn handleDeath() void {
    const account_id = reader.read(i32);
    const char_id = reader.read(i32);
    const killed_by = reader.read([]u8);

    main.disconnect();

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Death: account_id={d}, char_id={d}, killed_by={s}", .{ account_id, char_id, killed_by });
}

fn handleEnemyShoot() void {
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
    if (map.findEntityConst(owner_id)) |en| {
        if (en == .object) {
            owner = en.object;
        }
    }

    if (owner == null)
        return;

    const owner_props = game_data.obj_type_to_props.getPtr(owner.?.obj_type);
    if (owner_props == null)
        return;

    const total_angle = angle_inc * @as(f32, @floatFromInt(num_shots - 1));
    var current_angle = angle - total_angle / 2.0;
    const proj_props = &owner_props.?.projectiles[bullet_type];
    for (0..num_shots) |i| {
        var proj = map.Projectile{
            .x = starting_pos.x,
            .y = starting_pos.y,
            .damage = damage,
            .props = proj_props,
            .angle = current_angle,
            .start_time = @divFloor(main.current_time, std.time.us_per_ms),
            .bullet_id = bullet_id +% @as(u8, @intCast(i)),
            .owner_id = owner_id,
            .damage_players = true,
        };
        proj.addToMap(true);

        current_angle += angle_inc;
    }

    owner.?.attack_angle = angle;
    owner.?.attack_start = main.current_time;

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - EnemyShoot: bullet_id={d}, owner_id={d}, bullet_type={d}, x={e}, y={e}, angle={e}, damage={d}, num_shots={d}, angle_inc={e}", .{ bullet_id, owner_id, bullet_type, starting_pos.x, starting_pos.y, angle, damage, num_shots, angle_inc });

    sendShootAck(main.current_time);
}

fn handleFailure() void {
    const error_id = reader.read(i32);
    const error_description = reader.read([]u8);

    main.disconnect();

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Failure: error_id={d}, error_description={s}", .{ error_id, error_description });
}

fn handleGlobalNotification() void {
    const notif_type = reader.read(i32);
    const text = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - GlobalNotification: type={d}, text={s}", .{ notif_type, text });
}

fn handleGoto() void {
    const object_id = reader.read(i32);
    const position = reader.read(Position);

    if (map.findEntityRef(object_id)) |en| {
        if (en.* == .player) {
            const player = &en.player;
            if (object_id == map.local_player_id) {
                player.x = position.x;
                player.y = position.y;
            } else {
                player.target_x = position.x;
                player.target_y = position.y;
                player.tick_x = player.x;
                player.tick_y = player.y;
            }
        }
    } else {
        std.log.err("Object id {d} not found while attempting to goto to pos {any}", .{ object_id, position });
    }

    sendGotoAck(main.last_update);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Goto: object_id={d}, x={e}, y={e}", .{ object_id, position.x, position.y });
}

fn handleGuildResult() void {
    const success = reader.read(bool);
    const error_text = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - GuildResult: success={any}, error_text={s}", .{ success, error_text });
}

fn handleInvitedToGuild() void {
    const guild_name = reader.read([]u8);
    const name = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - InvitedToGuild: guild_name={s}, name={s}", .{ guild_name, name });
}

fn handleInvResult() void {
    const result = reader.read(u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - InvResult: result={d}", .{result});
}

fn handleMapInfo(allocator: std.mem.Allocator) void {
    main.clear();
    camera.quake = false;

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

    map.bg_light_color = reader.read(u32);
    map.bg_light_intensity = reader.read(f32);
    const uses_day_night = reader.read(bool);
    if (uses_day_night) {
        map.day_light_intensity = reader.read(f32);
        map.night_light_intensity = reader.read(f32);
        map.server_time_offset = reader.read(i64) - main.current_time;
    }
    map.random = utils.Random{ .seed = map.seed };

    main.tick_frame = true;

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - MapInfo: width={d}, height={d}, name={s}, display_name={s}, seed={d}, difficulty={d}, background={d}, allow_player_teleport={any}, show_displays={any}, bg_light_color={d}, bg_light_intensity={e}, day_and_night={any}", .{ width, height, map.name, display_name, map.seed, difficulty, background, allow_player_teleport, show_displays, map.bg_light_color, map.bg_light_intensity, uses_day_night });
}

fn handleNameResult() void {
    const success = reader.read(bool);
    const error_text = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - NameResult: success={any}, error_text={s}", .{ success, error_text });
}

fn handleNewTick(allocator: std.mem.Allocator) void {
    const tick_id = reader.read(i32);
    const tick_time = reader.read(i32);

    defer {
        if (main.tick_frame) {
            if (map.localPlayerConst()) |local_player| {
                sendMove(tick_id, main.last_update, local_player.x, local_player.y, map.move_records.items());
            } else {
                sendMove(tick_id, main.last_update, -1, -1, &[0]TimedPosition{});
            }
        }
    }

    const statuses_len = reader.read(u16);
    for (0..statuses_len) |_| {
        const obj_id = reader.read(i32);
        const position = reader.read(Position);

        const stats_len = reader.read(u16);
        const stats_byte_len = reader.read(u16);
        const next_obj_idx = reader.index + stats_byte_len;

        if (map.findEntityRef(obj_id)) |en| {
            switch (en.*) {
                .player => |*player| {
                    if (player.obj_id != map.local_player_id) {
                        player.target_x = position.x;
                        player.target_y = position.y;
                        player.tick_x = player.x;
                        player.tick_y = player.y;
                        const y_dt = position.y - player.y;
                        const x_dt = position.x - player.x;
                        player.move_angle = if (y_dt <= 0 and x_dt <= 0) std.math.nan(f32) else std.math.atan2(f32, y_dt, x_dt);
                        player.move_angle_camera_included = camera.angle_unbound + player.move_angle;
                    }

                    for (0..stats_len) |_| {
                        const stat_id = reader.read(u8);
                        const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                            std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                            reader.index = next_obj_idx;
                            continue;
                        };
                        if (!parsePlrStatData(&player.*, stat, allocator)) {
                            std.log.err("Stat data parsing for stat {d} failed, player: {any}", .{ stat_id, player });
                            reader.index = next_obj_idx;
                            continue;
                        }
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
                            reader.index = next_obj_idx;
                            continue;
                        };
                        if (!parseObjStatData(&object.*, stat, allocator)) {
                            std.log.err("Stat data parsing for stat {d} failed, object: {any}", .{ stat_id, object });
                            reader.index = next_obj_idx;
                            continue;
                        }
                    }

                    continue;
                },
                else => {},
            }
        }

        reader.index = next_obj_idx;
        std.log.err("Could not find object in NewTick (obj_id={d}, x={d}, y={d})", .{ obj_id, position.x, position.y });
    }

    map.last_tick_time = @divFloor(main.current_time, std.time.us_per_ms);
    map.last_tick_ms = @floatFromInt(tick_time);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
        std.log.debug("Recv - NewTick: tick_id={d}, tick_time={d}, statuses_len={d}", .{ tick_id, tick_time, statuses_len });
}

fn handleNotification(allocator: std.mem.Allocator) void {
    const object_id = reader.read(i32);
    const message = reader.read([]u8);
    const color = @byteSwap(@as(u32, @bitCast(reader.read(ARGB))));

    if (map.findEntityConst(object_id)) |en| {
        const text_data = ui.TextData{
            .text = allocator.dupe(u8, message) catch return,
            .text_type = .bold,
            .size = 22,
            .color = color,
            .backing_buffer = &[0]u8{},
        };

        if (en == .player) {
            ui.elements.add(.{ .status = ui.StatusText{
                .obj_id = en.player.obj_id,
                .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                .lifetime = 2000,
                .text_data = text_data,
                .initial_size = 22,
            } }) catch unreachable;
        } else if (en == .object) {
            ui.elements.add(.{ .status = ui.StatusText{
                .obj_id = en.object.obj_id,
                .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                .lifetime = 2000,
                .text_data = text_data,
                .initial_size = 22,
            } }) catch unreachable;
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Notification: object_id={d}, message={s}, color={any}", .{ object_id, message, color });
}

fn handlePing() void {
    const serial = reader.read(i32);

    sendPong(serial, main.current_time);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
        std.log.debug("Recv - Ping: serial={d}", .{serial});
}

fn handlePlaySound() void {
    const owner_id = reader.read(i32);
    const sound_id = reader.read(i32);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - PlaySound: owner_id={d}, sound_id={d}", .{ owner_id, sound_id });
}

fn handleQuestObjId() void {
    const object_id = reader.read(i32);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - QuestObjId: object_id={d}", .{object_id});
}

fn handleServerPlayerShoot() void {
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
    if (map.findEntityConst(owner_id)) |en| {
        if (en == .player) {
            const item_props = game_data.item_type_to_props.getPtr(@intCast(container_type));
            if (item_props == null or item_props.?.projectile == null)
                return;

            const proj_props = &item_props.?.projectile.?;
            const total_angle = angle_inc * @as(f32, @floatFromInt(num_shots - 1));
            var current_angle = angle - total_angle / 2.0;
            for (0..num_shots) |i| {
                var proj = map.Projectile{
                    .x = starting_pos.x,
                    .y = starting_pos.y,
                    .damage = damage,
                    .props = proj_props,
                    .angle = current_angle,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .bullet_id = bullet_id +% @as(u8, @intCast(i)), // this is wrong but whatever
                    .owner_id = owner_id,
                };
                proj.addToMap(true);

                current_angle += angle_inc;
            }

            if (needs_ack) {
                sendShootAck(main.current_time);
            }
        } else {
            if (needs_ack) {
                sendShootAck(-1);
            }
        }
    }
}

fn handleShowEffect() void {
    const effect_type: EffectType = @enumFromInt(reader.read(u8));
    const target_object_id = reader.read(i32);
    const pos1 = reader.read(Position);
    const pos2 = reader.read(Position);
    const color = @byteSwap(@as(u32, @bitCast(reader.read(ARGB))));

    switch (effect_type) {
        .throw => {
            var start_x = pos2.x;
            var start_y = pos2.y;

            if (map.findEntityConst(target_object_id)) |en| {
                switch (en) {
                    .object => |object| {
                        start_x = object.x;
                        start_y = object.y;
                    },
                    .player => |player| {
                        start_x = player.x;
                        start_y = player.y;
                    },
                    else => {},
                }
            }

            var effect = map.ThrowEffect{
                .start_x = start_x,
                .start_y = start_y,
                .end_x = pos1.x,
                .end_y = pos1.y,
                .color = color,
                .duration = 1000,
            };
            effect.addToMap();
            map.entities.add(.{ .particle_effect = .{ .throw = effect } }) catch |e| {
                std.log.err("Out of memory: {any}", .{e});
            };
        },
        .teleport => {
            var effect = map.TeleportEffect{
                .x = pos1.x,
                .y = pos1.y,
            };
            effect.addToMap();
            map.entities.add(.{ .particle_effect = .{ .teleport = effect } }) catch |e| {
                std.log.err("Out of memory: {any}", .{e});
            };
        },
        .trail => {
            var start_x = pos2.x;
            var start_y = pos2.y;

            if (map.findEntityConst(target_object_id)) |en| {
                switch (en) {
                    .object => |object| {
                        start_x = object.x;
                        start_y = object.y;
                    },
                    .player => |player| {
                        start_x = player.x;
                        start_y = player.y;
                    },
                    else => {},
                }
            }

            var effect = map.LineEffect{
                .start_x = start_x,
                .start_y = start_y,
                .end_x = pos1.x,
                .end_y = pos1.y,
                .color = color,
            };
            effect.addToMap();
            map.entities.add(.{ .particle_effect = .{ .line = effect } }) catch |e| {
                std.log.err("Out of memory: {any}", .{e});
            };
        },
        .earthquake => {
            camera.quake = true;
            camera.quake_amount = 0.0;
        },
        else => {},
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - ShowEffect: effect_type={any}, target_object_id={d}, x1={e}, y1={e}, x2={e}, y2={e}, color={any}", .{ effect_type, target_object_id, pos1.x, pos1.y, pos2.x, pos2.y, color });
}

fn handleText(allocator: std.mem.Allocator) void {
    const name = reader.read([]u8);
    const object_id = reader.read(i32);
    const num_stars = reader.read(i32);
    const bubble_time = reader.read(u8);
    const recipient = reader.read([]u8);
    const text = reader.read([]u8);

    while (!map.object_lock.tryLockShared()) {}
    defer map.object_lock.unlockShared();

    if (map.findEntityConst(object_id)) |en| {
        var atlas_data = assets.error_data;
        if (assets.ui_atlas_data.get("speechBalloons")) |balloon_data| {
            // todo: guild, party and admin balloons

            if (!std.mem.eql(u8, recipient, "")) {
                atlas_data = balloon_data[1]; // tell balloon
            } else {
                if (en == .object) {
                    atlas_data = balloon_data[3]; // enemy balloon
                } else {
                    atlas_data = balloon_data[0]; // normal balloon
                }
            }
        }

        ui.elements.add(.{ .balloon = ui.SpeechBalloon{
            .image_data = .{ .normal = .{
                .scale_x = 3.0,
                .scale_y = 3.0,
                .atlas_data = atlas_data,
            } },
            .text_data = .{
                .text = allocator.dupe(u8, text) catch unreachable,
                .size = 16,
                .max_width = 160,
                .backing_buffer = &[0]u8{},
                .outline_width = 1.5,
                .disable_subpixel = true,
            },
            .target_id = object_id,
            .start_time = @divFloor(main.current_time, std.time.us_per_ms),
        } }) catch unreachable;
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Text: name={s}, object_id={d}, num_stars={d}, bubble_time={d}, recipient={s}, text={s}", .{ name, object_id, num_stars, bubble_time, recipient, text });
}

fn handleTradeAccepted() void {
    const my_offer = reader.read([]bool);
    const your_offer = reader.read([]bool);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - TradeAccepted: my_offer={any}, your_offer={any}", .{ my_offer, your_offer });
}

fn handleTradeChanged() void {
    const offer = reader.read([]bool);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - TradeChanged: offer={any}", .{offer});
}

fn handleTradeDone() void {
    const code = reader.read(i32);
    const description = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - TradeDone: code={d}, description={s}", .{ code, description });
}

fn handleTradeRequested() void {
    const name = reader.read([]u8);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - TradeRequested: name={s}", .{name});
}

fn handleTradeStart() void {
    const my_items = reader.read([]TradeItem);
    const your_name = reader.read([]u8);
    const your_items = reader.read([]TradeItem);

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - TradeStart: my_items={any}, your_name={s}, your_items={any}", .{ my_items, your_name, your_items });
}

fn handleUpdate(allocator: std.mem.Allocator) void {
    defer {
        if (main.tick_frame)
            sendUpdateAck();
    }

    const tiles = reader.read([]TileData);
    for (tiles) |tile| {
        map.setSquare(tile.x, tile.y, tile.tile_type);
    }

    main.need_minimap_update = tiles.len > 0;

    const drops = reader.read([]i32);
    {
        while (!map.object_lock.tryLock()) {}
        defer map.object_lock.unlock();

        for (drops) |drop| {
            if (map.removeEntity(drop)) |en| {
                map.disposeEntity(allocator, en);
                continue;
            }

            std.log.err("Could not remove object with id {d}", .{drop});
        }
    }

    const new_objs_len = reader.read(u16);
    for (0..new_objs_len) |_| {
        const obj_type = reader.read(u16);
        const obj_id = reader.read(i32);
        const position = reader.read(Position);

        const stats_len = reader.read(u16);
        const stats_byte_len = reader.read(u16);
        const next_obj_idx = reader.index + stats_byte_len;
        const class = game_data.obj_type_to_class.get(obj_type) orelse game_data.ClassType.game_object;

        switch (class) {
            .player => {
                var player = map.Player{ .x = position.x, .y = position.y, .obj_id = obj_id, .obj_type = obj_type };
                for (0..stats_len) |_| {
                    const stat_id = reader.read(u8);
                    const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                        std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                        reader.index = next_obj_idx;
                        continue;
                    };
                    if (!parsePlrStatData(&player, stat, allocator)) {
                        std.log.err("Stat data parsing for stat {d} failed, player: {any}", .{ stat_id, player });
                        reader.index = next_obj_idx;
                        continue;
                    }
                }

                player.addToMap();
            },
            inline else => {
                var obj = map.GameObject{ .x = position.x, .y = position.y, .obj_id = obj_id, .obj_type = obj_type };
                for (0..stats_len) |_| {
                    const stat_id = reader.read(u8);
                    const stat = std.meta.intToEnum(game_data.StatType, stat_id) catch |e| {
                        std.log.err("Could not parse stat {d}: {any}", .{ stat_id, e });
                        reader.index = next_obj_idx;
                        continue;
                    };
                    if (!parseObjStatData(&obj, stat, allocator)) {
                        std.log.err("Stat data parsing for stat {d} failed, object: {any}", .{ stat_id, obj });
                        reader.index = next_obj_idx;
                        continue;
                    }
                }

                obj.addToMap();
            },
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_tick)
        std.log.debug("Recv - Update: tiles_len={d}, new_objs_len={d}, drops_len={d}", .{ tiles.len, new_objs_len, drops.len });
}

fn parsePlrStatData(plr: *map.Player, stat_type: game_data.StatType, allocator: std.mem.Allocator) bool {
    @setEvalBranchQuota(5000);
    switch (stat_type) {
        .max_hp => plr.max_hp = reader.read(i32),
        .hp => plr.hp = reader.read(i32),
        .size => plr.size = @as(f32, @floatFromInt(reader.read(i32))) / 100.0,
        .max_mp => plr.max_mp = reader.read(i32),
        .mp => plr.mp = reader.read(i32),
        .exp_goal => plr.exp_goal = reader.read(i32),
        .exp => {
            const last_xp = plr.exp;
            plr.exp = reader.read(i32);
            if (last_xp != 0 and last_xp < plr.exp and (settings.always_show_xp_gain or plr.level < 20)) {
                const text_data = ui.TextData{
                    .text = std.fmt.allocPrint(allocator, "+{d} XP", .{plr.exp - last_xp}) catch return false,
                    .text_type = .bold,
                    .size = 22,
                    .color = 0x0D5936,
                    .backing_buffer = &[0]u8{},
                };

                ui.elements.add(.{ .status = ui.StatusText{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = text_data,
                    .initial_size = 22,
                } }) catch return false;
            }
        },
        .level => {
            const last_level = plr.level;
            plr.level = reader.read(i32);
            if (last_level != 0 and last_level < plr.level) {
                const text_data = ui.TextData{
                    .text = std.fmt.allocPrint(allocator, "Level Up!", .{}) catch return false,
                    .text_type = .bold,
                    .size = 22,
                    .color = 0x0D5936,
                    .backing_buffer = &[0]u8{},
                };

                ui.elements.add(.{ .status = ui.StatusText{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = text_data,
                    .initial_size = 22,
                } }) catch return false;
            }
        },
        .attack => plr.attack = reader.read(i32),
        .defense => plr.defense = reader.read(i32),
        .speed => plr.speed = reader.read(i32),
        .dexterity => plr.dexterity = reader.read(i32),
        .vitality => plr.vitality = reader.read(i32),
        .wisdom => plr.wisdom = reader.read(i32),
        .condition => plr.condition = reader.read(utils.Condition),
        .inv_0, .inv_1, .inv_2, .inv_3, .inv_4, .inv_5, .inv_6, .inv_7, .inv_8, .inv_9, .inv_10, .inv_11 => {
            const inv_idx = @intFromEnum(stat_type) - @intFromEnum(game_data.StatType.inv_0);
            const item = reader.read(i32);
            plr.inventory[inv_idx] = item;
            if (plr.obj_id == map.local_player_id)
                ui.in_game_screen.setInvItem(item, inv_idx);
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
        .fame => {
            const last_fame = plr.fame;
            plr.fame = reader.read(i32);
            if (last_fame != 0 and last_fame < plr.fame and plr.level >= 20) {
                const text_data = ui.TextData{
                    .text = std.fmt.allocPrint(allocator, "+{d} Fame", .{plr.fame - last_fame}) catch return false,
                    .text_type = .bold,
                    .size = 22,
                    .color = 0xE64F2A,
                    .backing_buffer = &[0]u8{},
                };

                ui.elements.add(.{ .status = ui.StatusText{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = text_data,
                    .initial_size = 22,
                } }) catch return false;
            }
        },
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
            const item = reader.read(i32);
            plr.inventory[backpack_idx] = item;
            if (plr.obj_id == map.local_player_id)
                ui.in_game_screen.setInvItem(item, backpack_idx);
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

fn parseObjStatData(obj: *map.GameObject, stat_type: game_data.StatType, allocator: std.mem.Allocator) bool {
    @setEvalBranchQuota(5000);
    switch (stat_type) {
        .max_hp => obj.max_hp = reader.read(i32),
        .hp => obj.hp = reader.read(i32),
        .size => obj.size = @as(f32, @floatFromInt(reader.read(i32))) / 100.0,
        .level => obj.level = reader.read(i32),
        .defense => obj.defense = reader.read(i32),
        .condition => obj.condition = reader.read(utils.Condition),
        .inv_0, .inv_1, .inv_2, .inv_3, .inv_4, .inv_5, .inv_6, .inv_7 => {
            const inv_idx = @intFromEnum(stat_type) - @intFromEnum(game_data.StatType.inv_0);
            const item = reader.read(i32);
            obj.inventory[inv_idx] = item;
            if (obj.obj_id == map.interactive_id.load(.Acquire)) {
                ui.in_game_screen.setContainerItem(item, inv_idx);
            }
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

fn writeBuffer() void {
    stream.writer().writeAll(writer.buffer[0..writer.index]) catch |e| {
        onError(e);
        return;
    };
    writer.index = 0;
    writer.write_lock.unlock();
}

pub fn sendAcceptTrade(my_offer: []bool, your_offer: []bool) void {
    if (!connected) {
        std.log.err("Could not send AcceptTrade, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - AcceptTrade: my_offer={any} your_offer={any}", .{ my_offer, your_offer });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.accept_trade));
    writer.write(my_offer);
    writer.write(your_offer);
    writer.updateLength();

    writeBuffer();
}

pub fn sendAoeAck(time: u32, position: Position) void {
    if (!connected) {
        std.log.err("Could not send AoeAck, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - AoeAck: time={d} position={any}", .{ time, position });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.aoe_ack));
    writer.write(time);
    writer.write(position);
    writer.updateLength();

    writeBuffer();
}

pub fn sendBuy(object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send Buy, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Buy: object_id={d}", .{object_id});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.buy));
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendCancelTrade() void {
    if (!connected) {
        std.log.err("Could not send CancelTrade, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - CancelTrade", .{});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.cancel_trade));
    writer.updateLength();

    writeBuffer();
}

pub fn sendChangeGuildRank(name: []const u8, guild_rank: i32) void {
    if (!connected) {
        std.log.err("Could not send ChangeGuildRank, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - ChangeGuildRank: name={s} guild_rank={}", .{ name, guild_rank });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.change_guild_rank));
    writer.write(name);
    writer.write(guild_rank);
    writer.updateLength();

    writeBuffer();
}

pub fn sendChangeTrade(offer: []bool) void {
    if (!connected) {
        std.log.err("Could not send ChangeTrade, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - ChangeTrade: offer={any}", .{offer});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.change_trade));
    writer.write(offer);
    writer.updateLength();

    writeBuffer();
}

pub fn sendCheckCredits() void {
    if (!connected) {
        std.log.err("Could not send CheckCredits, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - CheckCredits", .{});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.check_credits));
    writer.updateLength();

    writeBuffer();
}

pub fn sendChooseName(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send ChooseName, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - ChooseName: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.choose_name));
    writer.write(name);
    writer.updateLength();

    writeBuffer();
}

pub fn sendCreate(class_type: u16, skin_type: u16) void {
    if (!connected) {
        std.log.err("Could not send Create, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Create: class_type={d} skin_type={d}", .{ class_type, skin_type });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.create));
    writer.write(class_type);
    writer.write(skin_type);
    writer.updateLength();

    writeBuffer();
}

pub fn sendCreateGuild(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send CreateGuild, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - CreateGuild: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.create_guild));
    writer.write(name);
    writer.updateLength();

    writeBuffer();
}

pub fn sendEditAccountList(account_list_id: i32, add: bool, object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send EditAccountList, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - EditAccountList: account_list_id={d} add={any} object_id={d}", .{ account_list_id, add, object_id });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.edit_account_list));
    writer.write(account_list_id);
    writer.write(add);
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendEnemyHit(time: i64, bullet_id: u8, target_id: i32, killed: bool) void {
    if (!connected) {
        std.log.err("Could not send EnemyHit, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - EnemyHit: time={d} bullet_id={d} target_id={d} killed={any}", .{ time, bullet_id, target_id, killed });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.enemy_hit));
    writer.write(time);
    writer.write(bullet_id);
    writer.write(target_id);
    writer.write(killed);
    writer.updateLength();

    writeBuffer();
}

pub fn sendEscape() void {
    if (!connected) {
        std.log.err("Could not send Escape, client is not connected", .{});
    }

    if (std.mem.eql(u8, map.name, "Nexus")) {
        return;
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Escape", .{});

    main.clear();
    main.tick_frame = false;

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.escape));
    writer.updateLength();

    writeBuffer();
}

pub fn sendGotoAck(time: i64) void {
    if (!connected) {
        std.log.err("Could not send GotoAck, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - GotoAck: time={d}", .{time});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.goto_ack));
    writer.write(time);
    writer.updateLength();

    writeBuffer();
}

pub fn sendGroundDamage(time: i64, position: Position) void {
    if (!connected) {
        std.log.err("Could not send GroundDamage, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - GroundDamage: time={d} position={any}", .{ time, position });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.ground_damage));
    writer.write(time);
    writer.write(position);
    writer.updateLength();

    writeBuffer();
}

pub fn sendGuildInvite(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send GuildInvite, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - GuildInvite: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.guild_invite));
    writer.write(name);
    writer.updateLength();

    writeBuffer();
}

pub fn sendGuildRemove(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send GuildRemove, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - GuildRemove: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.guild_remove));
    writer.updateLength();

    writeBuffer();
}

pub fn sendHello(build_ver: []const u8, gameId: i32, email: []const u8, password: []const u8, char_id: i16, create_char: bool, class_type: u16, skin_type: u16) void {
    if (!connected) {
        std.log.err("Could not send Hello, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Hello: build_ver={s}, game_id={d}, email={s}, password={s}, char_id={d}, create_char={any}, class_type={d}, skin_type={d}", .{ build_ver, gameId, email, password, char_id, create_char, class_type, skin_type });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.hello));
    writer.write(build_ver);
    writer.write(gameId);
    writer.write(email);
    writer.write(password);
    writer.write(char_id);
    writer.write(create_char);
    if (create_char) {
        writer.write(class_type);
        writer.write(skin_type);
    }
    writer.updateLength();

    writeBuffer();
}

pub fn sendInvDrop(slot_object: ObjectSlot) void {
    if (!connected) {
        std.log.err("Could not send InvDrop, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - InvDrop: slot_object={any}", .{slot_object});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.inv_drop));
    writer.write(slot_object);
    writer.updateLength();

    writeBuffer();
}

pub fn sendInvSwap(time: i64, position: Position, from_slot: ObjectSlot, to_slot: ObjectSlot) void {
    if (!connected) {
        std.log.err("Could not send InvSwap, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - InvSwap: time={d} position={any} from_slot={any} to_slot={any}", .{ time, position, from_slot, to_slot });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.inv_swap));
    writer.write(time);
    writer.write(position);
    writer.write(from_slot);
    writer.write(to_slot);
    writer.updateLength();

    writeBuffer();
}

pub fn sendJoinGuild(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send JoinGuild, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - JoinGuild: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.join_guild));
    writer.write(name);
    writer.updateLength();

    writeBuffer();
}

pub fn sendLoad(char_id: i32) void {
    if (!connected) {
        std.log.err("Could not send Load, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Load: char_id={d}", .{char_id});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.load));
    writer.write(char_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendMove(tick_id: i32, time: i64, pos_x: f32, pos_y: f32, records: []const TimedPosition) void {
    if (!connected) {
        std.log.err("Could not send Move, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s)
        std.log.debug("Send - Move: tick_id={d} time={d} pos_x={d} pos_y={d} records={any}", .{ tick_id, time, pos_x, pos_y, records });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.move));
    writer.write(tick_id);
    writer.write(time);
    writer.write(pos_x);
    writer.write(pos_y);
    writer.write(records);
    writer.updateLength();

    writeBuffer();

    if (map.localPlayerRef()) |local_player| {
        local_player.onMove();
    }
}

pub fn sendOtherHit(time: i64, bullet_id: u8, object_id: i32, target_id: i32) void {
    if (!connected) {
        std.log.err("Could not send OtherHit, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - OtherHit: time={d} bullet_id={d} object_id={d} target_id={d}", .{ time, bullet_id, object_id, target_id });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.other_hit));
    writer.write(time);
    writer.write(bullet_id);
    writer.write(object_id);
    writer.write(target_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendPlayerHit(bullet_id: u8, object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send PlayerHit, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - PlayerHit: bullet_id={d} object_id={d}", .{ bullet_id, object_id });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.player_hit));
    writer.write(bullet_id);
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendPlayerShoot(time: i64, bullet_id: u8, container_type: u16, starting_pos: Position, angle: f32) void {
    if (!connected) {
        std.log.err("Could not send PlayerShoot, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - PlayerShoot: time={d} bullet_id={d} container_type={d} staring_pos={any} angle={d}", .{ time, bullet_id, container_type, starting_pos, angle });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.player_shoot));
    writer.write(time);
    writer.write(bullet_id);
    writer.write(container_type);
    writer.write(starting_pos);
    writer.write(angle);
    writer.updateLength();

    writeBuffer();
}

pub fn sendPlayerText(text: []const u8) void {
    if (!connected) {
        std.log.err("Could not send PlayerText, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - PlayerText: text={s}", .{text});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.player_text));
    writer.write(text);
    writer.updateLength();

    writeBuffer();
}

pub fn sendPong(serial: i32, time: i64) void {
    if (!connected) {
        std.log.err("Could not send Pong, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Pong: serial={d} time={d}", .{ serial, time });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.pong));
    writer.write(serial);
    writer.write(time);
    writer.updateLength();

    writeBuffer();
}

pub fn sendRequestTrade(name: []const u8) void {
    if (!connected) {
        std.log.err("Could not send RequestTrade, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - RequestTrade: name={s}", .{name});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.request_trade));
    writer.write(name);
    writer.updateLength();

    writeBuffer();
}

pub fn sendReskin(skin_id: i32) void {
    if (!connected) {
        std.log.err("Could not send Reskin, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Reskin: skin_id={d}", .{skin_id});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.reskin));
    writer.write(skin_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendSetCondition(condition_effect: i32, condition_duration: i32) void {
    if (!connected) {
        std.log.err("Could not send SetCondition, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - SetCondition: condition_effect={d} condition_duration={d}", .{ condition_effect, condition_duration });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.set_condition));
    writer.write(condition_effect);
    writer.write(condition_duration);
    writer.updateLength();

    writeBuffer();
}

pub fn sendShootAck(time: i64) void {
    if (!connected) {
        std.log.err("Could not send ShootAck, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - ShootAck: time={d}", .{time});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.shoot_ack));
    writer.write(time);
    writer.updateLength();

    writeBuffer();
}

pub fn sendSquareHit(time: i64, bullet_id: u8, object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send SquareHit, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - SquareHit: time={d} bullet_id={d} object_id={d}", .{ time, bullet_id, object_id });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.square_hit));
    writer.write(time);
    writer.write(bullet_id);
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendTeleport(object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send Teleport, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - Teleport: object_id={d}", .{object_id});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.teleport));
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}

pub fn sendUpdateAck() void {
    if (!connected) {
        std.log.err("Could not send UpdateAck, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s)
        std.log.debug("Send - UpdateAck", .{});

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.update_ack));
    writer.updateLength();

    writeBuffer();
}

pub fn sendUseItem(
    time: i64,
    slot_object: ObjectSlot,
    use_position: Position,
    use_type: u8,
) void {
    if (!connected) {
        std.log.err("Could not send UseItem, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - UseItem: time={d} slot_object={any} use_position={any} use_type={d} ", .{ time, slot_object, use_position, use_type });

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.use_item));
    writer.write(time);
    writer.write(slot_object);
    writer.write(use_position);
    writer.write(use_type);
    writer.updateLength();

    writeBuffer();
}

pub fn sendUsePortal(object_id: i32) void {
    if (!connected) {
        std.log.err("Could not send UsePortal, client is not connected", .{});
    }

    if (settings.log_packets == .all or settings.log_packets == .c2s or settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Send - UsePortal: object_id={d}", .{object_id});

    main.clear();
    main.tick_frame = false;

    writer.writeLength();
    writer.write(@intFromEnum(C2SPacketId.use_portal));
    writer.write(object_id);
    writer.updateLength();

    writeBuffer();
}
