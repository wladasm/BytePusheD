# BytePusheD

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Language](https://img.shields.io/badge/language-Delphi-orange)
![Frame Rate](https://img.shields.io/badge/frame%20rate-60%20FPS-brightgreen)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Build](https://img.shields.io/badge/build-manual-lightgrey)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-blue)

_BytePusheD: Where Delphi powers the bytes._

An implementation of the [BytePusher](https://esolangs.org/wiki/BytePusher) virtual machine — a fantasy gaming console.

## Features

- Fully self-contained, written in Delphi
- Uses only standard VCL and WinAPI — no external engines or libraries
- Consistent 60 FPS frame rate
- Sound subsystem support
- On-screen keyboard (mouse-operated; no physical key bindings yet)

## Building

The project was developed and tested in Delphi 2009, but should be compatible with any Delphi version from D2007 onward. Support for older versions might be added in the future.

## Usage

To run the program, just double-click `BytePusheD.exe`.

You can also run it with the path to a BytePusher memory snapshot file (`.BytePusher` or `.bp` extension) as a command line parameter. The snapshot will load automatically on startup. This feature is particularly useful for developing and testing your own BytePusher programs.

## Known Issues

1. The sound implementation isn't perfect (but which one is?) and may occasionally stutter. Improvements are planned, though currently there are no concrete ideas on how to improve it :(

2. The VM temporarily freezes during window movement, resizing, or when expanding main menu items.