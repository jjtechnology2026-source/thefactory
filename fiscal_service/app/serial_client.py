import logging
import time
from dataclasses import dataclass

import serial
from serial import SerialException

from app.aclas_protocol import build_frame, bytes_to_payload
from app.config import Settings

logger = logging.getLogger(__name__)


class FiscalPrinterError(RuntimeError):
    pass


@dataclass
class CommandResult:
    command: str
    frame_hex: str
    response: dict[str, str | int]


class SerialFiscalClient:
    def __init__(self, settings: Settings):
        self.settings = settings

    def send_command(self, command: str) -> CommandResult:
        frame = build_frame(command)
        logger.info("Enviando comando fiscal", extra={"command": command, "frame": frame.hex(" ").upper()})

        try:
            with serial.Serial(
                self.settings.serial_port,
                self.settings.baudrate,
                timeout=self.settings.timeout_seconds,
            ) as connection:
                connection.write(frame)
                time.sleep(self.settings.command_delay_seconds)
                response = connection.read_all()
        except SerialException as exc:
            raise FiscalPrinterError(f"No se pudo comunicar con la impresora fiscal: {exc}") from exc

        payload = bytes_to_payload(response)
        logger.info("Respuesta fiscal recibida", extra={"command": command, "response": payload})
        return CommandResult(command=command, frame_hex=frame.hex(" ").upper(), response=payload)
