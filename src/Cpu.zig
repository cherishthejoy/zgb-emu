const std = @import("std");
const Register = @import("Register.zig").Register;
const FlagRegister = @import("FlagRegister.zig").FlagRegister;
const RegisterType = @import("Instruction.zig").RegisterType;
const RestRegisterType = @import("Instruction.zig").RestRegisterType;
const AddressMode = @import("Instruction.zig").AddressMode;
const Instruction = @import("Instruction.zig").Instruction;

const Inst = @import("Instruction.zig");

const cf = @import("Fetch.zig");
const cp = @import("Process.zig");
const util = @import("Utility.zig");

const Interrupts = @import("Interrupts.zig").Interrupts;
const InterruptsType = @import("Interrupts.zig").InterruptType;

const SystemContext = @import("SystemContext.zig").SystemContext;

const CPU_DEBUG = false;

pub const Cpu = struct {
    registers: Register,

    opcode: u8,
    inst: *const Instruction,

    dest_is_mem: bool,
    mem_dest: u16,
    fetched_data: u16,

    halted: bool,
    ime: bool,
    enable_ime: bool,

    cycle_debt: u8,

    pub fn init() Cpu {
        return Cpu{
            .registers = Register.init(),
            .opcode = 0,
            .inst = &Instruction{ .IN = .NOP },
            .dest_is_mem = false,
            .mem_dest = 0,
            .fetched_data = 0,
            .cycle_debt = 0,
            .halted = false,
            .ime = false,
            .enable_ime = false,
        };
    }

    pub fn fetch(self: *Cpu, ctx: *SystemContext) void {
        self.opcode = ctx.bus.read(ctx, self.registers.pc);
        self.registers.pc +%= 1;
        self.inst = Inst.instByOpcode(self.opcode);
    }

    pub fn step(self: *Cpu, ctx: *SystemContext) u8 {
        self.cycle_debt = 0;

        if (!self.halted) {
            const pc: u16 = self.registers.pc;

            if (CPU_DEBUG) {
                util.debugInfo(self, ctx, pc);
                // util.newDebug(self, ctx, pc);
            }

            self.fetch(ctx);
            self.addCycles(1);
            cf.fetchData(self, ctx);

            self.execute(ctx);
        } else {
            self.addCycles(1);

            if (ctx.int.intf != 0) {
                self.halted = false;
            }
        }

        if (self.ime) {
            self.handleInterrupt(ctx);
            self.enable_ime = false;
        }

        if (self.enable_ime) {
            self.ime = true;
        }

        return self.cycle_debt;
    }

    pub fn execute(self: *Cpu, ctx: *SystemContext) void {
        if (cp.instruction_handler.get(self.inst.IN)) |handler| {
            handler(self, ctx);
        } else {
            return;
        }
    }

    pub fn addCycles(self: *Cpu, cycles: u8) void {
        self.cycle_debt += cycles;
    }

    pub fn handleInterrupt(self: *Cpu, ctx: *SystemContext) void {
        if (self.intCheck(0x40, .VBLANK, ctx)) {
            //TODO
        } else if (self.intCheck(0x48, .STAT, ctx)) {
            //TODO
        } else if (self.intCheck(0x50, .TIMER, ctx)) {
            //TODO
        } else if (self.intCheck(0x58, .SERIAL, ctx)) {
            //TODO
        } else if (self.intCheck(0x60, .JOYPAD, ctx)) {
            //TODO
        }
    }

    pub fn intCheck(self: *Cpu, address: u16, it: InterruptsType, ctx: *SystemContext) bool {
        const interrupt_bit = @intFromEnum(it);

        if ((ctx.int.intf & interrupt_bit) != 0 and (ctx.int.ie & interrupt_bit) != 0) {
            self.intHandle(ctx, address);
            ctx.int.intf &= ~interrupt_bit;
            self.halted = false;
            self.ime = false;

            return true;
        }
        return false;
    }

    pub fn intHandle(self: *Cpu, ctx: *SystemContext, address: u16) void {
        self.push16(ctx, self.registers.pc);
        self.registers.pc = address;
    }

    pub fn readRegister(self: *const Cpu, reg_type: RegisterType) u16 {
        return switch (reg_type) {
            .A => self.registers.a,
            .F => @as(u16, self.registers.f.toByte()),
            .B => self.registers.b,
            .C => self.registers.c,
            .D => self.registers.d,
            .E => self.registers.e,
            .H => self.registers.h,
            .L => self.registers.l,

            .AF => self.registers.getAF(),
            .BC => self.registers.getBC(),
            .DE => self.registers.getDE(),
            .HL => self.registers.getHL(),
            .PC => self.registers.pc,
            .SP => self.registers.sp,
            else => {
                std.log.info("Error, Invalid register...{}", .{reg_type});
                std.process.exit(1);
            },
        };
    }

    pub fn setRegister(self: *Cpu, reg_type: RegisterType, value: u16) void {
        switch (reg_type) {
            .NONE => return,

            .A => self.registers.a = @truncate(value & 0xFF),
            .B => self.registers.b = @truncate(value & 0xFF),
            .C => self.registers.c = @truncate(value & 0xFF),
            .D => self.registers.d = @truncate(value & 0xFF),
            .E => self.registers.e = @truncate(value & 0xFF),
            .F => self.registers.f = FlagRegister.fromByte(@truncate(value & 0xFF)),
            .H => self.registers.h = @truncate(value & 0xFF),
            .L => self.registers.l = @truncate(value & 0xFF),

            .AF => self.registers.setAF(value),
            .BC => self.registers.setBC(value),
            .DE => self.registers.setDE(value),
            .HL => self.registers.setHL(value),
            .PC => self.registers.setPC(value),
            .SP => self.registers.setSP(value),
        }
    }

    pub fn readRegister8(self: *Cpu, ctx: *SystemContext, reg_type: RestRegisterType) u8 {
        return switch (reg_type) {
            .A => return self.registers.a,
            .B => return self.registers.b,
            .C => return self.registers.c,
            .D => return self.registers.d,
            .E => return self.registers.e,
            .H => return self.registers.h,
            .L => return self.registers.l,
            .HL => {
                return ctx.bus.read(ctx, readRegister(self, .HL));
            },
            else => {
                std.log.info("Error, Invalid register...", .{});
                std.process.exit(1);
            },
        };
    }

    pub fn setRegister8(self: *Cpu, ctx: *SystemContext, reg_type: RestRegisterType, value: u8) void {
        switch (reg_type) {
            .A => self.registers.a = value,
            .B => self.registers.b = value,
            .C => self.registers.c = value,
            .D => self.registers.d = value,
            .E => self.registers.e = value,
            .H => self.registers.h = value,
            .L => self.registers.l = value,
            .HL => {
                ctx.bus.write(ctx, self.readRegister(.HL), value);
            },
            else => {
                std.log.info("Error, Invalid registers..", .{});
                std.process.exit(1);
            },
        }
    }

    pub fn push(self: *Cpu, ctx: *SystemContext, data: u8) void {
        self.registers.sp = self.registers.sp -% 1;
        ctx.bus.write(ctx, self.registers.sp, data);
    }

    pub fn pop(self: *Cpu, ctx: *SystemContext) u8 {
        const value = ctx.bus.read(ctx, self.registers.sp);
        self.registers.sp = self.registers.sp +% 1;
        return value;
    }

    pub fn pop16(self: *Cpu, ctx: *SystemContext) u16 {
        const lo = self.pop(ctx);
        const hi = self.pop(ctx);

        return @as(u16, hi) << 8 | @as(u16, lo);
    }

    pub fn push16(self: *Cpu, ctx: *SystemContext, data: u16) void {
        self.push(ctx, @truncate(data >> 8));
        self.push(ctx, @truncate(data));
    }
};
