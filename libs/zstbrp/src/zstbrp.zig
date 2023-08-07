pub const PackRect = extern struct {
    id: u32,
    w: u32,
    h: u32,
    x: u32,
    y: u32,
    was_packed: u8,
};

pub const PackNode = extern struct {
    x: u32,
    y: u32,
    next: ?*PackNode,
};

pub const PackContext = extern struct {
    width: u32,
    height: u32,
    pack_align: u8,
    init_mode: u8,
    heuristic: u8,
    num_nodes: u32,
    active_head: ?*PackNode,
    free_head: ?*PackNode,
    extra: [2]PackNode,
};

pub fn initPack(ctx: *PackContext, nodes: []PackNode) void {
    stbrp_init_target(ctx, @intCast(ctx.width), @intCast(ctx.height), nodes.ptr, @intCast(nodes.len));
}
extern fn stbrp_init_target(context: *PackContext, width: c_int, height: c_int, nodes: [*c]PackNode, num_nodes: c_int) void;

pub fn allowPackOutOfMem(ctx: *PackContext, allow: bool) void {
    stbrp_setup_allow_out_of_mem(ctx, @bitCast(allow));
}
extern fn stbrp_setup_allow_out_of_mem(context: *PackContext, allow_out_of_mem: c_int) void;

pub fn setupPackHeuristic(ctx: *PackContext, heuristic: u8) void {
    stbrp_setup_heuristic(ctx, @intCast(heuristic));
}
extern fn stbrp_setup_heuristic(context: *PackContext, heuristic: c_int) void;

pub fn packRects(ctx: *PackContext, rects: []PackRect) bool {
    return stbrp_pack_rects(ctx, rects.ptr, @intCast(rects.len)) == 1;
}
extern fn stbrp_pack_rects(context: *PackContext, rects: [*c]PackRect, num_rects: c_int) c_int;
