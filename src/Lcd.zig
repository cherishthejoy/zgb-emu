const std = @import("std");
const rl = @import("raylib");

const SystemContext = @import("SystemContext.zig").SystemContext;

const colors_default: [4]u32 = .{ 0xFFFFFFFF, 0xFFAAAAAA, 0xFF555555, 0xFF000000 };

pub const LcdMode = enum {
    HBLANK,
    VBLANK,
    OAM,
    XFER,
};

pub const Lcd = struct {
    regs: LcdRegs,
    bg_colors: [4]u32,
    sp1_colors: [4]u32,
    sp2_colors: [4]u32,

    pub fn init() Lcd {
        var lcd = Lcd{
            .regs = LcdRegs.init(),
            .bg_colors = [_]u32{ 0, 0, 0, 0 },
            .sp1_colors = [_]u32{ 0, 0, 0, 0 },
            .sp2_colors = [_]u32{ 0, 0, 0, 0 },
        };

        for (0..4) |i| {
            lcd.bg_colors[i] = colors_default[i];
            lcd.sp1_colors[i] = colors_default[i];
            lcd.sp2_colors[i] = colors_default[i];
        }

        return lcd;
    }

    pub fn read(self: *const Lcd, address: u16) u8 {
        return switch (address) {
            0xFF40 => @bitCast(self.regs.lcdc),
            0xFF41 => @bitCast(self.regs.lcds),
            0xFF42 => self.regs.scroll_y,
            0xFF43 => self.regs.scroll_x,
            0xFF44 => self.regs.ly,
            0xFF45 => self.regs.ly_cmp,
            0xFF46 => self.regs.dma,
            0xFF47 => self.regs.bg_palette,
            0xFF48 => self.regs.obj_palette0,
            0xFF49 => self.regs.obj_palette1,
            0xFF4A => self.regs.win_y,
            0xFF4B => self.regs.win_x,
            else => 0xFF,
        };
    }

    pub fn write(self: *Lcd, ctx: *SystemContext, address: u16, value: u8) void {
        switch (address) {
            0xFF40 => self.regs.lcdc = @bitCast(value),
            0xFF41 => self.regs.lcds = @bitCast(value),
            0xFF42 => self.regs.scroll_y = value,
            0xFF43 => self.regs.scroll_x = value,
            0xFF44 => self.regs.ly = value,
            0xFF45 => self.regs.ly_cmp = value,
            0xFF46 => ctx.dma.dstart(value),
            0xFF47 => self.updatePalette(value, 0),
            0xFF48 => self.updatePalette(value & 0b11111100, 1),
            0xFF49 => self.updatePalette(value & 0b11111100, 2),
            0xFF4A => self.regs.win_y = value,
            0xFF4B => self.regs.win_x = value,
            else => return,
        }
    }

    pub fn updatePalette(self: *Lcd, palette_data: u8, pal: u8) void {
        var p_colors: *[4]u32 = &self.bg_colors;

        switch (pal) {
            0 => {},
            1 => p_colors = &self.sp1_colors,
            2 => p_colors = &self.sp2_colors,
            else => unreachable,
        }

        p_colors[0] = colors_default[palette_data & 0b11];
        p_colors[1] = colors_default[(palette_data >> 2) & 0b11];
        p_colors[2] = colors_default[(palette_data >> 4) & 0b11];
        p_colors[3] = colors_default[(palette_data >> 6) & 0b11];
    }
};

pub const LcdcFields = packed struct {
    bg_window_enable_prio: bool,
    obj_enable: bool,
    obj_size: bool,
    bg_tile_map: bool,
    bg_window_tiles: bool,
    window_enable: bool,
    window_tile_map: bool,
    lcd_enable: bool,
};

pub const LcdsFields = packed struct {
    mode: u2,
    lyc_eq_ly: bool,
    hblank: bool,
    vblank: bool,
    oam: bool,
    lyc_int: bool,
    _pad7: bool = false,
};

pub const LcdRegs = packed struct {
    lcdc: u8, // FF40
    lcds: u8, // FF41
    scroll_y: u8, // FF42
    scroll_x: u8, // FF43
    ly: u8, // FF44
    ly_cmp: u8, // FF45
    dma: u8, // FF46
    bg_palette: u8, // FF47
    obj_palette0: u8, // FF48
    obj_palette1: u8, // FF49
    win_y: u8, // FF4A
    win_x: u8, // FF4B

    pub fn init() LcdRegs {
        return LcdRegs{
            .lcdc = 0x91,
            .lcds = 0,
            .scroll_y = 0,
            .scroll_x = 0,
            .ly = 0,
            .ly_cmp = 0,
            .dma = 0,
            .bg_palette = 0xFC,
            .obj_palette0 = 0xFF,
            .obj_palette1 = 0xFF,
            .win_y = 0,
            .win_x = 0,
        };
    }

    pub fn lcdcBgwEnable(self: *LcdRegs) bool {
        return self.lcdcView().bg_window_enable_prio;
    }

    pub fn lcdcObjEnable(self: *LcdRegs) bool {
        return self.lcdcView().obj_enable;
    }

    pub fn lcdcObjHeight(self: *LcdRegs) u8 {
        return if (self.lcdcView().obj_size) 16 else 8;
    }

    pub fn bgMapArea(self: *LcdRegs) u16 {
        return if (self.lcdcView().bg_tile_map) 0x9C00 else 0x9800;
    }

    pub fn bgwDataArea(self: *LcdRegs) u16 {
        return if (self.lcdcView().bg_window_tiles) 0x8000 else 0x8800;
    }

    pub fn lcdcWindowEnable(self: *LcdRegs) bool {
        return self.lcdcView().window_enable;
    }

    pub fn lcdcWinMapArea(self: *LcdRegs) u16 {
        return if (self.lcdcView().window_tile_map) 0x9C00 else 0x9800;
    }

    pub fn lcdcLcdEnable(self: *LcdRegs) bool {
        return self.lcdcView().lcd_enable;
    }

    pub fn lcdsMode(self: *LcdRegs) LcdMode {
        return @enumFromInt(self.lcds & 0b11);
    }

    pub fn lcdsModeSet(self: *LcdRegs, mode: LcdMode) void {
        self.lcds &= ~@as(u8, 0b11);
        self.lcds |= @intFromEnum(mode);
    }

    pub fn lcdsLyc(self: *LcdRegs) bool {
        return self.lcdsView().lyc_eq_ly;
    }

    pub fn lcdsLycSet(self: *LcdRegs, value: bool) void {
        self.lcdsView().lyc_eq_ly = value;
    }

    pub fn lcdcView(self: *LcdRegs) *LcdcFields {
        return @ptrCast(&self.lcdc);
    }

    pub fn lcdsView(self: *LcdRegs) *LcdsFields {
        return @ptrCast(&self.lcds);
    }
};
