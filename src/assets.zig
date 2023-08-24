const xml = @import("xml.zig");
const zstbi = @import("zstbi");
const zstbrp = @import("zstbrp");
const asset_dir = @import("build_options").asset_dir;
const std = @import("std");
const game_data = @import("game_data.zig");
const settings = @import("settings.zig");
const builtin = @import("builtin");
const zaudio = @import("zaudio");

pub const padding = 2;

pub const atlas_width: u32 = 4096;
pub const atlas_height: u32 = 4096;
pub const base_texel_w: f32 = 1.0 / 4096.0;
pub const base_texel_h: f32 = 1.0 / 4096.0;

// todo turn into enum in future
pub const stand_action: u8 = 0;
pub const walk_action: u8 = 1;
pub const attack_action: u8 = 2;

pub const right_dir: u8 = 0;
pub const left_dir: u8 = 1;
pub const down_dir: u8 = 2;
pub const up_dir: u8 = 3;

pub const CharacterData = struct {
    pub const atlas_w = 1024.0;
    pub const atlas_h = 512.0;
    pub const size = 64.0;
    pub const padding = 8.0;
    pub const padding_mult = 1.0 + CharacterData.padding * 2 / size;
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
            .x_advance = try std.fmt.parseFloat(f32, split.next().?) * size,
            .x_offset = try std.fmt.parseFloat(f32, split.next().?) * size,
            .y_offset = try std.fmt.parseFloat(f32, split.next().?) * size,
            .width = try std.fmt.parseFloat(f32, split.next().?) * size + CharacterData.padding * 2,
            .height = try std.fmt.parseFloat(f32, split.next().?) * size + CharacterData.padding * 2,
            .tex_u = (try std.fmt.parseFloat(f32, split.next().?) - CharacterData.padding) / atlas_w,
            .tex_h = (atlas_h - try std.fmt.parseFloat(f32, split.next().?) + CharacterData.padding * 2) / atlas_h,
            .tex_w = (try std.fmt.parseFloat(f32, split.next().?) + CharacterData.padding * 2) / atlas_w,
            .tex_v = (atlas_h - try std.fmt.parseFloat(f32, split.next().?) - CharacterData.padding) / atlas_h,
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
    walk_anims: [2][3]AtlasData,
    attack_anims: [2][2]AtlasData,
};

pub const AnimPlayerData = struct {
    // all dirs
    walk_anims: [4][3]AtlasData,
    attack_anims: [4][2]AtlasData,
};

pub const AtlasData = struct {
    tex_u: f32,
    tex_v: f32,
    tex_w: f32,
    tex_h: f32,

    pub fn removePadding(self: *AtlasData) void {
        const float_pad: f32 = padding;
        self.tex_u += float_pad / @as(f32, atlas_width);
        self.tex_v += float_pad / @as(f32, atlas_height);
        self.tex_w -= float_pad * 2 / @as(f32, atlas_width);
        self.tex_h -= float_pad * 2 / @as(f32, atlas_height);
    }

    pub inline fn fromRaw(u: u32, v: u32, w: u32, h: u32) AtlasData {
        return AtlasData{
            .tex_u = @as(f32, @floatFromInt(u)) / @as(f32, atlas_width),
            .tex_v = @as(f32, @floatFromInt(v)) / @as(f32, atlas_height),
            .tex_w = @as(f32, @floatFromInt(w)) / @as(f32, atlas_width),
            .tex_h = @as(f32, @floatFromInt(h)) / @as(f32, atlas_height),
        };
    }

    pub inline fn texURaw(self: AtlasData) f32 {
        return self.tex_u * atlas_width;
    }

    pub inline fn texVRaw(self: AtlasData) f32 {
        return self.tex_v * atlas_height;
    }

    pub inline fn texWRaw(self: AtlasData) f32 {
        return self.tex_w * atlas_width;
    }

    pub inline fn texHRaw(self: AtlasData) f32 {
        return self.tex_h * atlas_height;
    }
};

const AudioState = struct {
    const num_sets = 100;
    const samples_per_set = 512;
    const usable_samples_per_set = 480;

    device: *zaudio.Device,
    engine: *zaudio.Engine,
    mutex: std.Thread.Mutex = .{},
    current_set: u32 = num_sets - 1,
    samples: std.ArrayList(f32),

    fn audioCallback(
        device: *zaudio.Device,
        output: ?*anyopaque,
        _: ?*const anyopaque,
        num_frames: u32,
    ) callconv(.C) void {
        const audio = @as(*AudioState, @ptrCast(@alignCast(device.getUserData())));

        audio.engine.readPcmFrames(output.?, num_frames, null) catch {};

        audio.mutex.lock();
        defer audio.mutex.unlock();

        audio.current_set = (audio.current_set + 1) % num_sets;

        const num_channels = 2;
        const base_index = samples_per_set * audio.current_set;
        const frames = @as([*]f32, @ptrCast(@alignCast(output)));

        var i: u32 = 0;
        while (i < @min(num_frames, usable_samples_per_set)) : (i += 1) {
            audio.samples.items[base_index + i] = frames[i * num_channels];
        }
    }

    fn create(allocator: std.mem.Allocator) !*AudioState {
        const samples = samples: {
            var samples = std.ArrayList(f32).initCapacity(
                allocator,
                num_sets * samples_per_set,
            ) catch unreachable;
            samples.expandToCapacity();
            @memset(samples.items, 0.0);
            break :samples samples;
        };

        const audio = try allocator.create(AudioState);

        const device = device: {
            var config = zaudio.Device.Config.init(.playback);
            config.data_callback = audioCallback;
            config.user_data = audio;
            config.sample_rate = 48000;
            config.period_size_in_frames = 480;
            config.period_size_in_milliseconds = 10;
            config.playback.format = .float32;
            config.playback.channels = 2;
            break :device try zaudio.Device.create(null, config);
        };

        const engine = engine: {
            var config = zaudio.Engine.Config.init();
            config.device = device;
            config.no_auto_start = .true32;
            break :engine try zaudio.Engine.create(config);
        };

        audio.* = .{
            .device = device,
            .engine = engine,
            .samples = samples,
        };
        return audio;
    }

    fn destroy(audio: *AudioState, allocator: std.mem.Allocator) void {
        audio.samples.deinit();
        audio.engine.destroy();
        audio.device.destroy();
        allocator.destroy(audio);
    }
};

pub var audio_state: *AudioState = undefined;
pub var main_music: *zaudio.Sound = undefined;

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

pub var atlas_data: std.StringHashMap([]AtlasData) = undefined;
pub var anim_enemies: std.StringHashMap([]AnimEnemyData) = undefined;
pub var anim_players: std.StringHashMap([]AnimPlayerData) = undefined;

pub var left_top_mask_uv: [4]f32 = undefined;
pub var right_bottom_mask_uv: [4]f32 = undefined;
pub var wall_backface_data: AtlasData = undefined;
pub var empty_bar_data: AtlasData = undefined;
pub var hp_bar_data: AtlasData = undefined;
pub var mp_bar_data: AtlasData = undefined;
pub var particle_data: AtlasData = undefined;
pub var error_data: AtlasData = undefined;
pub var error_anim: AnimEnemyData = undefined;

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
    defer allocator.free(current_rects);
    var data = try allocator.alloc(AtlasData, len);

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

        for (current_rects, 0..) |rect, i| {
            data[i] = AtlasData.fromRaw(rect.x, rect.y, rect.w, rect.h);
        }

        try atlas_data.put(sheet_name, data);
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
                const data = AtlasData.fromRaw(rect.x, rect.y, rect.w, rect.h);
                const frame_idx = j % 5;
                const set_idx = @divFloor(j, 5);
                if (frame_idx >= 3) {
                    enemy_data[set_idx].attack_anims[i][frame_idx - 3] = data;
                } else {
                    enemy_data[set_idx].walk_anims[i][frame_idx] = data;
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
            const data = AtlasData.fromRaw(rect.x, rect.y, rect.w, rect.h);
            const frame_idx = j % 5;
            const set_idx = @divFloor(j, 5);
            if (set_idx % 4 == 1 and frame_idx == 0) {
                left_sub += 1;
            }

            const data_idx = @divFloor(set_idx, 4);
            if (frame_idx >= 3) {
                player_data[data_idx].attack_anims[set_idx % 4][frame_idx - 3] = data;
            } else {
                player_data[data_idx].walk_anims[set_idx % 4][frame_idx] = data;
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

pub fn deinit(allocator: std.mem.Allocator) void {
    main_music.destroy();
    audio_state.destroy(allocator);

    atlas.deinit();
    light_tex.deinit();
    bold_atlas.deinit();
    bold_italic_atlas.deinit();
    medium_atlas.deinit();
    medium_italic_atlas.deinit();

    var rects_iter = atlas_data.valueIterator();
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

    atlas_data.deinit();
    anim_enemies.deinit();
    anim_players.deinit();
}

pub fn init(allocator: std.mem.Allocator) !void {
    atlas_data = std.StringHashMap([]AtlasData).init(allocator);
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

    audio_state = try AudioState.create(allocator);
    try audio_state.engine.start();

    if (settings.music_volume > 0.0) {
        main_music = try audio_state.engine.createSoundFromFile(
            asset_dir ++ "music/sorc.mp3",
            .{},
        );
        main_music.setLooping(true);
        main_music.setVolume(settings.music_volume);
        try main_music.start();
    }

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

    try addImage("particle", "Particle.png", 8, 8, &ctx, allocator);
    try addImage("textile4x4", "Textile4x4.png", 4, 4, &ctx, allocator);
    try addImage("textile5x5", "Textile5x5.png", 5, 5, &ctx, allocator);
    try addImage("textile9x9", "Textile9x9.png", 9, 9, &ctx, allocator);
    try addImage("textile10x10", "Textile10x10.png", 10, 10, &ctx, allocator);
    try addImage("redLootBag", "RedLootBag.png", 8, 8, &ctx, allocator);
    try addImage("bars", "Bars.png", 24, 8, &ctx, allocator);
    try addImage("cursors", "Cursors.png", 32, 32, &ctx, allocator);
    try addImage("errorTexture", "ErrorTexture.png", 8, 8, &ctx, allocator);
    try addImage("invisible", "Invisible.png", 8, 8, &ctx, allocator);
    try addImage("groundMasks", "GroundMasks.png", 8, 8, &ctx, allocator);
    try addImage("keyIndicators", "KeyIndicators.png", 100, 100, &ctx, allocator);
    try addImage("lofiChar", "LofiChar.png", 8, 8, &ctx, allocator);
    try addImage("lofiChar8x8", "LofiChar.png", 8, 8, &ctx, allocator);
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
    try addAnimEnemy("chars8x8rBeach", "Chars8x8rBeach.png", 8, 8, 48, 8, &ctx, allocator);
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

    if (atlas_data.get("groundMasks")) |ground_masks| {
        var left_mask_data = ground_masks[0x0];
        left_mask_data.removePadding();

        var top_mask_data = ground_masks[0x1];
        top_mask_data.removePadding();

        left_top_mask_uv = [4]f32{ left_mask_data.tex_u, left_mask_data.tex_v, top_mask_data.tex_u, top_mask_data.tex_v };

        var right_mask_rect = ground_masks[0x2];
        right_mask_rect.removePadding();

        var bottom_mask_rect = ground_masks[0x3];
        bottom_mask_rect.removePadding();

        right_bottom_mask_uv = [4]f32{ right_mask_rect.tex_u, right_mask_rect.tex_v, bottom_mask_rect.tex_u, bottom_mask_rect.tex_v };
    }

    if (atlas_data.get("wallBackface")) |backfaces| {
        wall_backface_data = backfaces[0x0];
        wall_backface_data.removePadding();
    }

    if (atlas_data.get("particle")) |particles| {
        particle_data = particles[0x0];
    }

    if (atlas_data.get("bars")) |bars| {
        hp_bar_data = bars[0x0];
        mp_bar_data = bars[0x1];
        empty_bar_data = bars[0x4];
    }

    if (atlas_data.get("errorTexture")) |error_tex| {
        error_data = error_tex[0x0];
        error_anim = AnimEnemyData{
            .walk_anims = [2][3]AtlasData{
                [_]AtlasData{ error_data, error_data, error_data },
                [_]AtlasData{ error_data, error_data, error_data },
            },
            .attack_anims = [2][2]AtlasData{
                [_]AtlasData{ error_data, error_data },
                [_]AtlasData{ error_data, error_data },
            },
        };
    }

    allocator.free(nodes);
}
