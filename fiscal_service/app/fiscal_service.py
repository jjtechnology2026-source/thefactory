import threading
from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status

from app.config import Settings
from app.schemas import CommandResponse, InvoiceRequest, InvoiceResponse, PaymentMethod, TaxCode
from app.serial_client import FiscalPrinterError, SerialFiscalClient


TAX_COMMANDS = {
    TaxCode.EXENTO: " ",
    TaxCode.IVA_GENERAL: "!",
    TaxCode.IVA_REDUCIDO: '"',
    TaxCode.IVA_ADICIONAL: "#",
    TaxCode.PERCIBIDO: "$",
}

PAYMENT_COMMANDS = {
    PaymentMethod.CASH: "201",
    PaymentMethod.CARD: "122",
    PaymentMethod.TRANSFER: "122",
    PaymentMethod.MOBILE_PAYMENT: "122",
    PaymentMethod.OTHER: "122",
}


class FiscalService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.client = SerialFiscalClient(settings)
        self._lock = threading.Lock()

    def printer_status(self) -> CommandResponse:
        return self._send(self.settings.status_command)

    def report_x(self) -> CommandResponse:
        return self._send(self.settings.report_x_command)

    def report_z(self, confirm: bool) -> CommandResponse:
        if not confirm:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Reporte Z requiere confirm=true porque cierra la jornada fiscal.",
            )
        if not self.settings.report_z_command:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail="Configure ACLAS_REPORT_Z_COMMAND con el comando exacto del modelo antes de imprimir Reporte Z.",
            )
        return self._send(self.settings.report_z_command)

    def invoice(self, request: InvoiceRequest) -> InvoiceResponse:
        commands = self._build_invoice_commands(request)

        if request.dry_run:
            return InvoiceResponse(
                status="validated",
                total=request.total,
                dry_run=True,
                planned_commands=commands,
                message="Factura validada sin enviar comandos a la impresora.",
            )

        if not self.settings.enable_invoice_commands:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail=(
                    "La facturacion real esta deshabilitada. Revise los comandos con el manual ACLAS PP9-PLUS "
                    "y active ACLAS_ENABLE_INVOICE_COMMANDS=true cuando esten confirmados."
                ),
            )

        responses = [self._send(command) for command in commands]
        return InvoiceResponse(
            status="printed",
            total=request.total,
            dry_run=False,
            commands=responses,
            planned_commands=commands,
        )

    def _send(self, command: str) -> CommandResponse:
        with self._lock:
            try:
                result = self.client.send_command(command)
            except FiscalPrinterError as exc:
                raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc

        return CommandResponse(command=result.command, frame_hex=result.frame_hex, response=result.response)

    def _build_invoice_commands(self, request: InvoiceRequest) -> list[str]:
        commands: list[str] = [
            f"iR*{_clean_text(request.customer.document, 32)}",
            f"iS*{_clean_text(request.customer.name, 120)}",
        ]

        if request.customer.address:
            commands.append(f"i01{_clean_text(request.customer.address, 120)}")
        if request.notes:
            commands.append(f"@{_clean_text(request.notes, 120)}")

        for item in request.items:
            sku = _clean_text(item.sku or "0000", 32)
            description = _clean_text(item.description, 120)
            command = TAX_COMMANDS[item.tax_code]
            commands.append(
                f"{command}{_format_amount(item.unit_price, 10)}{_format_quantity(item.quantity)}{sku}{description}"
            )
            if item.discount_amount > 0:
                commands.append(f"q-{_format_amount(item.discount_amount, 9)}")

        for payment in request.payments:
            payment_command = PAYMENT_COMMANDS[payment.method]
            commands.append(f"{payment_command}{_format_amount(payment.amount, 12)}")

        commands.append("199")
        return commands


def _format_amount(value: Decimal, width: int) -> str:
    cents = (value * Decimal("100")).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return str(int(cents)).zfill(width)


def _format_quantity(value: Decimal) -> str:
    thousandths = (value * Decimal("1000")).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return str(int(thousandths)).zfill(8)


def _clean_text(value: str, max_length: int) -> str:
    clean = value.replace("\x02", "").replace("\x03", "").strip()
    return clean[:max_length]
