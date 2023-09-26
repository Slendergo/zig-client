const std = @import("std");

const c = @cImport(@cInclude("windows.h"));

pub const Stream = std.fs.File;

pub fn getpid() std.os.pid_t {
    return @ptrFromInt(c.GetCurrentProcessId());
}

pub fn peek(stream: Stream) bool {
    var bytes_available: std.os.windows.DWORD = undefined;
    std.debug.assert(c.PeekNamedPipe(
        stream.handle,
        null,
        0,
        null,
        &bytes_available,
        null,
    ) != 0);
    return bytes_available != 0;
}
