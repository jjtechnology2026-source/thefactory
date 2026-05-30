import argparse
import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen


BASE_URL = "http://127.0.0.1:8000"


def request_json(method: str, path: str, payload: dict | None = None) -> dict:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        f"{BASE_URL}{path}",
        data=body,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8")
        raise SystemExit(f"HTTP {exc.code}: {detail}") from exc


def main() -> None:
    parser = argparse.ArgumentParser(description="Cliente de prueba del servicio fiscal ACLAS.")
    parser.add_argument("action", choices=["health", "status", "x", "z", "invoice-dry-run"])
    args = parser.parse_args()

    if args.action == "health":
        response = request_json("GET", "/health")
    elif args.action == "status":
        response = request_json("GET", "/printer/status")
    elif args.action == "x":
        response = request_json("POST", "/reports/x", {})
    elif args.action == "z":
        response = request_json("POST", "/reports/z", {"confirm": True})
    else:
        response = request_json(
            "POST",
            "/invoices",
            {
                "customer": {
                    "name": "Cliente de prueba",
                    "document": "V-00000000",
                    "address": "Direccion de prueba",
                },
                "items": [
                    {
                        "description": "Producto prueba",
                        "quantity": "1",
                        "unit_price": "10.00",
                        "tax_code": "IVA_GENERAL",
                        "sku": "0001",
                    }
                ],
                "payments": [{"method": "cash", "amount": "10.00"}],
                "dry_run": True,
            },
        )

    print(json.dumps(response, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
