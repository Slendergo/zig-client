const std = @import("std");
const settings = @import("settings.zig");

var client: std.http.Client = undefined;
var headers: std.http.Headers = undefined;
var buffer: [std.math.maxInt(u16)]u8 = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    client = std.http.Client{ .allocator = allocator };
    headers = std.http.Headers{ .allocator = allocator };
}

pub fn deinit() void {
    client.deinit();
    headers.deinit();
}

pub fn sendCharList(email: []const u8, password: []const u8) ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "char/list") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send char/list (params: email={s}, password={s}): {any}\n", .{ email, password, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("email=");
    try writer.writeAll(email);
    try writer.writeAll("&password=");
    try writer.writeAll(password);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendCharDelete(email: []const u8, password: []const u8, char_id: []const u8) ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "char/delete") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send char/delete (params: email={s}, password={s}, charId={s}): {any}\n", .{ email, password, char_id, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("email=");
    try writer.writeAll(email);
    try writer.writeAll("&password=");
    try writer.writeAll(password);
    try writer.writeAll("&charId=");
    try writer.writeAll(char_id);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendAccountVerify(email: []const u8, password: []const u8) ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "account/verify") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send account/verify (params: email={s}, password={s}): {any}\n", .{ email, password, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("email=");
    try writer.writeAll(email);
    try writer.writeAll("&password=");
    try writer.writeAll(password);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendAccountRegister(email: []const u8, password: []const u8, name: []const u8) ![]const u8 {
    _ = name; // todo: add name to registering
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "account/register") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send account/register (params: email={s}, password={s}): {any}\n", .{ email, password, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("guid=");
    try writer.writeAll("0"); // Server requires randomized GUID, leaving it as 0 for now
    try writer.writeAll("newGUID=");
    try writer.writeAll(email);
    try writer.writeAll("&newPassword=");
    try writer.writeAll(password);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendAccountChangePassword(email: []const u8, password: []const u8, newPassword: []const u8) ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "account/changePassword") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send account/changePassword (params: email={s}, password={s}, newPassword={s}): {any}\n", .{ email, password, newPassword, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("email=");
    try writer.writeAll(email);
    try writer.writeAll("&password=");
    try writer.writeAll(password);
    try writer.writeAll("&newPassword=");
    try writer.writeAll(newPassword);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendAccountSetName(email: []const u8, password: []const u8, name: []const u8) ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "account/setName") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send account/setName (params: email={s}, password={s}, name={s}): {any}\n", .{ email, password, name, e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    const writer = req.writer();
    try writer.writeAll("email=");
    try writer.writeAll(email);
    try writer.writeAll("&password=");
    try writer.writeAll(password);
    try writer.writeAll("&name=");
    try writer.writeAll(name);
    try req.finish();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}

pub fn sendAppInit() ![]const u8 {
    var req = client.request(std.http.Method.POST, std.Uri.parse(settings.app_engine_url ++ "app/init") catch unreachable, headers, .{ .max_redirects = 0 }) catch |e| {
        std.log.err("Could not send app/init: {any}\n", .{ e });
        return "<Error />";
    };

    defer req.deinit();
    req.transfer_encoding = .chunked;
    try req.start();
    try req.wait();
    const len = try req.readAll(&buffer);
    return buffer[0..len];
}