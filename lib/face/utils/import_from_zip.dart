// import "dart:io";

import "dart:convert";

import "package:archive/archive_io.dart";
// import "package:dio/dio.dart";
import "package:logging/logging.dart";
// import "package:photos/core/configuration.dart";
// import "package:photos/core/network/network.dart";

final _logger = Logger("import_from_zip");
// Future<String> downloadZip() async {
//   // temp zip path
//   final String tempDir = Configuration.instance.getTempDirectory();
//   final String zipPath = "${tempDir}temp.zip";
//   final File zipFile = File(zipPath);
//   const remoteZipUrl = "http://localhost:8700/json/file.zip";
//   final response = await NetworkClient.instance.getDio().download(
//         remoteZipUrl,
//         zipPath,
//         options: Options(
//           headers: {"X-Auth-Token": Configuration.instance.getToken()},
//         ),
//       );
//   if (response.statusCode != 200 || !zipFile.existsSync()) {
//     _logger.warning('download failed ${response.toString()}');
//     throw Exception("download failed");
//   }
//   return zipPath;
// }

// for a given zip path, unzip it and read the json content of file at
// location indexeddb/mldata.json
Future<dynamic> readJsonFromZip(String zipPath) async {
  final input = InputFileStream(zipPath);
  final archive = ZipDecoder().decodeBuffer(input);
  for (final file in archive) {
    final filename = file.name;
    if (filename == "indexeddb/mldata.json") {
      // read the json content from the file
      final data = file.content as List<int>;
      final jsonContent = utf8.decode(data);
      // parse the json content
      final json = jsonDecode(jsonContent);
      return json;
    }
  }
  throw Exception("json file not found");
}
