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
  });
}
