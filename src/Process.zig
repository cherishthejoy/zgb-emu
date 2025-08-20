const std = @import("std");

const Cpu = @import("Cpu.zig").Cpu;
const util = @import("Utility.zig");
const RegisterType = @import("Instruction.zig").RegisterType;
const AddressMode = @import("Instruction.zig").AddressMode;

const Instruction = @import("Instruction.zig");

const RestRegisterType = @import("Instruction.zig").RestRegisterType;

const SystemContext = @import("SystemContext.zig").SystemContext;

pub fn load(self: *Cpu, ctx: *SystemContext) void {
    if (self.dest_is_mem) {
        if (util.is16Bit(self.inst.RT2)) {
            self.addCycles(1);
            ctx.bus.write16(ctx, self.mem_dest, self.fetched_data);
        } else {
            ctx.bus.write(ctx, self.mem_dest, @truncate(self.fetched_data));
        }
        self.addCycles(1);
        return;
    }

    if (self.inst.ADRM == .AM_HL_SPR) {
        const sign = @as(u16, @bitCast(@as(i16, @as(i8, @bitCast(@as(u8, @truncate(self.fetched_data)))))));

        const h_flag = ((self.readRegister(self.inst.RT2) & 0xF) +% (sign & 0xF)) >= 0x10;
        const c_flag = ((self.readRegister(self.inst.RT2) & 0xFF) +% (sign & 0xFF)) >= 0x100;

        self.registers.setFlags(false, false, h_flag, c_flag);
        self.setRegister(self.inst.RT, self.readRegister(self.inst.RT2) +% sign);
        return;
    }
    self.setRegister(self.inst.RT, self.fetched_data);
}

pub fn loadh(self: *Cpu, ctx: *SystemContext) void {
    if (self.inst.RT == RegisterType.A) {
        self.setRegister(self.inst.RT, ctx.bus.read(ctx, 0xFF00 | self.fetched_data));
    } else {
        ctx.bus.write(ctx, self.mem_dest, self.registers.a);
    }

    self.addCycles(1);
}

pub fn inc(self: *Cpu, ctx: *SystemContext) void {
    var value: u16 = self.readRegister(self.inst.RT) +% 1;

    if (util.is16Bit(self.inst.RT)) {
        self.addCycles(1);
    }

    if (self.inst.RT == RegisterType.HL and self.inst.ADRM == AddressMode.AM_MR) {
        value = ctx.bus.read(ctx, self.readRegister(.HL)) +% 1;
        value &= 0xFF;
        ctx.bus.write(ctx, self.readRegister(.HL), @truncate(value));
    } else {
        self.setRegister(self.inst.RT, value);
        value = self.readRegister(self.inst.RT);
    }

    if ((self.opcode & 0x03) == 0x03) {
        return;
    }

    self.registers.setFlags(value == 0, false, (value & 0x0F) == 0, null);
}

pub fn dec(self: *Cpu, ctx: *SystemContext) void {
    var value: u16 = self.readRegister(self.inst.RT) -% 1;

    if (util.is16Bit(self.inst.RT)) {
        self.addCycles(1);
    }

    if (self.inst.RT == RegisterType.HL and self.inst.ADRM == AddressMode.AM_MR) {
        value = ctx.bus.read(ctx, self.readRegister(.HL)) -% 1;
        ctx.bus.write(ctx, self.readRegister(.HL), @truncate(value));
    } else {
        self.setRegister(self.inst.RT, value);
        value = self.readRegister(self.inst.RT);
    }

    if ((self.opcode & 0x0B) == 0x0B) {
        return;
    }
    self.registers.setFlags(value == 0, true, (value & 0x0F) == 0x0F, null);
}

pub fn add(self: *Cpu, _: *SystemContext) void {
    var value = @as(u32, self.readRegister(self.inst.RT) +% self.fetched_data);

    const is_16_bit: bool = util.is16Bit(self.inst.RT);

    if (is_16_bit) {
        self.addCycles(1);
    }

    if (self.inst.RT == .SP) {
        value = self.readRegister(self.inst.RT) +% @as(u32, @bitCast(@as(i32, @as(i8, @bitCast(@as(u8, @truncate(self.fetched_data)))))));
    }

    // Set flags for base case
    var z: ?bool = (value & 0xFF) == 0;
    var h: ?bool = ((self.readRegister(self.inst.RT) & 0xF) + (self.fetched_data & 0xF)) >= 0x10;
    var c: ?bool = ((self.readRegister(self.inst.RT) & 0xFF) + (self.fetched_data & 0xFF)) >= 0x100;

    // ADD HL, r16
    if (is_16_bit) {
        z = null;
        h = ((self.readRegister(self.inst.RT) & 0xFFF) + (self.fetched_data & 0xFFF)) >= 0x1000;
        const n: u32 = @as(u32, self.readRegister(self.inst.RT)) + @as(u32, (self.fetched_data));
        c = n >= 0x10000;
    }
    // Set flags for 0xE8
    if (self.inst.RT == .SP) {
        z = false;
        h = (self.readRegister(self.inst.RT) & 0xF) + (self.fetched_data & 0xF) >= 0x10;
        c = ((self.readRegister(self.inst.RT)) & 0x00FF) + (self.fetched_data & 0xFF) >= 0x100;
    }

    self.setRegister(self.inst.RT, @truncate(value & 0xFFFF));
    self.registers.setFlags(z, false, h, c);
}

pub fn sub(self: *Cpu, _: *SystemContext) void {
    const value: u16 = self.readRegister(self.inst.RT) -% self.fetched_data;

    const z = value == 0;
    const h = ((self.readRegister(self.inst.RT) & 0xF) < (self.fetched_data & 0xF));
    const c = (self.readRegister(self.inst.RT) < self.fetched_data);

    self.setRegister(self.inst.RT, value);
    self.registers.setFlags(z, true, h, c);
}

pub fn adc(self: *Cpu, _: *SystemContext) void {
    const fd: u16 = self.fetched_data;
    const a: u16 = self.registers.a;
    const c: u16 = @intFromBool(self.registers.f.carry);

    self.registers.a = @truncate(a + fd + c);

    self.registers.setFlags(
        self.registers.a == 0,
        false,
        (a & 0xF) + (fd & 0xF) + c > 0xF,
        a + fd + c > 0xFF,
    );
}

pub fn sbc(self: *Cpu, _: *SystemContext) void {
    const fd: u16 = self.fetched_data;
    const a: u16 = self.registers.a;
    const c: u16 = @intFromBool(self.registers.f.carry);

    self.registers.a = @truncate(a -% fd -% c);
    self.registers.setFlags(self.registers.a == 0, true, (a & 0xF) < (fd & 0xF) + c, a < fd + c);
}

pub fn compare(self: *Cpu, _: *SystemContext) void {
    const result: u8 = @truncate(self.registers.a -% self.fetched_data);

    self.registers.setFlags(
        result == 0,
        true,
        (self.registers.a & 0xF) < (self.fetched_data & 0xF),
        self.registers.a < self.fetched_data,
    );
}

pub fn bitAnd(self: *Cpu, _: *SystemContext) void {
    self.registers.a &= @truncate(self.fetched_data);
    self.registers.setFlags(self.registers.a == 0, false, true, false);
}

pub fn bitOr(self: *Cpu, _: *SystemContext) void {
    self.registers.a |= @truncate(self.fetched_data);
    self.registers.setFlags(self.registers.a == 0, false, false, false);
}

pub fn bitXor(self: *Cpu, _: *SystemContext) void {
    self.registers.a ^= @truncate(self.fetched_data);
    self.registers.setFlags(self.registers.a == 0, false, false, false);
}

pub fn checkCon(self: *Cpu, _: *SystemContext) bool {
    const z = self.registers.f.zero;
    const c = self.registers.f.carry;

    switch (self.inst.CT) {
        .CT_NONE => return true,
        .CT_C => return c,
        .CT_NC => return !c,
        .CT_Z => return z,
        .CT_NZ => return !z,
    }
    return false;
}

pub fn gotoAddr(self: *Cpu, ctx: *SystemContext, addr: u16, push_pc: bool) void {
    if (checkCon(self, ctx)) {
        if (push_pc) {
            self.addCycles(2);
            self.push16(ctx, self.registers.pc);
        }
        self.registers.pc = addr;
        self.addCycles(1);
    }
}

pub fn jump(self: *Cpu, ctx: *SystemContext) void {
    gotoAddr(self, ctx, self.fetched_data, false);
}

pub fn jr(self: *Cpu, ctx: *SystemContext) void {
    const rel: i8 = @bitCast(@as(u8, @truncate(self.fetched_data & 0xFF)));
    const pc_signed: i32 = @as(i32, self.registers.pc);
    const addr: u16 = @intCast(@as(u32, @bitCast(pc_signed + @as(i32, rel))));

    gotoAddr(self, ctx, addr, false);
}

pub fn call(self: *Cpu, ctx: *SystemContext) void {
    gotoAddr(self, ctx, self.fetched_data, true);
}

pub fn rst(self: *Cpu, ctx: *SystemContext) void {
    gotoAddr(self, ctx, self.inst.PARAM, true);
}

pub fn ret(self: *Cpu, ctx: *SystemContext) void {
    if (self.inst.CT != .CT_NONE) {
        self.addCycles(1);
    }

    if (checkCon(self, ctx)) {
        const lo: u16 = self.pop(ctx);
        self.addCycles(1);
        const hi: u16 = self.pop(ctx);
        self.addCycles(1);

        const n: u16 = (hi << 8) | lo;
        self.registers.pc = n;

        self.addCycles(1);
    }
}

pub fn reti(self: *Cpu, ctx: *SystemContext) void {
    self.ime = true;
    ret(self, ctx);
}

pub fn pop(self: *Cpu, ctx: *SystemContext) void {
    const lo: u16 = self.pop(ctx);
    self.addCycles(1);
    const hi: u16 = self.pop(ctx);
    self.addCycles(1);

    const n: u16 = (hi << 8) | lo;

    self.setRegister(self.inst.RT, n);

    if (self.inst.RT == .AF) {
        self.setRegister(self.inst.RT, n & 0xFFF0);
    }
}

pub fn push(self: *Cpu, ctx: *SystemContext) void {
    const hi: u16 = (self.readRegister(self.inst.RT) >> 8) & 0xFF;
    self.addCycles(1);
    self.push(ctx, @truncate(hi));

    const lo: u16 = self.readRegister(self.inst.RT) & 0xFF;
    self.addCycles(1);
    self.push(ctx, @truncate(lo));

    self.addCycles(1);
}

pub fn di(self: *Cpu, _: *SystemContext) void {
    self.ime = false;
}

pub fn ei(self: *Cpu, _: *SystemContext) void {
    self.enable_ime = true;
}

pub fn decodeReg(reg: u8) RestRegisterType {
    if (reg > 0b111) {
        return RestRegisterType.NONE;
    }
    return @enumFromInt(reg);
}

pub fn cb(self: *Cpu, ctx: *SystemContext) void {

    // Example: CB47 => 47 (01000111) => 01(BIT), 000(Bit 0), 111(A Register)

    const op: u8 = @truncate(self.fetched_data);
    const reg: RestRegisterType = decodeReg(op & 0b111);
    const bit: u8 = (op >> 3) & 0b111;
    const bit_op: u8 = (op >> 6) & 0b11;
    var reg_val: u8 = self.readRegister8(ctx, reg);

    self.addCycles(1);

    if (reg == .HL) {
        self.addCycles(2);
    }

    switch (bit_op) {
        1 => {
            // BIT
            self.registers.setFlags((reg_val & std.math.shl(u8, 1, bit)) == 0, false, true, null);
            return;
        },
        2 => {
            // RST
            reg_val &= ~std.math.shl(u8, 1, bit);
            self.setRegister8(ctx, reg, reg_val);
            return;
        },
        3 => {
            // SET

            reg_val |= std.math.shl(u8, 1, bit);
            self.setRegister8(ctx, reg, reg_val);
            return;
        },
        else => {},
    }
    const flag_c: bool = self.registers.f.carry;

    switch (bit) {
        0 => {
            // RLC
            var set_c: bool = false;
            var result: u8 = (reg_val << 1) & 0xFF;

            if ((reg_val & (1 << 7)) != 0) {
                result |= 1;
                set_c = true;
            }
            self.setRegister8(ctx, reg, result);
            self.registers.setFlags(result == 0, false, false, set_c);
            return;
        },
        1 => {
            // RRC
            const old: u8 = reg_val;
            reg_val >>= 1;
            reg_val |= (old << 7);

            self.setRegister8(ctx, reg, reg_val);
            self.registers.setFlags(reg_val == 0, false, false, (old & 1) != 0);
            return;
        },
        2 => {
            // RL
            const old: u8 = reg_val;
            reg_val <<= 1;
            reg_val |= @intFromBool(flag_c);

            self.setRegister8(ctx, reg, reg_val);
            self.registers.setFlags(reg_val == 0, false, false, (old & 0x80) != 0);
            return;
        },
        3 => {
            // RR
            const old: u8 = reg_val;
            reg_val >>= 1;
            reg_val |= (@as(u8, @intFromBool(flag_c)) << 7);

            self.setRegister8(ctx, reg, reg_val);
            self.registers.setFlags(reg_val == 0, false, false, (old & 1) != 0);
            return;
        },
        4 => {
            // SLA
            const old: u8 = reg_val;
            reg_val <<= 1;
            self.setRegister8(ctx, reg, reg_val);
            self.registers.setFlags(reg_val == 0, false, false, (old & 0x80) != 0);
            return;
        },
        5 => {
            // SRA
            const u: u8 = (reg_val >> 1) | (reg_val & 0x80);
            self.setRegister8(ctx, reg, u);
            self.registers.setFlags(u == 0, false, false, (reg_val & 1) != 0);
            return;
        },
        6 => {
            // SWAP
            reg_val = ((reg_val & 0xF0) >> 4) | ((reg_val & 0xF) << 4);
            self.setRegister8(ctx, reg, reg_val);
            self.registers.setFlags(reg_val == 0, false, false, false);
            return;
        },
        7 => {
            // SRL
            const u: u8 = reg_val >> 1;
            self.setRegister8(ctx, reg, u);
            self.registers.setFlags(u == 0, false, false, (reg_val & 1) != 0);
            return;
        },
        else => return,
    }

    std.log.warn("Warning: Invalid CB: {X:0>2}", .{op});
    return;
}

pub fn rlca(self: *Cpu, _: *SystemContext) void {
    var u: u8 = self.registers.a;
    const c: u8 = (u >> 7) & 1;
    u = (u << 1) | c;
    self.registers.a = u;

    self.registers.setFlags(false, false, false, c != 0);
}

pub fn rrca(self: *Cpu, _: *SystemContext) void {
    const b: u8 = self.registers.a & 1;
    self.registers.a >>= 1;
    self.registers.a |= (b << 7);
    self.registers.setFlags(false, false, false, b != 0);
}

pub fn rla(self: *Cpu, _: *SystemContext) void {
    const u: u8 = self.registers.a;
    const c_flag: bool = self.registers.f.carry;
    const c: u8 = (u >> 7) & 1;

    self.registers.a = (u << 1) | @intFromBool(c_flag);

    self.registers.setFlags(false, false, false, c != 0);
}

pub fn rra(self: *Cpu, _: *SystemContext) void {
    const carry = self.registers.f.carry;
    const new_c = self.registers.a & 1;

    self.registers.a >>= 1;
    self.registers.a |= (@as(u8, @intFromBool(carry)) << 7);

    self.registers.setFlags(false, false, false, new_c != 0);
}

pub fn daa(self: *Cpu, _: *SystemContext) void {
    var u: u8 = 0;
    var fc: u8 = 0;

    if (self.registers.f.half_carry or (!self.registers.f.subtract and (self.registers.a & 0xF) > 9)) {
        u = 6;
    }

    if (self.registers.f.carry or (!self.registers.f.subtract and self.registers.a > 0x99)) {
        u |= 0x60;
        fc = 1;
    }

    self.registers.a = if (self.registers.f.subtract) self.registers.a -% u else self.registers.a +% u;
    self.registers.setFlags(self.registers.a == 0, null, false, fc != 0);
}

pub fn cpl(self: *Cpu, _: *SystemContext) void {
    self.registers.a = ~self.registers.a;
    self.registers.setFlags(null, true, true, null);
}

pub fn scf(self: *Cpu, _: *SystemContext) void {
    self.registers.setFlags(null, false, false, true);
}

pub fn ccf(self: *Cpu, _: *SystemContext) void {
    self.registers.setFlags(null, false, false, !self.registers.f.carry);
}

pub fn halt(self: *Cpu, _: *SystemContext) void {
    self.halted = true;
}

pub fn stop(_: *Cpu, _: *SystemContext) void {
    std.debug.print("STOP Implementation\n", .{});
    // std.process.exit(1);
}

const InstructionHandler = *const fn (*Cpu, ctx: *SystemContext) void;

pub const instruction_handler = std.EnumArray(Instruction.InstructionType, ?InstructionHandler).init(.{
    .NO_IMPL = null,
    .LD = load,
    .LDH = loadh,
    .INC = inc,
    .DEC = dec,
    .ADD = add,
    .SUB = sub,
    .ADC = adc,
    .SBC = sbc,
    .CP = compare,
    .CB = cb,
    .RRCA = rrca,
    .RLCA = rlca,
    .RRA = rra,
    .RLA = rla,
    .AND = bitAnd,
    .OR = bitOr,
    .XOR = bitXor,
    .JP = jump,
    .JR = jr,
    .CALL = call,
    .RET = ret,
    .RETI = reti,
    .RST = rst,
    .NOP = null,
    .HALT = halt,
    .STOP = stop,
    .DI = di,
    .EI = ei,
    .DAA = daa,
    .CPL = cpl,
    .SCF = scf,
    .CCF = ccf,
    .POP = pop,
    .PUSH = push,
});
