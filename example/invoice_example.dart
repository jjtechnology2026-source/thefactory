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
    stderr.writeln(
      'Asegurese de que $exePath existe o que el servicio ya esta corriendo.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('Servicio fiscal listo.');

  try {
    await api.registrarCliente('Cliente de prueba', 'V-00000000', 'Direccion');
    await api.agregarRenglon('Producto prueba', 1, 1.0, 16);
    await api.procesarPago(const FiscalPayment.cash(amount: 1.16));
    final ok = await api.totalizarFactura();

    stdout.writeln('Factura enviada: $ok');
    if (!ok) {
      stderr.writeln(api.obtenerMensajeError());
      exitCode = 2;
    }
  } finally {
    api.cerrarPuerto();
  }
}
