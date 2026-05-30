import logging
import os
import sys
import threading
from logging.handlers import RotatingFileHandler
from pathlib import Path

from fastapi import Depends, FastAPI

from app.config import Settings, get_settings
from app.fiscal_service import FiscalService
from app.schemas import CommandResponse, InvoiceRequest, InvoiceResponse, ReportRequest

IS_FROZEN = getattr(sys, 'frozen', False)
if IS_FROZEN:
    BASE_DIR = Path(sys.executable).parent
else:
    BASE_DIR = Path(__file__).resolve().parent.parent

PID_FILE = BASE_DIR / "fiscal_service.pid"
LOG_FILE = BASE_DIR / "fiscal_service.log"

PID_FILE.write_text(str(os.getpid()))

if IS_FROZEN:
    handler = RotatingFileHandler(str(LOG_FILE), maxBytes=1024 * 1024, backupCount=3)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        handlers=[handler],
    )
else:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Servicio Fiscal ACLAS",
    description="API local para operar una maquina fiscal ACLAS PP9-PLUS por puerto serial.",
    version="0.1.0",
)

_service_lock = threading.Lock()
_service_instance: FiscalService | None = None


def get_fiscal_service(settings: Settings = Depends(get_settings)) -> FiscalService:
    global _service_instance
    with _service_lock:
        if _service_instance is None:
            _service_instance = FiscalService(settings)
        return _service_instance


@app.get("/health")
def health(
    settings: Settings = Depends(get_settings),
) -> dict[str, str | int | float | bool | None]:
    return {
        "status": "ok",
        "serial_port": settings.serial_port,
        "baudrate": settings.baudrate,
        "timeout_seconds": settings.timeout_seconds,
        "report_z_configured": settings.report_z_command is not None,
        "invoice_commands_enabled": settings.enable_invoice_commands,
    }


@app.get("/printer/status", response_model=CommandResponse)
def printer_status(
    service: FiscalService = Depends(get_fiscal_service),
) -> CommandResponse:
    return service.printer_status()


@app.post("/reports/x", response_model=CommandResponse)
def report_x(
    service: FiscalService = Depends(get_fiscal_service),
) -> CommandResponse:
    return service.report_x()


@app.post("/reports/z", response_model=CommandResponse)
def report_z(
    request: ReportRequest,
    service: FiscalService = Depends(get_fiscal_service),
) -> CommandResponse:
    return service.report_z(confirm=request.confirm)


@app.post("/invoices", response_model=InvoiceResponse)
def create_invoice(
    request: InvoiceRequest,
    service: FiscalService = Depends(get_fiscal_service),
) -> InvoiceResponse:
    return service.invoice(request)


@app.on_event("shutdown")
def _cleanup_pid():
    try:
        PID_FILE.unlink(missing_ok=True)
    except Exception:
        pass


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
