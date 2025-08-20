# Gameboy Emulator

Gameboy emulator written in Zig language (0.14.1)

# Not too long didn't read anyways

Somewhat functional, some games are playable at best. No audio. 

## Graphics

* Raylib (5.6.0-dev)

## Description

Work in progress. Many bugs, such sloppy implementations. Timings are out of place (I think). I tried to make it as accurate as possible for ticks and cycles. You could find and try playing some of the games in the list below. I think I might try to implement the audio some time later.

- [x] Cpu
- [x] Ppu
- [x] Gamepad
- [ ] Audio

## Tests passed

* Blargg's cpu instructions via [gameboy-doctor](https://github.com/robert/gameboy-doctor)
* [Dmg-acid2](https://github.com/mattcurrie/dmg-acid2) by Matt Currie

## To run

```bash
zig build run -- arg1 [path-to-rom-file]
```

## Controls

| Keyboard key          | Gameboy            |
|-----------------------|--------------------|
| Esc                   | Exit               |
| Arrow Keys            | Move               |
| X                     | A                  |
| Z                     | B                  |
| Enter                 | Start              |
| Tab                   | Select             |

## Tested games

* Dr.Mario (Playable)
* Tetris (Playable)
* Legend of Zelda, The - Link's Awakening (Playable)
* Mega Man 2 (Playable)
* Megami Tensei Gaiden - Last Bible (Japan) (Playable)
* Alien 3 (Has some issues with window tiles)
* Batman - Return of the Joker (Playable)
* Asteroids (Playable)
* NBA All-Star Challenge - Doesn't work

## Learning resources

* [Low Level Devel](https://www.youtube.com/@lowleveldevel1712)
* [Pandocs](https://gbdev.io/pandocs/CPU_Instruction_Set.html)
* [GbDocs](https://gbdev.io/gb-opcodes/optables/)
* [RGBDS](https://rgbds.gbdev.io/docs/v0.9.3/gbz80.7#SUB_A,r8)





