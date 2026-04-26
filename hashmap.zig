// NOTE
// This hashmap uses a linear probing strategy for hash collisions.
// Available space is 1/2 of the total capacity. When available
// space hits 0, capacity will double. Available space will then
// be reset to (1/2 new capacity - item count).

const std = @import("std");

const INIT_CAPACITY: usize = 4;

pub fn Hashmap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        keys: []?K,
        values: []?V,
        capacity: usize,
        size: usize,
        available: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const keys = try allocator.alloc(?K, INIT_CAPACITY);
            const values = try allocator.alloc(?V, INIT_CAPACITY);
            @memset(keys, null);
            @memset(values, null);
            return Self{
                .keys = keys,
                .values = values,
                .capacity = INIT_CAPACITY,
                .size = 0,
                .available = @divFloor(INIT_CAPACITY, 2),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.keys);
            self.allocator.free(self.values);
        }

        pub fn instert(self: *Self, k: K, v: V) !void {
            var idx = self.getIdx(@as(usize, hashKey(k)));
            for (0..self.capacity) |_| {
                if (self.keys[idx] == null) {
                    self.keys[idx] = k;
                    self.values[idx] = v;
                    self.size += 1;
                    self.available -|= 1;
                    if (self.available == 0) try self.expand();
                    return;
                }
                if (eqlKey(self.keys[idx].?, k)) {
                    self.values[idx] = v;
                    return;
                }
                idx = self.getIdx(idx + 1);
            }
            try self.expand();
            try self.instert(k, v);
        }

        pub fn get(self: Self, query: K) ?V {
            var idx = self.getIdx(@as(usize, hashKey(query)));
            if (self.keys[idx] == null) return null;

            while (self.keys[idx]) |k| {
                if (eqlKey(k, query)) return self.values[idx];
                idx = self.getIdx(idx + 1);
            }
            return null;
        }

        fn expand(self: *Self) !void {
            const new_capacity = self.capacity * 2;
            const new_keys = try self.allocator.alloc(?K, new_capacity);
            const new_values = try self.allocator.alloc(?V, new_capacity);
            @memset(new_keys, null);
            @memset(new_values, null);

            const old_capacity = self.capacity;
            self.capacity = new_capacity;

            for (0..old_capacity) |i| {
                if (self.keys[i]) |k| {
                    var new_idx = self.getIdx(@as(usize, hashKey(k)));
                    while (new_keys[new_idx] != null) {
                        new_idx = self.getIdx(new_idx + 1);
                    }
                    new_keys[new_idx] = k;
                    new_values[new_idx] = self.values[i];
                }
            }
            self.allocator.free(self.keys);
            self.allocator.free(self.values);

            self.keys = new_keys;
            self.values = new_values;
            self.available = @divFloor(new_capacity, 2) -| self.size;
        }

        fn find_next_blank(self: Self, start: usize) ?usize {
            var idx = self.getIdx(start);
            for (0..self.capacity) |_| {
                if (self.keys[idx] == null) {
                    return idx;
                }
                idx = self.getIdx(idx + 1);
            }

            return null; // full
        }

        fn getIdx(self: Self, idx: usize) usize {
            return idx & (self.capacity - 1);
        }

        fn hashKey(k: K) u64 {
            var hasher = std.hash.Wyhash.init(42);
            std.hash.autoHashStrat(&hasher, k, .DeepRecursive);
            return hasher.final();
            // _ = k;
            // return @as(u64, 0);
        }

        fn eqlKey(a: K, b: K) bool {
            return std.meta.eql(a, b);
        }
    };
}

test "test_instert" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const StringMap = Hashmap(u8, u8);
    var map = try StringMap.init(allocator);
    defer map.deinit();
    try map.instert(1, 1);
    try map.instert(2, 2);
    try map.instert(3, 3);
    try map.instert(4, 4);
    try map.instert(5, 5);
    std.debug.assert(map.capacity == @as(usize, 16));
}

test "test_get" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const StringMap = Hashmap([]const u8, u8);
    var map = try StringMap.init(allocator);
    defer map.deinit();
    try map.instert("1", 1);
    try map.instert("2", 2);
    try map.instert("3", 3);
    try map.instert("4", 4);
    try map.instert("5", 5);
    try map.instert("5", 6);
    std.debug.assert(map.capacity == @as(usize, 16));
    std.debug.assert(map.get("5") == 6);
}
