import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/event.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/file_load_result.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/ui/common_elements.dart';
import 'package:photos/ui/huge_listview/huge_listview.dart';
import 'package:photos/ui/huge_listview/lazy_loading_gallery.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/utils/date_time_util.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

typedef GalleryLoader = Future<FileLoadResult>
    Function(int creationStartTime, int creationEndTime, {int? limit, bool? asc});

class Gallery extends StatefulWidget {
  final GalleryLoader asyncLoader;
  final List<File?>? initialFiles;
  final Stream<FilesUpdatedEvent>? reloadEvent;
  final List<Stream<Event>>? forceReloadEvents;
  final Set<EventType> removalEventTypes;
  final SelectedFiles selectedFiles;
  final String tagPrefix;
  final Widget? header;
  final Widget? footer;

  Gallery({
    required this.asyncLoader,
    required this.selectedFiles,
    required this.tagPrefix,
    this.initialFiles,
    this.reloadEvent,
    this.forceReloadEvents,
    this.removalEventTypes = const {},
    this.header,
    this.footer,
    Key? key,
  }) : super(key: key);

  @override
  _GalleryState createState() {
    return _GalleryState();
  }
}

class _GalleryState extends State<Gallery> {
  static const int kInitialLoadLimit = 100;

  final _hugeListViewKey = GlobalKey<HugeListViewState>();

  late Logger _logger;
  List<List<File?>> _collatedFiles = [];
  bool _hasLoadedFiles = false;
  StreamSubscription<FilesUpdatedEvent>? _reloadEventSubscription;
  final _forceReloadEventSubscriptions = <StreamSubscription<Event>>[];

  @override
  void initState() {
    _logger = Logger("Gallery_" + widget.tagPrefix);
    _logger.info("initState");
    if (widget.reloadEvent != null) {
      _reloadEventSubscription = widget.reloadEvent!.listen((event) async {
        _logger.info("Building gallery because reload event fired");
        final result = await _loadFiles();
        _onFilesLoaded(result.files);
      });
    }
    if (widget.forceReloadEvents != null) {
      for (final event in widget.forceReloadEvents!) {
        _forceReloadEventSubscriptions.add(event.listen((event) async {
          _logger.info("Force reload triggered");
          final result = await _loadFiles();
          _setFilesAndReload(result.files);
        }));
      }
    }
    if (widget.initialFiles != null) {
      _onFilesLoaded(widget.initialFiles!);
    }
    _loadFiles(limit: kInitialLoadLimit).then((result) async {
      _setFilesAndReload(result.files);
      if (result.hasMore) {
        final result = await _loadFiles();
        _setFilesAndReload(result.files);
      }
    });
    super.initState();
  }

  void _setFilesAndReload(List<File> files) {
    final hasReloaded = _onFilesLoaded(files);
    if (!hasReloaded && mounted) {
      setState(() {});
    }
  }

  Future<FileLoadResult> _loadFiles({int? limit}) async {
    _logger.info("Loading files");
    try {
      final startTime = DateTime.now().microsecondsSinceEpoch;
      final result = await widget.asyncLoader(
          kGalleryLoadStartTime, DateTime.now().microsecondsSinceEpoch,
          limit: limit);
      final endTime = DateTime.now().microsecondsSinceEpoch;
      final duration = Duration(microseconds: endTime - startTime);
      _logger.info("Time taken to load " +
          result.files.length.toString() +
          " files :" +
          duration.inMilliseconds.toString() +
          "ms");
      return result;
    } catch (e, s) {
      _logger.severe("failed to load files", e, s);
      rethrow;
    }
  }

  // Collates files and returns `true` if it resulted in a gallery reload
  bool _onFilesLoaded(List<File?> files) {
    final collatedFiles = _collateFiles(files);
    if (_collatedFiles.length != collatedFiles.length ||
        _collatedFiles.isEmpty) {
      if (mounted) {
        setState(() {
          _hasLoadedFiles = true;
          _collatedFiles = collatedFiles;
        });
      }
      return true;
    } else {
      _collatedFiles = collatedFiles;
      return false;
    }
  }

  @override
  void dispose() {
    _reloadEventSubscription?.cancel();
    for (final subscription in _forceReloadEventSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.info("Building " + widget.tagPrefix);
    if (!_hasLoadedFiles) {
      return loadWidget;
    }
    return _getListView();
  }

  Widget _getListView() {
    return HugeListView<List<File>>(
      key: _hugeListViewKey,
      controller: ItemScrollController(),
      startIndex: 0,
      totalCount: _collatedFiles.length,
      isDraggableScrollbarEnabled: _collatedFiles.length > 30,
      waitBuilder: (_) {
        return loadWidget;
      },
      emptyResultBuilder: (_) {
        List<Widget> children = [];
        if (widget.header != null) {
          children.add(widget.header!);
        }
        children.add(Expanded(child: nothingToSeeHere));
        if (widget.footer != null) {
          children.add(widget.footer!);
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        );
      },
      itemBuilder: (context, index) {
        Widget gallery;
        gallery = LazyLoadingGallery(
          _collatedFiles[index],
          index,
          widget.reloadEvent,
          widget.removalEventTypes,
          widget.asyncLoader,
          widget.selectedFiles,
          widget.tagPrefix,
          Bus.instance
              .on<GalleryIndexUpdatedEvent>()
              .where((event) => event.tag == widget.tagPrefix)
              .map((event) => event.index),
        );
        if (widget.header != null && index == 0) {
          gallery = Column(children: [widget.header!, gallery]);
        }
        if (widget.footer != null && index == _collatedFiles.length - 1) {
          gallery = Column(children: [gallery, widget.footer!]);
        }
        return gallery;
      },
      labelTextBuilder: (int index) {
        return getMonthAndYear(DateTime.fromMicrosecondsSinceEpoch(
            _collatedFiles[index][0]!.creationTime!));
      },
      thumbBackgroundColor: Color(0xFF151515),
      thumbDrawColor: Colors.white.withOpacity(0.5),
      firstShown: (int firstIndex) {
        Bus.instance
            .fire(GalleryIndexUpdatedEvent(widget.tagPrefix, firstIndex));
      },
    );
  }

  List<List<File?>> _collateFiles(List<File?> files) {
    final List<File?> dailyFiles = [];
    final List<List<File?>> collatedFiles = [];
    for (int index = 0; index < files.length; index++) {
      if (index > 0 &&
          !_areFromSameDay(
              files[index - 1]!.creationTime!, files[index]!.creationTime!)) {
        final List<File?> collatedDailyFiles = [];
        collatedDailyFiles.addAll(dailyFiles);
        collatedFiles.add(collatedDailyFiles);
        dailyFiles.clear();
      }
      dailyFiles.add(files[index]);
    }
    if (dailyFiles.isNotEmpty) {
      collatedFiles.add(dailyFiles);
    }
    collatedFiles
        .sort((a, b) => b[0]!.creationTime!.compareTo(a[0]!.creationTime!));
    return collatedFiles;
  }

  bool _areFromSameDay(int firstCreationTime, int secondCreationTime) {
    var firstDate = DateTime.fromMicrosecondsSinceEpoch(firstCreationTime);
    var secondDate = DateTime.fromMicrosecondsSinceEpoch(secondCreationTime);
    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }
}

class GalleryIndexUpdatedEvent {
  final String tag;
  final int index;

  GalleryIndexUpdatedEvent(this.tag, this.index);
}
