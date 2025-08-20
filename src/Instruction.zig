pub const RegisterType = enum { NONE, A, B, C, D, E, F, H, L, AF, BC, DE, HL, PC, SP };
pub const RestRegisterType = enum { B, C, D, E, H, L, HL, A, NONE };
pub const InstructionType = enum {
    NO_IMPL,
    NOP,
    HALT,
    STOP,
    ADD,
    ADC,
    SUB,
    SBC,
    CP,
    CB,
    RRCA,
    RLCA,
    RRA,
    RLA,
    AND,
    OR,
    XOR,
    INC,
    DEC,
    LD,
    LDH,
    DI,
    EI,
    JP,
    JR,
    CALL,
    RST,
    RET,
    RETI,
    DAA,
    CPL,
    SCF,
    CCF,
    PUSH,
    POP,
};

pub const AddressMode = enum {
    NONE,
    AM_IMP,
    AM_R,
    AM_R_R,
    AM_N8,
    AM_R_N8,
    AM_A8_R,
    AM_R_A8,
    AM_N16,
    AM_N16_R,
    AM_R_N16,
    AM_R_MR,
    AM_R_A16,
    AM_A16_R,
    AM_R_HLI,
    AM_R_HLD,
    AM_MR,
    AM_MR_R,
    AM_MR_N8,
    AM_HLI_R,
    AM_HLD_R,
    AM_HL_SPR,
    NO_IMPL,
};

pub const ConditionType = enum {
    CT_NONE,
    CT_NZ,
    CT_Z,
    CT_NC,
    CT_C,
};

pub const Instruction = struct {
    IN: InstructionType,
    ADRM: AddressMode = .NONE,
    RT: RegisterType = .NONE,
    RT2: RegisterType = .NONE,
    CT: ConditionType = .CT_NONE,
    PARAM: u8 = 0,
};

pub const instruction_table = [_]Instruction{};

pub const inst_table = blk: {
    var table: [256]Instruction = undefined;

    for (&table) |*inst| {
        inst.* = Instruction{ .IN = .NO_IMPL, .ADRM = .NO_IMPL };
    }

    // 0x00 - 0x0F
    table[0x00] = Instruction{ .IN = .NOP, .ADRM = .AM_IMP };
    table[0x01] = Instruction{ .IN = .LD, .ADRM = .AM_R_N16, .RT = .BC };
    table[0x02] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .BC, .RT2 = .A };
    table[0x03] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .BC };
    table[0x04] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .B };
    table[0x05] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .B };
    table[0x06] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .B };
    table[0x07] = Instruction{ .IN = .RLCA };
    table[0x08] = Instruction{ .IN = .LD, .ADRM = .AM_A16_R, .RT2 = .SP };
    table[0x09] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .HL, .RT2 = .BC };
    table[0x0A] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .BC };
    table[0x0B] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .BC };
    table[0x0C] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .C };
    table[0x0D] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .C };
    table[0x0E] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .C };
    table[0x0F] = Instruction{ .IN = .RRCA };

    // 0x10 - 0x1F
    table[0x10] = Instruction{ .IN = .STOP };
    table[0x11] = Instruction{ .IN = .LD, .ADRM = .AM_R_N16, .RT = .DE };
    table[0x12] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .DE, .RT2 = .A };
    table[0x13] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .DE };
    table[0x14] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .D };
    table[0x15] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .D };
    table[0x16] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .D };
    table[0x17] = Instruction{ .IN = .RLA };
    table[0x18] = Instruction{ .IN = .JR, .ADRM = .AM_N8 };
    table[0x19] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .HL, .RT2 = .DE };
    table[0x1A] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .DE };
    table[0x1B] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .DE };
    table[0x1C] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .E };
    table[0x1D] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .E };
    table[0x1E] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .E };
    table[0x1F] = Instruction{ .IN = .RRA };

    // 0x20 - 0x2F
    table[0x20] = Instruction{ .IN = .JR, .ADRM = .AM_N8, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NZ };
    table[0x21] = Instruction{ .IN = .LD, .ADRM = .AM_R_N16, .RT = .HL };
    table[0x22] = Instruction{ .IN = .LD, .ADRM = .AM_HLI_R, .RT = .HL, .RT2 = .A };
    table[0x23] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .HL };
    table[0x24] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .H };
    table[0x25] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .H };
    table[0x26] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .H };
    table[0x27] = Instruction{ .IN = .DAA };
    table[0x28] = Instruction{ .IN = .JR, .ADRM = .AM_N8, .RT = .NONE, .RT2 = .NONE, .CT = .CT_Z };
    table[0x29] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .HL, .RT2 = .HL };
    table[0x2A] = Instruction{ .IN = .LD, .ADRM = .AM_R_HLI, .RT = .A, .RT2 = .HL };
    table[0x2B] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .HL };
    table[0x2C] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .L };
    table[0x2D] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .L };
    table[0x2E] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .L };
    table[0x2F] = Instruction{ .IN = .CPL };

    // 0x30 - 0x3F
    table[0x30] = Instruction{ .IN = .JR, .ADRM = .AM_N8, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NC };
    table[0x31] = Instruction{ .IN = .LD, .ADRM = .AM_R_N16, .RT = .SP };
    table[0x32] = Instruction{ .IN = .LD, .ADRM = .AM_HLD_R, .RT = .HL, .RT2 = .A };
    table[0x33] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .SP };
    table[0x34] = Instruction{ .IN = .INC, .ADRM = .AM_MR, .RT = .HL };
    table[0x35] = Instruction{ .IN = .DEC, .ADRM = .AM_MR, .RT = .HL };
    table[0x36] = Instruction{ .IN = .LD, .ADRM = .AM_MR_N8, .RT = .HL };
    table[0x37] = Instruction{ .IN = .SCF };
    table[0x38] = Instruction{ .IN = .JR, .ADRM = .AM_N8, .RT = .NONE, .RT2 = .NONE, .CT = .CT_C };
    table[0x39] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .HL, .RT2 = .SP };
    table[0x3A] = Instruction{ .IN = .LD, .ADRM = .AM_R_HLD, .RT = .A, .RT2 = .HL };
    table[0x3B] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .SP };
    table[0x3C] = Instruction{ .IN = .INC, .ADRM = .AM_R, .RT = .A };
    table[0x3D] = Instruction{ .IN = .DEC, .ADRM = .AM_R, .RT = .A };
    table[0x3E] = Instruction{ .IN = .LD, .ADRM = .AM_R_N8, .RT = .A };
    table[0x3F] = Instruction{ .IN = .CCF };

    // 0x40 - 0x4F
    table[0x40] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .B };
    table[0x41] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .C };
    table[0x42] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .D };
    table[0x43] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .E };
    table[0x44] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .H };
    table[0x45] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .L };
    table[0x46] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .B, .RT2 = .HL };
    table[0x47] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .B, .RT2 = .A };
    table[0x48] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .B };
    table[0x49] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .C };
    table[0x4A] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .D };
    table[0x4B] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .E };
    table[0x4C] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .H };
    table[0x4D] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .L };
    table[0x4E] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .C, .RT2 = .HL };
    table[0x4F] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .C, .RT2 = .A };

    // 0x50 - 0x5F
    table[0x50] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .B };
    table[0x51] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .C };
    table[0x52] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .D };
    table[0x53] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .E };
    table[0x54] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .H };
    table[0x55] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .L };
    table[0x56] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .D, .RT2 = .HL };
    table[0x57] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .D, .RT2 = .A };
    table[0x58] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .B };
    table[0x59] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .C };
    table[0x5A] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .D };
    table[0x5B] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .E };
    table[0x5C] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .H };
    table[0x5D] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .L };
    table[0x5E] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .E, .RT2 = .HL };
    table[0x5F] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .E, .RT2 = .A };

    // 0x60 - 0x6F
    table[0x60] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .B };
    table[0x61] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .C };
    table[0x62] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .D };
    table[0x63] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .E };
    table[0x64] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .H };
    table[0x65] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .L };
    table[0x66] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .H, .RT2 = .HL };
    table[0x67] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .H, .RT2 = .A };
    table[0x68] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .B };
    table[0x69] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .C };
    table[0x6A] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .D };
    table[0x6B] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .E };
    table[0x6C] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .H };
    table[0x6D] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .L };
    table[0x6E] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .L, .RT2 = .HL };
    table[0x6F] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .L, .RT2 = .A };

    // 0x70 - 0x7F
    table[0x70] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .B };
    table[0x71] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .C };
    table[0x72] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .D };
    table[0x73] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .E };
    table[0x74] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .H };
    table[0x75] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .L };
    table[0x76] = Instruction{ .IN = .HALT };
    table[0x77] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .HL, .RT2 = .A };
    table[0x78] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0x79] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0x7A] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0x7B] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0x7C] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0x7D] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0x7E] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0x7F] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };

    // 0x80 - 0x8F
    table[0x80] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0x81] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0x82] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0x83] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0x84] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0x85] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0x86] = Instruction{ .IN = .ADD, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0x87] = Instruction{ .IN = .ADD, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };
    table[0x88] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0x89] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0x8A] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0x8B] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0x8C] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0x8D] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0x8E] = Instruction{ .IN = .ADC, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0x8F] = Instruction{ .IN = .ADC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };

    // 0x90 - 0x9F
    table[0x90] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0x91] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0x92] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0x93] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0x94] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0x95] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0x96] = Instruction{ .IN = .SUB, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0x97] = Instruction{ .IN = .SUB, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };
    table[0x98] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0x99] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0x9A] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0x9B] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0x9C] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0x9D] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0x9E] = Instruction{ .IN = .SBC, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0x9F] = Instruction{ .IN = .SBC, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };

    // 0xA0 - 0xAF
    table[0xA0] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0xA1] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0xA2] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0xA3] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0xA4] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0xA5] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0xA6] = Instruction{ .IN = .AND, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0xA7] = Instruction{ .IN = .AND, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };
    table[0xA8] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0xA9] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0xAA] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0xAB] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0xAC] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0xAD] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0xAE] = Instruction{ .IN = .XOR, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0xAF] = Instruction{ .IN = .XOR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };

    // 0xB0 - 0xBF
    table[0xB0] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0xB1] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0xB2] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0xB3] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0xB4] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0xB5] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0xB6] = Instruction{ .IN = .OR, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0xB7] = Instruction{ .IN = .OR, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };
    table[0xB8] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .B };
    table[0xB9] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .C };
    table[0xBA] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .D };
    table[0xBB] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .E };
    table[0xBC] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .H };
    table[0xBD] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .L };
    table[0xBE] = Instruction{ .IN = .CP, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .HL };
    table[0xBF] = Instruction{ .IN = .CP, .ADRM = .AM_R_R, .RT = .A, .RT2 = .A };

    // 0xC0 - 0xCF
    table[0xC0] = Instruction{ .IN = .RET, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NZ };
    table[0xC1] = Instruction{ .IN = .POP, .ADRM = .AM_R, .RT = .BC };
    table[0xC2] = Instruction{ .IN = .JP, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NZ };
    table[0xC3] = Instruction{ .IN = .JP, .ADRM = .AM_N16 };
    table[0xC4] = Instruction{ .IN = .CALL, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NZ };
    table[0xC5] = Instruction{ .IN = .PUSH, .ADRM = .AM_R, .RT = .BC };
    table[0xC6] = Instruction{ .IN = .ADD, .ADRM = .AM_R_N8, .RT = .A };
    table[0xC7] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x00 };
    table[0xC8] = Instruction{ .IN = .RET, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_Z };
    table[0xC9] = Instruction{ .IN = .RET };
    table[0xCA] = Instruction{ .IN = .JP, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_Z };
    table[0xCB] = Instruction{ .IN = .CB, .ADRM = .AM_N8 };
    table[0xCC] = Instruction{ .IN = .CALL, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_Z };
    table[0xCD] = Instruction{ .IN = .CALL, .ADRM = .AM_N16 };
    table[0xCE] = Instruction{ .IN = .ADC, .ADRM = .AM_R_N8, .RT = .A };
    table[0xCF] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x08 };

    // 0xD0 - 0xDF
    table[0xD0] = Instruction{ .IN = .RET, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NC };
    table[0xD1] = Instruction{ .IN = .POP, .ADRM = .AM_R, .RT = .DE };
    table[0xD2] = Instruction{ .IN = .JP, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NC };
    // Empty Instruction
    table[0xD4] = Instruction{ .IN = .CALL, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NC };
    table[0xD5] = Instruction{ .IN = .PUSH, .ADRM = .AM_R, .RT = .DE };
    table[0xD6] = Instruction{ .IN = .SUB, .ADRM = .AM_R_N8, .RT = .A };
    table[0xD7] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x10 };
    table[0xD8] = Instruction{ .IN = .RET, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_C };
    table[0xD9] = Instruction{ .IN = .RETI };
    table[0xDA] = Instruction{ .IN = .JP, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_C };
    // Empty Instruction
    table[0xDC] = Instruction{ .IN = .CALL, .ADRM = .AM_N16, .RT = .NONE, .RT2 = .NONE, .CT = .CT_C };
    // Empty Instruction
    table[0xDE] = Instruction{ .IN = .SBC, .ADRM = .AM_R_N8, .RT = .A };
    table[0xDF] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x18 };

    // 0xE0 - 0xEF
    table[0xE0] = Instruction{ .IN = .LDH, .ADRM = .AM_A8_R, .RT = .NONE, .RT2 = .A };
    table[0xE1] = Instruction{ .IN = .POP, .ADRM = .AM_R, .RT = .HL };
    table[0xE2] = Instruction{ .IN = .LD, .ADRM = .AM_MR_R, .RT = .C, .RT2 = .A };
    // Empty Instruction
    // Empty Instruction
    table[0xE5] = Instruction{ .IN = .PUSH, .ADRM = .AM_R, .RT = .HL };
    table[0xE6] = Instruction{ .IN = .AND, .ADRM = .AM_R_N8, .RT = .A };
    table[0xE7] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x20 };
    table[0xE8] = Instruction{ .IN = .ADD, .ADRM = .AM_R_N8, .RT = .SP };
    table[0xE9] = Instruction{ .IN = .JP, .ADRM = .AM_R, .RT = .HL };
    table[0xEA] = Instruction{ .IN = .LD, .ADRM = .AM_A16_R, .RT = .NONE, .RT2 = .A };
    // Empty Instruction
    // Empty Instruction
    // Empty Instruction
    table[0xEE] = Instruction{ .IN = .XOR, .ADRM = .AM_R_N8, .RT = .A };
    table[0xEF] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x28 };

    // 0xF0 - 0xFF
    table[0xF0] = Instruction{ .IN = .LDH, .ADRM = .AM_R_A8, .RT = .A };
    table[0xF1] = Instruction{ .IN = .POP, .ADRM = .AM_R, .RT = .AF };
    table[0xF2] = Instruction{ .IN = .LD, .ADRM = .AM_R_MR, .RT = .A, .RT2 = .C };
    table[0xF3] = Instruction{ .IN = .DI };
    // Empty Instruction
    table[0xF5] = Instruction{ .IN = .PUSH, .ADRM = .AM_R, .RT = .AF };
    table[0xF6] = Instruction{ .IN = .OR, .ADRM = .AM_R_N8, .RT = .A };
    table[0xF7] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x30 };
    table[0xF8] = Instruction{ .IN = .LD, .ADRM = .AM_HL_SPR, .RT = .HL, .RT2 = .SP };
    table[0xF9] = Instruction{ .IN = .LD, .ADRM = .AM_R_R, .RT = .SP, .RT2 = .HL };
    table[0xFA] = Instruction{ .IN = .LD, .ADRM = .AM_R_A16, .RT = .A };
    table[0xFB] = Instruction{ .IN = .EI };
    // Empty Instruction
    // Empty Instruction
    table[0xFE] = Instruction{ .IN = .CP, .ADRM = .AM_R_N8, .RT = .A };
    table[0xFF] = Instruction{ .IN = .RST, .ADRM = .AM_IMP, .RT = .NONE, .RT2 = .NONE, .CT = .CT_NONE, .PARAM = 0x38 };

    break :blk table;
};

pub inline fn instByOpcode(opcode: u8) *const Instruction {
    return &inst_table[opcode];
}
