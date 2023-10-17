const std = @import("std");
const xml = @import("xml.zig");
const utils = @import("utils.zig");
const asset_dir = @import("build_options").asset_dir;

const item_files = [_][]const u8{ "Equip", "Dyes", "Textiles" };
const object_files = [_][]const u8{
    "Projectiles",     "Permapets",       "Players",
    "Objects",         "TestingObjects",  "StaticObjects",
    "TutorialObjects", "Monsters",        "Pets",
    "TempObjects",     "Shore",           "Low",
    "Mid",             "High",            "Mountains",
    "Encounters",      "OryxCastle",      "TombOfTheAncients",
    "SpriteWorld",     "UndeadLair",      "OceanTrench",
    "ForbiddenJungle", "OryxChamber",     "ManorOfTheImmortals",
    "PirateCave",      "SnakePit",        "AbyssOfDemons",
    "GhostShip",       "MadLab",          "CaveOfAThousandTreasures",
    "CandyLand",       "HauntedCemetery",
};
const ground_files = [_][]const u8{"Ground"};
const region_files = [_][]const u8{"Regions"};

pub const ClassType = enum(u8) {
    cave_wall,
    character,
    character_changer,
    closed_vault_chest,
    connected_wall,
    container,
    game_object,
    guild_board,
    guild_chronicle,
    guild_hall_portal,
    guild_merchant,
    guild_register,
    merchant,
    money_changer,
    name_changer,
    reskin_vendor,
    one_way_container,
    player,
    portal,
    projectile,
    sign,
    spider_web,
    stalagmite,
    wall,
    vault_chest,
    market_place,
    wiki,

    const map = std.ComptimeStringMap(ClassType, .{
        .{ "CaveWall", .cave_wall },
        .{ "Character", .character },
        .{ "CharacterChanger", .character_changer },
        .{ "ClosedVaultChest", .closed_vault_chest },
        .{ "ConnectedWall", .connected_wall },
        .{ "Container", .container },
        .{ "GameObject", .game_object },
        .{ "GuildBoard", .guild_board },
        .{ "GuildChronicle", .guild_chronicle },
        .{ "GuildHallPortal", .guild_hall_portal },
        .{ "GuildMerchant", .guild_merchant },
        .{ "GuildRegister", .guild_register },
        .{ "Merchant", .merchant },
        .{ "MoneyChanger", .money_changer },
        .{ "NameChanger", .name_changer },
        .{ "ReskinVendor", .reskin_vendor },
        .{ "OneWayContainer", .one_way_container },
        .{ "Player", .player },
        .{ "Portal", .portal },
        .{ "Projectile", .projectile },
        .{ "Sign", .sign },
        .{ "SpiderWeb", .spider_web },
        .{ "Stalagmite", .stalagmite },
        .{ "Wall", .wall },
        .{ "VaultChest", .vault_chest }, //one page vault (use api to get item info?)
        .{ "MarketObject", .market_place }, //market place duh
        .{ "WikiObject", .wiki }, //simple list of all items
    });

    pub fn fromString(str: []const u8) ClassType {
        return map.get(str) orelse .game_object;
    }

    pub fn isInteractive(class: ClassType) bool {
        return class == .portal or class == .container or class == .vault_chest or class == .market_place or class == .wiki or class == .guild_board or class == .guild_chronicle or class == .guild_register or class == .guild_merchant;
    }

    pub fn hasPanel(class: ClassType) bool {
        return class == .vault_chest or class == .wiki or class == .guild_board or class == .guild_chronicle or class == .guild_merchant or class == .guild_register;
    }
};

pub const TextureData = struct {
    sheet: []const u8,
    index: u16,
    animated: bool,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator, animated: bool) !TextureData {
        return TextureData{
            .sheet = try node.getValueAlloc("File", allocator, "Unknown"),
            .index = try node.getValueInt("Index", u16, 0),
            .animated = animated,
        };
    }
};

pub const CharacterSkin = struct {
    obj_type: u16,
    name: []const u8,
    texture: TextureData,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) CharacterSkin {
        return CharacterSkin{
            .objType = try node.getAttributeInt("type", u16, 0),
            .name = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .texture = try TextureData.parse(
                node.findChild("AnimatedTexture") orelse @panic("Could not parse CharacterClass"),
                allocator,
                false,
            ),
        };
    }
};

pub const CharacterClass = struct {
    obj_type: u16,
    name: []const u8,
    desc: []const u8,
    hit_sound: []const u8,
    death_sound: []const u8,
    blood_prob: f32,
    slot_types: []i8,
    equipment: []i16,
    texture: TextureData,
    skins: ?[]CharacterSkin,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !CharacterClass {
        var slot_list = try utils.DynSlice(i8).init(20, allocator);
        defer slot_list.deinit();
        var slot_iter = std.mem.split(u8, node.getValue("SlotTypes") orelse "", ", ");
        while (slot_iter.next()) |s|
            try slot_list.add(try std.fmt.parseInt(i8, s, 0));

        var equip_list = try utils.DynSlice(i16).init(20, allocator);
        defer equip_list.deinit();
        var equip_iter = std.mem.split(u8, node.getValue("Equipment") orelse "", ", ");
        while (equip_iter.next()) |s|
            try equip_list.add(try std.fmt.parseInt(i16, s, 0));

        return CharacterClass{
            .obj_type = try node.getAttributeInt("type", u16, 0),
            .name = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .desc = try node.getValueAlloc("Description", allocator, "Unknown"),
            .hit_sound = try node.getValueAlloc("HitSound", allocator, "Unknown"),
            .death_sound = try node.getValueAlloc("DeathSound", allocator, "Unknown"),
            .blood_prob = try node.getAttributeFloat("BloodProb", f32, 0.0),
            .slot_types = try allocator.dupe(i8, slot_list.items()),
            .equipment = try allocator.dupe(i16, equip_list.items()),
            .texture = try TextureData.parse(node.findChild("AnimatedTexture") orelse @panic("Could not parse CharacterClass"), allocator, false),
            .skins = null,
        };
    }
};

pub const AnimFrame = struct {
    time: f32,
    tex: TextureData,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !AnimFrame {
        return AnimFrame{
            .time = try node.getAttributeFloat("time", f32, 0.0) * 1000,
            .tex = try TextureData.parse(node.findChild("Texture").?, allocator, false),
        };
    }
};

pub const AnimProps = struct {
    prob: f32,
    period: u16,
    period_jitter: u16,
    sync: bool,
    frames: []AnimFrame,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !AnimProps {
        var frame_list = utils.DynSlice(AnimFrame).init(5, allocator);
        defer frame_list.deinit();
        var frame_iter = node.iterate(&.{}, "Frame");
        while (frame_iter.next()) |animNode|
            try frame_list.add(try AnimFrame.parse(animNode, allocator));

        return AnimProps{
            .prob = try node.getAttributeFloat("prob", f32, 0.0),
            .period = try node.getAttributeInt("period", u16, 0),
            .period_jitter = try node.getAttributeInt("periodJitter", u16, 0),
            .sync = node.attributeExists("sync"),
            .frames = frame_list.items(),
        };
    }
};

pub const GroundAnimType = enum(u8) {
    none = 0,
    wave = 1,
    flow = 2,

    const map = std.ComptimeStringMap(GroundAnimType, .{
        .{ "Wave", .wave },
        .{ "Flow", .flow },
    });

    pub fn fromString(str: []const u8) GroundAnimType {
        return map.get(str) orelse .none;
    }
};

pub const GroundProps = struct {
    obj_type: i32,
    obj_id: []const u8,
    no_walk: bool,
    min_damage: u16,
    max_damage: u16,
    blend_prio: i32,
    composite_prio: i32,
    speed: f32,
    x_offset: f32,
    y_offset: f32,
    push: bool,
    sink: bool,
    sinking: bool,
    random_offset: bool,
    light_color: u32,
    light_intensity: f32,
    light_radius: f32,
    anim_type: GroundAnimType,
    anim_dx: f32,
    anim_dy: f32,
    slide_amount: f32,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !GroundProps {
        var anim_type: GroundAnimType = .none;
        var dx: f32 = 0.0;
        var dy: f32 = 0.0;
        if (node.findChild("Animate")) |anim_node| {
            anim_type = GroundAnimType.fromString(anim_node.currentValue().?);
            dx = try anim_node.getAttributeFloat("dx", f32, 0.0);
            dy = try anim_node.getAttributeFloat("dy", f32, 0.0);
        }

        return GroundProps{
            .obj_type = try node.getAttributeInt("type", i32, 0),
            .obj_id = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .no_walk = node.elementExists("NoWalk"),
            .min_damage = try node.getValueInt("MinDamage", u16, 0),
            .max_damage = try node.getValueInt("MaxDamage", u16, 0),
            .blend_prio = try node.getValueInt("BlendPriority", i32, 0),
            .composite_prio = try node.getValueInt("CompositePriority", i32, 0),
            .speed = try node.getValueFloat("Speed", f32, 1.0),
            .x_offset = try node.getValueFloat("XOffset", f32, 0.0),
            .y_offset = try node.getValueFloat("YOffset", f32, 0.0),
            .slide_amount = try node.getValueFloat("SlideAmount", f32, 0.0),
            .push = node.elementExists("Push"),
            .sink = node.elementExists("Sink"),
            .sinking = node.elementExists("Sinking"),
            .random_offset = node.elementExists("RandomOffset"),
            .light_color = try node.getValueInt("LightColor", u32, 0),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
            .anim_type = anim_type,
            .anim_dx = dx,
            .anim_dy = dy,
        };
    }
};

pub const ObjProps = struct {
    obj_type: u16,
    obj_id: []const u8,
    display_id: []const u8,
    shadow_size: i32,
    is_player: bool,
    is_enemy: bool,
    draw_on_ground: bool,
    draw_under: bool,
    occupy_square: bool,
    full_occupy: bool,
    enemy_occupy_square: bool,
    static: bool,
    no_mini_map: bool,
    protect_from_ground_damage: bool,
    protect_from_sink: bool,
    base_z: f32,
    flying: bool,
    color: u32,
    show_name: bool,
    face_attacks: bool,
    blood_probability: f32,
    blood_color: u32,
    shadow_color: u32,
    portrait: ?TextureData,
    min_size: f32,
    max_size: f32,
    size_step: f32,
    angle_correction: f32,
    rotation: f32,
    float: bool,
    float_time: u16,
    float_height: f32,
    float_sine: bool,
    light_color: u32,
    light_intensity: f32,
    light_radius: f32,
    alpha_mult: f32,
    projectiles: []ProjProps,
    hit_sound: []const u8,
    death_sound: []const u8,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ObjProps {
        const obj_id = try node.getAttributeAlloc("id", allocator, "");
        var min_size = try node.getValueFloat("MinSize", f32, 100.0) / 100.0;
        var max_size = try node.getValueFloat("MaxSize", f32, 100.0) / 100.0;
        const size = try node.getValueFloat("Size", f32, 0.0) / 100.0;
        if (size > 0) {
            min_size = size;
            max_size = size;
        }

        var proj_it = node.iterate(&.{}, "Projectile");
        var proj_list = try utils.DynSlice(ProjProps).init(5, allocator);
        defer proj_list.deinit();
        while (proj_it.next()) |proj_node|
            try proj_list.add(try ProjProps.parse(proj_node, allocator));

        const float_node = node.findChild("Float");
        return ObjProps{
            .obj_type = try node.getAttributeInt("type", u16, 0),
            .obj_id = obj_id,
            .display_id = try node.getValueAlloc("DisplayId", allocator, obj_id),
            .shadow_size = try node.getValueInt("ShadowSize", i32, -1),
            .is_player = node.elementExists("Player"),
            .is_enemy = node.elementExists("Enemy"),
            .draw_on_ground = node.elementExists("DrawOnGround"),
            .draw_under = node.elementExists("DrawUnder"),
            .occupy_square = node.elementExists("OccupySquare"),
            .full_occupy = node.elementExists("FullOccupy"),
            .enemy_occupy_square = node.elementExists("EnemyOccupySquare"),
            .static = node.elementExists("Static"),
            .no_mini_map = node.elementExists("NoMiniMap"),
            .base_z = try node.getValueFloat("Z", f32, 0.0),
            .flying = node.elementExists("Flying"),
            .color = try node.getValueInt("Color", u32, 0xFFFFFF),
            .show_name = node.elementExists("ShowName"),
            .face_attacks = !node.elementExists("DontFaceAttacks"),
            .blood_probability = try node.getValueFloat("BloodProb", f32, 0.0),
            .blood_color = try node.getValueInt("BloodColor", u32, 0xFF0000),
            .shadow_color = try node.getValueInt("ShadowColor", u32, 0),
            .portrait = if (node.elementExists("Portrait")) try TextureData.parse(node.findChild("Portrait").?, allocator, false) else null,
            .min_size = min_size,
            .max_size = max_size,
            .size_step = try node.getValueFloat("SizeStep", f32, 0.0) / 100.0,
            .angle_correction = try node.getValueFloat("AngleCorrection", f32, 0.0) * (std.math.pi / 4.0),
            .rotation = try node.getValueFloat("Rotation", f32, 0.0),
            .light_color = try node.getValueInt("LightColor", u32, 0),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
            .alpha_mult = try node.getValueFloat("AlphaMult", f32, 1.0),
            .float = float_node != null,
            .float_time = try std.fmt.parseInt(u16, if (float_node != null) float_node.?.getAttribute("time") orelse "0" else "0", 0),
            .float_height = try std.fmt.parseFloat(f32, if (float_node != null) float_node.?.getAttribute("height") orelse "0.0" else "0.0"),
            .float_sine = float_node != null and float_node.?.getAttribute("sine") != null,
            .projectiles = try allocator.dupe(ProjProps, proj_list.items()),
            .hit_sound = try node.getValueAlloc("HitSound", allocator, "Unknown"),
            .death_sound = try node.getValueAlloc("DeathSound", allocator, "Unknown"),
            .protect_from_ground_damage = node.elementExists("ProtectFromGroundDamage"),
            .protect_from_sink = node.elementExists("ProtectFromSink"),
        };
    }

    pub fn getSize(self: *const ObjProps) f32 {
        if (self.min_size == self.max_size)
            return self.min_size;

        const max_steps = std.math.round((self.max_size - self.min_size) / self.size_step);
        return self.min_size + std.math.round(utils.rng.random().float(f32) * max_steps) * self.size_step;
    }
};

pub const ConditionEffect = struct {
    duration: f32,
    condition: utils.ConditionEnum,

    pub fn parse(node: xml.Node) !ConditionEffect {
        return ConditionEffect{
            .duration = try node.getAttributeFloat("duration", f32, 0.0),
            .condition = utils.ConditionEnum.fromString(node.currentValue().?),
        };
    }
};

pub const ProjProps = struct {
    texture_data: []TextureData,
    angle_correction: f32,
    rotation: f32,
    light_color: i32,
    light_intensity: f32,
    light_radius: f32,
    bullet_type: i32,
    object_id: []const u8,
    lifetime_ms: u16,
    speed: f32,
    size: f32,
    damage: i32,
    min_damage: i32,
    max_damage: i32,
    effects: []ConditionEffect,
    multi_hit: bool,
    passes_cover: bool,
    armor_piercing: bool,
    particle_trail: bool,
    wavy: bool,
    parametric: bool,
    boomerang: bool,
    amplitude: f32,
    frequency: f32,
    magnitude: f32,
    accel: f32,
    accel_delay: u16,
    speed_clamp: u16,
    angle_change: f32,
    angle_change_delay: u16,
    angle_change_end: u16,
    angle_change_accel: f32,
    angle_change_accel_delay: u16,
    angle_change_clamp: f32,
    zero_velocity_delay: i16,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ProjProps {
        var effect_it = node.iterate(&.{}, "ConditionEffect");
        var effect_list = try utils.DynSlice(ConditionEffect).init(2, allocator);
        defer effect_list.deinit();
        while (effect_it.next()) |effect_node|
            try effect_list.add(try ConditionEffect.parse(effect_node));

        return ProjProps{
            .texture_data = try parseTexture(node, allocator),
            .angle_correction = try node.getValueFloat("AngleCorrection", f32, 0.0) * (std.math.pi / 4.0),
            .rotation = try node.getValueFloat("Rotation", f32, 0.0),
            .light_color = try node.getValueInt("LightColor", i32, -1),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
            .bullet_type = try node.getAttributeInt("type", i32, 0),
            .object_id = try node.getValueAlloc("ObjectId", allocator, ""),
            .lifetime_ms = try node.getValueInt("LifetimeMS", u16, 0),
            .speed = try node.getValueFloat("Speed", f32, 0) / 10000.0,
            .size = try node.getValueFloat("Size", f32, 100) / 100.0,
            .damage = try node.getValueInt("Damage", i32, 0),
            .min_damage = try node.getValueInt("MinDamage", i32, 0),
            .max_damage = try node.getValueInt("MaxDamage", i32, 0),
            .effects = try allocator.dupe(ConditionEffect, effect_list.items()),
            .multi_hit = node.elementExists("MultiHit"),
            .passes_cover = node.elementExists("PassesCover"),
            .armor_piercing = node.elementExists("ArmorPiercing"),
            .particle_trail = node.elementExists("ParticleTrail"),
            .wavy = node.elementExists("Wavy"),
            .parametric = node.elementExists("Parametric"),
            .boomerang = node.elementExists("Boomerang"),
            .amplitude = try node.getValueFloat("Amplitude", f32, 0.0),
            .frequency = try node.getValueFloat("Frequency", f32, 1.0),
            .magnitude = try node.getValueFloat("Magnitude", f32, 3.0),
            .accel = try node.getValueFloat("Acceleration", f32, 0.0),
            .accel_delay = try node.getValueInt("AccelerationDelay", u16, 0),
            .speed_clamp = try node.getValueInt("SpeedClamp", u16, 0),
            .angle_change = std.math.degreesToRadians(f32, try node.getValueFloat("AngleChange", f32, 0.0)),
            .angle_change_delay = try node.getValueInt("AngleChangeDelay", u16, 0),
            .angle_change_end = try node.getValueInt("AngleChangeEnd", u16, 0),
            .angle_change_accel = std.math.degreesToRadians(f32, try node.getValueFloat("AngleChangeAccel", f32, 0.0)),
            .angle_change_accel_delay = try node.getValueInt("AngleChangeAccelDelay", u16, 0),
            .angle_change_clamp = try node.getValueFloat("AngleChangeClamp", f32, 0.0),
            .zero_velocity_delay = try node.getValueInt("ZeroVelocityDelay", i16, -1),
        };
    }
};

pub const EffectProps = struct {
    id: []const u8,
    particle: []const u8,
    cooldown: f32,
    color: u32,
    rate: f32,
    speed: f32,
    speed_variance: f32,
    spread: f32,
    life: f32,
    life_variance: f32,
    size: i32,
    friction: f32,
    rise: f32,
    rise_variance: f32,
    rise_acc: f32,
    range_x: i32,
    range_y: i32,
    z_offset: f32,
    bitmap_file: []const u8,
    bitmap_index: u32,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !EffectProps {
        return EffectProps{
            .id = try node.currentValue(),
            .particle = try node.getAttributeAlloc("particle", allocator, ""),
            .cooldown = try node.getAttributeFloat("Cooldown", f32, 0.0),
            .color = try node.getAttributeInt("color", u32, 0xFFFFFF),
            .rate = try node.getAttributeFloat("rate", f32, 5.0),
            .speed = try node.getAttributeFloat("speed", f32, 0.0),
            .speed_variance = try node.getAttributeFloat("speedVariance", f32, 0.0),
            .spread = try node.getAttributeFloat("spread", f32, 0.0),
            .life = try node.getAttributeFloat("life", f32, 1.0),
            .life_variance = try node.getAttributeFloat("lifeVariance", f32, 0.0),
            .size = try node.getAttributeInt("size", i32, 3),
            .rise = try node.getAttributeFloat("rise", f32, 0.0),
            .rise_variance = try node.getAttributeFloat("riseVariance", f32, 0.0),
            .rise_acc = try node.getAttributeFloat("riseAcc", f32, 0.0),
            .range_x = try node.getAttributeInt("rangeX", i32, 0),
            .range_y = try node.getAttributeInt("rangeY", i32, 0),
            .z_offset = try node.getAttributeFloat("zOffset", f32, 0.0),
            .bitmap_file = try node.getAttributeAlloc("bitmapFile", allocator, ""),
            .bitmap_index = try node.getAttributeInt("bitmapIndex", u32, 0),
        };
    }
};

pub const StatType = enum(u8) {
    max_hp = 0,
    hp = 1,
    size = 2,
    max_mp = 3,
    mp = 4,
    exp_goal = 5,
    exp = 6,
    level = 7,
    inv_0 = 8,
    inv_1 = 9,
    inv_2 = 10,
    inv_3 = 11,
    inv_4 = 12,
    inv_5 = 13,
    inv_6 = 14,
    inv_7 = 15,
    inv_8 = 16,
    inv_9 = 17,
    inv_10 = 18,
    inv_11 = 19,
    attack = 20,
    defense = 21,
    speed = 22,
    vitality = 26,
    wisdom = 27,
    dexterity = 28,
    condition = 29,
    stars = 30,
    name = 31,
    tex_1 = 32,
    tex_2 = 33,
    merchant_merch_type = 34,
    credits = 35,
    sellable_price = 36,
    portal_active = 37,
    account_id = 38,
    current_fame = 39,
    sellable_currency = 40,
    object_connection = 41,
    merchant_rem_count = 42,
    merchant_rem_minute = 43,
    merchant_discount = 44,
    sellable_rank_req = 45,
    hp_boost = 46,
    mp_boost = 47,
    attack_bonus = 48,
    defense_bonus = 49,
    speed_bonus = 50,
    vitality_bonus = 51,
    wisdom_bonus = 52,
    dexterity_bonus = 53,
    owner_acc_id = 54,
    rank_required = 55,
    name_chosen = 56,
    fame = 57,
    fame_goal = 58,
    glow = 59,
    sink_level = 60,
    alt_texture_index = 61,
    guild = 62,
    guild_rank = 63,
    oxygen_bar = 64,
    health_stack_count = 65,
    magic_stack_count = 66,
    backpack_0 = 67,
    backpack_1 = 68,
    backpack_2 = 69,
    backpack_3 = 70,
    backpack_4 = 71,
    backpack_5 = 72,
    backpack_6 = 73,
    backpack_7 = 74,
    has_backpack = 75,
    skin = 76,

    none = 255,

    const map = std.ComptimeStringMap(StatType, .{
        .{ "MaxHP", .max_hp },
        .{ "MaxMP", .max_mp },
        .{ "Attack", .attack },
        .{ "Defense", .defense },
        .{ "Speed", .speed },
        .{ "Dexterity", .dexterity },
        .{ "Vitality", .vitality },
        .{ "Wisdom", .wisdom },
    });

    pub fn fromString(str: []const u8) StatType {
        return map.get(str) orelse .max_hp;
    }
};

pub const ActivationType = enum(u8) {
    increment_stat,
    heal,
    magic,
    unlock_skin,
    create,
    heal_nova,
    bullet_nova,
    stat_boost,
    stat_boost_aura,
    effect_aura,
    effect,
    teleport,
    shoot,
    vampire_blast,
    poison_grenade,
    trap,
    stasis_blast,
    pet,
    decoy,
    lightning,
    remove_debuffs,
    remove_debuffs_aura,
    magic_nova,
    daze_blast,
    unlock_portal,
    shuriken_ability,
    backpack,
    object_toss,
    dye,
    stat_boost_self,
    clear_condition_effect_self,
    clear_condition_effect_aura,
    remove_negative_conditions_self,
    unknown = std.math.maxInt(u8),

    const map = std.ComptimeStringMap(ActivationType, .{
        .{ "IncrementStat", .increment_stat },
        .{ "Heal", .heal },
        .{ "HealNova", .heal_nova },
        .{ "BulletNova", .bullet_nova },
        .{ "Magic", .magic },
        .{ "UnlockSkin", .unlock_skin },
        .{ "Create", .create },
        .{ "StatBoost", .stat_boost },
        .{ "StatBoostAura", .stat_boost_aura },
        .{ "ConditionEffectAura", .effect_aura },
        .{ "ConditionEffectSelf", .effect },
        .{ "Teleport", .teleport },
        .{ "Shoot", .shoot },
        .{ "VampireBlast", .vampire_blast },
        .{ "PoisonGrenade", .poison_grenade },
        .{ "Trap", .trap },
        .{ "StasisBlast", .stasis_blast },
        .{ "Pet", .pet },
        .{ "Decoy", .decoy },
        .{ "Lightning", .remove_debuffs },
        .{ "RemoveNegativeConditions", .remove_debuffs_aura },
        .{ "MagicNova", .magic_nova },
        .{ "DazeBlast", .daze_blast },
        .{ "UnlockPortal", .unlock_portal },
        .{ "ShurikenAbility", .shuriken_ability },
        .{ "Backpack", .backpack },
        .{ "ObjectToss", .object_toss },
        .{ "Dye", .dye },
        .{ "StatBoostSelf", .stat_boost_self },
        .{ "ClearConditionEffectSelf", .clear_condition_effect_self },
        .{ "ClearConditionEffectAura", .clear_condition_effect_aura },
        .{ "RemoveNegativeConditionsSelf", .remove_negative_conditions_self },
    });

    pub fn fromString(str: []const u8) ActivationType {
        const ret = map.get(str) orelse .unknown;
        if (ret == .unknown) {
            std.log.warn("Unknown ActivateType: {s} Defaulted to 'unknown'", .{str});
        }
        return ret;
    }
};

pub const ActivationData = struct {
    activation_type: ActivationType,
    object_id: []const u8,
    duration: f32,
    max_distance: u8,
    radius: f32,
    total_damage: u32,
    cond_duration: f32,
    id: []const u8,
    effect: utils.ConditionEnum,
    range: f32,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ActivationData {
        return ActivationData{
            .activation_type = ActivationType.fromString(node.currentValue() orelse "IncrementStat"),
            .object_id = try node.getAttributeAlloc("objectId", allocator, ""),
            .id = try node.getAttributeAlloc("id", allocator, ""),
            .effect = utils.ConditionEnum.fromString(node.getAttribute("effect") orelse ""),
            .duration = try node.getAttributeFloat("duration", f32, 0.0),
            .cond_duration = try node.getAttributeFloat("condDuration", f32, 0.0),
            .max_distance = try node.getAttributeInt("maxDistance", u8, 0),
            .radius = try node.getAttributeFloat("maxDistance", f32, 0.0),
            .total_damage = try node.getAttributeInt("totalDamage", u32, 0),
            .range = try node.getAttributeFloat("condDuration", f32, 0.0),
        };
    }
};

pub const StatIncrementData = struct {
    stat: StatType,
    amount: u16,

    pub fn parse(node: xml.Node) !StatIncrementData {
        return StatIncrementData{
            .stat = StatType.fromString(node.getAttribute("stat") orelse "MaxHP"),
            .amount = try node.getAttributeInt("amount", u16, 0),
        };
    }
};

pub const EffectInfo = struct {
    name: []const u8,
    description: []const u8,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !EffectInfo {
        return EffectInfo{
            .name = try node.getAttributeAlloc("name", allocator, ""),
            .description = try node.getAttributeAlloc("description", allocator, ""),
        };
    }
};

pub const ItemProps = struct {
    consumable: bool,
    untradeable: bool,
    usable: bool,
    is_potion: bool,
    multi_phase: bool,
    xp_boost: bool,
    lt_boosted: bool,
    ld_boosted: bool,
    backpack: bool,
    slot_type: i8,
    tier: []const u8,
    mp_cost: f32,
    fame_bonus: u8,
    bag_type: u8,
    num_projectiles: u8,
    arc_gap: f32,
    doses: u8,
    display_id: []const u8,
    successor_id: []const u8,
    rate_of_fire: f32,
    texture_data: TextureData,
    projectile: ?ProjProps,
    stat_increments: ?[]StatIncrementData,
    activations: ?[]ActivationData,
    cooldown: f32,
    sound: []const u8,
    old_sound: []const u8,
    mp_end_cost: f32,
    timer: f32,
    extra_tooltip_data: ?[]EffectInfo,

    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ItemProps {
        var incr_it = node.iterate(&.{}, "IncrementStat");
        var incr_list = try utils.DynSlice(StatIncrementData).init(4, allocator);
        defer incr_list.deinit();
        while (incr_it.next()) |incr_node|
            try incr_list.add(try StatIncrementData.parse(incr_node));

        var activate_it = node.iterate(&.{}, "Activate");
        var activate_list = try utils.DynSlice(ActivationData).init(4, allocator);
        defer activate_list.deinit();
        while (activate_it.next()) |activate_node|
            try activate_list.add(try ActivationData.parse(activate_node, allocator));

        var extra_tooltip_it = node.iterate(&.{}, "ExtraTooltipData");
        var extra_tooltip_list = try utils.DynSlice(EffectInfo).init(4, allocator);
        defer extra_tooltip_list.deinit();
        while (extra_tooltip_it.next()) |extra_tooltip_node|
            try extra_tooltip_list.add(try EffectInfo.parse(extra_tooltip_node, allocator));

        return ItemProps{
            .consumable = node.elementExists("Consumable"),
            .untradeable = node.elementExists("Soulbound"),
            .usable = node.elementExists("Usable"),
            .slot_type = try node.getValueInt("SlotType", i8, 0),
            .tier = try node.getValueAlloc("Tier", allocator, "UT"),
            .bag_type = try node.getValueInt("BagType", u8, 0),
            .num_projectiles = try node.getValueInt("NumProjectiles", u8, 1),
            .arc_gap = std.math.degreesToRadians(f32, try node.getValueFloat("ArcGap", f32, 11.25)),
            .doses = try node.getValueInt("Doses", u8, 0),
            .display_id = try node.getValueAlloc("DisplayId", allocator, ""),
            .successor_id = try node.getValueAlloc("SuccessorId", allocator, ""),
            .mp_cost = try node.getValueFloat("MpCost", f32, 0.0),
            .fame_bonus = try node.getValueInt("FameBonus", u8, 0),
            .rate_of_fire = try node.getValueFloat("RateOfFire", f32, 1.0),
            .texture_data = try TextureData.parse(node.findChild("Texture").?, allocator, false),
            .projectile = if (node.elementExists("Projectile")) try ProjProps.parse(node.findChild("Projectile").?, allocator) else null,
            .stat_increments = try allocator.dupe(StatIncrementData, incr_list.items()),
            .activations = if (node.elementExists("Activate")) try allocator.dupe(ActivationData, activate_list.items()) else null,
            .sound = try node.getValueAlloc("Sound", allocator, ""),
            .old_sound = try node.getValueAlloc("OldSound", allocator, ""),
            .is_potion = node.elementExists("Potion"),
            .cooldown = try node.getValueFloat("Cooldown", f32, 0.5), // 500 ms
            .mp_end_cost = try node.getValueFloat("MpEndCost", f32, 0.0),
            .timer = try node.getValueFloat("Timer", f32, 0.0),
            .multi_phase = node.elementExists("MultiPhase"),
            .xp_boost = node.elementExists("XpBoost"),
            .lt_boosted = node.elementExists("LTBoosted"),
            .ld_boosted = node.elementExists("LDBoosted"),
            .backpack = node.elementExists("Backpack"),
            .extra_tooltip_data = if (node.elementExists("ExtraTooltipData")) try allocator.dupe(EffectInfo, extra_tooltip_list.items()) else null,
        };
    }
};

pub const UseType = enum(u8) {
    default = 0,
    start = 1,
    end = 2,
};

pub const ItemType = enum(i8) {
    no_item = -1,
    any = 0,
    sword = 1,
    bow = 3,
    tome = 4,
    shield = 5,
    leather = 6,
    heavy = 7,
    wand = 8,
    ring = 9,
    consumable = 10,
    spell = 11,
    seal = 12,
    cloak = 13,
    robe = 14,
    quiver = 15,
    helm = 16,
    staff = 17,
    poison = 18,
    skull = 19,
    trap = 20,
    orb = 21,
    prism = 22,
    scepter = 23,
    shuriken = 24,

    pub inline fn slotsMatch(slot_1: i8, slot_2: i8) bool {
        if (slot_1 == @intFromEnum(ItemType.any) or slot_2 == @intFromEnum(ItemType.any)) {
            return true;
        }

        return slot_1 == slot_2;
    }
};

pub const Currency = enum(u8) {
    gold = 0,
    fame = 1,
    guild_fame = 2,
    tokens = 3,
};

pub var classes: []CharacterClass = undefined;
pub var item_name_to_type: std.StringHashMap(u16) = undefined;
pub var item_type_to_props: std.AutoHashMap(u16, ItemProps) = undefined;
pub var item_type_to_name: std.AutoHashMap(u16, []const u8) = undefined;
pub var obj_name_to_type: std.StringHashMap(u16) = undefined;
pub var obj_type_to_props: std.AutoHashMap(u16, ObjProps) = undefined;
pub var obj_type_to_name: std.AutoHashMap(u16, []const u8) = undefined;
pub var obj_type_to_tex_data: std.AutoHashMap(u16, []const TextureData) = undefined;
pub var obj_type_to_top_tex_data: std.AutoHashMap(u16, []const TextureData) = undefined;
pub var obj_type_to_anim_data: std.AutoHashMap(u16, AnimProps) = undefined;
pub var obj_type_to_class: std.AutoHashMap(u16, ClassType) = undefined;
pub var ground_name_to_type: std.StringHashMap(u16) = undefined;
pub var ground_type_to_props: std.AutoHashMap(u16, GroundProps) = undefined;
pub var ground_type_to_name: std.AutoHashMap(u16, []const u8) = undefined;
pub var ground_type_to_tex_data: std.AutoHashMap(u16, []const TextureData) = undefined;
pub var region_type_to_name: std.AutoHashMap(u16, []const u8) = undefined;
pub var region_type_to_color: std.AutoHashMap(u16, u32) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    item_name_to_type = std.StringHashMap(u16).init(allocator);
    item_type_to_props = std.AutoHashMap(u16, ItemProps).init(allocator);
    item_type_to_name = std.AutoHashMap(u16, []const u8).init(allocator);
    obj_name_to_type = std.StringHashMap(u16).init(allocator);
    obj_type_to_props = std.AutoHashMap(u16, ObjProps).init(allocator);
    obj_type_to_name = std.AutoHashMap(u16, []const u8).init(allocator);
    obj_type_to_tex_data = std.AutoHashMap(u16, []const TextureData).init(allocator);
    obj_type_to_top_tex_data = std.AutoHashMap(u16, []const TextureData).init(allocator);
    obj_type_to_anim_data = std.AutoHashMap(u16, AnimProps).init(allocator);
    obj_type_to_class = std.AutoHashMap(u16, ClassType).init(allocator);
    ground_name_to_type = std.StringHashMap(u16).init(allocator);
    ground_type_to_props = std.AutoHashMap(u16, GroundProps).init(allocator);
    ground_type_to_name = std.AutoHashMap(u16, []const u8).init(allocator);
    ground_type_to_tex_data = std.AutoHashMap(u16, []const TextureData).init(allocator);
    region_type_to_name = std.AutoHashMap(u16, []const u8).init(allocator);
    region_type_to_color = std.AutoHashMap(u16, u32).init(allocator);

    inline for (item_files) |item_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ item_name ++ ".xml");
        defer doc.deinit();
        parseItems(doc, allocator) catch |e| {
            std.log.err("Item parsing error: {any} {any}", .{ e, @errorReturnTrace() orelse return });
        };
    }

    inline for (object_files) |object_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ object_name ++ ".xml");
        defer doc.deinit();
        parseObjects(doc, allocator) catch |e| {
            std.log.err("Object parsing error: {any} {any}", .{ e, @errorReturnTrace() orelse return });
        };
    }

    inline for (ground_files) |ground_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ ground_name ++ ".xml");
        defer doc.deinit();
        parseGrounds(doc, allocator) catch |e| {
            std.log.err("Ground parsing error: {any} {any}", .{ e, @errorReturnTrace() orelse return });
        };
    }

    inline for (region_files) |region_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ region_name ++ ".xml");
        defer doc.deinit();
        parseRegions(doc, allocator) catch |e| {
            std.log.err("Region parsing error: {any} {any}", .{ e, @errorReturnTrace() orelse return });
        };
    }

    const player_doc = try xml.Doc.fromFile(asset_dir ++ "xmls/Players.xml");
    defer player_doc.deinit();
    const player_root = try player_doc.getRootElement();
    var player_root_it = player_root.iterate(&.{}, "Object");

    var class_list = try utils.DynSlice(CharacterClass).init(14, allocator);
    defer class_list.deinit();
    while (player_root_it.next()) |node|
        try class_list.add(try CharacterClass.parse(node, allocator));
    classes = try allocator.dupe(CharacterClass, class_list.items());
}

pub fn deinit(allocator: std.mem.Allocator) void {
    var obj_id_iter = obj_type_to_name.valueIterator();
    while (obj_id_iter.next()) |id| {
        allocator.free(id.*);
    }

    var obj_props_iter = obj_type_to_props.valueIterator();
    while (obj_props_iter.next()) |prop| {
        allocator.free(prop.obj_id);
        allocator.free(prop.display_id);
        allocator.free(prop.death_sound);
        allocator.free(prop.hit_sound);

        if (prop.portrait) |tex_data| {
            allocator.free(tex_data.sheet);
        }

        for (prop.projectiles) |proj_prop| {
            for (proj_prop.texture_data) |tex| {
                allocator.free(tex.sheet);
            }
            allocator.free(proj_prop.texture_data);
            allocator.free(proj_prop.object_id);
            allocator.free(proj_prop.effects);
        }

        allocator.free(prop.projectiles);
    }

    var item_props_iter = item_type_to_props.valueIterator();
    while (item_props_iter.next()) |prop| {
        if (prop.stat_increments) |incr| {
            allocator.free(incr);
        }

        if (prop.activations) |activate| {
            for (activate) |data| {
                allocator.free(data.id);
                allocator.free(data.object_id);
            }

            allocator.free(activate);
        }

        if (prop.extra_tooltip_data) |data| {
            allocator.free(data);
        }

        allocator.free(prop.texture_data.sheet);
        allocator.free(prop.tier);
        allocator.free(prop.old_sound);
        allocator.free(prop.sound);
        allocator.free(prop.successor_id);
        allocator.free(prop.display_id);

        if (prop.projectile) |proj_prop| {
            for (proj_prop.texture_data) |tex| {
                allocator.free(tex.sheet);
            }
            allocator.free(proj_prop.texture_data);
            allocator.free(proj_prop.object_id);
            allocator.free(proj_prop.effects);
        }
    }

    var item_name_iter = item_type_to_name.valueIterator();
    while (item_name_iter.next()) |id| {
        allocator.free(id.*);
    }

    var ground_name_iter = ground_type_to_name.valueIterator();
    while (ground_name_iter.next()) |id| {
        allocator.free(id.*);
    }

    var ground_iter = ground_type_to_props.valueIterator();
    while (ground_iter.next()) |props| {
        allocator.free(props.obj_id);
    }

    var region_iter = region_type_to_name.valueIterator();
    while (region_iter.next()) |id| {
        allocator.free(id.*);
    }

    var ground_tex_iter = ground_type_to_tex_data.valueIterator();
    while (ground_tex_iter.next()) |tex_list| {
        for (tex_list.*) |tex| {
            allocator.free(tex.sheet);
        }
        allocator.free(tex_list.*);
    }

    var obj_tex_iter = obj_type_to_tex_data.valueIterator();
    while (obj_tex_iter.next()) |tex_list| {
        for (tex_list.*) |tex| {
            allocator.free(tex.sheet);
        }
        allocator.free(tex_list.*);
    }

    var obj_top_tex_iter = obj_type_to_top_tex_data.valueIterator();
    while (obj_top_tex_iter.next()) |tex_list| {
        for (tex_list.*) |tex| {
            allocator.free(tex.sheet);
        }
        allocator.free(tex_list.*);
    }

    for (classes) |class| {
        allocator.free(class.texture.sheet);
        allocator.free(class.hit_sound);
        allocator.free(class.death_sound);
        allocator.free(class.name);
        allocator.free(class.desc);
        allocator.free(class.slot_types);
        allocator.free(class.equipment);
    }

    allocator.free(classes);

    item_name_to_type.deinit();
    item_type_to_props.deinit();
    item_type_to_name.deinit();
    obj_name_to_type.deinit();
    obj_type_to_props.deinit();
    obj_type_to_name.deinit();
    obj_type_to_tex_data.deinit();
    obj_type_to_top_tex_data.deinit();
    obj_type_to_anim_data.deinit();
    obj_type_to_class.deinit();
    ground_name_to_type.deinit();
    ground_type_to_props.deinit();
    ground_type_to_name.deinit();
    ground_type_to_tex_data.deinit();
    region_type_to_name.deinit();
    region_type_to_color.deinit();
}

fn parseTexture(node: xml.Node, allocator: std.mem.Allocator) ![]TextureData {
    if (node.findChild("RandomTexture")) |random_tex_child| {
        var tex_iter = random_tex_child.iterate(&.{}, "Texture");
        var tex_list = try utils.DynSlice(TextureData).init(4, allocator);
        defer tex_list.deinit();
        while (tex_iter.next()) |tex_node| {
            try tex_list.add(try TextureData.parse(tex_node, allocator, false));
        }

        if (tex_list.capacity > 0) {
            return try allocator.dupe(TextureData, tex_list.items());
        } else {
            var anim_tex_iter = random_tex_child.iterate(&.{}, "AnimatedTexture");
            var anim_tex_list = try utils.DynSlice(TextureData).init(4, allocator);
            defer anim_tex_list.deinit();
            while (anim_tex_iter.next()) |tex_node| {
                try anim_tex_list.add(try TextureData.parse(tex_node, allocator, true));
            }

            return try allocator.dupe(TextureData, anim_tex_list.items());
        }
    } else {
        if (node.findChild("Texture")) |tex_child| {
            const ret = try allocator.alloc(TextureData, 1);
            ret[0] = try TextureData.parse(tex_child, allocator, false);
            return ret;
        } else {
            if (node.findChild("AnimatedTexture")) |anim_tex_child| {
                const ret = try allocator.alloc(TextureData, 1);
                ret[0] = try TextureData.parse(anim_tex_child, allocator, true);
                return ret;
            }
        }
    }

    return &[0]TextureData{};
}

pub fn parseItems(doc: xml.Doc, allocator: std.mem.Allocator) !void {
    const root = try doc.getRootElement();
    var iter = root.iterate(&.{}, "Object");
    while (iter.next()) |node| {
        const obj_type = try node.getAttributeInt("type", u16, 0);
        const id = try node.getAttributeAlloc("id", allocator, "Unknown");
        try item_name_to_type.put(id, obj_type);
        try item_type_to_props.put(obj_type, try ItemProps.parse(node, allocator));
        try item_type_to_name.put(obj_type, id);
    }
}

pub fn parseObjects(doc: xml.Doc, allocator: std.mem.Allocator) !void {
    const root = try doc.getRootElement();
    var iter = root.iterate(&.{}, "Object");
    while (iter.next()) |node| {
        const obj_type = try node.getAttributeInt("type", u16, 0);
        const id = try node.getAttributeAlloc("id", allocator, "Unknown");
        try obj_type_to_class.put(obj_type, ClassType.fromString(node.getValue("Class") orelse "GameObject"));
        try obj_name_to_type.put(id, obj_type);
        try obj_type_to_props.put(obj_type, try ObjProps.parse(node, allocator));
        try obj_type_to_name.put(obj_type, id);

        try obj_type_to_tex_data.put(obj_type, try parseTexture(node, allocator));

        if (node.findChild("Top")) |top_tex_child| {
            try obj_type_to_top_tex_data.put(obj_type, try parseTexture(top_tex_child, allocator));
        }
    }
}

pub fn parseGrounds(doc: xml.Doc, allocator: std.mem.Allocator) !void {
    const root = try doc.getRootElement();
    var iter = root.iterate(&.{}, "Ground");
    while (iter.next()) |node| {
        const obj_type = try node.getAttributeInt("type", u16, 0);
        const id = try node.getAttributeAlloc("id", allocator, "Unknown");
        try ground_name_to_type.put(id, obj_type);
        try ground_type_to_props.put(obj_type, try GroundProps.parse(node, allocator));
        try ground_type_to_name.put(obj_type, id);

        if (node.findChild("RandomTexture")) |random_tex_child| {
            var tex_iter = random_tex_child.iterate(&.{}, "Texture");
            var tex_list = try utils.DynSlice(TextureData).init(4, allocator);
            defer tex_list.deinit();
            while (tex_iter.next()) |tex_node| {
                try tex_list.add(try TextureData.parse(tex_node, allocator, false));
            }
            try ground_type_to_tex_data.put(obj_type, try allocator.dupe(TextureData, tex_list.items()));
        } else {
            if (node.findChild("Texture")) |tex_child| {
                const ret = try allocator.alloc(TextureData, 1);
                ret[0] = try TextureData.parse(tex_child, allocator, false);
                try ground_type_to_tex_data.put(obj_type, ret);
            }
        }
    }
}

pub fn parseRegions(doc: xml.Doc, allocator: std.mem.Allocator) !void {
    const root = try doc.getRootElement();
    var iter = root.iterate(&.{}, "Region");
    while (iter.next()) |node| {
        const obj_type = try node.getAttributeInt("type", u16, 0);
        const id = try node.getAttributeAlloc("id", allocator, "Unknown");
        try region_type_to_name.put(obj_type, id);
        try region_type_to_color.put(obj_type, try node.getValueInt("Color", u32, 0));
    }
}
