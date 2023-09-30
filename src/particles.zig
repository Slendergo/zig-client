const std = @import("std");
const assets = @import("assets.zig");
const utils = @import("utils.zig");
const map = @import("map.zig");

pub const ThrowParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    initial_size: f32,
    lifetime: f32,
    time_left: f32,
    dx: f32,
    dy: f32,

    _last_update: i64 = 0,

    pub fn addToMap(self: *ThrowParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .throw = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *ThrowParticle, time: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.z = @sin(self.time_left / self.lifetime * std.math.pi) * 2;
        self.x += self.dx * dt;
        self.y += self.dy * dt;

        if (time - self._last_update >= 16) {
            const duration: f32 = 400.0;
            var particle = SparkParticle{
                .size = @floor(self.z + 1),
                .initial_size = @floor(self.z + 1),
                .color = self.color,
                .lifetime = duration,
                .time_left = duration,
                .dx = utils.plusMinus(1),
                .dy = utils.plusMinus(1),
                .x = self.x,
                .y = self.y,
                .z = self.z,
            };
            particle.addToMap();

            self._last_update = time;
        }
        return true;
    }
};

pub const SparkerParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    initial_size: f32,
    lifetime: f32,
    time_left: f32,
    dx: f32,
    dy: f32,

    _last_update: i64 = 0,

    pub fn addToMap(self: *SparkerParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .sparker = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *SparkerParticle, time: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.x += self.dx * dt;
        self.y += self.dy * dt;

        if (time - self._last_update >= 16) {
            const duration: f32 = 600.0;
            var particle = SparkParticle{
                .size = 0.5,
                .initial_size = 0.5,
                .color = self.color,
                .lifetime = duration,
                .time_left = duration,
                .dx = utils.plusMinus(1),
                .dy = utils.plusMinus(1),
                .x = self.x,
                .y = self.y,
                .z = self.z,
            };
            particle.addToMap();

            self._last_update = time;
        }

        return true;
    }
};

pub const SparkParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    initial_size: f32,
    lifetime: f32,
    time_left: f32,
    dx: f32,
    dy: f32,

    pub fn addToMap(self: *SparkParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .spark = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *SparkParticle, _: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.x += self.dx * (dt / 1000.0);
        self.y += self.dy * (dt / 1000.0);
        self.size = self.time_left / self.lifetime * self.initial_size;
        return true;
    }
};

pub const TeleportParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    time_left: f32,
    z_dir: f32,

    pub fn addToMap(self: *TeleportParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .teleport = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *TeleportParticle, _: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.z += self.z_dir * dt * 0.008;
        return true;
    }
};

pub const ExplosionParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    lifetime: f32,
    time_left: f32,
    x_dir: f32,
    y_dir: f32,
    z_dir: f32,

    pub fn addToMap(self: *ExplosionParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .explosion = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *ExplosionParticle, _: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.x += self.x_dir * dt * 0.008;
        self.y += self.y_dir * dt * 0.008;
        self.z += self.z_dir * dt * 0.008;
        return true;
    }
};

pub const HitParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    lifetime: f32,
    time_left: f32,
    x_dir: f32,
    y_dir: f32,
    z_dir: f32,

    pub fn addToMap(self: *HitParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .hit = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *HitParticle, _: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        self.x += self.x_dir * dt * 0.008;
        self.y += self.y_dir * dt * 0.008;
        self.z += self.z_dir * dt * 0.008;
        return true;
    }
};

pub const HealParticle = struct {
    obj_id: i32 = 0,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    color: u32 = 0,
    size: f32 = 1.0,
    alpha_mult: f32 = 1.0,
    atlas_data: assets.AtlasData = assets.AtlasData.fromRaw(0, 0, 0, 0),

    target_id: i32,
    angle: f32,
    dist: f32,
    time_left: f32,
    z_dir: f32,

    pub fn addToMap(self: *HealParticle) void {
        self.obj_id = Particle.getNextObjId();
        Particle.setTexture(&self.atlas_data, 0);

        map.entities.add(.{ .particle = .{ .heal = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *HealParticle, _: i64, dt: f32) bool {
        self.time_left -= dt;
        if (self.time_left <= 0)
            return false;

        if (map.findEntityConst(self.target_id)) |en| {
            switch (en) {
                .particle_effect, .particle, .projectile => {},
                inline else => |entity| {
                    self.x = entity.x + self.dist * @cos(self.angle);
                    self.y = entity.y + self.dist * @sin(self.angle);
                    self.z += self.z_dir * dt * 0.008;
                    return true;
                },
            }
        }

        return false;
    }
};

pub const Particle = union(enum) {
    const obj_id_max = 0x7F000000;
    const obj_id_base = 0x7E000000;
    var next_obj_id: i32 = obj_id_base;

    throw: ThrowParticle,
    spark: SparkParticle,
    sparker: SparkerParticle,
    teleport: TeleportParticle,
    explosion: ExplosionParticle,
    hit: HitParticle,
    heal: HealParticle,

    pub inline fn getNextObjId() i32 {
        const obj_id = next_obj_id + 1;
        next_obj_id += 1;
        if (next_obj_id == obj_id_max)
            next_obj_id = obj_id_base;
        return obj_id;
    }

    pub inline fn setTexture(atlas_data: *assets.AtlasData, id: u32) void {
        if (assets.atlas_data.get("particles")) |data| {
            atlas_data.* = data[id];
        } else {
            std.log.err("Could not find sheet for particle. Using error texture", .{});
            atlas_data.* = assets.error_data;
        }
    }
};

pub const ThrowEffect = struct {
    obj_id: i32 = 0,
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    color: u32,
    duration: i64,

    pub fn addToMap(self: *ThrowEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .throw = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *ThrowEffect, _: i64, _: f32) bool {
        const duration: f32 = @floatFromInt(if (self.duration == 0) 1500 else self.duration);
        var particle = ThrowParticle{
            .size = 2.0,
            .initial_size = 2.0,
            .color = self.color,
            .lifetime = duration,
            .time_left = duration,
            .dx = (self.end_x - self.start_x) / duration,
            .dy = (self.end_y - self.start_y) / duration,
            .x = self.start_x,
            .y = self.start_y,
        };
        particle.addToMap();

        return false;
    }
};

pub const AoeEffect = struct {
    obj_id: i32 = 0,
    x: f32,
    y: f32,
    radius: f32,
    color: u32,

    pub fn addToMap(self: *AoeEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .aoe = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *AoeEffect, _: i64, _: f32) bool {
        const part_num = 4 + self.radius * 2;
        for (0..@intFromFloat(part_num)) |i| {
            const float_i: f32 = @floatFromInt(i);
            const angle = (float_i * 2.0 * std.math.pi) / part_num;
            const end_x = self.x + self.radius * @cos(angle);
            const end_y = self.y + self.radius * @sin(angle);
            const duration = 200.0;
            var particle = SparkerParticle{
                .size = 0.4,
                .initial_size = 0.4,
                .color = self.color,
                .lifetime = duration,
                .time_left = duration,
                .dx = (end_x - self.x) / duration,
                .dy = (end_y - self.y) / duration,
                .x = self.x,
                .y = self.y,
            };
            particle.addToMap();
        }

        return false;
    }
};

pub const TeleportEffect = struct {
    obj_id: i32 = 0,
    x: f32,
    y: f32,

    pub fn addToMap(self: *TeleportEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .teleport = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *TeleportEffect, _: i64, _: f32) bool {
        for (0..20) |_| {
            const rand = utils.rng.random().float(f32);
            const angle = 2.0 * std.math.pi * rand;
            const radius = 0.7 * rand;

            var particle = TeleportParticle{
                .size = 0.8,
                .color = 0x0000FF,
                .time_left = 500 + 1000 * rand,
                .z_dir = 0.1,
                .x = self.x + radius * @cos(angle),
                .y = self.y + radius * @sin(angle),
            };
            particle.addToMap();
        }

        return false;
    }
};

pub const LineEffect = struct {
    obj_id: i32 = 0,
    start_x: f32,
    start_y: f32,
    end_x: f32,
    end_y: f32,
    color: u32,

    pub fn addToMap(self: *LineEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .line = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *LineEffect, _: i64, _: f32) bool {
        const duration = 700.0;
        for (0..30) |i| {
            const f = @as(f32, @floatFromInt(i)) / 30;
            var particle = SparkParticle{
                .size = 1.0,
                .initial_size = 1.0,
                .color = self.color,
                .lifetime = duration,
                .time_left = duration,
                .dx = (self.end_x - self.start_x) / duration,
                .dy = (self.end_y - self.start_y) / duration,
                .x = self.end_x + f * (self.start_x - self.end_x),
                .y = self.end_y + f * (self.start_y - self.end_y),
                .z = 0.5,
            };
            particle.addToMap();
        }

        return false;
    }
};

pub const ExplosionEffect = struct {
    obj_id: i32 = 0,
    x: f32,
    y: f32,
    colors: []u32,
    size: f32,
    amount: u32,

    pub fn addToMap(self: *ExplosionEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .explosion = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *ExplosionEffect, _: i64, _: f32) bool {
        if (self.colors.len == 0)
            return false;

        for (0..self.amount) |_| {
            const duration = 200.0 + utils.rng.random().float(f32) * 100.0;
            var particle = ExplosionParticle{
                .size = self.size,
                .color = self.colors[utils.rng.next() % self.colors.len],
                .lifetime = duration,
                .time_left = duration,
                .x_dir = utils.rng.random().float(f32) - 0.5,
                .y_dir = utils.rng.random().float(f32) - 0.5,
                .z_dir = 0,
                .x = self.x,
                .y = self.y,
                .z = 0.5,
            };
            particle.addToMap();
        }

        return false;
    }
};

pub const HitEffect = struct {
    obj_id: i32 = 0,
    x: f32,
    y: f32,
    colors: []u32,
    size: f32,
    angle: f32,
    speed: f32,
    amount: u32,

    pub fn addToMap(self: *HitEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .hit = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *HitEffect, _: i64, _: f32) bool {
        if (self.colors.len == 0)
            return false;

        const cos = self.speed / 600.0 * -@cos(self.angle);
        const sin = self.speed / 600.0 * -@sin(self.angle);

        for (0..self.amount) |_| {
            const duration = 200.0 + utils.rng.random().float(f32) * 100.0;
            var particle = HitParticle{
                .size = self.size,
                .color = self.colors[utils.rng.next() % self.colors.len],
                .lifetime = duration,
                .time_left = duration,
                .x_dir = cos + (utils.rng.random().float(f32) - 0.5) * 0.4,
                .y_dir = sin + (utils.rng.random().float(f32) - 0.5) * 0.4,
                .z_dir = 0,
                .x = self.x,
                .y = self.y,
                .z = 0.5,
            };
            particle.addToMap();
        }

        return false;
    }
};

pub const HealEffect = struct {
    obj_id: i32 = 0,
    target_id: i32,
    color: u32,

    pub fn addToMap(self: *HealEffect) void {
        self.obj_id = ParticleEffect.getNextObjId();
        map.entities.add(.{ .particle_effect = .{ .heal = self.* } }) catch |e| {
            std.log.err("Out of memory: {any}", .{e});
        };
    }

    pub fn update(self: *HealEffect, _: i64, _: f32) bool {
        if (map.findEntityConst(self.target_id)) |en| {
            switch (en) {
                .particle_effect, .particle, .projectile => {},
                inline else => |entity| {
                    for (0..10) |i| {
                        const float_i: f32 = @floatFromInt(i);
                        const angle = std.math.tau * (float_i / 10.0);
                        const radius = 0.3 + 0.4 * utils.rng.random().float(f32);
                        var particle = HealParticle{
                            .size = 0.5 + utils.rng.random().float(f32),
                            .color = self.color,
                            .time_left = 1000.0,
                            .angle = angle,
                            .dist = radius,
                            .target_id = entity.obj_id,
                            .z_dir = 0.1 + utils.rng.random().float(f32) * 0.1,
                            .x = entity.x + radius * @cos(angle),
                            .y = entity.y + radius * @sin(angle),
                            .z = utils.rng.random().float(f32) * 0.3,
                        };
                        particle.addToMap();
                    }

                    return false;
                },
            }
        }

        std.log.err("Target with id {d} not found for HealEffect", .{self.target_id});
        return false;
    }
};

pub const ParticleEffect = union(enum) {
    const obj_id_max = 0x7E000000;
    const obj_id_base = 0x7D000000;
    var next_obj_id: i32 = obj_id_base;

    throw: ThrowEffect,
    aoe: AoeEffect,
    teleport: TeleportEffect,
    line: LineEffect,
    explosion: ExplosionEffect,
    hit: HitEffect,
    heal: HealEffect,

    pub inline fn getNextObjId() i32 {
        const obj_id = next_obj_id + 1;
        next_obj_id += 1;
        if (next_obj_id == obj_id_max)
            next_obj_id = obj_id_base;
        return obj_id;
    }
};
