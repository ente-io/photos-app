//
//  Generated code. Do not modify.
//  source: ente/ml/face.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use detectionDescriptor instead')
const Detection$json = {
  '1': 'Detection',
  '2': [
    {'1': 'box', '3': 1, '4': 2, '5': 11, '6': '.CenterBox', '10': 'box'},
    {'1': 'landmarks', '3': 2, '4': 3, '5': 11, '6': '.EPoint', '10': 'landmarks'},
  ],
};

/// Descriptor for `Detection`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List detectionDescriptor = $convert.base64Decode(
    'CglEZXRlY3Rpb24SHAoDYm94GAEgAigLMgouQ2VudGVyQm94UgNib3gSJQoJbGFuZG1hcmtzGA'
    'IgAygLMgcuRVBvaW50UglsYW5kbWFya3M=');

