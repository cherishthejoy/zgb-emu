const std = @import("std");
const Cpu = @import("Cpu.zig").Cpu;
const RegisterType = @import("Instruction.zig").RegisterType;

const SystemContext = @import("SystemContext.zig").SystemContext;

pub fn fetchData(self: *Cpu, ctx: *SystemContext) void {
    self.mem_dest = 0;
    self.dest_is_mem = false;

    if (self.inst.IN == .NO_IMPL) return;

    switch (self.inst.ADRM) {
        .AM_IMP => return,
        .AM_R => {
            self.fetched_data = self.readRegister(self.inst.RT);
            return;
        },
        .AM_R_R => {
            self.fetched_data = self.readRegister(self.inst.RT2);
            return;
        },

        .AM_R_N8 => {
            self.fetched_data = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);
            self.registers.pc +%= 1;
            return;
        },

        .AM_R_N16, .AM_N16 => {
            const lo: u16 = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);

            const hi: u16 = ctx.bus.read(ctx, self.registers.pc + 1);
            self.addCycles(1);

            self.fetched_data = lo | (hi << 8);
            self.registers.pc += 2;
            return;
        },

        .AM_MR_R => {
            self.fetched_data = self.readRegister(self.inst.RT2);
            self.mem_dest = self.readRegister(self.inst.RT);
            self.dest_is_mem = true;

            if (self.inst.RT == RegisterType.C) {
                self.mem_dest |= 0xFF00;
            }

            return;
        },

        .AM_R_MR => {
            var addr: u16 = self.readRegister(self.inst.RT2);

            if (self.inst.RT2 == RegisterType.C) {
                addr |= 0xFF00;
            }
            self.fetched_data = ctx.bus.read(ctx, addr);
            self.addCycles(1);

            return;
        },

        .AM_R_HLI => {
            self.fetched_data = ctx.bus.read(ctx, self.readRegister(self.inst.RT2));
            self.addCycles(1);
            self.setRegister(.HL, self.readRegister(.HL) +% 1);
            return;
        },

        .AM_R_HLD => {
            self.fetched_data = ctx.bus.read(ctx, self.readRegister(self.inst.RT2));
            self.addCycles(1);
            self.setRegister(.HL, self.readRegister(.HL) -% 1);
            return;
        },

        .AM_HLI_R => {
            self.fetched_data = self.readRegister(self.inst.RT2);
            self.mem_dest = self.readRegister(self.inst.RT);
            self.dest_is_mem = true;
            self.setRegister(.HL, self.readRegister(.HL) +% 1);
            return;
        },

        .AM_HLD_R => {
            self.fetched_data = self.readRegister(self.inst.RT2);
            self.mem_dest = self.readRegister(self.inst.RT);
            self.dest_is_mem = true;
            self.setRegister(.HL, self.readRegister(.HL) -% 1);
            return;
        },

        .AM_R_A8 => {
            self.fetched_data = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);
            self.registers.pc += 1;
            return;
        },

        .AM_A8_R => {
            self.mem_dest = @as(u16, ctx.bus.read(ctx, self.registers.pc)) | 0xFF00;
            self.dest_is_mem = true;
            self.addCycles(1);
            self.registers.pc += 1;
            return;
        },

        .AM_HL_SPR => {
            self.fetched_data = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);
            self.registers.pc += 1;
            return;
        },

        .AM_N8 => {
            self.fetched_data = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);
            self.registers.pc += 1;
            return;
        },

        .AM_A16_R, .AM_N16_R => {
            const lo: u16 = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);

            const hi: u16 = ctx.bus.read(ctx, self.registers.pc + 1);
            self.addCycles(1);

            self.mem_dest = lo | (hi << 8);
            self.dest_is_mem = true;

            self.registers.pc += 2;
            self.fetched_data = self.readRegister(self.inst.RT2);

            return;
        },

        .AM_MR_N8 => {
            self.fetched_data = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);
            self.registers.pc += 1;
            self.mem_dest = self.readRegister(self.inst.RT);
            self.dest_is_mem = true;
            return;
        },

        .AM_MR => {
            self.mem_dest = self.readRegister(self.inst.RT);
            self.dest_is_mem = true;
            self.fetched_data = ctx.bus.read(ctx, self.readRegister(self.inst.RT));
            self.addCycles(1);
            return;
        },

        .AM_R_A16 => {
            const lo: u16 = ctx.bus.read(ctx, self.registers.pc);
            self.addCycles(1);

            const hi: u16 = ctx.bus.read(ctx, self.registers.pc + 1);
            self.addCycles(1);

            const addr: u16 = lo | (hi << 8);
            self.registers.pc += 2;
            self.fetched_data = ctx.bus.read(ctx, addr);
            self.addCycles(1);
            return;
        },
        .NONE => {},
        else => {
            std.log.info("Unknown Addressing mode! {s} : {X}", .{ @tagName(self.inst.ADRM), self.opcode });
            std.process.exit(1);
            return;
        },
    }
}
