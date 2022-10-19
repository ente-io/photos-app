import 'dart:math';

final storageUnits = ["bytes", "KB", "MB", "GB"];

String convertBytesToReadableFormat(int bytes) {
  int storageUnitIndex = 0;
  while (bytes >= 1024 && storageUnitIndex < storageUnits.length - 1) {
    storageUnitIndex++;
    bytes = (bytes / 1024).round();
  }
  return bytes.toString() + " " + storageUnits[storageUnitIndex];
}

String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes == 0) return '0 bytes';
  const k = 1024;
  final int dm = decimals < 0 ? 0 : decimals;
  final int i = (log(bytes) / log(k)).floor();
  return ((bytes / pow(k, i)).toStringAsFixed(dm)) + ' ' + storageUnits[i];
}

//shows decimals only if less than 10GB & omits decimal if decimal is 0
num convertBytesToGBs(int bytes) {
  const tenGBinBytes = 10737418240;
  int precision = 0;
  if (bytes < tenGBinBytes) {
    precision = 1;
  }
  final bytesInGB =
      num.parse((bytes / (pow(1024, 3))).toStringAsPrecision(precision));
  return bytesInGB;
}

int convertBytesToMBs(int bytes) {
  return (bytes / pow(1024, 2)).round();
}
