const std = @import("std");

const Cartridge = @import("Cartridge.zig").Cartridge;
const SystemContext = @import("SystemContext.zig").SystemContext;

const Io = @import("Io.zig");
const Ppu = @import("Ppu.zig").Ppu;

pub const Bus = struct {
    cart: *Cartridge,
    wram: [0x2000]u8,
    hram: [0x80]u8,
    ppu: Ppu,

    pub fn init(cart: *Cartridge) Bus {
        return Bus{
            .cart = cart,
            .wram = [_]u8{0} ** 0x2000,
            .hram = [_]u8{0} ** 0x80,
            .ppu = Ppu.init(),
        };
    }

    pub fn read16(self: *const Bus, ctx: *SystemContext, address: u16) u16 {
        const lo: u16 = self.read(ctx, address);
        const hi: u16 = self.read(ctx, address + 1);

        return lo | (hi << 8);
    }

    pub fn write16(self: *Bus, ctx: *SystemContext, address: u16, value: u16) void {
        self.write(ctx, address + 1, @truncate((value >> 8) & 0xFF));
        self.write(ctx, address, @truncate(value & 0xFF));
    }

    pub fn read(self: *Bus, ctx: *SystemContext, address: u16) u8 {
        return switch (address) {
            0x0000...0x7FFF => self.cart.read(address),
            0x8000...0x9FFF => self.ppu.vramRead(address),
            0xA000...0xBFFF => self.cart.read(address),
            0xC000...0xDFFF => self.wread(address),
            0xE000...0xFDFF => 0, // NOTE: Echo RAM
            0xFE00...0xFE9F => {
                if (ctx.dma.transferring()) {
                    return 0xFF;
                }
                return self.ppu.oamRead(address);
            },
            0xFEA0...0xFEFF => 0,
            0xFF00...0xFF7F => Io.read(ctx, address),
            0xFFFF => ctx.int.ie,
            else => self.hread(address),
        };
    }

    pub fn write(self: *Bus, ctx: *SystemContext, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x7FFF => self.cart.write(address, value),
            0x8000...0x9FFF => self.ppu.vramWrite(address, value),
            0xA000...0xBFFF => self.cart.write(address, value),
            0xC000...0xDFFF => self.wwrite(address, value),
            0xE000...0xFDFF => return,
            0xFE00...0xFE9F => {
                if (ctx.dma.transferring()) {
                    return;
                }
                self.ppu.oamWrite(address, value);
            },
            0xFEA0...0xFEFF => return, //NOTE: Unusable
            0xFF00...0xFF7F => Io.write(ctx, address, value),
            0xFFFF => ctx.int.ie = value,
            else => self.hwrite(address, value),
        }
    }

    pub fn wread(self: *const Bus, address: u16) u8 {
        const addr = address -% 0xC000;

        if (addr >= 0x2000) {
            std.log.info("INVALID WRAM ADDRESS: {X}", .{addr + 0xC000});
            std.process.exit(1);
        }
        return self.wram[addr];
    }

    pub fn hread(self: *const Bus, address: u16) u8 {
        const addr = address -% 0xFF80;
        return self.hram[addr];
    }

    pub fn wwrite(self: *Bus, address: u16, value: u8) void {
        const addr = address -% 0xC000;
        self.wram[addr] = value;
    }

    pub fn hwrite(self: *Bus, address: u16, value: u8) void {
        const addr = address -% 0xFF80;
        self.hram[addr] = value;
    }

    pub fn deinit(self: *Bus) void {
        self.cart.deinit();
    }
};
