const std = @import("std");

const Cartridge = @import("Cartridge.zig").Cartridge;

const Cpu = @import("Cpu.zig").Cpu;
const Bus = @import("Bus.zig").Bus;
const Interrupts = @import("Interrupts.zig").Interrupts;
const Timer = @import("Timer.zig").Timer;
const Dma = @import("Dma.zig").Dma;
const Lcd = @import("Lcd.zig").Lcd;

const Gamepad = @import("Gamepad.zig").Gamepad;

const SystemContext = @import("SystemContext.zig").SystemContext;

const Ui = @import("Ui.zig");

pub const System = struct {
    cpu: Cpu,
    bus: Bus,
    timer: Timer,
    int: Interrupts,
    dma: Dma,

    gp: Gamepad,

    running: bool,
    paused: bool,
    die: bool,
    ticks: u64,

    pub fn init(cart: *Cartridge) System {
        var sys = System{
            .timer = Timer.init(),
            .cpu = Cpu.init(),
            .bus = undefined,
            .int = Interrupts.init(),
            .dma = Dma.init(),

            .gp = Gamepad.init(),

            .ticks = 0,
            .running = false,
            .paused = false,
            .die = false,
        };

        sys.bus = Bus.init(cart);

        return sys;
    }

    pub fn step(self: *System, ctx: *SystemContext) void {
        self.running = true;
        self.paused = false;
        self.ticks = 0;

        while (self.running and !self.die) {
            // if (self.paused) {
            //     // std.Thread.sleep(10000000);
            //     continue;
            // }

            const cpu_cycles = self.cpu.step(ctx);
            self.ticker(ctx, cpu_cycles);
        }
    }

    pub fn run(self: *System) !void {
        try Ui.init();
        defer Ui.cleanUp();

        var cpu_ctx = SystemContext{
            .bus = &self.bus,
            .int = &self.int,
            .timer = &self.timer,
            .dma = &self.dma,
            .gp = &self.gp,
        };

        const cpu_handle = try std.Thread.spawn(.{}, step, .{ self, &cpu_ctx });
        defer cpu_handle.join();

        std.log.info("Starting Emulation", .{});

        var prev_frame: u32 = 0;

        while (!self.die) {
            // std.time.sleep(1000 * std.time.ns_per_ms);
            Ui.handleEvents(self, &cpu_ctx);

            if (prev_frame != cpu_ctx.bus.ppu.current_frame) {
                Ui.update(&cpu_ctx);
            }

            prev_frame = cpu_ctx.bus.ppu.current_frame;
        }
    }

    pub fn ticker(self: *System, ctx: *SystemContext, cpu_cycles: u8) void {
        for (0..cpu_cycles) |_| {
            for (0..4) |_| {
                self.ticks += 1;
                self.timer.tick(ctx);
                ctx.bus.ppu.tick(ctx);
            }
            ctx.dma.tick(ctx);
        }
    }

    pub fn deinit(self: *System) void {
        self.bus.deinit();
    }
};
