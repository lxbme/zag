// NOTE
// This dynamic array automatically resizes:
// Expansion: Triggered when full. newCapacity = (old * 1.5) + 1.
// Shrinkage: Capacity halves when the length drops below 25%.

const std = @import("std");

pub fn DynamicArray(comptime Item: type) type {
    return struct {
        const Self = @This();

        storage: []?Item,
        capacity: usize,
        length: usize,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            const storage = try allocator.alloc(?Item, capacity);
            @memset(storage, null);
            return Self{
                .storage = storage,
                .capacity = capacity,
                .length = 0,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        fn append(self: *Self, item: Item) !void {
            if (self.length >= self.capacity) { // if full then extract
                const new_capacity = @divFloor(self.capacity * 3, 2) + 1; // make sure have 1 free capacity
                const new_storage = try self.allocator.alloc(?Item, new_capacity);
                @memset(new_storage, null);
                @memcpy(new_storage[0..self.capacity], self.storage[0..self.capacity]);

                self.allocator.free(self.storage);
                self.storage = new_storage;
                self.capacity = new_capacity;
            }
            self.storage[self.length] = item;
            self.length += 1;
        }

        fn get(self: Self, idx: usize) !Item {
            if (idx < self.length) {
                return self.storage[idx].?;
            } else {
                return error.IndexOutOfBounds;
            }
        }

        fn set(self: Self, idx: usize, item: Item) !void {
            if (idx < self.length) {
                self.storage[idx] = item;
            } else {
                return error.IndexOutOfBounds;
            }
        }

        fn delete(self: *Self, idx: usize) !void {
            if (idx < self.length) {
                for (idx..self.length - 1) |i| {
                    self.storage[i] = self.storage[i + 1];
                }
                self.storage[self.length - 1] = null;
                self.length -= 1;
            } else {
                return error.IndexOutOfBounds;
            }

            // shrink
            if (self.length < @divFloor(self.capacity, 4)) {
                const new_capacity = @divFloor(self.capacity, 2);
                const new_storage = try self.allocator.alloc(?Item, new_capacity);
                @memset(new_storage, null);
                @memcpy(new_storage[0..new_capacity], self.storage[0..new_capacity]);
                self.allocator.free(self.storage);
                self.storage = new_storage;
                self.capacity = new_capacity;
            }
        }
    };
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Array = DynamicArray(u8);
    var array = try Array.init(allocator, 1);
    defer array.deinit();
    std.debug.assert(array.capacity == 1);
    std.debug.assert(array.length == 0);
}

test "append" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Array = DynamicArray(u8);
    var array = try Array.init(allocator, 1);
    defer array.deinit();
    try array.append(@as(u8, 42));
    try array.append(@as(u8, 43));
    try array.append(@as(u8, 44));
    std.debug.assert(array.capacity == 4);
    std.debug.assert(array.length == 3);
}

test "get" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Array = DynamicArray(u8);
    var array = try Array.init(allocator, 1);
    defer array.deinit();
    try array.append(@as(u8, 42));
    try array.append(@as(u8, 43));
    try array.append(@as(u8, 44));
    std.debug.assert(try array.get(1) == 43);
}

test "set" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Array = DynamicArray(u8);
    var array = try Array.init(allocator, 1);
    defer array.deinit();
    try array.append(@as(u8, 42));
    try array.append(@as(u8, 43));
    try array.append(@as(u8, 44));
    try array.set(1, 53);
    std.debug.assert(try array.get(1) == 53);
}

test "delete" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Array = DynamicArray(u8);
    var array = try Array.init(allocator, 1);
    defer array.deinit();
    for (0..8) |_| {
        try array.append(@as(u8, 42)); // capacity 11
    }
    for (0..7) |_| {
        try array.delete(0);
    }

    std.debug.assert(try array.get(0) == 42);
    std.debug.assert(array.capacity == 5);
}
