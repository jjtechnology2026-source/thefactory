import 'package:thefactory/tfhka.dart';
import 'package:test/test.dart';

void main() {
  group('parsers', () {
    test('S1 real fixture', () {
      const frame =
          '\x02S100\n00000000000000000\n00000000\n00000\n00000000\n00000\n00000000\n00000\n00000000\n00000\n0175\n0001\nJ-312171197\nZ1F1234567\n093149\n140426\n\x03\x12';
      final data = S1PrinterData.fromRawFrame(frame);
      expect(data.cashierNumber, '00');
      expect(data.lastInvoiceNumber, 0);
      expect(data.auditReportsCounter, 175);
      expect(data.dailyClosureCounter, 1);
      expect(data.rif, 'J-312171197');
      expect(data.registeredMachineNumber, 'Z1F1234567');
      expect(data.currentPrinterTime, '09:31:49');
      expect(data.currentPrinterDate, '14-04-2026');
    });

    test('S2 real fixture', () {
      const frame =
          '\x02S2 0000000000000\n 0000000000000\n 0000000000000\n000000\n 0000000000000\n0000\n0\n\x03X';
      final data = S2PrinterData.fromRawFrame(frame);
      expect(data.subTotalBases, 0);
      expect(data.subTotalTax, 0);
      expect(data.quantityArticles, 0);
      expect(data.numberPaymentsMade, 0);
      expect(data.typeDocument, 0);
    });

    test('S2 soporta montos con signo intercalado', () {
      const frame =
          '\x02S2 0000000000000\n 0000000000000\n 0000000000000\n000000\n 000000000-1\n0000\n0\n\x03X';
      final data = S2PrinterData.fromRawFrame(frame);
      expect(data.amountPayable, -0.01);
    });

    test('S3 real fixture', () {
      const frame =
          '\x02S300016\n00008\n00031\n00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000\n\x03_';
      final data = S3PrinterData.fromRawFrame(frame);
      expect(data.typeTax1, '0');
      expect(data.tax1, 0.16);
      expect(data.tax2, 0.08);
      expect(data.tax3, 0.31);
      expect(data.systemFlags.length, greaterThan(10));
    });

    test('S4 real fixture', () {
      const frame =
          '\x02S40000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n\x03d';
      final data = S4PrinterData.fromRawFrame(frame);
      expect(data.allMeansOfPayment, contains('Medio de Pago 1 : 0.0'));
      expect(data.allMeansOfPayment, contains('Medio de Pago 24 : 0.0'));
    });

    test('S5 real fixture', () {
      const frame =
          '\x02S5J-312171197\nZ1F1234567\n0000\n0000\n0000\n000000\x03-';
      final data = S5PrinterData.fromRawFrame(frame);
      expect(data.rif, 'J-312171197');
      expect(data.registeredMachineNumber, 'Z1F1234567');
      expect(data.auditMemoryNumber, 0);
      expect(data.numberRegisteredDocuments, 0);
    });

    test('S6 real fixture', () {
      const frame = '\x02S6000\x03V';
      final data = S6PrinterData.fromRawFrame(frame);
      expect(data.bitFacturacion, '000');
    });

    test('S7 real fixture', () {
      const frame = '\x02S7???????????????????????????????????????\x03X';
      final data = S7PrinterData.fromRawFrame(frame);
      expect(data.micr, '???????????????????????????????????????');
    });

    test('S8E real fixture', () {
      const frame =
          '\x02S8EImpresoras Fiscales\nThe Factory HKA\nVenezuela\n0212-2375253\n\n\n\n\n\x03\x1d';
      final data = S8EPrinterData.fromRawFrame(frame);
      expect(data.headers[0], 'Impresoras Fiscales');
      expect(data.headers[1], 'The Factory HKA');
      expect(data.headers[2], 'Venezuela');
    });

    test('S8P real fixture', () {
      const frame = '\x02S8P\n\n\n\n\n\n\n\n\x038';
      final data = S8PPrinterData.fromRawFrame(frame);
      expect(data.footers.length, 8);
      expect(data.footers[0], '');
    });

    test('X report real fixture', () {
      const frame =
          '\x020176\n061125\n0956\n00000837\n140426\n0935\n00000011\n00000019\n00000506\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n0000000000\n\x03\x0f';
      final data = ReportData.fromRawFrame(frame);
      expect(data.numberOfLastZReport, 176);
      expect(data.zReportDate, '06-11-2025');
      expect(data.zReportTime, '09:56');
      expect(data.numberOfLastInvoice, 837);
      expect(data.lastInvoiceDate, '14-04-2026');
      expect(data.lastInvoiceTime, '09:35');
      expect(data.numberOfLastCreditNote, 11);
      expect(data.numberOfLastDebitNote, 19);
      expect(data.numberOfLastNonFiscal, 506);
    });
  });
}
