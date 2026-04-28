// [abc________def]
//     ^       ^
//   cursor   rear

const std = @import("std");

pub fn GapBuffer(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        storage: []?ItemType,
        capacity: usize,
        cursor: usize,
        gap_rear: usize,
        length: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, init_capacity: usize) !Self {
            const storage_ptr = try allocator.alloc(?ItemType, init_capacity);
            @memset(storage_ptr, null);
            return Self{
                .storage = storage_ptr,
                .capacity = init_capacity,
                .cursor = 0,
                .gap_rear = init_capacity,
                .length = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        pub fn insert(self: *Self, data: ItemType) !void {
            if (self.length >= self.capacity) try self.expand();
            self.storage[self.cursor] = data;
            self.cursor += 1;
            self.length += 1;
        }

        pub fn backspace(self: *Self) !void {
            if (self.cursor == 0) return error.Empty;
            self.cursor -= 1;
            self.length -= 1;
            self.storage[self.cursor] = null;
        }

        pub fn delete_forward(self: *Self) !void {
            if (self.gap_rear == self.capacity) return error.Empty;
            self.storage[self.gap_rear] = null;
            self.gap_rear += 1;
            self.length -= 1;
        }

        pub fn move_cursor(self: *Self, position: usize) !void {
            if (position > self.length) return error.IndexOutOfBounds;
            if (position == self.cursor) return;
            if (position > self.cursor) {
                const move_length = position - self.cursor;
                @memmove(self.storage[self.cursor..position], self.storage[self.gap_rear .. self.gap_rear + move_length]);
                self.cursor = position;
                self.gap_rear += move_length;
            } else {
                const move_length = self.cursor - position;
                @memmove(self.storage[self.gap_rear - move_length .. self.gap_rear], self.storage[position..self.cursor]);
                self.cursor = position;
                self.gap_rear -= move_length;
            }
            @memset(self.storage[self.cursor..self.gap_rear], null);
        }

        fn expand(self: *Self) !void {
            const new_capacity = @max(self.capacity * 2, 4);
            const new_ptr = try self.allocator.alloc(?ItemType, new_capacity);
            @memset(new_ptr, null);
            const new_gap_rear = new_capacity - (self.capacity - self.gap_rear);
            @memcpy(new_ptr[0..self.cursor], self.storage[0..self.cursor]); // first part
            @memcpy(new_ptr[new_gap_rear..], self.storage[self.gap_rear..]); // second part
            self.allocator.free(self.storage);
            self.capacity = new_capacity;
            self.gap_rear = new_gap_rear;
            self.storage = new_ptr;
        }
    };
}
