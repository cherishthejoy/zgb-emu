const std = @import("std");
const rl = @import("raylib");

const Ppu = @import("Ppu.zig").Ppu;
const Pipe = @import("PpuPipeline.zig");

const SystemContext = @import("SystemContext.zig").SystemContext;
const OamEntry = @import("Ppu.zig").OamEntry;
const OamLineEntry = @import("Ppu.zig").OamLineEntry;

const LINES_PER_FRAME = 154;
const TICKS_PER_LINE = 456;
const YRES = 144;
const XRES = 160;

const target_frame_time: u32 = 1000 / 60;
var prev_frame_time: u32 = 0;
var start_timer: u32 = 0;
var frame_count: u32 = 0;

fn incrementLy(ppu: *Ppu, ctx: *SystemContext) void {
    if (Pipe.windowVisible(ppu) and ppu.lcd.regs.ly >= ppu.lcd.regs.win_y) {
        ppu.window_line += 1;
    }
    ppu.lcd.regs.ly += 1;

    if (ppu.lcd.regs.ly == ppu.lcd.regs.ly_cmp) {
        ppu.lcd.regs.lcdsLycSet(true);

        if (ppu.lcd.regs.lcdsView().lyc_int) {
            ctx.int.requestInterrupt(.STAT);
        }
    } else {
        ppu.lcd.regs.lcdsLycSet(false);
    }
}

fn loadLineSprites(ppu: *Ppu) void {
    // const cur_y: i32 = @intCast(ppu.lcd.regs.ly);
    const cur_y = ppu.lcd.regs.ly;
    const sprite_height: u8 = ppu.lcd.regs.lcdcObjHeight();
    @memset(&ppu.line_entry_array, std.mem.zeroes(OamLineEntry));

    for (0..40) |i| {
        const e: OamEntry = ppu.oam_ram[i];
        if (e.x == 0) {
            // NOTE: x == 0 means not visible
            continue;
        }

        if (ppu.line_sprite_count >= 10) {
            // NOTE: Max 10 sprites per line
            break;
        }

        if (e.y <= cur_y + 16 and e.y + sprite_height > cur_y + 16) {
            // NOTE: This sprite is on the current frame

            var entry: *OamLineEntry = &ppu.line_entry_array[ppu.line_sprite_count];
            ppu.line_sprite_count += 1;

            entry.entry = e;
            entry.next = null;

            if (ppu.line_sprites == null or ppu.line_sprites.?.entry.x > e.x) {
                entry.next = ppu.line_sprites;
                ppu.line_sprites = entry;
                continue;
            }

            // NOTE: Do sorting
            var le = ppu.line_sprites;
            var prev = le;

            while (le != null) {
                if (le.?.entry.x > e.x) {
                    prev.?.next = entry;
                    entry.next = le;
                    break;
                }

                if (le.?.next == null) {
                    le.?.next = entry;
                    break;
                }

                prev = le;
                le = le.?.next;
            }
        }
    }
}
pub fn ppuModeOam(ppu: *Ppu) void {
    if (ppu.line_ticks >= 80) {
        ppu.lcd.regs.lcdsModeSet(.XFER);

        ppu.pfc.cur_fetch_state = .TILE;
        ppu.pfc.line_x = 0;
        ppu.pfc.fetch_x = 0;
        ppu.pfc.pushed_x = 0;
        ppu.pfc.fifo_x = 0;
    }

    if (ppu.line_ticks == 1) {
        // NOTE: Read oam on the first tick only
        ppu.line_sprites = null;
        ppu.line_sprite_count = 0;

        loadLineSprites(ppu);
    }
}

pub fn ppuModeXfer(ppu: *Ppu, ctx: *SystemContext) void {
    Pipe.pipelineProcess(ppu, ctx);
    if (ppu.pfc.pushed_x >= XRES) {
        Pipe.pipelineFifoReset(ppu);
        ppu.lcd.regs.lcdsModeSet(.HBLANK);

        if (ppu.lcd.regs.lcdsView().hblank) {
            ctx.int.requestInterrupt(.STAT);
        }
    }
}

pub fn ppuModeVblank(ppu: *Ppu, ctx: *SystemContext) void {
    if (ppu.line_ticks >= TICKS_PER_LINE) {
        incrementLy(ppu, ctx);

        if (ppu.lcd.regs.ly >= LINES_PER_FRAME) {
            ppu.lcd.regs.lcdsModeSet(.OAM);
            ppu.lcd.regs.ly = 0;
            ppu.window_line = 0;
        }
        ppu.line_ticks = 0;
    }
}

pub fn ppuModeHblank(ppu: *Ppu, ctx: *SystemContext) void {
    if (ppu.line_ticks >= TICKS_PER_LINE) {
        incrementLy(ppu, ctx);

        if (ppu.lcd.regs.ly >= YRES) {
            ppu.lcd.regs.lcdsModeSet(.VBLANK);

            ctx.int.requestInterrupt(.VBLANK);

            if (ppu.lcd.regs.lcdsView().vblank) {
                ctx.int.requestInterrupt(.STAT);
            }
            ppu.current_frame += 1;

            // XXX: Calculate FPS
            const end: u32 = @intFromFloat(rl.getTime() * 1000);
            const frame_time: u32 = end - prev_frame_time;

            if (frame_time < target_frame_time) {
                std.time.sleep((target_frame_time - frame_time) * std.time.ns_per_ms);
            }

            if (end - start_timer >= 1000) {
                const fps: u32 = frame_count;
                start_timer = end;
                frame_count = 0;

                std.debug.print("FPS: {}\n", .{fps});

                if (ctx.bus.cart.cartNeedSave()) {
                    ctx.bus.cart.cartBatterySave();
                }
            }

            frame_count += 1;
            prev_frame_time = @intFromFloat(rl.getTime() * 1000);
        } else {
            ppu.lcd.regs.lcdsModeSet(.OAM);
        }

        ppu.line_ticks = 0;
    }
}
