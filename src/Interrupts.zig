pub const InterruptType = enum(u8) {
    VBLANK = 1,
    STAT = 2,
    TIMER = 4,
    SERIAL = 8,
    JOYPAD = 16,
};

pub const Interrupts = struct {
    ie: u8,
    intf: u8,

    pub fn init() Interrupts {
        return Interrupts{
            .ie = 0,
            .intf = 0,
        };
    }

    pub fn requestInterrupt(self: *Interrupts, it: InterruptType) void {
        const interrupt_bit = @intFromEnum(it);
        self.intf |= interrupt_bit;
    }
};
