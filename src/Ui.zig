const std = @import("std");
const rl = @import("raylib");

const System = @import("System.zig").System;
const SystemContext = @import("SystemContext.zig").SystemContext;

const debug_scale: usize = 2;
const scale: usize = 4;

const LINES_PER_FRAME = 154;
const TICKS_PER_LINE = 456;
const YRES = 144;
const XRES = 160;

const tile_color_palette = [4]rl.Color{
    .white,
    rl.Color{ .r = 170, .g = 170, .b = 170, .a = 255 },
    rl.Color{ .r = 85, .g = 85, .b = 85, .a = 255 },
    .black,
};

const Rectangle = struct {};

pub fn init() !void {
    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    const window_width: i32 = 1200;
    const window_height: i32 = 900;

    rl.initWindow(window_width, window_height, "Demo");
    rl.setTargetFPS(60);
}

pub fn update(ctx: *SystemContext) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.gray);

    drawGameDisplay(ctx);
    drawDebugTiles(ctx);
}

pub fn createVideoTexture() rl.Texture2D {
    const image = rl.genImageColor(XRES, YRES, .blank);
    defer rl.unloadImage(image);
    return rl.loadTextureFromImage(image);
}

pub fn drawGameDisplay(ctx: *SystemContext) void {
    const video_buffer: [*]u32 = &ctx.bus.ppu.video_buffer;

    var pixel_rect = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(scale),
        .height = @floatFromInt(scale),
    };

    for (0..YRES) |line_num| {
        for (0..XRES) |x| {
            const pixel_data = video_buffer[x + (line_num * XRES)];
            const pixel_color = rl.Color{
                .r = @truncate((pixel_data >> 16) & 0xFF),
                .g = @truncate((pixel_data >> 8) & 0xFF),
                .b = @truncate((pixel_data) & 0xFF),
                .a = 255,
            };

            pixel_rect.x = @floatFromInt(x * scale);
            pixel_rect.y = @floatFromInt(line_num * scale);

            rl.drawRectangleRec(pixel_rect, pixel_color);
        }
    }
}

pub fn drawDebugTiles(ctx: *SystemContext) void {
    const addr = 0x8000;
    const debug_x: i32 = 700;
    const debug_y: i32 = 0;
    var tile_num: u16 = 0;

    for (0..24) |y| {
        for (0..16) |x| {
            const tile_spacing = 9;
            const tile_x = debug_x + @as(i32, @intCast(x * tile_spacing * debug_scale));
            const tile_y = debug_y + @as(i32, @intCast(y * tile_spacing * debug_scale));

            displayTile(ctx, addr, tile_num, @intCast(tile_x), @intCast(tile_y));
            tile_num += 1;
        }
    }
}

pub fn displayTile(ctx: *SystemContext, start: u16, tile_num: u16, x: usize, y: usize) void {
    var tile_y: usize = 0;
    while (tile_y < 16) : (tile_y += 2) {
        const b1: u8 = ctx.bus.read(ctx, start + (tile_num * 16) + @as(u16, @intCast(tile_y)));
        const b2: u8 = ctx.bus.read(ctx, start + (tile_num * 16) + @as(u16, @intCast(tile_y + 1)));

        for (0..8) |i| {
            const bit: u3 = 7 - @as(u3, @intCast(i));
            const mask: u8 = @as(u8, 1) << bit;
            const hi: u8 = @as(u8, @intFromBool((b1 & mask) != 0)) << 1;
            const lo: u8 = @intFromBool((b2 & mask) != 0);
            const color: u8 = hi | lo;

            const rect = rl.Rectangle{
                .x = @floatFromInt(x + ((7 - bit) * debug_scale)),
                .y = @floatFromInt(y + (tile_y / 2 * debug_scale)),
                .width = @floatFromInt(debug_scale),
                .height = @floatFromInt(debug_scale),
            };

            rl.drawRectangleRec(rect, tile_color_palette[color]);
        }
    }
}

pub fn updateInputs(ctx: *SystemContext) void {
    const gamepad_state = ctx.gp.getState();

    gamepad_state.b = rl.isKeyDown(rl.KeyboardKey.z);
    gamepad_state.a = rl.isKeyDown(rl.KeyboardKey.x);
    gamepad_state.start = rl.isKeyDown(rl.KeyboardKey.enter);
    gamepad_state.select = rl.isKeyDown(rl.KeyboardKey.tab);
    gamepad_state.up = rl.isKeyDown(rl.KeyboardKey.up);
    gamepad_state.down = rl.isKeyDown(rl.KeyboardKey.down);
    gamepad_state.right = rl.isKeyDown(rl.KeyboardKey.right);
    gamepad_state.left = rl.isKeyDown(rl.KeyboardKey.left);
}

pub fn handleEvents(sys: *System, ctx: *SystemContext) void {
    if (rl.windowShouldClose()) {
        sys.die = true;
    }
    updateInputs(ctx);
}

pub fn cleanUp() void {
    rl.closeWindow();
}
