const Allocator = @import("std").mem.Allocator;

pub const MapEditorScreen = struct {
    _allocator: Allocator,
    inited: bool = false,

    pub fn init(allocator: Allocator) !*MapEditorScreen {
        var screen = try allocator.create(MapEditorScreen);
        screen.* = .{ ._allocator = allocator };
        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *MapEditorScreen) void {
        self._allocator.destroy(self);
    }

    pub fn resize(_: *MapEditorScreen, _: f32, _: f32) void {}
    pub fn update(_: *MapEditorScreen, _: i64, _: f32) !void {}
};
