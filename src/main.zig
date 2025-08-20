const std = @import("std");
const System = @import("System.zig").System;
const Cartridge = @import("Cartridge.zig").Cartridge;
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cart = try Cartridge.load(allocator, args[2]);
    cart.debug() catch |err| {
        std.log.err("Failed to load from the savefile: {}", .{err});
    };
    defer cart.deinit();
    var sys = System.init(&cart);

    try sys.run();
}
