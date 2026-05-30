from functools import lru_cache
from os import getenv
from typing import Optional

from pydantic import BaseModel, Field


class Settings(BaseModel):
    app_name: str = "Servicio Fiscal ACLAS"
    serial_port: str = Field(default_factory=lambda: getenv("ACLAS_SERIAL_PORT", "COM8"))
    baudrate: int = Field(default_factory=lambda: int(getenv("ACLAS_BAUDRATE", "9600")))
    timeout_seconds: float = Field(default_factory=lambda: float(getenv("ACLAS_TIMEOUT_SECONDS", "2")))
    command_delay_seconds: float = Field(
        default_factory=lambda: float(getenv("ACLAS_COMMAND_DELAY_SECONDS", "1.5"))
    )
    report_x_command: str = Field(default_factory=lambda: getenv("ACLAS_REPORT_X_COMMAND", "I0X"))
    report_z_command: Optional[str] = Field(default_factory=lambda: getenv("ACLAS_REPORT_Z_COMMAND"))
    status_command: str = Field(default_factory=lambda: getenv("ACLAS_STATUS_COMMAND", "S1"))
    enable_invoice_commands: bool = Field(
        default_factory=lambda: getenv("ACLAS_ENABLE_INVOICE_COMMANDS", "false").lower()
        in {"1", "true", "yes", "on"}
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
