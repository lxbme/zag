const std = @import("std");

fn Node(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        data: ItemType,
        prev: *Self,
        next: *Self,
    };
}

pub fn LinkedList(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        const NodeType = Node(ItemType);

        head: *NodeType,
        length: usize,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator) !Self {
            const head_ptr = try allocator.create(NodeType);
            head_ptr.* = .{
                .data = undefined,
                .next = head_ptr,
                .prev = head_ptr,
            };
            return Self{
                .head = head_ptr,
                .length = 0,
                .allocator = allocator,
            };
        }

        fn insert(self: *Self, idx: usize, data: ItemType) !void {
            if (idx > self.length) return error.IndexOutOfBounds;

            var new_node_ptr = try self.allocator.create(NodeType);
            new_node_ptr.* = .{
                .data = data,
                .next = undefined,
                .prev = undefined,
            };

            var the_prev = self.head;
            for (0..idx) |_| {
                the_prev = the_prev.next;
            }

            const the_next = the_prev.next;

            new_node_ptr.next = the_next;
            new_node_ptr.prev = the_prev;
            the_prev.next = new_node_ptr;
            the_next.prev = new_node_ptr;

            self.length += 1;
        }

        fn delete(self: *Self, idx: usize) !void {
            if (idx >= self.length) return error.IndexOutOfBounds;

            var the_prev = self.head;
            for (0..idx) |_| {
                the_prev = the_prev.next;
            }

            const this_node = the_prev.next;
            const the_next = this_node.next;

            the_prev.next = the_next;
            the_next.prev = the_prev;

            self.allocator.destroy(this_node);
            self.length -= 1;
        }

        fn deinit(self: *Self) void {
            var current = self.head.next;
            for (0..self.length) |_| {
                current = current.next;
                self.allocator.destroy(current.prev);
            }
            self.allocator.destroy(self.head);
        }

        fn get(self: Self, idx: usize) !ItemType {
            if (idx >= self.length) return error.IndexOutOfBounds;
            var the_prev = self.head;
            for (0..idx) |_| {
                the_prev = the_prev.next;
            }
            return the_prev.next.data;
        }

        fn append(self: *Self, data: ItemType) !void {
            var new_node_ptr = try self.allocator.create(NodeType);
            new_node_ptr.* = .{
                .data = data,
                .next = undefined,
                .prev = undefined,
            };
            var the_prev = self.head.prev;
            new_node_ptr.prev = the_prev;
            new_node_ptr.next = self.head;
            the_prev.next = new_node_ptr;
            self.head.prev = new_node_ptr;
            self.length += 1;
        }

        fn popend(self: *Self) !ItemType {
            if (self.length == 0) return error.IndexOutOfBounds;
            const tail = self.head.prev;
            const data = tail.data;
            self.head.prev.prev.next = self.head;
            self.head.prev = self.head.prev.prev;
            self.allocator.destroy(tail);
            self.length -= 1;
            return data;
        }

        fn getend(self: Self) !ItemType {
            if (self.length == 0) return error.IndexOutOfBounds;
            return self.head.prev.data;
        }
    };
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    std.debug.assert(linkedlist.length == 0);
}

test "insert" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    try linkedlist.insert(0, 1);
    std.debug.assert(linkedlist.length == 1);
}

test "get" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    try linkedlist.insert(0, 42);
    std.debug.assert(linkedlist.length == 1);
    std.debug.assert(try linkedlist.get(0) == 42);
}

test "append" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    try linkedlist.insert(0, 42);
    try linkedlist.append(43);
    std.debug.assert(linkedlist.length == 2);
    std.debug.assert(try linkedlist.get(1) == 43);
}

test "getend" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    try linkedlist.insert(0, 42);
    try linkedlist.append(43);
    std.debug.assert(linkedlist.length == 2);
    std.debug.assert(try linkedlist.getend() == 43);
}

test "popend" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const U8LinkedList = LinkedList(u8);
    var linkedlist = try U8LinkedList.init(allocator);
    defer linkedlist.deinit();

    try linkedlist.insert(0, 42);
    try linkedlist.append(43);
    const data = try linkedlist.popend();
    std.debug.assert(linkedlist.length == 1);
    std.debug.assert(data == 43);
}
