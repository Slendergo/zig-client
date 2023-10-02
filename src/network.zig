const std = @import("std");
const utils = @import("utils.zig");
const settings = @import("settings.zig");
const main = @import("main.zig");
const map = @import("map.zig");
const game_data = @import("game_data.zig");
const ui = @import("ui/ui.zig");
const camera = @import("camera.zig");
const assets = @import("assets.zig");
const particles = @import("particles.zig");
const builtin = @import("builtin");
const C2SQueue = @import("spsc.zig").UnboundedQueue(C2SPacket);

pub const TimedPosition = packed struct {
    time: i64,
    x: f32,
    y: f32,
};

pub const TileData = extern struct {
    x: u16,
    y: u16,
    tile_type: u16,
};

pub const TradeItem = extern struct {
    item: i32 align(1),
    slot_type: i32 align(1),
    tradeable: bool align(1),
    included: bool align(1),
};

pub const ARGB = packed struct {
    a: u8,
    r: u8,
    g: u8,
    b: u8,
};

const C2SPacketId = enum(u8) {
    unknown = 0,
    accept_trade = 1,
    aoe_ack = 2,
    buy = 3,
    cancel_trade = 4,
    change_guild_rank = 5,
    change_trade = 6,
    choose_name = 8,
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
    move = 23,
    other_hit = 24,
    player_hit = 25,
    player_shoot = 26,
    player_text = 27,
    pong = 28,
    request_trade = 29,
    reskin = 30,
    shoot_ack = 32,
    square_hit = 33,
    teleport = 34,
    update_ack = 35,
    use_item = 36,
    use_portal = 37,
};

// All packets without variable length fields (like slices) should be packed.
// This allows us to directly copy the struct into the buffer
pub const C2SPacket = union(C2SPacketId) {
    unknown: packed struct {},
    accept_trade: struct { my_offer: []bool, your_offer: []bool },
    aoe_ack: packed struct { time: u32, x: f32, y: f32 },
    buy: packed struct { obj_id: i32 },
    cancel_trade: packed struct {},
    change_guild_rank: struct { name: []const u8, rank: i32 },
    change_trade: struct { offer: []bool },
    choose_name: struct { name: []const u8 },
    create_guild: struct { guild_name: []const u8 },
    edit_account_list: packed struct { list_id: i32, add: bool, obj_id: i32 },
    enemy_hit: packed struct { time: i64, bullet_id: u8, target_id: i32, killed: bool },
    escape: packed struct {},
    goto_ack: packed struct { time: i64 },
    ground_damage: packed struct { time: i64, x: f32, y: f32 },
    guild_invite: struct { name: []const u8 },
    guild_remove: struct { name: []const u8 },
    hello: struct {
        build_ver: []const u8,
        game_id: i32,
        email: []const u8,
        password: []const u8,
        char_id: i16,
        create_char: bool,
        class_type: u16,
        skin_type: u16,
    },
    inv_drop: packed struct { obj_id: i32, slot_id: u8, obj_type: i32 },
    inv_swap: packed struct {
        time: i64,
        x: f32,
        y: f32,
        from_obj_id: i32,
        from_slot_id: u8,
        from_obj_type: i32,
        to_obj_id: i32,
        to_slot_id: u8,
        to_obj_type: i32,
    },
    join_guild: struct { name: []const u8 },
    move: struct { tick_id: i32, time: i64, pos_x: f32, pos_y: f32, records: []const TimedPosition },
    other_hit: packed struct { time: i64, bullet_id: u8, object_id: i32, target_id: i32 },
    player_hit: packed struct { bullet_id: u8, object_id: i32 },
    player_shoot: packed struct { time: i64, bullet_id: u8, container_type: u16, start_x: f32, start_y: f32, angle: f32 },
    player_text: struct { text: []const u8 },
    pong: packed struct { serial: i32, time: i64 },
    request_trade: struct { name: []const u8 },
    reskin: packed struct { skin_id: i32 },
    shoot_ack: packed struct { time: i64 },
    square_hit: packed struct { time: i64, bullet_id: u8, obj_id: i32 },
    teleport: packed struct { obj_id: i32 },
    update_ack: packed struct {},
    use_item: packed struct { time: i64, obj_id: i32, slot_id: u8, obj_type: i32, x: f32, y: f32, use_type: game_data.UseType },
    use_portal: packed struct { obj_id: i32 },
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

pub var connected = false;
pub var queue: C2SQueue = undefined;

var queue_lock: std.Thread.Mutex = .{};
var message_len: u16 = 65535;
var buffer_idx: usize = 0;
var stream: std.net.Stream = undefined;
var reader = utils.PacketReader{};
var writer = utils.PacketWriter{};

pub fn init(ip: []const u8, port: u16, allocator: *std.mem.Allocator) void {
    stream = std.net.tcpConnectToAddress(std.net.Address.parseIp(ip, port) catch |address_error| {
        std.log.err("Could not parse address {s}:{d}: {any}", .{ ip, port, address_error });
        return;
    }) catch |connect_error| {
        std.log.err("Could not connect to address {s}:{d}: {any}", .{ ip, port, connect_error });
        return;
    };

    queue = C2SQueue.init(allocator) catch |e| {
        std.log.err("Queue init failed: {any}", .{e});
        return;
    };

    connected = true;
}

pub fn deinit(allocator: *std.mem.Allocator) void {
    queue.deinit(allocator);
    stream.close();
    connected = false;
}

pub fn onError(e: anytype) void {
    std.log.err("Error while handling server packets: {any}", .{e});
    main.disconnect();
}

pub fn accept(allocator: std.mem.Allocator) void {
    while (queue.pop()) |packet| {
        sendPacket(packet);
    }

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
            .damage => handleDamage(allocator),
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

    main.network_fba.reset();
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
            const item_props = game_data.item_type_to_props.getPtr(@intCast(container_type));
            const proj_props = &item_props.?.projectile.?;
            // in case of Shoot AE this will cause problems as we send 1 per shot
            // (in future might be ideal to redo the shoot AE in PlayerShoot as we can credit the shot for AE to use for validation)
            // const projs_len = item_props.?.num_projectiles;
            // for (0..projs_len) |_| {
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
            // }

            const attack_period: i64 = @intFromFloat((1.0 / player.attackFrequency()) * (1.0 / item_props.?.rate_of_fire) * std.time.us_per_ms);
            player.attack_period = attack_period;
            player.attack_angle = angle - camera.angle;
            player.attack_start = main.current_time;
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - AllyShoot: bullet_id={d}, owner_id={d}, container_type={d}, angle={e}", .{ bullet_id, owner_id, container_type, angle });
}

fn handleAoe() void {
    const x = reader.read(f32);
    const y = reader.read(f32);
    const radius = reader.read(f32);
    const damage = reader.read(i16);
    const condition_effect = reader.read(utils.Condition);
    const duration = reader.read(f32);
    const orig_type = reader.read(u8);

    var effect = particles.AoeEffect{
        .x = x,
        .y = y,
        .color = 0xFF0000,
        .radius = radius,
    };
    effect.addToMap();

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - Aoe: x={e}, y={e}, radius={e}, damage={d}, condition_effect={any}, duration={e}, orig_type={d}", .{ x, y, radius, damage, condition_effect, duration, orig_type });
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

fn handleDamage(allocator: std.mem.Allocator) void {
    const target_id = reader.read(i32);
    const effects = reader.read(utils.Condition);
    const amount = reader.read(u16);
    const kill = reader.read(bool);

    if (map.findEntityRef(target_id)) |en| {
        switch (en.*) {
            .player => |*player| {
                player.takeDamage(
                    amount,
                    kill,
                    false,
                    @divFloor(main.current_time, std.time.us_per_ms),
                    effects,
                    player.colors,
                    0.0,
                    100.0 / 10000.0,
                    false,
                    allocator,
                );
            },
            .object => |*object| {
                object.takeDamage(
                    amount,
                    kill,
                    false,
                    @divFloor(main.current_time, std.time.us_per_ms),
                    effects,
                    object.colors,
                    0.0,
                    100.0 / 10000.0,
                    false,
                    allocator,
                );
            },
            else => {},
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick or settings.log_packets == .all_non_tick)
        std.log.debug("Recv - Damage: target_id={d}, effects={any}, damage_amount={d}, kill={any}", .{ target_id, effects, amount, kill });
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
    const start_x = reader.read(f32);
    const start_y = reader.read(f32);
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
            .x = start_x,
            .y = start_y,
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
        std.log.debug("Recv - EnemyShoot: bullet_id={d}, owner_id={d}, bullet_type={d}, x={e}, y={e}, angle={e}, damage={d}, num_shots={d}, angle_inc={e}", .{ bullet_id, owner_id, bullet_type, start_x, start_y, angle, damage, num_shots, angle_inc });

    sendPacket(.{ .shoot_ack = .{ .time = main.current_time } });
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
    const x = reader.read(f32);
    const y = reader.read(f32);

    if (map.findEntityRef(object_id)) |en| {
        if (en.* == .player) {
            const player = &en.player;
            if (object_id == map.local_player_id) {
                player.x = x;
                player.y = y;
            } else {
                player.target_x = x;
                player.target_y = y;
                player.tick_x = player.x;
                player.tick_y = player.y;
            }
        }
    } else {
        std.log.err("Object id {d} not found while attempting to goto to pos x={d}, y={d}", .{ object_id, x, y });
    }

    sendPacket(.{ .goto_ack = .{ .time = main.current_time } });

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Goto: object_id={d}, x={e}, y={e}", .{ object_id, x, y });
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

    const width: u32 = @intCast(@max(0, reader.read(i32)));
    const height: u32 = @intCast(@max(0, reader.read(i32)));
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
            while (!map.object_lock.tryLock()) {}
            defer map.object_lock.unlock();

            if (map.localPlayerRef()) |local_player| {
                sendPacket(.{ .move = .{
                    .tick_id = tick_id,
                    .time = main.current_time,
                    .pos_x = local_player.x,
                    .pos_y = local_player.y,
                    .records = map.move_records.items(),
                } });

                local_player.onMove();
            } else {
                sendPacket(.{ .move = .{
                    .tick_id = tick_id,
                    .time = main.current_time,
                    .pos_x = -1,
                    .pos_y = -1,
                    .records = &[0]TimedPosition{},
                } });
            }
        }
    }

    const statuses_len = reader.read(u16);
    for (0..statuses_len) |_| {
        const obj_id = reader.read(i32);
        const x = reader.read(f32);
        const y = reader.read(f32);

        const stats_len = reader.read(u16);
        const stats_byte_len = reader.read(u16);
        const next_obj_idx = reader.index + stats_byte_len;

        if (map.findEntityRef(obj_id)) |en| {
            switch (en.*) {
                .player => |*player| {
                    if (player.obj_id != map.local_player_id) {
                        player.target_x = x;
                        player.target_y = y;
                        player.tick_x = player.x;
                        player.tick_y = player.y;
                        const y_dt = y - player.y;
                        const x_dt = x - player.x;
                        player.move_angle = if (y_dt <= 0 and x_dt <= 0) std.math.nan(f32) else std.math.atan2(f32, y_dt, x_dt);

                        const float_tick_time = @as(f32, @floatFromInt(tick_time));
                        player.x_dir = (player.target_x - player.tick_x) / float_tick_time;
                        player.y_dir = (player.target_y - player.tick_y) / float_tick_time; // used for animation stuff for non "self" player
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
                    object.target_x = x;
                    object.target_y = y;
                    object.tick_x = object.x;
                    object.tick_y = object.y;
                    const y_dt = y - object.y;
                    const x_dt = x - object.x;
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
        std.log.err("Could not find object in NewTick (obj_id={d}, x={d}, y={d})", .{ obj_id, x, y });
    }

    const ms_time = @divFloor(main.current_time, std.time.us_per_ms);
    map.last_tick_ms = @floatFromInt(if (map.last_tick_time == 0) tick_time else ms_time - map.last_tick_time);
    map.last_tick_time = ms_time;

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
            ui.StatusText.add(.{
                .obj_id = en.player.obj_id,
                .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                .lifetime = 2000,
                .text_data = text_data,
                .initial_size = 22,
            }) catch unreachable;
        } else if (en == .object) {
            ui.StatusText.add(.{
                .obj_id = en.object.obj_id,
                .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                .lifetime = 2000,
                .text_data = text_data,
                .initial_size = 22,
            }) catch unreachable;
        }
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - Notification: object_id={d}, message={s}, color={any}", .{ object_id, message, color });
}

fn handlePing() void {
    const serial = reader.read(i32);

    sendPacket(.{ .pong = .{ .serial = serial, .time = main.current_time } });

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
    const start_x = reader.read(f32);
    const start_y = reader.read(f32);
    const angle = reader.read(f32);
    const damage = reader.read(i16);
    const num_shots = 1; // todo
    const angle_inc = 0.0;

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - ServerPlayerShoot: bullet_id={d}, owner_id={d}, container_type={d}, x={e}, y={e}, angle={e}, damage={d}", .{ bullet_id, owner_id, container_type, start_x, start_y, angle, damage });

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
                    .x = start_x,
                    .y = start_y,
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
                sendPacket(.{ .shoot_ack = .{ .time = main.current_time } });
            }
        } else {
            if (needs_ack) {
                sendPacket(.{ .shoot_ack = .{ .time = -1 } });
            }
        }
    }
}

fn handleShowEffect() void {
    const effect_type: EffectType = @enumFromInt(reader.read(u8));
    const target_object_id = reader.read(i32);
    const x1 = reader.read(f32);
    const y1 = reader.read(f32);
    const x2 = reader.read(f32);
    const y2 = reader.read(f32);
    const color = @byteSwap(@as(u32, @bitCast(reader.read(ARGB))));

    switch (effect_type) {
        .throw => {
            var start_x = x2;
            var start_y = y2;

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

            var effect = particles.ThrowEffect{
                .start_x = start_x,
                .start_y = start_y,
                .end_x = x1,
                .end_y = y1,
                .color = color,
                .duration = 1500,
            };
            effect.addToMap();
        },
        .teleport => {
            var effect = particles.TeleportEffect{
                .x = x1,
                .y = y1,
            };
            effect.addToMap();
        },
        .trail => {
            var start_x = x2;
            var start_y = y2;

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

            var effect = particles.LineEffect{
                .start_x = start_x,
                .start_y = start_y,
                .end_x = x1,
                .end_y = y1,
                .color = color,
            };
            effect.addToMap();
        },
        .potion => {
            // the effect itself handles checks for invalid entity
            var effect = particles.HealEffect{
                .target_id = target_object_id,
                .color = color,
            };
            effect.addToMap();
        },
        .earthquake => {
            camera.quake = true;
            camera.quake_amount = 0.0;
        },
        else => {},
    }

    if (settings.log_packets == .all or settings.log_packets == .s2c or settings.log_packets == .s2c_non_tick)
        std.log.debug("Recv - ShowEffect: effect_type={any}, target_object_id={d}, x1={e}, y1={e}, x2={e}, y2={e}, color={any}", .{ effect_type, target_object_id, x1, y1, x2, y2, color });
}

fn handleText(allocator: std.mem.Allocator) void {
    const name = reader.read([]u8);
    const object_id = reader.read(i32);
    const num_stars = reader.read(i32);
    const bubble_time = reader.read(u8);
    const recipient = reader.read([]u8);
    const text = reader.read([]u8);

    while (!map.object_lock.tryLock()) {}
    defer map.object_lock.unlock();

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

        ui.SpeechBalloon.add(.{
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
        }) catch unreachable;
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
            sendPacket(.{ .update_ack = .{} });
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
        const x = reader.read(f32);
        const y = reader.read(f32);

        const stats_len = reader.read(u16);
        const stats_byte_len = reader.read(u16);
        const next_obj_idx = reader.index + stats_byte_len;
        const class = game_data.obj_type_to_class.get(obj_type) orelse game_data.ClassType.game_object;

        switch (class) {
            .player => {
                var player = map.Player{ .x = x, .y = y, .obj_id = obj_id, .obj_type = obj_type };
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

                player.addToMap(allocator);
            },
            inline else => {
                var obj = map.GameObject{ .x = x, .y = y, .obj_id = obj_id, .obj_type = obj_type };
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

                obj.addToMap(allocator);
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
        .hp => {
            plr.hp = reader.read(i32);
            if (plr.hp > 0)
                plr.dead = false;
        },
        .size => plr.size = @as(f32, @floatFromInt(reader.read(i32))) / 100.0,
        .max_mp => plr.max_mp = reader.read(i32),
        .mp => plr.mp = reader.read(i32),
        .exp_goal => plr.exp_goal = reader.read(i32),
        .exp => {
            const last_xp = plr.exp;
            plr.exp = reader.read(i32);
            if (last_xp != 0 and last_xp < plr.exp and (settings.always_show_xp_gain or plr.level < 20)) {
                ui.StatusText.add(.{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = .{
                        .text = std.fmt.allocPrint(allocator, "+{d} XP", .{plr.exp - last_xp}) catch return false,
                        .text_type = .bold,
                        .size = 22,
                        .color = 0x0D5936,
                        .backing_buffer = &[0]u8{},
                    },
                    .initial_size = 22,
                }) catch return false;
            }
        },
        .level => {
            const last_level = plr.level;
            plr.level = reader.read(i32);
            if (last_level != 0 and last_level < plr.level) {
                ui.StatusText.add(.{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = .{
                        .text = std.fmt.allocPrint(allocator, "Level Up!", .{}) catch return false,
                        .text_type = .bold,
                        .size = 22,
                        .color = 0x0D5936,
                        .backing_buffer = &[0]u8{},
                    },
                    .initial_size = 22,
                }) catch return false;
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
                ui.StatusText.add(.{
                    .obj_id = plr.obj_id,
                    .start_time = @divFloor(main.current_time, std.time.us_per_ms),
                    .lifetime = 2000,
                    .text_data = .{
                        .text = std.fmt.allocPrint(allocator, "+{d} Fame", .{plr.fame - last_fame}) catch return false,
                        .text_type = .bold,
                        .size = 22,
                        .color = 0xE64F2A,
                        .backing_buffer = &[0]u8{},
                    },
                    .initial_size = 22,
                }) catch return false;
            }
        },
        .fame_goal => plr.fame_goal = reader.read(i32),
        .glow => plr.glow = reader.read(i32),
        .sink_level => plr.sink_level = @floatFromInt(reader.read(u16)),
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
        .hp => {
            obj.hp = reader.read(i32);
            if (obj.hp > 0)
                obj.dead = false;
        },
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

pub fn queuePacket(packet: C2SPacket) void {
    if (packet == .use_portal or packet == .escape) {
        while (queue.pop()) |_| {} // not ideal...
        main.clear();
        main.tick_frame = false;
    }

    queue.push(&main._allocator, packet) catch |e| {
        std.log.err("Packet enqueue failed: {any}", .{e});
        return;
    };
}

fn sendPacket(packet: C2SPacket) void {
    const tag = std.meta.activeTag(packet);
    if (!connected) {
        std.log.err("Could not send {any}, client is not connected", .{tag});
    }

    if (settings.log_packets == .all or
        settings.log_packets == .c2s or
        (settings.log_packets == .c2s_non_tick or settings.log_packets == .all_non_tick) and packet != .move and packet != .update_ack)
    {
        std.log.info("Send: {any}", .{packet}); // todo custom formatting
    }

    writer.writeLength();
    writer.write(@intFromEnum(tag));
    switch (packet) {
        inline else => |data| {
            var data_bytes = std.mem.asBytes(&data);
            const data_type = @TypeOf(data);
            const data_info = @typeInfo(data_type);
            if (data_info.Struct.layout == .Packed) {
                const field_len = (@bitSizeOf(data_info.Struct.backing_integer.?) + 7) / 8;
                if (field_len > 0)
                    writer.writeDirect(data_bytes[0..field_len]);
            } else {
                inline for (data_info.Struct.fields) |field| {
                    const base_offset = @offsetOf(data_type, field.name);
                    const type_info = @typeInfo(field.type);
                    if (type_info == .Pointer and (type_info.Pointer.size == .Slice or type_info.Pointer.size == .Many)) {
                        writer.write(std.mem.bytesAsValue([]type_info.Pointer.child, data_bytes[base_offset .. base_offset + 16]).*);
                    } else {
                        const field_len = (@bitSizeOf(field.type) + 7) / 8;
                        if (field_len > 0)
                            writer.writeDirect(data_bytes[base_offset .. base_offset + field_len]);
                    }
                }
            }
        },
    }
    writer.updateLength();
    stream.writer().writeAll(writer.buffer[0..writer.index]) catch |e| {
        onError(e);
        return;
    };
    writer.index = 0;
}
