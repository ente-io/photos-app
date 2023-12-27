import "dart:async";

import 'package:flutter/material.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/models/file/file.dart';
import 'package:photos/models/file_load_result.dart';
import 'package:photos/models/gallery_type.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/ui/viewer/actions/file_selection_overlay_bar.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import 'package:photos/ui/viewer/gallery/gallery_app_bar_widget.dart';
import "package:photos/ui/viewer/people/add_person_action_sheet.dart";
import "package:photos/ui/viewer/search/result/search_result_page.dart";
import "package:photos/utils/toast_util.dart";

class PeoplePage extends StatefulWidget {
  final List<EnteFile> searchResult;
  final bool enableGrouping;
  final String tagPrefix;
  final int? cluserID;
  final String? personID;

  static const GalleryType appBarType = GalleryType.peopleTag;
  static const GalleryType overlayType = GalleryType.peopleTag;

  const PeoplePage(
    this.searchResult, {
    this.enableGrouping = true,
    this.tagPrefix = "",
    this.cluserID,
    this.personID,
    Key? key,
  }) : super(key: key);

  @override
  State<PeoplePage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<PeoplePage> {
  final _selectedFiles = SelectedFiles();
  late final List<EnteFile> files;
  late final StreamSubscription<LocalPhotosUpdatedEvent> _filesUpdatedEvent;

  @override
  void initState() {
    super.initState();
    files = widget.searchResult;
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

  @override
  void dispose() {
    _filesUpdatedEvent.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = Gallery(
      asyncLoader: (creationStartTime, creationEndTime, {limit, asc}) {
        final result = files
            .where(
              (file) =>
                  file.creationTime! >= creationStartTime &&
                  file.creationTime! <= creationEndTime,
            )
            .toList();
        return Future.value(
          FileLoadResult(
            result,
            result.length < files.length,
          ),
        );
      },
      reloadEvent: Bus.instance.on<LocalPhotosUpdatedEvent>(),
      removalEventTypes: const {
        EventType.deletedFromRemote,
        EventType.deletedFromEverywhere,
        EventType.hide,
      },
      tagPrefix: widget.tagPrefix + widget.tagPrefix,
      selectedFiles: _selectedFiles,
      enableFileGrouping: widget.enableGrouping,
      initialFiles: [widget.searchResult.first],
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: GestureDetector(
          onTap: () {
            if (widget.cluserID != null) {
              showAssignPersonAction(context, clusterID: widget.cluserID!);
            } else {
              showShortToast(context, "11No personID or clusterID");
            }
          },
          child: GalleryAppBarWidget(
            SearchResultPage.appBarType,
            "Add name",
            _selectedFiles,
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          gallery,
          FileSelectionOverlayBar(
            PeoplePage.overlayType,
            _selectedFiles,
          ),
        ],
      ),
    );
  }
}
