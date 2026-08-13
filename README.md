# Flex6502 Console
A four-game console running on a real 6502 CPU core inside an FPGA, with VGA
output and keyboard control over a serial terminal.

Snake, Tetris, Space Invaders and Breakout, picked from a start menu, all
running as 6502 machine code on a Zedboard.

|                                 |                                 |                             |
|---                              |---                              |---                          |
| ![menu](docs/menu.png)          | ![snake](docs/snake.png)        | ![tetris](docs/tetris.png)  |
| ![invaders](docs/invaders.png)  | ![breakout](docs/breakout.png)  |                             |

## Quick start
```bash
git clone https://github.com/RubenVerra/ES-S-Demo-s.git
cd flex6502-console

# Creates build/flex6502_console.xpr with every source and the right part.
vivado -mode batch -source create_project.tcl

# Or go all the way to a bitstream in one command:
vivado -mode batch -source create_project.tcl -tclargs bit
```

Then:
1. Open `build/flex6502_console.xpr` and press **Generate Bitstream**, or use the `bit` variant above and program `flex6502_console.bit` directly.
2. Program the board from the Vivado Hardware Manager.
3. Connect the monitor to VGA. The menu should appear immediately.
4. Open a serial terminal on the board's COM port at **115200 baud, 8N1**. Keystrokes typed there are the controller.

There is nothing to configure by hand. `create_project.tcl` derives every path
from its own location, so the repository works wherever you clone it.

## Controls
Everything is typed into the serial terminal. Only these keys are read.

|     | Menu    | Snake | Tetris      | Invaders  | Breakout  |
|---  |---      |---    |---          |---        |---        |
| `W` | up      | up    | rotate      | fire      | -         |
| `A` | -       | left  | left        | left      | left      |
| `S` | down    | down  | drop faster | -         | -         |
| `D` | select  | right | right       | right     | right     |


The digit keys `0`-`9` and `J`/`K`/`L` change the CPU clock live, from very slow
to full speed. `0` is the normal setting.

Two switches are wired for diagnostics: **SW0** shows VGA colour bars (proves
the monitor and timing are fine), **SW1** shows every non-zero screen byte as
white (proves the CPU is writing to the framebuffer).

## How it works
![systemarchitecture 6502 console](docs/systemarchitecture_6502_console.svg)

The 6502 never touches VGA. It only writes tile codes into a 1 kB screen buffer
at `0x0200`. A separate block continuously sends that buffer over an internal
UART link and hands the bytes to the renderer, which turns each byte into a
20x15 pixel tile.

Because the sender reads memory continuously, the games redraw **incrementally**, they erase and redraw only the cells that changed. Clearing the whole screen
every frame produces visible tearing.

### Tile codes
| Code            | Tile            | Code          | Tile          |
|---              |---              |---            |---            |
| `0x00`          | empty           | `0x0D`        | bomb          |
| `0x01`          | wall            | `0x0E`        | paddle        |
| `0x02`-`0x08`   | Tetris blocks   | `0x0F`        | ball          |
| `0x09`, `0x0A`  | alien frames    | `0x11`        | snake segment |
| `0x0B`          | cannon          | `0xEE`        | apple         |
| `0x0C`          | bullet          | `0x80`        | menu bar      |
| `0x40`-`0x49`   | digits 0-9      | `0x4A`-`0x63` | letters A-Z   |

### Memory map
All four games live in a single 32 kB image, `memory/games.list`, which is
loaded into the block RAM at configuration time.

| Range             | Size    | Contents                                                |
|---                |---      |---                                                      |
| `0x0000`-`0x00FF` | 256 B   | zero page: game state, scores, `0xFF` = keystroke inbox |
| `0x0100`-`0x01FF` | 256 B   | 6502 hardware stack                                     |
| `0x0200`-`0x05FF` | 1 kB    | screen buffer, 32x32 tile codes                         |
| `0x0600`-`0x110A` | 2827 B  | menu, Snake, Tetris, Invaders, Breakout                 |
| `0x1200`-`0x12FF` | 256 B   | Tetris playfield                                        |
| `0x1300`-`0x133F` | 64 B    | alien fleet state                                       |
| `0x1340`-`0x137F` | 64 B    | Tetris piece shapes                                     |
| `0x1380`-`0x13BF` | 64 B    | screen row address table (low/high bytes)               |
| `0x1400`-`0x147F` | 128 B   | Breakout bricks and row colours                         |
| `0x1500`-`0x15C9` | 202 B   | menu and status text                                    |
| `0x15CA`-`0x7FFB` | 26 kB   | free                                                    |
| `0x7FFC`-`0x7FFF` | 4 B     | reset and IRQ vectors, both `0x0600`                    |

## Changing the games
The image in `memory/games.list` is built from `software/games.asm`
