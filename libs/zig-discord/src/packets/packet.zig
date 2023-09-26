const std = @import("std");

const Rpc = @import("../rpc.zig");

pub fn Packet(comptime op: Opcode, comptime DataType: type) type {
    return struct {
        const Self = @This();

        data: DataType,

        pub fn serialize(self: Self, writer: Rpc.Writer) !void {
            const stringify_options = std.json.StringifyOptions{
                .emit_null_optional_fields = false,
            };

            var counter = std.io.countingWriter(std.io.null_writer);
            try std.json.stringify(self.data, stringify_options, counter.writer());
            const size: u32 = @intCast(counter.bytes_written);

            try writer.writeIntLittle(u32, @intFromEnum(op));
            try writer.writeIntLittle(u32, size);
            try std.json.stringify(self.data, stringify_options, writer);
        }
    };
}

pub const Opcode = enum(u32) {
    ///Initial handshake
    handshake = 0,
    ///Generic message frame
    frame = 1,
    ///Discord has closed the connection
    close = 2,
    ///Ping, unused
    ping = 3,
    ///Pong, unused
    pong = 4,
};

pub const Command = enum {
    DISPATCH,
    SET_ACTIVITY,
    SUBSCRIBE,
    UNSUBSCRIBE,
    SEND_ACTIVITY_JOIN_INVITE,
    CLOSE_ACTIVITY_JOIN_REQUEST,
};

pub const ServerEvent = enum {
    READY,
    ERROR,
    ACTIVITY_JOIN,
    ACTIVITY_SPECTATE,
    ACTIVITY_JOIN_REQUEST,
};

pub const PacketData = ServerPacket(?struct {});

pub fn ServerPacket(comptime DataType: type) type {
    return struct {
        cmd: Command,
        evt: ?ServerEvent,
        nonce: ?[]const u8 = null,
        data: DataType,
    };
}

pub fn ArrayString(comptime len: comptime_int) type {
    return struct {
        const Self = @This();

        buf: [len]u8,
        len: usize,

        pub fn slice(self: *const Self) []const u8 {
            return self.buf[0..self.len];
        }

        pub fn jsonStringify(self: *const Self, jw: anytype) !void {
            try jw.write(self.slice());
        }

        pub fn create(str: []const u8) Self {
            var self = Self{
                .buf = undefined,
                .len = str.len,
            };
            @memcpy(self.buf[0..self.len], str);

            return self;
        }

        pub fn createFromFormat(comptime fmt: []const u8, args: anytype) !Self {
            var self: Self = undefined;

            var buf = std.io.fixedBufferStream(&self.buf);
            try std.fmt.format(buf.writer(), fmt, args);
            self.len = buf.pos;

            return self;
        }
    };
}

pub const Handshake = Packet(.handshake, struct {
    v: i32,
    nonce: []const u8,
    client_id: []const u8,
});

pub const PresencePacket = Packet(.frame, struct {
    cmd: Command,
    nonce: []const u8,
    args: PresenceCommand,
});

pub const ReadyEventData = struct {
    v: i32,
    config: Configuration,
    user: User,
};

pub const PresenceCommand = struct {
    pid: i32,
    activity: Presence,
};

pub const Configuration = struct {
    api_endpoint: []const u8,
    cdn_host: []const u8,
    environment: []const u8,
};

pub const User = struct {
    pub const AvatarFormat = enum {
        PNG,
        JPEG,
        WebP,
        GIF,
    };

    pub const AvatarSize = enum(i32) {
        x16 = 16,
        x32 = 32,
        x64 = 64,
        x128 = 128,
        x256 = 256,
        x512 = 512,
        x1024 = 1024,
        x2048 = 2048,
    };

    pub const Flags = i32;

    pub const PremiumType = enum(i32) {
        none = 0,
        nitro_classic = 1,
        nitro = 2,

        pub fn jsonStringify(self: *const PremiumType, jw: anytype) !void {
            try jw.write(@as(i32, @intFromEnum(self.*)));
        }
    };

    id: u64 = 0,
    username: []const u8 = "",
    discriminator: u16 = 0,
    global_name: []const u8 = "",
    avatar: []const u8 = "",
    flags: Flags = 0,
    premium_type: PremiumType = .none,
};

pub const Presence = struct {
    pub const Button = struct {
        label: ArrayString(128),
        url: ArrayString(256),
    };

    //all in unix epoch
    pub const Timestamps = struct {
        start: ?u64,
        end: ?u64,
    };

    pub const Assets = struct {
        large_image: ?ArrayString(256),
        large_text: ?ArrayString(128),
        small_image: ?ArrayString(256),
        small_text: ?ArrayString(128),
    };

    pub const Party = struct {
        pub const Privacy = enum(i32) {
            private = 0,
            public = 1,

            pub fn jsonStringify(self: *const Privacy, jw: anytype) !void {
                try jw.write(@as(i32, @intFromEnum(self.*)));
            }
        };

        id: ArrayString(128),
        privacy: Privacy,
        ///Element 0 is size, element 1 is max
        size: []const i32,
    };

    pub const Secrets = struct {
        join: ArrayString(128),
        spectate: ArrayString(128),
    };

    buttons: ?[]const Button,
    state: ArrayString(128),
    details: ArrayString(128),
    timestamps: Timestamps,
    assets: Assets,
    party: ?Party,
    secrets: ?Secrets,
};
