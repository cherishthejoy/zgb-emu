const std = @import("std");
const SystemContext = @import("SystemContext.zig").SystemContext;

pub const Dma = struct {
    active: bool,
    byte: u8,
    value: u8,
    start_delay: u8,

    pub fn init() Dma {
        return Dma{
            .active = false,
            .byte = 0,
            .value = 0,
            .start_delay = 0,
        };
    }

    pub fn dstart(self: *Dma, start: u8) void {
        self.active = true;
        self.byte = 0;
        self.start_delay = 2;
        self.value = start;
    }

    pub fn tick(self: *Dma, ctx: *SystemContext) void {
        if (!self.active) {
            return;
        }

        if (self.start_delay != 0) {
            self.start_delay -= 1;
            return;
        }

        const data = @as(u16, @intCast(self.value)) * 0x100;

        ctx.bus.ppu.oamWrite(self.byte, ctx.bus.read(ctx, data + self.byte));

        self.byte += 1;
        self.active = (self.byte < 0xA0);
    }

    pub fn transferring(self: *Dma) bool {
        return self.active;
    }
};
