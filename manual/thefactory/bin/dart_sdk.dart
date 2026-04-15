import 'dart:io';

import 'package:thefactory/tfhka.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

Future<void> main(List<String> arguments) async {
  final portName = arguments.isNotEmpty ? arguments.first : 'COM99';
  final printer = Tfhka();

  stdout.writeln('Puertos disponibles: ${SerialPort.getAvailablePorts()}');
  stdout.writeln('Abriendo $portName ...');

  final opened = await printer.openFpctrl(portName);
  if (!opened) {
    stderr.writeln('No se pudo abrir $portName: ${printer.envio}');
    exitCode = 1;
    return;
  }

  try {
    final status = await printer.readFpStatus();
    stdout.writeln('status=$status');
    if (!status.contains('Sin error')) {
      stderr.writeln('La impresora no reporto estado sano');
      exitCode = 2;
      return;
    }

    final s1 = await printer.getS1PrinterData();
    stdout.writeln(
      'S1 rif=${s1.rif} machine=${s1.registeredMachineNumber} date=${s1.currentPrinterDate} time=${s1.currentPrinterTime}',
    );

    final s2 = await printer.getS2PrinterData();
    stdout.writeln(
      'S2 subtotal=${s2.subTotalBases} tax=${s2.subTotalTax} payable=${s2.amountPayable}',
    );

    final s3 = await printer.getS3PrinterData();
    stdout.writeln(
      'S3 tax1=${s3.tax1} tax2=${s3.tax2} tax3=${s3.tax3} flags=${s3.systemFlags.length}',
    );

    final s4 = await printer.getS4PrinterData();
    stdout.writeln('S4 means=${s4.allMeansOfPayment.split('\n').length - 1}');

    final s5 = await printer.getS5PrinterData();
    stdout.writeln(
      'S5 rif=${s5.rif} auditMemory=${s5.auditMemoryNumber} documents=${s5.numberRegisteredDocuments}',
    );

    final s6 = await printer.getS6PrinterData();
    stdout.writeln('S6 facturacion=${s6.bitFacturacion}');

    final s7 = await printer.getS7PrinterData();
    stdout.writeln('S7 micrLength=${s7.micr.length}');

    final s8e = await printer.getS8EPrinterData();
    stdout.writeln('S8E header1=${s8e.headers[0]}');

    final s8p = await printer.getS8PPrinterData();
    stdout.writeln('S8P footer1=${s8p.footers[0]}');

    final xReport = await printer.getXReport();
    if (xReport == null) {
      stderr.writeln('No se pudo leer el reporte X');
      exitCode = 3;
      return;
    }

    stdout.writeln(
      'xReport z=${xReport.numberOfLastZReport} invoice=${xReport.numberOfLastInvoice} date=${xReport.zReportDate} time=${xReport.zReportTime}',
    );

    final zReport = await printer.getZReport();
    if (zReport is! ReportData) {
      stderr.writeln('No se pudo leer el reporte Z');
      exitCode = 4;
      return;
    }
    stdout.writeln(
      'zReport z=${zReport.numberOfLastZReport} invoice=${zReport.numberOfLastInvoice} date=${zReport.zReportDate} time=${zReport.zReportTime}',
    );

    final x2 = await printer.getX2Report();
    stdout.writeln('X2=${x2 == null ? 'UNSUPPORTED' : 'OK'}');

    final x4 = await printer.getX4Report();
    stdout.writeln('X4=${x4 == null ? 'UNSUPPORTED' : 'OK'}');

    final x5 = await printer.getX5Report();
    stdout.writeln('X5=${x5 == null ? 'UNSUPPORTED' : 'OK'}');

    final x7 = await printer.getX7Report();
    stdout.writeln('X7=${x7 == null ? 'UNSUPPORTED' : 'OK'}');

    final printXResult = await printer.printXReport();
    stdout.writeln('printX=${_repr(printXResult)}');

    if (printXResult == null || printXResult.isEmpty) {
      stderr.writeln('El emulador no respondió a I0X');
      exitCode = 5;
      return;
    }

    stdout.writeln('Full validation OK');
  } finally {
    printer.closeFpctrl();
  }
}

String _repr(String? value) {
  if (value == null) {
    return 'null';
  }
  return value.codeUnits
      .map((unit) => '\\x${unit.toRadixString(16).padLeft(2, '0')}')
      .join();
}
