"""Build script to package the fiscal service as a standalone .exe.

Usage:
    python build_exe.py

Requires PyInstaller to be installed:
    pip install pyinstaller

The output .exe will be in dist/fiscal_service.exe
"""

import subprocess
import sys
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent

    spec_file = root / "fiscal_service.spec"
    if not spec_file.exists():
        print(f"ERROR: spec file not found at {spec_file}", file=sys.stderr)
        sys.exit(1)

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--clean",
        str(spec_file),
    ]

    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=str(root))

    if result.returncode == 0:
        exe_path = root / "dist" / "fiscal_service.exe"
        print(f"\nBuild successful: {exe_path}")
    else:
        print(f"\nBuild failed with code {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
