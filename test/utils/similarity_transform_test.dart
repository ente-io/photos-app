import 'dart:developer' as devtools show log;

import 'package:ml_linalg/linalg.dart';
import "package:photos/services/face_ml/face_alignment/similarity_transform.dart";
import 'package:test/test.dart';

// run `dart test test/similarity_transform_test.dart ` to test
void main() {
  final exampleLandmarks = [
    <double>[103, 114],
    <double>[147, 111],
    <double>[129, 142],
    <double>[128, 160],
  ];
  final expectedParameters = Matrix.fromList([
    [0.81073804, -0.05217403, -39.88931937],
    [0.05217403, 0.81073804, -46.62302376],
    [0, 0, 1],
  ]);

  final tform = SimilarityTransform();
  final isNoNanInParam = tform.estimate(exampleLandmarks);
  final parameters = tform.paramsList;

  group('Similarity Transform Test', () {
    for (var i = 0; i < parameters.length; i++) {
      for (var j = 0; j < parameters[0].length; j++) {
        final actual = parameters[i][j];
        final expected = expectedParameters[i][j];
        devtools.log('actual: $actual, expected: $expected');
        test(
            'Test parameter estimation of SimilarityTransform at [$i, $j] in parameter matrix',
            () {
          expect(actual, closeTo(expected, 1e-4));
        });
      }
    }

    devtools.log('isNoNanInParam: $isNoNanInParam');
    test('isNoNanInParam test', () {
      expect(isNoNanInParam, isTrue);
    });

    // // Let's clean the parameters and test again.
    // tform._cleanParams();
    // final parametersAfterClean = tform.params;
    // test('cleanParams test', () {
    //   expect(
    //     parametersAfterClean,
    //     equals(
    //       Matrix.fromList([
    //         [1.0, 0.0, 0.0],
    //         [0.0, 1.0, 0.0],
    //         [0, 0, 1],
    //       ]),
    //     ),
    //   );
    // });

    // Let's test again
    final secondExampleLandmarks = [
      <double>[107, 113],
      <double>[147, 116],
      <double>[128, 137],
      <double>[127, 155],
    ];
    final secondExpectedParameters = Matrix.fromList([
      [9.42784402e-01, 2.96919308e-02, -6.78388902e+01],
      [-2.96919308e-02, 9.42784402e-01, -5.22145987e+01],
      [0, 0, 1],
    ]);
    final secondIsNoNanInParam = tform.estimate(secondExampleLandmarks);
    final secondParameters = tform.paramsList;

    for (var i = 0; i < secondParameters.length; i++) {
      for (var j = 0; j < secondParameters[0].length; j++) {
        final actual = secondParameters[i][j];
        final expected = secondExpectedParameters[i][j];
        devtools.log('actual: $actual, expected: $expected');
        test(
            'Test parameter estimation AFTER cleaning of SimilarityTransform at [$i, $j] in parameter matrix',
            () {
          expect(actual, closeTo(expected, 1e-4));
        });
      }
    }
    devtools.log('isNoNanInParam AFTER cleaning: $secondIsNoNanInParam');
    test('isNoNanInParam test AFTER cleaning', () {
      expect(secondIsNoNanInParam, isTrue);
    });
  });
}
