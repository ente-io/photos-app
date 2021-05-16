import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_user_agent/flutter_user_agent.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Network {
  Dio _dio;

  Future<void> init() async {
    await FlutterUserAgent.init();
    final version = await _getAppVersion();
    _dio = Dio(BaseOptions(headers: {
      HttpHeaders.userAgentHeader: FlutterUserAgent.userAgent,
      'X-Client-Version': version,
    }));
  }

  Network._privateConstructor();
  static Network instance = Network._privateConstructor();

  Dio getDio() => _dio;

  Future<String> _getAppVersion() async {
    final pkgInfo = await PackageInfo.fromPlatform();
    return pkgInfo.version;
  }
}
