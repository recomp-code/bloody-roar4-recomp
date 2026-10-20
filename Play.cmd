@echo off
rem Starts the recompiled Bloody Roar 4 with the launcher's saved settings, without the launcher window
rem (normally just use Launcher.cmd). Options for this start only, in any order:
rem   Play.cmd 6x | dlss | dlss5     picture preset (6x supersampling / 2x + NVIDIA DLSS / DLSS + neural pass)
rem   Play.cmd 16:9 | 4:3            widescreen patch on / original picture
rem   Play.cmd window | fullscreen   (Alt+Enter or F11 also switches in the game)
rem   e.g. Play.cmd dlss 4:3 window
rem Pad: the mod's ANALOG mode is always on; the left stick moves like the D-pad. Keyboard: arrows = D-pad,
rem WASD = left stick, Z/X/C/V = Square/Cross/Circle/Triangle, Q/E = L1/R1, 1/3 = L2/R2, Enter = START,
rem Backspace = SELECT. Xbox-style controller: A = Cross, B = Circle, X = Square, Y = Triangle.
rem Graphics menu: F1, Back+Start or hold START. Logs: <project>\logs\play.log and play_err.log.
start "" powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Launcher.ps1" -Play %*
