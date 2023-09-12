import 'dart:async';
import 'dart:isolate';

import "package:logging/logging.dart";
import "package:photos/models/ml_typedefs.dart";
import 'package:simple_cluster/simple_cluster.dart';
import 'package:synchronized/synchronized.dart';

class ClusteringIsolate {
  static const String debugName = "ClusteringIsolate";

  final _logger = Logger("ClusteringIsolate");

  final _initLock = Lock();

  late Isolate _isolate;
  late ReceivePort _receivePort = ReceivePort();
  late SendPort _mainSendPort;

  bool isSpawned = false;

  // Singleton pattern
  ClusteringIsolate._privateConstructor();

  /// Use this instance to access the ClusteringIsolate service. Make sure to call `init()` before using it.
  /// e.g. `await ClusteringIsolate.instance.init();`
  /// And kill the isolate when you're done with it with `dispose()`, e.g. `ClusteringIsolate.instance.dispose();`
  ///
  /// Then you can use `runClustering()` to get the clustering result, so `ClusteringIsolate.instance.runClustering(data, dbscan)`
  static final ClusteringIsolate instance =
      ClusteringIsolate._privateConstructor();
  factory ClusteringIsolate() => instance;

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

    receivePort.listen((message) {
      final data = message[0] as List<Embedding>;
      final dbscan = message[1] as DBSCAN;
      final sendPort = message[2] as SendPort;

      dbscan.run(data);

      sendPort.send(dbscan);
    });
  }

  /// Runs the clustering algorithm in an isolate, basedn on the given [data] and [dbscan] parameters.
  /// 
  /// Returns the [DBSCAN] object with the clustering result. Access the clustering result with [DBSCAN.cluster].
  Future<DBSCAN> runClustering(List<Embedding> data, DBSCAN dbscan) async {
    await ensureSpawned();
    final completer = Completer<DBSCAN>();
    final answerPort = ReceivePort();

    _mainSendPort.send([data, dbscan, answerPort.sendPort]);

    answerPort.listen((message) {
      completer.complete(message as DBSCAN);
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
