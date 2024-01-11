import 'dart:developer' as dev;
import "dart:typed_data";

import "package:flutter/foundation.dart";
import "package:logging/logging.dart";
import "package:photos/extensions/stop_watch.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/person.dart";
import "package:photos/generated/protos/ente/common/vector.pb.dart";
import "package:photos/models/file/file.dart";
import "package:photos/services/face_ml/face_clustering/cosine_distance.dart";
import "package:photos/services/search_service.dart";

class ClusterFeedbackService {
  final Logger _logger = Logger("ClusterFeedbackService");
  ClusterFeedbackService._privateConstructor();

  static final ClusterFeedbackService instance =
      ClusterFeedbackService._privateConstructor();

  Future<Map<int, List<(int, double)>>> getSuggestions(
    Person p, {
    double maxClusterDistance = 0.4,
  }) async {
    final faceMlDb = FaceMLDataDB.instance;
    // suggestions contains map of person's clusterID to map of closest clusterID to with disstance
    final Map<int, List<(int, double)>> suggestions = {};
    final allClusterIdsToCountMap = (await faceMlDb.clusterIdToFaceCount());
    final ignoredClusters = await faceMlDb.getPersonIgnoredClusters(p.remoteID);
    final personClusters = await faceMlDb.getPersonClusterIDs(p.remoteID);
    dev.log(
      'existing clusters for ${p.attr.name} are $personClusters',
      name: "ClusterFeedbackService",
    );
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
      int? nearestPersonCluster;
      double? minDistance;
      for (final personCluster in personClusters) {
        final avg = clusterAvg[personCluster]!;
        final distance = cosineDistForNormVectors(avg, otherAvg);
        if (distance < maxClusterDistance) {
          if (minDistance == null || distance < minDistance) {
            minDistance = distance;
            nearestPersonCluster = personCluster;
          }
        }
      }
      if (nearestPersonCluster != null && minDistance != null) {
        suggestions
            .putIfAbsent(nearestPersonCluster, () => [])
            .add((otherClusterID, minDistance));
      }
    }

    for (final entry in suggestions.entries) {
      entry.value.sort((a, b) => a.$1.compareTo(b.$1));
    }
    // log suggestions
    for (final entry in suggestions.entries) {
      dev.log(
        ' ${entry.value.length} suggestion for ${p.attr.name} for cluster ID ${entry.key} are  suggestions ${entry.value}}',
        name: "ClusterFeedbackService",
      );
    }
    return suggestions;
  }

  Future<Map<int, List<EnteFile>>> getClusterFilesForPersonID(
    Person person,
  ) async {
    _logger.info(
      'getClusterFilesForPersonID ${kDebugMode ? person.attr.name : person.remoteID}',
    );
    final Map<int, List<(int, double)>> suggestions =
        await getSuggestions(person);
    final Set<int> suggestClusterIds = {};
    for (final List<(int, double)> suggestion in suggestions.values) {
      for (final clusterNeighbors in suggestion) {
        suggestClusterIds.add(clusterNeighbors.$1);
      }
    }
    final Map<int, Set<int>> fileIdToClusterID = await FaceMLDataDB.instance
        .getFileIdToClusterIDSetForCluster(suggestClusterIds);
    final Map<int, List<EnteFile>> clusterIDToFiles = {};
    final allFiles = await SearchService.instance.getAllFiles();
    for (final f in allFiles) {
      if (!fileIdToClusterID.containsKey(f.uploadedFileID ?? -1)) {
        continue;
      }
      final cluserIds = fileIdToClusterID[f.uploadedFileID ?? -1]!;
      for (final cluster in cluserIds) {
        if (clusterIDToFiles.containsKey(cluster)) {
          clusterIDToFiles[cluster]!.add(f);
        } else {
          clusterIDToFiles[cluster] = [f];
        }
      }
    }
    return clusterIDToFiles;
  }

  Future<void> removePersonFromFiles(List<EnteFile> files, Person p) {
    return FaceMLDataDB.instance.removePersonFromFiles(files, p);
  }
}
