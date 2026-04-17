import 'package:thefactory/tfhka.dart';
import 'package:test/test.dart';

class _FakeTfhka extends Tfhka {
  final bool closeResult;
  final String envioValue;

  _FakeTfhka({required this.closeResult, required this.envioValue});

  @override
  bool closeFpctrl() {
    envio = envioValue;
    return closeResult;
  }
}

class _FakeCommandTfhka extends Tfhka {
  final dynamic response;
  final String envioValue;
  final bool open;

  _FakeCommandTfhka({
    required this.response,
    this.envioValue = 'Status: 00  Error: 89',
    this.open = true,
  });

  @override
  bool get isOpen => open;

  @override
  Future<dynamic> sendCmd(String cmd) async {
    envio = envioValue;
    return response;
  }
}

class _FakeDocumentTfhka extends Tfhka {
  _FakeDocumentTfhka({
    this.commandsOk = true,
    S1PrinterData? s1Data,
    this.zPrintResponse = 'RESPUESTA Z',
    this.zReport,
  }) : s1Data = s1Data ?? S1PrinterData();

  final bool commandsOk;
  final S1PrinterData s1Data;
  final String? zPrintResponse;
  final ReportData? zReport;
  List<String> nonFiscalLines = const <String>[];

  @override
  Future<bool> sendCommandsSuccessful(Iterable<String> commands) async {
    return commandsOk;
  }

  @override
  Future<S1PrinterData> getS1PrinterData() async => s1Data;

  @override
  Future<bool> issueNonFiscalDocument(List<String> lines) async {
    nonFiscalLines = lines;
    return commandsOk;
  }

  @override
  Future<String?> printZReport() async => zPrintResponse;

  @override
  Future<dynamic> getZReport({
    String? mode,
    Object? startParam,
    Object? endParam,
  }) async {
    return zReport;
  }
}

void main() {
  group('TfhkaFiscalApi', () {
    test('sanitiza acentos y eñes', () {
      final value = TfhkaFiscalApi.sanitizarTextoFiscal('Información Núñez');
      expect(value, 'Informacion Nunez');
    });

    test('construye renglon fiscal con formato esperado', () {
      final command = TfhkaFiscalApi.construirComandoRenglon(
        'Producto con áéíóú',
        2,
        15.5,
        16,
      );
      expect(command.startsWith('!000000155000002000'), isTrue);
      expect(command, contains('Producto con aeiou'));
    });

    test('usa COM99 por defecto y genera TODO si el puerto no existe', () {
      final api = TfhkaFiscalApi(puertoPredeterminado: 'COM404');
      final todo = api.obtenerTodoPendienteDocumentoNoFiscal();
      expect(todo, contains('TODO: probar la impresora fiscal'));
      expect(todo, contains('COM404'));
    });

    test('procesa codigos de pago esperados', () {
      expect(const FiscalPayment.cash(amount: 10).paymentCode, '01');
      expect(const FiscalPayment.dollars(amount: 10).paymentCode, '20');
      expect(const FiscalPayment.card(amount: 10).paymentCode, '03');
      expect(const FiscalPayment.mobile(amount: 10).paymentCode, '05');
      expect(const FiscalPayment.biopago(amount: 10).paymentCode, '06');
    });

    test('notifica error cuando falla cerrar puerto', () {
      final printer = _FakeTfhka(
        closeResult: false,
        envioValue: 'Error al cerrar',
      );
      final api = TfhkaFiscalApi(printer: printer);
      api.ultimoPuertoAbierto = 'COM99';

      final closed = api.cerrarPuerto();

      expect(closed, isFalse);
      expect(api.ultimoError, 128);
      expect(api.ultimoPuertoAbierto, 'COM99');
    });

    test('limpia estado cuando cierra puerto correctamente', () {
      final printer = _FakeTfhka(
        closeResult: true,
        envioValue: 'Status: 00  Error: 00',
      );
      final api = TfhkaFiscalApi(printer: printer);
      api.ultimoPuertoAbierto = 'COM99';
      api.ultimoError = 89;

      final closed = api.cerrarPuerto();

      expect(closed, isTrue);
      expect(api.ultimoError, 0);
      expect(api.ultimoPuertoAbierto, isNull);
    });

    test('acepta respuesta de reporte aunque no sea ACK', () async {
      final printer = _FakeCommandTfhka(response: String.fromCharCode(0x15));
      final api = TfhkaFiscalApi(printer: printer);

      final ok = await api.imprimirReporteX();

      expect(ok, isTrue);
      expect(api.ultimoError, 0);
    });

    test('mantiene validacion estricta para comandos regulares', () async {
      final printer = _FakeCommandTfhka(response: String.fromCharCode(0x15));
      final api = TfhkaFiscalApi(printer: printer);

      final ok = await api.enviarComando('3');

      expect(ok, isFalse);
      expect(api.ultimoError, 89);
    });

    test(
      'issueSimpleInvoiceWithNumber devuelve ultimo numero de factura',
      () async {
        final s1 = S1PrinterData()..lastInvoiceNumber = 321;
        final printer = _FakeDocumentTfhka(s1Data: s1);

        final result = await printer.issueSimpleInvoiceWithNumber();

        expect(result.ok, isTrue);
        expect(result.number, 321);
        expect(result.printerData, same(s1));
      },
    );

    test('issueCreditNoteWithNumber devuelve ultimo numero de nota', () async {
      final s1 = S1PrinterData()..lastNCNumber = 45;
      final printer = _FakeDocumentTfhka(s1Data: s1);

      final result = await printer.issueCreditNoteWithNumber(
        const FiscalCustomerData(),
      );

      expect(result.ok, isTrue);
      expect(result.number, 45);
    });

    test('executeZReport devuelve ReportData estructurado', () async {
      final report = ReportData()
        ..numberOfLastZReport = 176
        ..numberOfLastInvoice = 837;
      final printer = _FakeDocumentTfhka(zReport: report);

      final result = await printer.executeZReport();

      expect(result.ok, isTrue);
      expect(result.report, same(report));
      expect(result.report?.numberOfLastInvoice, 837);
    });

    test('api expone numero de factura y reporte Z estructurado', () async {
      final s1 = S1PrinterData()..lastInvoiceNumber = 654;
      final report = ReportData()..numberOfLastInvoice = 654;
      final printer = _FakeDocumentTfhka(s1Data: s1, zReport: report);
      final api = TfhkaFiscalApi(printer: printer);

      final invoiceNumber = await api.emitirFacturaSimpleConNumero();
      final zReport = await api.ejecutarReporteZEstructurado();

      expect(invoiceNumber, 654);
      expect(zReport, same(report));
      expect(api.ultimoError, 0);
    });

    test('api expone documento no fiscal sanitizado', () async {
      final printer = _FakeDocumentTfhka();
      final api = TfhkaFiscalApi(printer: printer);

      final ok = await api.emitirDocumentoNoFiscal(const <String>[
        'Documento no fiscal de prueba',
        'Línea con acento',
      ]);

      expect(ok, isTrue);
      expect(api.ultimoError, 0);
      expect(printer.nonFiscalLines, <String>[
        'Documento no fiscal de prueba',
        'Linea con acento',
      ]);
    });

    test('api expone resultado estructurado no fiscal', () async {
      final printer = _FakeDocumentTfhka();
      final api = TfhkaFiscalApi(printer: printer);

      final result = await api.imprimirDocumentoNoFiscal(
        const NonFiscalDocumentRequest(lines: <String>['Linea 1', 'Linea 2']),
      );

      expect(result.ok, isTrue);
      expect(result.codigoRetorno, 0);
      expect(result.processedLines, 2);
    });
  });
}
