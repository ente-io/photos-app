enum FeedbackType {
  removePhotoClusterFeedback,
  addPhotoClusterFeedback,
  deleteClusterFeedback,
  mergeClusterFeedback,
  renameOrCustomThumbnailClusterFeedback; // I have merged renameClusterFeedback and customThumbnailClusterFeedback, since I suspect they will be used together often

  factory FeedbackType.fromValueString(String value) {
    switch (value) {
      case 'deleteClusterFeedback':
        return FeedbackType.deleteClusterFeedback;
      case 'mergeClusterFeedback':
        return FeedbackType.mergeClusterFeedback;
      case 'renameOrCustomThumbnailClusterFeedback':
        return FeedbackType.renameOrCustomThumbnailClusterFeedback;
      case 'removePhotoClusterFeedback':
        return FeedbackType.removePhotoClusterFeedback;
      case 'addPhotoClusterFeedback':
        return FeedbackType.addPhotoClusterFeedback;
      default:
        throw Exception('Invalid FeedbackType: $value');
    }
  }

  String toValueString() => name;
}