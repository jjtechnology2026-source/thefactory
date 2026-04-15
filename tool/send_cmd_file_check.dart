import 'dart:io';

import 'package:thefactory/tfhka.dart';

Future<void> main(List<String> arguments) async {
  final portName = arguments.isNotEmpty ? arguments[0] : 'COM99';
  final commandFile = arguments.length > 1 ? arguments[1] : '';

  if (commandFile.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/send_cmd_file_check.dart COM99 ruta-al-archivo',
    );
    exitCode = 1;
    return;
  }

  final printer = Tfhka();
  final opened = await printer.openFpctrl(portName);
  if (!opened) {
    stderr.writeln('No se pudo abrir $portName: ${printer.envio}');
    exitCode = 2;
    return;
  }

  try {
    await printer.sendCmdFile(commandFile);
    stdout.writeln('sendCmdFile OK');
  } finally {
    printer.closeFpctrl();
  }
}
