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
const ui = @import("ui/ui.zig");
const zstbi = @import("zstbi");
const particles = @import("particles.zig");

pub const move_threshold = 0.4;
pub const min_move_speed = 0.004;
pub const max_move_speed = 0.0096;
pub const min_attack_freq = 0.0015;
pub const max_attack_freq = 0.008;
pub const min_attack_mult = 0.5;
pub const max_attack_mult = 2.0;
pub const max_sink_level = 18.0;
const object_attack_period = 300 * std.time.us_per_ms;

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
    props: ?*const game_data.GroundProps = null,
    sinking: bool = false,
    full_occupy: bool = false,
    occupy_square: bool = false,
    enemy_occupy_square: bool = false,
    is_enemy: bool = false,
    obj_id: i32 = -1,
    has_wall: bool = false,
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
            if (left_sq.tile_type != 0xFFFF and left_sq.tile_type != 0xFF and left_sq.props != null) {
                const left_blend_prio = left_sq.props.?.blend_prio;
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
            }
        }

        if (validPos(x, y - 1)) {
            const top_idx: usize = @intCast(x + (y - 1) * width);
            const top_sq = squares[top_idx];
            if (top_sq.tile_type != 0xFFFF and top_sq.tile_type != 0xFF and top_sq.props != null) {
                const top_blend_prio = top_sq.props.?.blend_prio;
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
            }
        }

        if (validPos(x + 1, y)) {
            const right_idx: usize = @intCast(x + 1 + y * width);
            const right_sq = squares[right_idx];
            if (right_sq.tile_type != 0xFFFF and right_sq.tile_type != 0xFF and right_sq.props != null) {
                const right_blend_prio = right_sq.props.?.blend_prio;
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
            }
        }

        if (validPos(x, y + 1)) {
            const bottom_idx: usize = @intCast(x + (y + 1) * width);
            const bottom_sq = squares[bottom_idx];
            if (bottom_sq.tile_type != 0xFFFF and bottom_sq.tile_type != 0xFF and bottom_sq.props != null) {
                const bottom_blend_prio = bottom_sq.props.?.blend_prio;
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
            }
        }
    }
};

pub const GameObject = struct {
    obj_id: i32 = -1,
    obj_type: u16 = 0,
    dead: bool = false,
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
    light_color: u32 = 0,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    class: game_data.ClassType = .game_object,
    show_name: bool = false,
    hit_sound: []const u8 = &[0]u8{},
    death_sound: []const u8 = &[0]u8{},
    action: u8 = 0,
    float_period: f32 = 0.0,
    full_occupy: bool = false,
    occupy_square: bool = false,
    enemy_occupy_square: bool = false,
    colors: []u32 = &[0]u32{},

    pub fn addToMap(self: *GameObject, allocator: std.mem.Allocator) void {
        const should_lock = entities.isFull();
        if (should_lock) {
            while (!object_lock.tryLock()) {}
        }
        defer if (should_lock) object_lock.unlock();

        const floor_y: u32 = @intFromFloat(@floor(self.y));
        const floor_x: u32 = @intFromFloat(@floor(self.x));

        var _props: ?game_data.ObjProps = null;
        if (game_data.obj_type_to_props.get(self.obj_type)) |props| {
            _props = props;
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
            self.full_occupy = props.full_occupy;
            self.occupy_square = props.occupy_square;
            self.enemy_occupy_square = props.enemy_occupy_square;

            if (props.draw_on_ground)
                self.atlas_data.removePadding();

            if (props.full_occupy or props.static and props.occupy_square) {
                if (validPos(floor_x, floor_y)) {
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].obj_id = self.obj_id;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].enemy_occupy_square = props.enemy_occupy_square;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].occupy_square = props.occupy_square;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].full_occupy = props.full_occupy;
                    squares[floor_y * @as(u32, @intCast(width)) + floor_x].is_enemy = props.is_enemy;
                }
            }
        }

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

                    if (_props != null and _props.?.static and _props.?.occupy_square) {
                        if (assets.dominant_color_data.get(tex.sheet)) |color_data| {
                            const color = color_data[tex.index];
                            const base_data_idx: usize = @intCast(floor_y * minimap.num_components * minimap.width + floor_x * minimap.num_components);
                            minimap.data[base_data_idx] = color.r;
                            minimap.data[base_data_idx + 1] = color.g;
                            minimap.data[base_data_idx + 2] = color.b;
                            minimap.data[base_data_idx + 3] = color.a;

                            main.minimap_update_min_x = @min(main.minimap_update_min_x, floor_x);
                            main.minimap_update_max_x = @max(main.minimap_update_max_x, floor_x);
                            main.minimap_update_min_y = @min(main.minimap_update_min_y, floor_y);
                            main.minimap_update_max_y = @max(main.minimap_update_max_y, floor_y);
                        }
                    }

                    if (game_data.obj_type_to_class.get(self.obj_type) == .wall) {
                        self.atlas_data.removePadding();
                    }
                }

                colorParse: {
                    const atlas_data = if (tex.animated) self.anim_data.?.walk_anims[0][0] else self.atlas_data;
                    if (atlas_to_color_data.get(@bitCast(atlas_data))) |colors| {
                        self.colors = colors;
                    } else {
                        var colors = std.ArrayList(u32).init(allocator);
                        defer colors.deinit();

                        const num_comps = assets.atlas.num_components;
                        const atlas_w = assets.atlas.width;
                        const tex_x: u32 = @intFromFloat(atlas_data.texURaw());
                        const tex_y: u32 = @intFromFloat(atlas_data.texVRaw());
                        const tex_w: u32 = @intFromFloat(atlas_data.texWRaw());
                        const tex_h: u32 = @intFromFloat(atlas_data.texHRaw());

                        for (tex_y..tex_y + tex_h) |y| {
                            colorParseInner: for (tex_x..tex_x + tex_w) |x| {
                                if (assets.atlas.data[(y * atlas_w + x) * num_comps + 3] > 0) {
                                    const r: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps]);
                                    const g: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 1]);
                                    const b: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 2]);
                                    const color: u32 = r << 16 | g << 8 | b;
                                    for (colors.items) |out_color| {
                                        if (out_color == color)
                                            continue :colorParseInner;
                                    }

                                    colors.append(color) catch break :colorParse;
                                }
                            }
                        }

                        if (colors.items.len == 0)
                            break :colorParse;

                        self.colors = allocator.dupe(u32, colors.items) catch break :colorParse;
                        atlas_to_color_data.put(@bitCast(atlas_data), self.colors) catch break :colorParse;
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
            if (self.is_wall and validPos(floor_x, floor_y)) {
                self.x = @floor(self.x) + 0.5;
                self.y = @floor(self.y) + 0.5;
                self.target_x = -1;
                self.target_y = -1;

                const w: u32 = @intCast(width);
                squares[floor_y * w + floor_x].has_wall = true;
            }

            if (class_props == .container)
                assets.playSfx("loot_appears");
        }

        self.class = game_data.obj_type_to_class.get(self.obj_type) orelse .game_object;

        entities.add(.{ .object = self.* }) catch |e| {
            std.log.err("Could not add object to map (obj_id={d}, obj_type={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.obj_type, self.x, self.y, e });
        };
    }

    pub fn takeDamage(
        self: *GameObject,
        damage_amount: i32,
        kill: bool,
        armor_pierce: bool,
        time: i64,
        conditions: []game_data.ConditionEffect,
        proj_colors: []u32,
        proj_angle: f32,
        proj_speed: f32,
        ground_damage: bool,
        allocator: std.mem.Allocator,
    ) void {
        if (self.dead)
            return;

        if (kill) {
            self.dead = true;

            assets.playSfx(self.death_sound);
            var effect = particles.ExplosionEffect{
                .x = self.x,
                .y = self.y,
                .colors = self.colors,
                .size = self.size,
                .amount = 30,
            };
            effect.addToMap();
        } else {
            assets.playSfx(self.hit_sound);

            var effect = particles.HitEffect{
                .x = self.x,
                .y = self.y,
                .colors = proj_colors,
                .angle = proj_angle,
                .speed = proj_speed,
                .size = 1.0,
                .amount = 3,
            };
            effect.addToMap();

            if (conditions.len > 0) {
                for (conditions) |eff| {
                    const cond_str = eff.condition.toString();
                    if (cond_str.len == 0)
                        continue;

                    switch (eff.condition) {
                        .dead => self.condition.dead = true,
                        .quiet => self.condition.quiet = true,
                        .weak => self.condition.weak = true,
                        .slowed => self.condition.slowed = true,
                        .sick => self.condition.sick = true,
                        .dazed => self.condition.dazed = true,
                        .blind => self.condition.blind = true,
                        .hallucinating => self.condition.hallucinating = true,
                        .drunk => self.condition.drunk = true,
                        .confused => self.condition.confused = true,
                        .invisible => self.condition.invisible = true,
                        .paralyzed => self.condition.paralyzed = true,
                        .speedy => self.condition.speedy = true,
                        .bleeding => self.condition.bleeding = true,
                        .healing => self.condition.healing = true,
                        .damaging => self.condition.damaging = true,
                        .berserk => self.condition.berserk = true,
                        .paused => self.condition.paused = true,
                        .invincible => self.condition.invincible = true,
                        .invulnerable => self.condition.invulnerable = true,
                        .armored => self.condition.armored = true,
                        .armor_broken => self.condition.armor_broken = true,
                        .hexed => self.condition.hexed = true,
                        .ninja_speedy => self.condition.ninja_speedy = true,

                        // immune cases
                        // only have two cases in this version so just doing them

                        .stasis => {
                            if (self.condition.stasis_immune) {
                                const immune_text_data = ui.TextData{
                                    .text = std.fmt.allocPrint(allocator, "Immune", .{}) catch unreachable,
                                    .text_type = .bold,
                                    .size = 22,
                                    .color = 0xFF0000,
                                    .backing_buffer = &[0]u8{},
                                };

                                ui.elements.add(.{ .status = ui.StatusText{
                                    .obj_id = self.obj_id,
                                    .start_time = time,
                                    .text_data = immune_text_data,
                                    .initial_size = 22,
                                } }) catch |e| {
                                    std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                                };
                            } else {
                                // apply stasis effect
                                self.condition.stasis = true;
                            }
                        },
                        .stunned => {
                            if (self.condition.stun_immune) {
                                const immune_text_data = ui.TextData{
                                    .text = std.fmt.allocPrint(allocator, "Immune", .{}) catch unreachable,
                                    .text_type = .bold,
                                    .size = 22,
                                    .color = 0xFF0000,
                                    .backing_buffer = &[0]u8{},
                                };

                                ui.elements.add(.{ .status = ui.StatusText{
                                    .obj_id = self.obj_id,
                                    .start_time = time,
                                    .text_data = immune_text_data,
                                    .initial_size = 22,
                                } }) catch |e| {
                                    std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                                };
                            } else {
                                // apply stasis effect
                                self.condition.stunned = true;
                            }
                        },
                        else => {
                            std.log.err("Unknown ConditionEffect: {s} inside gameobject.takeDamage();", .{cond_str});
                        },
                    }

                    const text_data = ui.TextData{
                        .text = std.fmt.allocPrint(allocator, "{s}", .{cond_str}) catch unreachable,
                        .text_type = .bold,
                        .size = 22,
                        .color = 0xB02020,
                        .backing_buffer = &[0]u8{},
                    };

                    ui.elements.add(.{ .status = ui.StatusText{
                        .obj_id = self.obj_id,
                        .start_time = time,
                        .text_data = text_data,
                        .initial_size = 22,
                    } }) catch |e| {
                        std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                    };
                }
            }
        }

        if (damage_amount > 0) {
            const pierced = self.condition.armor_broken or armor_pierce or ground_damage;
            showDamageText(time, damage_amount, pierced, self.obj_id, allocator);
        }
    }

    pub fn update(self: *GameObject, time: i64, _: f32) void {
        // todo: clean this up, reuse
        const normal_time = main.current_time;
        if (normal_time < self.attack_start + object_attack_period) {
            // if(!bo.dont_face_attacks){
            self.facing = self.attack_angle;
            // }
            const time_dt: f32 = @floatFromInt(normal_time - self.attack_start);
            self.float_period = @mod(time_dt, object_attack_period) / object_attack_period;
            self.action = assets.attack_action;
        } else if (!std.math.isNan(self.move_angle)) {
            var move_period = 0.5 / utils.distSqr(self.tick_x, self.tick_y, self.target_x, self.target_y);
            move_period += 400 - @mod(move_period, 400);
            const float_time = @as(f32, @floatFromInt(normal_time)) / std.time.us_per_ms;
            self.float_period = @mod(float_time, move_period) / move_period;
            // if(!bo.dont_face_attacks){
            self.facing = self.move_angle;
            // }
            self.action = assets.walk_action;
        } else {
            self.float_period = 0;
            self.action = assets.stand_action;
        }

        var screen_pos = camera.rotateAroundCamera(self.x, self.y);
        const size = camera.size_mult * camera.scale * self.size;

        const angle = utils.halfBound(self.facing);
        const pi_over_4 = std.math.pi / 4.0;
        const angle_div = @divFloor(angle, pi_over_4);

        var sec: u8 = if (std.math.isNan(angle_div)) 0 else @as(u8, @intFromFloat(angle_div + 4)) % 8;

        sec = switch (sec) {
            0, 1, 6, 7 => assets.left_dir,
            2, 3, 4, 5 => assets.right_dir,
            else => unreachable,
        };

        // 2 frames so multiply by 2
        const capped_period = @max(0, @min(0.99999, self.float_period)) * 2.0; // 2 walk cycle frames so * 2
        const anim_idx: usize = @intFromFloat(capped_period);

        var atlas_data = self.atlas_data;
        if (self.anim_data) |anim_data| {
            atlas_data = switch (self.action) {
                assets.walk_action => anim_data.walk_anims[sec][1 + anim_idx], // offset by 1 to start at walk frame instead of idle
                assets.attack_action => anim_data.attack_anims[sec][anim_idx],
                assets.stand_action => anim_data.walk_anims[sec][0],
                else => unreachable,
            };
        }

        const h = atlas_data.texHRaw() * size;
        self.screen_y = screen_pos.y + self.z * -camera.px_per_tile - (h - size * assets.padding) - 10;
        self.screen_x = screen_pos.x;

        moveBlock: {
            if (self.is_wall)
                break :moveBlock;

            if (self.target_x > 0 and self.target_y > 0) {
                if (last_tick_time <= 0 or self.x <= 0 or self.y <= 0) {
                    self.x = self.target_x;
                    self.y = self.target_y;
                    self.target_x = -1;
                    self.target_y = -1;
                    break :moveBlock;
                }

                const scale_dt = @as(f32, @floatFromInt(time - last_tick_time)) / last_tick_ms;
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
    dead: bool = false,
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
    light_color: u32 = 0,
    light_intensity: f32 = 0.1,
    light_radius: f32 = 1.0,
    last_ground_damage_time: i64 = -1,
    anim_data: assets.AnimPlayerData = undefined,
    move_multiplier: f32 = 1.0,
    sink_level: f32 = 0,
    hit_sound: []const u8 = &[0]u8{},
    death_sound: []const u8 = &[0]u8{},
    action: u8 = 0,
    float_period: f32 = 0.0,
    colors: []u32 = &[0]u32{},
    next_ability_attack_time: i64 = -1,
    mp_zeroed: bool = false,
    move_vec_x: f32 = 0.0,
    move_vec_y: f32 = 0.0,

    pub fn onMove(self: *Player) void {
        const square = getSquare(self.x, self.y);
        if (square.props == null)
            return;

        if (square.props.?.sinking) {
            self.sink_level = @min(self.sink_level + 1, max_sink_level);
            self.move_multiplier = 0.1 + (1 - self.sink_level / max_sink_level) * (square.props.?.speed - 0.1);
        } else {
            self.sink_level = 0;
            self.move_multiplier = square.props.?.speed;
        }
    }

    pub fn attackMultiplier(self: Player) f32 {
        if (self.condition.weak)
            return min_attack_mult;

        const float_attack: f32 = @floatFromInt(self.attack);
        var mult = min_attack_mult + float_attack / 75.0 * (max_attack_mult - min_attack_mult);
        if (self.condition.damaging)
            mult *= 1.5;

        return mult;
    }

    pub fn moveSpeedMultiplier(self: Player) f32 {
        if (self.condition.slowed)
            return min_move_speed * self.move_multiplier * self.walk_speed_multiplier;

        const float_speed: f32 = @floatFromInt(self.speed);
        var move_speed = min_move_speed + float_speed / 75.0 * (max_move_speed - min_move_speed);
        if (self.condition.speedy or self.condition.ninja_speedy)
            move_speed *= 1.5;

        return move_speed * self.move_multiplier * self.walk_speed_multiplier;
    }

    pub fn addToMap(self: *Player, allocator: std.mem.Allocator) void {
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

            colorParse: {
                const atlas_data = self.anim_data.walk_anims[0][0];
                if (atlas_to_color_data.get(@bitCast(atlas_data))) |colors| {
                    self.colors = colors;
                } else {
                    var colors = std.ArrayList(u32).init(allocator);
                    defer colors.deinit();

                    const num_comps = assets.atlas.num_components;
                    const atlas_w = assets.atlas.width;
                    const tex_x: u32 = @intFromFloat(atlas_data.texURaw());
                    const tex_y: u32 = @intFromFloat(atlas_data.texVRaw());
                    const tex_w: u32 = @intFromFloat(atlas_data.texWRaw());
                    const tex_h: u32 = @intFromFloat(atlas_data.texHRaw());

                    for (tex_y..tex_y + tex_h) |y| {
                        colorParseInner: for (tex_x..tex_x + tex_w) |x| {
                            if (assets.atlas.data[(y * atlas_w + x) * num_comps + 3] > 0) {
                                const r: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps]);
                                const g: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 1]);
                                const b: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 2]);
                                const color: u32 = r << 16 | g << 8 | b;
                                for (colors.items) |out_color| {
                                    if (out_color == color)
                                        continue :colorParseInner;
                                }

                                colors.append(color) catch break :colorParse;
                            }
                        }
                    }

                    if (colors.items.len == 0)
                        break :colorParse;

                    self.colors = allocator.dupe(u32, colors.items) catch break :colorParse;
                    atlas_to_color_data.put(@bitCast(atlas_data), self.colors) catch break :colorParse;
                }
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

    // todo change use_type to be enum?
    pub fn useAbility(self: *Player, screen_x: f32, screen_y: f32, use_type: game_data.UseType) void {
        if (self.condition.paused) {
            assets.playSfx("error");
            return;
        }

        const item_type: i32 = self.inventory[1];
        if (item_type == -1) {
            assets.playSfx("error");
            return;
        }

        const item_props = game_data.item_type_to_props.getPtr(@intCast(item_type));
        if (item_props == null or !item_props.?.usable) {
            // doesnt actually error on original but it hink it makes sense
            assets.playSfx("error");
            return;
        }

        const angle = camera.angle + std.math.atan2(f32, screen_y - camera.screen_height / 2.0, screen_x - camera.screen_width / 2.0);

        var is_shoot = false;
        var needs_walkable = false;

        if (use_type == game_data.UseType.start) {
            if (item_props.?.activations) |activate| {
                for (activate) |data| {
                    if (data.activation_type == game_data.ActivationType.teleport or
                        data.activation_type == game_data.ActivationType.object_toss)
                    {
                        needs_walkable = true;
                    }

                    if (data.activation_type == game_data.ActivationType.shoot) {
                        is_shoot = true;
                    }
                }
            }
        }

        var position = camera.screenToWorld(screen_x, screen_y);
        if (needs_walkable and !isValidPosition(position.x, position.y)) {
            assets.playSfx("error");
            return;
        }

        const now = main.current_time;
        if (use_type == game_data.UseType.start) {
            if (now < self.next_ability_attack_time) {
                assets.playSfx("error");
                return;
            }

            const mana_cost: i32 = @intFromFloat(item_props.?.mp_cost);
            if (mana_cost > self.mp) {
                assets.playSfx("no_mana");
                return;
            }

            const cooldown = @as(i64, @intFromFloat(item_props.?.cooldown * 1000.0)) * std.time.us_per_ms;
            self.next_ability_attack_time = now + cooldown;

            self.mp_zeroed = false;

            network.queuePacket(.{ .use_item = .{
                .obj_id = self.obj_id,
                .slot_id = 1,
                .obj_type = item_type,
                .x = position.x,
                .y = position.y,
                .time = main.current_time,
                .use_type = use_type,
            } });

            if (is_shoot)
                self.doShoot(now, item_type, item_props, angle, false);
        } else {
            if (item_props.?.multi_phase) {
                network.queuePacket(.{ .use_item = .{
                    .obj_id = self.obj_id,
                    .slot_id = 1,
                    .obj_type = item_type,
                    .x = position.x,
                    .y = position.y,
                    .time = main.current_time,
                    .use_type = use_type,
                } });

                // todo
                // if (@as(i32, @intFromFloat(item_props.?.mp_end_cost)) <= self.mp && !self.mp_zeroed) {
                //     self.doShoot(now, itemType, objectXML, angle, false);
                // }
            }
        }
    }

    pub fn doShoot(self: *Player, time: i64, weapon_type: i32, item_props: ?*game_data.ItemProps, attack_angle: f32, use_mult: bool) void {
        const projs_len = item_props.?.num_projectiles;
        const arc_gap = item_props.?.arc_gap;
        const total_angle = arc_gap * @as(f32, @floatFromInt(projs_len - 1));
        var angle = attack_angle - total_angle / 2.0;
        const proj_props = &item_props.?.projectile.?;

        const container_type = if (weapon_type == -1) std.math.maxInt(u16) else @as(u16, @intCast(weapon_type));

        for (0..projs_len) |_| {
            const bullet_id = @mod(self.next_bullet_id + 1, 128);
            self.next_bullet_id = bullet_id;
            const x = self.x + @cos(attack_angle) * 0.25;
            const y = self.y + @sin(attack_angle) * 0.25;

            const att_mult = if (use_mult) self.attackMultiplier() else 1.0;
            const damage_raw: f32 = @floatFromInt(random.nextIntRange(@intCast(proj_props.min_damage), @intCast(proj_props.max_damage)));
            const damage: i32 = @intFromFloat(damage_raw * att_mult);

            // todo add once move records are added
            // var damage: i32 = @as(i32, @intFromFloat(damageRaw));
            // if (time > map.last_records_clear_time + (std.time.us_per_ms * 600)) { // 600ms then drop dmg
            //     damage = 0;
            // }

            var proj = Projectile{
                .x = x,
                .y = y,
                .props = proj_props,
                .angle = angle,
                .start_time = @divFloor(time, std.time.us_per_ms),
                .bullet_id = bullet_id,
                .owner_id = self.obj_id,
                .damage = damage,
            };
            proj.addToMap(false);

            network.queuePacket(.{
                .player_shoot = .{
                    .time = time,
                    .bullet_id = bullet_id,
                    .container_type = container_type, // todo mabye convert to a i32 for packet or convert client into u16?
                    .start_x = x,
                    .start_y = y,
                    .angle = angle,
                },
            });

            angle += arc_gap;
        }
    }

    pub fn weaponShoot(self: *Player, angle: f32, time: i64) void {
        if (self.condition.stunned or self.condition.stasis)
            return;

        const weapon_type: i32 = self.inventory[0];
        if (weapon_type == -1)
            return;

        const item_props = game_data.item_type_to_props.getPtr(@intCast(weapon_type));
        if (item_props == null or item_props.?.projectile == null)
            return;

        const attack_delay: i64 = @intFromFloat((1.0 / attackFrequency(self)) * (1.0 / item_props.?.rate_of_fire) * std.time.us_per_ms);
        if (time < self.attack_start + attack_delay)
            return;

        assets.playSfx(item_props.?.old_sound);

        self.attack_period = attack_delay;
        self.attack_angle = angle - camera.angle;
        self.attack_angle_raw = angle;
        self.attack_start = time;

        self.doShoot(self.attack_start, weapon_type, item_props, self.attack_angle_raw, true);
    }

    pub fn takeDamage(
        self: *Player,
        damage_amount: i32,
        kill: bool,
        armor_pierce: bool,
        time: i64,
        conditions: []game_data.ConditionEffect,
        proj_colors: []u32,
        proj_angle: f32,
        proj_speed: f32,
        ground_damage: bool,
        allocator: std.mem.Allocator,
    ) void {
        if (self.dead)
            return;

        if (kill) {
            self.dead = true;

            assets.playSfx(self.death_sound);
            var effect = particles.ExplosionEffect{
                .x = self.x,
                .y = self.y,
                .colors = self.colors,
                .size = self.size,
                .amount = 30,
            };
            effect.addToMap();
        } else {
            assets.playSfx(self.hit_sound);

            var effect = particles.HitEffect{
                .x = self.x,
                .y = self.y,
                .colors = proj_colors,
                .angle = proj_angle,
                .speed = proj_speed,
                .size = 1.0,
                .amount = 3,
            };
            effect.addToMap();

            if (conditions.len > 0) {
                for (conditions) |eff| {
                    const cond_str = eff.condition.toString();
                    if (cond_str.len == 0)
                        continue;

                    switch (eff.condition) {
                        utils.ConditionEnum.dead => self.condition.dead = true,
                        utils.ConditionEnum.quiet => self.condition.quiet = true,
                        utils.ConditionEnum.weak => self.condition.weak = true,
                        utils.ConditionEnum.slowed => self.condition.slowed = true,
                        utils.ConditionEnum.sick => self.condition.sick = true,
                        utils.ConditionEnum.dazed => self.condition.dazed = true,
                        utils.ConditionEnum.blind => self.condition.blind = true,
                        utils.ConditionEnum.hallucinating => self.condition.hallucinating = true,
                        utils.ConditionEnum.drunk => self.condition.drunk = true,
                        utils.ConditionEnum.confused => self.condition.confused = true,
                        utils.ConditionEnum.invisible => self.condition.invisible = true,
                        utils.ConditionEnum.paralyzed => self.condition.paralyzed = true,
                        utils.ConditionEnum.speedy => self.condition.speedy = true,
                        utils.ConditionEnum.bleeding => self.condition.bleeding = true,
                        utils.ConditionEnum.healing => self.condition.healing = true,
                        utils.ConditionEnum.damaging => self.condition.damaging = true,
                        utils.ConditionEnum.berserk => self.condition.berserk = true,
                        utils.ConditionEnum.paused => self.condition.paused = true,
                        utils.ConditionEnum.invincible => self.condition.invincible = true,
                        utils.ConditionEnum.invulnerable => self.condition.invulnerable = true,
                        utils.ConditionEnum.armored => self.condition.armored = true,
                        utils.ConditionEnum.armor_broken => self.condition.armor_broken = true,
                        utils.ConditionEnum.hexed => self.condition.hexed = true,
                        utils.ConditionEnum.ninja_speedy => self.condition.ninja_speedy = true,

                        // immune cases
                        // only have two cases in this version so just doing them

                        utils.ConditionEnum.stasis => {
                            if (self.condition.stasis_immune) {
                                const immune_text_data = ui.TextData{
                                    .text = std.fmt.allocPrint(allocator, "Immune", .{}) catch unreachable,
                                    .text_type = .bold,
                                    .size = 22,
                                    .color = 0xFF0000,
                                    .backing_buffer = &[0]u8{},
                                };

                                ui.elements.add(.{ .status = ui.StatusText{
                                    .obj_id = self.obj_id,
                                    .start_time = time,
                                    .text_data = immune_text_data,
                                    .initial_size = 22,
                                } }) catch |e| {
                                    std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                                };
                            } else {
                                // apply stasis effect
                                self.condition.stasis = true;
                            }
                        },
                        utils.ConditionEnum.stunned => {
                            if (self.condition.stun_immune) {
                                const immune_text_data = ui.TextData{
                                    .text = std.fmt.allocPrint(allocator, "Immune", .{}) catch unreachable,
                                    .text_type = .bold,
                                    .size = 22,
                                    .color = 0xFF0000,
                                    .backing_buffer = &[0]u8{},
                                };

                                ui.elements.add(.{ .status = ui.StatusText{
                                    .obj_id = self.obj_id,
                                    .start_time = time,
                                    .text_data = immune_text_data,
                                    .initial_size = 22,
                                } }) catch |e| {
                                    std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                                };
                            } else {
                                // apply stasis effect
                                self.condition.stunned = true;
                            }
                        },
                        else => {
                            std.log.err("Unknown ConditionEffect: {s} inside player.takeDamage();", .{cond_str});
                        },
                    }

                    const text_data = ui.TextData{
                        .text = std.fmt.allocPrint(allocator, "{s}", .{cond_str}) catch unreachable,
                        .text_type = .bold,
                        .size = 22,
                        .color = 0xB02020,
                        .backing_buffer = &[0]u8{},
                    };

                    ui.elements.add(.{ .status = ui.StatusText{
                        .obj_id = self.obj_id,
                        .start_time = time,
                        .text_data = text_data,
                        .initial_size = 22,
                    } }) catch |e| {
                        std.log.err("Allocation for condition text \"{s}\" failed: {any}", .{ cond_str, e });
                    };
                }
            }
        }

        if (damage_amount > 0) {
            const pierced = self.condition.armor_broken or armor_pierce or ground_damage;
            showDamageText(time, damage_amount, pierced, self.obj_id, allocator);
        }
    }

    pub fn update(self: *Player, time: i64, dt: f32, allocator: std.mem.Allocator) void {
        const normal_time = main.current_time;
        if (normal_time < self.attack_start + self.attack_period) {
            self.facing = self.attack_angle_raw;
            const time_dt: f32 = @floatFromInt(normal_time - self.attack_start);
            self.float_period = @floatFromInt(self.attack_period);
            self.float_period = @mod(time_dt, self.float_period) / self.float_period;
            self.action = assets.attack_action;
        } else if (!std.math.isNan(self.move_angle)) {
            const walk_period = 3.5 * std.time.us_per_ms / self.moveSpeedMultiplier();
            const float_time: f32 = @floatFromInt(normal_time);
            self.float_period = @mod(float_time, walk_period) / walk_period;
            self.facing = self.move_angle_camera_included;
            self.action = assets.walk_action;
        } else {
            self.float_period = 0.0;
            self.action = assets.stand_action;
        }

        const size = camera.size_mult * camera.scale * self.size;

        const angle = utils.halfBound(self.facing - camera.angle_unbound);
        const pi_over_4 = std.math.pi / 4.0;
        const angle_div = (angle / pi_over_4) + 4;

        var sec: u8 = if (std.math.isNan(angle_div)) 0 else @as(u8, @intFromFloat(@round(angle_div))) % 8;

        sec = switch (sec) {
            0, 7 => assets.left_dir,
            1, 2 => assets.up_dir,
            3, 4 => assets.right_dir,
            5, 6 => assets.down_dir,
            else => unreachable,
        };

        const capped_period = @max(0, @min(0.99999, self.float_period)) * 2.0; // 2 walk cycle frames so * 2
        const anim_idx: usize = @intFromFloat(capped_period);

        var atlas_data = switch (self.action) {
            assets.walk_action => self.anim_data.walk_anims[sec][1 + anim_idx], // offset by 1 to start at walk frame instead of idle
            assets.attack_action => self.anim_data.attack_anims[sec][anim_idx],
            assets.stand_action => self.anim_data.walk_anims[sec][0],
            else => unreachable,
        };

        var screen_pos = camera.rotateAroundCamera(self.x, self.y);
        const h = atlas_data.texHRaw() * size;

        self.screen_y = screen_pos.y + self.z * -camera.px_per_tile - (h - size * assets.padding) - 30; // account for name
        self.screen_x = screen_pos.x;

        const is_self = self.obj_id == local_player_id;
        if (is_self) {
            const floor_x: u32 = @intFromFloat(@floor(self.x));
            const floor_y: u32 = @intFromFloat(@floor(self.y));
            if (validPos(floor_x, floor_y)) {
                const current_square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
                if (current_square.props) |props| {
                    const slide_amount = props.slide_amount;
                    if (!std.math.isNan(self.move_angle)) {
                        const move_angle = camera.angle_unbound + self.move_angle;
                        const move_speed = self.moveSpeedMultiplier();
                        self.move_angle_camera_included = move_angle;

                        var vec_x = move_speed * @cos(move_angle);
                        var vec_y = move_speed * @sin(move_angle);

                        if (slide_amount > 0.0) {
                            var max_move_length = std.math.sqrt(vec_x * vec_x + vec_y * vec_y);

                            var temp_move_vec_x = vec_x * -1.0 * (slide_amount - 1.0);
                            var temp_move_vec_y = vec_y * -1.0 * (slide_amount - 1.0);

                            self.move_vec_x *= slide_amount;
                            self.move_vec_y *= slide_amount;

                            var move_length = std.math.sqrt(self.move_vec_x * self.move_vec_x + self.move_vec_y * self.move_vec_y);
                            if (move_length < max_move_length) {
                                self.move_vec_x += temp_move_vec_x;
                                self.move_vec_y += temp_move_vec_y;
                            }
                        } else {
                            self.move_vec_x = vec_x;
                            self.move_vec_y = vec_y;
                        }
                    } else if (std.math.sqrt(self.move_vec_x * self.move_vec_x + self.move_vec_y * self.move_vec_y) > 0.00012 and slide_amount > 0.0) {
                        self.move_vec_x *= slide_amount;
                        self.move_vec_y *= slide_amount;
                    } else {
                        self.move_vec_x = 0.0;
                        self.move_vec_y = 0.0;
                    }

                    if (props.push) {
                        self.move_vec_x -= props.anim_dx / 1000.0;
                        self.move_vec_y -= props.anim_dy / 1000.0;
                    }
                }

                const next_x = self.x + self.move_vec_x * dt;
                const next_y = self.y + self.move_vec_y * dt;
                modifyMove(self, next_x, next_y, &self.x, &self.y);
            }

            if (!self.condition.invulnerable and !self.condition.invincible and !self.condition.stasis and time - self.last_ground_damage_time >= 500) {
                const floor_ground_x: u32 = @intFromFloat(@floor(self.x));
                const floor_ground_y: u32 = @intFromFloat(@floor(self.y));
                if (validPos(floor_ground_x, floor_ground_y)) {
                    const square = squares[floor_ground_y * @as(u32, @intCast(width)) + floor_ground_x];
                    if (square.tile_type != 0xFFFF and square.tile_type != 0xFF and square.props != null and square.props.?.min_damage > 0 and !square.props.?.protect_from_ground_damage) {
                        const dmg = random.nextIntRange(square.props.?.min_damage, square.props.?.max_damage);
                        network.queuePacket(.{ .ground_damage = .{ .time = time, .x = self.x, .y = self.y } });
                        self.takeDamage(
                            @intCast(dmg),
                            dmg >= self.hp,
                            true,
                            time,
                            &[0]game_data.ConditionEffect{},
                            &[0]u32{},
                            0.0,
                            0.0,
                            true,
                            allocator,
                        );
                        self.last_ground_damage_time = time;
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

                    const scale_dt = @as(f32, @floatFromInt(time - last_tick_time)) / last_tick_ms;
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
        if (self.condition.paralyzed or self.condition.stasis) {
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
        while (true) {
            if (d + step_size >= 1.0) {
                step_size = 1.0 - d;
                break;
            }
            modifyStep(self, target_x.* + dx * step_size, target_y.* + dy * step_size, target_x, target_y);
            d += step_size;
        }
    }

    fn isValidPosition(x: f32, y: f32) bool {
        if (!isWalkable(x, y))
            return false;

        const x_frac = x - @floor(x);
        const y_frac = y - @floor(y);

        if (x_frac < 0.5) {
            if (isFullOccupy(x - 1, y))
                return false;

            if (y_frac < 0.5 and (isFullOccupy(x, y - 1) or isFullOccupy(x - 1, y - 1)))
                return false;

            if (y_frac > 0.5 and (isFullOccupy(x, y + 1) or isFullOccupy(x - 1, y + 1)))
                return false;
        } else if (x_frac > 0.5) {
            if (isFullOccupy(x + 1, y))
                return false;

            if (y_frac < 0.5 and (isFullOccupy(x, y - 1) or isFullOccupy(x + 1, y - 1)))
                return false;

            if (y_frac > 0.5 and (isFullOccupy(x, y + 1) or isFullOccupy(x + 1, y + 1)))
                return false;
        } else {
            if (y_frac < 0.5 and isFullOccupy(x, y - 1))
                return false;

            if (y_frac > 0.5 and isFullOccupy(x, y + 1))
                return false;
        }
        return true;
    }

    fn isWalkable(x: f32, y: f32) bool {
        if (x < 0 or y < 0)
            return false;

        const square = getSquare(x, y);
        const walkable = square.props == null or !square.props.?.no_walk;
        const not_occupied = !square.occupy_square;
        return square.tile_type != 0xFFFF and square.tile_type != 0xFF and walkable and not_occupied;
    }

    fn isFullOccupy(x: f32, y: f32) bool {
        if (x < 0 or y < 0)
            return true;

        return getSquare(x, y).full_occupy;
    }

    fn modifyStep(self: *Player, x: f32, y: f32, target_x: *f32, target_y: *f32) void {
        const x_cross = (@mod(self.x, 0.5) == 0 and x != self.x) or (@floor(self.x / 0.5) != @floor(x / 0.5));
        const y_cross = (@mod(self.y, 0.5) == 0 and y != self.y) or (@floor(self.y / 0.5) != @floor(y / 0.5));

        if (!x_cross and !y_cross or isValidPosition(x, y)) {
            target_x.* = x;
            target_y.* = y;
            return;
        }

        var next_x_border: f32 = 0.0;
        var next_y_border: f32 = 0.0;
        if (x_cross) {
            next_x_border = if (x > self.x) @floor(x * 2) / 2.0 else @floor(self.x * 2) / 2.0;
            if (@floor(next_x_border) > @floor(self.x))
                next_x_border -= 0.01;
        }

        if (y_cross) {
            next_y_border = if (y > self.y) @floor(y * 2) / 2.0 else @floor(self.y * 2) / 2.0;
            if (@floor(next_y_border) > @floor(self.y))
                next_y_border -= 0.01;
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
    total_angle_change: f32 = 0.0,
    zero_vel_dist: f32 = -1.0,
    start_x: f32 = 0.0,
    start_y: f32 = 0.0,
    last_deflect: f32 = 0.0,
    bullet_id: u8 = 0,
    owner_id: i32 = 0,
    damage_players: bool = false,
    damage: i32 = 0,
    props: *const game_data.ProjProps,
    last_hit_check: i64 = 0,
    colors: []u32 = &[0]u32{},
    hit_list: std.AutoHashMap(i32, void) = undefined,

    pub fn addToMap(self: *Projectile, needs_lock: bool) void {
        const should_lock = needs_lock and entities.isFull();
        if (should_lock) {
            while (!object_lock.tryLock()) {}
        }
        defer if (should_lock) object_lock.unlock();

        self.hit_list = std.AutoHashMap(i32, void).init(main._allocator);

        const tex_list = self.props.texture_data;
        const tex = tex_list[@as(usize, @intCast(self.obj_id)) % tex_list.len];
        if (assets.atlas_data.get(tex.sheet)) |data| {
            self.atlas_data = data[tex.index];
        } else {
            std.log.err("Could not find sheet {s} for proj with id {d}. Using error texture", .{ tex.sheet, self.obj_id });
            self.atlas_data = assets.error_data;
        }

        colorParse: {
            if (atlas_to_color_data.get(@bitCast(self.atlas_data))) |colors| {
                self.colors = colors;
            } else {
                var colors = std.ArrayList(u32).init(main._allocator);
                defer colors.deinit();

                const num_comps = assets.atlas.num_components;
                const atlas_w = assets.atlas.width;
                const tex_x: u32 = @intFromFloat(self.atlas_data.texURaw());
                const tex_y: u32 = @intFromFloat(self.atlas_data.texVRaw());
                const tex_w: u32 = @intFromFloat(self.atlas_data.texWRaw());
                const tex_h: u32 = @intFromFloat(self.atlas_data.texHRaw());

                for (tex_y..tex_y + tex_h) |y| {
                    colorParseInner: for (tex_x..tex_x + tex_w) |x| {
                        if (assets.atlas.data[(y * atlas_w + x) * num_comps + 3] > 0) {
                            const r: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps]);
                            const g: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 1]);
                            const b: u32 = @intCast(assets.atlas.data[(y * atlas_w + x) * num_comps + 2]);
                            const color: u32 = r << 16 | g << 8 | b;
                            for (colors.items) |out_color| {
                                if (out_color == color)
                                    continue :colorParseInner;
                            }

                            colors.append(color) catch break :colorParse;
                        }
                    }
                }

                if (colors.items.len == 0)
                    break :colorParse;

                self.colors = main._allocator.dupe(u32, colors.items) catch break :colorParse;
                atlas_to_color_data.put(@bitCast(self.atlas_data), self.colors) catch break :colorParse;
            }
        }

        self.obj_id = Projectile.next_obj_id + 1;
        Projectile.next_obj_id += 1;
        if (Projectile.next_obj_id == std.math.maxInt(i32))
            Projectile.next_obj_id = 0x7F000000;

        entities.add(.{ .projectile = self.* }) catch |e| {
            std.log.err("Could not add projectile to map (obj_id={d}, x={d}, y={d}): {any}", .{ self.obj_id, self.x, self.y, e });
        };
    }

    fn findTargetPlayer(x: f32, y: f32, radius_sqr: f32) ?*Player {
        var min_dist = radius_sqr;
        var target: ?*Player = null;

        for (entities.items()) |*en| {
            if (en.* == .player) {
                const dist_sqr = utils.distSqr(en.player.x, en.player.y, x, y);
                if (dist_sqr < min_dist) {
                    min_dist = dist_sqr;
                    target = &en.player;
                }
            }
        }

        return target;
    }

    fn findTargetObject(x: f32, y: f32, radius_sqr: f32) ?*GameObject {
        var min_dist = radius_sqr;
        var target: ?*GameObject = null;

        // todo check multi_hit container
        for (entities.items()) |*en| {
            if (en.* == .object) {
                if (en.object.is_enemy or en.object.occupy_square or en.object.enemy_occupy_square) {
                    const dist_sqr = utils.distSqr(en.object.x, en.object.y, x, y);
                    if (dist_sqr < min_dist) {
                        min_dist = dist_sqr;
                        target = &en.object;
                    }
                }
            }
        }

        return target;
    }

    fn updatePosition(self: *Projectile, elapsed: i64, dt: f32) void {
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
            if (self.props.accel == 0.0 or elapsed < self.props.accel_delay) {
                dist = dt * self.props.speed;
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

    pub fn update(self: *Projectile, time: i64, dt: f32, allocator: std.mem.Allocator) bool {
        const elapsed = time - self.start_time;
        if (elapsed >= self.props.lifetime_ms)
            return false;

        const last_x = self.x;
        const last_y = self.y;

        self.updatePosition(elapsed, dt);
        if (last_x == 0 and last_y == 0) {
            self.visual_angle = self.angle;
        } else {
            const y_dt: f32 = self.y - last_y;
            const x_dt: f32 = self.x - last_x;
            self.visual_angle = std.math.atan2(f32, y_dt, x_dt);
        }

        const floor_y: u32 = @intFromFloat(@floor(self.y));
        const floor_x: u32 = @intFromFloat(@floor(self.x));
        if (validPos(floor_x, floor_y)) {
            const square = squares[floor_y * @as(u32, @intCast(width)) + floor_x];
            if (square.tile_type == 0xFF or square.tile_type == 0xFFFF) {
                if (self.damage_players) {
                    network.queuePacket(.{ .square_hit = .{
                        .time = time,
                        .bullet_id = self.bullet_id,
                        .obj_id = self.owner_id,
                    } });
                } else {
                    // equivilant to square.obj != null)
                    if (square.obj_id != -1) {
                        var effect = particles.HitEffect{
                            .x = self.x,
                            .y = self.y,
                            .colors = self.colors,
                            .angle = self.angle,
                            .speed = self.props.speed,
                            .size = 1.0,
                            .amount = 3,
                        };
                        effect.addToMap();
                    }
                }
                return false;
            }

            if (square.obj_id != -1 and (!square.is_enemy or self.damage_players) and (square.enemy_occupy_square or (!self.props.passes_cover and square.occupy_square))) {
                if (self.damage_players) {
                    network.queuePacket(.{ .other_hit = .{
                        .time = time,
                        .bullet_id = self.bullet_id,
                        .object_id = self.owner_id,
                        .target_id = square.obj_id,
                    } });
                } else {
                    var effect = particles.HitEffect{
                        .x = self.x,
                        .y = self.y,
                        .colors = self.colors,
                        .angle = self.angle,
                        .speed = self.props.speed,
                        .size = 1.0,
                        .amount = 3,
                    };
                    effect.addToMap();
                }
                return false;
            }
        }

        if (time - self.last_hit_check > 16) {
            // todo other hit from multi projectiles
            if (self.damage_players) {
                if (findTargetPlayer(self.x, self.y, 0.33)) |player| {
                    if (player.condition.invincible or player.condition.stasis or self.hit_list.contains(player.obj_id))
                        return true;

                    if (player.condition.invulnerable) {
                        assets.playSfx(player.hit_sound);
                        return false;
                    }

                    if (map.local_player_id == player.obj_id) {
                        const pierced = self.props.armor_piercing;
                        const d = damageWithDefense(
                            @floatFromInt(self.damage),
                            @floatFromInt(player.defense),
                            pierced,
                            player.condition,
                        );
                        const dead = player.hp <= d;

                        player.takeDamage(
                            d,
                            dead,
                            pierced,
                            time,
                            self.props.effects,
                            self.colors,
                            self.angle,
                            self.props.speed,
                            false,
                            allocator,
                        );
                        network.queuePacket(.{ .player_hit = .{ .bullet_id = self.bullet_id, .object_id = self.owner_id } });
                    } else if (!self.props.multi_hit) {
                        var effect = particles.HitEffect{
                            .x = self.x,
                            .y = self.y,
                            .colors = self.colors,
                            .angle = self.angle,
                            .speed = self.props.speed,
                            .size = 1.0,
                            .amount = 3,
                        };
                        effect.addToMap();

                        network.queuePacket(.{ .other_hit = .{
                            .time = time,
                            .bullet_id = self.bullet_id,
                            .object_id = self.owner_id,
                            .target_id = player.obj_id,
                        } });
                    } else {
                        std.log.err("Unknown logic for player side of hit logic unexpected branch, todo figure out how to fix this mabye implement send_message check: {s}", .{player.name});
                    }

                    if (self.props.multi_hit) {
                        self.hit_list.put(player.obj_id, {}) catch |e| {
                            std.log.err("failed to add player to hit_list: {any}", .{e});
                        };
                    } else {
                        return false;
                    }
                }
            } else {
                if (findTargetObject(self.x, self.y, 0.33)) |object| {
                    if (object.condition.invincible or object.condition.stasis or self.hit_list.contains(object.obj_id))
                        return true;

                    if (object.condition.invulnerable) {
                        assets.playSfx(object.hit_sound);
                        return false;
                    }

                    if (object.is_enemy) {
                        const pierced = self.props.armor_piercing;
                        const d = damageWithDefense(
                            @floatFromInt(self.damage),
                            @floatFromInt(object.defense),
                            pierced,
                            object.condition,
                        );
                        const dead = object.hp <= d;

                        object.takeDamage(
                            d,
                            dead,
                            pierced,
                            time,
                            self.props.effects,
                            self.colors,
                            self.angle,
                            self.props.speed,
                            false,
                            allocator,
                        );

                        network.queuePacket(.{ .enemy_hit = .{
                            .time = time,
                            .bullet_id = self.bullet_id,
                            .target_id = object.obj_id,
                            .killed = dead,
                        } });
                    } else if (!self.props.multi_hit) {
                        var effect = particles.HitEffect{
                            .x = self.x,
                            .y = self.y,
                            .colors = self.colors,
                            .angle = self.angle,
                            .speed = self.props.speed,
                            .size = 1.0,
                            .amount = 3,
                        };
                        effect.addToMap();

                        network.queuePacket(.{ .other_hit = .{
                            .time = time,
                            .bullet_id = self.bullet_id,
                            .object_id = self.owner_id,
                            .target_id = object.obj_id,
                        } });
                    } else {
                        std.log.err("Unknown logic for object side of hit logic unexpected branch, todo figure out how to fix this mabye implement send_message check: {s}", .{object.name});
                    }

                    if (self.props.multi_hit) {
                        self.hit_list.put(object.obj_id, {}) catch |e| {
                            std.log.err("failed to add object to hit_list: {any}", .{e});
                        };
                    } else {
                        return false;
                    }
                }
            }
            self.last_hit_check = time;
        }

        return true;
    }
};

pub fn damageWithDefense(orig_damage: f32, target_defense: f32, armor_piercing: bool, condition: utils.Condition) i32 {
    var def = target_defense;
    if (armor_piercing or condition.armor_broken) {
        def = 0.0;
    } else if (condition.armored) {
        def *= 2.0;
    }

    if (condition.invulnerable or condition.invincible) {
        return 0;
    }

    const min = orig_damage * 0.25;
    return @intFromFloat(@max(min, orig_damage - def));
}

pub fn showDamageText(time: i64, damage: i32, pierced: bool, object_id: i32, allocator: std.mem.Allocator) void {
    var damage_color: u32 = 0xB02020;
    if (pierced) {
        damage_color = 0x890AFF;
    }

    const text_data = ui.TextData{
        .text = std.fmt.allocPrint(allocator, "-{d}", .{damage}) catch unreachable,
        .text_type = .bold,
        .size = 22,
        .color = damage_color,
        .backing_buffer = &[0]u8{},
    };

    ui.elements.add(.{ .status = ui.StatusText{
        .obj_id = object_id,
        .start_time = time,
        .text_data = text_data,
        .initial_size = 22,
    } }) catch |e| {
        std.log.err("Allocation for damage text \"-{d}\" failed: {any}", .{ damage, e });
    };
}

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
        .particle_effect => lhs_sort_val = 0,
        .particle => |pt| {
            switch (pt) {
                inline else => |particle| lhs_sort_val = camera.rotateAroundCamera(particle.x, particle.y).y + particle.z * -camera.px_per_tile,
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
        .particle_effect => rhs_sort_val = 0,
        .particle => |pt| {
            switch (pt) {
                inline else => |particle| rhs_sort_val = camera.rotateAroundCamera(particle.x, particle.y).y + particle.z * -camera.px_per_tile,
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
    particle: particles.Particle,
    particle_effect: particles.ParticleEffect,
};

const AtlasHashHack = [4]u32;

const day_cycle_ms: i32 = 10 * 60 * 1000; // 10 minutes
const day_cycle_ms_half: f32 = @as(f32, day_cycle_ms) / 2;

pub var object_lock: std.Thread.RwLock = .{};
pub var entities: utils.DynSlice(Entity) = undefined;
pub var entity_indices_to_remove: utils.DynSlice(usize) = undefined;
pub var atlas_to_color_data: std.AutoHashMap(AtlasHashHack, []u32) = undefined;
pub var last_tick_ms: f32 = 0.0;
pub var last_tick_time: i64 = 0;
pub var local_player_id: i32 = -1;
pub var interactive_id = std.atomic.Atomic(i32).init(-1);
pub var interactive_type = std.atomic.Atomic(game_data.ClassType).init(.game_object);
pub var name: []const u8 = "";
pub var seed: u32 = 0;
pub var width: isize = 0;
pub var height: isize = 0;
pub var squares: []Square = &[0]Square{};
pub var bg_light_color: u32 = 0;
pub var bg_light_intensity: f32 = 0.0;
pub var day_light_intensity: f32 = 0.0;
pub var night_light_intensity: f32 = 0.0;
pub var server_time_offset: i64 = 0;
pub var move_records: utils.DynSlice(network.TimedPosition) = undefined;
pub var last_records_clear_time: i64 = 0;
pub var random: utils.Random = utils.Random{};
pub var minimap: zstbi.Image = undefined;
var last_sort: i64 = -1;

pub fn init(allocator: std.mem.Allocator) !void {
    entities = try utils.DynSlice(Entity).init(16384, allocator);
    entity_indices_to_remove = try utils.DynSlice(usize).init(256, allocator);
    move_records = try utils.DynSlice(network.TimedPosition).init(10, allocator);
    atlas_to_color_data = std.AutoHashMap(AtlasHashHack, []u32).init(allocator);

    minimap = try zstbi.Image.createEmpty(4096, 4096, 4, .{});
}

pub fn disposeEntity(allocator: std.mem.Allocator, en: *map.Entity) void {
    switch (en.*) {
        .object => |obj| {
            var square = map.getSquarePtr(obj.x, obj.y);
            if (square.obj_id == obj.obj_id) {
                square.obj_id = -1;
                square.enemy_occupy_square = false;
                square.occupy_square = false;
                square.full_occupy = false;
                square.has_wall = false;
            }

            ui.removeAttachedUi(obj.obj_id, allocator);
            allocator.free(obj.name_override);
        },
        .projectile => |*projectile| {
            projectile.hit_list.deinit();
        },
        .player => |player| {
            ui.removeAttachedUi(player.obj_id, allocator);
            allocator.free(player.name_override);
            allocator.free(player.guild);
        },
        else => {},
    }
}

pub fn dispose(allocator: std.mem.Allocator) void {
    local_player_id = -1;
    interactive_id.store(-1, .Release);
    interactive_type.store(.game_object, .Release);
    width = 0;
    height = 0;
    seed = 0;

    for (entities.items()) |*en| {
        disposeEntity(allocator, en);
    }

    entities.clear();
    @memset(minimap.data, 0);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    if (squares.len > 0) {
        allocator.free(squares);
    }

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

    var colors_iter = atlas_to_color_data.valueIterator();
    while (colors_iter.next()) |colors| {
        allocator.free(colors.*);
    }

    entities.deinit();
    entity_indices_to_remove.deinit();
    move_records.deinit();
    atlas_to_color_data.deinit();
    minimap.deinit();
}

pub fn getLightIntensity(time: i64) f32 {
    if (server_time_offset == 0)
        return bg_light_intensity;

    const server_time_clamped: f32 = @floatFromInt(@mod(time + server_time_offset, day_cycle_ms));
    const intensity_delta = day_light_intensity - night_light_intensity;
    if (server_time_clamped <= day_cycle_ms_half) {
        const scale = server_time_clamped / day_cycle_ms_half;
        return night_light_intensity + intensity_delta * scale;
    } else {
        const scale = (server_time_clamped - day_cycle_ms_half) / day_cycle_ms_half;
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

    @memset(minimap.data, 0);

    const size = @max(w, h);
    const max_zoom: f32 = @floatFromInt(@divFloor(size, 32));
    camera.minimap_zoom = @max(1, @min(max_zoom, camera.minimap_zoom));
}

pub fn localPlayerConst() ?Player {
    if (map.local_player_id == -1)
        return null;

    if (findEntityConst(map.local_player_id)) |en| {
        return en.player;
    }

    return null;
}

pub fn localPlayerRef() ?*Player {
    if (map.local_player_id == -1)
        return null;

    if (findEntityRef(map.local_player_id)) |en| {
        return &en.player;
    }

    return null;
}

pub fn findEntityConst(obj_id: i32) ?Entity {
    for (entities.items()) |en| {
        switch (en) {
            .particle => |pt| {
                switch (pt) {
                    inline else => |particle| {
                        if (particle.obj_id == obj_id)
                            return en;
                    },
                }
            },
            .particle_effect => |pt_eff| {
                switch (pt_eff) {
                    inline else => |effect| {
                        if (effect.obj_id == obj_id)
                            return en;
                    },
                }
            },
            inline else => |obj| {
                if (obj.obj_id == obj_id)
                    return en;
            },
        }
    }

    return null;
}

pub fn findEntityRef(obj_id: i32) ?*Entity {
    for (entities.items()) |*en| {
        switch (en.*) {
            .particle => |*pt| {
                switch (pt.*) {
                    inline else => |*particle| {
                        if (particle.obj_id == obj_id)
                            return en;
                    },
                }
            },
            .particle_effect => |*pt_eff| {
                switch (pt_eff.*) {
                    inline else => |*effect| {
                        if (effect.obj_id == obj_id)
                            return en;
                    },
                }
            },
            inline else => |*obj| {
                if (obj.obj_id == obj_id)
                    return en;
            },
        }
    }

    return null;
}

pub fn removeEntity(obj_id: i32) ?*Entity {
    for (entities.items(), 0..) |en, i| {
        switch (en) {
            .particle => |*pt| {
                switch (pt.*) {
                    inline else => |*particle| {
                        if (particle.obj_id == obj_id)
                            return entities.removePtr(i);
                    },
                }
            },
            .particle_effect => |*pt_eff| {
                switch (pt_eff.*) {
                    inline else => |*effect| {
                        if (effect.obj_id == obj_id)
                            return entities.removePtr(i);
                    },
                }
            },
            inline else => |obj| {
                if (obj.obj_id == obj_id)
                    return entities.removePtr(i);
            },
        }
    }
    return null;
}

pub fn update(time: i64, dt: i64, allocator: std.mem.Allocator) void {
    while (!object_lock.tryLock()) {}
    defer object_lock.unlock();

    interactive_id.store(-1, .Release);
    interactive_type.store(.game_object, .Release);

    const ms_time = @divFloor(time, std.time.us_per_ms);
    const ms_dt: f32 = @as(f32, @floatFromInt(dt)) / std.time.us_per_ms;

    var cam_x: f32 = camera.x.load(.Acquire);
    var cam_y: f32 = camera.y.load(.Acquire);

    var interactive_set = false;
    for (entities.items(), 0..) |*en, i| {
        switch (en.*) {
            .player => |*player| {
                player.update(ms_time, ms_dt, allocator);
                if (player.obj_id == local_player_id) {
                    camera.update(player.x, player.y, ms_dt, input.rotate);
                    if (input.attacking) {
                        const y: f32 = @floatCast(input.mouse_y);
                        const x: f32 = @floatCast(input.mouse_x);
                        const shoot_angle = std.math.atan2(f32, y - camera.screen_height / 2.0, x - camera.screen_width / 2.0) + camera.angle;
                        player.weaponShoot(shoot_angle, time);
                    }
                }
            },
            .object => |*object| {
                const is_container = object.class == .container;
                if (!interactive_set and (object.class == .portal or is_container)) {
                    const dt_x = cam_x - object.x;
                    const dt_y = cam_y - object.y;
                    if (dt_x * dt_x + dt_y * dt_y < 1) {
                        interactive_id.store(object.obj_id, .Release);
                        interactive_type.store(object.class, .Release);

                        if (is_container) {
                            if (ui.in_game_screen.container_id != object.obj_id) {
                                inline for (0..8) |idx| {
                                    ui.in_game_screen.setContainerItem(object.inventory[idx], idx);
                                }
                            }

                            ui.in_game_screen.container_id = object.obj_id;
                            ui.in_game_screen.setContainerVisible(true);
                        }

                        interactive_set = true;
                    }
                }

                object.update(ms_time, ms_dt);
            },
            .projectile => |*projectile| {
                if (!projectile.update(ms_time, ms_dt, allocator))
                    entity_indices_to_remove.add(i) catch |e| {
                        std.log.err("Out of memory: {any}", .{e});
                    };
            },
            .particle => |*pt| {
                switch (pt.*) {
                    inline else => |*particle| {
                        if (!particle.update(ms_time, ms_dt))
                            entity_indices_to_remove.add(i) catch |e| {
                                std.log.err("Out of memory: {any}", .{e});
                            };
                    },
                }
            },
            .particle_effect => |*pt_eff| {
                switch (pt_eff.*) {
                    inline else => |*effect| {
                        if (!effect.update(ms_time, ms_dt))
                            entity_indices_to_remove.add(i) catch |e| {
                                std.log.err("Out of memory: {any}", .{e});
                            };
                    },
                }
            },
        }
    }

    if (!interactive_set) {
        if (ui.in_game_screen.container_id != -1) {
            inline for (0..8) |idx| {
                ui.in_game_screen.setContainerItem(-1, idx);
            }
        }

        ui.in_game_screen.container_id = -1;
        ui.in_game_screen.setContainerVisible(false);
    }

    std.mem.reverse(usize, entity_indices_to_remove.items());

    for (entity_indices_to_remove.items()) |idx| {
        disposeEntity(allocator, entities.removePtr(idx));
    }

    entity_indices_to_remove.clear();

    std.sort.pdq(Entity, entities.items(), {}, lessThan);
}

pub inline fn validPos(x: isize, y: isize) bool {
    return !(x < 0 or x >= width or y < 0 or y >= height);
}

pub inline fn getSquare(x: f32, y: f32) Square {
    const floor_x: u32 = @intFromFloat(@floor(x));
    const floor_y: u32 = @intFromFloat(@floor(y));
    return squares[floor_y * @as(u32, @intCast(width)) + floor_x];
}

pub inline fn getSquarePtr(x: f32, y: f32) *Square {
    const floor_x: u32 = @intFromFloat(@floor(x));
    const floor_y: u32 = @intFromFloat(@floor(y));
    return &squares[floor_y * @as(u32, @intCast(width)) + floor_x];
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

            if (assets.dominant_color_data.get(tex.sheet)) |color_data| {
                const color = color_data[tex.index];
                const base_data_idx: usize = @intCast(y * minimap.num_components * minimap.width + x * minimap.num_components);
                minimap.data[base_data_idx] = color.r;
                minimap.data[base_data_idx + 1] = color.g;
                minimap.data[base_data_idx + 2] = color.b;
                minimap.data[base_data_idx + 3] = color.a;

                const ux: u32 = @intCast(x);
                const uy: u32 = @intCast(y);

                main.minimap_update_min_x = @min(main.minimap_update_min_x, ux);
                main.minimap_update_max_x = @max(main.minimap_update_max_x, ux);
                main.minimap_update_min_y = @min(main.minimap_update_min_y, uy);
                main.minimap_update_max_y = @max(main.minimap_update_max_y, uy);
            }

            square.updateBlends();
        }
    }

    if (game_data.ground_type_to_props.getPtr(tile_type)) |props| {
        square.props = props;
        if (props.random_offset) {
            const u_offset: f32 = @floatFromInt(utils.rng.next() % 8);
            const v_offset: f32 = @floatFromInt(utils.rng.next() % 8);
            square.u_offset = u_offset * assets.base_texel_w;
            square.v_offset = v_offset * assets.base_texel_h;
        }
        square.u_offset += props.x_offset * 10.0 * assets.base_texel_w;
        square.v_offset += props.y_offset * 10.0 * assets.base_texel_h;
    }

    squares[idx] = square;
}

pub fn addMoveRecord(time: i64, x: f32, y: f32) void {
    if (last_records_clear_time < 0) {
        return;
    }

    const id = getId(time);
    if (id < 1 or id > 10) {
        return;
    }

    if (move_records.capacity == 0) {
        move_records.add(.{ .time = time, .x = x, .y = y });
        return;
    }

    const curr_record = move_records.items()[move_records.capacity - 1];
    const curr_id = getId(curr_record.time);
    if (id != curr_id) {
        move_records.add(.{ .time = time, .x = x, .y = y });
        return;
    }

    const score = getScore(id, time);
    const curr_score = getScore(id, curr_record.time);
    if (score < curr_score) {
        curr_record.time = time;
        curr_record.x = x;
        curr_record.y = y;
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
