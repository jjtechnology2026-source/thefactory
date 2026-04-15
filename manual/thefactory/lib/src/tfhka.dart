import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:serial_port_win32/serial_port_win32.dart';
import 'package:win32/win32.dart';

import 'accumulated_x.dart';
import 'command_sequences.dart';
import 'printer_data.dart';
import 'report_data.dart';

class Tfhka {
  SerialPort? _port;
  bool _opened = false;
  String status = '';
  String envio = '';
  String error = '';
  bool debug = false;

  bool get isOpen => _opened;

  Future<bool> openFpctrl(
    String portName, {
    int baudRate = CBR_9600,
    int byteSize = 8,
    int parity = EVENPARITY,
    int stopBits = ONESTOPBIT,
    int readIntervalTimeout = 0,
    int readTotalTimeoutConstant = 0,
    int readTotalTimeoutMultiplier = 0,
  }) async {
    if (_opened) {
      return true;
    }

    try {
      final port = SerialPort(
        portName,
        openNow: false,
        BaudRate: baudRate,
        ByteSize: byteSize,
        Parity: parity,
        StopBits: stopBits,
        ReadIntervalTimeout: readIntervalTimeout,
        ReadTotalTimeoutConstant: readTotalTimeoutConstant,
        ReadTotalTimeoutMultiplier: readTotalTimeoutMultiplier,
      );
      await port.open();
      port.WriteTotalTimeoutConstant = 5000;
      port.WriteTotalTimeoutMultiplier = 0;
      _port = port;
      _opened = true;
      return true;
    } catch (_) {
      _opened = false;
      envio = 'Impresora no conectada o error accediendo al puerto$portName';
      return false;
    }
  }

  bool closeFpctrl() {
    if (!_opened || _port == null) {
      envio = 'Status: 00  Error: 128';
      return false;
    }

    try {
      _port!.close();
      _port = null;
      _opened = false;
      return true;
    } catch (_) {
      envio = 'Status: 00  Error: 128';
      return false;
    }
  }

  Future<dynamic> sendCmd(String cmd) async {
    if (cmd == 'I0X' || cmd == 'I1X' || cmd == 'I1Z') {
      return _statesReport(cmd, const Duration(seconds: 4));
    }
    if (cmd == 'I0Z') {
      return _statesReport(cmd, const Duration(seconds: 9));
    }

    try {
      await _purge();
      if (await _handleCtsRts()) {
        final message = _assembleQueryToSend(cmd);
        await _write(message);
        final response = await _read(1, timeout: const Duration(seconds: 2));
        if (response == String.fromCharCode(0x06)) {
          envio = 'Status: 00  Error: 00';
          _clearRts();
          return true;
        }
        envio = 'Status: 00  Error: 89';
      } else {
        _getStatusError(0, 128);
        envio = 'Error... CTS in False';
      }
    } catch (_) {
      envio = 'Status: 00  Error: 89';
    }

    _clearRts();
    return false;
  }

  Future<String> readFpStatus() async {
    if (await _handleCtsRts()) {
      await _write(Uint8List.fromList([0x05]));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final response = await _read(5, timeout: const Duration(seconds: 2));
      if (response.length == 5) {
        if ((response.codeUnitAt(1) ^ response.codeUnitAt(2) ^ 0x03) ==
            response.codeUnitAt(4)) {
          _clearRts();
          return _getStatusError(
            response.codeUnitAt(1),
            response.codeUnitAt(2),
          );
        }
        _clearRts();
        return _getStatusError(0, 144);
      }
      _clearRts();
      return _getStatusError(0, 114);
    }
    return _getStatusError(0, 128);
  }

  Future<ReportData?> getXReport() async {
    final frame = await _uploadDataReport('U0X');
    if (frame == null) {
      return null;
    }
    return ReportData.fromRawFrame(frame);
  }

  Future<ReportData?> getX2Report() async {
    final frame = await _uploadDataReport('U1X');
    if (frame == null) {
      return null;
    }
    return ReportData.fromRawFrame(frame);
  }

  Future<AccumulatedX?> getX4Report() async {
    final frame = await _uploadDataReport('U0X4');
    if (frame == null) {
      return null;
    }
    return AccumulatedX.fromRawFrame(frame);
  }

  Future<AccumulatedX?> getX5Report() async {
    final frame = await _uploadDataReport('U0X5');
    if (frame == null) {
      return null;
    }
    return AccumulatedX.fromRawFrame(frame);
  }

  Future<AccumulatedX?> getX7Report() async {
    final frame = await _uploadDataReport('U0X7');
    if (frame == null) {
      return null;
    }
    return AccumulatedX.fromRawFrame(frame);
  }

  Future<S1PrinterData> getS1PrinterData() async =>
      S1PrinterData.fromRawFrame(await _states('S1'));

  Future<S2PrinterData> getS2PrinterData() async =>
      S2PrinterData.fromRawFrame(await _states('S2'));

  Future<S3PrinterData> getS3PrinterData() async =>
      S3PrinterData.fromRawFrame(await _states('S3'));

  Future<S4PrinterData> getS4PrinterData() async =>
      S4PrinterData.fromRawFrame(await _states('S4'));

  Future<S5PrinterData> getS5PrinterData() async =>
      S5PrinterData.fromRawFrame(await _states('S5'));

  Future<S6PrinterData> getS6PrinterData() async =>
      S6PrinterData.fromRawFrame(await _states('S6'));

  Future<S7PrinterData> getS7PrinterData() async =>
      S7PrinterData.fromRawFrame(await _states('S7'));

  Future<S8EPrinterData> getS8EPrinterData() async =>
      S8EPrinterData.fromRawFrame(await _states('S8E'));

  Future<S8PPrinterData> getS8PPrinterData() async =>
      S8PPrinterData.fromRawFrame(await _states('S8P'));

  Future<dynamic> getZReport({
    String? mode,
    Object? startParam,
    Object? endParam,
  }) async {
    if (mode == null || startParam == null || endParam == null) {
      final frame = await _uploadDataReport('U0Z');
      return frame == null ? null : ReportData.fromRawFrame(frame);
    }

    if (startParam is DateTime && endParam is DateTime) {
      final startString = _formatDateParameter(startParam);
      final endString = _formatDateParameter(endParam);
      final reports = await _readFiscalMemoryByCommand(
        'U2$mode$startString$endString',
      );
      return reports.map(ReportData.fromRawFrame).toList();
    }

    final startString = _padRangeValue(startParam);
    final endString = _padRangeValue(endParam);
    final reports = await _readFiscalMemoryByCommand(
      'U3$mode$startString$endString',
    );
    return reports.map(ReportData.fromRawFrame).toList();
  }

  Future<String?> printXReport() async {
    return _statesReport('I0X', const Duration(seconds: 4));
  }

  Future<String?> printZReport() async {
    return _statesReport('I0Z', const Duration(seconds: 9));
  }

  Future<void> sendCmdFile(String path) async {
    final file = File(path);
    final lines = await file.readAsLines();
    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        await sendCmd(line.trim());
      }
    }
  }

  Future<List<dynamic>> sendCommands(Iterable<String> commands) async {
    final results = <dynamic>[];
    for (final command in commands) {
      results.add(await sendCmd(command));
    }
    return results;
  }

  Future<bool> sendCommandsSuccessful(Iterable<String> commands) async {
    final results = await sendCommands(commands);
    return results.every((result) {
      if (result is bool) {
        return result;
      }
      if (result is String) {
        return result == String.fromCharCode(0x06);
      }
      return false;
    });
  }

  Future<bool> issueSimpleInvoice() async {
    return sendCommandsSuccessful(FiscalCommandSequences.simpleInvoice());
  }

  Future<bool> issuePersonalizedInvoice(FiscalCustomerData customer) async {
    return sendCommandsSuccessful(
      FiscalCommandSequences.personalizedInvoice(customer),
    );
  }

  Future<bool> issueCancelledInvoice(FiscalCustomerData customer) async {
    return sendCommandsSuccessful(
      FiscalCommandSequences.cancelledInvoice(customer),
    );
  }

  Future<bool> issueNonFiscalDocument(List<String> lines) async {
    final commands = FiscalCommandSequences.nonFiscalDocument(lines);
    if (commands.isEmpty) {
      return true;
    }

    for (final command in commands) {
      var sent = false;
      for (var attempt = 0; attempt < 4; attempt++) {
        final result = await sendCmd(command);
        if (_isAck(result)) {
          sent = true;
          break;
        }

        // El emulador puede rechazar temporalmente lineas consecutivas.
        if (!envio.contains('Error: 89') && !envio.contains('Error: 114')) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      if (!sent) {
        return false;
      }

      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    return true;
  }

  Future<bool> issueCreditNote(
    FiscalCustomerData customer, {
    String comment = 'COMENTARIO NOTA DE CREDITO',
  }) async {
    return sendCommandsSuccessful(
      FiscalCommandSequences.creditNote(customer, comment),
    );
  }

  Future<bool> issueDebitNote(
    FiscalCustomerData customer, {
    String comment = 'COMENTARIO NOTA DE DEBITO',
  }) async {
    return sendCommandsSuccessful(
      FiscalCommandSequences.debitNote(customer, comment),
    );
  }

  Future<bool> reprintInvoices(int start, int end) async {
    final result = await sendCmd(
      FiscalCommandSequences.reprintInvoices(start, end),
    );
    return _isAck(result);
  }

  bool _isAck(dynamic result) {
    if (result is bool) {
      return result;
    }
    if (result is String) {
      return result == String.fromCharCode(0x06);
    }
    return false;
  }

  Future<String?> _states(String cmd) async {
    await _queryCmd(cmd);
    return _fetchRow();
  }

  Future<String?> _statesReport(String cmd, Duration wait) async {
    await _queryCmd(cmd);
    return _fetchRowReport(wait);
  }

  Future<bool> _queryCmd(String cmd) async {
    try {
      await _purge();
      if (await _handleCtsRts()) {
        await _write(_assembleQueryToSend(cmd));
        return true;
      }
      _getStatusError(0, 128);
      envio = 'Error... CTS in False';
      _clearRts();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _fetchRow() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    final available = _bytesInQueue();
    if (available > 1) {
      final message = await _read(
        available,
        timeout: const Duration(seconds: 2),
      );
      final line = message.substring(1, message.length - 1);
      final lrc = _lrc(line);
      if (lrc == message.codeUnitAt(message.length - 1)) {
        await _purge();
        return message;
      }
    }
    return null;
  }

  Future<String?> _fetchRowReport(Duration wait) async {
    await Future<void>.delayed(wait);
    final available = _bytesInQueue();
    if (available > 0) {
      return _read(available, timeout: const Duration(seconds: 2));
    }
    return null;
  }

  Future<String?> _uploadDataReport(String cmd) async {
    try {
      await _purge();
      if (await _handleCtsRts()) {
        await _write(_assembleQueryToSend(cmd));
        var response = await _read(1, timeout: const Duration(seconds: 2));
        while (response == String.fromCharCode(0x05)) {
          response = await _read(1, timeout: const Duration(seconds: 2));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await _write(Uint8List.fromList([0x06]));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final row = await _fetchRow();
          _clearRts();
          return row;
        }
      } else {
        _getStatusError(0, 128);
        envio = 'Error... CTS in False';
      }
    } catch (_) {
      return null;
    }
    _clearRts();
    return null;
  }

  Future<List<String>> _readFiscalMemoryByCommand(
    String cmd, {
    int maxEmptyReads = 5,
  }) async {
    final reports = <String>[];
    try {
      await _purge();
      if (!await _handleCtsRts()) {
        _getStatusError(0, 128);
        envio = 'Error... CTS in False';
        return reports;
      }

      await _write(_assembleQueryToSend(cmd));
      String? message;
      var emptyReads = 0;
      while (message != String.fromCharCode(0x04)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _write(Uint8List.fromList([0x06]));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        message = await _fetchRowReport(const Duration(milliseconds: 1300));
        if (message == null) {
          emptyReads += 1;
          if (emptyReads >= maxEmptyReads) {
            break;
          }
          continue;
        }

        emptyReads = 0;
        if (message == String.fromCharCode(0x04)) {
          break;
        }

        if (message.contains(String.fromCharCode(0x04))) {
          final cleaned = message.replaceAll(String.fromCharCode(0x04), '');
          if (cleaned.isNotEmpty) {
            reports.add(cleaned);
          }
          break;
        }

        reports.add(message);
      }
    } catch (_) {
      return reports;
    } finally {
      _clearRts();
    }
    return reports;
  }

  Future<bool> _handleCtsRts() async {
    final port = _port;
    if (port == null) {
      return false;
    }

    final modemStatus = calloc<Uint32>();
    try {
      port.setFlowControlSignal(SerialPort.SETRTS);
      for (var attempt = 1; attempt <= 20; attempt++) {
        if (GetCommModemStatus(port.handler, modemStatus) != 0 &&
            (modemStatus.value & MS_CTS_ON) == MS_CTS_ON) {
          return true;
        }
        await Future<void>.delayed(Duration(milliseconds: attempt * 100));
      }
      _clearRts();
      return false;
    } finally {
      free(modemStatus);
    }
  }

  Future<void> _purge() async {
    final port = _port;
    if (port == null) {
      return;
    }
    PurgeComm(port.handler, PURGE_RXCLEAR | PURGE_TXCLEAR);
  }

  void _clearRts() {
    final port = _port;
    if (port != null && port.isOpened) {
      port.setFlowControlSignal(SerialPort.CLRRTS);
    }
  }

  Future<void> _write(Uint8List bytes) async {
    if (debug) {
      print('<<< ${_debug(bytes)}');
    }
    await _port!.writeBytesFromUint8List(bytes, timeout: 5000);
  }

  Future<String> _read(int size, {required Duration timeout}) async {
    final bytes = await _port!.readBytes(size, timeout: timeout);
    if (debug) {
      print('>>> ${_debug(bytes)}');
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  Uint8List _assembleQueryToSend(String line) {
    final body = <int>[...latin1.encode(line), 0x03];
    final lrc = _lrcFromCodes(body);
    return Uint8List.fromList([0x02, ...body, lrc]);
  }

  int _lrc(String line) {
    return _lrcFromCodes(line.codeUnits);
  }

  int _lrcFromCodes(List<int> values) {
    return values.fold<int>(0, (acc, item) => acc ^ item);
  }

  String _debug(Uint8List data) {
    if (data.isEmpty) {
      return 'null';
    }
    final working = List<int>.from(data);
    String suffix = '';
    if (working.length > 3) {
      suffix = ' LRC(${working.removeLast()})';
    }
    return working
            .map(
              (value) => switch (value) {
                0x02 => 'STX',
                0x03 => 'ETX',
                0x04 => 'EOT',
                0x05 => 'ENQ',
                0x06 => 'ACK',
                0x15 => 'NAK',
                0x17 => 'ETB',
                _ => latin1.decode([value], allowInvalid: true),
              },
            )
            .join() +
        suffix;
  }

  int _bytesInQueue() {
    final port = _port;
    if (port == null) {
      return 0;
    }
    final errors = calloc<Uint32>();
    final stat = calloc<COMSTAT>();
    try {
      if (ClearCommError(port.handler, errors, stat) == 0) {
        throw Exception('ClearCommError failed with ${GetLastError()}');
      }
      return stat.ref.cbInQue;
    } finally {
      free(errors);
      free(stat);
    }
  }

  String _formatDateParameter(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = (value.year % 100).toString().padLeft(2, '0');
    return '$day$month$year';
  }

  String _padRangeValue(Object value) {
    return value.toString().padLeft(6, '0');
  }

  String _getStatusError(int st, int er) {
    final originalStatus = st;
    final maskedStatus = st & ~0x04;
    late String statusCode;

    if ((maskedStatus & 0x6A) == 0x6A) {
      status =
          'En modo fiscal, carga completa de la memoria fiscal y emisión de documentos no fiscales';
      statusCode = '12';
    } else if ((maskedStatus & 0x69) == 0x69) {
      status =
          'En modo fiscal, carga completa de la memoria fiscal y emisión de documentos fiscales';
      statusCode = '11';
    } else if ((maskedStatus & 0x68) == 0x68) {
      status =
          'En modo fiscal, carga completa de la memoria fiscal y en espera';
      statusCode = '10';
    } else if ((maskedStatus & 0x72) == 0x72) {
      status =
          'En modo fiscal, cercana carga completa de la memoria fiscal y en emisión de documentos no fiscales';
      statusCode = '9 ';
    } else if ((maskedStatus & 0x71) == 0x71) {
      status =
          'En modo fiscal, cercana carga completa de la memoria fiscal y en emisión de documentos no fiscales';
      statusCode = '8 ';
    } else if ((maskedStatus & 0x70) == 0x70) {
      status =
          'En modo fiscal, cercana carga completa de la memoria fiscal y en espera';
      statusCode = '7 ';
    } else if ((maskedStatus & 0x62) == 0x62) {
      status = 'En modo fiscal y en emisión de documentos no fiscales';
      statusCode = '6 ';
    } else if ((maskedStatus & 0x61) == 0x61) {
      status = 'En modo fiscal y en emisión de documentos fiscales';
      statusCode = '5 ';
    } else if ((maskedStatus & 0x60) == 0x60) {
      status = 'En modo fiscal y en espera';
      statusCode = '4 ';
    } else if ((maskedStatus & 0x42) == 0x42) {
      status = 'En modo prueba y en emisión de documentos no fiscales';
      statusCode = '3 ';
    } else if ((maskedStatus & 0x41) == 0x41) {
      status = 'En modo prueba y en emisión de documentos fiscales';
      statusCode = '2 ';
    } else if ((maskedStatus & 0x40) == 0x40) {
      status = 'En modo prueba y en espera';
      statusCode = '1 ';
    } else {
      status = 'Status Desconocido';
      statusCode = '0 ';
    }

    late String errorCode;
    if ((er & 0x6C) == 0x6C) {
      error = 'Memoria Fiscal llena';
      errorCode = '108';
    } else if ((er & 0x64) == 0x64) {
      error = 'Error en memoria fiscal';
      errorCode = '100';
    } else if ((er & 0x60) == 0x60) {
      error = 'Error Fiscal';
      errorCode = '96 ';
    } else if ((er & 0x5C) == 0x5C) {
      error = 'Comando Invalido';
      errorCode = '92 ';
    } else if ((er & 0x58) == 0x58) {
      error = 'No hay asignadas directivas';
      errorCode = '88 ';
    } else if ((er & 0x54) == 0x54) {
      error = 'Tasa Invalida';
      errorCode = '84 ';
    } else if ((er & 0x50) == 0x50) {
      error = 'Comando Invalido/Valor Invalido';
      errorCode = '80 ';
    } else if ((er & 0x43) == 0x43) {
      error = 'Fin en la entrega de papel y error mecánico';
      errorCode = '3  ';
    } else if ((er & 0x42) == 0x42) {
      error = 'Error de índole mecánica en la entrega de papel';
      errorCode = '2  ';
    } else if ((er & 0x41) == 0x41) {
      error = 'Fin en la entrega de papel';
      errorCode = '1  ';
    } else if ((er & 0x40) == 0x40) {
      error = 'Sin error';
      errorCode = '0  ';
    } else {
      error = 'Error desconocido';
      errorCode = '0  ';
    }

    if ((originalStatus & 0x04) == 0x04) {
      error = '';
      errorCode = '112 ';
    } else if (er == 128) {
      error = 'CTS en falso';
      errorCode = '128 ';
    } else if (er == 137) {
      error = 'No hay respuesta';
      errorCode = '137 ';
    } else if (er == 144) {
      error = 'Error LRC';
      errorCode = '144 ';
    } else if (er == 114) {
      error = 'Impresora no responde o ocupada';
      errorCode = '114 ';
    }

    return '$statusCode   $errorCode   $error';
  }
}
