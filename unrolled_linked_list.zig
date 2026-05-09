const std = @import("std");

pub fn Node(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        size: usize,
        storage: []?ItemType,
        next: ?*Self,
    };
}

pub fn UnrolledLinkedList(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        const NodeType = Node(ItemType);
        head: ?*NodeType,
        size: usize,
        node_capacity: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, node_capacity: usize) !Self {
            const head_ptr = try allocator.create(NodeType);
            errdefer allocator.destroy(head_ptr);
            const storage_ptr = try allocator.alloc(?ItemType, node_capacity);
            errdefer allocator.free(storage_ptr);
            head_ptr.* = .{
                .next = null,
                .size = 0,
                .storage = storage_ptr,
            };
            return Self{
                .allocator = allocator,
                .head = head_ptr,
                .node_capacity = node_capacity,
                .size = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.free(node.storage);
                self.allocator.destroy(node);
                current = next;
            }
        }

        fn createNode(self: *Self) !*NodeType {
            const node = try self.allocator.create(NodeType);
            errdefer self.allocator.destroy(node);
            const storage = try self.allocator.alloc(?ItemType, self.node_capacity);
            node.* = .{
                .size = 0,
                .storage = storage,
                .next = null,
            };
            return node;
        }

        pub fn get(self: *Self, index: usize) !ItemType {
            if (index >= self.size) return error.IndexOutOfBounds;
            var current = self.head.?;
            var remaining = index;
            while (remaining >= current.size) {
                remaining -= current.size;
                current = current.next.?;
            }
            return current.storage[remaining].?;
        }

        pub fn set(self: *Self, index: usize, item: ItemType) !void {
            if (index >= self.size) return error.IndexOutOfBounds;
            var current = self.head.?;
            var remaining = index;
            while (remaining >= current.size) {
                remaining -= current.size;
                current = current.next.?;
            }
            current.storage[remaining] = item;
        }

        pub fn insert(self: *Self, index: usize, item: ItemType) !void {
            if (index > self.size) return error.IndexOutOfBounds;

            var current = self.head.?;
            var remaining = index;
            while (remaining > current.size) {
                remaining -= current.size;
                current = current.next.?;
            }

            if (current.size == self.node_capacity) {
                const new_node = try self.createNode();
                const half = self.node_capacity / 2;
                const move_count = current.size - half;
                var i: usize = 0;
                while (i < move_count) : (i += 1) {
                    new_node.storage[i] = current.storage[half + i];
                    current.storage[half + i] = null;
                }
                new_node.size = move_count;
                current.size = half;
                new_node.next = current.next;
                current.next = new_node;

                if (remaining > half) {
                    remaining -= half;
                    current = new_node;
                }
            }

            var j: usize = current.size;
            while (j > remaining) : (j -= 1) {
                current.storage[j] = current.storage[j - 1];
            }
            current.storage[remaining] = item;
            current.size += 1;
            self.size += 1;
        }

        pub fn delete(self: *Self, index: usize) !ItemType {
            if (index >= self.size) return error.IndexOutOfBounds;

            var prev: ?*NodeType = null;
            var current = self.head.?;
            var remaining = index;
            while (remaining >= current.size) {
                remaining -= current.size;
                prev = current;
                current = current.next.?;
            }

            const removed = current.storage[remaining].?;
            var j: usize = remaining;
            while (j + 1 < current.size) : (j += 1) {
                current.storage[j] = current.storage[j + 1];
            }
            current.storage[current.size - 1] = null;
            current.size -= 1;
            self.size -= 1;

            const threshold = (self.node_capacity + 1) / 2;
            if (current.size < threshold) {
                if (current.next) |next| {
                    if (current.size + next.size <= self.node_capacity) {
                        var k: usize = 0;
                        while (k < next.size) : (k += 1) {
                            current.storage[current.size + k] = next.storage[k];
                        }
                        current.size += next.size;
                        current.next = next.next;
                        self.allocator.free(next.storage);
                        self.allocator.destroy(next);
                    } else {
                        current.storage[current.size] = next.storage[0];
                        current.size += 1;
                        var k: usize = 0;
                        while (k + 1 < next.size) : (k += 1) {
                            next.storage[k] = next.storage[k + 1];
                        }
                        next.storage[next.size - 1] = null;
                        next.size -= 1;
                    }
                } else if (prev) |p| {
                    if (p.size + current.size <= self.node_capacity) {
                        var k: usize = 0;
                        while (k < current.size) : (k += 1) {
                            p.storage[p.size + k] = current.storage[k];
                        }
                        p.size += current.size;
                        p.next = current.next;
                        self.allocator.free(current.storage);
                        self.allocator.destroy(current);
                    }
                }
            }

            return removed;
        }
    };
}

test "init and deinit" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var unrolled_linked_list = try UnrolledLinkedList(u8).init(allocator, 4);
    defer unrolled_linked_list.deinit();
}

test "insert get set delete" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = try UnrolledLinkedList(u32).init(allocator, 4);
    defer list.deinit();

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try list.insert(i, i);
    }
    try std.testing.expectEqual(@as(usize, 10), list.size);

    i = 0;
    while (i < 10) : (i += 1) {
        try std.testing.expectEqual(i, try list.get(i));
    }

    try list.insert(0, 99);
    try std.testing.expectEqual(@as(u32, 99), try list.get(0));
    try std.testing.expectEqual(@as(u32, 0), try list.get(1));

    try list.insert(5, 88);
    try std.testing.expectEqual(@as(u32, 88), try list.get(5));
    try std.testing.expectEqual(@as(usize, 12), list.size);

    try list.set(0, 100);
    try std.testing.expectEqual(@as(u32, 100), try list.get(0));

    const removed = try list.delete(0);
    try std.testing.expectEqual(@as(u32, 100), removed);
    try std.testing.expectEqual(@as(u32, 0), try list.get(0));

    while (list.size > 0) {
        _ = try list.delete(0);
    }
    try std.testing.expectEqual(@as(usize, 0), list.size);

    try std.testing.expectError(error.IndexOutOfBounds, list.get(0));
    try std.testing.expectError(error.IndexOutOfBounds, list.set(0, 1));
    try std.testing.expectError(error.IndexOutOfBounds, list.delete(0));
    try std.testing.expectError(error.IndexOutOfBounds, list.insert(1, 1));
}

test "insert at end and delete from end" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var list = try UnrolledLinkedList(u32).init(allocator, 3);
    defer list.deinit();

    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        try list.insert(list.size, i);
    }
    try std.testing.expectEqual(@as(usize, 50), list.size);

    i = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expectEqual(i, try list.get(i));
    }

    while (list.size > 0) {
        const expected: u32 = @intCast(list.size - 1);
        const got = try list.delete(list.size - 1);
        try std.testing.expectEqual(expected, got);
    }
}
