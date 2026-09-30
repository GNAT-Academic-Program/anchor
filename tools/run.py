#!/usr/bin/env python3
"""Boot the bootloader in Renode, with the images of your choice.

    python3 tools/run.py                                  # good image in slot A
    python3 tools/run.py build/attacks/unsigned.img       # another image in slot A
    python3 tools/run.py --slot-b build/slot_b.img        # good A, plus an image in B
    python3 tools/run.py --no-gui                         # log in this terminal, no window

Works the same on Linux, macOS and Windows. Needs `renode` on the PATH.
Type `quit` in the Renode monitor to stop.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def renode_path(path):
    """Absolute path with forward slashes: what Renode wants on every OS."""
    return "@" + Path(path).resolve().as_posix()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("slot_a", nargs="?", default=ROOT / "build" / "slot_a.img",
                        help="image for slot A (default: build/slot_a.img)")
    parser.add_argument("--slot-b", help="image for slot B (default: empty)")
    parser.add_argument("--no-gui", action="store_true",
                        help="no windows, Renode monitor in this terminal")
    args = parser.parse_args()

    renode = shutil.which("renode")
    if renode is None:
        sys.exit("renode not found on the PATH. Install it from "
                 "https://github.com/renode/renode/releases")

    for needed in (ROOT / "bin" / "anchor", Path(args.slot_a)):
        if not os.path.exists(needed):
            sys.exit(f"{needed} is missing. Run `alr build`, then "
                     "`python3 tools/pack.py`.")

    commands = [f"$slot_a={renode_path(args.slot_a)}"]
    if args.slot_b:
        commands.append(f"$slot_b={renode_path(args.slot_b)}")
    commands.append(f"include {renode_path(ROOT / 'renode' / 'anchor.resc')}")

    command = [renode]
    if args.no_gui:
        command += ["--disable-xwt", "--console"]
    command += ["-e", "; ".join(commands)]

    sys.exit(subprocess.call(command))


if __name__ == "__main__":
    main()
