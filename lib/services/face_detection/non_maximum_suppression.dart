import 'package:scidart/numdart.dart';

import 'detection.dart';

List<Detection> nonMaximumSuppression(
  List<Detection> detections,
  double threshold,
) {
  if (detections.isEmpty) return [];
  var x1 = <double>[];
  var x2 = <double>[];
  var y1 = <double>[];
  var y2 = <double>[];
  var s = <double>[];

  detections.forEach((detection) {
    x1.add(detection.xMin);
    x2.add(detection.xMin + detection.width);
    y1.add(detection.yMin);
    y2.add(detection.yMin + detection.height);
    s.add(detection.score);
  });

  var _x1 = Array(x1);
  var _x2 = Array(x2);
  var _y1 = Array(y1);
  var _y2 = Array(y2);

  var area = (_x2 - _x1) * (_y2 - _y1);
  var I = _quickSort(s);

  var positions = <int>[];
  I.forEach((element) {
    positions.add(s.indexOf(element));
  });

  var pick = <int>[];
  int counter = 0;
  final int maxLimit = I.length;
  while (I.isNotEmpty && counter < maxLimit) {
    counter++;
    var ind0 = positions.sublist(positions.length - 1, positions.length);
    var ind1 = positions.sublist(0, positions.length - 1);

    var xx1 = _maximum(_itemIndex(_x1, ind0)[0], _itemIndex(_x1, ind1));
    var yy1 = _maximum(_itemIndex(_y1, ind0)[0], _itemIndex(_y1, ind1));
    var xx2 = _minimum(_itemIndex(_x2, ind0)[0], _itemIndex(_x2, ind1));
    var yy2 = _minimum(_itemIndex(_y2, ind0)[0], _itemIndex(_y2, ind1));
    var w = _maximum(0.0, xx2 - xx1);
    var h = _maximum(0.0, yy2 - yy1);
    var inter = w * h;
    var o = inter /
        (_sum(_itemIndex(area, ind0)[0], _itemIndex(area, ind1)) - inter);

    pick.add(ind0[0]);
    final nextI = o.where((element) => element <= threshold).toList();
    if (nextI.length == I.length) {
      break;
    }
  }
  return [detections[pick[0]]];
}

Array _sum(double a, Array b) {
  var _temp = <double>[];
  b.forEach((element) {
    _temp.add(a + element);
  });
  return Array(_temp);
}

Array _maximum(double value, Array itemIndex) {
  var _temp = <double>[];
  itemIndex.forEach((element) {
    if (value > element) {
      _temp.add(value);
    } else {
      _temp.add(element);
    }
  });
  return Array(_temp);
}

Array _minimum(double value, Array itemIndex) {
  var _temp = <double>[];
  itemIndex.forEach((element) {
    if (value < element) {
      _temp.add(value);
    } else {
      _temp.add(element);
    }
  });
  return Array(_temp);
}

Array _itemIndex(Array item, List<int> positions) {
  var _temp = <double>[];
  positions.forEach((element) => _temp.add(item[element]));
  return Array(_temp);
}

List<double> _quickSort(List<double> a) {
  if (a.length <= 1) return a;

  var pivot = a[0];
  var less = <double>[];
  var more = <double>[];
  var pivotList = <double>[];

  a.forEach((var i) {
    if (i.compareTo(pivot) < 0) {
      less.add(i);
    } else if (i.compareTo(pivot) > 0) {
      more.add(i);
    } else {
      pivotList.add(i);
    }
  });

  less = _quickSort(less);
  more = _quickSort(more);

  less.addAll(pivotList);
  less.addAll(more);
  return less;
}
