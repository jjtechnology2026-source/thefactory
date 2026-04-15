import 'parsing_utils.dart';

class AccumulatedX {
  double freeTax = 0;
  double generalRate1 = 0;
  double generalRate1Tax = 0;
  double reducedRate2 = 0;
  double reducedRate2Tax = 0;
  double additionalRate3 = 0;
  double additionalRate3Tax = 0;

  AccumulatedX();

  factory AccumulatedX.fromRawFrame(String frame) {
    final value = AccumulatedX();
    final fields = frame.split(String.fromCharCode(0x0A));
    if (fields.length >= 7) {
      value.freeTax = parseAmount(fields[0]);
      value.generalRate1 = parseAmount(fields[1]);
      value.reducedRate2 = parseAmount(fields[2]);
      value.additionalRate3 = parseAmount(fields[3]);
      value.generalRate1Tax = parseAmount(fields[4]);
      value.reducedRate2Tax = parseAmount(fields[5]);
      value.additionalRate3Tax = parseAmount(fields[6]);
    }
    return value;
  }
}
