import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:thefactory/tfhka.dart';

http.Client _mockClient(Map<String, dynamic> Function(String path, String? body)? handler) {
  return MockClient((request) async {
    if (handler == null) {
      return http.Response('Not found', 404);
    }
    final body = request.body.isNotEmpty ? request.body : null;
    final result = handler(request.url.path, body);
    return http.Response(jsonEncode(result['body']), result['status'] as int);
  });
}

Map<String, dynamic> _commandOk(String path, String? body) {
  return {
    'status': 200,
    'body': {
      'command': 'S1',
      'frame_hex': '02 53 31 03 52',
      'response': {'raw_hex': '06', 'ascii': '\u0006', 'length': 1},
    },
  };
}

Map<String, dynamic> _invoiceOk(String path, String? body) {
  return {
    'status': 200,
    'body': {
      'status': 'printed',
      'total': 1.16,
      'dry_run': false,
      'commands': [],
      'planned_commands': [],
    },
  };
}

Map<String, dynamic> _healthError(String path, String? body) {
  return {
    'status': 503,
    'body': {'detail': 'Service unavailable'},
  };
}

void main() {
  group('TfhkaFiscalApi static utilities', () {
    test('sanitiza acentos y enes', () {
      final value = TfhkaFiscalApi.sanitizarTextoFiscal('Informacion Nunez');
      expect(value, 'Informacion Nunez');
    });

    test('sanitiza acentos y enes con caracteres reales', () {
      final value = TfhkaFiscalApi.sanitizarTextoFiscal('Informacion Nunez');
      expect(value, contains('Informacion'));
      expect(value, contains('Nunez'));
    });

    test('construye renglon fiscal con formato esperado', () {
      final command = TfhkaFiscalApi.construirComandoRenglon(
        'Producto con aeiou',
        2,
        15.5,
        16,
      );
      expect(command.startsWith('!000000155000002000'), isTrue);
      expect(command, contains('Producto con aeiou'));
    });

    test('construye renglon para cada tasa de IVA', () {
      expect(
        TfhkaFiscalApi.construirComandoRenglon('E', 1, 1, 0).startsWith(' '),
        isTrue,
      );
      expect(
        TfhkaFiscalApi.construirComandoRenglon('G', 1, 1, 16).startsWith('!'),
        isTrue,
      );
      expect(
        TfhkaFiscalApi.construirComandoRenglon('R', 1, 1, 8).startsWith('"'),
        isTrue,
      );
      expect(
        TfhkaFiscalApi.construirComandoRenglon('A', 1, 1, 31).startsWith('#'),
        isTrue,
      );
    });
  });

  group('FiscalPayment', () {
    test('procesa codigos de pago esperados', () {
      expect(const FiscalPayment.cash(amount: 10).paymentCode, '01');
      expect(const FiscalPayment.dollars(amount: 10).paymentCode, '20');
      expect(const FiscalPayment.card(amount: 10).paymentCode, '03');
      expect(const FiscalPayment.mobile(amount: 10).paymentCode, '05');
      expect(const FiscalPayment.biopago(amount: 10).paymentCode, '06');
    });

    test('usesDollars flag', () {
      expect(const FiscalPayment.dollars(amount: 10).usesDollars, isTrue);
      expect(const FiscalPayment.cash(amount: 10).usesDollars, isFalse);
    });

    test('amountForPrinter aplica rate y descuenta cambio', () {
      const payment = FiscalPayment.cash(amount: 10, change: 2);
      expect(payment.amountForPrinter(1), 8.0);
      expect(payment.amountForPrinter(2), 16.0);
    });
  });

  group('NonFiscalDocumentResult', () {
    test('ok es true cuando codigoRetorno es 0', () {
      const result = NonFiscalDocumentResult(
        codigoRetorno: 0,
        processedLines: 5,
      );
      expect(result.ok, isTrue);
      expect(result.lineasProcesadas, 5);
    });

    test('ok es false cuando codigoRetorno no es 0', () {
      const result = NonFiscalDocumentResult(
        codigoRetorno: 89,
        processedLines: 3,
      );
      expect(result.ok, isFalse);
    });
  });

  group('TfhkaFiscalApi error messages', () {
    test('mensajes de error segun codigo', () {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      api.ultimoError = 0;
      expect(api.obtenerMensajeError(), 'No hay error.');

      api.ultimoError = 128;
      expect(
        api.obtenerMensajeError(),
        contains('comunicacion'),
      );

      api.ultimoError = 400;
      expect(api.obtenerMensajeError(), contains('invalida'));

      api.ultimoError = 503;
      expect(api.obtenerMensajeError(), contains('disponible'));

      api.ultimoError = 501;
      expect(api.obtenerMensajeError(), contains('disponible'));

      api.ultimoError = 89;
      expect(api.obtenerMensajeError(), contains('soportada'));

      api.ultimoError = 999;
      expect(api.obtenerMensajeError(), contains('HTTP 999'));
    });
  });

  group('TfhkaFiscalApi HTTP commands', () {
    test('imprimirReporteX con respuesta exitosa', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_commandOk));
      final ok = await api.imprimirReporteX();
      expect(ok, isTrue);
      expect(api.ultimoError, 0);
    });

    test('imprimirReporteZ con respuesta exitosa', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_commandOk));
      final ok = await api.imprimirReporteZ();
      expect(ok, isTrue);
      expect(api.ultimoError, 0);
    });

    test('imprimirReporteX con error HTTP', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_healthError));
      final ok = await api.imprimirReporteX();
      expect(ok, isFalse);
      expect(api.ultimoError, 503);
    });

    test('imprimirReporteZ con error HTTP', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_healthError));
      final ok = await api.imprimirReporteZ();
      expect(ok, isFalse);
      expect(api.ultimoError, 503);
    });

    test('comprobarImpresora retorna false sin proceso', () {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      expect(api.comprobarImpresora(), isFalse);
    });

    test('cerrarPuerto limpia estado', () {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      api.ultimoPuertoAbierto = 'test.exe';
      api.ultimoError = 89;
      final closed = api.cerrarPuerto();
      expect(closed, isTrue);
      expect(api.ultimoError, 0);
      expect(api.ultimoPuertoAbierto, isNull);
    });
  });

  group('TfhkaFiscalApi invoice flow', () {
    test('totalizarFactura envia invoice correctamente', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_invoiceOk));
      await api.registrarCliente('CLIENTE', 'V-00000000', 'DIRECCION');
      await api.agregarRenglon('Producto', 1, 1.0, 16);
      await api.procesarPago(const FiscalPayment.cash(amount: 1.16));
      final ok = await api.totalizarFactura();
      expect(ok, isTrue);
      expect(api.ultimoError, 0);
    });

    test('totalizarFactura falla sin items', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_invoiceOk));
      final ok = await api.totalizarFactura();
      expect(ok, isFalse);
      expect(api.ultimoError, 80);
    });

    test('totalizarFactura maneja error HTTP', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_healthError));
      await api.agregarRenglon('Producto', 1, 1.0, 16);
      await api.procesarPago(const FiscalPayment.cash(amount: 1.16));
      final ok = await api.totalizarFactura();
      expect(ok, isFalse);
      expect(api.ultimoError, 503);
    });
  });

  group('TfhkaFiscalApi high-level invoice methods', () {
    test('emitirFacturaSimpleConNumero retorna null con exito', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_invoiceOk));
      final number = await api.emitirFacturaSimpleConNumero();
      expect(number, isNull);
      expect(api.ultimoError, 0);
    });

    test('emitirFacturaSimpleConNumero maneja error HTTP', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_healthError));
      final number = await api.emitirFacturaSimpleConNumero();
      expect(number, isNull);
      expect(api.ultimoError, 503);
    });

    test('emitirFacturaPersonalizadaConNumero retorna null con exito', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_invoiceOk));
      const customer = FiscalCustomerData(
        rif: 'J-12345678',
        name: 'Pedro Perez',
      );
      final number = await api.emitirFacturaPersonalizadaConNumero(customer);
      expect(number, isNull);
      expect(api.ultimoError, 0);
    });

    test('ejecutarReporteZEstructurado retorna null', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(_commandOk));
      final report = await api.ejecutarReporteZEstructurado();
      expect(report, isNull);
      expect(api.ultimoError, 0);
    });
  });

  group('TfhkaFiscalApi unimplemented operations', () {
    test('enviarComando notifica no soportado', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final ok = await api.enviarComando('S1');
      expect(ok, isFalse);
      expect(api.ultimoError, 89);
    });

    test('anularFacturaActual notifica no soportado', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final ok = await api.anularFacturaActual();
      expect(ok, isFalse);
      expect(api.ultimoError, 89);
    });

    test('emitirNotaCreditoConNumero notifica no soportado', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final number = await api.emitirNotaCreditoConNumero(
        const FiscalCustomerData(),
      );
      expect(number, isNull);
      expect(api.ultimoError, 89);
    });

    test('imprimirDocumentoNoFiscal retorna error', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final result = await api.imprimirDocumentoNoFiscal(
        const NonFiscalDocumentRequest(lines: ['Linea 1']),
      );
      expect(result.ok, isFalse);
      expect(result.codigoRetorno, 89);
    });

    test('emitirDocumentoNoFiscal retorna false', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final ok = await api.emitirDocumentoNoFiscal(['Linea 1']);
      expect(ok, isFalse);
    });

    test('emitirDocumentoNoFiscalEstructurado retorna error', () async {
      final api = TfhkaFiscalApi(httpClient: _mockClient(null));
      final result = await api.emitirDocumentoNoFiscalEstructurado(
        const NonFiscalDocumentRequest(lines: ['Linea 1']),
      );
      expect(result.ok, isFalse);
    });
  });
}
