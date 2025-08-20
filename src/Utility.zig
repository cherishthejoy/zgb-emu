const std = @import("std");
const Cpu = @import("Cpu.zig").Cpu;
const RegisterType = @import("Instruction.zig").RegisterType;
const AddressMode = @import("Instruction.zig").AddressMode;
const InstructionType = @import("Instruction.zig").InstructionType;

const SystemContext = @import("SystemContext.zig").SystemContext;

pub inline fn is16Bit(rtype: RegisterType) bool {
    return @intFromEnum(rtype) >= @intFromEnum(RegisterType.AF);
}

pub fn instByStr(cpu: *const Cpu, ctx: *SystemContext, buffer: []u8) []const u8 {
    const inst = cpu.inst;

    const result = switch (cpu.inst.ADRM) {
        .NONE => std.fmt.bufPrint(buffer, "{s}", .{@tagName(inst.IN)}),
        .AM_IMP => std.fmt.bufPrint(buffer, "{s}", .{@tagName(inst.IN)}),
        .AM_R => std.fmt.bufPrint(buffer, "{s} {s}", .{ @tagName(inst.IN), @tagName(inst.RT) }),
        .AM_R_R => std.fmt.bufPrint(buffer, "{s} {s} {s}", .{ @tagName(inst.IN), @tagName(inst.RT), @tagName(inst.RT2) }),
        .AM_R_N8, .AM_R_A8 => std.fmt.bufPrint(buffer, "{s} {s} ${X:0>2}", .{ @tagName(inst.IN), @tagName(inst.RT), cpu.fetched_data }),
        .AM_R_A16, .AM_R_N16 => std.fmt.bufPrint(buffer, "{s} {s} ${X:0>4}", .{ @tagName(inst.IN), @tagName(inst.RT), cpu.fetched_data }),
        .AM_MR => std.fmt.bufPrint(buffer, "{s} ({s})", .{ @tagName(inst.IN), @tagName(inst.RT) }),
        .AM_MR_R => std.fmt.bufPrint(buffer, "{s} ({s}) {s}", .{ @tagName(inst.IN), @tagName(inst.RT), @tagName(inst.RT2) }),
        .AM_MR_N8 => std.fmt.bufPrint(buffer, "{s} ({s}) ${X:0>2}", .{ @tagName(inst.IN), @tagName(inst.RT), cpu.fetched_data }),
        .AM_R_MR => std.fmt.bufPrint(buffer, "{s} {s} ({s})", .{ @tagName(inst.IN), @tagName(inst.RT), @tagName(inst.RT2) }),
        .AM_R_HLI => std.fmt.bufPrint(buffer, "{s} {s} (HL+)", .{ @tagName(inst.IN), @tagName(inst.RT) }),
        .AM_R_HLD => std.fmt.bufPrint(buffer, "{s} {s} (HL-)", .{ @tagName(inst.IN), @tagName(inst.RT) }),
        .AM_A8_R => std.fmt.bufPrint(buffer, "{s} (${X:0>2}) {s}", .{ @tagName(inst.IN), ctx.bus.read(ctx, cpu.registers.pc - 1), @tagName(inst.RT2) }),
        .AM_HLI_R => std.fmt.bufPrint(buffer, "{s} (HL+) {s}", .{ @tagName(inst.IN), @tagName(inst.RT2) }),
        .AM_HLD_R => std.fmt.bufPrint(buffer, "{s} (HL-) {s}", .{ @tagName(inst.IN), @tagName(inst.RT2) }),
        .AM_HL_SPR => std.fmt.bufPrint(buffer, "{s} {s} SP+{X:0>2}", .{ @tagName(inst.IN), @tagName(inst.RT), cpu.fetched_data }),
        .AM_N8 => std.fmt.bufPrint(buffer, "{s} ${X:0>2}", .{ @tagName(inst.IN), cpu.fetched_data }),
        .AM_N16 => std.fmt.bufPrint(buffer, "{s} ${X:0>4}", .{ @tagName(inst.IN), cpu.fetched_data }),
        .AM_A16_R => std.fmt.bufPrint(buffer, "{s} (${X:0>4}) {s}", .{ @tagName(inst.IN), cpu.mem_dest, @tagName(inst.RT2) }),
        else => std.fmt.bufPrint(buffer, "{s} ???", .{@tagName(inst.IN)}),
    };

    return result catch "FORMAT_ERROR";
}

pub fn debugInfo(cpu: *const Cpu, ctx: *SystemContext, pc: u16) void {
    var inst_buffer: [64]u8 = undefined;
    const inst_str = instByStr(cpu, ctx, &inst_buffer);

    std.debug.print(": {X:0>4} {s: <12} | [{X:0>2} {X:0>2} {X:0>2}] | A: {X:0>2} | BC: {X:0>3}{} | DE: {X:0>3}{} | HL: {X:0>3}{} | F: {c}{c}{c}{c} |\n", .{
        pc,
        inst_str,
        // ctx.curr_opcode,
        ctx.bus.read(ctx, pc),
        ctx.bus.read(ctx, pc + 1),
        ctx.bus.read(ctx, pc + 2),
        cpu.registers.a,
        cpu.registers.b,
        cpu.registers.c,
        cpu.registers.d,
        cpu.registers.e,
        cpu.registers.h,
        cpu.registers.l,
        if (cpu.registers.f.zero) @as(u8, 'Z') else @as(u8, '-'),
        if (cpu.registers.f.subtract) @as(u8, 'N') else @as(u8, '-'),
        if (cpu.registers.f.half_carry) @as(u8, 'H') else @as(u8, '-'),
        if (cpu.registers.f.carry) @as(u8, 'C') else @as(u8, '-'),
    });
}

pub fn newDebug(cpu: *const Cpu, ctx: *SystemContext, pc: u16) void {
    std.debug.print("A:{X:0>2} F:{X:0>2} B:{X:0>2} C:{X:0>2} D:{X:0>2} E:{X:0>2} H:{X:0>2} L:{X:0>2} SP:{X:0>4} PC:{X:0>4} PCMEM:{X:0>2},{X:0>2},{X:0>2},{X:0>2} {X:0>2} {X:0>2}\n", .{
        cpu.registers.a,
        cpu.registers.f.toByte(),
        cpu.registers.b,
        cpu.registers.c,
        cpu.registers.d,
        cpu.registers.e,
        cpu.registers.h,
        cpu.registers.l,
        cpu.registers.sp,
        pc,
        ctx.bus.read(ctx, pc),
        ctx.bus.read(ctx, pc + 1),
        ctx.bus.read(ctx, pc + 2),
        ctx.bus.read(ctx, pc + 3),
        ctx.int.ie,
        ctx.int.intf,
    });
}
