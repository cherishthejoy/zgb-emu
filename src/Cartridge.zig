const std = @import("std");

const RamBankCount = 16;
const RamBankSize = 0x2000;

fn inRange(val: anytype, lo: @TypeOf(val), hi: @TypeOf(val)) bool {
    return val >= lo and val <= hi;
}

const CartridgeHeader = struct {
    entry: u8,
    logo: u8,
    title: [16]u8,
    new_lic_code: u16,
    lic_code: u8,
    sgb: u8,
    rtype: u8,
    rom_size: u8,
    ram_size: u8,
    dest_code: u8,
    checksum: u8,
    global_checksum: u8,

    pub fn init(rom_data: []u8) CartridgeError!CartridgeHeader {
        if (rom_data.len < 0x150) {
            return CartridgeError.InvalidRomSize;
        }

        return .{
            .entry = 0,
            .logo = 0,
            .title = rom_data[0x134..0x144].*,
            .new_lic_code = rom_data[0x144],
            .lic_code = 0,
            .sgb = 0,
            .rtype = rom_data[0x0147],
            .rom_size = rom_data[0x0148],
            .ram_size = rom_data[0x0149],
            .dest_code = rom_data[0x014A],
            .checksum = 0,
            .global_checksum = 0,
        };
    }
};

pub const CartridgeError = error{
    InvalidRomSize,
    InvalidHeader,
    UnsupportedCartridgeType,
    OutOfMemory,
    FileError,
    TestFail,
};

pub const Cartridge = struct {
    allocator: std.mem.Allocator,
    header: CartridgeHeader,
    file_name: []const u8,
    rom_size: u32,
    rom_data: []u8,

    // NOTE: MBC1
    ram_enabled: bool,
    ram_banking: bool,

    rom_bank_x: []u8,
    banking_mode: u8,

    rom_bank_value: u8,
    ram_bank_value: u8,

    ram_bank: ?[]u8,
    ram_banks: [RamBankCount]?[]u8,

    battery: bool,
    need_save: bool,

    pub fn init(allocator: std.mem.Allocator, rom_data: []u8) CartridgeError!Cartridge {
        const header = try CartridgeHeader.init(rom_data);
        return Cartridge{
            .allocator = allocator,
            .header = header,
            .file_name = "",
            .rom_size = 0,
            .rom_data = rom_data,

            .ram_enabled = false,
            .ram_banking = false,

            .rom_bank_x = &[_]u8{},
            .banking_mode = 0,

            .rom_bank_value = 0,
            .ram_bank_value = 0,

            .ram_bank = null,
            .ram_banks = [_]?[]u8{null} ** RamBankCount,

            .battery = false,
            .need_save = false,
        };
    }

    pub fn cartNeedSave(self: *Cartridge) bool {
        return self.need_save;
    }

    pub fn cartMbc1(self: *Cartridge) bool {
        return inRange(self.header.rtype, 1, 3);
    }

    pub fn cartBattery(self: *Cartridge) bool {
        // NOTE: Mbc1 only for now
        return self.header.rtype == 0x03;
    }

    pub fn cartSetupBanking(self: *Cartridge) !void {
        for (&self.ram_banks) |*bank| {
            bank.* = null;
        }

        for (0..RamBankCount) |i| {
            if (self.header.ram_size == 2 and i == 0 or
                self.header.ram_size == 3 and i < 4 or
                self.header.ram_size == 4 and i < 16 or
                self.header.ram_size == 5 and i < 8)
            {
                const mem = try self.allocator.alloc(u8, RamBankSize);
                @memset(mem, 0);
                self.ram_banks[i] = mem;
            }
        }

        self.ram_bank = self.ram_banks[0];
        self.rom_bank_x = self.rom_data[0x4000..];
    }

    pub fn cartBatteryLoad(self: *Cartridge) !void {
        if (self.ram_bank == null) return;

        // build "<filename>.battery"
        var buf: [1024]u8 = undefined;
        const file_name = try std.fmt.bufPrint(&buf, "{s}.battery", .{self.file_name});

        var file = try std.fs.cwd().openFile(file_name, .{});

        defer file.close();

        const ram = self.ram_bank.?;
        _ = try file.readAll(ram[0..0x2000]);
    }

    pub fn cartBatterySave(self: *Cartridge) void {
        if (self.ram_bank == null) return;

        // build "<filename>.battery"
        var buf: [1024]u8 = undefined;
        const file_name = std.fmt.bufPrint(&buf, "{s}.battery", .{self.file_name}) catch |err| {
            std.log.err("Failed to save to savefile: {}", .{err});
            return;
        };

        var file = std.fs.cwd().createFile(file_name, .{
            .truncate = true,
        }) catch |err| {
            std.log.err("Failed to save to savefile: {}", .{err});
            return;
        };

        defer file.close();

        const ram = self.ram_bank.?;
        file.writeAll(ram[0..0x2000]) catch |err| {
            std.log.err("Failed to write to savefile: {}", .{err});
        };
    }

    pub fn load(allocator: std.mem.Allocator, name: [:0]const u8) CartridgeError!Cartridge {
        const file = std.fs.cwd().openFile(name, .{ .mode = .read_only }) catch {
            return CartridgeError.FileError;
        };

        defer file.close();

        const stat = file.stat() catch |err| {
            std.log.err("Failed to extract metadata: {}", .{err});
            return CartridgeError.TestFail;
        };

        const file_size: u32 = @intCast(stat.size);

        const buffer = allocator.alloc(u8, file_size) catch |err| {
            std.log.err("Failed to create buffer: {}", .{err});
            return CartridgeError.TestFail;
        };

        errdefer allocator.free(buffer);

        const data = std.fs.cwd().readFile(name, buffer) catch |err| {
            std.log.err("Failed to read the ROM file {}...", .{err});
            return CartridgeError.TestFail;
        };

        var cart = try Cartridge.init(allocator, data);

        // NOTE: Extract just the filename without path and extension
        const basename = std.fs.path.basename(name);
        const filename_no_ext = if (std.mem.lastIndexOf(u8, basename, ".")) |dot_index|
            basename[0..dot_index]
        else
            basename;

        cart.file_name = filename_no_ext;
        cart.rom_size = file_size;

        // std.log.info("File size: {}", .{file_size});
        cart.header.title[15] = 0;
        cart.battery = cartBattery(&cart);
        cart.need_save = false;
        return cart;
    }

    pub fn deinit(self: *Cartridge) void {
        for (&self.ram_banks) |*bank_opt| {
            if (bank_opt.*) |bank| {
                self.allocator.free(bank);
                bank_opt.* = null;
            }
        }

        self.ram_bank = null;
        self.rom_bank_x = &[_]u8{};
        self.allocator.free(self.rom_data);
    }

    pub fn debug(self: *Cartridge) !void {
        std.log.info("Cartridge Loaded:", .{});

        std.debug.print("{s}\n", .{"---------------------------------------------"});

        std.debug.print("\tCBG flag: {X}\n", .{self.rom_data[0x0143]});
        std.debug.print("\tCartridge type: {s}\n", .{cartTypeName(self.rom_data[0x0147])});
        std.debug.print("\tROM size: {X}\n", .{self.rom_data[0x0148]});
        std.debug.print("\tRAM size: {X}\n", .{self.rom_data[0x0149]});
        std.debug.print("\tLIC code: {s}\n", .{self.licenseName(0x144)});
        std.debug.print("\tDestination code: {X}\n", .{self.rom_data[0x014A]});
        std.debug.print("\tVersion: {X}\n", .{self.rom_data[0x014C]});
        std.debug.print("\tTitle: {s}\n", .{self.header.title});

        self.cartSetupBanking() catch |err| {
            std.log.err("Encountered an issue setting up banking: {}", .{err});
        };

        var x: u8 = 0;
        for (0x0134..0x014C) |i| {
            x = x -% self.rom_data[i] - 1;
        }

        std.debug.print("\n\tChecksum: {s}\n", .{if ((x & 0xFF) != 0) "Passed" else "Failed"});

        if (self.battery) {
            try self.cartBatteryLoad();
        }

        std.debug.print("{s}\n", .{"---------------------------------------------"});
    }

    pub fn read(self: *Cartridge, address: u16) u8 {
        if (!self.cartMbc1() or address < 0x4000) {
            return self.rom_data[address];
        }

        if ((address & 0xE000) == 0xA000) {
            if (!self.ram_enabled) {
                return 0xFF;
            }

            if (self.ram_bank == null) {
                return 0xFF;
            }

            return self.ram_bank.?[address - 0xA000];
        }

        return self.rom_bank_x[address - 0x4000];
    }

    pub fn write(self: *Cartridge, address: u16, value: u8) void {
        var val = value;
        if (!self.cartMbc1()) {
            return;
        }

        if (address < 0x2000) {
            self.ram_enabled = ((val & 0xF) == 0xA);
        }

        if ((address & 0xE000) == 0x2000) {
            // NOTE: ROM bank

            if (val == 0) {
                val = 1;
            }

            val &= 0b11111;

            self.rom_bank_value = val;

            const offset = @as(u32, self.rom_bank_value) * 0x4000;
            if (offset < self.rom_data.len) {
                self.rom_bank_x = self.rom_data[offset..];
            }
        }

        if ((address & 0xE000) == 0x4000) {
            // NOTE: RAM bank number

            self.ram_bank_value = val & 0b11;

            if (self.ram_banking) {
                if (self.cartNeedSave()) {
                    self.cartBatterySave();
                }
                self.ram_bank = self.ram_banks[self.ram_bank_value];
            }
        }

        if ((address & 0xE000) == 0x6000) {
            // NOTE: Banking mode select

            self.banking_mode = val & 1;
            self.ram_banking = self.banking_mode != 0;

            if (self.ram_banking) {
                if (self.cartNeedSave()) {
                    self.cartBatterySave();
                }
                self.ram_bank = self.ram_banks[self.ram_bank_value];
            }
        }

        if ((address & 0xE000) == 0xA000) {
            if (!self.ram_enabled) {
                return;
            }

            if (self.ram_bank == null) {
                return;
            }

            self.ram_bank.?[address - 0xA000] = value;

            if (self.battery) {
                self.need_save = true;
            }
        }
    }

    pub fn licenseName(self: *const Cartridge, code: u16) [:0]const u8 {
        if (self.header.new_lic_code <= 0xA4) {
            return switch (self.rom_data[code]) {
                0x00 => "None",
                0x01 => "Nintendo R&D1",
                0x08 => "Capcom",
                0x13 => "Electronic Arts",
                0x18 => "Hudson Soft",
                0x19 => "b-ai",
                0x20 => "kss",
                0x22 => "pow",
                0x24 => "PCM Complete",
                0x25 => "san-x",
                0x28 => "Kemco Japan",
                0x29 => "seta",
                0x30 => "Viacom",
                0x31 => "Nintendo",
                0x32 => "Bandai",
                0x33 => "Ocean/Acclaim",
                0x34 => "Konami",
                0x35 => "Hector",
                0x37 => "Taito",
                0x38 => "Hudson",
                0x39 => "Banpresto",
                0x41 => "Ubi Soft",
                0x42 => "Atlus",
                0x46 => "angel",
                0x44 => "Malibu",
                0x47 => "Bullet-Proof",
                0x49 => "irem",
                0x50 => "Absolute",
                0x51 => "Acclaim",
                0x52 => "Activision",
                0x53 => "American sammy",
                0x54 => "Konami",
                0x55 => "Hi tech entertainment",
                0x56 => "LJN",
                0x57 => "Matchbox",
                0x58 => "Mattel",
                0x59 => "Milton Bradley",
                0x60 => "Titus",
                0x61 => "Virgin",
                0x64 => "LucasArts",
                0x67 => "Ocean",
                0x69 => "Electronic Arts",
                0x70 => "Infogrames",
                0x71 => "Interplay",
                0x72 => "Broderbund",
                0x73 => "sculptured",
                0x75 => "sci",
                0x78 => "THQ",
                0x79 => "Accolade",
                0x80 => "misawa",
                0x83 => "lozc",
                0x86 => "Tokuma Shoten Intermedia",
                0x87 => "Tsukuda Original",
                0x91 => "Chunsoft",
                0x92 => "Video system",
                0x93 => "Ocean/Acclaim",
                0x95 => "Varie",
                0x96 => "Yonezawa/s’pal",
                0x97 => "Kaneko",
                0x99 => "Pack in soft",
                0xA4 => "Konami (Yu-Gi-Oh!)",
                else => "UNKNOWN",
            };
        }
        return "UNKNOWN";
    }

    pub fn cartTypeName(value: u8) []const u8 {
        if (value <= ROM_TYPES.len) {
            return ROM_TYPES[value];
        }
        return "UNKNOWN";
    }

    const ROM_TYPES = [_][]const u8{
        "ROM ONLY",
        "MBC1",
        "MBC1+RAM",
        "MBC1+RAM+BATTERY",
        "0x04 ???",
        "MBC2",
        "MBC2+BATTERY",
        "0x07 ???",
        "ROM+RAM 1",
        "ROM+RAM+BATTERY 1",
        "0x0A ???",
        "MMM01",
        "MMM01+RAM",
        "MMM01+RAM+BATTERY",
        "0x0E ???",
        "MBC3+TIMER+BATTERY",
        "MBC3+TIMER+RAM+BATTERY 2",
        "MBC3",
        "MBC3+RAM 2",
        "MBC3+RAM+BATTERY 2",
        "0x14 ???",
        "0x15 ???",
        "0x16 ???",
        "0x17 ???",
        "0x18 ???",
        "MBC5",
        "MBC5+RAM",
        "MBC5+RAM+BATTERY",
        "MBC5+RUMBLE",
        "MBC5+RUMBLE+RAM",
        "MBC5+RUMBLE+RAM+BATTERY",
        "0x1F ???",
        "MBC6",
        "0x21 ???",
        "MBC7+SENSOR+RUMBLE+RAM+BATTERY",
    };
};
