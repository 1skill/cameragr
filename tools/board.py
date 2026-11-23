#!/usr/bin/env python3
"""The board at https://claude.ai/artifact/VEX8ciWNH6KtZGbRvwKciH is the
decision page (project/board/decide.html: questions with buttons, answers in
its database). The old long board this script used to build is retired (the
user asked for the decision page). Kept so the auto-run steps "python3
tools/board.py, then publish project/board/index.html" publish the decision
page and never the old one again: index.html becomes a copy of decide.html.
The old builder is in project/board/board_old.py.txt."""
import pathlib, shutil
board = pathlib.Path(__file__).resolve().parent.parent / "project/board"
shutil.copyfile(board / "decide.html", board / "index.html")
print(board / "index.html", "(= decide.html)")
