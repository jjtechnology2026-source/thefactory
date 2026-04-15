double parseAmount(String value) {
  if (value.isEmpty) {
    return 0;
  }

  final negative = value.contains('-');
  final normalized = value.replaceAll('-', '');
  if (normalized.length < 2) {
    return 0;
  }

  final integerPart = normalized.substring(0, normalized.length - 2);
  final decimalPart = normalized.substring(normalized.length - 2);
  final amount = int.parse(integerPart) + (int.parse(decimalPart) / 100.0);
  return negative ? -amount : amount;
}

String parseDateFromYyMmDd(String value) {
  final year = int.parse(value.substring(0, 2)) + 2000;
  final month = value.substring(2, 4);
  final day = value.substring(4, 6);
  return '$day-$month-$year';
}

String parseDateFromDdMmYy(String value) {
  final day = value.substring(0, 2);
  final month = value.substring(2, 4);
  final year = int.parse(value.substring(4, 6)) + 2000;
  return '$day-$month-$year';
}

String parseTimeFromHhMm(String value) {
  final hour = value.substring(0, 2);
  final minute = value.substring(2, 4);
  return '$hour:$minute';
}

String parseTimeFromHhMmSs(String value) {
  final hour = value.substring(0, 2);
  final minute = value.substring(2, 4);
  final second = value.substring(4, 6);
  return '$hour:$minute:$second';
}

List<String> splitFrameFields(String frame, {int trimEnd = 1}) {
  if (frame.isEmpty || frame.length <= trimEnd) {
    return const [];
  }
  return frame
      .substring(1, frame.length - trimEnd)
      .split(String.fromCharCode(0x0A));
}
