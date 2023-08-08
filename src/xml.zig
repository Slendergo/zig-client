const std = @import("std");
pub const c = @cImport({
    @cDefine("LIBXML_TREE_ENABLED", {});
    @cDefine("LIBXML_SCHEMAS_ENABLED", {});
    @cDefine("LIBXML_READER_ENABLED", {});
    @cInclude("libxml/xmlreader.h");
});

const Allocator = std.mem.Allocator;

pub const Attr = c.xmlAttr;
pub const readIo = c.xmlReadIO;
pub const cleanupParser = c.xmlCleanupParser;

pub const Node = struct {
    impl: *c.xmlNode,

    pub const Iterator = struct {
        node: ?Node,
        filter: []const u8,

        pub fn next(it: *Iterator) ?Node {
            return while (it.node != null) : (it.node = if (it.node.?.impl.next) |impl| Node{ .impl = impl } else null) {
                if (it.node.?.impl.type != 1)
                    continue;

                if (it.node.?.impl.name) |name|
                    if (std.mem.eql(u8, it.filter, std.mem.span(name))) {
                        const ret = it.node;
                        it.node = if (it.node.?.impl.next) |impl| Node{ .impl = impl } else null;
                        break ret;
                    };
            } else return null;
        }
    };

    pub const AttrIterator = struct {
        attr: ?*Attr,

        pub const Entry = struct {
            key: []const u8,
            value: []const u8,
        };

        pub fn next(it: *AttrIterator) ?Entry {
            return if (it.attr) |attr| ret: {
                if (attr.name) |name|
                    if (@as(*c.xmlNode, @ptrCast(attr.children)).content) |content| {
                        defer it.attr = attr.next;
                        break :ret Entry{
                            .key = std.mem.span(name),
                            .value = std.mem.span(content),
                        };
                    };
            } else null;
        }
    };

    pub fn getAttribute(node: Node, key: [:0]const u8) ?[]const u8 {
        if (c.xmlHasProp(node.impl, key.ptr)) |prop| {
            if (@as(*c.xmlAttr, @ptrCast(prop)).children) |value_node| {
                if (@as(*c.xmlNode, @ptrCast(value_node)).content) |content| {
                    return std.mem.span(content);
                }
            }
        }

        return null;
    }

    pub fn attributeExists(node: Node, key: [:0]const u8) bool {
        return getAttribute(node, key) != null;
    }

    pub fn getAttributeAlloc(node: Node, key: [:0]const u8, allocator: std.mem.Allocator, default_value: []const u8) ![]const u8 {
        const val = getAttribute(node, key);
        if (val == null)
            return try allocator.dupe(u8, default_value);

        return try allocator.dupe(u8, val.?);
    }

    pub fn getAttributeAllocZ(node: Node, key: [:0]const u8, allocator: std.mem.Allocator, default_value: []const u8) ![:0]const u8 {
        const val = getAttribute(node, key);
        if (val == null)
            return try allocator.dupeZ(u8, default_value);

        return try allocator.dupeZ(u8, val.?);
    }

    pub fn getAttributeInt(node: Node, key: [:0]const u8, comptime T: type, default_value: T) !T {
        const val = getAttribute(node, key);
        if (val == null)
            return default_value;

        return try std.fmt.parseInt(T, val.?, 0);
    }

    pub fn getAttributeFloat(node: Node, key: [:0]const u8, comptime T: type, default_value: T) !T {
        const val = getAttribute(node, key);
        if (val == null)
            return default_value;

        return try std.fmt.parseFloat(T, val.?);
    }

    pub fn findChild(node: Node, key: []const u8) ?Node {
        var it: ?*c.xmlNode = @ptrCast(node.impl.children);
        return while (it != null) : (it = it.?.next) {
            if (it.?.type != 1)
                continue;

            const name = std.mem.span(it.?.name orelse continue);
            if (std.mem.eql(u8, key, name))
                break Node{ .impl = it.? };
        } else null;
    }

    pub fn elementExists(node: Node, key: []const u8) bool {
        return findChild(node, key) != null;
    }

    pub fn iterate(node: Node, skip: []const []const u8, filter: []const u8) Iterator {
        var current: Node = node;
        for (skip) |elem|
            current = current.findChild(elem) orelse return Iterator{
                .node = null,
                .filter = filter,
            };

        return Iterator{
            .node = current.findChild(filter),
            .filter = filter,
        };
    }

    pub fn iterateAttrs(node: Node) AttrIterator {
        return AttrIterator{
            .attr = node.impl.properties,
        };
    }

    pub fn getValue(node: Node, key: []const u8) ?[:0]const u8 {
        return if (node.findChild(key)) |child|
            if (child.impl.children) |value_node|
                if (@as(*c.xmlNode, @ptrCast(value_node)).content) |content|
                    std.mem.span(content)
                else
                    null
            else
                null
        else
            null;
    }

    pub fn getValueAlloc(node: Node, key: []const u8, allocator: std.mem.Allocator, default_value: []const u8) ![]const u8 {
        const val = getValue(node, key);
        if (val == null)
            return try allocator.dupe(u8, default_value);

        return try allocator.dupe(u8, val.?);
    }

    pub fn getValueAllocZ(node: Node, key: []const u8, allocator: std.mem.Allocator, default_value: []const u8) ![:0]const u8 {
        const val = getValue(node, key);
        if (val == null)
            return try allocator.dupeZ(u8, default_value);

        return try allocator.dupeZ(u8, val.?);
    }

    pub fn getValueInt(node: Node, key: []const u8, comptime T: type, default_value: T) !T {
        const val = getValue(node, key);
        if (val == null)
            return default_value;

        return try std.fmt.parseInt(T, val.?, 0);
    }

    pub fn getValueFloat(node: Node, key: []const u8, comptime T: type, default_value: T) !T {
        const val = getValue(node, key);
        if (val == null)
            return default_value;

        return try std.fmt.parseFloat(T, val.?);
    }

    pub fn currentValue(node: Node) ?[:0]const u8 {
        return if (node.impl.children) |value_node|
            if (@as(*c.xmlNode, @ptrCast(value_node)).content) |content|
                std.mem.span(content)
            else
                null
        else
            null;
    }

    pub fn currentValueInt(node: Node, comptime T: type, default_value: T) !T {
        const val = currentValue(node);
        if (val == null)
            return default_value;

        return try std.fmt.parseInt(T, val, default_value);
    }

    pub fn currentValueFloat(node: Node, comptime T: type, default_value: T) !T {
        const val = currentValue(node);
        if (val == null)
            return default_value;

        return try std.fmt.parseFloat(T, val, default_value);
    }
};

pub const Doc = struct {
    impl: *c.xmlDoc,

    pub fn fromFile(path: [:0]const u8) !Doc {
        return Doc{
            .impl = c.xmlReadFile(
                path.ptr,
                null,
                0,
            ) orelse return error.ReadXmlFile,
        };
    }

    pub fn fromMemory(text: []const u8) !Doc {
        return Doc{
            .impl = c.xmlReadMemory(
                text.ptr,
                @intCast(text.len),
                null,
                null,
                0,
            ) orelse return error.XmlReadMemory,
        };
    }

    pub fn fromIO(read_fn: c.xmlInputReadCallback, ctx: ?*anyopaque) !Doc {
        return Doc{
            .impl = c.xmlReadIO(
                read_fn,
                null,
                ctx,
                null,
                null,
                0,
            ) orelse return error.ReadXmlFd,
        };
    }

    pub fn deinit(doc: *const Doc) void {
        c.xmlFreeDoc(doc.impl);
    }

    pub fn getRootElement(doc: Doc) !Node {
        return Node{
            .impl = c.xmlDocGetRootElement(doc.impl) orelse return error.NoRoot,
        };
    }
};
