class Detection {
  final double score;
  final int classID;
  final double xMin;
  final double yMin;
  final double width;
  final double height;
  Detection(
      this.score, this.classID, this.xMin, this.yMin, this.width, this.height);
}
