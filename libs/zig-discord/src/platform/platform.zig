const std = @import("std");
const builtin = @import("builtin");

const impl = switch (builtin.os.tag) {
    .macos => @import("macos.zig"),
    .linux => @import("linux.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("platform not implemented"),
};

pub const Stream = impl.Stream;

pub fn getpid() std.os.pid_t {
    return impl.getpid();
}

pub fn peek(stream: Stream) !bool {
    return impl.peek(stream);
}
