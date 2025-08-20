const std = @import("std");

const SystemContext = @import("SystemContext.zig").SystemContext;

const Lcd = @import("Lcd.zig").Lcd;
const LcdMode = @import("Lcd.zig").LcdMode;

const State = @import("State.zig");

//  Bit7   BG and Window over OBJ (0=No, 1=BG and Window colors 1-3 over the OBJ)
//  Bit6   Y flip          (0=Normal, 1=Vertically mirrored)
//  Bit5   X flip          (0=Normal, 1=Horizontally mirrored)
//  Bit4   Palette number  **Non CGB Mode Only** (0=OBP0, 1=OBP1)
//  Bit3   Tile VRAM-Bank  **CGB Mode Only**     (0=Bank 0, 1=Bank 1)
//  Bit2-0 Palette number  **CGB Mode Only**     (OBP0-7)

const LINES_PER_FRAME = 154;
const TICKS_PER_LINE = 456;
const YRES = 144;
const XRES = 160;

const BUFFER_SIZE = YRES * XRES;

pub const FetchState = enum {
    TILE,
    DATA0,
    DATA1,
    IDLE,
    PUSH,
};

pub const FifoEntry = struct {
    next: ?*FifoEntry,
    value: u32,
};

pub const Fifo = struct {
    head: u8,
    tail: u8,
    size: u32,
    data: [16]u32 = undefined,

    pub fn init() Fifo {
        return Fifo{
            .head = 0,
            .tail = 0,
            .size = 0,
            .data = [_]u32{0} ** 16,
        };
    }
};

pub const PixelFifo = struct {
    cur_fetch_state: FetchState,
    pixel_fifo: Fifo,
    line_x: u8,
    pushed_x: u8,
    fetch_x: u8,
    bgw_fetch_data: [3]u8,
    fetch_entry_data: [6]u8,
    map_y: u8,
    map_x: u8,
    tile_y: u8,
    tile_x: u8,
    fifo_x: u8,

    pub fn init() PixelFifo {
        return PixelFifo{
            .cur_fetch_state = .TILE,
            .pixel_fifo = Fifo.init(),
            .line_x = 0,
            .pushed_x = 0,
            .fetch_x = 0,
            .bgw_fetch_data = [_]u8{0} ** 3,
            .fetch_entry_data = [_]u8{0} ** 6,
            .map_y = 0,
            .map_x = 0,
            .tile_y = 0,
            .tile_x = 0,
            .fifo_x = 0,
        };
    }
};

pub const OamEntry = packed struct {
    y: u8,
    x: u8,
    tile: u8,

    flags: packed struct {
        f_cgb_pn: u3,
        f_cgb_vram_bank: u1,
        f_pn: u1,
        f_x_flip: u1,
        f_y_flip: u1,
        f_bgp: u1,
    },
};

pub const OamLineEntry = struct {
    entry: OamEntry,
    next: ?*OamLineEntry,
};

pub const Ppu = struct {
    oam_ram: [40]OamEntry,
    vram: [0x2000]u8,
    lcd: Lcd,

    line_sprite_count: u8,
    line_sprites: ?*OamLineEntry,
    line_entry_array: [10]OamLineEntry,

    fetched_entry_count: u8,
    fetched_entries: [3]OamEntry,

    window_line: u8,

    pfc: PixelFifo,

    current_frame: u32,
    line_ticks: u32,
    video_buffer: [BUFFER_SIZE]u32,

    pub fn init() Ppu {
        var ppu = Ppu{
            .oam_ram = [_]OamEntry{std.mem.zeroes(OamEntry)} ** 40,
            .vram = [_]u8{0} ** 0x2000,
            .lcd = Lcd.init(),

            .line_sprite_count = 0,
            .line_sprites = null,
            .line_entry_array = [_]OamLineEntry{std.mem.zeroes(OamLineEntry)} ** 10,

            .fetched_entry_count = 0,
            .fetched_entries = [_]OamEntry{std.mem.zeroes(OamEntry)} ** 3,

            .window_line = 0,

            .pfc = PixelFifo.init(),
            .current_frame = 0,
            .line_ticks = 0,
            .video_buffer = [_]u32{0} ** BUFFER_SIZE,
        };

        ppu.lcd.regs.lcdsModeSet(.OAM);

        return ppu;
    }

    pub fn tick(self: *Ppu, ctx: *SystemContext) void {
        self.line_ticks += 1;

        switch (self.lcd.regs.lcdsMode()) {
            .OAM => State.ppuModeOam(self),
            .XFER => State.ppuModeXfer(self, ctx),
            .VBLANK => State.ppuModeVblank(self, ctx),
            .HBLANK => State.ppuModeHblank(self, ctx),
        }
    }

    pub fn oamWrite(self: *Ppu, address: u16, value: u8) void {
        const addr = if (address >= 0xFE00) address - 0xFE00 else address;

        if (addr >= 0xA0) return;

        const oam_bytes = @as([*]u8, @ptrCast(&self.oam_ram));
        oam_bytes[addr] = value;
    }

    pub fn oamRead(self: *Ppu, address: u16) u8 {
        const addr = if (address >= 0xFE00) address - 0xFE00 else address;

        if (addr >= 0xA0) return 0;
        const oam_bytes = @as([*]const u8, @ptrCast(&self.oam_ram));
        return oam_bytes[addr];
    }

    pub fn vramWrite(self: *Ppu, address: u16, value: u8) void {
        self.vram[address - 0x8000] = value;
    }

    pub fn vramRead(self: *Ppu, address: u16) u8 {
        return self.vram[address - 0x8000];
    }

    pub fn clearBuffer(self: *Ppu) void {
        @memset(&self.video_buffer, 0);
    }
};
