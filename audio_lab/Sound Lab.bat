@echo off
rem Sound Lab: the training ring with live sound swapping (F1). Uses its own save, never your real one.
set FRIGHT_NIGHT_SAVE=user://sound_lab_save.json
set FRIGHT_NIGHT_SETTINGS=user://sound_lab_settings.cfg
start "" "C:\Users\IsaiahandLaura\Desktop\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "%~dp0..\punch-craft" res://sound_lab.tscn
