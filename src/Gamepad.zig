const std = @import("std");

pub const GamepadState = struct {
    start: bool,
    select: bool,
    a: bool,
    b: bool,
    up: bool,
    down: bool,
    left: bool,
    right: bool,

    pub fn init() GamepadState {
        return GamepadState{
            .start = false,
            .select = false,
            .a = false,
            .b = false,
            .up = false,
            .down = false,
            .left = false,
            .right = false,
        };
    }
};

pub const Gamepad = struct {
    button_sel: bool,
    dir_sel: bool,
    controller: GamepadState,

    pub fn init() Gamepad {
        return Gamepad{
            .button_sel = false,
            .dir_sel = false,
            .controller = GamepadState.init(),
        };
    }

    pub fn buttonSelect(self: *Gamepad) bool {
        return self.button_sel;
    }

    pub fn dirSelect(self: *Gamepad) bool {
        return self.dir_sel;
    }

    pub fn setSelect(self: *Gamepad, value: u8) void {
        self.button_sel = (value & 0x20) != 0;
        self.dir_sel = (value & 0x10) != 0;
    }

    pub fn getState(self: *Gamepad) *GamepadState {
        return &self.controller;
    }

    pub fn getOutput(self: *Gamepad) u8 {
        var output: u8 = 0xCF;

        if (!self.buttonSelect()) {
            if (self.getState().start) {
                output &= ~(@as(u8, 1) << 3);
            }
            if (self.getState().select) {
                output &= ~(@as(u8, 1) << 2);
            }
            if (self.getState().a) {
                output &= ~(@as(u8, 1) << 0);
            }
            if (self.getState().b) {
                output &= ~(@as(u8, 1) << 1);
            }
        }

        if (!self.dirSelect()) {
            if (self.getState().left) {
                output &= ~(@as(u8, 1) << 1);
            }
            if (self.getState().right) {
                output &= ~(@as(u8, 1) << 0);
            }
            if (self.getState().up) {
                output &= ~(@as(u8, 1) << 2);
            }
            if (self.getState().down) {
                output &= ~(@as(u8, 1) << 3);
            }
        }
        return output;
    }
};
