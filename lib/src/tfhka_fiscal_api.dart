import 'package:serial_port_win32/serial_port_win32.dart';

import 'command_sequences.dart';
import 'report_data.dart';
import 'tfhka.dart';

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
    : this._(kind: FiscalPaymentKind.dollars, amount: amount, change: change);

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

class TfhkaFiscalApi {
  final Tfhka _printer;
  final String puertoPredeterminado;
  int ultimoError = 0;
  String? ultimoPuertoAbierto;

  TfhkaFiscalApi({Tfhka? printer, this.puertoPredeterminado = 'COM99'})
    : _printer = printer ?? Tfhka();

  List<String> puertosDisponibles() => SerialPort.getAvailablePorts();

  Future<bool> abrirPuerto([String? puerto]) async {
    final puertoObjetivo = _resolvePort(puerto);
    final opened = await _printer.openFpctrl(puertoObjetivo);
    if (opened) {
      ultimoPuertoAbierto = puertoObjetivo;
      ultimoError = 0;
      return true;
    }
    ultimoError = 128;
    return false;
  }

  bool cerrarPuerto() {
    final closed = _printer.closeFpctrl();
    if (closed) {
      ultimoPuertoAbierto = null;
      ultimoError = 0;
      return true;
    }

    _syncErrorFromPrinter(fallbackError: 128);
    return false;
  }

  bool comprobarImpresora() => _printer.isOpen;

  Future<bool> enviarComando(String comando) async {
    if (!comprobarImpresora()) {
      ultimoError = 128;
      return false;
    }

    final limpio = sanitizarTextoFiscal(comando);
    final result = await _printer.sendCmd(limpio);
    if (result is bool) {
      if (result) {
        ultimoError = 0;
        return true;
      }
      _syncErrorFromPrinter();
      return false;
    }

    if (result is String) {
      final ok =
          result == String.fromCharCode(0x06) ||
          (_esComandoReporteImpresion(limpio) && result.isNotEmpty);
      if (ok) {
        ultimoError = 0;
        return true;
      }
      _syncErrorFromPrinter();
      return false;
    }

    _syncErrorFromPrinter();
    return false;
  }

  Future<bool> registrarCliente(
    String nombre,
    String rif,
    String direccion,
  ) async {
    var ok = true;
    if (nombre.isNotEmpty) {
      ok = await enviarComando(
        'iS*${_truncate(sanitizarTextoFiscal(nombre), 40)}',
      );
    }
    if (ok && rif.isNotEmpty) {
      ok = await enviarComando(
        'iR*${_truncate(sanitizarTextoFiscal(rif), 15)}',
      );
    }
    if (ok && direccion.isNotEmpty) {
      ok = await enviarComando(
        'i00${_truncate(sanitizarTextoFiscal(direccion), 40)}',
      );
    }
    return ok;
  }

  Future<bool> agregarRenglon(
    String descripcion,
    double cantidad,
    double precioSinIva,
    double porcentajeIva,
  ) async {
    return enviarComando(
      construirComandoRenglon(
        descripcion,
        cantidad,
        precioSinIva,
        porcentajeIva,
      ),
    );
  }

  Future<bool> procesarPago(FiscalPayment payment, {double rate = 1}) async {
    final amount = payment.amountForPrinter(rate);
    final amountString = (amount * 100).toStringAsFixed(0).padLeft(12, '0');
    return enviarComando('2${payment.paymentCode}$amountString');
  }

  Future<bool> totalizarFactura({bool seUsoDivisas = false}) async {
    if (seUsoDivisas) {
      return enviarComando('199');
    }
    return enviarComando('101000000000000');
  }

  Future<bool> anularFacturaActual() async => enviarComando('7');

  Future<bool> imprimirReporteZ() async => enviarComando('I0Z');

  Future<bool> imprimirReporteX() async => enviarComando('I0X');

  Future<int?> emitirFacturaSimpleConNumero() async {
    final result = await _printer.issueSimpleInvoiceWithNumber();
    if (result.ok) {
      ultimoError = 0;
      return result.number;
    }

    _syncErrorFromPrinter();
    return null;
  }

  Future<int?> emitirFacturaPersonalizadaConNumero(
    FiscalCustomerData customer,
  ) async {
    final result = await _printer.issuePersonalizedInvoiceWithNumber(customer);
    if (result.ok) {
      ultimoError = 0;
      return result.number;
    }

    _syncErrorFromPrinter();
    return null;
  }

  Future<int?> emitirNotaCreditoConNumero(
    FiscalCustomerData customer, {
    String comment = 'COMENTARIO NOTA DE CREDITO',
  }) async {
    final result = await _printer.issueCreditNoteWithNumber(
      customer,
      comment: comment,
    );
    if (result.ok) {
      ultimoError = 0;
      return result.number;
    }

    _syncErrorFromPrinter();
    return null;
  }

  Future<ReportData?> ejecutarReporteZEstructurado() async {
    final result = await _printer.executeZReport();
    if (result.report != null) {
      ultimoError = 0;
      return result.report;
    }

    _syncErrorFromPrinter(fallbackError: 137);
    return null;
  }

  Future<NonFiscalDocumentResult> imprimirDocumentoNoFiscal(
    NonFiscalDocumentRequest request,
  ) async {
    final lineasNormalizadas = request.lines
        .map((linea) => _truncate(sanitizarTextoFiscal(linea.trim()), 40))
        .where((linea) => linea.isNotEmpty)
        .toList(growable: false);

    final ok = await _printer.issueNonFiscalDocument(lineasNormalizadas);
    if (ok) {
      ultimoError = 0;
      return NonFiscalDocumentResult(
        codigoRetorno: 0,
        processedLines: lineasNormalizadas.length,
      );
    }

    _syncErrorFromPrinter();
    return NonFiscalDocumentResult(
      codigoRetorno: ultimoError,
      processedLines: lineasNormalizadas.length,
    );
  }

  Future<NonFiscalDocumentResult> emitirDocumentoNoFiscalEstructurado(
    NonFiscalDocumentRequest request,
  ) => imprimirDocumentoNoFiscal(request);

  Future<bool> emitirDocumentoNoFiscal(List<String> lineas) async {
    final result = await imprimirDocumentoNoFiscal(
      NonFiscalDocumentRequest(lines: lineas),
    );
    return result.ok;
  }

  String obtenerMensajeError() {
    switch (ultimoError) {
      case 0:
        return 'No hay error.';
      case 1:
        return 'Fin en la entrega de papel.';
      case 2:
        return 'Error mecanico en la entrega de papel.';
      case 3:
        return 'Fin en papel y error mecanico.';
      case 80:
        return 'Comando invalido o valor invalido.';
      case 84:
        return 'Tasa invalida.';
      case 89:
        return 'Comando rechazado por la impresora o emulador.';
      case 96:
        return 'Error fiscal.';
      case 100:
        return 'Error de la memoria fiscal.';
      case 108:
        return 'Memoria fiscal llena.';
      case 112:
        return 'Buffer completo.';
      case 114:
        return 'Impresora no responde o esta ocupada.';
      case 128:
        return 'Error en la comunicacion.';
      case 137:
        return 'No hay respuesta.';
      case 144:
        return 'Error LRC.';
      default:
        return 'Error desconocido (Codigo Decimal: $ultimoError)';
    }
  }

  String? obtenerTodoPendienteDocumentoNoFiscal({String? puerto}) {
    final puertoObjetivo = _resolvePort(puerto);
    if (!puertosDisponibles().contains(puertoObjetivo)) {
      return 'TODO: probar la impresora fiscal con un documento no fiscal cuando el puerto $puertoObjetivo este disponible.';
    }
    return null;
  }

  static String sanitizarTextoFiscal(String value) {
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'ñ': 'n',
      'Ñ': 'N',
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

    final priceString = (precioSinIva * 100)
        .toStringAsFixed(0)
        .padLeft(10, '0');
    final quantityString = (cantidad * 1000).toStringAsFixed(0).padLeft(8, '0');
    final description = _truncate(sanitizarTextoFiscal(descripcion), 40);
    return '$tasaChar$priceString$quantityString$description';
  }

  String _resolvePort(String? puerto) {
    if (puerto != null && puerto.trim().isNotEmpty) {
      return puerto.trim();
    }
    return puertoPredeterminado;
  }

  void _syncErrorFromPrinter({int fallbackError = 89}) {
    final match = RegExp(r'Error:\s*(\d+)').firstMatch(_printer.envio);
    if (match != null) {
      ultimoError = int.tryParse(match.group(1) ?? '') ?? fallbackError;
      return;
    }
    ultimoError = fallbackError;
  }

  static bool _esComandoReporteImpresion(String comando) {
    return comando == 'I0X' ||
        comando == 'I1X' ||
        comando == 'I0Z' ||
        comando == 'I1Z';
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value.trim();
    }
    return value.substring(0, maxLength).trim();
  }
}
