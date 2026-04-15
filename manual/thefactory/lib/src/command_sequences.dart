class FiscalDocumentItem {
  final String prefix;
  final String body;

  const FiscalDocumentItem({required this.prefix, required this.body});

  String toCommand() => '$prefix$body';
}

class FiscalCustomerData {
  final String? rif;
  final String? name;
  final String? referenceInvoiceNumber;
  final String? referenceInvoiceDate;
  final String? machineNumber;
  final List<String> extraInfo;

  const FiscalCustomerData({
    this.rif,
    this.name,
    this.referenceInvoiceNumber,
    this.referenceInvoiceDate,
    this.machineNumber,
    this.extraInfo = const [],
  });

  List<String> toCommands() {
    final commands = <String>[];
    if (rif != null) commands.add('iR*$rif');
    if (name != null) commands.add('iS*$name');
    if (referenceInvoiceNumber != null) {
      commands.add('iF*$referenceInvoiceNumber');
    }
    if (referenceInvoiceDate != null) commands.add('iD*$referenceInvoiceDate');
    if (machineNumber != null) commands.add('iI*$machineNumber');
    commands.addAll(
      extraInfo.asMap().entries.map((entry) {
        final index = entry.key.toString().padLeft(2, '0');
        return 'i$index${entry.value}';
      }),
    );
    return commands;
  }
}

class FiscalCommandSequences {
  static List<String> simpleInvoice() => const [
    '@COMMENT/COMENTARIO',
    ' 000000030000001000Tax Free/Producto Exento',
    '!000000050000001000Tax Rate 1/Producto Tasa General',
    '"000000070000001000Tax Rate 2/ Producto Tasa Reducida',
    '#000000090000001000Tax Rate 3/ Producto Tasa Adicional',
    '3',
    '101',
  ];

  static List<String> personalizedInvoice(FiscalCustomerData customer) => [
    ...customer.toCommands(),
    ...simpleInvoice(),
  ];

  static List<String> cancelledInvoice(FiscalCustomerData customer) => [
    ...customer.toCommands(),
    '@COMMENT/COMENTARIO',
    ' 000000030000001000Tax Free/Producto Exento',
    '!000000050000001000Tax Rate 1/Producto Tasa General',
    '"000000070000001000Tax Rate 2/ Producto Tasa Reducida',
    '#000000090000001000Tax Rate 3/ Producto Tasa Adicional',
    '7',
  ];

  static List<String> nonFiscalDocument(List<String> lines) {
    if (lines.isEmpty) {
      return const [];
    }
    final commands = <String>[];
    for (var index = 0; index < lines.length; index++) {
      final prefix = switch (index) {
        0 when lines.length == 1 => '810',
        0 => '80',
        _ when index == lines.length - 1 => '810',
        _ => '81',
      };
      commands.add('$prefix${lines[index]}');
    }
    return commands;
  }

  static List<String> creditNote(FiscalCustomerData customer, String comment) =>
      [
        ...customer.toCommands(),
        'A$comment',
        'd0000000030000001000Tax Free/Producto Exento',
        'd1000000050000001000Tax Rate 1/Producto Tasa General',
        'd2000000070000001000Tax Rate 2/ Producto Tasa Reducida',
        'd3000000090000001000Tax Rate 3/ Producto Tasa Adicional',
        '3',
        '101',
      ];

  static List<String> debitNote(FiscalCustomerData customer, String comment) =>
      [
        ...customer.toCommands(),
        'B$comment',
        '`0000000003000000100Tax Free/Producto Exento',
        '`1100000005000000100Tax Rate 1/Producto Tasa General',
        '`2200000007000000100Tax Rate 2/ Producto Tasa Reducida',
        '`3300000009000000100Tax Rate 3/ Producto Tasa Adicional',
        '3',
        '101',
      ];

  static String reprintInvoices(int start, int end) {
    final startString = start.toString().padLeft(7, '0');
    final endString = end.toString().padLeft(7, '0');
    return 'RF$startString$endString';
  }
}
