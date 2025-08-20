const std = @import("std");

const ZERO_FLAG_BYTE_POSITION: u8 = 7;
const SUBTRACT_FLAG_BYTE_POSITION: u8 = 6;
const HALF_CARRY_FLAG_BYTE_POSITION: u8 = 5;
const CARRY_FLAG_BYTE_POSITION: u8 = 4;

pub const FlagRegister = struct {
    zero: bool,
    subtract: bool,
    half_carry: bool,
    carry: bool,

    pub fn init() FlagRegister {
        return .{
            .zero = true,
            .subtract = false,
            .half_carry = true,
            .carry = true,
        };
    }

    pub fn toByte(self: *const FlagRegister) u8 {
        return (@as(u8, if (self.zero) 1 else 0) << ZERO_FLAG_BYTE_POSITION) |
            (@as(u8, if (self.subtract) 1 else 0) << SUBTRACT_FLAG_BYTE_POSITION) |
            (@as(u8, if (self.half_carry) 1 else 0) << HALF_CARRY_FLAG_BYTE_POSITION) |
            (@as(u8, if (self.carry) 1 else 0) << CARRY_FLAG_BYTE_POSITION);
    }

    pub fn fromByte(byte: u8) FlagRegister {
        return .{
            .zero = ((byte >> ZERO_FLAG_BYTE_POSITION) & 0b1) != 0,
            .subtract = ((byte >> SUBTRACT_FLAG_BYTE_POSITION) & 0b1) != 0,
            .half_carry = ((byte >> HALF_CARRY_FLAG_BYTE_POSITION) & 0b1) != 0,
            .carry = ((byte >> CARRY_FLAG_BYTE_POSITION) & 0b1) != 0,
        };
    }
};
