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
    final ok = await api.imprimirReporteX();
    stdout.writeln('Reporte X enviado: $ok');
    if (!ok) {
      stderr.writeln(api.obtenerMensajeError());
      exitCode = 2;
    }
  } finally {
    api.cerrarPuerto();
  }
}
