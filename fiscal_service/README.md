# Servicio Fiscal ACLAS PP9-PLUS

API local en Python para enviar comandos fiscales por puerto serial a una maquina fiscal ACLAS PP9-PLUS.

El servicio recibe JSON desde un sistema POS, valida los datos y traduce cada accion a comandos seriales con trama fiscal:

```text
STX + COMANDO + ETX + LRC
```

El Reporte X y la facturacion basica ya fueron probados contra la maquina en `COM8`.

## Arquitectura

```text
Sistema POS -> API FastAPI -> FiscalService -> SerialFiscalClient -> COM8 -> ACLAS PP9-PLUS
```

Archivos principales:

- `app/main.py`: endpoints HTTP.
- `app/config.py`: configuracion por variables de entorno.
- `app/aclas_protocol.py`: armado de trama `STX + comando + ETX + LRC`.
- `app/serial_client.py`: comunicacion serial con la impresora.
- `app/fiscal_service.py`: acciones fiscales, bloqueo de concurrencia y construccion de comandos.
- `app/schemas.py`: payloads y validaciones.
- `scripts/test_client.py`: cliente simple de pruebas.

## Instalacion

### Windows

```powershell
cd "c:\Users\Ricardo\Desktop\fiscal_service"
python -m pip install -r requirements.txt
```

### Linux

```bash
cd /opt/fiscal_service
python3 -m pip install -r requirements.txt
```

En Linux, el usuario que ejecuta el servicio debe tener permisos sobre el puerto serial, normalmente `/dev/ttyUSB0` o `/dev/ttyS0`:

```bash
sudo usermod -aG dialout $USER
```

Cierra sesion y vuelve a entrar para que el grupo aplique.

## Configuracion

El servicio usa variables de entorno. Valores por defecto:

```text
ACLAS_SERIAL_PORT=COM8
ACLAS_BAUDRATE=9600
ACLAS_TIMEOUT_SECONDS=2
ACLAS_COMMAND_DELAY_SECONDS=1.5
ACLAS_REPORT_X_COMMAND=I0X
ACLAS_REPORT_Z_COMMAND=
ACLAS_ENABLE_INVOICE_COMMANDS=false
```

Variables importantes:

- `ACLAS_SERIAL_PORT`: puerto serial de la maquina fiscal. En Windows suele ser `COM8`; en Linux puede ser `/dev/ttyUSB0`.
- `ACLAS_BAUDRATE`: velocidad serial. La maquina probada usa `9600`.
- `ACLAS_TIMEOUT_SECONDS`: tiempo maximo de lectura serial.
- `ACLAS_COMMAND_DELAY_SECONDS`: espera despues de enviar cada comando antes de leer respuesta.
- `ACLAS_REPORT_X_COMMAND`: comando de Reporte X. Validado: `I0X`.
- `ACLAS_REPORT_Z_COMMAND`: comando de Reporte Z. Debe configurarse solo al confirmar el comando correcto del equipo.
- `ACLAS_ENABLE_INVOICE_COMMANDS`: debe estar en `true` para imprimir facturas reales.

Ejemplo Windows:

```powershell
$env:ACLAS_SERIAL_PORT="COM8"
$env:ACLAS_ENABLE_INVOICE_COMMANDS="true"
```

Ejemplo Linux:

```bash
export ACLAS_SERIAL_PORT="/dev/ttyUSB0"
export ACLAS_ENABLE_INVOICE_COMMANDS="true"
```

## Levantar El Servicio

### Windows

```powershell
cd "c:\Users\Ricardo\Desktop\fiscal_service"
$env:ACLAS_ENABLE_INVOICE_COMMANDS="true"
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### Linux

```bash
cd /opt/fiscal_service
export ACLAS_SERIAL_PORT="/dev/ttyUSB0"
export ACLAS_ENABLE_INVOICE_COMMANDS="true"
python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

URLs utiles:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/docs`

## Seguridad

Recomendaciones operativas:

- Ejecutar el servicio solo en `127.0.0.1` si sera consumido desde la misma computadora.
- No exponer el puerto `8000` a internet.
- Si otro equipo de la red necesita consumir la API, usar firewall para permitir solo IPs autorizadas.
- Mantener `ACLAS_ENABLE_INVOICE_COMMANDS=false` en ambientes de prueba si no se quiere imprimir fiscalmente.
- Reporte Z debe requerir confirmacion y comando configurado, porque cierra la jornada fiscal.
- No enviar dos operaciones al mismo tiempo. El servicio ya usa un bloqueo interno para serializar comandos, pero el POS tambien debe evitar doble clic o reintentos agresivos.
- Registrar en el POS el payload enviado y la respuesta de la API para auditoria.
- Tratar `0x06` como `ACK` y `0x15` como `NAK` o rechazo del equipo.
- Si una factura queda abierta, completar pago/cierre antes de iniciar otra.

Ejemplo de respuesta serial:

```json
{
  "command": "199",
  "frame_hex": "02 31 39 39 03 32",
  "response": {
    "raw_hex": "06",
    "ascii": "\u0006",
    "length": 1
  }
}
```

## Endpoints

### `GET /health`

Verifica que el servicio esta vivo y muestra la configuracion activa.

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Respuesta esperada:

```json
{
  "status": "ok",
  "serial_port": "COM8",
  "baudrate": 9600,
  "timeout_seconds": 2.0,
  "report_z_configured": false,
  "invoice_commands_enabled": true
}
```

### `GET /printer/status`

Envia el comando de estado configurado, por defecto `S1`.

```powershell
Invoke-RestMethod http://127.0.0.1:8000/printer/status
```

### `POST /reports/x`

Imprime Reporte X. Este comando fue validado con `I0X`.

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/reports/x
```

Payload: no requiere body.

### `POST /reports/z`

Imprime Reporte Z. Requiere:

- `ACLAS_REPORT_Z_COMMAND` configurado.
- `confirm=true` en el payload.

```powershell
Invoke-RestMethod -Method Post http://127.0.0.1:8000/reports/z `
  -ContentType "application/json" `
  -Body '{"confirm": true}'
```

Payload:

```json
{
  "confirm": true
}
```

### `POST /invoices`

Recibe una factura y la envia a la impresora. Para imprimir realmente, debe venir con:

```json
{
  "dry_run": false
}
```

Si `dry_run` es `true`, valida y muestra los comandos planeados sin imprimir.

## Payload De Factura

Estructura general:

```json
{
  "customer": {
    "name": "Cliente de prueba",
    "document": "V-00000000",
    "address": "Direccion de prueba",
    "phone": "04140000000"
  },
  "items": [
    {
      "description": "Producto prueba",
      "quantity": "1",
      "unit_price": "1.00",
      "tax_code": "IVA_GENERAL",
      "sku": "0001",
      "discount_amount": "0"
    }
  ],
  "payments": [
    {
      "method": "cash",
      "amount": "1.16",
      "reference": "EFECTIVO"
    }
  ],
  "invoice_number": "OPCIONAL-001",
  "notes": "Comentario opcional",
  "dry_run": false
}
```

Campos de `customer`:

- `name`: razon social o nombre del cliente.
- `document`: RIF, cedula o documento fiscal.
- `address`: direccion fiscal o comercial.
- `phone`: opcional.

Campos de `items`:

- `description`: descripcion impresa del producto.
- `quantity`: cantidad vendida.
- `unit_price`: precio base del item, sin IVA cuando se usa tasa gravada.
- `tax_code`: codigo de impuesto.
- `sku`: codigo del producto.
- `discount_amount`: descuento por monto para la linea.

Valores de `tax_code`:

- `EXENTO`
- `IVA_GENERAL`
- `IVA_REDUCIDO`
- `IVA_ADICIONAL`
- `PERCIBIDO`

Campos de `payments`:

- `method`: medio de pago.
- `amount`: monto pagado.
- `reference`: referencia opcional.

Valores de `method`:

- `cash`
- `card`
- `transfer`
- `mobile_payment`
- `other`

## Ejemplo Real: Base Bs 1,00 Mas IVA

Este payload imprime una factura con base imponible `Bs 1,00`, IVA general `16%` calculado por la impresora y pago total `Bs 1,16`.

```json
{
  "customer": {
    "name": "Cliente de prueba",
    "document": "V-00000000",
    "address": "Direccion de prueba"
  },
  "items": [
    {
      "description": "Producto prueba 1Bs",
      "quantity": "1",
      "unit_price": "1.00",
      "tax_code": "IVA_GENERAL",
      "sku": "0001"
    }
  ],
  "payments": [
    {
      "method": "cash",
      "amount": "1.16"
    }
  ],
  "dry_run": false
}
```

Comando PowerShell:

```powershell
$payload = '{
  "customer": {
    "name": "Cliente de prueba",
    "document": "V-00000000",
    "address": "Direccion de prueba"
  },
  "items": [
    {
      "description": "Producto prueba 1Bs",
      "quantity": "1",
      "unit_price": "1.00",
      "tax_code": "IVA_GENERAL",
      "sku": "0001"
    }
  ],
  "payments": [
    {
      "method": "cash",
      "amount": "1.16"
    }
  ],
  "dry_run": false
}'

Invoke-RestMethod -Method Post http://127.0.0.1:8000/invoices `
  -ContentType "application/json" `
  -Body $payload
```

Comandos fiscales generados:

```text
iR*V-00000000
iS*Cliente de prueba
i01Direccion de prueba
!0000000100000010000001Producto prueba 1Bs
201000000000116
199
```

Respuesta correcta esperada:

```text
06 en cada comando
```

## Factura De Prueba Sin Imprimir

Cambiar `dry_run` a `true`:

```json
{
  "customer": {
    "name": "Cliente de prueba",
    "document": "V-00000000"
  },
  "items": [
    {
      "description": "Producto prueba 1Bs",
      "quantity": "1",
      "unit_price": "1.00",
      "tax_code": "IVA_GENERAL",
      "sku": "0001"
    }
  ],
  "payments": [
    {
      "method": "cash",
      "amount": "1.16"
    }
  ],
  "dry_run": true
}
```

## Cliente De Prueba

Con el servicio levantado:

```powershell
python scripts\test_client.py health
python scripts\test_client.py status
python scripts\test_client.py x
python scripts\test_client.py invoice-dry-run
```

## Arranque Automatico En Windows

Opcion recomendada sin instalar herramientas externas: Programador de tareas.

1. Crear un archivo `start_fiscal_service.ps1`, por ejemplo en `c:\Users\Ricardo\Desktop\fiscal_service\start_fiscal_service.ps1`.

```powershell
Set-Location "c:\Users\Ricardo\Desktop\fiscal_service"
$env:ACLAS_SERIAL_PORT="COM8"
$env:ACLAS_ENABLE_INVOICE_COMMANDS="true"
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

2. Abrir el Programador de tareas.
3. Crear tarea.
4. En `Desencadenadores`, elegir `Al iniciar sesion` o `Al iniciar el equipo`.
5. En `Acciones`, configurar:

```text
Programa: powershell.exe
Argumentos: -ExecutionPolicy Bypass -File "c:\Users\Ricardo\Desktop\fiscal_service\start_fiscal_service.ps1"
```

6. Activar `Ejecutar con los privilegios mas altos` si el puerto serial lo requiere.
7. Reiniciar y validar:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Alternativa para produccion: usar NSSM o WinSW para instalar Uvicorn como servicio de Windows. En ese caso, el comando del servicio debe apuntar a:

```text
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Y debe ejecutar dentro de:

```text
c:\Users\Ricardo\Desktop\fiscal_service
```

## Arranque Automatico En Linux

Usar `systemd`.

1. Copiar el proyecto a una ruta estable:

```bash
sudo mkdir -p /opt/fiscal_service
sudo cp -r /ruta/del/proyecto/* /opt/fiscal_service/
cd /opt/fiscal_service
python3 -m pip install -r requirements.txt
```

2. Crear el archivo de servicio:

```bash
sudo nano /etc/systemd/system/fiscal-service.service
```

Contenido:

```ini
[Unit]
Description=Servicio Fiscal ACLAS PP9-PLUS
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/fiscal_service
Environment=ACLAS_SERIAL_PORT=/dev/ttyUSB0
Environment=ACLAS_BAUDRATE=9600
Environment=ACLAS_ENABLE_INVOICE_COMMANDS=true
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5
User=ricardo

[Install]
WantedBy=multi-user.target
```

3. Activar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable fiscal-service
sudo systemctl start fiscal-service
```

4. Ver estado:

```bash
systemctl status fiscal-service
journalctl -u fiscal-service -f
curl http://127.0.0.1:8000/health
```

Si el puerto serial no abre, verificar permisos:

```bash
ls -l /dev/ttyUSB0
sudo usermod -aG dialout ricardo
```

## Solucion De Problemas

Puerto ocupado:

```powershell
Get-NetTCPConnection -LocalPort 8000 -State Listen
```

Cerrar proceso en Windows:

```powershell
$conn = Get-NetTCPConnection -LocalPort 8000 -State Listen
Stop-Process -Id $conn.OwningProcess -Force
```

Verificar si la API esta activa:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Respuesta `0x15`:

- El comando fue rechazado.
- Puede haber una factura abierta.
- Puede faltar pago suficiente.
- Puede haberse enviado una secuencia fuera de orden.

Factura queda abierta:

- Enviar el pago faltante.
- Enviar cierre `199`.
- No iniciar otra factura hasta completar la anterior.

Pago insuficiente:

- Para una base gravada `Bs 1,00` con IVA `16%`, el pago debe ser `Bs 1,16`.
- Si se quiere que el total final sea `Bs 1,00`, la base debe ser aproximadamente `Bs 0,86`.

## Nota Fiscal Importante

El comando `I0X` ya fue validado en la maquina y se usa para Reporte X.

La facturacion real tambien fue validada con una factura de base `Bs 1,00` y pago `Bs 1,16`, respondiendo `0x06` en todos los comandos.

Reporte Z debe activarse solo despues de confirmar el comando exacto de la ACLAS PP9-PLUS instalada, porque cierra la jornada fiscal.
