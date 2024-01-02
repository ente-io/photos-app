import 'dart:async';
import "dart:developer";
import 'dart:isolate';
import "dart:typed_data";

import "package:computer/computer.dart";
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
      final data = message[0] as Map<String, Uint8List>;
      final sendPort = message[1] as SendPort;
      final result = await runClusteringSync(data);
      sendPort.send(result);
    });
  }

  static const recommendedDistanceThreshold = 0.3;
  static const happyDistanceThreshold = 0.1;

  static Future<Map<String, int>> runClusteringSync(
    Map<String, Uint8List> x,
  ) async {
    final Computer _computer = Computer.shared();
    await _computer.turnOn(
      workersCount: 4,
      verbose: false,
    );
    log("[ClusterIsolate] ${DateTime.now()} Copied to isolate");
    final List<FaceInfo> faceInfos = [];
    for (final entry in x.entries) {
      faceInfos.add(
        FaceInfo(
          faceID: entry.key,
          embedding: EVector.fromBuffer(entry.value).values,
        ),
      );
    }
    final int totalFaces = faceInfos.length;
    int clusterID = 1;
    if (faceInfos.isNotEmpty) {
      faceInfos.first.clusterId = clusterID;
    }
    log("[ClusterIsolate] ${DateTime.now()} Processing ${totalFaces} faces");
    final stopwatchClustering = Stopwatch()..start();
    for (int i = 1; i < totalFaces; i++) {
      final currentEmbedding = faceInfos[i].embedding;
      int closestIdx = -1;
      double closestDistance = double.infinity;
      if (i % 250 == 0) {
        log("[ClusterIsolate] ${DateTime.now()} Processing ${i} faces");
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
          log(' [ClusterIsolate] ${DateTime.now()} Found new cluster ${clusterID}');
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

  /// Runs the clustering algorithm in an isolate, basedn on the given [data] and [dbscan] parameters.
  ///
  /// Returns the [DBSCAN] object with the clustering result. Access the clustering result with [DBSCAN.cluster].
  Future<Map<String, int>> runClustering(
    Map<String, Uint8List> x,
  ) async {
    await ensureSpawned();
    final completer = Completer<Map<String, int>>();
    final answerPort = ReceivePort();

    log("Sending items ${x.length} to ClusterIsolate ${DateTime.now()}");
    _mainSendPort.send([x, answerPort.sendPort]);
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
