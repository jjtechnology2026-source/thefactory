"""Entry point for the fiscal service executable.

Used by PyInstaller to build a standalone .exe.
When running as a frozen exe, uvicorn is embedded and the
server starts directly without console window (--noconsole in spec).
"""

import uvicorn


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="127.0.0.1",
        port=8000,
        log_level="info",
    )
