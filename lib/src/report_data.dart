import 'parsing_utils.dart';

class ReportData {
  int numberOfLastZReport = 0;
  String zReportDate = '';
  String zReportTime = '';
  int numberOfLastInvoice = 0;
  String lastInvoiceDate = '';
  String lastInvoiceTime = '';
  int numberOfLastDebitNote = 0;
  int numberOfLastCreditNote = 0;
  int numberOfLastNonFiscal = 0;

  double freeSalesTax = 0;
  double generalRate1Sale = 0;
  double generalRate1Tax = 0;
  double reducedRate2Sale = 0;
  double reducedRate2Tax = 0;
  double additionalRate3Sale = 0;
  double additionalRate3Tax = 0;

  double freeTaxDebit = 0;
  double generalRateDebit = 0;
  double generalRateTaxDebit = 0;
  double reducedRateDebit = 0;
  double reducedRateTaxDebit = 0;
  double additionalRateDebit = 0;
  double additionalRateTaxDebit = 0;

  double freeTaxDevolution = 0;
  double generalRateDevolution = 0;
  double generalRateTaxDevolution = 0;
  double reducedRateDevolution = 0;
  double reducedRateTaxDevolution = 0;
  double additionalRateDevolution = 0;
  double additionalRateTaxDevolution = 0;

  ReportData();

  factory ReportData.fromRawFrame(String frame) {
    final report = ReportData();
    if (frame.length <= 100) {
      return report;
    }

    final payload = frame.substring(1, frame.length - 1);
    final fields = payload.split(String.fromCharCode(0x0A));

    if (fields.length > 31) {
      report.numberOfLastZReport = int.parse(fields[0]);
      report.zReportDate = parseDateFromDdMmYy(fields[1]);
      report.zReportTime = parseTimeFromHhMm(fields[2]);
      report.numberOfLastInvoice = int.parse(fields[3]);
      report.lastInvoiceDate = parseDateFromDdMmYy(fields[4]);
      report.lastInvoiceTime = parseTimeFromHhMm(fields[5]);
      report.numberOfLastCreditNote = int.parse(fields[6]);
      report.numberOfLastDebitNote = int.parse(fields[7]);
      report.numberOfLastNonFiscal = int.parse(fields[8]);
      report.freeSalesTax = parseAmount(fields[9]);
      report.generalRate1Sale = parseAmount(fields[10]);
      report.generalRate1Tax = parseAmount(fields[11]);
      report.reducedRate2Sale = parseAmount(fields[12]);
      report.reducedRate2Tax = parseAmount(fields[13]);
      report.additionalRate3Sale = parseAmount(fields[14]);
      report.additionalRate3Tax = parseAmount(fields[15]);
      report.freeTaxDebit = parseAmount(fields[16]);
      report.generalRateDebit = parseAmount(fields[17]);
      report.generalRateTaxDebit = parseAmount(fields[18]);
      report.reducedRateDebit = parseAmount(fields[19]);
      report.reducedRateTaxDebit = parseAmount(fields[20]);
      report.additionalRateDebit = parseAmount(fields[21]);
      report.additionalRateTaxDebit = parseAmount(fields[22]);
      report.freeTaxDevolution = parseAmount(fields[23]);
      report.generalRateDevolution = parseAmount(fields[24]);
      report.generalRateTaxDevolution = parseAmount(fields[25]);
      report.reducedRateDevolution = parseAmount(fields[26]);
      report.reducedRateTaxDevolution = parseAmount(fields[27]);
      report.additionalRateDevolution = parseAmount(fields[28]);
      report.additionalRateTaxDevolution = parseAmount(fields[29]);
      return report;
    }

    if (fields.length == 31) {
      report.numberOfLastZReport = int.parse(fields[0]);
      report.zReportDate = parseDateFromYyMmDd(fields[1]);
      report.zReportTime = parseTimeFromHhMm(fields[2]);
      report.numberOfLastInvoice = int.parse(fields[3]);
      report.lastInvoiceDate = parseDateFromYyMmDd(fields[4]);
      report.lastInvoiceTime = parseTimeFromHhMm(fields[5]);
      report.numberOfLastCreditNote = int.parse(fields[6]);
      report.numberOfLastDebitNote = int.parse(fields[7]);
      report.numberOfLastNonFiscal = int.parse(fields[8]);
      report.freeSalesTax = parseAmount(fields[9]);
      report.generalRate1Sale = parseAmount(fields[10]);
      report.generalRate1Tax = parseAmount(fields[11]);
      report.reducedRate2Sale = parseAmount(fields[12]);
      report.reducedRate2Tax = parseAmount(fields[13]);
      report.additionalRate3Sale = parseAmount(fields[14]);
      report.additionalRate3Tax = parseAmount(fields[15]);
      report.freeTaxDebit = parseAmount(fields[16]);
      report.generalRateDebit = parseAmount(fields[17]);
      report.generalRateTaxDebit = parseAmount(fields[18]);
      report.reducedRateDebit = parseAmount(fields[19]);
      report.reducedRateTaxDebit = parseAmount(fields[20]);
      report.additionalRateDebit = parseAmount(fields[21]);
      report.additionalRateTaxDebit = parseAmount(fields[22]);
      report.freeTaxDevolution = parseAmount(fields[23]);
      report.generalRateDevolution = parseAmount(fields[24]);
      report.generalRateTaxDevolution = parseAmount(fields[25]);
      report.reducedRateDevolution = parseAmount(fields[26]);
      report.reducedRateTaxDevolution = parseAmount(fields[27]);
      report.additionalRateDevolution = parseAmount(fields[28]);
      report.additionalRateTaxDevolution = parseAmount(fields[29]);
      return report;
    }

    if (fields.length == 21) {
      report.numberOfLastZReport = int.parse(fields[0]);
      report.zReportDate = parseDateFromYyMmDd(fields[1]);
      report.numberOfLastInvoice = int.parse(fields[2]);
      report.lastInvoiceDate = parseDateFromYyMmDd(fields[3]);
      report.lastInvoiceTime = parseTimeFromHhMm(fields[4]);
      report.freeSalesTax = parseAmount(fields[5]);
      report.generalRate1Sale = parseAmount(fields[6]);
      report.generalRate1Tax = parseAmount(fields[7]);
      report.reducedRate2Sale = parseAmount(fields[8]);
      report.reducedRate2Tax = parseAmount(fields[9]);
      report.additionalRate3Sale = parseAmount(fields[10]);
      report.additionalRate3Tax = parseAmount(fields[11]);
      report.freeTaxDevolution = parseAmount(fields[12]);
      report.generalRateDevolution = parseAmount(fields[13]);
      report.generalRateTaxDevolution = parseAmount(fields[14]);
      report.reducedRateDevolution = parseAmount(fields[15]);
      report.reducedRateTaxDevolution = parseAmount(fields[16]);
      report.additionalRateDevolution = parseAmount(fields[17]);
      report.additionalRateTaxDevolution = parseAmount(fields[18]);
      report.numberOfLastCreditNote = int.parse(fields[19]);
      return report;
    }

    if (fields.length == 22) {
      report.numberOfLastZReport = int.parse(fields[0]);
      report.zReportDate = parseDateFromDdMmYy(fields[1]);
      report.zReportTime = parseTimeFromHhMm(fields[2]);
      report.numberOfLastInvoice = int.parse(fields[3]);
      report.lastInvoiceDate = parseDateFromDdMmYy(fields[4]);
      report.lastInvoiceTime = parseTimeFromHhMm(fields[5]);
      report.freeSalesTax = parseAmount(fields[6]);
      report.generalRate1Sale = parseAmount(fields[7]);
      report.generalRate1Tax = parseAmount(fields[8]);
      report.reducedRate2Sale = parseAmount(fields[9]);
      report.reducedRate2Tax = parseAmount(fields[10]);
      report.additionalRate3Sale = parseAmount(fields[11]);
      report.additionalRate3Tax = parseAmount(fields[12]);
      report.freeTaxDevolution = parseAmount(fields[13]);
      report.generalRateDevolution = parseAmount(fields[14]);
      report.generalRateTaxDevolution = parseAmount(fields[15]);
      report.reducedRateDevolution = parseAmount(fields[16]);
      report.reducedRateTaxDevolution = parseAmount(fields[17]);
      report.additionalRateDevolution = parseAmount(fields[18]);
      report.additionalRateTaxDevolution = parseAmount(fields[19]);
      report.numberOfLastCreditNote = int.parse(fields[20]);
    }

    return report;
  }
}
