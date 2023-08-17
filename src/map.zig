const std = @import("std");
const zstbrp = @import("zstbrp");
const network = @import("network.zig");
const game_data = @import("game_data.zig");
const camera = @import("camera.zig");
const input = @import("input.zig");
const main = @import("main.zig");
const utils = @import("utils.zig");
const assets = @import("assets.zig");
const ui = @import("ui.zig");

pub const Square = struct {
    tile_type: u16 = 0xFFFF,
    x: f32 = 0.0,
    y: f32 = 0.0,
    tex_u: f32 = -1.0,
    tex_v: f32 = -1.0,
    tex_w: f32 = 0.0,
    tex_h: f32 = 0.0,
    left_blend_u: f32 = -1.0,
    left_blend_v: f32 = -1.0,
    top_blend_u: f32 = -1.0,
    top_blend_v: f32 = -1.0,
    right_blend_u: f32 = -1.0,
    right_blend_v: f32 = -1.0,
    bottom_blend_u: f32 = -1.0,
    bottom_blend_v: f32 = -1.0,
    sink: f32 = 0.0,
    has_wall: bool = false,
    light_color: i32 = -1,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    damage: u16 = 0,
    blocking: bool = false,

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
                        square.left_blend_u = left_sq.tex_u;
                        square.left_blend_v = left_sq.tex_v;
                        squares[left_idx].right_blend_u = -1.0;
                        squares[left_idx].right_blend_v = -1.0;
                    } else if (left_blend_prio < current_prio) {
                        squares[left_idx].right_blend_u = square.tex_u;
                        squares[left_idx].right_blend_v = square.tex_v;
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
                        square.top_blend_u = top_sq.tex_u;
                        square.top_blend_v = top_sq.tex_v;
                        squares[top_idx].bottom_blend_u = -1.0;
                        squares[top_idx].bottom_blend_v = -1.0;
                    } else if (top_blend_prio < current_prio) {
                        squares[top_idx].bottom_blend_u = square.tex_u;
                        squares[top_idx].bottom_blend_v = square.tex_v;
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
                        square.right_blend_u = right_sq.tex_u;
                        square.right_blend_v = right_sq.tex_v;
                        squares[right_idx].left_blend_u = -1.0;
                        squares[right_idx].left_blend_v = -1.0;
                    } else if (right_blend_prio < current_prio) {
                        squares[right_idx].left_blend_u = square.tex_u;
                        squares[right_idx].left_blend_v = square.tex_v;
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
                        square.bottom_blend_u = bottom_sq.tex_u;
                        square.bottom_blend_v = bottom_sq.tex_v;
                        squares[bottom_idx].top_blend_u = -1.0;
                        squares[bottom_idx].top_blend_v = -1.0;
                    } else if (bottom_blend_prio < current_prio) {
                        squares[bottom_idx].top_blend_u = square.tex_u;
                        squares[bottom_idx].top_blend_v = square.tex_v;
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
    h: f32 = 0.0,
    target_x: f32 = 0.0,
    target_y: f32 = 0.0,
    tick_x: f32 = 0.0,
    tick_y: f32 = 0.0,
    name: []u8 = &[0]u8{},
    size: f32 = 0,
    max_hp: i32 = 0,
    hp: i32 = 0,
    defense: i32 = 0,
    condition: u64 = 0,
    level: i32 = 0,
    tex_1: i32 = 0,
    tex_2: i32 = 0,
    alt_texture_index: i32 = 0,
    inventory: [8]i32 = [_]i32{-1} ** 8,
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
    anim_data: ?assets.AnimEnemyData = null,
    tex_u: f32 = 0.0,
    tex_v: f32 = 0.0,
    tex_w: f32 = 0.0,
    tex_h: f32 = 0.0,
    top_tex_u: f32 = 0.0,
    top_tex_v: f32 = 0.0,
    visual_move_angle: f32 = std.math.nan_f32,
    attack_start: i32 = 0,
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

    pub fn getSquare(self: GameObject) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn addToMap(self: *GameObject) void {
        while (!object_lock.tryLock()) {}
        defer object_lock.unlock();

        const tex_list = game_data.obj_type_to_tex_data.get(self.obj_type);
        if (tex_list != null and tex_list.?.len > 0) {
            const tex = tex_list.?[@as(usize, @intCast(self.obj_id)) % tex_list.?.len];

            if (tex.animated) {
                const tex_sheet = assets.anim_enemies.get(tex.sheet);
                if (tex_sheet != null) {
                    self.anim_data = tex_sheet.?[tex.index];
                } else {
                    self.anim_data = assets.error_anim;
                }
            } else {
                const rect_sheet = assets.rects.get(tex.sheet);

                var rect: zstbrp.PackRect = undefined;
                if (rect_sheet != null) {
                    rect = rect_sheet.?[tex.index];
                } else {
                    rect = assets.error_rect;
                }
                // hack
                if (game_data.obj_type_to_class.get(self.obj_type) == .wall) {
                    self.tex_u = @as(f32, @floatFromInt(rect.x + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_width));
                    self.tex_v = @as(f32, @floatFromInt(rect.y + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_height));
                } else {
                    self.tex_u = @floatFromInt(rect.x);
                    self.tex_v = @floatFromInt(rect.y);
                    self.tex_w = @floatFromInt(rect.w);
                    self.tex_h = @floatFromInt(rect.h);
                }
            }
        }

        const top_tex_list = game_data.obj_type_to_top_tex_data.get(self.obj_type);
        if (top_tex_list != null and top_tex_list.?.len > 0) {
            const tex = top_tex_list.?[@as(usize, @intCast(self.obj_id)) % top_tex_list.?.len];
            const rect = assets.rects.get(tex.sheet).?[tex.index];
            self.top_tex_u = @as(f32, @floatFromInt(rect.x + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_width));
            self.top_tex_v = @as(f32, @floatFromInt(rect.y + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_height));
        }

        const class_props = game_data.obj_type_to_class.get(self.obj_type);
        if (class_props != null) {
            self.is_wall = class_props.? == .wall;
            const floor_y: u32 = @intFromFloat(@floor(self.y));
            const floor_x: u32 = @intFromFloat(@floor(self.x));
            if (validPos(floor_x, floor_y)) {
                squares[floor_y * @as(u32, @intCast(width)) + floor_x].has_wall = self.is_wall;
                squares[floor_y * @as(u32, @intCast(width)) + floor_x].blocking = self.is_wall;
            }
        }

        const props = game_data.obj_type_to_props.get(self.obj_type);
        if (props != null) {
            self.size = props.?.getSize();
            self.draw_on_ground = props.?.draw_on_ground;
            self.light_color = props.?.light_color;
            self.light_intensity = props.?.light_intensity;
            self.light_radius = props.?.light_radius;
            self.is_enemy = props.?.is_enemy;
            self.show_name = props.?.show_name;
            self.name = @constCast(props.?.display_id);
            if (props.?.full_occupy or props.?.static and props.?.occupy_square) {
                const floor_x: u32 = @intFromFloat(@floor(self.x));
                const floor_y: u32 = @intFromFloat(@floor(self.y));
                if (validPos(floor_x, floor_y)) {
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].blocking = true;
                }
            }
        }

        self.class = game_data.obj_type_to_class.get(self.obj_type) orelse .game_object;

        objects.append(self.*) catch |e| {
            std.log.err("Could not add object to map (obj_id={d}, obj_type={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.obj_type, self.x, self.y, e });
        };
    }

    pub fn update(self: *GameObject, time: i32, dt: i32) void {
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

                const last_tick_var = last_tick_time;
                const scale_dt = @as(f32, @floatFromInt(time - last_tick_var)) / 100.0;
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
    h: f32 = 0.0,
    name: []u8 = &[0]u8{},
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
    condition: u64 = 0,
    inventory: [20]i32 = [_]i32{-1} ** 20,
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
    sink_offset: i32 = 0,
    attack_start: i32 = 0,
    attack_angle: f32 = 0,
    next_bullet_id: u8 = 0,
    move_angle: f32 = std.math.nan_f32,
    visual_move_angle: f32 = std.math.nan_f32,
    speed_mult: f32 = 1.0,
    dir: u8 = assets.left_dir,
    light_color: i32 = -1,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    last_ground_damage: i32 = -1,
    anim_data: assets.AnimPlayerData = undefined,

    pub fn getSquare(self: Player) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn moveSpeed(self: Player) f32 {
        return (0.004 + @as(f32, @floatFromInt(self.speed)) / 100.0 * 0.004) * self.speed_mult;
    }

    pub fn addToMap(self: *Player) void {
        while (!object_lock.tryLock()) {}
        defer object_lock.unlock();

        const tex_list = game_data.obj_type_to_tex_data.get(self.obj_type);
        if (tex_list != null) {
            const tex = tex_list.?[@as(usize, @intCast(self.obj_id)) % tex_list.?.len];
            self.anim_data = assets.anim_players.get(tex.sheet).?[tex.index];
        }

        const props = game_data.obj_type_to_props.get(self.obj_type);
        if (props) |obj_props| {
            self.size = obj_props.getSize();
            self.light_color = obj_props.light_color;
            self.light_intensity = obj_props.light_intensity;
            self.light_radius = obj_props.light_radius;
        }

        players.append(self.*) catch |e| {
            std.log.err("Could not add player to map (obj_id={d}, obj_type={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.obj_type, self.x, self.y, e });
        };
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

    pub inline fn update(self: *Player, time: i32, dt: i32) void {
        const is_self = self.obj_id == local_player_id;
        if (is_self) {
            if (!std.math.isNan(self.move_angle)) {
                const move_speed = self.moveSpeed();
                const total_angle = camera.angle + self.move_angle;
                const float_dt: f32 = @floatFromInt(dt);
                const next_x = self.x + move_speed * float_dt * @cos(total_angle);
                const next_y = self.y + move_speed * float_dt * @sin(total_angle);
                const next_x_floor: u32 = @intFromFloat(@floor(next_x));
                const next_y_floor: u32 = @intFromFloat(@floor(next_y));
                if (validPos(@intCast(next_x_floor), @intCast(next_y_floor))) {
                    const target_square = squares[next_y_floor * @as(u32, @intCast(width)) + next_x_floor];
                    if (!target_square.blocking) {
                        self.x = next_x;
                        self.y = next_y;
                    }
                }
            }

            if (time - self.last_ground_damage >= 550) {
                const floor_x: u32 = @intFromFloat(@floor(self.x));
                const floor_y: u32 = @intFromFloat(@floor(self.y));
                if (validPos(floor_x, floor_y)) {
                    const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
                    if (square.tile_type != 0xFFFF and square.tile_type != 0xFF and square.damage > 0) {
                        if (main.server) |*server|
                            server.sendGroundDamage(time, .{ .x = self.x, .y = self.y }) catch |e| {
                                std.log.err("Failed to ground damage: {any}", .{e});
                            };
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
                        break :moveBlock;
                    }

                    const scale_dt = @as(f32, @floatFromInt(time - last_tick_time)) / 100.0;
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
        }
    }
};
pub const Projectile = struct {
    var next_obj_id: i32 = 0x7F000000;

    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    size: f32 = 1.0,
    screen_y: f32 = 0.0,
    obj_id: i32 = 0,
    tex_u: f32 = 0.0,
    tex_v: f32 = 0.0,
    tex_w: f32 = 0.0,
    tex_h: f32 = 0.0,
    start_time: i32 = 0.0,
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
    props: game_data.ProjProps,

    pub fn getSquare(self: Projectile) Square {
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
    }

    pub fn addToMap(self: *Projectile) void {
        while (!proj_lock.tryLock()) {}
        defer proj_lock.unlock();

        const tex_list = self.props.texture_data;
        const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];
        const rect = assets.rects.get(tex.sheet).?[tex.index];
        self.tex_u = @as(f32, @floatFromInt(rect.x)) * assets.base_texel_w;
        self.tex_v = @as(f32, @floatFromInt(rect.y)) * assets.base_texel_h;
        self.tex_w = @as(f32, @floatFromInt(rect.w)) * assets.base_texel_w;
        self.tex_h = @as(f32, @floatFromInt(rect.h)) * assets.base_texel_h;

        self.obj_id = Projectile.next_obj_id + 1;
        Projectile.next_obj_id += 1;

        projectiles.append(self.*) catch |e| {
            std.log.err("Could not add projectile to map (obj_id={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.x, self.y, e });
        };
    }

    inline fn findTargetObject(x: f32, y: f32, radius_sqr: f32) ?*GameObject {
        var min_dist = std.math.floatMax(f32);
        var target: ?*GameObject = null;
        for (objects.items) |*obj| {
            if (obj.is_enemy) {
                const dist_sqr = utils.distSqr(obj.x, obj.y, x, y);
                if (dist_sqr < radius_sqr and dist_sqr < min_dist) {
                    min_dist = dist_sqr;
                    target = obj;
                }
            }
        }

        return target;
    }

    inline fn findTargetPlayer(x: f32, y: f32, radius_sqr: f32) ?*Player {
        var min_dist = std.math.floatMax(f32);
        var target: ?*Player = null;
        for (players.items) |*player| {
            const dist_sqr = utils.distSqr(player.x, player.y, x, y);
            if (dist_sqr < radius_sqr and dist_sqr < min_dist) {
                min_dist = dist_sqr;
                target = player;
            }
        }

        return target;
    }

    inline fn updatePosition(self: *Projectile, elapsed: i32, dt: f32) void {
        if (self.props.heat_seek_radius > 0 and elapsed >= self.props.heat_seek_delay and !self.heat_seek_fired) {
            var target_x: f32 = -1.0;
            var target_y: f32 = -1.0;

            if (self.damage_players) {
                const player = findTargetPlayer(self.x, self.y, self.props.heat_seek_radius * self.props.heat_seek_radius);
                if (player != null) {
                    target_x = player.?.x;
                    target_y = player.?.y;
                }
            } else {
                const object = findTargetObject(self.x, self.y, self.props.heat_seek_radius * self.props.heat_seek_radius);
                if (object != null) {
                    target_x = object.?.x;
                    target_y = object.?.y;
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

    pub inline fn update(self: *Projectile, time: i32, dt: i32, allocator: std.mem.Allocator) bool {
        const elapsed = time - self.start_time;
        if (elapsed >= self.props.lifetime_ms)
            return false;

        const last_x = self.x;
        const last_y = self.y;

        self.updatePosition(elapsed, @floatFromInt(dt));
        const floor_y: u32 = @intFromFloat(@floor(self.y));
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        if (validPos(floor_x, floor_y)) {
            const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
            if (square.tile_type == 0xFF or square.tile_type == 0xFFFF or square.blocking) {
                // if (main.server) |*server| {
                //     server.otherHit(time, self.bullet_id, self.owner_id) catch |e| {
                //         std.log.err("Could not send other hit: {any}", .{e});
                //     };
                // }

                return false;
            }
        }

        if (last_x == 0 and last_y == 0) {
            self.visual_angle = self.angle;
        } else if (self.y - last_y != 0 or self.x - last_x != 0) {
            self.visual_angle = std.math.atan2(f32, self.y - last_y, self.x - last_x);
        }

        if (self.damage_players) {
            const player = findTargetPlayer(self.x, self.y, 0.33);
            if (player != null) {
                if (main.server) |*server|
                    server.sendPlayerHit(self.bullet_id, self.owner_id) catch |e| {
                        std.log.err("Could not send player hit: {any}", .{e});
                    };

                if (self.props.min_damage > 0) {
                    // zig fmt: off
                    ui.status_texts.append(ui.StatusText{
                        .ref_x = &player.?.screen_x,
                        .ref_y = &player.?.screen_y,
                        .start_time = time,
                        .color = 0xB02020,
                        .text = std.fmt.allocPrint(allocator, "-{d}", .{self.props.min_damage}) catch unreachable
                    }) catch |e| {
                        std.log.err("Allocation for damage text \"-{d}\" failed: {any}", .{self.props.min_damage, e});
                    };
                    // zig fmt: on
                }

                return false;
            }
        } else {
            const object = findTargetObject(self.x, self.y, 0.33);
            if (object != null and main.server != null) {
                const dead = object.?.hp <= self.props.min_damage;

                if (main.server) |*server|
                    server.sendEnemyHit(time, self.bullet_id, object.?.obj_id, dead) catch |e| {
                        std.log.err("Could not send enemy hit: {any}", .{e});
                    };

                if (self.props.min_damage > 0) {
                    // zig fmt: off
                    ui.status_texts.append(ui.StatusText{
                        .ref_x = &object.?.screen_x,
                        .ref_y = &object.?.screen_y,
                        .start_time = time,
                        .color = 0xB02020,
                        .text = std.fmt.allocPrint(allocator, "-{d}", .{self.props.min_damage}) catch unreachable
                    }) catch |e| {
                        std.log.err("Allocation for damage text \"-{d}\" failed: {any}", .{self.props.min_damage, e});
                    };
                    // zig fmt: on
                }

                return false;
            }
        }

        return true;
    }
};

const day_cycle_ms: i32 = 10 * 60 * 1000; // 10 minutes
const day_cycle_ms_half: f32 = @floatFromInt(day_cycle_ms / 2);

pub var object_lock: std.Thread.Mutex = .{};
pub var proj_lock: std.Thread.Mutex = .{};
pub var objects: std.ArrayList(GameObject) = undefined;
pub var players: std.ArrayList(Player) = undefined;
pub var projectiles: std.ArrayList(Projectile) = undefined;
pub var proj_indices_to_remove: std.ArrayList(usize) = undefined;
pub var last_tick_time: i32 = 0;
pub var local_player_id: i32 = -1;
pub var interactive_id: i32 = -1;
pub var name: []const u8 = "";
pub var width: isize = 0;
pub var height: isize = 0;
pub var squares: []Square = &[0]Square{};
pub var bg_light_color: i32 = -1;
pub var bg_light_intensity: f32 = 0.0;
pub var day_light_intensity: f32 = 0.0;
pub var night_light_intensity: f32 = 0.0;
pub var server_time_offset: i32 = 0;
pub var move_records: std.ArrayList(network.TimedPosition) = undefined;
pub var last_records_clear_time: i32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    objects = std.ArrayList(GameObject).init(allocator);
    players = std.ArrayList(Player).init(allocator);
    projectiles = std.ArrayList(Projectile).init(allocator);
    proj_indices_to_remove = std.ArrayList(usize).init(allocator);
    move_records = std.ArrayList(network.TimedPosition).init(allocator);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    if (squares.len > 0) {
        allocator.free(squares);
    }

    objects.deinit();
    players.deinit();
    projectiles.deinit();
    proj_indices_to_remove.deinit();
    move_records.deinit();
}

pub fn getLightIntensity(time: i32) f32 {
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
    while (!object_lock.tryLock()) {}
    defer object_lock.unlock();

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

    var interactive_set: bool = false;
    for (objects.items) |*obj| {
        if (!interactive_set and obj.class == .portal) {
            const dt_x = camera.x - obj.x;
            const dt_y = camera.y - obj.y;
            if (dt_x * dt_x + dt_y * dt_y < 1) {
                interactive_id = obj.obj_id;
                interactive_set = true;
            }
        }

        obj.update(time, dt);
    }

    if (!interactive_set)
        interactive_id = -1;

    while (!proj_lock.tryLock()) {}
    defer proj_lock.unlock();

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

pub inline fn validPos(x: isize, y: isize) bool {
    return !(x < 0 or x >= width or y < 0 or y >= height);
}

pub fn setSquare(x: isize, y: isize, tile_type: u16) void {
    const idx: usize = @intCast(x + y * width);

    var square = Square{
        .tile_type = tile_type,
        .x = @as(f32, @floatFromInt(x)) + 0.5,
        .y = @as(f32, @floatFromInt(y)) + 0.5,
    };

    const tex_list = game_data.ground_type_to_tex_data.get(tile_type);
    if (tex_list != null) {
        const tex = if (tex_list.?.len == 1) tex_list.?[0] else tex_list.?[utils.rng.next() % tex_list.?.len];
        const rect = assets.rects.get(tex.sheet).?[tex.index];
        square.tex_u = @as(f32, @floatFromInt(rect.x + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_width));
        square.tex_v = @as(f32, @floatFromInt(rect.y + assets.padding)) / @as(f32, @floatFromInt(assets.atlas_height));
        square.tex_w = @as(f32, @floatFromInt(rect.w - assets.padding * 2)) / @as(f32, @floatFromInt(assets.atlas_width));
        square.tex_h = @as(f32, @floatFromInt(rect.h - assets.padding * 2)) / @as(f32, @floatFromInt(assets.atlas_height));
        square.updateBlends();
    }

    const props = game_data.ground_type_to_props.get(tile_type);
    if (props != null) {
        square.sink = if (props.?.sink) 0.6 else 0.0;
        square.light_color = props.?.light_color;
        square.light_intensity = props.?.light_intensity;
        square.light_radius = props.?.light_radius;
        square.damage = props.?.min_damage;
        square.blocking = props.?.no_walk;
    }

    squares[idx] = square;
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
