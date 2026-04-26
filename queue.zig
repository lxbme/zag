const std = @import("std");

pub fn Queue(comptime ItemType: type) type {
    return struct {
        const Self = @This();

        storage: []?ItemType,
        header: usize,
        rearer: usize,
        capacity: usize,
        length: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            const storage = try allocator.alloc(?ItemType, capacity);
            @memset(storage, null);
            return Self{
                .storage = storage,
                .header = 0,
                .rearer = 0,
                .capacity = capacity,
                .length = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        pub fn enqueue(self: *Self, item: ItemType) !void {
            if (self.length >= self.capacity) {
                try self.resize(true);
            }
            self.storage[self.rearer] = item;
            self.rearer = (self.rearer + 1) % self.capacity;
            self.length += 1;
        }

        pub fn dequeue(self: *Self) !?ItemType {
            if (self.length == 0) return null;
            const item = self.storage[self.header].?;
            self.storage[self.header] = null;
            self.header = (self.header + 1) % self.capacity;
            self.length -= 1;

            // shrink if length < 1/4 capacity
            if (self.length < @divFloor(self.capacity, 4)) try self.resize(false);
            return item;
        }

        fn resize(self: *Self, expand: bool) !void {
            const old_capacity = self.capacity;
            var new_capacity: usize = undefined;
            if (expand) {
                new_capacity = old_capacity * 2;
            } else {
                new_capacity = @divFloor(old_capacity, 2);
                if (new_capacity < 1) return; // don't shrink to 0
                if (new_capacity < self.length) return; // sanity guard
            }

            const new_ptr = try self.allocator.alloc(?ItemType, new_capacity);
            @memset(new_ptr, null);

            if (self.length > 0) {
                if (self.header < self.rearer) {
                    @memcpy(new_ptr[0..self.length], self.storage[self.header..self.rearer]);
                } else {
                    const first_part_len = old_capacity - self.header;
                    @memcpy(new_ptr[0..first_part_len], self.storage[self.header..old_capacity]);
                    @memcpy(new_ptr[first_part_len..self.length], self.storage[0..self.rearer]);
                }
            }

            self.allocator.free(self.storage);
            self.storage = new_ptr;
            self.capacity = new_capacity;
            self.header = 0;
            self.rearer = self.length;
        }
    };
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var queue = try Queue(u8).init(allocator, 1);
    defer queue.deinit();
}

test "enqueue and expand" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var queue = try Queue(u32).init(allocator, 1);
    defer queue.deinit();
    for (0..128) |idx| {
        try queue.enqueue(@intCast(idx));
    }

    std.debug.assert(queue.capacity == 128);
    std.debug.assert(queue.length == 128);
}

test "dequeue" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var queue = try Queue(u32).init(allocator, 1);
    defer queue.deinit();
    for (0..128) |idx| {
        try queue.enqueue(@intCast(idx));
    }
    for (0..128) |idx| {
        std.debug.assert((try queue.dequeue()).? == idx);
    }
    // std.debug.print("capacity: {}\n", .{queue.capacity});
    std.debug.assert(queue.length == 0);
}
