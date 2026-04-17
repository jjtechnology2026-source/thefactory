Port Dart de la SDK fiscal TFHKA Venezuela.

Incluye:

- Comunicacion serial Windows con serial_port_win32.
- API Dart para estado, reportes X/Z y consultas S1..S8.
- Capa compatible TfhkaFiscalApi inspirada en tu API previa, con COM99 por defecto.
- Parser de tramas fiscales reales capturadas del emulador.
- Pruebas unitarias del parsing.
- Validacion de consola contra el emulador en COM99.
- Examples por caso de uso en la carpeta example/.

Flujos estructurados agregados:

- `Tfhka.issueSimpleInvoiceWithNumber()` y `Tfhka.issuePersonalizedInvoiceWithNumber()` devuelven `IssuedFiscalDocumentResult` con el ultimo numero de factura tomado desde `S1`.
- `Tfhka.issueCreditNoteWithNumber()` devuelve el ultimo numero de nota de credito tomado desde `S1`.
- `Tfhka.issueNonFiscalDocument()` emite un documento no fiscal usando las secuencias `80`, `81` y `810`.
- `Tfhka.executeZReport()` devuelve `PrintedZReportResult` con `ReportData` luego de ejecutar el Z.
- `TfhkaFiscalApi` expone atajos equivalentes con `emitirFacturaSimpleConNumero()`, `emitirFacturaPersonalizadaConNumero()`, `emitirNotaCreditoConNumero()`, `emitirDocumentoNoFiscal()`, `imprimirDocumentoNoFiscal()` y `ejecutarReporteZEstructurado()`.

Uso rapido:

```powershell
dart run bin/dart_sdk.dart COM99
```

Uso compatible con la API anterior:

```dart
final api = TfhkaFiscalApi(); // usa COM99 por defecto
final opened = await api.abrirPuerto();
if (!opened) {
	print(api.obtenerMensajeError());
	print(api.obtenerTodoPendienteDocumentoNoFiscal() ?? '');
}
```

Pruebas unitarias:

```powershell
dart test
```

Chequeo de envio por archivo:

```powershell
dart run tool/send_cmd_file_check.dart COM99 ruta-al-archivo
```

Examples:

```powershell
dart run example/invoice_example.dart COM99
dart run example/notes_example.dart COM99 debit
dart run example/notes_example.dart COM99 credit
dart run example/notes_example.dart COM99 nonfiscal
dart run example/non_fiscal_example.dart COM99
```

Documento no fiscal desde la API compatible:

```dart
final api = TfhkaFiscalApi();
await api.abrirPuerto();

try {
	final result = await api.imprimirDocumentoNoFiscal(
	  const NonFiscalDocumentRequest(
	    lines: <String>[
		    'Documento no fiscal de prueba',
		    'Linea 2',
	    ],
	  ),
	);

	print(result.ok);
	print(result.processedLines);
} finally {
	api.cerrarPuerto();
}
```

Si necesitas compatibilidad con la firma anterior, `emitirDocumentoNoFiscal(List<String>)` sigue disponible y devuelve `bool`.

La matriz sugerida para validacion real de hardware esta en `MATRIZ_PRUEBAS_DOCUMENTO_NO_FISCAL.md` en la raiz del workspace.

Validado contra el emulador:

- ReadFpStatus, S1..S8, GetXReport, GetZReport, PrintXReport y sendCmdFile responden en COM99.
- GetZReport por numero y por fecha devuelve lista en el emulador usado.
- Factura simple, factura personalizada, nota de debito y reimpresion de facturas fueron aceptadas por el emulador.
- Nota de credito fue aceptada cuando se referencia una factura real del emulador.
- Documento no fiscal y factura anulada tienen comandos aceptados parcialmente, pero el emulador rechaza el cierre final con Error 89 en las pruebas realizadas.
- En el emulador probado, I0X puede responder NAK (0x15) aun cuando el comando se ejecuta; este comportamiento coincide con la libreria Python.
- Si el puerto configurado no existe, la capa compatible puede devolverte un TODO para recordar la prueba pendiente del documento no fiscal en una impresora fiscal real.
