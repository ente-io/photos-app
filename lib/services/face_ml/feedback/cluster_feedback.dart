import 'dart:developer' as dev;
import "dart:typed_data";

import "package:photos/extensions/stop_watch.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/person.dart";
import "package:photos/generated/protos/ente/common/vector.pb.dart";
import "package:photos/services/face_ml/face_clustering/cosine_distance.dart";

class ClusterFeedbackService {
  ClusterFeedbackService._privateConstructor();

  static final ClusterFeedbackService instance =
      ClusterFeedbackService._privateConstructor();

  Future<Map<int, List<(int, double)>>> getSuggestions(Person p) async {
    final faceMlDb = FaceMLDataDB.instance;
    // suggestions contains map of person's clusterID to map of closest clusterID to with disstance
    final Map<int, List<(int, double)>> suggestions = {};
    final allClusterIdsToCountMap = (await faceMlDb.clusterIdToFaceCount());
    final ignoredClusters = await faceMlDb.getPersonIgnoredClusters(p.remoteID);
    final personClusters = await faceMlDb.getPersonClusterIDs(p.remoteID);
    final Map<int, (Uint8List, int)> clusterToSummary =
        await faceMlDb.clusterSummaryAll();
    final Map<int, (Uint8List, int)> updatesForClusterSummary = {};

    final Map<int, List<double>> clusterAvg = {};
    final EnteWatch watch = EnteWatch("ClusterFeedbackService")..start();

    final allClusterIds = allClusterIdsToCountMap.keys;
    for (final clusterID in allClusterIds) {
      if (ignoredClusters.contains(clusterID)) {
        continue;
      }
      late List<double> avg;
      if (clusterToSummary[clusterID]?.$2 ==
          allClusterIdsToCountMap[clusterID]) {
        avg = EVector.fromBuffer(clusterToSummary[clusterID]!.$1).values;
      } else {
        final Iterable<Uint8List> embedings =
            await FaceMLDataDB.instance.getFaceEmbeddingsForCluster(clusterID);
        final List<double> sum = List.filled(192, 0);
        for (final embedding in embedings) {
          final data = EVector.fromBuffer(embedding).values;
          for (int i = 0; i < sum.length; i++) {
            sum[i] += data[i];
          }
        }
        avg = sum.map((e) => e / embedings.length).toList();
        final avgEmbeedingBuffer = EVector(values: avg).writeToBuffer();
        updatesForClusterSummary[clusterID] =
            (avgEmbeedingBuffer, embedings.length);
      }
      clusterAvg[clusterID] = avg;
    }
    if (updatesForClusterSummary.isNotEmpty) {
      await faceMlDb.clusterSummaryUpdate(updatesForClusterSummary);
    }
    watch.log('computed avg for ${clusterAvg.length} clusters');

    for (final otherClusterID in clusterAvg.keys) {
      // ignore the cluster that belong to the person or is ignored
      if (personClusters.contains(otherClusterID) ||
          ignoredClusters.contains(otherClusterID)) {
        continue;
      }
      final otherAvg = clusterAvg[otherClusterID]!;
      int? closestClusterID;
      double? closestDistance;
      for (final personCluster in personClusters) {
        final avg = clusterAvg[personCluster]!;
        final distance = cosineDistForNormVectors(avg, otherAvg);
        if (distance < 0.4) {
          if (closestDistance == null || distance < closestDistance) {
            closestDistance = distance;
            closestClusterID = personCluster;
          }
        }
      }
      if (closestClusterID != null && closestDistance != null) {
        suggestions
            .putIfAbsent(closestClusterID, () => [])
            .add((otherClusterID, closestDistance));
      }
    }
    dev.log(
      'suggestions for ${p.attr.name} are ${suggestions.length}',
      name: "ClusterFeedbackService",
    );
    for (final entry in suggestions.entries) {
      entry.value.sort((a, b) => a.$1.compareTo(b.$1));
    }
    // log suggestions
    for (final entry in suggestions.entries) {
      dev.log(
        'suggestion for ${p.attr.name} is ${entry.key} with ${entry.value.length} suggestions ${entry.value}}',
        name: "ClusterFeedbackService",
      );
    }
    return suggestions;
  }
}
