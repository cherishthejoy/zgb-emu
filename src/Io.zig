const std = @import("std");

const SystemContext = @import("SystemContext.zig").SystemContext;

pub var serial_data: [2]u8 = .{ 0, 0 };

pub fn read(ctx: *SystemContext, address: u16) u8 {
    return switch (address) {
        0xFF00 => return ctx.gp.getOutput(),
        0xFF01 => serial_data[0],
        0xFF02 => serial_data[1],
        0xFF04...0xFF07 => ctx.timer.read(address),
        0xFF0F => ctx.int.intf,
        0xFF10...0xFF3F => {
            // NOTE: Audio not implemented
            return 0;
        },
        0xFF40...0xFF4B => {
            return ctx.bus.ppu.lcd.read(address);
        },
        else => 0,
    };
}

pub fn write(ctx: *SystemContext, address: u16, value: u8) void {
    switch (address) {
        0xFF00 => ctx.gp.setSelect(value),
        0xFF01 => serial_data[0] = value,
        0xFF02 => serial_data[1] = value,
        0xFF04...0xFF07 => ctx.timer.write(address, value),
        0xFF0F => ctx.int.intf = value,
        0xFF10...0xFF3F => {
            // NOTE: Audio not implemented
            return;
        },
        0xFF40...0xFF4B => {
            ctx.bus.ppu.lcd.write(ctx, address, value);
        },
        else => return,
    }
}
