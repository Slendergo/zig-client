const std = @import("std");
const zglfw = @import("zglfw");
const builtin = @import("builtin");
const assets = @import("assets.zig");
const ini = @import("ini");
const main = @import("main.zig");

pub const LogType = enum(u8) {
    all = 0,
    all_non_tick = 1,
    c2s = 2,
    c2s_non_tick = 3,
    c2s_tick = 4,
    s2c = 5,
    s2c_non_tick = 6,
    s2c_tick = 7,
    off = 255,
};

pub const CursorType = enum(u8) {
    basic = 0,
    royal = 1,
    ranger = 2,
    aztec = 3,
    fiery = 4,
    target_enemy = 5,
    target_ally = 6,
};

pub const AaType = enum(u8) {
    none = 0,
    fxaa = 1, // not implemented yet
    msaa2x = 2,
    msaa4x = 3,
};

pub const Button = union(enum) {
    key: zglfw.Key,
    mouse: zglfw.MouseButton,

    pub fn getKey(self: Button) zglfw.Key {
        switch (self) {
            .key => |key| return key,
            .mouse => |_| return .unknown,
        }
    }

    pub fn getMouse(self: Button) zglfw.MouseButton {
        switch (self) {
            .key => |_| return .unknown,
            .mouse => |mouse| return mouse,
        }
    }

    pub fn getName(self: Button) [:0]const u8 {
        switch (self) {
            .key => |key| return getKeyNameOrNone(key),
            .mouse => |mouse| return getMouseNameOrNone(mouse),
        }
    }

    fn getKeyNameOrNone(key: zglfw.Key) [:0]const u8 {
        if (key == .unknown)
            return "None";
        return @tagName(key);
    }

    fn getMouseNameOrNone(mouse: zglfw.MouseButton) [:0]const u8 {
        if (mouse == .unknown)
            return "None";
        return @tagName(mouse);
    }

    pub fn getSettingsInt(self: Button) i32 {
        switch (self) {
            .key => |key| return @intFromEnum(key),
            .mouse => |mouse| return @intFromEnum(mouse),
        }
    }
};

//Format of the .ini file
//Name SHOULD be the same as the Button variable name its refering to
//Name and *Button variable MUST be assigned to name_key_map inside of the init fn
//name=value
const data_fmt =
    \\[Settings]
    \\move_left={d}
    \\move_right={d}
    \\move_down={d}
    \\move_up={d}
    \\shoot={d}
;

pub const build_version = "0.5";
pub const app_engine_url = "http://127.0.0.1:8080/";
pub const log_packets = LogType.off;
pub const print_atlas = false;
pub const print_ui_atlas = false;
pub const rotate_speed = 0.002;
pub const enable_tracy = false;
pub const unset_key_tex_idx: u16 = 0x68;
pub var key_tex_map: std.AutoHashMap(Button, u16) = undefined;
pub var name_key_map: std.StringHashMap(*Button) = undefined;
pub var interact_key_tex: assets.AtlasData = undefined;
pub var inv_0 = Button{ .key = .one };
pub var inv_1 = Button{ .key = .two };
pub var inv_2 = Button{ .key = .three };
pub var inv_3 = Button{ .key = .four };
pub var inv_4 = Button{ .key = .five };
pub var inv_5 = Button{ .key = .six };
pub var inv_6 = Button{ .key = .seven };
pub var inv_7 = Button{ .key = .eight };
pub var move_left = Button{ .key = .a };
pub var move_right = Button{ .key = .d };
pub var move_up = Button{ .key = .w };
pub var move_down = Button{ .key = .s };
pub var rotate_left = Button{ .key = .q };
pub var rotate_right = Button{ .key = .e };
pub var interact = Button{ .key = .r };
pub var options = Button{ .key = .escape };
pub var escape = Button{ .key = .tab };
pub var chat_up = Button{ .key = .page_up };
pub var chat_down = Button{ .key = .page_down };
pub var walk = Button{ .key = .left_shift };
pub var reset_camera = Button{ .key = .z };
pub var toggle_stats = Button{ .key = .F3 };
pub var chat = Button{ .key = .enter };
pub var chat_cmd = Button{ .key = .slash };
pub var respond = Button{ .key = .F2 };
pub var toggle_centering = Button{ .key = .x };
pub var shoot = Button{ .mouse = .left };
pub var ability = Button{ .mouse = .right };
pub var sfx_volume: f32 = 0.0; // 0.33;
pub var music_volume: f32 = 0.0; // 0.1;
pub var enable_glow = true;
pub var enable_lights = true;
pub var enable_vsync = true;
pub var always_show_xp_gain = true;
pub var stats_enabled = true;
pub var fps_cap: f32 = 360.0; // 0 to disable
pub var selected_cursor = CursorType.aztec;
pub var aa_type = AaType.msaa4x;
pub var save_email = true;

pub fn init(allocator: std.mem.Allocator) !void {
    _ = try createFile(allocator);
    key_tex_map = std.AutoHashMap(Button, u16).init(allocator);
    name_key_map = std.StringHashMap(*Button).init(allocator);

    try key_tex_map.put(.{ .mouse = .left }, 0x2e);
    try key_tex_map.put(.{ .mouse = .right }, 0x3b);
    try key_tex_map.put(.{ .mouse = .middle }, 0x3a);
    try key_tex_map.put(.{ .mouse = .four }, 0x6c);
    try key_tex_map.put(.{ .mouse = .five }, 0x6d);
    try key_tex_map.put(.{ .key = .zero }, 0x00);
    try key_tex_map.put(.{ .key = .one }, 0x04);
    try key_tex_map.put(.{ .key = .two }, 0x05);
    try key_tex_map.put(.{ .key = .three }, 0x06);
    try key_tex_map.put(.{ .key = .four }, 0x07);
    try key_tex_map.put(.{ .key = .five }, 0x08);
    try key_tex_map.put(.{ .key = .six }, 0x10);
    try key_tex_map.put(.{ .key = .seven }, 0x11);
    try key_tex_map.put(.{ .key = .eight }, 0x12);
    try key_tex_map.put(.{ .key = .nine }, 0x13);
    try key_tex_map.put(.{ .key = .kp_0 }, 0x5b);
    try key_tex_map.put(.{ .key = .kp_1 }, 0x5c);
    try key_tex_map.put(.{ .key = .kp_2 }, 0x5d);
    try key_tex_map.put(.{ .key = .kp_3 }, 0x5e);
    try key_tex_map.put(.{ .key = .kp_4 }, 0x5f);
    try key_tex_map.put(.{ .key = .kp_5 }, 0x60);
    try key_tex_map.put(.{ .key = .kp_6 }, 0x61);
    try key_tex_map.put(.{ .key = .kp_7 }, 0x62);
    try key_tex_map.put(.{ .key = .kp_8 }, 0x63);
    try key_tex_map.put(.{ .key = .kp_9 }, 0x64);
    try key_tex_map.put(.{ .key = .F1 }, 0x44);
    try key_tex_map.put(.{ .key = .F2 }, 0x45);
    try key_tex_map.put(.{ .key = .F3 }, 0x46);
    try key_tex_map.put(.{ .key = .F4 }, 0x47);
    try key_tex_map.put(.{ .key = .F5 }, 0x48);
    try key_tex_map.put(.{ .key = .F6 }, 0x50);
    try key_tex_map.put(.{ .key = .F7 }, 0x51);
    try key_tex_map.put(.{ .key = .F8 }, 0x52);
    try key_tex_map.put(.{ .key = .F9 }, 0x53);
    try key_tex_map.put(.{ .key = .F10 }, 0x01);
    try key_tex_map.put(.{ .key = .F11 }, 0x02);
    try key_tex_map.put(.{ .key = .F12 }, 0x03);
    try key_tex_map.put(.{ .key = .a }, 0x14);
    try key_tex_map.put(.{ .key = .b }, 0x22);
    try key_tex_map.put(.{ .key = .c }, 0x27);
    try key_tex_map.put(.{ .key = .d }, 0x32);
    try key_tex_map.put(.{ .key = .e }, 0x34);
    try key_tex_map.put(.{ .key = .f }, 0x54);
    try key_tex_map.put(.{ .key = .g }, 0x55);
    try key_tex_map.put(.{ .key = .h }, 0x56);
    try key_tex_map.put(.{ .key = .i }, 0x58);
    try key_tex_map.put(.{ .key = .j }, 0x3f);
    try key_tex_map.put(.{ .key = .k }, 0x4a);
    try key_tex_map.put(.{ .key = .l }, 0x4b);
    try key_tex_map.put(.{ .key = .m }, 0x4c);
    try key_tex_map.put(.{ .key = .n }, 0x3d);
    try key_tex_map.put(.{ .key = .o }, 0x41);
    try key_tex_map.put(.{ .key = .p }, 0x42);
    try key_tex_map.put(.{ .key = .q }, 0x19);
    try key_tex_map.put(.{ .key = .r }, 0x1c);
    try key_tex_map.put(.{ .key = .s }, 0x1d);
    try key_tex_map.put(.{ .key = .t }, 0x49);
    try key_tex_map.put(.{ .key = .u }, 0x43);
    try key_tex_map.put(.{ .key = .v }, 0x1f);
    try key_tex_map.put(.{ .key = .w }, 0x0a);
    try key_tex_map.put(.{ .key = .x }, 0x0c);
    try key_tex_map.put(.{ .key = .y }, 0x0d);
    try key_tex_map.put(.{ .key = .z }, 0x0e);
    try key_tex_map.put(.{ .key = .up }, 0x20);
    try key_tex_map.put(.{ .key = .down }, 0x16);
    try key_tex_map.put(.{ .key = .left }, 0x17);
    try key_tex_map.put(.{ .key = .right }, 0x18);
    try key_tex_map.put(.{ .key = .left_shift }, 0x0f);
    try key_tex_map.put(.{ .key = .right_shift }, 0x09);
    try key_tex_map.put(.{ .key = .left_bracket }, 0x25);
    try key_tex_map.put(.{ .key = .right_bracket }, 0x26);
    try key_tex_map.put(.{ .key = .left_control }, 0x31);
    try key_tex_map.put(.{ .key = .right_control }, 0x31);
    try key_tex_map.put(.{ .key = .left_alt }, 0x15);
    try key_tex_map.put(.{ .key = .right_alt }, 0x15);
    try key_tex_map.put(.{ .key = .comma }, 0x65);
    try key_tex_map.put(.{ .key = .period }, 0x66);
    try key_tex_map.put(.{ .key = .slash }, 0x67);
    try key_tex_map.put(.{ .key = .backslash }, 0x29);
    try key_tex_map.put(.{ .key = .semicolon }, 0x1e);
    try key_tex_map.put(.{ .key = .minus }, 0x2d);
    try key_tex_map.put(.{ .key = .equal }, 0x2a);
    try key_tex_map.put(.{ .key = .tab }, 0x4f);
    try key_tex_map.put(.{ .key = .space }, 0x39);
    try key_tex_map.put(.{ .key = .backspace }, 0x23);
    try key_tex_map.put(.{ .key = .enter }, 0x36);
    try key_tex_map.put(.{ .key = .delete }, 0x33);
    try key_tex_map.put(.{ .key = .end }, 0x35);
    try key_tex_map.put(.{ .key = .print_screen }, 0x2c);
    try key_tex_map.put(.{ .key = .insert }, 0x3e);
    try key_tex_map.put(.{ .key = .escape }, 0x40);
    try key_tex_map.put(.{ .key = .home }, 0x57);
    try key_tex_map.put(.{ .key = .page_up }, 0x59);
    try key_tex_map.put(.{ .key = .page_down }, 0x5a);
    try key_tex_map.put(.{ .key = .caps_lock }, 0x28);
    try key_tex_map.put(.{ .key = .kp_add }, 0x2b);
    try key_tex_map.put(.{ .key = .kp_subtract }, 0x6b);
    try key_tex_map.put(.{ .key = .kp_multiply }, 0x21);
    try key_tex_map.put(.{ .key = .kp_divide }, 0x6a);
    try key_tex_map.put(.{ .key = .kp_decimal }, 0x69);
    try key_tex_map.put(.{ .key = .kp_enter }, 0x38);

    try key_tex_map.put(.{ .key = .left_super }, if (builtin.os.tag == .windows) 0x0b else 0x30);
    try key_tex_map.put(.{ .key = .right_super }, if (builtin.os.tag == .windows) 0x0b else 0x30);

    const tex_list = assets.atlas_data.get("keyIndicators");
    if (tex_list) |list| {
        interact_key_tex = list[key_tex_map.get(interact) orelse unset_key_tex_idx];
    }

    try name_key_map.put("move_up", &move_up);
    try name_key_map.put("move_down", &move_down);
    try name_key_map.put("move_right", &move_right);
    try name_key_map.put("move_left", &move_left);
    try name_key_map.put("shoot", &shoot);

    _ = try parseSettings(allocator);
}

pub fn getKeyTexture(button: Button) assets.AtlasData {
    const tex_list = assets.atlas_data.get("keyIndicators");
    if (tex_list == null)
        @panic("Key texture parsing failed, the keyIndicators sheet is missing");

    return tex_list.?[key_tex_map.get(button) orelse unset_key_tex_idx];
}

pub fn deinit() void {
    key_tex_map.deinit();
}

//Parses settings.ini file and sets found values to proper Button variables
fn parseSettings(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("settings.ini", .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    var writer = std.io.getStdOut().writer();
    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                //try writer.print("{s} = {s}\n", .{ kv.key, kv.value });

                if (name_key_map.get(kv.key)) |button| {
                    const value: i32 = try std.fmt.parseInt(
                        i32,
                        kv.value,
                        10,
                    );
                    //Mouse value
                    var key: zglfw.Key = .unknown;
                    var mouse_button: zglfw.MouseButton = .unknown;

                    if (value >= 0 and value < 8) {
                        mouse_button = @enumFromInt(value);
                        button.* = .{ .mouse = mouse_button };
                        //try writer.print("Bound {d} to mouse {s}\n", .{ value, kv.key });
                    } else if (value > -1) {
                        key = @enumFromInt(value);
                        button.* = .{ .key = key };
                        //try writer.print("Bound {d} to key {s}\n", .{ value, kv.key });
                    } else {
                        //try writer.print("Value {d} is not valid\n", .{value});
                        continue;
                    }
                } else {
                    try writer.print("Settings key {s} doesn't exist in string map\n", .{kv.key});
                }
            },
            else => continue,
        }
    }
}

//Saves default values to file to make sure a file exists
//Probably not needed?
fn createFile(allocator: std.mem.Allocator) !void {
    var file = std.fs.cwd().createFile("settings.ini", .{ .exclusive = true }) catch |e|
        switch (e) {
        error.PathAlreadyExists => {
            std.log.info("settings file already exists, not overwriting", .{});
            return;
        },
        else => return e,
    };
    defer file.close();

    const arr = try allocator.alloc(u8, 1024);
    _ = try file.write(try formatData(arr));
}

//Called when options ui is closed or key mapper values get changed
//overwrites ini file with latest settings values
pub fn save(backing_arr: []u8) !void {
    var file = try std.fs.cwd().createFile("settings.ini", .{});
    defer file.close();

    _ = try file.write(try formatData(backing_arr));
}

//formats data_fmt with settings values
//Add Button values here
//The order MATTERS! Same order as data_fmt
fn formatData(backing_arr: []u8) ![]u8 {
    return try std.fmt.bufPrint(backing_arr, data_fmt, .{ move_left.getSettingsInt(), move_right.getSettingsInt(), move_down.getSettingsInt(), move_up.getSettingsInt(), shoot.getSettingsInt() });
}

pub fn resetToDefault() void {
    inv_0 = .{ .key = .one };
    inv_1 = .{ .key = .two };
    inv_2 = .{ .key = .three };
    inv_3 = .{ .key = .four };
    inv_4 = .{ .key = .five };
    inv_5 = .{ .key = .six };
    inv_6 = .{ .key = .seven };
    inv_7 = .{ .key = .eight };
    move_left = .{ .key = .a };
    move_right = .{ .key = .d };
    move_up = .{ .key = .w };
    move_down = .{ .key = .s };
    rotate_left = .{ .key = .q };
    rotate_right = .{ .key = .e };
    interact = .{ .key = .r };
    options = .{ .key = .escape };
    escape = .{ .key = .tab };
    chat_up = .{ .key = .page_up };
    chat_down = .{ .key = .page_down };
    walk = .{ .key = .left_shift };
    reset_camera = .{ .key = .z };
    toggle_stats = .{ .key = .F3 };
    chat = .{ .key = .enter };
    chat_cmd = .{ .key = .slash };
    respond = .{ .key = .F2 };
    toggle_centering = .{ .key = .x };
    shoot = .{ .mouse = .left };
    ability = .{ .mouse = .right };
    sfx_volume = 0.33;
    music_volume = 0.33;
    enable_glow = false;
    enable_lights = false;
    enable_vsync = false;
    always_show_xp_gain = false;
    fps_cap = 360.0;
    selected_cursor = CursorType.aztec;
    aa_type = .none; //.msaa4x; //caused the client to crash switching from none to msaa4x
    save_email = true;
}
