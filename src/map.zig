const std = @import("std");
const network = @import("network.zig");
const game_data = @import("game_data.zig");
const camera = @import("camera.zig");
const input = @import("input.zig");
const main = @import("main.zig");

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

    pub fn update(self: *GameObject, time: i32, dt: i32) void {
        _ = dt;
        _ = time;
        _ = self;
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
    attack_start: i32 = 0,
    attack_angle: f32 = 0,
    next_bullet_id: u8 = 0,

    pub fn addToMap(self: Player) void {
        players.append(self) catch |err| {
            std.debug.print("Error adding player to map: {}\n", .{err});
        };

        std.debug.print("Added player with obj_id: {}, obj_type: {} to map\n", .{ self.obj_id, self.obj_type });
    }

    pub fn shoot(self: *Player, angle: f32, time: i32) void {
        const weapon = self.inventory[0];
        if (weapon == -1)
            return;

        const item_props = game_data.item_type_to_props.get(@intCast(weapon));
        if (item_props == null or item_props.?.projectile == null)
            return;

        const attack_delay: i32 = @intFromFloat(200.0 / item_props.?.rate_of_fire);
        if (time < self.attack_start + attack_delay)
            return;

        const projs_len = item_props.?.num_projectiles;
        const arc_gap = item_props.?.arc_gap;
        const total_angle = arc_gap * @as(f32, @floatFromInt(projs_len - 1));
        var current_angle = angle - total_angle / 2.0;
        const proj_props = item_props.?.projectile.?;
        for (0..projs_len) |_| {
            const bullet_id = @mod(self.next_bullet_id + 1, 128);
            self.next_bullet_id = bullet_id;
            const x = self.x + @cos(current_angle) * 0.25;
            const y = self.y + @sin(current_angle) * 0.25;
            // zig fmt: off
            var proj = Projectile{ 
                .x = x,
                .y = y,
                .props = proj_props,
                .angle = current_angle,
                .start_time = time,
                .bullet_id = bullet_id,
                .owner_id = self.obj_id,
            };
            // zig fmt: on
            proj.addToMap();

            if (main.server) |*server| {
                server.sendPlayerShoot(time, bullet_id, @intCast(weapon), network.Position{ .x = x, .y = y }, current_angle) catch |e| {
                    std.log.err("PlayerShoot failure: {any}", .{e});
                };
            }

            current_angle += arc_gap;
        }

        self.attack_angle = angle - camera.angle;
        self.attack_start = time;
    }

    pub fn update(self: *Player, time: i32, dt: i32) void {
        _ = dt;
        _ = time;
        _ = self;
    }
};

pub const Projectile = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,
    props: game_data.ProjProps,
    angle: f32 = 0,
    start_time: i32 = -1,
    bullet_id: u8 = 0,
    owner_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn addToMap(self: Projectile) void {
        _ = self;
    }

    pub fn update(self: *Projectile, time: i32, dt: i32, allocator: std.mem.Allocator) bool {
        _ = allocator;
        _ = dt;
        _ = time;
        _ = self;
        return true;
    }
};

pub var objects: std.ArrayList(GameObject) = undefined;
pub var players: std.ArrayList(Player) = undefined;
pub var projectiles: std.ArrayList(Projectile) = undefined;
pub var proj_indices_to_remove: std.ArrayList(usize) = undefined;

pub var local_player_id: i32 = -1;

pub var move_records: std.ArrayList(network.TimedPosition) = undefined;
pub var last_records_clear_time: i32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(GameObject).init(allocator);
    players = std.ArrayList(Player).init(allocator);
    projectiles = std.ArrayList(Projectile).init(allocator);
    proj_indices_to_remove = std.ArrayList(usize).init(allocator);
    move_records = std.ArrayList(network.TimedPosition).init(allocator);
}

pub fn deinit() void {
    objects.deinit();
    players.deinit();
    projectiles.deinit();
    proj_indices_to_remove.deinit();
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

pub fn update(time: i32, dt: i32, allocator: std.mem.Allocator) void {
    if (findPlayer(local_player_id)) |local_player| {
        camera.update(local_player.x, local_player.y, dt, input.rotate);
        if (input.attacking) {
            const y: f32 = @floatCast(input.mouse_y);
            const x: f32 = @floatCast(input.mouse_x);
            const shoot_angle = std.math.atan2(f32, y - camera.screen_height / 2.0, x - camera.screen_width / 2.0) + camera.angle;
            local_player.shoot(shoot_angle, time);
        }
    }

    for (players.items) |*player| {
        player.update(time, dt);
    }

    for (objects.items) |*obj| {
        obj.update(time, dt);
    }

    for (projectiles.items, 0..) |*proj, i| {
        if (!proj.update(time, dt, allocator))
            proj_indices_to_remove.append(i) catch |e| {
                std.log.err("Out of memory: {any}", .{e});
            };
    }

    std.mem.reverse(usize, proj_indices_to_remove.items);

    for (proj_indices_to_remove.items) |idx| {
        _ = projectiles.orderedRemove(idx);
    }

    proj_indices_to_remove.clearRetainingCapacity();
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
