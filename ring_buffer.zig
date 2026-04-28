const std = @import("std");

pub fn RingBuffer(comptime ItemType: type) type {
    return struct {
        const Self = @This();
        storage: []ItemType,
        capacity: usize,
        length: usize,
        header: usize,
        rearer: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            const storage_ptr = try allocator.alloc(ItemType, capacity);
            return Self{
                .storage = storage_ptr,
                .capacity = capacity,
                .length = 0,
                .header = 0,
                .rearer = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        pub fn push(self: *Self, data: ItemType) !void {
            if (self.length >= self.capacity) return error.BufferFull;
            self.storage[self.rearer] = data;
            self.rearer = @mod(self.rearer + 1, self.capacity);
            self.length += 1;
        }

        pub fn pop(self: *Self) !ItemType {
            if (self.length <= 0) return error.Empty;
            const result = self.storage[self.header];
            self.header = @mod(self.header + 1, self.capacity);
            self.length -= 1;
            return result;
        }

        pub fn peek(self: Self) !ItemType {
            if (self.length <= 0) return error.Empty;
            return self.storage[self.header];
        }

        pub fn pushOverwrite(self: *Self, data: ItemType) void {
            if (self.length < self.capacity) {
                self.storage[self.rearer] = data;
                self.rearer = @mod(self.rearer + 1, self.capacity);
                self.length += 1;
            } else {
                self.storage[self.rearer] = data;
                self.rearer = @mod(self.rearer + 1, self.capacity);
                self.header = @mod(self.header + 1, self.capacity);
            }
        }

        pub fn read(self: *Self, dest: []ItemType) usize {
            const size: usize = @min(dest.len, self.length);
            if (size == 0) return 0;

            if (self.header < self.rearer) {
                @memcpy(dest[0..size], self.storage[self.header .. self.header + size]);
            } else {
                const first_size = self.capacity - self.header;
                if (first_size > size) {
                    @memcpy(dest[0..size], self.storage[self.header .. self.header + size]);
                } else {
                    const second_size = size - first_size;
                    @memcpy(dest[0..first_size], self.storage[self.header..]);
                    @memcpy(dest[first_size .. first_size + second_size], self.storage[0..second_size]);
                }
            }
            self.header = @mod(self.header + size, self.capacity);
            return size;
        }
    };
}

test "init" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 4);
    defer buf.deinit();

    try std.testing.expectEqual(@as(usize, 4), buf.capacity);
    try std.testing.expectEqual(@as(usize, 0), buf.length);
    try std.testing.expectEqual(@as(usize, 0), buf.header);
    try std.testing.expectEqual(@as(usize, 0), buf.rearer);
    try std.testing.expectEqual(@as(usize, 4), buf.storage.len);
}

test "push and length tracking" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 4);
    defer buf.deinit();

    try buf.push(10);
    try buf.push(20);
    try buf.push(30);

    try std.testing.expectEqual(@as(usize, 3), buf.length);
    try std.testing.expectEqual(@as(usize, 3), buf.rearer);
    try std.testing.expectEqual(@as(usize, 0), buf.header);
}

test "push returns BufferFull when full" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 2);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try std.testing.expectError(error.BufferFull, buf.push(3));
}

test "push wraps rearer index" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 3);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try buf.push(3);
    _ = try buf.pop();
    try buf.push(4);

    try std.testing.expectEqual(@as(usize, 1), buf.rearer);
    try std.testing.expectEqual(@as(usize, 3), buf.length);
}

test "pop returns items in FIFO order" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 4);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try buf.push(3);

    try std.testing.expectEqual(@as(u32, 1), try buf.pop());
    try std.testing.expectEqual(@as(u32, 2), try buf.pop());
    try std.testing.expectEqual(@as(u32, 3), try buf.pop());
    try std.testing.expectEqual(@as(usize, 0), buf.length);
}

test "pop returns Empty on empty buffer" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 2);
    defer buf.deinit();

    try std.testing.expectError(error.Empty, buf.pop());

    try buf.push(1);
    _ = try buf.pop();
    try std.testing.expectError(error.Empty, buf.pop());
}

test "peek returns front without removing" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 4);
    defer buf.deinit();

    try buf.push(42);
    try buf.push(99);

    try std.testing.expectEqual(@as(u32, 42), try buf.peek());
    try std.testing.expectEqual(@as(u32, 42), try buf.peek());
    try std.testing.expectEqual(@as(usize, 2), buf.length);
}

test "peek returns Empty on empty buffer" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 2);
    defer buf.deinit();

    try std.testing.expectError(error.Empty, buf.peek());
}

test "pushOverwrite fills buffer without overwriting" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 3);
    defer buf.deinit();

    buf.pushOverwrite(1);
    buf.pushOverwrite(2);
    buf.pushOverwrite(3);

    try std.testing.expectEqual(@as(usize, 3), buf.length);
    try std.testing.expectEqual(@as(u32, 1), try buf.pop());
    try std.testing.expectEqual(@as(u32, 2), try buf.pop());
    try std.testing.expectEqual(@as(u32, 3), try buf.pop());
}

test "pushOverwrite drops oldest when full" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 3);
    defer buf.deinit();

    buf.pushOverwrite(1);
    buf.pushOverwrite(2);
    buf.pushOverwrite(3);
    buf.pushOverwrite(4);
    buf.pushOverwrite(5);

    try std.testing.expectEqual(@as(usize, 3), buf.length);
    try std.testing.expectEqual(@as(u32, 3), try buf.pop());
    try std.testing.expectEqual(@as(u32, 4), try buf.pop());
    try std.testing.expectEqual(@as(u32, 5), try buf.pop());
}

test "read copies items into dest (no wrap)" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 8);
    defer buf.deinit();

    try buf.push(10);
    try buf.push(20);
    try buf.push(30);

    var dest: [3]u32 = undefined;
    const n = buf.read(&dest);

    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(u32, 10), dest[0]);
    try std.testing.expectEqual(@as(u32, 20), dest[1]);
    try std.testing.expectEqual(@as(u32, 30), dest[2]);
}

test "read returns 0 when buffer is empty" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u8).init(allocator, 4);
    defer buf.deinit();

    var dest: [4]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), buf.read(&dest));
}

test "read caps at buffer length when dest is larger" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 8);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);

    var dest: [5]u32 = undefined;
    const n = buf.read(&dest);

    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(@as(u32, 1), dest[0]);
    try std.testing.expectEqual(@as(u32, 2), dest[1]);
}

test "read advances header so subsequent pop sees the right item" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 8);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try buf.push(3);
    try buf.push(4);

    var dest: [2]u32 = undefined;
    const n = buf.read(&dest);

    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(@as(u32, 1), dest[0]);
    try std.testing.expectEqual(@as(u32, 2), dest[1]);
    try std.testing.expectEqual(@as(u32, 3), try buf.pop());
    try std.testing.expectEqual(@as(u32, 4), try buf.pop());
}

test "read with wrap-around, fully within first segment" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 4);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try buf.push(3);
    _ = try buf.pop();
    _ = try buf.pop();
    try buf.push(4);
    try buf.push(5);
    // state: storage=[5,_,3,4], header=2, rearer=1, length=3

    var dest: [1]u32 = undefined;
    const n = buf.read(&dest);

    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(@as(u32, 3), dest[0]);
    try std.testing.expectEqual(@as(u32, 4), try buf.pop());
    try std.testing.expectEqual(@as(u32, 5), try buf.pop());
}

test "read with wrap-around, spanning both segments" {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buf = try RingBuffer(u32).init(allocator, 4);
    defer buf.deinit();

    try buf.push(1);
    try buf.push(2);
    try buf.push(3);
    _ = try buf.pop();
    _ = try buf.pop();
    try buf.push(4);
    try buf.push(5);
    // state: storage=[5,_,3,4], header=2, rearer=1, length=3

    var dest: [3]u32 = undefined;
    const n = buf.read(&dest);

    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(u32, 3), dest[0]);
    try std.testing.expectEqual(@as(u32, 4), dest[1]);
    try std.testing.expectEqual(@as(u32, 5), dest[2]);
    try std.testing.expectEqual(@as(usize, 0), buf.length - 3);
}
