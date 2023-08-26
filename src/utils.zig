const std = @import("std");
const main = @import("main.zig");
const builtin = @import("builtin");

pub fn DynSlice(comptime T: type) type {
    return struct {
        const Self = @This();
        const scale_factor = 2;

        capacity: usize,
        _items: []T,
        _allocator: std.mem.Allocator,

        pub fn init(comptime default_capacity: usize, allocator: std.mem.Allocator) !Self {
            return Self{
                .capacity = 0,
                ._items = try allocator.alloc(T, @max(1, default_capacity)), // have to alloc at least 1, otherwise we can't scale off of len
                ._allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            if (@sizeOf(T) > 0) {
                self._allocator.free(self._items);
            }
        }

        pub inline fn clear(self: *Self) void {
            self.capacity = 0;
        }

        pub inline fn isFull(self: Self) bool {
            return self.capacity >= self._items.len;
        }

        pub inline fn items(self: Self) []T {
            return self._items[0..self.capacity];
        }

        pub inline fn add(self: *Self, item: T) !void {
            if (self.isFull()) {
                self._items = try self._allocator.realloc(self._items, self.capacity * scale_factor);
            }

            self._items[self.capacity] = item;
            self.capacity += 1;
        }

        pub inline fn remove(self: *Self, idx: usize) T {
            self.capacity -= 1;

            const old = self._items[idx];
            self._items[idx] = self._items[self.capacity];
            return old;
        }
    };
}

pub const Point = struct {
    x: f32,
    y: f32,
};

pub const Random = struct {
    seed: u32 = 1,

    pub fn init(seed: u32) Random {
        return Random{ .seed = seed };
    }

    pub fn nextIntRange(self: *Random, min: u32, max: u32) u32 {
        if (min == max)
            return min;
        return min + (self.gen() % (max - min));
    }

    fn gen(self: *Random) u32 {
        var lo: u32 = 16807 * (self.seed & 0xFFFF);
        var hi: u32 = 16807 * (self.seed >> 16);

        lo += (hi & 0x7FFF) << 16;
        lo += hi >> 15;

        if (lo > 0x7FFFFFFF)
            lo -= 0x7FFFFFFF;

        self.seed = lo;
        return lo;
    }
};

pub var rng = std.rand.DefaultPrng.init(0x99999999);

pub inline fn isInBounds(x: f32, y: f32, bound_x: f32, bound_y: f32, bound_w: f32, bound_h: f32) bool {
    return x >= bound_x and x <= bound_x + bound_w and y <= bound_y and y >= bound_y - bound_h;
}

pub fn strlen(str: []const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

pub fn halfBound(angle: f32) f32 {
    var new_angle = @mod(angle, std.math.tau);
    new_angle = @mod(new_angle + std.math.tau, std.math.tau);
    if (new_angle > std.math.pi)
        new_angle -= std.math.tau;
    return new_angle;
}

pub inline fn distSqr(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    const x_dt = x2 - x1;
    const y_dt = y2 - y1;
    return x_dt * x_dt + y_dt * y_dt;
}

pub inline fn dist(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    return @sqrt(distSqr(x1, y1, x2, y2));
}

pub const PacketWriter = struct {
    index: u16 = 0,
    length_index: u16 = 0,
    buffer: [65535]u8 = undefined,

    pub fn writeLength(self: *PacketWriter) void {
        self.length_index = self.index;
        self.index += 2;
    }

    pub fn updateLength(self: *PacketWriter) void {
        const buf = self.buffer[self.length_index .. self.length_index + 2];
        const len = self.index - self.length_index;
        switch (builtin.cpu.arch.endian()) {
            .Little => {
                @memcpy(buf, std.mem.asBytes(&len));
            },
            .Big => {
                var len_buf = std.mem.toBytes(len);
                std.mem.reverse(u8, len_buf[0..2]);
                @memcpy(buf, len_buf[0..2]);
            },
        }
    }

    pub fn write(self: *PacketWriter, value: anytype) void {
        const T = @TypeOf(value);
        const type_info = @typeInfo(T);

        if (type_info == .Pointer and (type_info.Pointer.size == .Slice or type_info.Pointer.size == .Many)) {
            self.writeArray(value);
            return;
        }

        if (type_info == .Array) {
            self.writeArray(value);
            return;
        }

        if (type_info == .Struct) {
            comptime std.debug.assert(type_info.Struct.layout != .Auto);
        }

        const byte_size = (@bitSizeOf(T) + 7) / 8;
        const buf = self.buffer[self.index .. self.index + byte_size];
        self.index += byte_size;

        switch (builtin.cpu.arch.endian()) {
            .Little => {
                @memcpy(buf, std.mem.asBytes(&value));
            },
            .Big => {
                var val_buf = std.mem.toBytes(value);
                std.mem.reverse(u8, val_buf[0..byte_size]);
                @memcpy(buf, val_buf[0..byte_size]);
            },
        }
    }

    inline fn writeArray(self: *PacketWriter, value: anytype) void {
        self.write(@as(u16, @intCast(value.len)));
        for (value) |val|
            self.write(val);
    }
};

pub const PacketReader = struct {
    index: u16 = 0,
    buffer: [65535]u8 = undefined,

    pub fn read(self: *PacketReader, comptime T: type) T {
        const type_info = @typeInfo(T);
        if (type_info == .Pointer and (type_info.Pointer.size == .Slice or type_info.Pointer.size == .Many)) {
            return self.readArray(type_info.Pointer.child);
        }

        if (type_info == .Array) {
            return self.readArray(type_info.Array.child);
        }

        if (type_info == .Struct) {
            comptime std.debug.assert(type_info.Struct.layout != .Auto);
        }

        const byte_size = (@bitSizeOf(T) + 7) / 8;
        var buf = self.buffer[self.index .. self.index + byte_size];
        self.index += byte_size;

        switch (builtin.cpu.arch.endian()) {
            .Little => return std.mem.bytesToValue(T, buf[0..byte_size]),
            .Big => {
                std.mem.reverse(u8, buf[0..byte_size]);
                return std.mem.bytesToValue(T, buf[0..byte_size]);
            },
        }
    }

    inline fn readArray(self: *PacketReader, comptime T: type) []T {
        const len = self.read(u16);
        const buf = main.stack_allocator.alloc(T, len) catch unreachable;
        for (0..len) |i| {
            buf[i] = self.read(T);
        }
        return buf;
    }
};
