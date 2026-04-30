const std = @import("std");
const Order = std.math.Order;

const DynamicArray = @import("dyn_array.zig").DynamicArray;

fn Node(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        k: ?K,
        v: ?V,
        next: ?*Self,
        lower: ?*Self,
    };
}

pub fn SkipList(comptime K: type, comptime V: type, comptime compareFn: fn (first: K, second: K) Order) type {
    return struct {
        const Self = @This();
        const NodeType = Node(K, V);
        const StorageType = DynamicArray(*NodeType);
        const A = compareFn;

        storage: StorageType,
        levels: usize,
        size: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const head_ptr = try allocator.create(NodeType);
            head_ptr.* = .{
                .k = null,
                .v = null,
                .next = null,
                .lower = null,
            };
            var storage = try StorageType.init(allocator, 64);
            try storage.append(head_ptr);
            return Self{
                .allocator = allocator,
                .storage = storage,
                .levels = 1,
                .size = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            for (0..self.storage.length) |idx| {
                var node = self.storage.get(idx) catch unreachable;
                while (node.next) |next| {
                    self.allocator.destroy(node);
                    node = next;
                }
                self.allocator.destroy(node);
            }
            self.storage.deinit();
        }

        pub fn get(self: Self, k: K) ?V {
            var current = self.storage.get(self.levels - 1) catch return null;
            while (true) {
                while (current.next) |next| {
                    if (compareFn(next.k.?, k) == .gt) break;
                    current = next;
                }
                if (current.k) |ck| {
                    if (compareFn(ck, k) == .eq) return current.v;
                }
                if (current.lower) |lower| {
                    current = lower;
                } else return null;
            }
        }

        pub fn set(self: *Self, k: K, v: V) !void {
            var update = try DynamicArray(*NodeType).init(self.allocator, self.levels);
            defer update.deinit();
            for (0..self.levels) |i| {
                try update.append(try self.storage.get(i));
            }

            var current = try self.storage.get(self.levels - 1);
            var level = self.levels;
            while (level > 0) {
                level -= 1;
                while (current.next) |next| {
                    if (compareFn(next.k.?, k) != .lt) break;
                    current = next;
                }
                try update.set(level, current);
                if (current.next) |next| {
                    if (compareFn(next.k.?, k) == .eq) {
                        var n: ?*NodeType = next;
                        while (n) |node| {
                            node.v = v;
                            n = node.lower;
                        }
                        return;
                    }
                }
                if (current.lower) |lower| {
                    current = lower;
                }
            }

            const extra = countTruesUntilFalse(0.7);
            const capped: u64 = if (extra > 31) 31 else extra;
            const new_height: usize = @as(usize, @intCast(capped)) + 1;
            const old_levels = self.levels;

            var lower: ?*NodeType = null;
            for (0..new_height) |i| {
                const new_node = try self.allocator.create(NodeType);
                new_node.* = .{
                    .k = k,
                    .v = v,
                    .next = null,
                    .lower = lower,
                };
                if (i < old_levels) {
                    const pred = try update.get(i);
                    new_node.next = pred.next;
                    pred.next = new_node;
                } else {
                    const old_top_head = try self.storage.get(self.levels - 1);
                    const new_head = try self.allocator.create(NodeType);
                    new_head.* = .{
                        .k = null,
                        .v = null,
                        .next = new_node,
                        .lower = old_top_head,
                    };
                    try self.storage.append(new_head);
                    self.levels += 1;
                }
                lower = new_node;
            }

            self.size += 1;
        }

        pub fn delete(self: *Self, k: K) !bool {
            var current = try self.storage.get(self.levels - 1);
            var found = false;
            var level = self.levels;
            while (level > 0) {
                level -= 1;
                while (current.next) |next| {
                    if (compareFn(next.k.?, k) != .lt) break;
                    current = next;
                }
                if (current.next) |match| {
                    if (compareFn(match.k.?, k) == .eq) {
                        current.next = match.next;
                        self.allocator.destroy(match);
                        found = true;
                    }
                }
                if (current.lower) |lower| {
                    current = lower;
                }
            }

            if (!found) return false;

            while (self.levels > 1) {
                const top_head = try self.storage.get(self.levels - 1);
                if (top_head.next != null) break;
                self.allocator.destroy(top_head);
                try self.storage.delete(self.levels - 1);
                self.levels -= 1;
            }

            self.size -= 1;
            return true;
        }
    };
}

var global_prng: std.Random.DefaultPrng = .init(0x9E3779B97F4A7C15);

fn countTruesUntilFalse(p: f64) u64 {
    const rand = global_prng.random();
    var n: u64 = 0;
    while (rand.float(f64) < p) : (n += 1) {}
    return n;
}

fn compareU8(a: u8, b: u8) Order {
    return std.math.order(a, b);
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var skip_list = try SkipList(u8, u8, compareU8).init(allocator);
    defer skip_list.deinit();
}

test "set, get, delete" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var skip_list = try SkipList(u8, u8, compareU8).init(allocator);
    defer skip_list.deinit();

    try skip_list.set(1, 10);
    try skip_list.set(3, 30);
    try skip_list.set(2, 20);
    try skip_list.set(5, 50);
    try skip_list.set(4, 40);
    try std.testing.expectEqual(@as(usize, 5), skip_list.size);

    try std.testing.expectEqual(@as(?u8, 10), skip_list.get(1));
    try std.testing.expectEqual(@as(?u8, 20), skip_list.get(2));
    try std.testing.expectEqual(@as(?u8, 30), skip_list.get(3));
    try std.testing.expectEqual(@as(?u8, 40), skip_list.get(4));
    try std.testing.expectEqual(@as(?u8, 50), skip_list.get(5));
    try std.testing.expectEqual(@as(?u8, null), skip_list.get(6));

    try skip_list.set(3, 99);
    try std.testing.expectEqual(@as(?u8, 99), skip_list.get(3));
    try std.testing.expectEqual(@as(usize, 5), skip_list.size);

    try std.testing.expect(try skip_list.delete(3));
    try std.testing.expectEqual(@as(?u8, null), skip_list.get(3));
    try std.testing.expectEqual(@as(usize, 4), skip_list.size);
    try std.testing.expect(!(try skip_list.delete(3)));

    try std.testing.expect(try skip_list.delete(1));
    try std.testing.expect(try skip_list.delete(2));
    try std.testing.expect(try skip_list.delete(4));
    try std.testing.expect(try skip_list.delete(5));
    try std.testing.expectEqual(@as(usize, 0), skip_list.size);
    try std.testing.expectEqual(@as(usize, 1), skip_list.levels);
}
