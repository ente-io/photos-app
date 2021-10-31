import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:photos/core/network.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlagService {
  FeatureFlagService._privateConstructor();

  static final FeatureFlagService instance =
      FeatureFlagService._privateConstructor();
  static const kBooleanFeatureFlagsKey = "feature_flags_key";

  final _logger = Logger("FeatureFlagService");
  FeatureFlags? _featureFlags;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await sync();
  }

  bool disableCFWorker() {
    try {
      _featureFlags ??=
          FeatureFlags.fromJson(_prefs.getString(kBooleanFeatureFlagsKey)!);
      return _featureFlags != null ? _featureFlags!.disableCFWorker : false;
    } catch (e) {
      _logger.severe(e);
      return false;
    }
  }

  bool enableStripe() {
    if (Platform.isIOS) {
      return false;
    }
    try {
      _featureFlags ??=
          FeatureFlags.fromJson(_prefs.getString(kBooleanFeatureFlagsKey)!);
      return _featureFlags != null ? _featureFlags!.enableStripe : true;
    } catch (e) {
      _logger.severe(e);
      return true;
    }
  }

  Future<void> sync() async {
    try {
      final response = await Network.instance
          .getDio()
          .get("https://static.ente.io/feature_flags.json");
      final featureFlags = FeatureFlags.fromMap(response.data);
      if (featureFlags != null) {
        _prefs.setString(kBooleanFeatureFlagsKey, featureFlags.toJson());
        _featureFlags = featureFlags;
      }
    } catch (e) {
      _logger.severe("Failed to sync feature flags ", e);
    }
  }
}

class FeatureFlags {
  bool disableCFWorker = false; // default to false
  bool enableStripe = true; // default to true

  FeatureFlags(
    this.disableCFWorker,
    this.enableStripe,
  );

  @override
  Map<String, dynamic> toMap() {
    return {
      "disableCFWorker": disableCFWorker,
      "enableStripe": enableStripe,
    };
  }

  String toJson() => json.encode(toMap());

  factory FeatureFlags.fromJson(String source) =>
      FeatureFlags.fromMap(json.decode(source));

  factory FeatureFlags.fromMap(Map<String, dynamic> json) {
    return FeatureFlags(
      json["disableCFWorker"] ?? false,
      json["enableStripe"] ?? true,
    );
  }

  @override
  String toString() {
    return toMap().toString();
  }
}
