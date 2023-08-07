const std = @import("std");
const main = @import("main.zig");
const builtin = @import("builtin");

pub var rng = std.rand.DefaultPrng.init(0x99999999);

pub fn strlen(str: []const u8) usize {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    return i;
}

pub fn halfBound(angle: f32) f32 {
    var new_angle = angle;
    new_angle = @mod(new_angle, std.math.tau);
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
    buffer: [65535]u8 = undefined,

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
