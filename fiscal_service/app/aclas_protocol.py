STX = b"\x02"
ETX = b"\x03"


def calculate_lrc(command_bytes: bytes) -> bytes:
    """Calcula el LRC aplicando XOR sobre el comando y el ETX."""
    lrc = 0
    for byte in command_bytes:
        lrc ^= byte
    lrc ^= ETX[0]
    return bytes([lrc])


def build_frame(command: str) -> bytes:
    command_bytes = command.encode("ascii")
    return STX + command_bytes + ETX + calculate_lrc(command_bytes)


def bytes_to_payload(data: bytes) -> dict[str, str | int]:
    return {
        "raw_hex": data.hex(" ").upper(),
        "ascii": data.decode("ascii", errors="replace"),
        "length": len(data),
    }
