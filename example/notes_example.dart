import 'dart:io';

import 'package:thefactory/tfhka.dart';

Future<void> main(List<String> arguments) async {
  final exePath =
      arguments.isNotEmpty ? arguments.first : 'fiscal_service.exe';

  stdout.writeln('Usando servicio fiscal: $exePath');
  final api = TfhkaFiscalApi(puertoPredeterminado: exePath);

  stdout.writeln('Iniciando servicio fiscal ...');
  final opened = await api.abrirPuerto();
  if (!opened) {
    stderr.writeln(api.obtenerMensajeError());
    exitCode = 1;
    return;
  }

  stdout.writeln('Servicio fiscal listo.');

  try {
    final number = await api.emitirFacturaSimpleConNumero();
    stdout.writeln('Factura simple enviada.');
    if (number != null) {
      stdout.writeln('Numero de factura: $number');
    }
  } finally {
    api.cerrarPuerto();
  }
}
