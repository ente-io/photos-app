import 'package:scidart/numdart.dart';

import 'anchors.dart';
import 'options.dart';

Array decodeBox(
    List<double> rawBoxes, int i, List<Anchor> anchors, OptionsFace options) {
  var boxData = Array(List<double>.generate(options.numCoords, (i) => 0.0));
  var boxOffset = i * options.numCoords + options.boxCoordOffset;
  var yCenter = rawBoxes[boxOffset];
  var xCenter = rawBoxes[boxOffset + 1];
  var h = rawBoxes[boxOffset + 2];
  var w = rawBoxes[boxOffset + 3];
  if (options.reverseOutputOrder) {
    xCenter = rawBoxes[boxOffset];
    yCenter = rawBoxes[boxOffset + 1];
    w = rawBoxes[boxOffset + 2];
    h = rawBoxes[boxOffset + 3];
  }

  // x, y, w, h = 1, 0, 3, 2

  xCenter = xCenter / options.xScale * anchors[i].w + anchors[i].xCenter;
  yCenter = yCenter / options.yScale * anchors[i].h + anchors[i].yCenter;

  if (options.applyExponentialOnBoxSize) {
    h = exp(h / options.hScale) * anchors[i].h;
    w = exp(w / options.wScale) * anchors[i].w;
  } else {
    h = h / options.hScale * anchors[i].h;
    w = w / options.wScale * anchors[i].w;
  }

  var yMin = yCenter - h / 2.0;
  var xMin = xCenter - w / 2.0;
  var yMax = yCenter + h / 2.0;
  var xMax = xCenter + w / 2.0;

  boxData[0] = yMin;
  boxData[1] = xMin;
  boxData[2] = yMax;
  boxData[3] = xMax;

  if (options.numKeypoints > 0) {
    for (var k = 0; k < options.numKeypoints; k++) {
      var offset = i * options.numCoords +
          options.keypointCoordOffset +
          k * options.numValuesPerKeypoint;
      var keyPointY = rawBoxes[offset];
      var keyPointX = rawBoxes[offset + 1];

      if (options.reverseOutputOrder) {
        keyPointX = rawBoxes[offset];
        keyPointY = rawBoxes[offset + 1];
      }
      boxData[4 + k * options.numValuesPerKeypoint] =
          keyPointX / options.xScale * anchors[i].w + anchors[i].xCenter;

      boxData[4 + k * options.numValuesPerKeypoint + 1] =
          keyPointY / options.yScale * anchors[i].h + anchors[i].yCenter;
    }
  }
  return boxData;
}
