import 'dart:async';
import "dart:developer";
import 'dart:isolate';
import "dart:math" show max;
import "dart:typed_data";

import "package:logging/logging.dart";
import "package:photos/generated/protos/ente/common/vector.pb.dart";
import "package:photos/services/face_ml/face_clustering/cosine_distance.dart";
import 'package:synchronized/synchronized.dart';

class FaceInfo {
  final String faceID;
  final List<double> embedding;
  int? clusterId;
  String? closestFaceId;
  int? closestDist;
  FaceInfo({
    required this.faceID,
    required this.embedding,
    this.clusterId,
  });
}

class ClusterInfo {
  final int clusterId;
  final List<FaceInfo> faces;
  ClusterInfo({
    required this.clusterId,
    required this.faces,
  });
}

class LinearIsolate {
  static const String debugName = "LinearIsolate";

  final _logger = Logger("ClusteringIsolate");

  final _initLock = Lock();

  late Isolate _isolate;
  late ReceivePort _receivePort = ReceivePort();
  late SendPort _mainSendPort;

  bool isSpawned = false;

  // Singleton pattern
  LinearIsolate._privateConstructor();

  /// Use this instance to access the ClusteringIsolate service. Make sure to call `init()` before using it.
  /// e.g. `await ClusteringIsolate.instance.init();`
  /// And kill the isolate when you're done with it with `dispose()`, e.g. `ClusteringIsolate.instance.dispose();`
  ///
  /// Then you can use `runClustering()` to get the clustering result, so `ClusteringIsolate.instance.runClustering(data, dbscan)`
  static final LinearIsolate instance = LinearIsolate._privateConstructor();
  factory LinearIsolate() => instance;

  Future<void> init() async {
    return _initLock.synchronized(() async {
      if (isSpawned) return;
      _receivePort = ReceivePort();

      try {
        _isolate = await Isolate.spawn(
          _isolateMain,
          _receivePort.sendPort,
          debugName: debugName,
        );
        _mainSendPort = await _receivePort.first as SendPort;
        isSpawned = true;
      } catch (e) {
        _logger.info("Could not spawn isolate: $e");
        isSpawned = false;
      }
    });
  }

  Future<void> ensureSpawned() async {
    if (!isSpawned) {
      await init();
    }
  }

  static void _isolateMain(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      final data = message[0] as Map<String, (int?, Uint8List)>;
      final sendPort = message[1] as SendPort;
      final result = await runClusteringSync(data);
      sendPort.send(result);
    });
  }

  static const recommendedDistanceThreshold = 0.3;
  static const happyDistanceThreshold = 0.1;

  static Future<Map<String, int>> runClusteringSync(
    Map<String, (int?, Uint8List)> x,
  ) async {
    log("[ClusterIsolate] ${DateTime.now()} Copied to isolate ${x.length} faces");
    final List<FaceInfo> faceInfos = [];
    for (final entry in x.entries) {
      faceInfos.add(
        FaceInfo(
          faceID: entry.key,
          embedding: EVector.fromBuffer(entry.value.$2).values,
          clusterId: entry.value.$1,
        ),
      );
    }
    // Sort the faceInfos such that the ones with null clusterId are at the end
    faceInfos.sort((a, b) {
      if (a.clusterId == null && b.clusterId == null) {
        return 0;
      } else if (a.clusterId == null) {
        return 1;
      } else if (b.clusterId == null) {
        return -1;
      } else {
        return 0;
      }
    });
    // Count the amount of null values at the end
    int nullCount = 0;
    for (final faceInfo in faceInfos.reversed) {
      if (faceInfo.clusterId == null) {
        nullCount++;
      } else {
        break;
      }
    }
    log("[ClusterIsolate] ${DateTime.now()} Clustering $nullCount new faces without clusterId, and ${faceInfos.length - nullCount} faces with clusterId");
    for (final clusteredFaceInfo
        in faceInfos.sublist(0, faceInfos.length - nullCount)) {
      assert(clusteredFaceInfo.clusterId != null);
    }

    final int totalFaces = faceInfos.length;
    int clusterID = 1;
    if (faceInfos.isNotEmpty) {
      faceInfos.first.clusterId = clusterID;
    }
    log("[ClusterIsolate] ${DateTime.now()} Processing $totalFaces faces");
    final stopwatchClustering = Stopwatch()..start();
    for (int i = 1; i < totalFaces; i++) {
      // Incremental clustering, so we can skip faces that already have a clusterId
      if (faceInfos[i].clusterId != null) {
        clusterID = max(clusterID, faceInfos[i].clusterId!);
        continue;
      }
      final currentEmbedding = faceInfos[i].embedding;
      int closestIdx = -1;
      double closestDistance = double.infinity;
      if (i % 250 == 0) {
        log("[ClusterIsolate] ${DateTime.now()} Processing $i faces");
      }
      for (int j = 0; j < i; j++) {
        final double distance = cosineDistForNormVectors(
          currentEmbedding,
          faceInfos[j].embedding,
        );
        if (distance < closestDistance) {
          closestDistance = distance;
          closestIdx = j;
        }
      }

      if (closestDistance < recommendedDistanceThreshold) {
        if (faceInfos[closestIdx].clusterId == null) {
          // Ideally this should never happen, but just in case log it
          log(" [ClusterIsolate] ${DateTime.now()} Found new cluster $clusterID");
          clusterID++;
          faceInfos[closestIdx].clusterId = clusterID;
        }
        faceInfos[i].clusterId = faceInfos[closestIdx].clusterId;
      } else {
        clusterID++;
        faceInfos[i].clusterId = clusterID;
      }
    }
    final Map<String, int> result = {};
    for (final faceInfo in faceInfos) {
      result[faceInfo.faceID] = faceInfo.clusterId!;
    }
    stopwatchClustering.stop();
    log(
      ' [ClusterIsolate] ${DateTime.now()} Clustering for ${faceInfos.length} embeddings (${faceInfos[0].embedding.length} size) executed in ${stopwatchClustering.elapsedMilliseconds}ms, clusters $clusterID',
    );
    return result;
  }

  /// Runs the linear incremental clustering algorithm in an isolate, based on the given [faceToEmbeddings]
  ///
  /// Executes [runClusteringSync] in an isolate, and returns the result.
  ///
  /// Returns the clustering result, which is a map of faceID to clusterID.
  Future<Map<String, int>> runClustering(
    Map<String, (int?, Uint8List)> faceToEmbeddings,
  ) async {
    await ensureSpawned();
    final completer = Completer<Map<String, int>>();
    final answerPort = ReceivePort();

    log("Sending items ${faceToEmbeddings.length} to ClusterIsolate ${DateTime.now()}");
    _mainSendPort.send([faceToEmbeddings, answerPort.sendPort]);
    answerPort.listen((message) {
      completer.complete(message as Map<String, int>);
    });
    return completer.future;
  }

  void dispose() {
    if (!isSpawned) return;

    _isolate.kill();
    _receivePort.close();
    isSpawned = false;
  }
}
