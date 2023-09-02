const std = @import("std");
const zstbrp = @import("zstbrp");
const network = @import("network.zig");
const game_data = @import("game_data.zig");
const camera = @import("camera.zig");
const input = @import("input.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const map = @import("map.zig");
const assets = @import("assets.zig");
const ui = @import("ui.zig");

pub const move_threshold: f32 = 0.4;
pub const min_move_speed: f32 = 0.004;
pub const max_move_speed: f32 = 0.0096;
pub const min_attack_freq: f32 = 0.0015;
pub const max_attack_freq: f32 = 0.008;
pub const min_attack_mult: f32 = 0.5;
pub const max_attack_mult: f32 = 2;
pub const max_sink_level: u32 = 18;
const tick_ms = 200.0;

pub const Square = struct {
    tile_type: u16 = 0xFFFF,
    x: f32 = 0.0,
    y: f32 = 0.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),
    left_blend_u: f32 = -1.0,
    left_blend_v: f32 = -1.0,
    top_blend_u: f32 = -1.0,
    top_blend_v: f32 = -1.0,
    right_blend_u: f32 = -1.0,
    right_blend_v: f32 = -1.0,
    bottom_blend_u: f32 = -1.0,
    bottom_blend_v: f32 = -1.0,
    sink: f32 = 0.0,
    speed: f32 = 1.0,
    sinking: bool = false,
    has_wall: bool = false,
    light_color: i32 = -1,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    damage: u16 = 0,
    blocking: bool = false,
    full_occupy: bool = false,
    occupy_square: bool = false,
    anim_type: game_data.GroundAnimType = .none,
    anim_dx: f32 = 0,
    anim_dy: f32 = 0,
    u_offset: f32 = 0,
    v_offset: f32 = 0,

    pub fn updateBlends(square: *Square) void {
        if (square.tile_type == 0xFFFF or square.tile_type == 0xFF)
            return;

        const x: isize = @intFromFloat(square.x);
        const y: isize = @intFromFloat(square.y);
        const props = game_data.ground_type_to_props.get(square.tile_type);
        if (props == null)
            return;

        const current_prio = props.?.blend_prio;

        if (validPos(x - 1, y)) {
            const left_idx: usize = @intCast(x - 1 + y * width);
            const left_sq = squares[left_idx];
            if (left_sq.tile_type != 0xFFFF and left_sq.tile_type != 0xFF) {
                if (game_data.ground_type_to_props.get(left_sq.tile_type)) |left_props| {
                    const left_blend_prio = left_props.blend_prio;
                    if (left_blend_prio > current_prio) {
                        square.left_blend_u = left_sq.atlas_data.tex_u;
                        square.left_blend_v = left_sq.atlas_data.tex_v;
                        squares[left_idx].right_blend_u = -1.0;
                        squares[left_idx].right_blend_v = -1.0;
                    } else if (left_blend_prio < current_prio) {
                        squares[left_idx].right_blend_u = square.atlas_data.tex_u;
                        squares[left_idx].right_blend_v = square.atlas_data.tex_v;
                        square.left_blend_u = -1.0;
                        square.left_blend_v = -1.0;
                    } else {
                        square.left_blend_u = -1.0;
                        square.left_blend_v = -1.0;
                        squares[left_idx].right_blend_u = -1.0;
                        squares[left_idx].right_blend_v = -1.0;
                    }
                } else {
                    square.left_blend_u = -1.0;
                    square.left_blend_v = -1.0;
                    squares[left_idx].right_blend_u = -1.0;
                    squares[left_idx].right_blend_v = -1.0;
                }
            }
        }

        if (validPos(x, y - 1)) {
            const top_idx: usize = @intCast(x + (y - 1) * width);
            const top_sq = squares[top_idx];
            if (top_sq.tile_type != 0xFFFF and top_sq.tile_type != 0xFF) {
                if (game_data.ground_type_to_props.get(top_sq.tile_type)) |top_props| {
                    const top_blend_prio = top_props.blend_prio;
                    if (top_blend_prio > current_prio) {
                        square.top_blend_u = top_sq.atlas_data.tex_u;
                        square.top_blend_v = top_sq.atlas_data.tex_v;
                        squares[top_idx].bottom_blend_u = -1.0;
                        squares[top_idx].bottom_blend_v = -1.0;
                    } else if (top_blend_prio < current_prio) {
                        squares[top_idx].bottom_blend_u = square.atlas_data.tex_u;
                        squares[top_idx].bottom_blend_v = square.atlas_data.tex_v;
                        square.top_blend_u = -1.0;
                        square.top_blend_v = -1.0;
                    } else {
                        square.top_blend_u = -1.0;
                        square.top_blend_v = -1.0;
                        squares[top_idx].bottom_blend_u = -1.0;
                        squares[top_idx].bottom_blend_v = -1.0;
                    }
                } else {
                    square.top_blend_u = -1.0;
                    square.top_blend_v = -1.0;
                    squares[top_idx].bottom_blend_u = -1.0;
                    squares[top_idx].bottom_blend_v = -1.0;
                }
            }
        }

        if (validPos(x + 1, y)) {
            const right_idx: usize = @intCast(x + 1 + y * width);
            const right_sq = squares[right_idx];
            if (right_sq.tile_type != 0xFFFF and right_sq.tile_type != 0xFF) {
                if (game_data.ground_type_to_props.get(right_sq.tile_type)) |right_props| {
                    const right_blend_prio = right_props.blend_prio;
                    if (right_blend_prio > current_prio) {
                        square.right_blend_u = right_sq.atlas_data.tex_u;
                        square.right_blend_v = right_sq.atlas_data.tex_v;
                        squares[right_idx].left_blend_u = -1.0;
                        squares[right_idx].left_blend_v = -1.0;
                    } else if (right_blend_prio < current_prio) {
                        squares[right_idx].left_blend_u = square.atlas_data.tex_u;
                        squares[right_idx].left_blend_v = square.atlas_data.tex_v;
                        square.right_blend_u = -1.0;
                        square.right_blend_v = -1.0;
                    } else {
                        square.right_blend_u = -1.0;
                        square.right_blend_v = -1.0;
                        squares[right_idx].left_blend_u = -1.0;
                        squares[right_idx].left_blend_v = -1.0;
                    }
                } else {
                    square.right_blend_u = -1.0;
                    square.right_blend_v = -1.0;
                    squares[right_idx].left_blend_u = -1.0;
                    squares[right_idx].left_blend_v = -1.0;
                }
            }
        }

        if (validPos(x, y + 1)) {
            const bottom_idx: usize = @intCast(x + (y + 1) * width);
            const bottom_sq = squares[bottom_idx];
            if (bottom_sq.tile_type != 0xFFFF and bottom_sq.tile_type != 0xFF) {
                if (game_data.ground_type_to_props.get(bottom_sq.tile_type)) |bottom_props| {
                    const bottom_blend_prio = bottom_props.blend_prio;
                    if (bottom_blend_prio > current_prio) {
                        square.bottom_blend_u = bottom_sq.atlas_data.tex_u;
                        square.bottom_blend_v = bottom_sq.atlas_data.tex_v;
                        squares[bottom_idx].top_blend_u = -1.0;
                        squares[bottom_idx].top_blend_v = -1.0;
                    } else if (bottom_blend_prio < current_prio) {
                        squares[bottom_idx].top_blend_u = square.atlas_data.tex_u;
                        squares[bottom_idx].top_blend_v = square.atlas_data.tex_v;
                        square.bottom_blend_u = -1.0;
                        square.bottom_blend_v = -1.0;
                    } else {
                        square.bottom_blend_u = -1.0;
                        square.bottom_blend_v = -1.0;
                        squares[bottom_idx].top_blend_u = -1.0;
                        squares[bottom_idx].top_blend_v = -1.0;
                    }
                } else {
                    square.bottom_blend_u = -1.0;
                    square.bottom_blend_v = -1.0;
                    squares[bottom_idx].top_blend_u = -1.0;
                    squares[bottom_idx].top_blend_v = -1.0;
                }
            }
        }
    }
};

pub const GameObject = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    screen_x: f32 = 0.0,
    screen_y: f32 = 0.0,
    target_x: f32 = 0.0,
    target_y: f32 = 0.0,
    tick_x: f32 = 0.0,
    tick_y: f32 = 0.0,
    name: []u8 = &[0]u8{},
    name_override: []u8 = &[0]u8{},
    size: f32 = 0,
    max_hp: i32 = 0,
    hp: i32 = 0,
    defense: i32 = 0,
    condition: utils.Condition = .{},
    level: i32 = 0,
    tex_1: i32 = 0,
    tex_2: i32 = 0,
    alt_texture_index: i32 = 0,
    inventory: [8]i32 = [_]i32{-1} ** 8,
    owner_acc_id: i32 = -1,
    last_merch_type: u16 = 0,
    merchant_obj_type: u16 = 0,
    merchant_rem_count: i32 = 0,
    merchant_rem_minute: i32 = 0,
    merchant_discount: i32 = 0,
    sellable_price: i32 = 0,
    sellable_currency: game_data.Currency = .gold,
    sellable_rank_req: i32 = 0,
    portal_active: bool = false,
    object_connection: i32 = 0,
    owner_account_id: i32 = 0,
    rank_required: i32 = 0,
    anim_data: ?assets.AnimEnemyData = null,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),
    top_atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),
    move_angle: f32 = std.math.nan(f32),
    facing: f32 = std.math.nan(f32),
    attack_start: i64 = 0,
    attack_angle: f32 = 0.0,
    dir: u8 = assets.left_dir,
    draw_on_ground: bool = false,
    is_wall: bool = false,
    is_enemy: bool = false,
    light_color: i32 = -1,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    class: game_data.ClassType = .game_object,
    show_name: bool = false,
    hit_sound: []const u8 = &[0]u8{},
    death_sound: []const u8 = &[0]u8{},

    pub fn getSquare(self: GameObject) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn addToMap(self: *GameObject) void {
        const should_lock = entities.isFull();
        if (should_lock) {
            while (!object_lock.tryLock()) {}
        }
        defer if (should_lock) object_lock.unlock();

        texParse: {
            if (game_data.obj_type_to_tex_data.get(self.obj_type)) |tex_list| {
                if (tex_list.len == 0) {
                    std.log.err("Object with type {d} has an empty texture list, parsing failed", .{self.obj_type});
                    break :texParse;
                }

                const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];

                if (tex.animated) {
                    if (assets.anim_enemies.get(tex.sheet)) |anim_data| {
                        self.anim_data = anim_data[tex.index];
                    } else {
                        std.log.err("Could not find anim sheet {s} for object with type {d}. Using error texture", .{ tex.sheet, self.obj_type });
                        self.anim_data = assets.error_data_enemy;
                    }
                } else {
                    if (assets.atlas_data.get(tex.sheet)) |data| {
                        self.atlas_data = data[tex.index];
                    } else {
                        std.log.err("Could not find sheet {s} for object with type 0x{x}. Using error texture", .{ tex.sheet, self.obj_type });
                        self.atlas_data = assets.error_data;
                    }

                    if (game_data.obj_type_to_class.get(self.obj_type) == .wall) {
                        self.atlas_data.removePadding();
                    }
                }
            } else {
                std.log.err("Could not find texture data for obj {d}", .{self.obj_type});
            }
        }

        topTexParse: {
            if (game_data.obj_type_to_top_tex_data.get(self.obj_type)) |top_tex_list| {
                if (top_tex_list.len == 0) {
                    std.log.err("Object with type {d} has an empty top texture list, parsing failed", .{self.obj_type});
                    break :topTexParse;
                }

                const tex = top_tex_list[@as(usize, @intCast(self.obj_id)) % top_tex_list.len];
                if (assets.atlas_data.get(tex.sheet)) |data| {
                    var top_data = data[tex.index];
                    top_data.removePadding();
                    self.top_atlas_data = top_data;
                } else {
                    std.log.err("Could not find top sheet {s} for object with type {d}. Using error texture", .{ tex.sheet, self.obj_type });
                    self.top_atlas_data = assets.error_data;
                }
            }
        }

        if (game_data.obj_type_to_class.get(self.obj_type)) |class_props| {
            self.is_wall = class_props == .wall;
            const floor_y: u32 = @intFromFloat(@floor(self.y));
            const floor_x: u32 = @intFromFloat(@floor(self.x));
            if (validPos(floor_x, floor_y)) {
                squares[floor_y * @as(u32, @intCast(width)) + floor_x].has_wall = self.is_wall;
                squares[floor_y * @as(u32, @intCast(width)) + floor_x].blocking = self.is_wall;
            }
        }

        if (game_data.obj_type_to_props.get(self.obj_type)) |props| {
            self.size = props.getSize();
            self.draw_on_ground = props.draw_on_ground;
            self.light_color = props.light_color;
            self.light_intensity = props.light_intensity;
            self.light_radius = props.light_radius;
            self.is_enemy = props.is_enemy;
            self.show_name = props.show_name;
            self.name = @constCast(props.display_id);
            self.hit_sound = props.hit_sound;
            self.death_sound = props.death_sound;

            if (props.draw_on_ground)
                self.atlas_data.removePadding();

            if (props.full_occupy or props.static and props.occupy_square) {
                const floor_x: u32 = @intFromFloat(@floor(self.x));
                const floor_y: u32 = @intFromFloat(@floor(self.y));
                if (validPos(floor_x, floor_y)) {
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].occupy_square = props.occupy_square;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].full_occupy = props.full_occupy;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].blocking = true;
                }
            }
        }

        self.class = game_data.obj_type_to_class.get(self.obj_type) orelse .game_object;

        entities.add(.{ .object = self.* }) catch |e| {
            std.log.err("Could not add object to map (obj_id={d}, obj_type={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.obj_type, self.x, self.y, e });
        };
    }

    pub fn update(self: *GameObject, time: i64, dt: f32) void {
        _ = dt;

        moveBlock: {
            if (self.target_x > 0 and self.target_y > 0) {
                if (last_tick_time <= 0 or self.x <= 0 or self.y <= 0) {
                    self.x = self.target_x;
                    self.y = self.target_y;
                    self.target_x = -1;
                    self.target_y = -1;
                    break :moveBlock;
                }

                const scale_dt = @as(f32, @floatFromInt(time - last_tick_time)) / tick_ms;
                if (scale_dt >= 1.0) {
                    self.x = self.target_x;
                    self.y = self.target_y;
                    self.target_x = -1;
                    self.target_y = -1;
                    break :moveBlock;
                }
                self.x = scale_dt * self.target_x + (1.0 - scale_dt) * self.tick_x;
                self.y = scale_dt * self.target_y + (1.0 - scale_dt) * self.tick_y;
            }
        }

        merchantBlock: {
            if (self.last_merch_type == self.merchant_obj_type)
                break :merchantBlock;

            // this may not be good idea for merchants every frame lols
            // todo move it into a fn call that will only be set on merchant_obj_type set
            // this is temporary

            if (game_data.obj_type_to_tex_data.get(self.merchant_obj_type)) |tex_list| {
                if (tex_list.len == 0) {
                    std.log.err("Merchant with type {d} has an empty texture list, parsing failed", .{self.merchant_obj_type});
                    break :merchantBlock;
                }

                const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];
                if (assets.atlas_data.get(tex.sheet)) |data| {
                    self.atlas_data = data[tex.index];
                } else {
                    std.log.err("Could not find sheet {s} for merchant with type 0x{x}. Using error texture", .{ tex.sheet, self.merchant_obj_type });
                    self.atlas_data = assets.error_data;
                }
            }

            self.last_merch_type = self.merchant_obj_type;
        }
    }
};

pub const Player = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    target_x: f32 = 0.0,
    target_y: f32 = 0.0,
    tick_x: f32 = 0.0,
    tick_y: f32 = 0.0,
    screen_x: f32 = 0.0,
    screen_y: f32 = 0.0,
    name: []u8 = &[0]u8{},
    name_override: []u8 = &[0]u8{},
    name_chosen: bool = false,
    account_id: i32 = 0,
    size: f32 = 0,
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
    condition: utils.Condition = utils.Condition{},
    inventory: [20]i32 = [_]i32{-1} ** 20,
    slot_types: [20]i8 = [_]i8{0} ** 20,
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
    guild: []u8 = &[0]u8{},
    guild_rank: i32 = 0,
    oxygen_bar: i32 = 0,
    attack_start: i64 = 0,
    attack_period: i64 = 0,
    attack_angle: f32 = 0,
    attack_angle_raw: f32 = 0,
    next_bullet_id: u8 = 0,
    move_angle: f32 = std.math.nan(f32),
    move_angle_camera_included: f32 = std.math.nan(f32),
    facing: f32 = std.math.nan(f32),
    walk_speed_multiplier: f32 = 1.0,
    light_color: i32 = -1,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    last_ground_damage: i64 = -1,
    anim_data: assets.AnimPlayerData = undefined,
    move_multiplier: f32 = 1.0,
    sink_level: u16 = 0,
    hit_sound: []const u8 = &[0]u8{},
    death_sound: []const u8 = &[0]u8{},

    pub fn getSquare(self: Player) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn onMove(self: *Player) void {
        const square = self.getSquare();
        if (square.sinking) {
            self.sink_level = @as(u16, @min((self.sink_level + 1), max_sink_level));
            self.move_multiplier = (0.1 + ((1 - (@as(f32, @floatFromInt(self.sink_level)) / @as(f32, @floatFromInt(max_sink_level)))) * (square.speed - 0.1)));
        } else {
            self.sink_level = 0;
            self.move_multiplier = square.speed;
        }
    }

    pub fn moveSpeedMultiplier(self: Player) f32 {
        if (self.condition.slowed) {
            return min_move_speed * self.move_multiplier * self.walk_speed_multiplier;
        }

        var move_speed: f32 = min_move_speed + @as(f32, @floatFromInt(self.speed)) / 75.0 * (max_move_speed - min_move_speed);
        if (self.condition.speedy or self.condition.ninja_speedy) {
            move_speed *= 1.5;
        }

        return move_speed * self.move_multiplier * self.walk_speed_multiplier;
    }

    pub fn addToMap(self: *Player) void {
        const should_lock = entities.isFull();
        if (should_lock) {
            while (!object_lock.tryLock()) {}
        }
        defer if (should_lock) object_lock.unlock();

        if (game_data.obj_type_to_tex_data.get(self.obj_type)) |tex_list| {
            const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];
            if (assets.anim_players.get(tex.sheet)) |anim_data| {
                self.anim_data = anim_data[tex.index];
            } else {
                std.log.err("Could not find anim sheet {s} for player with type {d}. Using error texture", .{ tex.sheet, self.obj_type });
                self.anim_data = assets.error_data_player;
            }
        }

        const props = game_data.obj_type_to_props.get(self.obj_type);
        if (props) |obj_props| {
            self.size = obj_props.getSize();
            self.light_color = obj_props.light_color;
            self.light_intensity = obj_props.light_intensity;
            self.light_radius = obj_props.light_radius;
            self.hit_sound = obj_props.hit_sound;
            self.death_sound = obj_props.death_sound;
        }

        for (game_data.classes) |class| {
            if (class.obj_type == self.obj_type and class.slot_types.len >= 20) {
                self.slot_types = class.slot_types[0..20].*;
            }
        }

        entities.add(.{ .player = self.* }) catch |e| {
            std.log.err("Could not add player to map (obj_id={d}, obj_type={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.obj_type, self.x, self.y, e });
        };
    }

    pub fn attackFrequency(self: *const Player) f32 {
        if (self.condition.dazed)
            return min_attack_freq;

        var frequency = (min_attack_freq + ((@as(f32, @floatFromInt(self.dexterity)) / 75.0) * (max_attack_freq - min_attack_freq)));
        if (self.condition.berserk)
            frequency *= 1.5;

        return frequency;
    }

    pub fn shoot(self: *Player, angle: f32, time: i64) void {
        const weapon = self.inventory[0];
        if (weapon == -1)
            return;

        const item_props = game_data.item_type_to_props.get(@intCast(weapon));
        if (item_props == null or item_props.?.projectile == null)
            return;

        const attack_delay: i64 = @intFromFloat((1.0 / attackFrequency(self)) * (1.0 / item_props.?.rate_of_fire) * std.time.us_per_ms);
        if (time < self.attack_start + attack_delay)
            return;

        assets.playSfx(item_props.?.old_sound);

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
            var proj = Projectile{
                .x = x,
                .y = y,
                .props = proj_props,
                .angle = current_angle,
                .start_time = @divFloor(time, std.time.us_per_ms),
                .bullet_id = bullet_id,
                .owner_id = self.obj_id,
            };
            proj.addToMap(false);

            network.sendPlayerShoot(
                time,
                bullet_id,
                @intCast(weapon),
                network.Position{ .x = x, .y = y },
                current_angle,
            );

            current_angle += arc_gap;
        }

        self.attack_period = attack_delay;
        self.attack_angle = angle - camera.angle;
        self.attack_angle_raw = angle;
        self.attack_start = time;
    }

    pub inline fn update(self: *Player, time: i64, dt: f32) void {
        const is_self = self.obj_id == local_player_id;
        if (is_self) {
            if (!std.math.isNan(self.move_angle)) {
                const move_speed = self.moveSpeedMultiplier();
                const total_angle = camera.angle_unbound + self.move_angle;
                const next_x = self.x + move_speed * dt * @cos(total_angle);
                const next_y = self.y + move_speed * dt * @sin(total_angle);
                self.move_angle_camera_included = total_angle;
                modifyMove(self, next_x, next_y, &self.x, &self.y);
            }

            if (time - self.last_ground_damage >= 550) {
                const floor_x: u32 = @intFromFloat(@floor(self.x));
                const floor_y: u32 = @intFromFloat(@floor(self.y));
                if (validPos(floor_x, floor_y)) {
                    const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
                    if (square.tile_type != 0xFFFF and square.tile_type != 0xFF and square.damage > 0) {
                        network.sendGroundDamage(time, .{ .x = self.x, .y = self.y });
                        self.last_ground_damage = time;
                    }
                }
            }
        } else {
            moveBlock: {
                if (self.target_x > 0 and self.target_y > 0) {
                    if (last_tick_time <= 0 or self.x <= 0 or self.y <= 0) {
                        self.x = self.target_x;
                        self.y = self.target_y;
                        self.target_x = -1;
                        self.target_y = -1;
                        self.move_angle = std.math.nan(f32);
                        break :moveBlock;
                    }

                    const scale_dt = @as(f32, @floatFromInt(time - last_tick_time)) / tick_ms;
                    if (scale_dt >= 1.0) {
                        self.x = self.target_x;
                        self.y = self.target_y;
                        self.target_x = -1;
                        self.target_y = -1;
                        self.move_angle = std.math.nan(f32);
                        break :moveBlock;
                    }
                    self.x = scale_dt * self.target_x + (1.0 - scale_dt) * self.tick_x;
                    self.y = scale_dt * self.target_y + (1.0 - scale_dt) * self.tick_y;
                }
            }
        }
    }

    fn modifyMove(self: *Player, x: f32, y: f32, target_x: *f32, target_y: *f32) void {
        if (self.condition.paralyzed) {
            target_x.* = self.x;
            target_y.* = self.y;
            return;
        }

        const dx = x - self.x;
        const dy = y - self.y;

        if (dx < move_threshold and dx > -move_threshold and dy < move_threshold and dy > -move_threshold) {
            modifyStep(self, x, y, target_x, target_y);
            return;
        }

        var step_size = move_threshold / @max(@fabs(dx), @fabs(dy));

        target_x.* = self.x;
        target_y.* = self.y;

        var d: f32 = 0.0;
        var done: bool = false;
        while (!done) {
            if (d + step_size >= 1.0) {
                step_size = 1.0 - d;
                done = true;
            }
            modifyStep(self, target_x.* + dx * step_size, target_y.* + dy * step_size, target_x, target_y);
            d += step_size;
        }
    }

    fn isValidPosition(x: f32, y: f32) bool {
        if (isWalkable(x, y))
            return false;

        const x_frac = x - @floor(x);
        const y_frac = y - @floor(y);

        if (x_frac < 0.5) {
            if (isFullOccupy(x - 1, y)) {
                return false;
            }

            if (y_frac < 0.5) {
                if (isFullOccupy(x, y - 1) or isFullOccupy(x - 1, y - 1)) {
                    return false;
                }
            }

            if (y_frac > 0.5) {
                if (isFullOccupy(x, y + 1) or isFullOccupy(x - 1, y + 1)) {
                    return false;
                }
            }
        } else if (x_frac > 0.5) {
            if (isFullOccupy(x + 1, y)) {
                return false;
            }
            if (y_frac < 0.5) {
                if (isFullOccupy(x, y - 1) or isFullOccupy(x + 1, y - 1)) {
                    return false;
                }
            }
            if (y_frac > 0.5) {
                if (isFullOccupy(x, y + 1) or isFullOccupy(x + 1, y + 1)) {
                    return false;
                }
            }
        } else {
            if (y_frac < 0.5) {
                if (isFullOccupy(x, y - 1)) {
                    return false;
                }
            }
            if (y_frac > 0.5) {
                if (isFullOccupy(x, y + 1)) {
                    return false;
                }
            }
        }
        return true;
    }

    fn isWalkable(x: f32, y: f32) bool {
        if (x < 0 or y < 0)
            return true;

        const floor_x: u32 = @intFromFloat(@floor(x));
        const floor_y: u32 = @intFromFloat(@floor(y));
        const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
        return square.occupy_square or square.blocking;
    }

    fn isFullOccupy(x: f32, y: f32) bool {
        if (x < 0 or y < 0)
            return true;

        const floor_x: u32 = @intFromFloat(@floor(x));
        const floor_y: u32 = @intFromFloat(@floor(y));
        const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
        return square.tile_type == 0xFF or square.tile_type == 0xFFFF or square.full_occupy;
    }

    fn modifyStep(self: *Player, x: f32, y: f32, target_x: *f32, target_y: *f32) void {
        const x_cross = (@mod(self.x, 0.5) == 0 and x != self.x) or (@floor(self.x / 0.5) != @floor(x / 0.5));
        const y_cross = (@mod(self.y, 0.5) == 0 and y != self.y) or (@floor(self.y / 0.5) != @floor(y / 0.5));

        if ((!x_cross and !y_cross) or isValidPosition(x, y)) {
            target_x.* = x;
            target_y.* = y;
            return;
        }

        var next_x_border: f32 = 0.0;
        var next_y_border: f32 = 0.0;
        if (x_cross) {
            next_x_border = if (x > self.x) @floor(x * 2) / 2.0 else @floor(self.x * 2) / 2.0;
            if (@floor(next_x_border) > @floor(self.x)) {
                next_x_border -= 0.01;
            }
        }

        if (y_cross) {
            next_y_border = if (y > self.y) @floor(y * 2) / 2.0 else @floor(self.y * 2) / 2.0;
            if (@floor(next_y_border) > @floor(self.y)) {
                next_y_border -= 0.01;
            }
        }

        // when we add in sliding i will do this

        // if (!xCross) {
        //     newP.x = x;
        //     newP.y = nextYBorder;
        //     if (square_ != null and square_.props_.slideAmount_ != 0) {
        //         resetMoveVector(false);
        //     }
        //     return;
        // }
        // else if (!yCross) {
        //     newP.x = nextXBorder;
        //     newP.y = y;
        //     if (square_ != null and square_.props_.slideAmount_ != 0) {
        //         resetMoveVector(true);
        //     }
        //     return;
        // }

        const x_border_dist = if (x > self.x) x - next_x_border else next_x_border - x;
        const y_border_dist = if (y > self.y) y - next_y_border else next_y_border - y;

        if (x_border_dist > y_border_dist) {
            if (isValidPosition(x, next_y_border)) {
                target_x.* = x;
                target_y.* = next_y_border;
                return;
            }

            if (isValidPosition(next_x_border, y)) {
                target_x.* = next_x_border;
                target_y.* = y;
                return;
            }
        } else {
            if (isValidPosition(next_x_border, y)) {
                target_x.* = next_x_border;
                target_y.* = y;
                return;
            }

            if (isValidPosition(x, next_y_border)) {
                target_x.* = x;
                target_y.* = next_y_border;
                return;
            }
        }

        target_x.* = next_x_border;
        target_y.* = next_y_border;
    }
};

pub const Projectile = struct {
    var next_obj_id: i32 = 0x7F000000;

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    screen_x: f32 = 0.0,
    screen_y: f32 = 0.0,
    size: f32 = 1.0,
    obj_id: i32 = 0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),
    start_time: i64 = 0,
    angle: f32 = 0.0,
    visual_angle: f32 = 0.0,
    heat_seek_fired: bool = false,
    total_angle_change: f32 = 0.0,
    zero_vel_dist: f32 = -1.0,
    start_x: f32 = 0.0,
    start_y: f32 = 0.0,
    last_deflect: f32 = 0.0,
    bullet_id: u8 = 0,
    owner_id: i32 = 0,
    damage_players: bool = false,
    damage: i16 = 0,
    props: game_data.ProjProps,

    pub fn getSquare(self: Projectile) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn addToMap(self: *Projectile, needs_lock: bool) void {
        const should_lock = needs_lock and entities.isFull();
        if (should_lock) {
            while (!object_lock.tryLock()) {}
        }
        defer if (should_lock) object_lock.unlock();

        const tex_list = self.props.texture_data;
        const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];
        if (assets.atlas_data.get(tex.sheet)) |data| {
            self.atlas_data = data[tex.index];
        } else {
            std.log.err("Could not find sheet {s} for proj with id {d}. Using error texture", .{ tex.sheet, self.obj_id });
            self.atlas_data = assets.error_data;
        }

        self.obj_id = Projectile.next_obj_id + 1;
        Projectile.next_obj_id += 1;

        entities.add(.{ .projectile = self.* }) catch |e| {
            std.log.err("Could not add projectile to map (obj_id={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.x, self.y, e });
        };
    }

    inline fn findTargetObject(x: f32, y: f32, radius_sqr: f32) ?*GameObject {
        var min_dist = std.math.floatMax(f32);
        var target: ?*GameObject = null;
        for (entities.items()) |*en| {
            switch (en.*) {
                .object => |*obj| {
                    if (obj.is_enemy) {
                        const dist_sqr = utils.distSqr(obj.x, obj.y, x, y);
                        if (dist_sqr < radius_sqr and dist_sqr < min_dist) {
                            min_dist = dist_sqr;
                            target = obj;
                        }
                    }
                },
                else => {},
            }
        }

        return target;
    }

    inline fn findTargetPlayer(x: f32, y: f32, radius_sqr: f32) ?*Player {
        var min_dist = std.math.floatMax(f32);
        var target: ?*Player = null;
        for (entities.items()) |*en| {
            switch (en.*) {
                .player => |*player| {
                    const dist_sqr = utils.distSqr(player.x, player.y, x, y);
                    if (dist_sqr < radius_sqr and dist_sqr < min_dist) {
                        min_dist = dist_sqr;
                        target = player;
                    }
                },
                else => {},
            }
        }

        return target;
    }

    inline fn updatePosition(self: *Projectile, elapsed: i64, dt: f32) void {
        if (self.props.heat_seek_radius > 0 and elapsed >= self.props.heat_seek_delay and !self.heat_seek_fired) {
            var target_x: f32 = -1.0;
            var target_y: f32 = -1.0;

            if (self.damage_players) {
                if (findTargetPlayer(
                    self.x,
                    self.y,
                    self.props.heat_seek_radius * self.props.heat_seek_radius,
                )) |player| {
                    target_x = player.x;
                    target_y = player.y;
                }
            } else {
                if (findTargetObject(
                    self.x,
                    self.y,
                    self.props.heat_seek_radius * self.props.heat_seek_radius,
                )) |object| {
                    target_x = object.x;
                    target_y = object.y;
                }
            }

            if (target_x > 0 and target_y > 0) {
                self.angle = @mod(std.math.atan2(f32, target_y - self.y, target_x - self.x), std.math.tau);
                self.heat_seek_fired = true;
            }
        }

        var angle_change: f32 = 0.0;
        if (self.props.angle_change != 0 and elapsed < self.props.angle_change_end and elapsed >= self.props.angle_change_delay) {
            angle_change += dt / 1000.0 * self.props.angle_change;
        }

        if (self.props.angle_change_accel != 0 and elapsed >= self.props.angle_change_accel_delay) {
            const time_in_accel: f32 = @floatFromInt(elapsed - self.props.angle_change_accel_delay);
            angle_change += dt / 1000.0 * self.props.angle_change_accel * time_in_accel / 1000.0;
        }

        if (angle_change != 0.0) {
            if (self.props.angle_change_clamp != 0) {
                const clamp_dt = self.props.angle_change_clamp - self.total_angle_change;
                const clamped_change = @min(angle_change, clamp_dt);
                self.total_angle_change += clamped_change;
                self.angle += clamped_change;
            } else {
                self.angle += angle_change;
            }
        }

        var dist: f32 = 0.0;
        const uses_zero_vel = self.props.zero_velocity_delay != -1;
        if (!uses_zero_vel or self.props.zero_velocity_delay > elapsed) {
            const base_speed = if (self.heat_seek_fired) self.props.heat_seek_speed else self.props.speed;
            if (self.props.accel == 0.0 or elapsed < self.props.accel_delay) {
                dist = dt * base_speed;
            } else {
                const time_in_accel: f32 = @floatFromInt(elapsed - self.props.accel_delay);
                const accel_dist = dt * ((self.props.speed * 10000.0 + self.props.accel * time_in_accel / 1000.0) / 10000.0);
                if (self.props.speed_clamp != -1) {
                    dist = accel_dist;
                } else {
                    const clamp_dist = dt * self.props.speed_clamp / 10000.0;
                    dist = if (self.props.accel > 0) @min(accel_dist, clamp_dist) else @max(accel_dist, clamp_dist);
                }
            }
        } else {
            if (self.zero_vel_dist == -1.0) {
                self.zero_vel_dist = utils.dist(self.start_x, self.start_y, self.x, self.y);
            }

            self.x = self.start_x + self.zero_vel_dist * @cos(self.angle);
            self.y = self.start_y + self.zero_vel_dist * @sin(self.angle);
            return;
        }

        if (self.heat_seek_fired) {
            self.x += dist * @cos(self.angle);
            self.y += dist * @sin(self.angle);
        } else {
            if (self.props.parametric) {
                const t = @as(f32, @floatFromInt(@divTrunc(elapsed, self.props.lifetime_ms))) * 2.0 * std.math.pi;
                const x = @sin(t) * if (self.bullet_id % 2 == 0) @as(f32, 1.0) else @as(f32, -1.0);
                const y = @sin(2 * t) * if (self.bullet_id % 4 < 2) @as(f32, 1.0) else @as(f32, -1.0);
                self.x += (x * @cos(self.angle) - y * @sin(self.angle)) * self.props.magnitude;
                self.y += (x * @sin(self.angle) + y * @cos(self.angle)) * self.props.magnitude;
            } else {
                if (self.props.boomerang and elapsed > self.props.lifetime_ms / 2)
                    dist = -dist;

                self.x += dist * @cos(self.angle);
                self.y += dist * @sin(self.angle);
                if (self.props.amplitude != 0) {
                    const phase: f32 = if (self.bullet_id % 2 == 0) 0.0 else std.math.pi;
                    const time_ratio: f32 = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(self.props.lifetime_ms));
                    const deflection_target = self.props.amplitude * @sin(phase + time_ratio * self.props.frequency * 2.0 * std.math.pi);
                    self.x += (deflection_target - self.last_deflect) * @cos(self.angle + std.math.pi / 2.0);
                    self.y += (deflection_target - self.last_deflect) * @sin(self.angle + std.math.pi / 2.0);
                    self.last_deflect = deflection_target;
                }
            }
        }
    }

    pub fn update(self: *Projectile, time: i64, dt: f32, allocator: std.mem.Allocator) bool {
        const elapsed = time - self.start_time;
        if (elapsed >= self.props.lifetime_ms)
            return false;

        const last_x = self.x;
        const last_y = self.y;

        self.updatePosition(elapsed, dt);
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        if (validPos(floor_x, floor_y)) {
            const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
            if (square.tile_type == 0xFF or square.tile_type == 0xFFFF or square.blocking) {
                // network.otherHit(time, self.bullet_id, self.owner_id) catch |e| {
                //     std.log.err("Could not send other hit: {any}", .{e});
                // };
                return false;
            }
        }

        if (last_x == 0 and last_y == 0) {
            self.visual_angle = self.angle;
        } else {
            const y_dt: f32 = self.y - last_y;
            const x_dt: f32 = self.x - last_x;
            if (y_dt > 0.0 or x_dt != 0) {
                self.visual_angle = std.math.atan2(f32, y_dt, x_dt);
            }
        }

        if (self.damage_players) {
            if (findTargetPlayer(self.x, self.y, 0.33)) |player| {
                network.sendPlayerHit(self.bullet_id, self.owner_id);
                assets.playSfx(player.hit_sound);
                if (self.props.damage > 0 or self.props.min_damage > 0) {
                    const piercing: bool = self.props.piercing;
                    var damage_color: i32 = 0xB02020;
                    if (piercing)
                        damage_color = 0x890AFF;

                    const damage_value = if (self.props.damage > 0) self.props.damage else self.props.min_damage;
                    if (damage_value > player.hp)
                        assets.playSfx(player.death_sound);

                    const text_data = ui.TextData{
                        .text = std.fmt.allocPrint(allocator, "-{d}", .{damage_value}) catch unreachable,
                        .text_type = .bold,
                        .size = 22,
                        .color = damage_color,
                    };

                    ui.status_texts.add(ui.StatusText{
                        .obj_id = player.obj_id,
                        .start_time = time,
                        .text_data = text_data,
                        .initial_size = 22,
                    }) catch |e| {
                        std.log.err("Allocation for damage text \"-{d}\" failed: {any}", .{ damage_value, e });
                    };
                }

                return false;
            }
        } else {
            if (findTargetObject(self.x, self.y, 0.33)) |object| {
                const dead = object.hp <= self.props.min_damage;

                network.sendEnemyHit(time, self.bullet_id, object.obj_id, dead);

                assets.playSfx(object.hit_sound);
                if (self.props.min_damage > 0) {
                    const piercing: bool = self.props.piercing;
                    var damage_color: i32 = 0xB02020;
                    if (piercing)
                        damage_color = 0x890AFF;

                    const damage = @as(i32, calculateDamage(
                        self,
                        object.obj_id,
                        self.owner_id,
                        piercing,
                    ));

                    if (damage > object.hp)
                        assets.playSfx(object.death_sound);

                    const text_data = ui.TextData{
                        .text = std.fmt.allocPrint(allocator, "-{d}", .{damage}) catch unreachable,
                        .text_type = .bold,
                        .size = 22,
                        .color = damage_color,
                    };

                    ui.status_texts.add(ui.StatusText{
                        .obj_id = object.obj_id,
                        .start_time = time,
                        .text_data = text_data,
                        .initial_size = 22,
                    }) catch |e| {
                        std.log.err("Allocation for damage text \"-{d}\" failed: {any}", .{ damage, e });
                    };
                }

                return false;
            }
        }

        return true;
    }
};

fn lessThan(_: void, lhs: Entity, rhs: Entity) bool {
    var lhs_sort_val: f32 = 0;
    var rhs_sort_val: f32 = 0;

    switch (lhs) {
        .object => |object| {
            if (object.draw_on_ground) {
                lhs_sort_val = -1;
            } else {
                lhs_sort_val = camera.rotateAroundCamera(object.x, object.y).y + object.z * -camera.px_per_tile;
            }
        },
        inline else => |en| {
            lhs_sort_val = camera.rotateAroundCamera(en.x, en.y).y + en.z * -camera.px_per_tile;
        },
    }

    switch (rhs) {
        .object => |object| {
            if (object.draw_on_ground) {
                rhs_sort_val = -1;
            } else {
                rhs_sort_val = camera.rotateAroundCamera(object.x, object.y).y + object.z * -camera.px_per_tile;
            }
        },
        inline else => |en| {
            rhs_sort_val = camera.rotateAroundCamera(en.x, en.y).y + en.z * -camera.px_per_tile;
        },
    }

    return lhs_sort_val < rhs_sort_val;
}

pub const Entity = union(enum) {
    player: Player,
    object: GameObject,
    projectile: Projectile,
};

const day_cycle_ms: i32 = 10 * 60 * 1000; // 10 minutes
const day_cycle_ms_half: f32 = @floatFromInt(day_cycle_ms / 2);

pub var object_lock: std.Thread.RwLock = .{};
pub var entities: utils.DynSlice(Entity) = undefined;
pub var entity_indices_to_remove: utils.DynSlice(usize) = undefined;
pub var last_tick_time: i64 = 0;
pub var local_player_id: i32 = -1;
pub var interactive_id = std.atomic.Atomic(i32).init(-1);
pub var interactive_type = std.atomic.Atomic(game_data.ClassType).init(.game_object);
pub var name: []const u8 = "";
pub var seed: u32 = 0;
pub var width: isize = 0;
pub var height: isize = 0;
pub var squares: []Square = &[0]Square{};
pub var bg_light_color: i32 = -1;
pub var bg_light_intensity: f32 = 0.0;
pub var day_light_intensity: f32 = 0.0;
pub var night_light_intensity: f32 = 0.0;
pub var server_time_offset: i64 = 0;
pub var move_records: utils.DynSlice(network.TimedPosition) = undefined;
pub var last_records_clear_time: i64 = 0;
pub var random: utils.Random = utils.Random{};
var last_sort: i64 = -1;

pub fn init(allocator: std.mem.Allocator) !void {
    entities = try utils.DynSlice(Entity).init(5000, allocator);
    entity_indices_to_remove = try utils.DynSlice(usize).init(100, allocator);
    move_records = try utils.DynSlice(network.TimedPosition).init(10, allocator);
}

pub fn dispose(allocator: std.mem.Allocator) void {
    for (entities.items()) |en| {
        switch (en) {
            .object => |obj| {
                allocator.free(obj.name_override);
            },
            .player => |player| {
                allocator.free(player.name_override);
                allocator.free(player.guild);
            },
            else => {},
        }
    }
}

pub fn deinit(allocator: std.mem.Allocator) void {
    if (squares.len > 0) {
        allocator.free(squares);
    }

    dispose(allocator);

    entities.deinit();
    entity_indices_to_remove.deinit();
    move_records.deinit();
}

pub fn getLightIntensity(time: i64) f32 {
    if (server_time_offset == 0)
        return bg_light_intensity;

    const server_time_clamped: f32 = @floatFromInt(@mod(time + server_time_offset, day_cycle_ms));
    const intensity_delta = day_light_intensity - night_light_intensity;
    if (server_time_clamped <= day_cycle_ms_half) {
        const scale: f32 = server_time_clamped / day_cycle_ms_half;
        return night_light_intensity + intensity_delta * scale;
    } else {
        const scale: f32 = (server_time_clamped - day_cycle_ms_half) / day_cycle_ms_half;
        return day_light_intensity - intensity_delta * scale;
    }
}

pub fn setWH(w: isize, h: isize, allocator: std.mem.Allocator) void {
    width = w;
    height = h;
    if (squares.len == 0) {
        squares = allocator.alloc(Square, @intCast(w * h)) catch return;
    } else {
        squares = allocator.realloc(squares, @intCast(w * h)) catch return;
    }

    for (0..squares.len) |i|
        squares[i] = Square{};
}

pub fn findEntity(obj_id: i32) ?*Entity {
    for (entities.items()) |*en| {
        switch (en.*) {
            inline else => |*obj| {
                if (obj.obj_id == obj_id)
                    return en;
            },
        }
    }

    return null;
}

pub fn removeEntity(obj_id: i32) ?Entity {
    for (entities.items(), 0..) |*en, i| {
        switch (en.*) {
            inline else => |*obj| {
                if (obj.obj_id == obj_id)
                    return entities.remove(i);
            },
        }
    }

    return null;
}

pub fn calculateDamage(proj: *Projectile, object_id: i32, player_id: i32, piercing: bool) i32 {
    if (findEntity(object_id)) |en| {
        switch (en.*) {
            .object => |object| {
                var damage = random.nextIntRange(@intCast(proj.props.min_damage), @intCast(proj.props.max_damage));

                if (!piercing)
                    damage -= @intCast(object.defense);

                // todo player buffs and mult
                // if (findPlayer(player_id)) |player| {
                // }
                return @intCast(damage);
            },
            else => {},
        }
        _ = player_id;
    }
    return -1;
}

pub fn update(time: i64, dt: i64, allocator: std.mem.Allocator) void {
    while (!object_lock.tryLock()) {}
    defer object_lock.unlock();

    interactive_id.store(-1, .Release);
    interactive_type.store(.game_object, .Release);

    const ms_time = @divFloor(time, std.time.us_per_ms);
    const ms_dt: f32 = @as(f32, @floatFromInt(dt)) / std.time.us_per_ms;

    var interactive_set = false;
    for (entities.items(), 0..) |*en, i| {
        switch (en.*) {
            .object => |*obj| {
                const is_container = obj.class == .container;
                if (!interactive_set and (obj.class == .portal or is_container)) {
                    const dt_x = camera.x - obj.x;
                    const dt_y = camera.y - obj.y;
                    if (dt_x * dt_x + dt_y * dt_y < 1) {
                        interactive_id.store(obj.obj_id, .Release);
                        interactive_type.store(obj.class, .Release);

                        if (is_container) {
                            if (ui.container_id != obj.obj_id) {
                                inline for (0..8) |idx| {
                                    ui.setContainerItem(obj.inventory[idx], idx);
                                }
                            }

                            ui.container_id = obj.obj_id;
                            ui.setContainerVisible(true);
                        }

                        interactive_set = true;
                    }
                }

                obj.update(ms_time, ms_dt);
            },
            .player => |*player| {
                if (player.obj_id == local_player_id) {
                    camera.update(player.x, player.y, ms_dt, input.rotate);
                    if (input.attacking) {
                        const y: f32 = @floatCast(input.mouse_y);
                        const x: f32 = @floatCast(input.mouse_x);
                        const shoot_angle = std.math.atan2(f32, y - camera.screen_height / 2.0, x - camera.screen_width / 2.0) + camera.angle;
                        player.shoot(shoot_angle, time);
                    }
                }

                player.update(ms_time, ms_dt);
            },
            .projectile => |*proj| {
                if (!proj.update(ms_time, ms_dt, allocator))
                    entity_indices_to_remove.add(i) catch |e| {
                        std.log.err("Out of memory: {any}", .{e});
                    };
            },
        }
    }

    if (!interactive_set) {
        if (ui.container_id != -1) {
            inline for (0..8) |idx| {
                ui.setContainerItem(-1, idx);
            }
        }

        ui.container_id = -1;
        ui.setContainerVisible(false);
    }

    std.mem.reverse(usize, entity_indices_to_remove.items());

    for (entity_indices_to_remove.items()) |idx| {
        _ = entities.remove(idx);
    }

    entity_indices_to_remove.clear();

    // hack
    if (time - last_sort > 7) {
        std.sort.pdq(Entity, entities.items(), {}, lessThan);
        last_sort = time;
    }
}

pub inline fn validPos(x: isize, y: isize) bool {
    return !(x < 0 or x >= width or y < 0 or y >= height);
}

pub inline fn getSquareUnsafe(x: f32, y: f32) Square {
    const floor_x: u32 = @intFromFloat(@floor(x));
    const floor_y: u32 = @intFromFloat(@floor(y));
    return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
}

pub fn setSquare(x: isize, y: isize, tile_type: u16) void {
    const idx: usize = @intCast(x + y * width);

    var square = Square{
        .tile_type = tile_type,
        .x = @as(f32, @floatFromInt(x)) + 0.5,
        .y = @as(f32, @floatFromInt(y)) + 0.5,
    };

    texParse: {
        if (game_data.ground_type_to_tex_data.get(tile_type)) |tex_list| {
            if (tex_list.len == 0) {
                std.log.err("Square with type {d} has an empty texture list, parsing failed", .{tile_type});
                break :texParse;
            }

            const tex = if (tex_list.len == 1) tex_list[0] else tex_list[utils.rng.next() % tex_list.len];
            if (assets.atlas_data.get(tex.sheet)) |data| {
                var ground_data = data[tex.index];
                ground_data.removePadding();
                square.atlas_data = ground_data;
            } else {
                std.log.err("Could not find sheet {s} for square with type 0x{x}. Using error texture", .{ tex.sheet, tile_type });
                square.atlas_data = assets.error_data;
            }

            square.updateBlends();
        }
    }

    if (game_data.ground_type_to_props.get(tile_type)) |props| {
        square.sink = if (props.sink) 0.75 else 0.0;
        square.sinking = props.sinking;
        square.speed = props.speed;
        square.light_color = props.light_color;
        square.light_intensity = props.light_intensity;
        square.light_radius = props.light_radius;
        square.damage = props.min_damage;
        square.blocking = props.no_walk;
        square.anim_type = props.anim_type;
        square.anim_dx = props.anim_dx;
        square.anim_dy = props.anim_dy;
        if (props.random_offset) {
            const u_offset: f32 = @floatFromInt(utils.rng.next() % 8);
            const v_offset: f32 = @floatFromInt(utils.rng.next() % 8);
            square.u_offset = u_offset * assets.base_texel_w;
            square.v_offset = v_offset * assets.base_texel_h;
        }
    }

    squares[idx] = square;
}

pub fn addMoveRecord(time: i64, position: network.Position) void {
    if (last_records_clear_time < 0) {
        return;
    }

    const id = getId(time);
    if (id < 1 or id > 10) {
        return;
    }

    if (move_records.capacity == 0) {
        move_records.add(network.TimedPosition{ .time = time, .position = position });
        return;
    }

    const curr_record = move_records.items()[move_records.capacity - 1];
    const curr_id = getId(curr_record.time);
    if (id != curr_id) {
        move_records.add(network.TimedPosition{ .time = time, .position = position });
        return;
    }

    const score = getScore(id, time);
    const curr_score = getScore(id, curr_record.time);
    if (score < curr_score) {
        curr_record.time = time;
        curr_record.position = position;
    }
}

pub fn clearMoveRecords(time: i64) void {
    move_records.clear();
    last_records_clear_time = time;
}

inline fn getId(time: i64) i32 {
    return (time - last_records_clear_time + 50) / 100;
}

inline fn getScore(id: i32, time: i64) i64 {
    return std.math.absInt(time - last_records_clear_time - id * 100);
}
