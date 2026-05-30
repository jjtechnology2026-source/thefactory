import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'command_sequences.dart';
import 'report_data.dart';

// ===========================================================================
// Internal HTTP client and JSON models for the fiscal_service API
// ===========================================================================

class _FiscalServiceHttpClient {
  final String baseUrl;
  final http.Client _client;

  _FiscalServiceHttpClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<_HealthResponse> health() async {
    final response = await _client.get(Uri.parse('$baseUrl/health'));
    _checkStatus(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _HealthResponse.fromJson(json);
  }

  Future<_CommandResponse> printerStatus() async {
    final response = await _client.get(Uri.parse('$baseUrl/printer/status'));
    _checkStatus(response);
    return _CommandResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<_CommandResponse> reportX() async {
    final response = await _client.post(Uri.parse('$baseUrl/reports/x'));
    _checkStatus(response);
    return _CommandResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<_CommandResponse> reportZ({required bool confirm}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/reports/z'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'confirm': confirm}),
    );
    _checkStatus(response);
    return _CommandResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<_InvoiceResponse> createInvoice(_InvoiceRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/invoices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    _checkStatus(response);
    return _InvoiceResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw HttpException(response.statusCode, response.body);
    }
  }

  void dispose() => _client.close();
}

class HttpException implements Exception {
  final int statusCode;
  final String body;

  const HttpException(this.statusCode, this.body);

  @override
  String toString() => 'HTTP $statusCode: $body';
}

class _HealthResponse {
  final String status;

  const _HealthResponse({required this.status});

  bool get ok => status == 'ok';

  factory _HealthResponse.fromJson(Map<String, dynamic> json) =>
      _HealthResponse(status: json['status'] as String? ?? '');
}

class _CommandResponse {
  final String command;
  final String frameHex;
  final Map<String, dynamic> response;

  const _CommandResponse({
    required this.command,
    required this.frameHex,
    required this.response,
  });

  factory _CommandResponse.fromJson(Map<String, dynamic> json) =>
      _CommandResponse(
        command: json['command'] as String? ?? '',
        frameHex: json['frame_hex'] as String? ?? '',
        response: (json['response'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      );
}

enum _TaxCode { exento, ivaGeneral, ivaReducido, ivaAdicional, percibido }

enum _PaymentMethod { cash, card, transfer, mobilePayment, other }

class _Customer {
  final String name;
  final String document;
  final String? address;

  const _Customer({
    required this.name,
    required this.document,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'document': document,
        if (address != null) 'address': address,
      };
}

class _InvoiceItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final _TaxCode taxCode;
  final String? sku;

  const _InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxCode = _TaxCode.ivaGeneral,
    this.sku,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity.toString(),
        'unit_price': unitPrice.toString(),
        'tax_code': _taxCodeLabel,
        if (sku != null) 'sku': sku,
        'discount_amount': '0',
      };

  String get _taxCodeLabel => switch (taxCode) {
        _TaxCode.exento => 'EXENTO',
        _TaxCode.ivaGeneral => 'IVA_GENERAL',
        _TaxCode.ivaReducido => 'IVA_REDUCIDO',
        _TaxCode.ivaAdicional => 'IVA_ADICIONAL',
        _TaxCode.percibido => 'PERCIBIDO',
      };
}

class _Payment {
  final _PaymentMethod method;
  final double amount;
  final String? reference;

  const _Payment({
    required this.method,
    required this.amount,
    this.reference,
  });

  Map<String, dynamic> toJson() => {
        'method': _methodLabel,
        'amount': amount.toString(),
        if (reference != null) 'reference': reference,
      };

  String get _methodLabel => switch (method) {
        _PaymentMethod.cash => 'cash',
        _PaymentMethod.card => 'card',
        _PaymentMethod.transfer => 'transfer',
        _PaymentMethod.mobilePayment => 'mobile_payment',
        _PaymentMethod.other => 'other',
      };
}

class _InvoiceRequest {
  final _Customer customer;
  final List<_InvoiceItem> items;
  final List<_Payment> payments;
  final String? notes;

  const _InvoiceRequest({
    required this.customer,
    required this.items,
    required this.payments,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'customer': customer.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        if (notes != null) 'notes': notes,
        'dry_run': false,
      };
}

class _InvoiceResponse {
  final String status;
  final double total;
  final bool dryRun;
  final List<_CommandResponse> commands;
  final List<String> plannedCommands;
  final String? message;

  const _InvoiceResponse({
    required this.status,
    required this.total,
    required this.dryRun,
    this.commands = const [],
    this.plannedCommands = const [],
    this.message,
  });

  factory _InvoiceResponse.fromJson(Map<String, dynamic> json) =>
      _InvoiceResponse(
        status: json['status'] as String? ?? '',
        total: (json['total'] as num?)?.toDouble() ?? 0,
        dryRun: json['dry_run'] as bool? ?? false,
        commands: (json['commands'] as List<dynamic>?)
                ?.map((c) =>
                    _CommandResponse.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        plannedCommands: (json['planned_commands'] as List<dynamic>?)
                ?.map((c) => c as String)
                .toList() ??
            const [],
        message: json['message'] as String?,
      );
}

// ===========================================================================
// Public types — unchanged from original interface
// ===========================================================================

enum FiscalPaymentKind { cash, dollars, card, mobile, biopago }

class NonFiscalDocumentRequest {
  final List<String> lines;

  const NonFiscalDocumentRequest({required this.lines});
}

class NonFiscalDocumentResult {
  final int codigoRetorno;
  final int processedLines;

  const NonFiscalDocumentResult({
    required this.codigoRetorno,
    required this.processedLines,
  });

  int get lineasProcesadas => processedLines;
  bool get ok => codigoRetorno == 0;
}

class FiscalPayment {
  final FiscalPaymentKind kind;
  final double amount;
  final double change;
  final String? punto;
  final String? type;
  final String? reference;
  final String? bank;

  const FiscalPayment._({
    required this.kind,
    required this.amount,
    this.change = 0,
    this.punto,
    this.type,
    this.reference,
    this.bank,
  });

  const FiscalPayment.cash({required double amount, double change = 0})
      : this._(kind: FiscalPaymentKind.cash, amount: amount, change: change);

  const FiscalPayment.dollars({required double amount, double change = 0})
      : this._(
          kind: FiscalPaymentKind.dollars,
          amount: amount,
          change: change,
        );

  const FiscalPayment.card({
    required double amount,
    String? punto,
    String? type,
    String? reference,
  }) : this._(
          kind: FiscalPaymentKind.card,
          amount: amount,
          punto: punto,
          type: type,
          reference: reference,
        );

  const FiscalPayment.mobile({
    required double amount,
    String? reference,
    String? bank,
  }) : this._(
          kind: FiscalPaymentKind.mobile,
          amount: amount,
          reference: reference,
          bank: bank,
        );

  const FiscalPayment.biopago({
    required double amount,
    String? reference,
    String? bank,
  }) : this._(
          kind: FiscalPaymentKind.biopago,
          amount: amount,
          reference: reference,
          bank: bank,
        );

  String get paymentCode => switch (kind) {
        FiscalPaymentKind.cash => '01',
        FiscalPaymentKind.dollars => '20',
        FiscalPaymentKind.card => '03',
        FiscalPaymentKind.mobile => '05',
        FiscalPaymentKind.biopago => '06',
      };

  double amountForPrinter(double rate) {
    final baseAmount = amount - change;
    return baseAmount * rate;
  }

  bool get usesDollars => kind == FiscalPaymentKind.dollars;
}

// ===========================================================================
// TfhkaFiscalApi — adapter that speaks HTTP to the fiscal_service
// ===========================================================================

class TfhkaFiscalApi {
  final String puertoPredeterminado;
  final String serviceUrl;

  int ultimoError = 0;
  String? ultimoPuertoAbierto;
  final String? directorioServicioPython;

  late final _FiscalServiceHttpClient _httpClient;
  Process? _serviceProcess;
  String? _pythonCommand;

  // Invoice accumulation buffers
  String _clienteNombre = '';
  String _clienteRif = '';
  String _clienteDireccion = '';
  final List<({String descripcion, double cantidad, double precio, double iva})>
  _items = [];
  final List<({double amount, _PaymentMethod method, String? reference})>
  _payments = [];

  TfhkaFiscalApi({
    String rutaServicioFiscal = 'fiscal_service.exe',
    this.serviceUrl = 'http://127.0.0.1:8000',
    this.puertoPredeterminado = 'fiscal_service.exe',
    this.directorioServicioPython,
    http.Client? httpClient,
  }) : _httpClient = _FiscalServiceHttpClient(
          baseUrl: serviceUrl,
          client: httpClient,
        );

  // -----------------------------------------------------------------------
  // Connection lifecycle
  // -----------------------------------------------------------------------

  List<String> puertosDisponibles() {
    final disponibles = <String>[];
    if (File(puertoPredeterminado).existsSync()) {
      disponibles.add(puertoPredeterminado);
    }
    if (directorioServicioPython != null &&
        Directory(directorioServicioPython!).existsSync()) {
      disponibles.add(directorioServicioPython!);
    }
    return disponibles;
  }

  Future<bool> abrirPuerto([String? exePath]) async {
    // 1. Already running?
    try {
      final health = await _httpClient.health();
      if (health.ok) {
        ultimoPuertoAbierto = exePath ?? puertoPredeterminado;
        ultimoError = 0;
        return true;
      }
    } catch (_) {}

    // 2. Try Python source if available
    if (directorioServicioPython != null) {
      final pythonOk = await _iniciarServicioPython(
        directorioServicioPython!,
      );
      if (pythonOk) return true;
    }

    // 3. Fallback to .exe
    return _iniciarServicioExe(_resolveExe(exePath));
  }

  bool cerrarPuerto() {
    _serviceProcess?.kill();
    _serviceProcess = null;
    _pythonCommand = null;
    ultimoPuertoAbierto = null;
    ultimoError = 0;
    _clearBuffers();
    return true;
  }

  bool comprobarImpresora() {
    return _serviceProcess != null;
  }

  // -----------------------------------------------------------------------
  // Service startup helpers
  // -----------------------------------------------------------------------

  Future<bool> _detectarPython() async {
    if (_pythonCommand != null) return true;

    for (final cmd in ['python3', 'python']) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          _pythonCommand = cmd;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _iniciarServicioPython(String directorio) async {
    final pythonFound = await _detectarPython();
    if (!pythonFound) return false;

    try {
      _serviceProcess = await Process.start(
        _pythonCommand!,
        ['-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', '8000'],
        workingDirectory: directorio,
        mode: ProcessStartMode.normal,
      );
    } catch (_) {
      return false;
    }

    return _esperarHealth();
  }

  Future<bool> _iniciarServicioExe(String ruta) async {
    if (!File(ruta).existsSync()) {
      ultimoError = 128;
      return false;
    }

    try {
      _serviceProcess = await Process.start(
        ruta,
        [],
        mode: ProcessStartMode.normal,
      );
    } catch (_) {
      ultimoError = 128;
      return false;
    }

    return _esperarHealth();
  }

  Future<bool> _esperarHealth() async {
    for (var i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final health = await _httpClient.health();
        if (health.ok) {
          ultimoPuertoAbierto = puertoPredeterminado;
          ultimoError = 0;
          return true;
        }
      } catch (_) {}
    }

    _serviceProcess?.kill();
    _serviceProcess = null;
    ultimoError = 114;
    return false;
  }

  // -----------------------------------------------------------------------
  // Raw command (not exposed via HTTP API)
  // -----------------------------------------------------------------------

  Future<bool> enviarComando(String comando) async {
    ultimoError = 89;
    return false;
  }

  // -----------------------------------------------------------------------
  // Invoice building (accumulate, send on totalizarFactura)
  // -----------------------------------------------------------------------

  Future<bool> registrarCliente(
    String nombre,
    String rif,
    String direccion,
  ) async {
    _clienteNombre = sanitizarTextoFiscal(nombre);
    _clienteRif = sanitizarTextoFiscal(rif);
    _clienteDireccion = sanitizarTextoFiscal(direccion);
    return true;
  }

  Future<bool> agregarRenglon(
    String descripcion,
    double cantidad,
    double precioSinIva,
    double porcentajeIva,
  ) async {
    _items.add((
      descripcion: sanitizarTextoFiscal(descripcion),
      cantidad: cantidad,
      precio: precioSinIva,
      iva: porcentajeIva,
    ));
    return true;
  }

  Future<bool> procesarPago(FiscalPayment payment, {double rate = 1}) async {
    final method = switch (payment.kind) {
      FiscalPaymentKind.cash => _PaymentMethod.cash,
      FiscalPaymentKind.dollars => _PaymentMethod.cash,
      FiscalPaymentKind.card => _PaymentMethod.card,
      FiscalPaymentKind.mobile => _PaymentMethod.mobilePayment,
      FiscalPaymentKind.biopago => _PaymentMethod.other,
    };

    _payments.add((
      amount: payment.amountForPrinter(rate),
      method: method,
      reference: payment.reference,
    ));
    return true;
  }

  Future<bool> totalizarFactura({bool seUsoDivisas = false}) async {
    if (_items.isEmpty) {
      ultimoError = 80;
      return false;
    }

    final customer = _Customer(
      name: _clienteNombre.isNotEmpty ? _clienteNombre : 'CLIENTE',
      document: _clienteRif.isNotEmpty ? _clienteRif : 'V-00000000',
      address: _clienteDireccion.isNotEmpty ? _clienteDireccion : null,
    );

    final items = _items.map((i) {
      return _InvoiceItem(
        description: i.descripcion,
        quantity: i.cantidad,
        unitPrice: i.precio,
        taxCode: _taxCodeFromRate(i.iva),
      );
    }).toList();

    final payments = _payments.map((p) {
      return _Payment(
        method: p.method,
        amount: p.amount,
        reference: p.reference,
      );
    }).toList();

    final request = _InvoiceRequest(
      customer: customer,
      items: items,
      payments: payments,
    );

    try {
      final response = await _httpClient.createInvoice(request);
      if (response.status == 'printed') {
        ultimoError = 0;
        _clearBuffers();
        return true;
      }
      ultimoError = 89;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
    } catch (_) {
      ultimoError = 128;
    }

    _clearBuffers();
    return false;
  }

  // -----------------------------------------------------------------------
  // Cancel
  // -----------------------------------------------------------------------

  Future<bool> anularFacturaActual() async {
    ultimoError = 89;
    return false;
  }

  // -----------------------------------------------------------------------
  // Reports
  // -----------------------------------------------------------------------

  Future<bool> imprimirReporteZ() async {
    try {
      await _httpClient.reportZ(confirm: true);
      ultimoError = 0;
      return true;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
      return false;
    } catch (_) {
      ultimoError = 128;
      return false;
    }
  }

  Future<bool> imprimirReporteX() async {
    try {
      await _httpClient.reportX();
      ultimoError = 0;
      return true;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
      return false;
    } catch (_) {
      ultimoError = 128;
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // High-level invoice methods
  // -----------------------------------------------------------------------

  Future<int?> emitirFacturaSimpleConNumero() async {
    final items = [
      _InvoiceItem(
        description: 'Producto Exento',
        quantity: 1,
        unitPrice: 0.03,
        taxCode: _TaxCode.exento,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa General',
        quantity: 1,
        unitPrice: 0.05,
        taxCode: _TaxCode.ivaGeneral,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa Reducida',
        quantity: 1,
        unitPrice: 0.07,
        taxCode: _TaxCode.ivaReducido,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa Adicional',
        quantity: 1,
        unitPrice: 0.09,
        taxCode: _TaxCode.ivaAdicional,
        sku: '0000',
      ),
    ];

    const total = 0.03 + (0.05 * 1.16) + (0.07 * 1.08) + (0.09 * 1.31);

    final request = _InvoiceRequest(
      customer: const _Customer(name: 'CLIENTE', document: 'V-00000000'),
      items: items,
      payments: [
        const _Payment(method: _PaymentMethod.cash, amount: total),
      ],
      notes: 'COMENTARIO',
    );

    try {
      final response = await _httpClient.createInvoice(request);
      if (response.status == 'printed') {
        ultimoError = 0;
        return null;
      }
      ultimoError = 89;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
    } catch (_) {
      ultimoError = 128;
    }

    return null;
  }

  Future<int?> emitirFacturaPersonalizadaConNumero(
    FiscalCustomerData customer,
  ) async {
    final items = [
      _InvoiceItem(
        description: 'Producto Exento',
        quantity: 1,
        unitPrice: 0.03,
        taxCode: _TaxCode.exento,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa General',
        quantity: 1,
        unitPrice: 0.05,
        taxCode: _TaxCode.ivaGeneral,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa Reducida',
        quantity: 1,
        unitPrice: 0.07,
        taxCode: _TaxCode.ivaReducido,
        sku: '0000',
      ),
      _InvoiceItem(
        description: 'Producto Tasa Adicional',
        quantity: 1,
        unitPrice: 0.09,
        taxCode: _TaxCode.ivaAdicional,
        sku: '0000',
      ),
    ];

    const total = 0.03 + (0.05 * 1.16) + (0.07 * 1.08) + (0.09 * 1.31);

    final request = _InvoiceRequest(
      customer: _Customer(
        name: customer.name ?? 'CLIENTE',
        document: customer.rif ?? 'V-00000000',
      ),
      items: items,
      payments: [
        const _Payment(method: _PaymentMethod.cash, amount: total),
      ],
    );

    try {
      final response = await _httpClient.createInvoice(request);
      if (response.status == 'printed') {
        ultimoError = 0;
        return null;
      }
      ultimoError = 89;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
    } catch (_) {
      ultimoError = 128;
    }

    return null;
  }

  Future<int?> emitirNotaCreditoConNumero(
    FiscalCustomerData customer, {
    String comment = 'COMENTARIO NOTA DE CREDITO',
  }) async {
    ultimoError = 89;
    return null;
  }

  Future<ReportData?> ejecutarReporteZEstructurado() async {
    try {
      await _httpClient.reportZ(confirm: true);
      ultimoError = 0;
    } on HttpException catch (e) {
      ultimoError = e.statusCode;
    } catch (_) {
      ultimoError = 128;
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Non-fiscal documents (not exposed via HTTP API)
  // -----------------------------------------------------------------------

  Future<NonFiscalDocumentResult> imprimirDocumentoNoFiscal(
    NonFiscalDocumentRequest request,
  ) async {
    ultimoError = 89;
    return NonFiscalDocumentResult(
      codigoRetorno: 89,
      processedLines: request.lines.length,
    );
  }

  Future<NonFiscalDocumentResult> emitirDocumentoNoFiscalEstructurado(
    NonFiscalDocumentRequest request,
  ) =>
      imprimirDocumentoNoFiscal(request);

  Future<bool> emitirDocumentoNoFiscal(List<String> lineas) async {
    final result = await imprimirDocumentoNoFiscal(
      NonFiscalDocumentRequest(lines: lineas),
    );
    return result.ok;
  }

  // -----------------------------------------------------------------------
  // Error messages
  // -----------------------------------------------------------------------

  String obtenerMensajeError() {
    switch (ultimoError) {
      case 0:
        return 'No hay error.';
      case 400:
        return 'Solicitud invalida. Revise los datos enviados.';
      case 501:
        return 'Funcion no disponible. Verifique la configuracion del servicio fiscal.';
      case 503:
        return 'Impresora fiscal no disponible. Verifique la conexion serial.';
      case 80:
        return 'Comando invalido o valor invalido.';
      case 84:
        return 'Tasa invalida.';
      case 89:
        return 'Operacion no soportada por el servicio fiscal ACLAS.';
      case 96:
        return 'Error fiscal.';
      case 100:
        return 'Error de la memoria fiscal.';
      case 108:
        return 'Memoria fiscal llena.';
      case 112:
        return 'Buffer completo.';
      case 114:
        return 'El servicio fiscal no responde. Verifique que el .exe este corriendo.';
      case 128:
        return 'Error en la comunicacion con el servicio fiscal.';
      case 137:
        return 'No hay respuesta del servicio fiscal.';
      default:
        return 'Error del servicio fiscal (HTTP $ultimoError)';
    }
  }

  // -----------------------------------------------------------------------
  // Pending non-fiscal check
  // -----------------------------------------------------------------------

  String? obtenerTodoPendienteDocumentoNoFiscal({String? exePath}) {
    final ruta = _resolveExe(exePath);
    if (!File(ruta).existsSync()) {
      return 'TODO: verifique que el servicio fiscal ($ruta) este disponible.';
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Static utilities — unchanged
  // -----------------------------------------------------------------------

  static String sanitizarTextoFiscal(String value) {
    const replacements = <String, String>{
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'ñ': 'n', 'Ñ': 'N',
    };

    var sanitized = value;
    replacements.forEach((key, replacement) {
      sanitized = sanitized.replaceAll(key, replacement);
    });
    return sanitized;
  }

  static String construirComandoRenglon(
    String descripcion,
    double cantidad,
    double precioSinIva,
    double porcentajeIva,
  ) {
    final tasaChar = switch (porcentajeIva) {
      0.0 => ' ',
      16.0 => '!',
      8.0 => '"',
      31.0 => '#',
      _ => '!',
    };

    final priceString =
        (precioSinIva * 100).toStringAsFixed(0).padLeft(10, '0');
    final quantityString =
        (cantidad * 1000).toStringAsFixed(0).padLeft(8, '0');
    final description = _truncate(sanitizarTextoFiscal(descripcion), 40);
    return '$tasaChar$priceString$quantityString$description';
  }

  // -----------------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------------

  String _resolveExe(String? exePath) {
    if (exePath != null && exePath.trim().isNotEmpty) {
      return exePath.trim();
    }
    return puertoPredeterminado;
  }

  void _clearBuffers() {
    _clienteNombre = '';
    _clienteRif = '';
    _clienteDireccion = '';
    _items.clear();
    _payments.clear();
  }

  static _TaxCode _taxCodeFromRate(double rate) {
    return switch (rate) {
      0.0 => _TaxCode.exento,
      16.0 => _TaxCode.ivaGeneral,
      8.0 => _TaxCode.ivaReducido,
      31.0 => _TaxCode.ivaAdicional,
      _ => _TaxCode.ivaGeneral,
    };
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value.trim();
    }
    return value.substring(0, maxLength).trim();
  }
}
