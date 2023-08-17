const xml = @import("xml.zig");
const zstbi = @import("zstbi");
const zstbrp = @import("zstbrp");
const asset_dir = @import("build_options").asset_dir;
const std = @import("std");
const game_data = @import("game_data.zig");
const settings = @import("settings.zig");
const builtin = @import("builtin");

pub const padding = 2;

pub const atlas_width: u32 = 4096;
pub const atlas_height: u32 = 4096;
pub const base_texel_w: f32 = 1.0 / 4096.0;
pub const base_texel_h: f32 = 1.0 / 4096.0;

pub const right_dir: u8 = 0;
pub const left_dir: u8 = 1;
pub const down_dir: u8 = 2;
pub const up_dir: u8 = 3;

pub const CharacterData = struct {
    pub const char_atlas_w = 1024;
    pub const char_atlas_h = 512;
    pub const char_size = 64.0;
    pub const line_height = 1.149;

    x_advance: f32,
    tex_u: f32,
    tex_v: f32,
    tex_w: f32,
    tex_h: f32,
    x_offset: f32,
    y_offset: f32,
    width: f32,
    height: f32,

    pub fn parse(split: *std.mem.SplitIterator(u8, .sequence)) !CharacterData {
        var data = CharacterData{
            .x_advance = try std.fmt.parseFloat(f32, split.next().?) * char_size,
            .x_offset = try std.fmt.parseFloat(f32, split.next().?) * char_size,
            .y_offset = try std.fmt.parseFloat(f32, split.next().?) * char_size,
            .width = try std.fmt.parseFloat(f32, split.next().?) * char_size,
            .height = try std.fmt.parseFloat(f32, split.next().?) * char_size,
            .tex_u = try std.fmt.parseFloat(f32, split.next().?) / char_atlas_w,
            .tex_h = (char_atlas_h - try std.fmt.parseFloat(f32, split.next().?)) / char_atlas_h,
            .tex_w = try std.fmt.parseFloat(f32, split.next().?) / char_atlas_w,
            .tex_v = (char_atlas_h - try std.fmt.parseFloat(f32, split.next().?)) / char_atlas_h,
        };
        data.width -= data.x_offset;
        data.height -= data.y_offset;
        data.tex_h -= data.tex_v;
        data.tex_w -= data.tex_u;
        return data;
    }
};

pub const AnimEnemyData = struct {
    // left/right dir
    walk_anims: [2][3]zstbrp.PackRect,
    attack_anims: [2][2]zstbrp.PackRect,
};

pub const AnimPlayerData = struct {
    // all dirs
    walk_anims: [4][3]zstbrp.PackRect,
    attack_anims: [4][2]zstbrp.PackRect,
};

pub const FloatRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub var atlas: zstbi.Image = undefined;
pub var light_tex: zstbi.Image = undefined;

pub var bold_atlas: zstbi.Image = undefined;
pub var bold_chars: [256]CharacterData = undefined;
pub var bold_italic_atlas: zstbi.Image = undefined;
pub var bold_italic_chars: [256]CharacterData = undefined;
pub var medium_atlas: zstbi.Image = undefined;
pub var medium_chars: [256]CharacterData = undefined;
pub var medium_italic_atlas: zstbi.Image = undefined;
pub var medium_italic_chars: [256]CharacterData = undefined;

pub var rects: std.StringHashMap([]zstbrp.PackRect) = undefined;
pub var anim_enemies: std.StringHashMap([]AnimEnemyData) = undefined;
pub var anim_players: std.StringHashMap([]AnimPlayerData) = undefined;

pub var left_top_mask_uv: [4]f32 = undefined;
pub var right_bottom_mask_uv: [4]f32 = undefined;
pub var wall_backface_uv: [2]f32 = undefined;
pub var empty_bar_rect: FloatRect = undefined;
pub var hp_bar_rect: FloatRect = undefined;
pub var mp_bar_rect: FloatRect = undefined;

fn isImageEmpty(img: zstbi.Image, x: usize, y: usize, w: u32, h: u32) bool {
    for (y..y + h) |loop_y| {
        for (x..x + w) |loop_x| {
            if (img.data[(loop_y * img.width + loop_x) * 4 + 3] != 0)
                return false;
        }
    }

    return true;
}

inline fn addImage(comptime sheet_name: []const u8, comptime image_name: []const u8, comptime cut_width: u32, comptime cut_height: u32, ctx: *zstbrp.PackContext, allocator: std.mem.Allocator) !void {
    var img = try zstbi.Image.loadFromFile(asset_dir ++ "sheets/" ++ image_name, 4);
    defer img.deinit();

    const img_size = cut_width * cut_height;
    var len = @divFloor(img.width * img.height, img_size);
    var current_rects = try allocator.alloc(zstbrp.PackRect, len);

    for (0..len) |i| {
        const cur_src_x = (i * cut_width) % img.width;
        const cur_src_y = @divFloor(i * cut_width, img.width) * cut_height;

        if (!isImageEmpty(img, cur_src_x, cur_src_y, cut_width, cut_height)) {
            current_rects[i].w = cut_width + padding * 2;
            current_rects[i].h = cut_height + padding * 2;
        } else {
            current_rects[i].w = 0;
            current_rects[i].h = 0;
        }
    }

    if (zstbrp.packRects(ctx, current_rects)) {
        for (0..len) |i| {
            const rect = current_rects[i];
            if (rect.w == 0 or rect.h == 0)
                continue;

            const cur_atlas_x = rect.x + padding;
            const cur_atlas_y = rect.y + padding;
            const cur_src_x = (i * cut_width) % img.width;
            const cur_src_y = @divFloor(i * cut_width, img.width) * cut_height;

            for (0..img_size) |j| {
                const row_count = @divFloor(j, cut_width);
                const row_idx = j % cut_width;
                const atlas_idx = ((cur_atlas_y + row_count) * atlas_width + cur_atlas_x + row_idx) * 4;
                const src_idx = ((cur_src_y + row_count) * img.width + cur_src_x + row_idx) * 4;
                @memcpy(atlas.data[atlas_idx .. atlas_idx + 4], img.data[src_idx .. src_idx + 4]);
            }
        }

        try rects.put(sheet_name, current_rects);
    } else {
        std.log.err("Could not pack " ++ image_name ++ " into the atlas", .{});
    }
}

inline fn addAnimEnemy(comptime sheet_name: []const u8, comptime image_name: []const u8, comptime cut_width: u32, comptime cut_height: u32, comptime full_cut_width: u32, comptime full_cut_height: u32, ctx: *zstbrp.PackContext, allocator: std.mem.Allocator) !void {
    var img = try zstbi.Image.loadFromFile(asset_dir ++ "sheets/" ++ image_name, 4);
    defer img.deinit();

    const img_size = cut_width * cut_height;
    var len = @divFloor(img.width, full_cut_width) * @divFloor(img.height, full_cut_height) * 5;

    var current_rects = try allocator.alloc(zstbrp.PackRect, len * 2);
    defer allocator.free(current_rects);

    const enemy_data = try allocator.alloc(AnimEnemyData, @divFloor(len, 5));

    for (0..2) |i| {
        for (0..len) |j| {
            const cur_src_x = (j % 5) * cut_width;
            const cur_src_y = @divFloor(j, 5) * cut_height;

            const attack_scale = @as(u32, @intFromBool(j % 5 == 4)) + 1;
            if (!isImageEmpty(img, cur_src_x, cur_src_y, cut_width * attack_scale, cut_height)) {
                current_rects[i * len + j].w = (cut_width + padding * 2) * attack_scale;
                current_rects[i * len + j].h = cut_height + padding * 2;
            } else {
                current_rects[i * len + j].w = 0;
                current_rects[i * len + j].h = 0;
            }
        }
    }

    if (zstbrp.packRects(ctx, current_rects)) {
        for (0..2) |i| {
            for (0..len) |j| {
                const rect = current_rects[i * len + j];
                const frame_idx = j % 5;
                const set_idx = @divFloor(j, 5);
                if (frame_idx >= 3) {
                    enemy_data[set_idx].attack_anims[i][frame_idx - 3] = rect;
                } else {
                    enemy_data[set_idx].walk_anims[i][frame_idx] = rect;
                }
                const cur_atlas_x = rect.x + padding;
                const cur_atlas_y = rect.y + padding;
                const cur_src_x = frame_idx * cut_width;
                const cur_src_y = set_idx * cut_height;

                const attack_scale = @as(u32, @intFromBool(j % 5 == 4)) + 1;
                const size = img_size * attack_scale;
                const scaled_w = cut_width * attack_scale;
                for (0..size) |k| {
                    const row_count = @divFloor(k, scaled_w);
                    const row_idx = k % scaled_w;
                    const atlas_idx = ((cur_atlas_y + row_count) * atlas_width + cur_atlas_x + row_idx) * 4;

                    if (i == left_dir) {
                        const src_idx = ((cur_src_y + row_count) * img.width + cur_src_x + scaled_w - row_idx - 1) * 4;
                        @memcpy(atlas.data[atlas_idx .. atlas_idx + 4], img.data[src_idx .. src_idx + 4]);
                    } else {
                        const src_idx = ((cur_src_y + row_count) * img.width + cur_src_x + row_idx) * 4;
                        @memcpy(atlas.data[atlas_idx .. atlas_idx + 4], img.data[src_idx .. src_idx + 4]);
                    }
                }
            }
        }

        try anim_enemies.put(sheet_name, enemy_data);
    } else {
        std.log.err("Could not pack " ++ image_name ++ " into the atlas", .{});
    }
}

inline fn addAnimPlayer(comptime sheet_name: []const u8, comptime image_name: []const u8, comptime cut_width: u32, comptime cut_height: u32, comptime full_cut_width: u32, comptime full_cut_height: u32, ctx: *zstbrp.PackContext, allocator: std.mem.Allocator) !void {
    var img = try zstbi.Image.loadFromFile(asset_dir ++ "sheets/" ++ image_name, 4);
    defer img.deinit();

    const img_size = cut_width * cut_height;
    var len = @divFloor(img.width, full_cut_width) * @divFloor(img.height, full_cut_height) * 5;
    len += @divFloor(len, 3);

    var current_rects = try allocator.alloc(zstbrp.PackRect, len);
    defer allocator.free(current_rects);

    const player_data = try allocator.alloc(AnimPlayerData, @divFloor(len, 5 * 4));

    var left_sub: u32 = 0;
    for (0..len) |j| {
        const frame_idx = j % 5;
        const set_idx = @divFloor(j, 5);
        const cur_src_x = frame_idx * cut_width;
        if (set_idx % 4 == 1 and frame_idx == 0) {
            left_sub += 1;
        }

        const cur_src_y = (set_idx - left_sub) * cut_height;

        const attack_scale = @as(u32, @intFromBool(frame_idx == 4)) + 1;
        if (!isImageEmpty(img, cur_src_x, cur_src_y, cut_width * attack_scale, cut_height)) {
            current_rects[j].w = (cut_width + padding * 2) * attack_scale;
            current_rects[j].h = cut_height + padding * 2;
        } else {
            current_rects[j].w = 0;
            current_rects[j].h = 0;
        }
    }

    if (zstbrp.packRects(ctx, current_rects)) {
        left_sub = 0;
        for (0..len) |j| {
            const rect = current_rects[j];
            const frame_idx = j % 5;
            const set_idx = @divFloor(j, 5);
            if (set_idx % 4 == 1 and frame_idx == 0) {
                left_sub += 1;
            }

            const data_idx = @divFloor(set_idx, 4);
            if (frame_idx >= 3) {
                player_data[data_idx].attack_anims[set_idx % 4][frame_idx - 3] = rect;
            } else {
                player_data[data_idx].walk_anims[set_idx % 4][frame_idx] = rect;
            }
            const cur_atlas_x = rect.x + padding;
            const cur_atlas_y = rect.y + padding;
            const cur_src_x = frame_idx * cut_width;
            const cur_src_y = (set_idx - left_sub) * cut_height;

            const attack_scale = @as(u32, @intFromBool(frame_idx == 4)) + 1;
            const size = img_size * attack_scale;
            const scaled_w = cut_width * attack_scale;
            for (0..size) |k| {
                const row_count = @divFloor(k, scaled_w);
                const row_idx = k % scaled_w;
                const atlas_idx = ((cur_atlas_y + row_count) * atlas_width + cur_atlas_x + row_idx) * 4;

                if (set_idx % 4 == left_dir) {
                    const src_idx = ((cur_src_y + row_count) * img.width + cur_src_x + scaled_w - row_idx - 1) * 4;
                    @memcpy(atlas.data[atlas_idx .. atlas_idx + 4], img.data[src_idx .. src_idx + 4]);
                } else {
                    const src_idx = ((cur_src_y + row_count) * img.width + cur_src_x + row_idx) * 4;
                    @memcpy(atlas.data[atlas_idx .. atlas_idx + 4], img.data[src_idx .. src_idx + 4]);
                }
            }
        }

        try anim_players.put(sheet_name, player_data);
    } else {
        std.log.err("Could not pack " ++ image_name ++ " into the atlas", .{});
    }
}

pub fn deinit(allocator: std.mem.Allocator) void {
    atlas.deinit();
    light_tex.deinit();
    bold_atlas.deinit();
    bold_italic_atlas.deinit();
    medium_atlas.deinit();
    medium_italic_atlas.deinit();

    var rects_iter = rects.valueIterator();
    while (rects_iter.next()) |sheet_rects| {
        if (sheet_rects.len > 0) {
            allocator.free(sheet_rects.*);
        }
    }

    var anim_enemy_iter = anim_enemies.valueIterator();
    while (anim_enemy_iter.next()) |enemy_data| {
        if (enemy_data.len > 0) {
            allocator.free(enemy_data.*);
        }
    }

    var anim_player_iter = anim_players.valueIterator();
    while (anim_player_iter.next()) |player_data| {
        if (player_data.len > 0) {
            allocator.free(player_data.*);
        }
    }

    rects.deinit();
    anim_enemies.deinit();
    anim_players.deinit();
}

fn parseFontData(allocator: std.mem.Allocator, path: []const u8, chars: *[256]CharacterData) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    var iter = std.mem.splitSequence(u8, data, if (builtin.os.tag == .windows) "\r\n" else "\n");
    while (iter.next()) |line| {
        if (line.len == 0)
            continue;

        var split = std.mem.splitSequence(u8, line, ",");
        const idx = try std.fmt.parseInt(usize, split.next().?, 0);
        chars[idx] = try CharacterData.parse(&split);
    }
}

pub fn init(allocator: std.mem.Allocator) !void {
    rects = std.StringHashMap([]zstbrp.PackRect).init(allocator);
    anim_enemies = std.StringHashMap([]AnimEnemyData).init(allocator);
    anim_players = std.StringHashMap([]AnimPlayerData).init(allocator);

    bold_atlas = try zstbi.Image.loadFromFile(asset_dir ++ "fonts/Ubuntu-Bold.png", 4);
    bold_italic_atlas = try zstbi.Image.loadFromFile(asset_dir ++ "fonts/Ubuntu-BoldItalic.png", 4);
    medium_atlas = try zstbi.Image.loadFromFile(asset_dir ++ "fonts/Ubuntu-Medium.png", 4);
    medium_italic_atlas = try zstbi.Image.loadFromFile(asset_dir ++ "fonts/Ubuntu-MediumItalic.png", 4);

    try parseFontData(allocator, asset_dir ++ "fonts/Ubuntu-Bold.csv", &bold_chars);
    try parseFontData(allocator, asset_dir ++ "fonts/Ubuntu-BoldItalic.csv", &bold_italic_chars);
    try parseFontData(allocator, asset_dir ++ "fonts/Ubuntu-Medium.csv", &medium_chars);
    try parseFontData(allocator, asset_dir ++ "fonts/Ubuntu-MediumItalic.csv", &medium_italic_chars);

    light_tex = try zstbi.Image.loadFromFile(asset_dir ++ "sheets/Light.png", 4);

    atlas = try zstbi.Image.createEmpty(atlas_width, atlas_height, 4, .{});
    var ctx = zstbrp.PackContext{
        .width = atlas_width,
        .height = atlas_height,
        .pack_align = 0,
        .init_mode = 0,
        .heuristic = 0,
        .num_nodes = 100,
        .active_head = null,
        .free_head = null,
        .extra = [2]zstbrp.PackNode{ zstbrp.PackNode{ .x = 0, .y = 0, .next = null }, zstbrp.PackNode{ .x = 0, .y = 0, .next = null } },
    };

    var nodes = try allocator.alloc(zstbrp.PackNode, 4096);
    zstbrp.initPack(&ctx, nodes);

    try addImage("textile4x4", "Textile4x4.png", 4, 4, &ctx, allocator);
    try addImage("textile5x5", "Textile5x5.png", 5, 5, &ctx, allocator);
    try addImage("textile9x9", "Textile9x9.png", 9, 9, &ctx, allocator);
    try addImage("textile10x10", "Textile10x10.png", 10, 10, &ctx, allocator);
    try addImage("redLootBag", "RedLootBag.png", 8, 8, &ctx, allocator);
    try addImage("bars", "Bars.png", 24, 8, &ctx, allocator);
    try addImage("cursors", "Cursors.png", 32, 32, &ctx, allocator);
    try addImage("errorTexture", "ErrorTexture.png", 8, 8, &ctx, allocator);
    try addImage("invisible", "Invisible.png", 8, 8, &ctx, allocator);
    try addImage("keyIndicators", "KeyIndicators.png", 100, 100, &ctx, allocator);
    try addImage("lofiChar", "LofiChar.png", 8, 8, &ctx, allocator);
    try addImage("lofiChar2", "LofiChar2.png", 8, 8, &ctx, allocator);
    try addImage("lofiChar216x16", "LofiChar2.png", 16, 16, &ctx, allocator);
    try addImage("lofiCharBig", "LofiCharBig.png", 16, 16, &ctx, allocator);
    try addImage("lofiEnvironment", "LofiEnvironment.png", 8, 8, &ctx, allocator);
    try addImage("lofiEnvironment2", "LofiEnvironment2.png", 8, 8, &ctx, allocator);
    try addImage("lofiEnvironment3", "LofiEnvironment3.png", 8, 8, &ctx, allocator);
    try addImage("lofiInterface", "LofiInterface.png", 8, 8, &ctx, allocator);
    try addImage("lofiInterface2", "LofiInterface2.png", 8, 8, &ctx, allocator);
    try addImage("lofiInterfaceBig", "LofiInterfaceBig.png", 16, 16, &ctx, allocator);
    try addImage("lofiObj", "LofiObj.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj2", "LofiObj2.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj3", "LofiObj3.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj4", "LofiObj4.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj5", "LofiObj5.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj6", "LofiObj6.png", 8, 8, &ctx, allocator);
    try addImage("lofiObj40x40", "LofiObj40x40.png", 40, 40, &ctx, allocator);
    try addImage("lofiObjBig", "LofiObjBig.png", 16, 16, &ctx, allocator);
    try addImage("lofiParts", "LofiParts.png", 8, 8, &ctx, allocator);
    try addImage("lofiProjs", "LofiProjs.png", 8, 8, &ctx, allocator);
    try addImage("lofiProjsBig", "LofiProjsBig.png", 16, 16, &ctx, allocator);
    try addImage("stars", "Stars.png", 8, 8, &ctx, allocator);
    try addImage("wallBackface", "WallBackface.png", 8, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8dEncounters", "Chars8x8dEncounters.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8dHero1", "Chars8x8dHero1.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8dBeach", "Chars8x8dBeach.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rEncounters", "Chars8x8rEncounters.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rHero1", "Chars8x8rHero1.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rHero2", "Chars8x8rHero2.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rHigh", "Chars8x8rHigh.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rLow1", "Chars8x8rLow1.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rLow2", "Chars8x8rLow2.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rMid", "Chars8x8rMid.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rMid2", "Chars8x8rMid2.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rPets1", "Chars8x8rPets1.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rPets1Mask", "Chars8x8rPets1Mask.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars8x8rPetsKaratePenguin", "Chars8x8rPetsKaratePenguin.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimEnemy("chars16x8dEncounters", "Chars16x8dEncounters.png", 16, 8, 96, 8, &ctx, allocator);
    try addAnimEnemy("chars16x8rEncounters", "Chars16x8rEncounters.png", 16, 8, 96, 8, &ctx, allocator);
    try addAnimEnemy("chars16x16dEncounters", "Chars16x16dEncounters.png", 16, 16, 96, 16, &ctx, allocator);
    try addAnimEnemy("chars16x16dEncounters2", "Chars16x16dEncounters2.png", 16, 16, 96, 16, &ctx, allocator);
    try addAnimEnemy("chars16x16dMountains1", "Chars16x16dMountains1.png", 16, 16, 96, 16, &ctx, allocator);
    try addAnimEnemy("chars16x16dMountains2", "Chars16x16dMountains2.png", 16, 16, 96, 16, &ctx, allocator);
    try addAnimEnemy("chars16x16rEncounters", "Chars16x16rEncounters.png", 16, 16, 96, 16, &ctx, allocator);
    try addAnimPlayer("players", "Players.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimPlayer("playersMask", "PlayersMask.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimPlayer("playerskins", "PlayersSkins.png", 8, 8, 48, 8, &ctx, allocator);
    try addAnimPlayer("playerskinsMask", "PlayersSkinsMask.png", 8, 8, 48, 8, &ctx, allocator);

    if (settings.print_atlas)
        try zstbi.Image.writeToFile(atlas, "atlas.png", .png);

    // zig fmt: off
    const mask_rects = rects.get("ground");
    if (mask_rects != null) {
        const left_mask_rect = mask_rects.?[0];
        const top_mask_rect = mask_rects.?[1];
        left_top_mask_uv = [4]f32{
            @as(f32, @floatFromInt(left_mask_rect.x + padding)) / @as(f32, @floatFromInt(atlas_width)),
            @as(f32, @floatFromInt(left_mask_rect.y + padding)) / @as(f32, @floatFromInt(atlas_height)),
            @as(f32, @floatFromInt(top_mask_rect.x + padding)) / @as(f32, @floatFromInt(atlas_width)),
            @as(f32, @floatFromInt(top_mask_rect.y + padding)) / @as(f32, @floatFromInt(atlas_height))
        };

        const right_mask_rect = mask_rects.?[2];
        const bottom_mask_rect = mask_rects.?[3];
        right_bottom_mask_uv = [4]f32{
            @as(f32, @floatFromInt(right_mask_rect.x + padding)) / @as(f32, @floatFromInt(atlas_width)),
            @as(f32, @floatFromInt(right_mask_rect.y + padding)) / @as(f32, @floatFromInt(atlas_height)),
            @as(f32, @floatFromInt(bottom_mask_rect.x + padding)) / @as(f32, @floatFromInt(atlas_width)),
            @as(f32, @floatFromInt(bottom_mask_rect.y + padding)) / @as(f32, @floatFromInt(atlas_height))
        };
    }
    
    const wall_backface_rect = rects.get("wallBackface").?[0x0];
    wall_backface_uv = [2]f32{
        @as(f32, @floatFromInt(wall_backface_rect.x + padding)) / @as(f32, @floatFromInt(atlas_width)),
        @as(f32, @floatFromInt(wall_backface_rect.y + padding)) / @as(f32, @floatFromInt(atlas_height))
    };

    const bar_rects = rects.get("bars");
    if (bar_rects != null) {
        const empty_bar_rect_rp = bar_rects.?[0x4];
        empty_bar_rect = FloatRect{
            .x = @as(f32, @floatFromInt(empty_bar_rect_rp.x)) / @as(f32, @floatFromInt(atlas_width)),
            .y = @as(f32, @floatFromInt(empty_bar_rect_rp.y)) / @as(f32, @floatFromInt(atlas_height)),
            .w = @as(f32, @floatFromInt(empty_bar_rect_rp.w)) / @as(f32, @floatFromInt(atlas_width)),
            .h = @as(f32, @floatFromInt(empty_bar_rect_rp.h)) / @as(f32, @floatFromInt(atlas_height)),
        };

        const hp_bar_rect_rp = bar_rects.?[0x0];
        hp_bar_rect = FloatRect{
            .x = @as(f32, @floatFromInt(hp_bar_rect_rp.x)) / @as(f32, @floatFromInt(atlas_width)),
            .y = @as(f32, @floatFromInt(hp_bar_rect_rp.y)) / @as(f32, @floatFromInt(atlas_height)),
            .w = @as(f32, @floatFromInt(hp_bar_rect_rp.w)) / @as(f32, @floatFromInt(atlas_width)),
            .h = @as(f32, @floatFromInt(hp_bar_rect_rp.h)) / @as(f32, @floatFromInt(atlas_height)),
        };

        const mp_bar_rect_rp = bar_rects.?[0x1];
        mp_bar_rect = FloatRect{
            .x = @as(f32, @floatFromInt(mp_bar_rect_rp.x)) / @as(f32, @floatFromInt(atlas_width)),
            .y = @as(f32, @floatFromInt(mp_bar_rect_rp.y)) / @as(f32, @floatFromInt(atlas_height)),
            .w = @as(f32, @floatFromInt(mp_bar_rect_rp.w)) / @as(f32, @floatFromInt(atlas_width)),
            .h = @as(f32, @floatFromInt(mp_bar_rect_rp.h)) / @as(f32, @floatFromInt(atlas_height)),
        };
    }
    // zig fmt: on

    allocator.free(nodes);
}
