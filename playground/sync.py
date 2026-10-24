"""Builds the Playground project: a copy of the game (punch-craft/) plus the
playground's own files (playground/src/ -> res://playground/), with its own
project name (so its own save folder) and the playground as the main scene.

Run before every launch (run_playground.bat / run_playground.sh do): it
mirrors the game, so the playground always runs the latest code. Only files
that changed are copied; files the game no longer has are removed.
"""
import filecmp
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "..", "punch-craft")
SRC = os.path.join(HERE, "src")
OUT = os.path.join(HERE, "project")
SKIP_DIRS = {".godot", "builds", ".git"}


def mirror(src, dst):
    copied = 0
    wanted = set()
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel = os.path.relpath(root, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for name in files:
            if rel == "." and name == "project.godot":
                continue
            wanted.add(os.path.normpath(os.path.join(rel, name)))
            a = os.path.join(root, name)
            b = os.path.join(dst, rel, name)
            if not os.path.exists(b) or not filecmp.cmp(a, b, shallow=False):
                shutil.copy2(a, b)
                copied += 1
    return copied, wanted


def main():
    os.makedirs(OUT, exist_ok=True)
    copied, wanted = mirror(GAME, OUT)
    extra, mine = mirror(SRC, os.path.join(OUT, "playground"))
    wanted |= {os.path.normpath(os.path.join("playground", p)) for p in mine}
    # Drop files the game no longer has (not Godot's cache).
    removed = 0
    for root, dirs, files in os.walk(OUT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            rel = os.path.normpath(os.path.relpath(os.path.join(root, name), OUT))
            if rel not in wanted and rel != "project.godot":
                os.remove(os.path.join(root, name))
                removed += 1
    # Its own name (so its own user:// folder and save) and main scene.
    project = open(os.path.join(GAME, "project.godot"), encoding="utf-8").read()
    project = re.sub(r'config/name=".*"', 'config/name="Fright Night Playground"', project)
    project = re.sub(r'run/main_scene=".*"', 'run/main_scene="res://playground/playground.tscn"', project)
    path = os.path.join(OUT, "project.godot")
    if not os.path.exists(path) or open(path, encoding="utf-8").read() != project:
        open(path, "w", encoding="utf-8", newline="").write(project)
        copied += 1
    print("Playground synced: %d file(s) updated, %d removed." % (copied + extra, removed))


if __name__ == "__main__":
    sys.exit(main())
