import 'dart:io';

import 'package:thefactory/tfhka.dart';

Future<void> main(List<String> arguments) async {
  final portName = arguments.isNotEmpty ? arguments.first : 'COM99';
  final api = TfhkaFiscalApi(puertoPredeterminado: portName);

  stdout.writeln('Abriendo $portName ...');
  final opened = await api.abrirPuerto();
  if (!opened) {
    stderr.writeln(api.obtenerMensajeError());
    exitCode = 1;
    return;
  }

  try {
    final ok = await api.emitirDocumentoNoFiscal(const <String>[
      'Documento no fiscal de prueba',
      'Segunda linea',
    ]);

    stdout.writeln('Documento no fiscal enviado: $ok');
    if (!ok) {
      stderr.writeln(api.obtenerMensajeError());
      exitCode = 2;
    }
  } finally {
    api.cerrarPuerto();
  }
}
