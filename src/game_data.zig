const std = @import("std");
const xml = @import("xml.zig");
const utils = @import("utils.zig");
const asset_dir = @import("build_options").asset_dir;

const item_files = [_][]const u8{ "Equip", "Dyes", "Textiles" };
// zig fmt: off
const object_files = [_][]const u8{
    "Projectiles",          "WillemTesting",       "MountainTempleObject",
    "TTesting",             "BTesting",            "STesting",
    "MTesting",             "KTesting",            "Players",
    "Containers",           "Objects",             "Portals",
    "TestingObjects",       "StaticObjects",       "TutorialObjects",
    "TutorialMonsters",     "Allies",              "Heroes",
    "PlayersZombies",       "Pets",                "NPCs",
    "Shore",                "Low",                 "Mid",
    "High",                 "Mountains",           "Encounters",
    "Arena",                "OryxCastle",          "TombOfTheAncients",
    "SpriteWorld",          "UndeadLair",          "OceanTrench",
    "ForbiddenJungle",      "OryxChamber",         "OryxChickenChamber",
    "OryxWineCellar",       "ManorOfTheImmortals", "PirateCave",
    "SnakePit",             "SpiderDen",           "AbyssOfDemons",
    "GhostShip",            "MadLab",              "CaveOfAThousandTreasures",
    "CandyLand",            "HauntedCemetery",     "ForestMaze",
    "EpicForestMaze",       "EpicPirateCave",      "EpicSpiderDen",
    "NexusDestroyed",       "MiniDungeonHub",      "LairOfDraconis",
    "LairOfShaitan",        "Shatters",            "Belladonna",
    "PuppetMaster",         "IceCave",             "TheHive",
    "ToxicSewers",          "PuppetMasterEncore",  "IceTomb",
    "StPatricksObject",     "BuffedBunnyObject",   "HanamiNexusObject",
};
// zig fmt: on
const ground_files = [_][]const u8{ "Ground", "StPatricksGround", "HanamiNexusGround", "MountainTempleGround" };

const region_files = [_][]const u8{"Regions"};

pub const ClassType = enum(u8) {
    arena_guard = 0,
    arena_portal = 1,
    cave_wall = 2,
    character = 3,
    character_changer = 4,
    closed_gift_chest = 5,
    closed_vault_chest = 6,
    connected_wall = 7,
    container = 8,
    daily_login_rewards = 9,
    double_wall = 10,
    fortune_ground = 11,
    fortune_teller = 12,
    game_object = 13,
    guild_board = 14,
    guild_chronicle = 15,
    guild_hall_portal = 16,
    guild_merchant = 17,
    guild_register = 18,
    merchant = 19,
    money_changer = 20,
    mystery_box_ground = 21,
    name_changer = 22,
    one_way_container = 23,
    pet = 24,
    pet_upgrader = 25,
    player = 26,
    portal = 27,
    projectile = 28,
    quest_rewards = 29,
    reskin_vendor = 30,
    sign = 31,
    spider_web = 32,
    stalagmite = 33,
    wall = 34,
    yard_upgrader = 35,

    const map = std.ComptimeStringMap(ClassType, .{
        .{ "ArenaGuard", .arena_guard },
        .{ "ArenaPortal", .arena_portal },
        .{ "CaveWall", .cave_wall },
        .{ "Character", .character },
        .{ "CharacterChanger", .character_changer },
        .{ "ClosedGiftChest", .closed_gift_chest },
        .{ "ClosedVaultChest", .closed_vault_chest },
        .{ "ConnectedWall", .connected_wall },
        .{ "Container", .container },
        .{ "DailyLoginRewards", .daily_login_rewards },
        .{ "DoubleWall", .double_wall },
        .{ "FortuneGround", .fortune_ground },
        .{ "FortuneTeller", .fortune_teller },
        .{ "GameObject", .game_object },
        .{ "GuildBoard", .guild_board },
        .{ "GuildChronicle", .guild_chronicle },
        .{ "GuildHallPortal", .guild_hall_portal },
        .{ "GuildMerchant", .guild_merchant },
        .{ "GuildRegister", .guild_register },
        .{ "Merchant", .merchant },
        .{ "MoneyChanger", .money_changer },
        .{ "MysteryBoxGround", .mystery_box_ground },
        .{ "NameChanger", .name_changer },
        .{ "OneWayContainer", .one_way_container },
        .{ "Pet", .pet },
        .{ "PetUpgrader", .pet_upgrader },
        .{ "Player", .player },
        .{ "Portal", .portal },
        .{ "Projectile", .projectile },
        .{ "QuestRewards", .quest_rewards },
        .{ "ReskinVendor", .reskin_vendor },
        .{ "Sign", .sign },
        .{ "SpiderWeb", .spider_web },
        .{ "Stalagmite", .stalagmite },
        .{ "Wall", .wall },
        .{ "YardUpgrader", .yard_upgrader },
    });

    pub fn fromString(str: []const u8) ClassType {
        return map.get(str) orelse .game_object;
    }
};

pub const TextureData = struct {
    sheet: []const u8,
    index: u16,
    animated: bool,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator, animated: bool) !TextureData {
        return TextureData {
            .sheet = try node.getValueAlloc("Sheet", allocator, "Unknown"),
            .index = try node.getValueInt("Index", u16, 0),
            .animated = animated,
        };
    }
    // zig fmt: on
};

pub const CharacterSkin = struct {
    obj_type: u16,
    name: []const u8,
    texture: TextureData,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) CharacterSkin {
        return CharacterSkin {
            .objType = try node.getAttributeInt("type", u16, 0),
            .name = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .texture = try TextureData.parse(node.findChild("AnimatedTexture") orelse @panic("Could not parse CharacterClass"), allocator, false),
        };
    }
    // zig fmt: on
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

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !CharacterClass {
        var slot_list = std.ArrayList(i8).init(allocator);
        defer slot_list.deinit();
        var slot_iter = std.mem.split(u8, node.getValue("SlotTypes") orelse "", ", ");
        while (slot_iter.next()) |s|
            try slot_list.append(try std.fmt.parseInt(i8, s, 0));

        var equip_list = std.ArrayList(i16).init(allocator);
        defer equip_list.deinit();
        var equip_iter = std.mem.split(u8, node.getValue("Equipment") orelse "", ", ");
        while (equip_iter.next()) |s|
            try equip_list.append(try std.fmt.parseInt(i16, s, 0));

        return CharacterClass {
            .obj_type = try node.getAttributeInt("type", u16, 0),
            .name = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .desc = try node.getValueAlloc("Description", allocator, "Unknown"),
            .hit_sound = try node.getValueAlloc("HitSound", allocator, "Unknown"),
            .death_sound = try node.getValueAlloc("DeathSound", allocator, "Unknown"),
            .blood_prob = try node.getAttributeFloat("BloodProb", f32, 0.0),
            .slot_types = slot_list.items,
            .equipment = equip_list.items,
            .texture = try TextureData.parse(node.findChild("AnimatedTexture") orelse @panic("Could not parse CharacterClass"), allocator, false),
            .skins = null
        };
    }
    // zig fmt: on
};

pub const AnimFrame = struct {
    time: u16,
    tex: TextureData,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) AnimFrame {
        return AnimFrame {
            .time = try node.getAttributeFloat("time", f32, 0.0) * 1000,
            .tex = TextureData.parse(node.findChild("Texture"), allocator, false)
        };
    }
    // zig fmt: on
};

pub const AnimProps = struct {
    prob: f32,
    period: u16,
    period_jitter: u16,
    sync: bool,
    frames: []AnimFrame,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) AnimProps {
        var frame_list = std.ArrayList(AnimFrame).init(allocator);
        defer frame_list.deinit();
        var frame_iter = node.iterate(&.{}, "Frame");
        while (frame_iter.next()) |animNode|
            try frame_list.append(AnimFrame.parse(animNode, allocator));

        return AnimProps {
            .prob = try node.getAttributeFloat("prob", f32, 0.0),
            .period = try node.getAttributeInt("period", u16, 0),
            .period_jitter = try node.getAttributeInt("periodJitter", u16, 0),
            .sync = node.attributeExists("sync"),
            .frames = frame_list.items
        };
    }
    // zig fmt: on
};

pub const GroundProps = struct {
    obj_type: u16,
    obj_id: []const u8,
    no_walk: bool,
    damage: u16,
    blend_prio: i16,
    speed: f32,
    sink: bool,
    light_color: i32,
    light_intensity: f32,
    light_radius: f32,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !GroundProps {
        return GroundProps {
            .obj_type = try node.getAttributeInt("node", u16, 0),
            .obj_id = try node.getAttributeAlloc("id", allocator, "Unknown"),
            .no_walk = node.elementExists("NoWalk"),
            .damage = try node.getValueInt("Damage", u16, 0),
            .blend_prio = try node.getValueInt("BlendPriority", i16, 0),
            .speed = try node.getValueFloat("Speed", f32, 0.0),
            .sink = node.elementExists("Sink"),
            .light_color = try node.getValueInt("LightColor", i32, -1),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
        };
    }
    // zig fmt: on
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
    static: bool,
    no_mini_map: bool,
    ground_damage_immune: bool,
    sink_immune: bool,
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
    light_color: i32,
    light_intensity: f32,
    light_radius: f32,
    alpha_mult: f32,
    projectiles: []ProjProps,
    hit_sound: []const u8,
    death_sound: []const u8,

    // zig fmt: off
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
        var proj_list = std.ArrayList(ProjProps).init(allocator);
        defer proj_list.deinit();
        while (proj_it.next()) |proj_node|
            try proj_list.append(try ProjProps.parse(proj_node, allocator));

        const float_node = node.findChild("Float");
        return ObjProps {
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
            .static = node.elementExists("Static"),
            .no_mini_map = node.elementExists("NoMiniMap"),
            .ground_damage_immune = node.elementExists("ProtectFromGroundDamage"),
            .sink_immune = node.elementExists("ProtectFromSink"),
            .base_z = try node.getValueFloat("Z", f32, 0.0),
            .flying = node.elementExists("Flying"),
            .color = try node.getValueInt("Color", u32, 0xFFFFFF),
            .show_name = node.elementExists("ShowName"),
            .face_attacks = !node.elementExists("DontFaceAttacks"),
            .blood_probability = try node.getValueFloat("BloodProb", f32, 0.0),
            .blood_color = try node.getValueInt("BloodColor", u32, 0),
            .shadow_color = try node.getValueInt("ShadowColor", u32, 0),
            .portrait = if (node.elementExists("Portrait")) try TextureData.parse(node.findChild("Portrait").?, allocator, false) else null,
            .min_size = min_size,
            .max_size = max_size,
            .size_step = try node.getValueFloat("SizeStep", f32, 0.0) / 100.0,
            .angle_correction = try node.getValueFloat("AngleCorrection", f32, 0.0) * (std.math.pi / 4.0),
            .rotation = try node.getValueFloat("Rotation", f32, 0.0),
            .light_color = try node.getValueInt("LightColor", i32, -1),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
            .alpha_mult = try node.getValueFloat("AlphaMult", f32, 1.0),
            .float = float_node != null,
            .float_time = try std.fmt.parseInt(u16, if (float_node != null) float_node.?.getAttribute("time") orelse "0" else "0", 0),
            .float_height = try std.fmt.parseFloat(f32, if (float_node != null) float_node.?.getAttribute("height") orelse "0.0" else "0.0"),
            .float_sine = float_node != null and float_node.?.getAttribute("sine") != null,
            .projectiles = try allocator.dupe(ProjProps, proj_list.items),
            .hit_sound = try node.getAttributeAlloc("HitSound", allocator, "Unknown"),
            .death_sound = try node.getAttributeAlloc("DeathSound", allocator, "Unknown"),
        };
    }
    // zig fmt: on

    pub fn getSize(self: *const ObjProps) f32 {
        if (self.min_size == self.max_size)
            return self.min_size;

        const max_steps = std.math.round((self.max_size - self.min_size) / self.size_step);
        return self.min_size + std.math.round(utils.rng.random().float(f32) * max_steps) * self.size_step;
    }
};

pub const ProjProps = struct {
    texture_data: []TextureData,
    angle_correction: f32,
    rotation: f32,
    light_color: i32,
    light_intensity: f32,
    light_radius: f32,
    lifetime_ms: u16,
    speed: f32,
    size: f32,
    phys_dmg: u16,
    magic_dmg: u16,
    true_dmg: u16,
    piercing: bool,
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
    heat_seek_speed: f32,
    heat_seek_radius: f32,
    heat_seek_delay: u16,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ProjProps {
        return ProjProps {
            .texture_data = try parseTexture(node, allocator),
            .angle_correction = try node.getValueFloat("AngleCorrection", f32, 0.0) * (std.math.pi / 4.0),
            .rotation = try node.getValueFloat("Rotation", f32, 0.0),
            .light_color = try node.getValueInt("LightColor", i32, -1),
            .light_intensity = try node.getValueFloat("LightIntensity", f32, 0.1),
            .light_radius = try node.getValueFloat("LightRadius", f32, 1.0),
            .lifetime_ms = try node.getValueInt("LifetimeMS", u16, 0),
            .speed = try node.getValueFloat("Speed", f32, 0) / 10000.0,
            .size = try node.getValueFloat("Size", f32, 100.0) / 100.0,
            .phys_dmg = try node.getValueInt("Damage", u16, 0),
            .magic_dmg = try node.getValueInt("MagicDamage", u16, 0),
            .true_dmg = try node.getValueInt("TrueDamage", u16, 0),
            .piercing = node.elementExists("MultiHit"),
            .parametric = node.elementExists("Parametric"),
            .boomerang = node.elementExists("Boomerang"),
            .amplitude = try node.getValueFloat("Amplitude", f32, 0.0),
            .frequency = try node.getValueFloat("Frequency", f32, 0.0),
            .magnitude = try node.getValueFloat("Magnitude", f32, 0.0),
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
            .heat_seek_speed = try node.getValueFloat("HeatSeekSpeed", f32, 0.0) / 10000.0,
            .heat_seek_radius = try node.getValueFloat("HeatSeekRadius", f32, 0.0),
            .heat_seek_delay = try node.getValueInt("HeatSeekDelay", u16, 0),
        };
    }
    // zig fmt: on
};

pub const StatType = enum(u8) {
    hp = 0,
    size = 1,
    mp = 2,
    inv0 = 3,
    inv1 = 4,
    inv2 = 5,
    inv3 = 6,
    inv4 = 7,
    inv5 = 8,
    inv6 = 9,
    inv7 = 10,
    inv8 = 11,
    inv9 = 12,
    inv10 = 13,
    inv11 = 14,
    inv12 = 15,
    inv13 = 16,
    inv14 = 17,
    inv15 = 18,
    inv16 = 19,
    inv17 = 20,
    inv18 = 21,
    inv19 = 22,
    inv20 = 23,
    inv21 = 24,
    name = 25,
    merch_type = 26,
    merch_price = 27,
    merch_count = 28,
    gems = 29,
    gold = 30,
    crowns = 31,
    owner_account_id = 32,
    max_hp = 33,
    max_mp = 34,
    strength = 35,
    defense = 36,
    speed = 37,
    stamina = 38,
    wit = 39,
    resistance = 40,
    intelligence = 41,
    penetration = 42,
    piercing = 43,
    haste = 44,
    tenacity = 45,
    max_hp_boost = 46,
    max_mp_boost = 47,
    strength_boost = 48,
    defense_boost = 49,
    speed_boost = 50,
    stamina_boost = 51,
    wit_boost = 52,
    resistance_boost = 53,
    intelligence_boost = 54,
    penetration_boost = 55,
    piercing_boost = 56,
    haste_boost = 57,
    tenacity_boost = 58,
    condition = 59,
    tex_mask_1 = 60,
    tex_mask_2 = 61,
    sellable_price = 62,
    portal_usable = 63,
    acc_id = 64,
    level = 65,
    damage_multiplier = 66,
    hit_multiplier = 67,
    glow = 68,
    alt_texture = 69,
    guild_name = 70,
    guild_rank = 71,
    texture = 72,

    const map = std.ComptimeStringMap(StatType, .{
        .{ "MaxHP", .max_hp },
        .{ "MaxMP", .max_mp },
        .{ "Strength", .strength },
        .{ "Wit", .wit },
        .{ "Defense", .defense },
        .{ "Resistance", .resistance },
        .{ "Stamina", .stamina },
        .{ "Intelligence", .intelligence },
        .{ "Penetration", .penetration },
        .{ "Piercing", .piercing },
        .{ "Speed", .speed },
        .{ "Haste", .haste },
        .{ "Tenacity", .tenacity },
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
    open_portal,

    const map = std.ComptimeStringMap(ActivationType, .{
        .{ "IncrementStat", .increment_stat },
        .{ "Heal", .heal },
        .{ "Magic", .magic },
        .{ "UnlockSkin", .unlock_skin },
        .{ "OpenPortal", .open_portal },
    });

    pub fn fromString(str: []const u8) ActivationType {
        return map.get(str) orelse .increment_stat;
    }
};

pub const ActivationData = struct {
    type: ActivationType,

    // zig fmt: off
    pub fn parse(node: xml.Node) !ActivationData { // todo
        return ActivationData {
            .type = ActivationType.fromString(node.currentValue() orelse "IncrementStat"),
        };
    }
    // zig fmt: on
};

pub const StatIncrementData = struct {
    stat: StatType,
    amount: u16,

    // zig fmt: off
    pub fn parse(node: xml.Node) !StatIncrementData {
        return StatIncrementData {
            .stat = StatType.fromString(node.getAttribute("stat") orelse "MaxHP"),
            .amount = try node.getAttributeInt("amount", u16, 0),
        };
    }
    // zig fmt: on
};

pub const ItemProps = struct {
    consumable: bool,
    untradable: bool,
    slot_type: i8,
    tier_req: i8,
    bag_type: u8,
    num_projectiles: u8,
    arc_gap: f32,
    rate_of_fire: f32,
    tier: []const u8,
    texture_data: TextureData,
    projectile: ?ProjProps,
    stat_increments: []StatIncrementData,
    activations: []ActivationData,

    // zig fmt: off
    pub fn parse(node: xml.Node, allocator: std.mem.Allocator) !ItemProps {
        var incr_it = node.iterate(&.{}, "IncrementStat");
        var incr_list = std.ArrayList(StatIncrementData).init(allocator);
        defer incr_list.deinit();
        while (incr_it.next()) |incr_node|
            try incr_list.append(try StatIncrementData.parse(incr_node));

        var activate_it = node.iterate(&.{}, "Activate");
        var activate_list = std.ArrayList(ActivationData).init(allocator);
        defer activate_list.deinit();
        while (activate_it.next()) |activate_node|
            try activate_list.append(try ActivationData.parse(activate_node));

        return ItemProps {
            .consumable = node.elementExists("Consumable"),
            .untradable = node.elementExists("Untradable"),
            .slot_type = try node.getValueInt("SlotType", i8, 0),
            .tier_req = try node.getValueInt("TierReq", i8, 0),
            .bag_type = try node.getValueInt("BagType", u8, 0),
            .num_projectiles = try node.getValueInt("NumProjectiles", u8, 1),
            .arc_gap = std.math.degreesToRadians(f32, try node.getValueFloat("ArcGap", f32, 11.25)),
            .rate_of_fire = try node.getValueFloat("RateOfFire", f32, 1.0),
            .tier = try node.getValueAlloc("Tier", allocator, "Common"),
            .texture_data = try TextureData.parse(node.findChild("Texture").?, allocator, false),
            .projectile = if (node.elementExists("Projectile")) try ProjProps.parse(node.findChild("Projectile").?, allocator) else null,
            .stat_increments = try allocator.dupe(StatIncrementData, incr_list.items),
            .activations = try allocator.dupe(ActivationData, activate_list.items),
        };
    }
    // zig fmt: on
};

// zig fmt: off
pub const ItemType = enum(i8) {
    Weapon,
    Ability,
    Armor,
    Ring,
    Potion,
    StatPot,
    Other,
    None,
};
// zig fmt: on

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
            std.log.err("Item parsing error: {any} {any}", .{ e, @errorReturnTrace().? });
        };
    }

    inline for (object_files) |object_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ object_name ++ ".xml");
        defer doc.deinit();
        parseObjects(doc, allocator) catch |e| {
            std.log.err("Object parsing error: {any} {any}", .{ e, @errorReturnTrace().? });
        };
    }

    inline for (ground_files) |ground_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ ground_name ++ ".xml");
        defer doc.deinit();
        parseGrounds(doc, allocator) catch |e| {
            std.log.err("Ground parsing error: {any} {any}", .{ e, @errorReturnTrace().? });
        };
    }

    inline for (region_files) |region_name| {
        const doc = try xml.Doc.fromFile(asset_dir ++ "xmls/" ++ region_name ++ ".xml");
        defer doc.deinit();
        parseRegions(doc, allocator) catch |e| {
            std.log.err("Region parsing error: {any} {any}", .{ e, @errorReturnTrace().? });
        };
    }

    const player_doc = try xml.Doc.fromFile(asset_dir ++ "xmls/Players.xml");
    defer player_doc.deinit();
    const player_root = try player_doc.getRootElement();
    var player_root_it = player_root.iterate(&.{}, "Object");

    var class_list = std.ArrayList(CharacterClass).init(allocator);
    defer class_list.deinit();
    while (player_root_it.next()) |node|
        try class_list.append(try CharacterClass.parse(node, allocator));
    classes = try allocator.dupe(CharacterClass, class_list.items);
}

pub fn deinit(allocator: std.mem.Allocator) void {
    var obj_id_iter = obj_type_to_name.valueIterator();
    while (obj_id_iter.next()) |id| {
        allocator.free(id.*);
    }

    var obj_props_iter = obj_type_to_props.valueIterator();
    while (obj_props_iter.next()) |props| {
        allocator.free(props.obj_id);
        allocator.free(props.display_id);
        for (props.projectiles) |proj| {
            for (proj.texture_data) |tex| {
                allocator.free(tex.sheet);
            }
            allocator.free(proj.texture_data);
        }
        allocator.free(props.projectiles);
    }

    var item_props_iter = item_type_to_props.valueIterator();
    while (item_props_iter.next()) |props| {
        allocator.free(props.tier);
        if (props.projectile) |proj| {
            for (proj.texture_data) |tex| {
                allocator.free(tex.sheet);
            }
            allocator.free(proj.texture_data);
        }

        allocator.free(props.stat_increments);
        allocator.free(props.activations);
        allocator.free(props.texture_data.sheet);
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

inline fn parseTexture(node: xml.Node, allocator: std.mem.Allocator) ![]TextureData {
    const random_tex_child = node.findChild("RandomTexture");
    if (random_tex_child != null) {
        var tex_iter = random_tex_child.?.iterate(&.{}, "Texture");
        var tex_list = std.ArrayList(TextureData).init(allocator);
        defer tex_list.deinit();
        while (tex_iter.next()) |tex_node| {
            try tex_list.append(try TextureData.parse(tex_node, allocator, false));
        }

        if (tex_list.items.len > 0) {
            return try allocator.dupe(TextureData, tex_list.items);
        } else {
            var anim_tex_iter = random_tex_child.?.iterate(&.{}, "AnimatedTexture");
            var anim_tex_list = std.ArrayList(TextureData).init(allocator);
            defer anim_tex_list.deinit();
            while (anim_tex_iter.next()) |tex_node| {
                try anim_tex_list.append(try TextureData.parse(tex_node, allocator, true));
            }

            return try allocator.dupe(TextureData, anim_tex_list.items);
        }
    } else {
        const tex_child = node.findChild("Texture");
        if (tex_child != null) {
            const ret = try allocator.alloc(TextureData, 1);
            ret[0] = try TextureData.parse(tex_child orelse unreachable, allocator, false);
            return ret;
        } else {
            const anim_tex_child = node.findChild("AnimatedTexture");
            if (anim_tex_child != null) {
                const ret = try allocator.alloc(TextureData, 1);
                ret[0] = try TextureData.parse(anim_tex_child orelse unreachable, allocator, true);
                return ret;
            }
        }
    }

    return &[0]TextureData{};
}

pub fn parseItems(doc: xml.Doc, allocator: std.mem.Allocator) !void {
    const root = try doc.getRootElement();
    var iter = root.iterate(&.{}, "Item");
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

        const top_tex_child = node.findChild("Top");
        if (top_tex_child != null) {
            try obj_type_to_top_tex_data.put(obj_type, try parseTexture(top_tex_child.?, allocator));
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

        const random_tex_child = node.findChild("RandomTexture");
        if (random_tex_child != null) {
            var tex_iter = random_tex_child.?.iterate(&.{}, "Texture");
            var tex_list = std.ArrayList(TextureData).init(allocator);
            defer tex_list.deinit();
            while (tex_iter.next()) |tex_node| {
                try tex_list.append(try TextureData.parse(tex_node, allocator, false));
            }
            try ground_type_to_tex_data.put(obj_type, try allocator.dupe(TextureData, tex_list.items));
        } else {
            const tex_child = node.findChild("Texture");
            if (tex_child != null) {
                const ret = try allocator.alloc(TextureData, 1);
                ret[0] = try TextureData.parse(tex_child orelse unreachable, allocator, false);
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
