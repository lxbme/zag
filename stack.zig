const std = @import("std");

pub fn Stack(comptime ItemType: type) type {
    return struct {
        const Self = @This();

        storage: []?ItemType,
        capacity: usize,
        top: usize, // the next idx of current top
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, init_capacity: usize) !Self {
            const storage_ptr = try allocator.alloc(?ItemType, init_capacity);
            @memset(storage_ptr, null);
            return Self{
                .storage = storage_ptr,
                .capacity = init_capacity,
                .top = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        pub fn push(self: *Self, data: ItemType) !void {
            if (self.top == self.capacity) try self.resize(true);
            self.storage[self.top] = data;
            self.top += 1;
        }

        pub fn pop(self: *Self) !?ItemType {
            if (self.top <= 0) return null;
            const result = self.storage[self.top - 1];
            self.top -= 1;
            if (self.top <= self.capacity / 4) try self.resize(false);
            return result;
        }

        fn resize(self: *Self, expand: bool) !void {
            var new_capacity: usize = undefined;
            if (expand) {
                new_capacity = @max(self.capacity * 2, 4);
            } else {
                new_capacity = @divFloor(self.capacity, 2);
                if (new_capacity < 1) return; // don't shrink to 0
                if (new_capacity < self.top) return; // sanity guard
            }
            const new_storage_ptr = try self.allocator.alloc(?ItemType, new_capacity);
            @memset(new_storage_ptr, null);

            @memcpy(new_storage_ptr[0..self.top], self.storage[0..self.top]);
            self.allocator.free(self.storage);
            self.storage = new_storage_ptr;
            self.capacity = new_capacity;
        }
    };
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stack = try Stack(u8).init(allocator, 2);
    defer stack.deinit();
}

test "push" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stack = try Stack(u8).init(allocator, 1);
    defer stack.deinit();

    for (0..128) |idx| try stack.push(@intCast(idx));
    std.debug.assert(stack.top == 128);
}

test "pop" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stack = try Stack(u8).init(allocator, 1);
    defer stack.deinit();

    var data: u8 = undefined;
    for (0..128) |idx| try stack.push(@intCast(idx));
    for (0..128) |_| data = (try stack.pop()).?;
    std.debug.assert(data == 0);
    std.debug.assert(stack.capacity == 1);
}
