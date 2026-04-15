import 'parsing_utils.dart';

class S1PrinterData {
  String cashierNumber = '';
  double totalDailySales = 0;
  int lastInvoiceNumber = 0;
  int quantityOfInvoicesToday = 0;
  int lastDebtNoteNumber = 0;
  int quantityDebtNoteToday = 0;
  int lastNCNumber = 0;
  int quantityOfNCToday = 0;
  int numberNonFiscalDocuments = 0;
  int quantityNonFiscalDocuments = 0;
  int auditReportsCounter = 0;
  int fiscalReportsCounter = 0;
  int dailyClosureCounter = 0;
  String rif = '';
  String registeredMachineNumber = '';
  String currentPrinterDate = '';
  String currentPrinterTime = '';

  S1PrinterData();

  factory S1PrinterData.fromRawFrame(String? frame) {
    final value = S1PrinterData();
    if (frame == null || frame.length <= 100) {
      return value;
    }

    final fields = splitFrameFields(frame);
    if (fields.length <= 15) {
      value.cashierNumber = fields[0].substring(2);
      value.totalDailySales = parseAmount(fields[1]);
      value.lastInvoiceNumber = int.parse(fields[2]);
      value.quantityOfInvoicesToday = int.parse(fields[3]);
      value.numberNonFiscalDocuments = int.parse(fields[4]);
      value.quantityNonFiscalDocuments = int.parse(fields[5]);
      value.dailyClosureCounter = int.parse(fields[6]);
      value.fiscalReportsCounter = int.parse(fields[7]);
      value.rif = fields[8];
      value.registeredMachineNumber = fields[9];
      value.currentPrinterTime = parseTimeFromHhMmSs(fields[10]);
      value.currentPrinterDate = parseDateFromDdMmYy(fields[11]);
      value.lastNCNumber = int.parse(fields[12]);
      value.quantityOfNCToday = int.parse(fields[13]);
      return value;
    }

    value.cashierNumber = fields[0].substring(2);
    value.totalDailySales = parseAmount(fields[1]);
    value.lastInvoiceNumber = int.parse(fields[2]);
    value.quantityOfInvoicesToday = int.parse(fields[3]);
    value.lastDebtNoteNumber = int.parse(fields[4]);
    value.quantityDebtNoteToday = int.parse(fields[5]);
    value.lastNCNumber = int.parse(fields[6]);
    value.quantityOfNCToday = int.parse(fields[7]);
    value.numberNonFiscalDocuments = int.parse(fields[8]);
    value.quantityNonFiscalDocuments = int.parse(fields[9]);
    value.auditReportsCounter = int.parse(fields[10]);
    value.dailyClosureCounter = int.parse(fields[11]);
    value.rif = fields[12];
    value.registeredMachineNumber = fields[13];
    value.currentPrinterTime = parseTimeFromHhMmSs(fields[14]);
    value.currentPrinterDate = parseDateFromDdMmYy(fields[15]);
    return value;
  }
}

class S2PrinterData {
  double subTotalBases = 0;
  double subTotalTax = 0;
  String dataDummy = '';
  double amountPayable = 0;
  int numberPaymentsMade = 0;
  int typeDocument = 0;
  int quantityArticles = 0;
  int condition = 0;

  S2PrinterData();

  factory S2PrinterData.fromRawFrame(String? frame) {
    final value = S2PrinterData();
    if (frame == null || frame.length <= 69) {
      return value;
    }
    final fields = splitFrameFields(frame);
    if (fields.length > 1) {
      value.subTotalBases = parseAmount(fields[0].substring(3));
      value.subTotalTax = parseAmount(fields[1].substring(1));
      value.dataDummy = fields[2].substring(1);
      value.quantityArticles = int.parse(fields[3]);
      value.amountPayable = parseAmount(fields[4].substring(1));
      value.numberPaymentsMade = int.parse(fields[5]);
      value.typeDocument = int.parse(fields[6]);
    }
    return value;
  }
}

class S3PrinterData {
  String typeTax1 = '';
  double tax1 = 0;
  String typeTax2 = '';
  double tax2 = 0;
  String typeTax3 = '';
  double tax3 = 0;
  List<int> systemFlags = const [];

  S3PrinterData();

  factory S3PrinterData.fromRawFrame(String? frame) {
    final value = S3PrinterData();
    if (frame == null || frame.isEmpty) {
      return value;
    }

    final fields = splitFrameFields(frame);
    if (fields.length > 1) {
      value.typeTax1 = fields[0][2];
      value.tax1 = parseAmount(fields[0].substring(3));
      value.typeTax2 = fields[1][0];
      value.tax2 = parseAmount(fields[1].substring(1));
      value.typeTax3 = fields[2][0];
      value.tax3 = parseAmount(fields[2].substring(1));
      final flagsText = fields[3];
      final flags = <int>[];
      for (var index = 0; index < flagsText.length; index += 2) {
        flags.add(int.parse(flagsText.substring(index, index + 2)));
      }
      value.systemFlags = flags;
    }
    return value;
  }
}

class S4PrinterData {
  String allMeansOfPayment = '';

  S4PrinterData();

  factory S4PrinterData.fromRawFrame(String? frame) {
    final value = S4PrinterData();
    if (frame == null || frame.isEmpty) {
      return value;
    }
    final fields = splitFrameFields(frame);
    if (fields.length > 1) {
      final lines = <String>[];
      for (var index = 0; index < fields.length - 1; index++) {
        final raw = index == 0 ? fields[index].substring(2) : fields[index];
        lines.add('Medio de Pago ${index + 1} : ${parseAmount(raw)}');
      }
      value.allMeansOfPayment = '\n${lines.join('\n')}';
    }
    return value;
  }
}

class S5PrinterData {
  String rif = '';
  String registeredMachineNumber = '';
  int auditMemoryNumber = 0;
  int auditMemoryTotalCapacity = 0;
  int auditMemoryFreeCapacity = 0;
  int numberRegisteredDocuments = 0;

  S5PrinterData();

  factory S5PrinterData.fromRawFrame(String? frame) {
    final value = S5PrinterData();
    if (frame == null || frame.isEmpty) {
      return value;
    }
    final fields = splitFrameFields(frame);
    if (fields.length >= 6) {
      value.rif = fields[0].substring(2);
      value.registeredMachineNumber = fields[1];
      value.auditMemoryNumber = int.parse(fields[2]);
      value.auditMemoryTotalCapacity = int.parse(fields[3]);
      value.auditMemoryFreeCapacity = int.parse(fields[4]);
      value.numberRegisteredDocuments = int.parse(
        fields[5].replaceAll(String.fromCharCode(0x03), ''),
      );
    }
    return value;
  }
}

class S6PrinterData {
  String bitFacturacion = '';
  String bitSlip = '';
  String bitValidacion = '';

  S6PrinterData();

  factory S6PrinterData.fromRawFrame(String? frame) {
    final value = S6PrinterData();
    if (frame == null || frame.isEmpty) {
      return value;
    }
    final fields = splitFrameFields(frame);
    if (fields.length > 1) {
      value.bitFacturacion = fields[0].substring(2);
      value.bitSlip = fields[1];
      value.bitValidacion = fields[2].replaceAll(String.fromCharCode(0x03), '');
    } else {
      final compact = frame
          .replaceAll(String.fromCharCode(0x02), '')
          .replaceAll(String.fromCharCode(0x03), '');
      if (compact.startsWith('S6') && compact.length >= 5) {
        value.bitFacturacion = compact.substring(2, 5);
      }
    }
    return value;
  }
}

class S7PrinterData {
  String micr = '';

  S7PrinterData();

  factory S7PrinterData.fromRawFrame(String? frame) {
    final value = S7PrinterData();
    if (frame == null || frame.isEmpty) {
      return value;
    }
    final fields = splitFrameFields(frame, trimEnd: 2);
    if (fields.isNotEmpty) {
      value.micr = fields[0].substring(2);
    }
    return value;
  }
}

class S8EPrinterData {
  final List<String> headers;

  S8EPrinterData({List<String>? headers})
    : headers = headers ?? List<String>.filled(8, '');

  factory S8EPrinterData.fromRawFrame(String? frame) {
    if (frame == null) {
      return S8EPrinterData();
    }
    final parts = frame.split('\n');
    final values = List<String>.filled(8, '');
    if (parts.length >= 8) {
      values[0] = parts[0].substring(4);
      values[1] = parts[1];
      values[2] = parts[2];
      values[3] = parts[3];
      values[4] = parts[4];
      values[5] = parts[5];
      values[6] = parts[6];
      values[7] = parts[7]
          .replaceAll(String.fromCharCode(0x03), '')
          .replaceAll(RegExp(r'.$'), '');
    }
    return S8EPrinterData(headers: values);
  }
}

class S8PPrinterData {
  final List<String> footers;

  S8PPrinterData({List<String>? footers})
    : footers = footers ?? List<String>.filled(8, '');

  factory S8PPrinterData.fromRawFrame(String? frame) {
    if (frame == null) {
      return S8PPrinterData();
    }
    final parts = frame.split('\n');
    final values = List<String>.filled(8, '');
    if (parts.length >= 8) {
      values[0] = parts[0].substring(4);
      values[1] = parts[1];
      values[2] = parts[2];
      values[3] = parts[3];
      values[4] = parts[4];
      values[5] = parts[5];
      values[6] = parts[6];
      values[7] = parts[7]
          .replaceAll(String.fromCharCode(0x03), '')
          .replaceAll(RegExp(r'.$'), '');
    }
    return S8PPrinterData(footers: values);
  }
}
