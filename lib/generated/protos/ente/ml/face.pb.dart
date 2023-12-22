//
//  Generated code. Do not modify.
//  source: ente/ml/face.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../common/box.pb.dart' as $0;
import '../common/point.pb.dart' as $1;

class Detection extends $pb.GeneratedMessage {
  factory Detection({
    $0.CenterBox? box,
    $core.Iterable<$1.EPoint>? landmarks,
  }) {
    final $result = create();
    if (box != null) {
      $result.box = box;
    }
    if (landmarks != null) {
      $result.landmarks.addAll(landmarks);
    }
    return $result;
  }
  Detection._() : super();
  factory Detection.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Detection.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Detection', createEmptyInstance: create)
    ..aQM<$0.CenterBox>(1, _omitFieldNames ? '' : 'box', subBuilder: $0.CenterBox.create)
    ..pc<$1.EPoint>(2, _omitFieldNames ? '' : 'landmarks', $pb.PbFieldType.PM, subBuilder: $1.EPoint.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Detection clone() => Detection()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Detection copyWith(void Function(Detection) updates) => super.copyWith((message) => updates(message as Detection)) as Detection;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Detection create() => Detection._();
  Detection createEmptyInstance() => create();
  static $pb.PbList<Detection> createRepeated() => $pb.PbList<Detection>();
  @$core.pragma('dart2js:noInline')
  static Detection getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Detection>(create);
  static Detection? _defaultInstance;

  @$pb.TagNumber(1)
  $0.CenterBox get box => $_getN(0);
  @$pb.TagNumber(1)
  set box($0.CenterBox v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasBox() => $_has(0);
  @$pb.TagNumber(1)
  void clearBox() => clearField(1);
  @$pb.TagNumber(1)
  $0.CenterBox ensureBox() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<$1.EPoint> get landmarks => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
