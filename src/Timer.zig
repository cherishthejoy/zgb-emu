const SystemContext = @import("SystemContext.zig").SystemContext;

pub const Timer = struct {
    div: u16,
    tima: u8,
    tma: u8,
    tac: u8,

    pub fn init() Timer {
        return Timer{
            .div = 0xABCC,
            .tima = 0,
            .tma = 0,
            .tac = 0,
        };
    }

    pub fn tick(self: *Timer, ctx: *SystemContext) void {
        const prev_div: u16 = self.div;

        self.div +%= 1;

        var timer_update: bool = false;

        switch (self.tac & 0b11) {
            0b00 => timer_update = ((prev_div & (1 << 9)) != 0) and ((self.div & (1 << 9)) == 0),
            0b01 => timer_update = ((prev_div & (1 << 3)) != 0) and ((self.div & (1 << 3)) == 0),
            0b10 => timer_update = ((prev_div & (1 << 5)) != 0) and ((self.div & (1 << 5)) == 0),
            0b11 => timer_update = ((prev_div & (1 << 7)) != 0) and ((self.div & (1 << 7)) == 0),

            else => {},
        }

        if (timer_update and self.tac & (1 << 2) != 0) {
            self.tima +%= 1;

            if (self.tima == 0xFF) {
                self.tima = self.tma;
                ctx.int.requestInterrupt(.TIMER);
            }
        }
    }
    pub fn write(self: *Timer, address: u16, value: u8) void {
        switch (address) {
            0xFF04 => self.div = 0,
            0xFF05 => self.tima = value,
            0xFF06 => self.tma = value,
            0xFF07 => self.tac = value,
            else => unreachable,
        }
    }

    pub fn read(self: *const Timer, address: u16) u8 {
        return switch (address) {
            0xFF04 => @truncate(self.div >> 8),
            0xFF05 => self.tima,
            0xFF06 => self.tma,
            0xFF07 => self.tac,
            else => unreachable,
        };
    }
};
