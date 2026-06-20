@echo off
rem Start Godot Studio (Windows twin of run.sh). Needs .godot-bin\godot.exe.
cd /d "%~dp0"
if not exist ".godot-bin\godot.exe" (
    echo godot.exe not found in .godot-bin\ - run install.sh (or place godot.exe there).
    pause
    exit /b 1
)
".godot-bin\godot.exe" --path . res://tools/godot_studio.tscn
