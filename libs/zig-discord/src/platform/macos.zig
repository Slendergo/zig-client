const std = @import("std");
const c = @cImport({
    @cInclude("sys/ioctl.h");
});

pub extern "c" fn getpid() std.os.pid_t;

pub const Stream = std.net.Stream;

pub fn peek(stream: Stream) !bool {
    var bytes_available: i32 = undefined;
    const ret: std.os.darwin.E = @enumFromInt(std.c.ioctl(stream.handle, c.FIONREAD, &bytes_available));
    switch (ret) {
        .BADF => return error.BadFileDescriptor,
        .FAULT => unreachable,
        .INVAL => return error.InvalidRequest,
        .NOTTY => unreachable,
        .SUCCESS => {},
        else => unreachable,
    }

    return bytes_available != 0;
}
