const std = @import("std");

const FlagRegister = @import("FlagRegister.zig").FlagRegister;

pub const Register = struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: FlagRegister,
    h: u8,
    l: u8,
    pc: u16,
    sp: u16,

    pub fn init() Register {
        return Register{
            .a = 0x01,
            .b = 0x00,
            .c = 0x13,
            .d = 0x00,
            .e = 0xD8,
            .f = FlagRegister.init(),
            .h = 0x01,
            .l = 0x4D,
            .pc = 0x0100,
            .sp = 0xFFFE,
        };
    }

    pub fn setFlags(self: *Register, z: ?bool, n: ?bool, h: ?bool, c: ?bool) void {
        if (z) |zero| {
            self.f.zero = zero;
        }
        if (n) |subtract| {
            self.f.subtract = subtract;
        }
        if (h) |half_carry| {
            self.f.half_carry = half_carry;
        }
        if (c) |carry| {
            self.f.carry = carry;
        }
    }

    pub fn getAF(self: *const Register) u16 {
        return @as(u16, self.a) << 8 | @as(u16, self.f.toByte());
    }

    pub fn getBC(self: *const Register) u16 {
        return @as(u16, self.b) << 8 | @as(u16, self.c);
    }

    pub fn getDE(self: *const Register) u16 {
        return @as(u16, self.d) << 8 | @as(u16, self.e);
    }

    pub fn getHL(self: *const Register) u16 {
        return @as(u16, self.h) << 8 | @as(u16, self.l);
    }

    pub fn setPC(self: *Register, value: u16) void {
        self.pc = value;
    }

    pub fn setSP(self: *Register, value: u16) void {
        self.sp = value;
    }

    pub fn setAF(self: *Register, value: u16) void {
        self.a = @truncate((value & 0xFF00) >> 8);
        self.f = FlagRegister.fromByte(@truncate(value & 0xFF));
    }

    pub fn setBC(self: *Register, value: u16) void {
        self.b = @truncate((value & 0xFF00) >> 8);
        self.c = @truncate(value & 0xFF);
    }

    pub fn setDE(self: *Register, value: u16) void {
        self.d = @truncate((value & 0xFF00) >> 8);
        self.e = @truncate(value & 0xFF);
    }

    pub fn setHL(self: *Register, value: u16) void {
        self.h = @truncate((value & 0xFF00) >> 8);
        self.l = @truncate(value & 0xFF);
    }
};
