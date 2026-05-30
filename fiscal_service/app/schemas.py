from decimal import Decimal
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator, model_validator


class TaxCode(str, Enum):
    EXENTO = "EXENTO"
    IVA_GENERAL = "IVA_GENERAL"
    IVA_REDUCIDO = "IVA_REDUCIDO"
    IVA_ADICIONAL = "IVA_ADICIONAL"
    PERCIBIDO = "PERCIBIDO"


class PaymentMethod(str, Enum):
    CASH = "cash"
    CARD = "card"
    TRANSFER = "transfer"
    MOBILE_PAYMENT = "mobile_payment"
    OTHER = "other"


class Customer(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    document: str = Field(..., min_length=1, max_length=32, description="RIF, cedula o documento fiscal")
    address: Optional[str] = Field(default=None, max_length=240)
    phone: Optional[str] = Field(default=None, max_length=32)


class InvoiceItem(BaseModel):
    description: str = Field(..., min_length=1, max_length=120)
    quantity: Decimal = Field(..., gt=0)
    unit_price: Decimal = Field(..., ge=0)
    tax_code: TaxCode = TaxCode.IVA_GENERAL
    sku: Optional[str] = Field(default=None, max_length=32)
    discount_amount: Decimal = Field(default=Decimal("0"), ge=0)

    @property
    def line_total(self) -> Decimal:
        total = (self.quantity * self.unit_price) - self.discount_amount
        return total if total > 0 else Decimal("0")


class Payment(BaseModel):
    method: PaymentMethod
    amount: Decimal = Field(..., gt=0)
    reference: Optional[str] = Field(default=None, max_length=64)


class InvoiceRequest(BaseModel):
    customer: Customer
    items: list[InvoiceItem] = Field(..., min_length=1)
    payments: list[Payment] = Field(..., min_length=1)
    invoice_number: Optional[str] = Field(default=None, max_length=32)
    notes: Optional[str] = Field(default=None, max_length=240)
    dry_run: bool = Field(
        default=False,
        description="Si es true, valida y devuelve el total sin enviar comandos a la impresora.",
    )

    @field_validator("items")
    @classmethod
    def validate_item_totals(cls, items: list[InvoiceItem]) -> list[InvoiceItem]:
        for item in items:
            if item.discount_amount > item.quantity * item.unit_price:
                raise ValueError("El descuento de un item no puede superar su total bruto.")
        return items

    @model_validator(mode="after")
    def validate_payments_cover_total(self) -> "InvoiceRequest":
        total = self.total
        paid = sum((payment.amount for payment in self.payments), Decimal("0"))
        if paid < total:
            raise ValueError("Los pagos no cubren el total de la factura.")
        return self

    @property
    def total(self) -> Decimal:
        return sum((item.line_total for item in self.items), Decimal("0"))


class ReportRequest(BaseModel):
    confirm: bool = Field(default=False, description="Confirmacion requerida para acciones fiscales sensibles.")


class CommandResponse(BaseModel):
    command: str
    frame_hex: str
    response: dict[str, str | int]


class InvoiceResponse(BaseModel):
    status: str
    total: Decimal
    dry_run: bool
    commands: list[CommandResponse] = []
    planned_commands: list[str] = []
    message: Optional[str] = None
