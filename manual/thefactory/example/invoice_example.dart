import 'dart:io';

import 'package:serial_port_win32/serial_port_win32.dart';
import 'package:thefactory/tfhka.dart';
import 'package:win32/win32.dart';

Future<void> main(List<String> arguments) async {
  final portName = arguments.isNotEmpty ? arguments.first : 'COM99';

  final printer = Tfhka();

  stdout.writeln('Puertos disponibles: ${SerialPort.getAvailablePorts()}');
  stdout.writeln('Conectando $portName ...');
  final opened = await _openPrinterAuto(printer, portName);
  if (!opened) {
    stderr.writeln(
      'No se encontro una combinacion puerto/configuracion que acepte escritura fiscal.',
    );
    stderr.writeln('Ultimo detalle: ${printer.envio}');
    exitCode = 1;
    return;
  }

  try {
    const commands = <String>[
      ' 000000030000001000Producto Exento',
      '!000000050000001000Producto Tasa General',
      '3',
      '101',
    ];
    for (var index = 0; index < commands.length; index++) {
      final command = commands[index];
      final result = await printer.sendCmd(command);
      final ok = result is bool
          ? result
          : (result is String && result == String.fromCharCode(0x06));
      stdout.writeln(
        '[${(index + 1).toString().padLeft(2, '0')}] $command -> $ok',
      );
      if (!ok) {
        stderr.writeln('La factura fue rechazada por el emulador.');
        stderr.writeln('Comando fallido: $command');
        stderr.writeln('Detalle impresora: ${printer.envio}');
        exitCode = 2;
        return;
      }
    }

    stdout.writeln('Factura enviada correctamente.');
  } finally {
    printer.closeFpctrl();
  }
}

Future<bool> _openPrinterAuto(Tfhka printer, String preferredPort) async {
  final ports = SerialPort.getAvailablePorts();
  if (ports.isEmpty) {
    return false;
  }

  final orderedPorts = <String>[preferredPort, ...ports]
      .map((port) => port.trim())
      .where((port) => port.isNotEmpty)
      .toSet()
      .toList();

  const configs = <({int baudRate, int parity, String name})>[
    (baudRate: CBR_9600, parity: EVENPARITY, name: '9600-E'),
    (baudRate: CBR_9600, parity: NOPARITY, name: '9600-N'),
    (baudRate: CBR_19200, parity: EVENPARITY, name: '19200-E'),
    (baudRate: CBR_19200, parity: NOPARITY, name: '19200-N'),
    (baudRate: CBR_115200, parity: NOPARITY, name: '115200-N'),
  ];

  for (final port in orderedPorts) {
    for (final cfg in configs) {
      final opened = await printer.openFpctrl(
        port,
        baudRate: cfg.baudRate,
        parity: cfg.parity,
      );
      if (!opened) {
        continue;
      }

      final probe = await printer.sendCmd('7');
      final accepted = probe is bool
          ? probe
          : (probe is String && probe == String.fromCharCode(0x06));
      if (accepted) {
        stdout.writeln('Conectado en $port con ${cfg.name}.');
        return true;
      }

      printer.closeFpctrl();
    }
  }

  return false;
}
