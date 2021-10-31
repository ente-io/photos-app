import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/models/magic_metadata.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/ui/gallery.dart';
import 'package:photos/ui/gallery_app_bar_widget.dart';

class ArchivePage extends StatelessWidget {
  final String tagPrefix;
  final GalleryAppBarType appBarType;
  final _selectedFiles = SelectedFiles();

  ArchivePage(
      {this.tagPrefix = "archived_page",
      this.appBarType = GalleryAppBarType.archive,
      Key? key})
      : super(key: key);

  @override
  Widget build(Object context) {
    final gallery = Gallery(
      asyncLoader: (creationStartTime, creationEndTime, {limit, asc}) {
        return FilesDB.instance.getAllUploadedFiles(creationStartTime,
            creationEndTime, Configuration.instance.getUserID(),
            visibility: kVisibilityArchive, limit: limit, asc: asc);
      },
      reloadEvent: Bus.instance.on<FilesUpdatedEvent>().where(
            (event) =>
                event.updatedFiles.firstWhereOrNull(
                    (element) => element.uploadedFileID != null) !=
                null,
          ),
      removalEventTypes: const {EventType.unarchived},
      forceReloadEvents: [
        Bus.instance.on<FilesUpdatedEvent>().where(
              (event) =>
                  event.updatedFiles.firstWhereOrNull(
                      (element) => element.uploadedFileID != null) !=
                  null,
            ),
      ],
      tagPrefix: tagPrefix,
      selectedFiles: _selectedFiles,
      initialFiles: null,
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50.0),
        child: GalleryAppBarWidget(
          appBarType,
          "archive",
          _selectedFiles,
        ),
      ),
      body: gallery,
    );
  }
}
