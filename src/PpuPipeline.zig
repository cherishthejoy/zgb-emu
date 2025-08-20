const std = @import("std");

const Ppu = @import("Ppu.zig").Ppu;
const Fifo = @import("Ppu.zig").Fifo;
const FifoEntry = @import("Ppu.zig").FifoEntry;
const SystemContext = @import("SystemContext.zig").SystemContext;

const OamLineEntry = @import("Ppu.zig").OamLineEntry;

const LINES_PER_FRAME = 154;
const TICKS_PER_LINE = 456;
const YRES = 144;
const XRES = 160;

pub fn windowVisible(ppu: *Ppu) bool {
    return (ppu.lcd.regs.lcdcWindowEnable() and
        ppu.lcd.regs.win_x >= 0 and
        ppu.lcd.regs.win_x <= 166 and
        ppu.lcd.regs.win_y >= 0 and
        ppu.lcd.regs.win_y < YRES);
}

pub fn push(fifo: *Fifo, value: u32) void {
    if (fifo.size >= 16) {
        std.log.warn("FIFO overflow!", .{});
        return;
    }

    fifo.data[fifo.tail] = value;
    fifo.tail = (fifo.tail + 1) % 16;
    fifo.size += 1;
}

pub fn pop(fifo: *Fifo) u32 {
    if (fifo.size <= 0) {
        std.log.info("Error in pixel FIFO", .{});
        std.process.exit(1);
    }

    const value = fifo.data[fifo.head];
    fifo.head = (fifo.head + 1) % 16;
    fifo.size -= 1;

    return value;
}

fn fetchSpritePixels(ppu: *Ppu, color: u32, bg_color: u8) u32 {
    var result_color = color;
    for (0..ppu.fetched_entry_count) |i| {
        const sp_x = (ppu.fetched_entries[i].x -% 8) +% @mod(ppu.lcd.regs.scroll_x, 8);

        if (sp_x +% 8 < ppu.pfc.fifo_x) {
            // NOTE: Past pixel point already
            continue;
        }

        const offset: i32 = @as(i32, ppu.pfc.fifo_x) - @as(i32, sp_x);

        if (offset < 0 or offset > 7) {
            // NOTE: Out of bounds
            continue;
        }

        // bit.* = @intCast(7 - offset);
        var local_bit: u3 = @intCast(7 - offset);

        if (ppu.fetched_entries[i].flags.f_x_flip != 0) {
            local_bit = @intCast(offset);
        }

        const hi: u8 = @intFromBool((ppu.pfc.fetch_entry_data[i * 2] & @as(u8, 1) << local_bit) != 0);
        const lo: u8 = @as(u8, @intFromBool((ppu.pfc.fetch_entry_data[(i * 2) + 1] & (@as(u8, 1) << local_bit)) != 0)) << 1;

        const bg_prio = ppu.fetched_entries[i].flags.f_bgp;

        if ((hi | lo) == 0) {
            // NOTE: Transparent
            continue;
        }

        if (bg_prio == 0 or bg_color == 0) {
            result_color = if (ppu.fetched_entries[i].flags.f_pn != 0) ppu.lcd.sp2_colors[hi | lo] else ppu.lcd.sp1_colors[hi | lo];

            if ((hi | lo) != 0) {
                break;
            }
        }
    }

    return result_color;
}

pub fn pipelineAdd(ppu: *Ppu) bool {
    if (ppu.pfc.pixel_fifo.size > 8) return false;

    const x: i32 = ppu.pfc.fetch_x - (8 - (@mod(ppu.lcd.regs.scroll_x, 8)));

    for (0..8) |i| {
        const bit: u3 = 7 - @as(u3, @intCast(i));
        const mask: u8 = @as(u8, 1) << bit;
        const hi: u8 = @intFromBool((ppu.pfc.bgw_fetch_data[1] & mask) != 0);
        const lo: u8 = @as(u8, @intFromBool((ppu.pfc.bgw_fetch_data[2] & mask) != 0)) << 1;
        var color: u32 = ppu.lcd.bg_colors[hi | lo];

        if (!ppu.lcd.regs.lcdcBgwEnable()) {
            color = ppu.lcd.bg_colors[0];
        }

        if (ppu.lcd.regs.lcdcObjEnable()) {
            color = fetchSpritePixels(ppu, color, hi | lo);
        }

        if (x >= 0) {
            push(&ppu.pfc.pixel_fifo, color);
            ppu.pfc.fifo_x += 1;
        }
    }

    return true;
}

pub fn pipelineLoadSpriteTile(ppu: *Ppu) void {
    var le: ?*OamLineEntry = ppu.line_sprites;

    while (le != null) {
        const sp_x = (le.?.entry.x -% 8) +% @mod(ppu.lcd.regs.scroll_x, 8);

        if ((sp_x >= ppu.pfc.fetch_x and sp_x < ppu.pfc.fetch_x +% 8) or
            ((sp_x +% 8) >= ppu.pfc.fetch_x and (sp_x +% 8) < ppu.pfc.fetch_x + 8))
        {
            // NOTE: Need to add entry
            ppu.fetched_entries[ppu.fetched_entry_count] = le.?.entry;
            ppu.fetched_entry_count += 1;
        }

        le = le.?.next;

        if (le == null or ppu.fetched_entry_count >= 3) {
            // NOTE: Max checking 3 sprites on pixels
            break;
        }
    }
}

pub fn pipelineLoadSpriteData(ppu: *Ppu, ctx: *SystemContext, offset: u8) void {
    const cur_y = ppu.lcd.regs.ly;
    const sprite_height: u8 = ppu.lcd.regs.lcdcObjHeight();

    for (0..ppu.fetched_entry_count) |i| {
        const sprite_y = ppu.fetched_entries[i].y;
        var ty: u8 = ((cur_y +% 16) -% sprite_y) * 2;

        if (ppu.fetched_entries[i].flags.f_y_flip != 0) {
            // NOTE: Flipped upside down
            ty = ((sprite_height * 2) - 2) -% ty;
        }

        var tile_index: u8 = ppu.fetched_entries[i].tile;

        if (sprite_height == 16) {
            tile_index &= ~@as(u8, 1); // XXX: Remove last bit
        }

        const address = 0x8000 + (@as(u16, tile_index) * 16) + @as(u16, ty) + offset;
        ppu.pfc.fetch_entry_data[(i * 2) + offset] = ctx.bus.read(ctx, address);
    }
}

fn pipelineLoadWindowTile(ppu: *Ppu, ctx: *SystemContext) void {
    if (!windowVisible(ppu)) {
        return;
    }

    const wx = ppu.lcd.regs.win_x;
    const wy = ppu.lcd.regs.win_y;

    if (ppu.pfc.fetch_x + 7 >= wx and
        ppu.pfc.fetch_x + 7 < wx +% XRES +% 14)
    {
        if (ppu.lcd.regs.ly >= wy and
            ppu.pfc.fetch_x + 7 >= wx)
        {
            const w_tile_y: u16 = ppu.window_line / 8;
            const w_tile_x: u16 = (ppu.pfc.fetch_x + 7 - wx) / 8;

            const tile_addr = ppu.lcd.regs.lcdcWinMapArea() + w_tile_x + (w_tile_y * 32);

            ppu.pfc.bgw_fetch_data[0] = ctx.bus.read(ctx, tile_addr);

            if (ppu.lcd.regs.bgwDataArea() == 0x8800) {
                ppu.pfc.bgw_fetch_data[0] +%= 128;
            }
        }
    }
}

pub fn pipelineFetch(ppu: *Ppu, ctx: *SystemContext) void {
    switch (ppu.pfc.cur_fetch_state) {
        .TILE => {
            ppu.fetched_entry_count = 0;

            if (ppu.lcd.regs.lcdcBgwEnable()) {
                const tile_x = @as(u16, ppu.pfc.map_x / 8);
                const tile_y = @as(u16, (ppu.pfc.map_y / 8));
                const tilemap_addr: u16 = ppu.lcd.regs.bgMapArea() + tile_x + tile_y * 32;

                ppu.pfc.bgw_fetch_data[0] = ctx.bus.read(ctx, tilemap_addr);

                if (ppu.lcd.regs.bgwDataArea() == 0x8800) {
                    ppu.pfc.bgw_fetch_data[0] +%= 128;
                }

                pipelineLoadWindowTile(ppu, ctx);
            }

            if (ppu.lcd.regs.lcdcObjEnable() and ppu.line_sprites != null) {
                pipelineLoadSpriteTile(ppu);
            }

            ppu.pfc.cur_fetch_state = .DATA0;
            ppu.pfc.fetch_x += 8;
        },
        .DATA0 => {
            const tiledata_addr = ppu.lcd.regs.bgwDataArea() + (@as(u16, ppu.pfc.bgw_fetch_data[0]) *% 16 +% ppu.pfc.tile_y);
            ppu.pfc.bgw_fetch_data[1] = ctx.bus.read(ctx, tiledata_addr);
            pipelineLoadSpriteData(ppu, ctx, 0);

            ppu.pfc.cur_fetch_state = .DATA1;
        },
        .DATA1 => {
            const tiledata_addr = ppu.lcd.regs.bgwDataArea() + (@as(u16, ppu.pfc.bgw_fetch_data[0]) *% 16 +% ppu.pfc.tile_y +% 1);
            ppu.pfc.bgw_fetch_data[2] = ctx.bus.read(ctx, tiledata_addr);
            pipelineLoadSpriteData(ppu, ctx, 1);

            ppu.pfc.cur_fetch_state = .IDLE;
        },
        .IDLE => {
            ppu.pfc.cur_fetch_state = .PUSH;
        },
        .PUSH => {
            if (pipelineAdd(ppu)) {
                ppu.pfc.cur_fetch_state = .TILE;
            }
        },
    }
}

pub fn pipelinePushPixel(ppu: *Ppu) void {
    if (ppu.pfc.pixel_fifo.size > 8) {
        const pixel_data: u32 = pop(&ppu.pfc.pixel_fifo);
        const index = @as(u32, ppu.pfc.pushed_x) + (@as(u32, ppu.lcd.regs.ly) * XRES);
        if (ppu.pfc.line_x >= @mod(ppu.lcd.regs.scroll_x, 8)) {
            if (index < ppu.video_buffer.len) {
                ppu.video_buffer[index] = pixel_data;
            }
            ppu.pfc.pushed_x += 1;
        }

        ppu.pfc.line_x += 1;
    }
}

pub fn pipelineProcess(ppu: *Ppu, ctx: *SystemContext) void {
    ppu.pfc.map_y = ppu.lcd.regs.ly +% ppu.lcd.regs.scroll_y;
    ppu.pfc.map_x = ppu.pfc.fetch_x +% ppu.lcd.regs.scroll_x;
    ppu.pfc.tile_y = @mod(ppu.lcd.regs.ly +% ppu.lcd.regs.scroll_y, 8) * 2;

    if ((ppu.line_ticks & 1) == 0) {
        pipelineFetch(ppu, ctx);
    }

    pipelinePushPixel(ppu);
}

pub fn pipelineFifoReset(ppu: *Ppu) void {
    while (ppu.pfc.pixel_fifo.size > 0) {
        _ = pop(&ppu.pfc.pixel_fifo);
    }

    ppu.pfc.pixel_fifo.head = 0;
    ppu.pfc.pixel_fifo.tail = 0;
    ppu.pfc.pixel_fifo.size = 0;
}
