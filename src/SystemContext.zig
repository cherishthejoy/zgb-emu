const Bus = @import("Bus.zig").Bus;
const Interrupts = @import("Interrupts.zig").Interrupts;
const Timer = @import("Timer.zig").Timer;
const Dma = @import("Dma.zig").Dma;
const Lcd = @import("Lcd.zig").Lcd;
const Gamepad = @import("Gamepad.zig").Gamepad;

pub const SystemContext = struct {
    bus: *Bus,
    int: *Interrupts,
    timer: *Timer,
    dma: *Dma,
    gp: *Gamepad,
};
