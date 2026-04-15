import 'package:thefactory/tfhka.dart';
import 'package:test/test.dart';

void main() {
  group('command sequences', () {
    test('simple invoice matches demo commands', () {
      final commands = FiscalCommandSequences.simpleInvoice();
      expect(commands.first, '@COMMENT/COMENTARIO');
      expect(commands.last, '101');
      expect(commands.length, 7);
    });

    test('customer data formats personalization commands', () {
      const customer = FiscalCustomerData(
        rif: '21.122.012',
        name: 'Pedro Perez',
        extraInfo: ['Direccion', 'Telefono'],
      );
      final commands = customer.toCommands();
      expect(commands[0], 'iR*21.122.012');
      expect(commands[1], 'iS*Pedro Perez');
      expect(commands[2], 'i00Direccion');
      expect(commands[3], 'i01Telefono');
    });

    test('credit note sequence includes reference data and totals', () {
      const customer = FiscalCustomerData(
        rif: '21.122.012',
        name: 'Pedro Perez',
        referenceInvoiceNumber: '00000000001',
        referenceInvoiceDate: '22/08/2016',
        machineNumber: 'Z1F1234567',
      );
      final commands = FiscalCommandSequences.creditNote(
        customer,
        'COMENTARIO NOTA DE CREDITO',
      );
      expect(commands, contains('iF*00000000001'));
      expect(commands, contains('iD*22/08/2016'));
      expect(commands, contains('ACOMENTARIO NOTA DE CREDITO'));
      expect(commands.last, '101');
    });

    test('debit note sequence matches demo prefixes', () {
      const customer = FiscalCustomerData(name: 'Pedro Perez');
      final commands = FiscalCommandSequences.debitNote(
        customer,
        'COMENTARIO NOTA DE DEBITO',
      );
      expect(commands, contains('BCOMENTARIO NOTA DE DEBITO'));
      expect(commands.any((value) => value.startsWith('`0')), isTrue);
      expect(commands.any((value) => value.startsWith('`1')), isTrue);
      expect(commands.any((value) => value.startsWith('`2')), isTrue);
      expect(commands.any((value) => value.startsWith('`3')), isTrue);
    });

    test('non fiscal document closes with 810', () {
      final commands = FiscalCommandSequences.nonFiscalDocument(const [
        r'$Documento de Prueba',
        'Esto es un documento de texto',
        'Fin del Documento no Fiscal',
      ]);
      expect(commands.first, '80\$Documento de Prueba');
      expect(commands[1], '81Esto es un documento de texto');
      expect(commands.last, '810Fin del Documento no Fiscal');
    });

    test('reprint invoice command pads both ends to 7 digits', () {
      final command = FiscalCommandSequences.reprintInvoices(12, 34);
      expect(command, 'RF00000120000034');
    });
  });
}
