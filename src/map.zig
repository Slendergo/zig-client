const std = @import("std");
const network = @import("network.zig");
const game_data = @import("game_data.zig");

pub const GameObject = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,

    x: f32 = 0.0,
    y: f32 = 0.0,

    name: []u8 = undefined,

    size: i32 = 0,

    max_hp: i32 = 0,
    hp: i32 = 0,
    defense: i32 = 0,

    condition: u64 = 0,

    level: i32 = 0,

    tex_1: i32 = 0,
    tex_2: i32 = 0,

    alt_texture_index: i32 = 0,

    inventory: [8]i32 = undefined,
    owner_acc_id: i32 = -1,

    merchant_obj_type: u16 = 0,
    merchant_rem_count: i32 = 0,
    merchant_rem_minute: i32 = 0,

    sellable_price: i32 = 0,
    sellable_currency: game_data.Currency = game_data.Currency.Gold,
    sellable_rank_req: i32 = 0,

    portal_active: bool = false,

    object_connection: i32 = 0,

    owner_account_id: i32 = 0,

    rank_required: i32 = 0,

    pub fn addToMap(self: GameObject) void {
        objects.append(self) catch |err| {
            std.debug.print("Error adding object to map: {}\n", .{err});
        };

        std.debug.print("Added object with obj_id: {}, obj_type: {} to map\n", .{ self.obj_id, self.obj_type });
    }
};

pub const Player = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,

    x: f32 = 0.0,
    y: f32 = 0.0,

    name: []u8 = undefined,
    name_chosen: bool = false,
    account_id: i32 = 0,

    size: i32 = 0,

    max_hp: i32 = 0,
    hp: i32 = 0,
    max_mp: i32 = 0,
    mp: i32 = 0,
    attack: i32 = 0,
    defense: i32 = 0,
    speed: i32 = 0,
    vitality: i32 = 0,
    wisdom: i32 = 0,
    dexterity: i32 = 0,

    hp_boost: i32 = 0,
    mp_boost: i32 = 0,
    attack_bonus: i32 = 0,
    defense_bonus: i32 = 0,
    speed_bonus: i32 = 0,
    vitality_bonus: i32 = 0,
    wisdom_bonus: i32 = 0,
    dexterity_bonus: i32 = 0,

    health_stack_count: i32 = 0,
    magic_stack_count: i32 = 0,

    condition: u64 = 0,

    inventory: [20]i32 = undefined,
    has_backpack: bool = false,

    exp_goal: i32 = 0,
    exp: i32 = 0,
    level: i32 = 0,

    stars: i32 = 0,

    tex_1: i32 = 0,
    tex_2: i32 = 0,
    skin: i32 = 0,
    glow: i32 = 0,

    credits: i32 = 0,
    current_fame: i32 = 0,
    fame: i32 = 0,
    fame_goal: i32 = 0,

    guild: []u8 = undefined,
    guild_rank: i32 = 0,

    oxygen_bar: i32 = 0,
    sink_offset: i32 = 0,

    pub fn addToMap(self: Player) void {
        players.append(self) catch |err| {
            std.debug.print("Error adding player to map: {}\n", .{err});
        };

        std.debug.print("Added player with obj_id: {}, obj_type: {} to map\n", .{ self.obj_id, self.obj_type });
    }
};

pub const Projectile = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,

    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn addToMap() void {}
};

pub var objects: std.ArrayList(GameObject) = undefined;
pub var players: std.ArrayList(Player) = undefined;
pub var projectiles: std.ArrayList(Projectile) = undefined;

pub var local_player_id: i32 = -1;

pub var move_records: std.ArrayList(network.TimedPosition) = undefined;
pub var last_records_clear_time: i32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(GameObject).init(allocator);
    players = std.ArrayList(Player).init(allocator);
    projectiles = std.ArrayList(Projectile).init(allocator);

    move_records = std.ArrayList(network.TimedPosition).init(allocator);
}

pub fn deinit() void {
    objects.deinit();
    players.deinit();
    projectiles.deinit();

    move_records.deinit();
}

pub fn findPlayer(obj_id: i32) ?*Player {
    for (players.items) |*player| {
        if (player.obj_id == obj_id)
            return player;
    }

    return null;
}

pub fn findObject(obj_id: i32) ?*GameObject {
    for (objects.items) |*obj| {
        if (obj.obj_id == obj_id)
            return obj;
    }

    return null;
}

pub fn findProj(obj_id: i32) ?*Projectile {
    for (projectiles.items) |*proj| {
        if (proj.obj_id == obj_id)
            return proj;
    }

    return null;
}

pub fn removePlayer(obj_id: i32) bool {
    for (players.items, 0..) |player, i| {
        if (player.obj_id == obj_id) {
            _ = players.orderedRemove(i);
            return true;
        }
    }

    return false;
}

pub fn removeObject(obj_id: i32) bool {
    for (objects.items, 0..) |object, i| {
        if (object.obj_id == obj_id) {
            _ = objects.orderedRemove(i);
            return true;
        }
    }

    return false;
}

pub fn removeProj(obj_id: i32) bool {
    for (projectiles.items, 0..) |proj, i| {
        if (proj.obj_id == obj_id) {
            _ = projectiles.orderedRemove(i);
            return true;
        }
    }

    return false;
}

pub fn addMoveRecord(time: i32, position: network.Position) void {
    if (last_records_clear_time < 0) {
        return;
    }

    const id: i32 = getId(time);
    if (id < 1 or id > 10) {
        return;
    }

    if (move_records.items.len == 0) {
        move_records.append(network.TimedPosition{ .time = time, .position = position });
        return;
    }

    const curr_record: network.TimedPosition = move_records.items[move_records.items.len - 1];
    const curr_id: i32 = getId(curr_record.time);
    if (id != curr_id) {
        move_records.append(network.TimedPosition{ .time = time, .position = position });
        return;
    }

    const score: i32 = getScore(id, time);
    const curr_score: i32 = getScore(id, curr_record.time);
    if (score < curr_score) {
        curr_record.time = time;
        curr_record.position = position;
    }
}

pub fn clearMoveRecords(time: i32) void {
    move_records.clear();
    last_records_clear_time = time;
}

inline fn getId(time: i32) i32 {
    return (time - last_records_clear_time + 50) / 100;
}

inline fn getScore(id: i32, time: i32) i32 {
    return std.math.absInt(time - last_records_clear_time - id * 100);
}
