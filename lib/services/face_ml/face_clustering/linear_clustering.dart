import "dart:developer";
import "dart:typed_data";

import "package:logging/logging.dart";
import 'package:photos/services/face_ml/face_clustering/cluster_isolate.dart';

class FaceLinearClustering {
  final _logger = Logger("FaceLinearClustering");

  bool isRunning = false;

  // singleton pattern
  FaceLinearClustering._privateConstructor();

  /// Use this instance to access the FaceClustering service.
  /// e.g. `FaceClustering.instance.run(dataset)`
  ///
  /// config options: faceClusteringDBSCANConfig
  static final instance = FaceLinearClustering._privateConstructor();
  factory FaceLinearClustering() => instance;

  /// Runs the clustering algorithm on the given [dataset], in an isolate.
  ///
  /// Returns the clustering result, which is a list of clusters, where each cluster is a list of indices of the dataset.
  ///
  /// WARNING: Make sure to always input data in the same ordering, otherwise the clustering can less less deterministic.
  Future<Map<String, int>?> predict(
    Map<String, (int?, Uint8List)> input,
  ) async {
    if (input.isEmpty) {
      _logger.warning(
        "Clustering dataset of embeddings is empty, returning empty list.",
      );
      return null;
    }
    if (isRunning) {
      _logger.warning("Clustering is already running, returning empty list.");
      return null;
    }

    await LinearIsolate.instance.ensureSpawned();

    isRunning = true;

    final stopwatchClustering = Stopwatch()..start();
    final Map<String, int> faceIdToCluster =
        await LinearIsolate.instance.runClustering(input);
    _logger.info(
      'Clustering executed in ${stopwatchClustering.elapsed.inSeconds} seconds',
    );
    //  Find faceIDs that are part of a cluster which is larger than 5;
    final Map<int, int> clusterIdToSize = {};
    faceIdToCluster.forEach((key, value) {
      if (clusterIdToSize.containsKey(value)) {
        clusterIdToSize[value] = clusterIdToSize[value]! + 1;
      } else {
        clusterIdToSize[value] = 1;
      }
    });
    final Map<String, int> faceIdToClusterFiltered = {};
    for (final entry in faceIdToCluster.entries) {
      if (clusterIdToSize[entry.value]! > 0) {
        faceIdToClusterFiltered[entry.key] = entry.value;
      }
    }

    // print top 10 cluster ids and their sizes based on the internal cluster id
    final clusterIds = faceIdToCluster.values.toSet();
    final clusterSizes = clusterIds.map((clusterId) {
      return faceIdToCluster.values.where((id) => id == clusterId).length;
    }).toList();
    clusterSizes.sort();
    // find clusters whose size is graeter than 1
    int oneClusterCount = 0;
    int moreThan5Count = 0;
    int moreThan10Count = 0;
    int moreThan20Count = 0;
    int moreThan50Count = 0;
    int moreThan100Count = 0;

    // for (int i = 0; i < clusterSizes.length; i++) {
    //   if (clusterSizes[i] > 100) {
    //     moreThan100Count++;
    //   } else if (clusterSizes[i] > 50) {
    //     moreThan50Count++;
    //   } else if (clusterSizes[i] > 20) {
    //     moreThan20Count++;
    //   } else if (clusterSizes[i] > 10) {
    //     moreThan10Count++;
    //   } else if (clusterSizes[i] > 5) {
    //     moreThan5Count++;
    //   } else if (clusterSizes[i] == 1) {
    //     oneClusterCount++;
    //   }
    // }
    for (int i = 0; i < clusterSizes.length; i++) {
      if (clusterSizes[i] > 100) {
        moreThan100Count++;
      }
      if (clusterSizes[i] > 50) {
        moreThan50Count++;
      }
      if (clusterSizes[i] > 20) {
        moreThan20Count++;
      }
      if (clusterSizes[i] > 10) {
        moreThan10Count++;
      }
      if (clusterSizes[i] > 5) {
        moreThan5Count++;
      }
      if (clusterSizes[i] == 1) {
        oneClusterCount++;
      }
    }
    // print the metrics
    log(
      '[Clustering]Total clusters ${clusterIds.length}, '
      'oneClusterCount $oneClusterCount, '
      'moreThan5Count $moreThan5Count, '
      'moreThan10Count $moreThan10Count, '
      'moreThan20Count $moreThan20Count, '
      'moreThan50Count $moreThan50Count, '
      'moreThan100Count $moreThan100Count',
    );

    // log('Top clusters count ${clusterSizes.reversed.take(10).toList()}');

    isRunning = false;
    return faceIdToClusterFiltered;
  }
}
