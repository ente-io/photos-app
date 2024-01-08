import "dart:async";
import "dart:developer";

import 'package:flutter/material.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import "package:photos/events/people_changed_event.dart";
import "package:photos/face/model/person.dart";
import 'package:photos/models/file/file.dart';
import 'package:photos/models/file_load_result.dart';
import 'package:photos/models/gallery_type.dart';
import 'package:photos/models/selected_files.dart';
import "package:photos/services/search_service.dart";
import 'package:photos/ui/viewer/actions/file_selection_overlay_bar.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import "package:photos/ui/viewer/people/people_app_bar.dart";

class PeoplePage extends StatefulWidget {
  final List<EnteFile> searchResult;
  final String tagPrefix;
  final Person person;

  static const GalleryType appBarType = GalleryType.peopleTag;
  static const GalleryType overlayType = GalleryType.peopleTag;

  const PeoplePage(
    this.searchResult, {
    this.tagPrefix = "",
    required this.person,
    Key? key,
  }) : super(key: key);

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _selectedFiles = SelectedFiles();
  late final List<EnteFile> files;

  late final StreamSubscription<LocalPhotosUpdatedEvent> _filesUpdatedEvent;

  @override
  void initState() {
    super.initState();

    _filesUpdatedEvent =
        Bus.instance.on<LocalPhotosUpdatedEvent>().listen((event) {
      if (event.type == EventType.deletedFromDevice ||
          event.type == EventType.deletedFromEverywhere ||
          event.type == EventType.deletedFromRemote ||
          event.type == EventType.hide) {
        for (var updatedFile in event.updatedFiles) {
          files.remove(updatedFile);
        }
        setState(() {});
      }
    });
  }

  Future<List<EnteFile>> loadPersonFiles() async {
    if (widget.searchResult.isNotEmpty) {
      files = widget.searchResult;
      return files;
    }
    log("loadPersonFiles");
    final result = await SearchService.instance
        .getClusterFilesForPersonID(widget.person.remoteID);
    final List<EnteFile> resultFiles = [];
    for (final e in result.entries) {
      resultFiles.addAll(e.value);
    }
    files = resultFiles;
    return resultFiles;
  }

  @override
  void dispose() {
    _filesUpdatedEvent.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: PeopleAppBar(
          GalleryType.peopleTag,
          widget.person.attr.name,
          _selectedFiles,
          widget.person,
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          FutureBuilder<List<EnteFile>>(
            future: loadPersonFiles(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final personFiles = snapshot.data as List<EnteFile>;
                return Gallery(
                  asyncLoader: (
                    creationStartTime,
                    creationEndTime, {
                    limit,
                    asc,
                  }) {
                    final result = personFiles
                        .where(
                          (file) =>
                              file.creationTime! >= creationStartTime &&
                              file.creationTime! <= creationEndTime,
                        )
                        .toList();
                    return Future.value(
                      FileLoadResult(
                        result,
                        result.length < personFiles.length,
                      ),
                    );
                  },
                  reloadEvent: Bus.instance.on<LocalPhotosUpdatedEvent>(),
                  forceReloadEvents: [
                    Bus.instance.on<PeopleChangedEvent>(),
                  ],
                  removalEventTypes: const {
                    EventType.deletedFromRemote,
                    EventType.deletedFromEverywhere,
                    EventType.hide,
                  },
                  tagPrefix: widget.tagPrefix + widget.tagPrefix,
                  selectedFiles: _selectedFiles,
                  initialFiles:
                      personFiles.isNotEmpty ? [personFiles.first] : [],
                );
              } else if (snapshot.hasError) {
                log("Error: ${snapshot.error} ${snapshot.stackTrace}}");
                //Need to show an error on the UI here
                return const SizedBox.shrink();
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
          FileSelectionOverlayBar(
            PeoplePage.overlayType,
            _selectedFiles,
          ),
        ],
      ),
    );
  }
}
