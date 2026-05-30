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
}
