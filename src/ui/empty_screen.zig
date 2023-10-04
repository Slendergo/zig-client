const Allocator = @import("std").mem.Allocator;

pub const EmptyScreen = struct {
    _allocator: Allocator,
    inited: bool = false,

    pub fn init(allocator: Allocator) !*EmptyScreen {
        var screen = try allocator.create(EmptyScreen);
        screen.* = .{
            ._allocator = allocator,
        };

        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *EmptyScreen) void {
        self._allocator.destroy(self);
    }

    pub fn resize(_: *EmptyScreen, _: f32, _: f32) void {}
    pub fn update(_: *EmptyScreen, _: i64, _: f32) !void {}
};
