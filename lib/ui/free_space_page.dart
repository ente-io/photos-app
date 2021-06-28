import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:photos/models/backup_status.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/ui/common_elements.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/utils/data_util.dart';
import 'package:photos/utils/delete_file_util.dart';
import 'package:photos/utils/dialog_util.dart';

class FreeSpacePage extends StatefulWidget {
  FreeSpacePage({Key key}) : super(key: key);

  @override
  _FreeSpacePageState createState() => _FreeSpacePageState();
}

class _FreeSpacePageState extends State<FreeSpacePage> {
  Future<BackupStatus> _future;

  @override
  void initState() {
    super.initState();
    _future = SyncService.instance.getBackupStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: "free_up_space",
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              "free up space",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
      body: _getBody(),
    );
  }

  Widget _getBody() {
    return FutureBuilder<BackupStatus>(
      future: _future,
      builder: (_, snapshot) {
        if (snapshot.hasData) {
          final status = snapshot.data;
          Logger("FreeSpacePage").info(
              "Number of uploaded files: " + status.localIDs.length.toString());
          Logger("FreeSpacePage")
              .info("Space consumed: " + status.size.toString());
          return _getWidget(status);
        } else if (snapshot.hasError) {
          return Center(child: Text("oops, something went wrong"));
        } else {
          return loadWidget;
        }
      },
    );
  }

  Widget _getWidget(BackupStatus status) {
    final count = status.localIDs.length;
    final formattedCount = NumberFormat().format(count);
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            "assets/backed_up_gallery.png",
            height: 160,
          ),
          Padding(padding: EdgeInsets.all(24)),
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 40),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  color: Color.fromRGBO(45, 194, 98, 1.0),
                ),
                Padding(padding: EdgeInsets.all(10)),
                Expanded(
                  child: Text(
                    count == 1
                        ? formattedCount.toString() +
                            " file on this device has been backed up safely"
                        : formattedCount.toString() +
                            " files on this device have been backed up safely",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(12)),
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 40),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  color: Color.fromRGBO(45, 194, 98, 1.0),
                ),
                Padding(padding: EdgeInsets.all(10)),
                Expanded(
                  child: Text(
                    "they can be deleted from this device to free up space",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(12)),
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 40),
            child: Row(
              children: [
                Icon(
                  Icons.devices,
                  color: Color.fromRGBO(45, 194, 98, 1.0),
                ),
                Padding(padding: EdgeInsets.all(10)),
                Expanded(
                  child: Text(
                    "you can still access them on ente as long as you have an active subscription",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(32)),
          Container(
            width: double.infinity,
            height: 64,
            padding: const EdgeInsets.fromLTRB(80, 0, 80, 0),
            child: button(
              "free up " + formatBytes(status.size),
              onPressed: () async {
                await _freeStorage(status);
              },
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _freeStorage(BackupStatus status) async {
    final dialog = createProgressDialog(
        context,
        "deleting " +
            status.localIDs.length.toString() +
            " backed up files...");
    await dialog.show();
    await deleteLocalFiles(status.localIDs);
    await dialog.hide();
    Navigator.of(context).pop(status);
  }
}
