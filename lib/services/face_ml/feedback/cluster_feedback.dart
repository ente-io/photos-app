import 'dart:developer' as dev;
import "dart:math" show Random;
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

  /// Returns a map of person's clusterID to map of closest clusterID to with disstance
  Future<Map<int, List<(int, double)>>> getSuggestionsUsingMean(
    Person p, {
    double maxClusterDistance = 0.4,
  }) async {
    // Get all the cluster data
    final faceMlDb = FaceMLDataDB.instance;

    final allClusterIdsToCountMap = (await faceMlDb.clusterIdToFaceCount());
    final ignoredClusters = await faceMlDb.getPersonIgnoredClusters(p.remoteID);
    final personClusters = await faceMlDb.getPersonClusterIDs(p.remoteID);
    dev.log(
      'existing clusters for ${p.attr.name} are $personClusters',
      name: "ClusterFeedbackService",
    );

    // Get and update the cluster summary to get the avg (centroid) and count
    final EnteWatch watch = EnteWatch("ClusterFeedbackService")..start();
    final Map<int, List<double>> clusterAvg = await _getUpdateClusterAvg(
      allClusterIdsToCountMap,
      ignoredClusters,
    );
    watch.log('computed avg for ${clusterAvg.length} clusters');

    // Find the actual closest clusters for the person
    final Map<int, List<(int, double)>> suggestions = _calcSuggestionsMean(
      clusterAvg,
      personClusters,
      ignoredClusters,
      maxClusterDistance,
    );

    // log suggestions
    for (final entry in suggestions.entries) {
      dev.log(
        ' ${entry.value.length} suggestion for ${p.attr.name} for cluster ID ${entry.key} are  suggestions ${entry.value}}',
        name: "ClusterFeedbackService",
      );
    }
    return suggestions;
  }

  Future<Set<int>> getSuggestionsUsingMedian(
    Person p, {
    int sampleSize = 50,
    double maxMedianDistance = 0.75,
    // double goodMedianDistance = 0.5,
    double maxMeanDistance = 0.70,
    double goodMeanDistance = 0.4,
  }) async {
    // Get all the cluster data
    final faceMlDb = FaceMLDataDB.instance;
    // final Map<int, List<(int, double)>> suggestions = {};
    final allClusterIdsToCountMap = (await faceMlDb.clusterIdToFaceCount());
    final ignoredClusters = await faceMlDb.getPersonIgnoredClusters(p.remoteID);
    final personClusters = await faceMlDb.getPersonClusterIDs(p.remoteID);
    dev.log(
      'existing clusters for ${p.attr.name} are $personClusters',
      name: "ClusterFeedbackService",
    );

    // Get and update the cluster summary to get the avg (centroid) and count
    final EnteWatch watch = EnteWatch("ClusterFeedbackService")..start();
    final Map<int, List<double>> clusterAvg = await _getUpdateClusterAvg(
      allClusterIdsToCountMap,
      ignoredClusters,
    );
    watch.log('computed avg for ${clusterAvg.length} clusters');

    // Find the other cluster candidates based on the mean
    final Map<int, List<(int, double)>> suggestionsMean = _calcSuggestionsMean(
      clusterAvg,
      personClusters,
      ignoredClusters,
      goodMeanDistance,
    );
    if (suggestionsMean.isNotEmpty) {
      final Set<int> suggestClusterIds = {};
      for (final List<(int, double)> suggestion in suggestionsMean.values) {
        for (final clusterNeighbors in suggestion) {
          suggestClusterIds.add(clusterNeighbors.$1);
        }
      }
      _logger.info(
        "Already found good suggestions using mean: $suggestClusterIds",
      );
      return suggestClusterIds;
    }

    // Find the other cluster candidates based on the median
    final Map<int, List<(int, double)>> moreSuggestionsMean =
        _calcSuggestionsMean(
      clusterAvg,
      personClusters,
      ignoredClusters,
      maxMeanDistance,
    );
    if (moreSuggestionsMean.isEmpty) {
      _logger
          .info("No suggestions found using mean, even with higher threshold");
      return <int>{};
    }

    final Set<int> otherClusterIdsCandidates = {};
    for (final List<(int, double)> suggestion in moreSuggestionsMean.values) {
      for (final clusterNeighbors in suggestion) {
        otherClusterIdsCandidates.add(clusterNeighbors.$1);
      }
    }
    _logger.info(
      "Found potential suggestions from loose mean for median test: $otherClusterIdsCandidates",
    );

    watch.logAndReset("Starting median test");
    // Take the embeddings from the person's clusters in one big list and sample from it
    final List<Uint8List> personEmbeddingsProto = [];
    for (final clusterID in personClusters) {
      final Iterable<Uint8List> embedings =
          await FaceMLDataDB.instance.getFaceEmbeddingsForCluster(clusterID);
      personEmbeddingsProto.addAll(embedings);
    }
    final List<Uint8List> sampledEmbeddingsProto =
        _randomSampleWithoutReplacement(
      personEmbeddingsProto,
      sampleSize,
    );
    final List<List<double>> sampledEmbeddings = sampledEmbeddingsProto
        .map((embedding) => EVector.fromBuffer(embedding).values)
        .toList(growable: false);

    // Find the actual closest clusters for the person using median
    final Set<int> suggestionsMedian = {};
    for (final otherClusterId in otherClusterIdsCandidates) {
      final Iterable<Uint8List> otherEmbeddingsProto =
          await FaceMLDataDB.instance.getFaceEmbeddingsForCluster(
        otherClusterId,
      );
      final sampledOtherEmbeddingsProto = _randomSampleWithoutReplacement(
        otherEmbeddingsProto,
        sampleSize,
      );
      final List<List<double>> sampledOtherEmbeddings =
          sampledOtherEmbeddingsProto
              .map((embedding) => EVector.fromBuffer(embedding).values)
              .toList(growable: false);

      // Calculate distances and find the median
      final List<double> distances = [];
      for (final otherEmbedding in sampledOtherEmbeddings) {
        for (final embedding in sampledEmbeddings) {
          distances.add(cosineDistForNormVectors(embedding, otherEmbedding));
        }
      }
      distances.sort();
      final double medianDistance = distances[distances.length ~/ 2];
      if (medianDistance < maxMedianDistance) {
        suggestionsMedian.add(otherClusterId);
      }
    }
    watch.log("Finished median test");
    if (suggestionsMedian.isEmpty) {
      _logger.info("No suggestions found using median");
    } else {
      _logger.info("Found suggestions using median: $suggestionsMedian");
    }

    return suggestionsMedian;
  }

  Future<Map<int, List<EnteFile>>> getClusterFilesForPersonID(
    Person person,
  ) async {
    _logger.info(
      'getClusterFilesForPersonID ${kDebugMode ? person.attr.name : person.remoteID}',
    );

    // Get the suggestions for the person using only centroids
    // final Map<int, List<(int, double)>> suggestions =
    //     await getSuggestionsUsingMean(person);
    // final Set<int> suggestClusterIds = {};
    // for (final List<(int, double)> suggestion in suggestions.values) {
    //   for (final clusterNeighbors in suggestion) {
    //     suggestClusterIds.add(clusterNeighbors.$1);
    //   }
    // }

    // Get the suggestions for the person using centroids and median
    final Set<int> suggestClusterIds = await getSuggestionsUsingMedian(person);

    // Get the files for the suggestions
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

  Future<Map<int, List<double>>> _getUpdateClusterAvg(
    Map<int, int> allClusterIdsToCountMap,
    Set<int> ignoredClusters,
  ) async {
    final faceMlDb = FaceMLDataDB.instance;

    final Map<int, (Uint8List, int)> clusterToSummary =
        await faceMlDb.clusterSummaryAll();
    final Map<int, (Uint8List, int)> updatesForClusterSummary = {};

    final Map<int, List<double>> clusterAvg = {};

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

    return clusterAvg;
  }

  Map<int, List<(int, double)>> _calcSuggestionsMean(
    Map<int, List<double>> clusterAvg,
    Set<int> personClusters,
    Set<int> ignoredClusters,
    double maxClusterDistance,
  ) {
    final Map<int, List<(int, double)>> suggestions = {};
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

    return suggestions;
  }

  List<T> _randomSampleWithoutReplacement<T>(
    Iterable<T> embeddings,
    int sampleSize,
  ) {
    final random = Random();

    if (sampleSize >= embeddings.length) {
      return embeddings.toList();
    }

    // If sampleSize is more than half the list size, shuffle and take first sampleSize elements
    if (sampleSize > embeddings.length / 2) {
      final List<T> shuffled = List<T>.from(embeddings)..shuffle(random);
      return shuffled.take(sampleSize).toList(growable: false);
    }

    // Otherwise, use the set-based method for efficiency
    final selectedIndices = <int>{};
    final sampledEmbeddings = <T>[];
    while (sampledEmbeddings.length < sampleSize) {
      final int index = random.nextInt(embeddings.length);
      if (!selectedIndices.contains(index)) {
        selectedIndices.add(index);
        sampledEmbeddings.add(embeddings.elementAt(index));
      }
    }

    return sampledEmbeddings;
  }
}
