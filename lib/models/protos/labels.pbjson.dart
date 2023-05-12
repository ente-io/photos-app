///
//  Generated code. Do not modify.
//  source: labels.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,deprecated_member_use_from_same_package,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:core' as $core;
import 'dart:convert' as $convert;
import 'dart:typed_data' as $typed_data;
@$core.Deprecated('Use labelDescriptor instead')
const Label$json = const {
  '1': 'Label',
  '2': const [
    const {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    const {'1': 'score', '3': 2, '4': 1, '5': 2, '10': 'score'},
  ],
};

/// Descriptor for `Label`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List labelDescriptor = $convert.base64Decode('CgVMYWJlbBISCgRuYW1lGAEgASgJUgRuYW1lEhQKBXNjb3JlGAIgASgCUgVzY29yZQ==');
@$core.Deprecated('Use labelMapDescriptor instead')
const LabelMap$json = const {
  '1': 'LabelMap',
  '2': const [
    const {'1': 'labels', '3': 1, '4': 3, '5': 11, '6': '.Label', '10': 'labels'},
  ],
};

/// Descriptor for `LabelMap`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List labelMapDescriptor = $convert.base64Decode('CghMYWJlbE1hcBIeCgZsYWJlbHMYASADKAsyBi5MYWJlbFIGbGFiZWxz');
