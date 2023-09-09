import "package:logging/logging.dart";
import "package:photos/services/face_ml/face_clustering/dbscan_clustering_isolate.dart";
import "package:photos/services/face_ml/face_clustering/dbscan_config.dart";
import "package:simple_cluster/simple_cluster.dart";

class FaceClustering {
  DBSCAN _dbscan;

  final _logger = Logger("FaceClusteringService");

  final DBSCANConfig config;

  bool _hasRun = false;

  ///Index of points considered as noise
  List<int>? get noise {
    if (!_hasRun) {
      return null;
    }
    return _dbscan.noise;
  }

  /// Cluster label for each points, similar to sklearn's output structure.
  ///
  /// -1 means noise (doesn't belong in any cluster)
  List<int>? get labels {
    if (!_hasRun) {
      return null;
    }
    return _dbscan.label;
  }

  /// Result clusters
  List<List<int>>? get cluster {
    if (!_hasRun) {
      return null;
    }
    return _dbscan.cluster;
  }

  // singleton pattern
  FaceClustering._privateConstructor({required this.config})
      : _dbscan = DBSCAN(
          epsilon: config.epsilon,
          minPoints: config.minPoints,
          distanceMeasure: config.distanceMeasure,
        );

  /// Use this instance to access the FaceClustering service.
  /// e.g. `FaceClustering.instance.run(dataset)`
  ///
  /// config options: faceClusteringDBSCANConfig
  static final instance =
      FaceClustering._privateConstructor(config: faceClusteringDBSCANConfig);
  factory FaceClustering() => instance;

  Future<List<List<int>>> predict(List<List<double>> dataset) async {
    ClusteringIsolate.instance.ensureSpawned();

    _hasRun = false;

    final stopwatchClustering = Stopwatch()..start();
    _dbscan = await ClusteringIsolate.instance.runClustering(dataset, _dbscan);
    final clusterOutput = _dbscan.cluster;
    stopwatchClustering.stop();
    _logger.info(
      'Clustering for ${dataset.length} embeddings (${dataset[0].length} size) executed in ${stopwatchClustering.elapsedMilliseconds}ms',
    );

    _hasRun = true;

    ClusteringIsolate.instance.dispose();

    return clusterOutput;
  }
}
