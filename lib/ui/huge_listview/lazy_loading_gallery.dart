import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/constants.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/clear_selections_event.dart';
import 'package:photos/events/files_updated_event.dart';
import 'package:photos/extensions/string_ext.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/huge_listview/place_holder_widget.dart';
import 'package:photos/ui/viewer/file/detail_page.dart';
import 'package:photos/ui/viewer/file/thumbnail_widget.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import 'package:photos/utils/date_time_util.dart';
import 'package:photos/utils/navigation_util.dart';
import 'package:visibility_detector/visibility_detector.dart';

class LazyLoadingGallery extends StatefulWidget {
  final List<File> files;
  final int index;
  final Stream<FilesUpdatedEvent>? reloadEvent;
  final Set<EventType> removalEventTypes;
  final GalleryLoader asyncLoader;
  final SelectedFiles selectedFiles;
  final String tag;
  final String? logTag;
  final Stream<int> currentIndexStream;
  final int? photoGirdSize;

  LazyLoadingGallery(
    this.files,
    this.index,
    this.reloadEvent,
    this.removalEventTypes,
    this.asyncLoader,
    this.selectedFiles,
    this.tag,
    this.currentIndexStream, {
    this.logTag = "",
    this.photoGirdSize = photoGridSizeDefault,
    Key? key,
  }) : super(key: key ?? UniqueKey());

  @override
  State<LazyLoadingGallery> createState() => _LazyLoadingGalleryState();
}

class _LazyLoadingGalleryState extends State<LazyLoadingGallery> {
  static const kRecycleLimit = 400;
  static const kNumberOfDaysToRenderBeforeAndAfter = 8;

  late Logger _logger;

  late List<File> _files;
  late StreamSubscription<FilesUpdatedEvent> _reloadEventSubscription;
  late StreamSubscription<int> _currentIndexSubscription;
  bool? _shouldRender;
  final ValueNotifier<bool> _toggleSelectAllFromDay = ValueNotifier(false);
  final ValueNotifier<bool> _showSelectAllButton = ValueNotifier(false);
  final ValueNotifier<bool> _areAllFromDaySelected = ValueNotifier(false);

  @override
  void initState() {
    //this is for removing the 'select all from day' icon on unselecting all files with 'cancel'
    widget.selectedFiles.addListener(_selectedFilesListener);
    super.initState();
    _init();
  }

  void _init() {
    _logger = Logger("LazyLoading_${widget.logTag}");
    _shouldRender = true;
    _files = widget.files;
    _reloadEventSubscription = widget.reloadEvent!.listen((e) => _onReload(e));

    _currentIndexSubscription =
        widget.currentIndexStream.listen((currentIndex) {
      final bool shouldRender = (currentIndex - widget.index).abs() <
          kNumberOfDaysToRenderBeforeAndAfter;
      if (mounted && shouldRender != _shouldRender) {
        setState(() {
          _shouldRender = shouldRender;
        });
      }
    });
  }

  Future _onReload(FilesUpdatedEvent event) async {
    final galleryDate =
        DateTime.fromMicrosecondsSinceEpoch(_files[0].creationTime!);
    final filesUpdatedThisDay = event.updatedFiles.where((file) {
      final fileDate = DateTime.fromMicrosecondsSinceEpoch(file.creationTime!);
      return fileDate.year == galleryDate.year &&
          fileDate.month == galleryDate.month &&
          fileDate.day == galleryDate.day;
    });
    if (filesUpdatedThisDay.isNotEmpty) {
      if (kDebugMode) {
        _logger.info(
          filesUpdatedThisDay.length.toString() +
              " files were updated due to ${event.reason} on " +
              getDayTitle(galleryDate.microsecondsSinceEpoch),
        );
      }
      if (event.type == EventType.addedOrUpdated) {
        final dayStartTime =
            DateTime(galleryDate.year, galleryDate.month, galleryDate.day);
        final result = await widget.asyncLoader(
          dayStartTime.microsecondsSinceEpoch,
          dayStartTime.microsecondsSinceEpoch + microSecondsInDay - 1,
        );
        if (mounted) {
          setState(() {
            _files = result.files;
          });
        }
      } else if (widget.removalEventTypes.contains(event.type)) {
        // Files were removed
        final generatedFileIDs = <int?>{};
        final uploadedFileIds = <int?>{};
        for (final file in filesUpdatedThisDay) {
          if (file.generatedID != null) {
            generatedFileIDs.add(file.generatedID);
          } else if (file.uploadedFileID != null) {
            uploadedFileIds.add(file.uploadedFileID);
          }
        }
        final List<File> files = [];
        files.addAll(_files);
        files.removeWhere(
          (file) =>
              generatedFileIDs.contains(file.generatedID) ||
              uploadedFileIds.contains(file.uploadedFileID),
        );
        if (kDebugMode) {
          _logger.finest(
            "removed ${_files.length - files.length} due to ${event.reason}",
          );
        }
        if (mounted) {
          setState(() {
            _files = files;
          });
        }
      } else {
        if (kDebugMode) {
          debugPrint("Unexpected event ${event.type.name}");
        }
      }
    }
  }

  @override
  void dispose() {
    _reloadEventSubscription.cancel();
    _currentIndexSubscription.cancel();
    widget.selectedFiles.removeListener(_selectedFilesListener);
    _toggleSelectAllFromDay.dispose();
    _showSelectAllButton.dispose();
    _areAllFromDaySelected.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LazyLoadingGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_files, widget.files)) {
      _reloadEventSubscription.cancel();
      _init();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            getDayWidget(
              context,
              _files[0].creationTime!,
              widget.photoGirdSize!,
            ),
            ValueListenableBuilder(
              valueListenable: _showSelectAllButton,
              builder: (context, dynamic value, _) {
                return !value
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        child: SizedBox(
                          width: 48,
                          height: 44,
                          child: ValueListenableBuilder(
                            valueListenable: _areAllFromDaySelected,
                            builder: (context, dynamic value, _) {
                              return value
                                  ? const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                    )
                                  : Icon(
                                      Icons.check_circle_outlined,
                                      color: getEnteColorScheme(context)
                                          .strokeMuted,
                                      size: 18,
                                    );
                            },
                          ),
                        ),
                        onTap: () {
                          //this value has no significance
                          //changing only to notify the listeners
                          _toggleSelectAllFromDay.value =
                              !_toggleSelectAllFromDay.value;
                        },
                      );
              },
            )
          ],
        ),
        _shouldRender!
            ? _getGallery()
            : PlaceHolderWidget(
                _files.length,
                widget.photoGirdSize!,
              ),
      ],
    );
  }

  Widget _getGallery() {
    final List<Widget> childGalleries = [];
    final subGalleryItemLimit = widget.photoGirdSize! < photoGridSizeDefault
        ? subGalleryLimitMin
        : subGalleryLimitDefault;
    for (int index = 0; index < _files.length; index += subGalleryItemLimit) {
      childGalleries.add(
        LazyLoadingGridView(
          widget.tag,
          _files.sublist(
            index,
            min(index + subGalleryItemLimit, _files.length),
          ),
          widget.asyncLoader,
          widget.selectedFiles,
          index == 0,
          _files.length > kRecycleLimit,
          _toggleSelectAllFromDay,
          _areAllFromDaySelected,
          widget.photoGirdSize,
        ),
      );
    }

    return Column(
      children: childGalleries,
    );
  }

  void _selectedFilesListener() {
    if (widget.selectedFiles.files.isEmpty) {
      _showSelectAllButton.value = false;
    } else {
      _showSelectAllButton.value = true;
    }
  }
}

class LazyLoadingGridView extends StatefulWidget {
  final String tag;
  final List<File> filesInDay;
  final GalleryLoader asyncLoader;
  final SelectedFiles selectedFiles;
  final bool shouldRender;
  final bool shouldRecycle;
  final ValueNotifier toggleSelectAllFromDay;
  final ValueNotifier areAllFilesSelected;
  final int? photoGridSize;

  LazyLoadingGridView(
    this.tag,
    this.filesInDay,
    this.asyncLoader,
    this.selectedFiles,
    this.shouldRender,
    this.shouldRecycle,
    this.toggleSelectAllFromDay,
    this.areAllFilesSelected,
    this.photoGridSize, {
    Key? key,
  }) : super(key: key ?? UniqueKey());

  @override
  State<LazyLoadingGridView> createState() => _LazyLoadingGridViewState();
}

class _LazyLoadingGridViewState extends State<LazyLoadingGridView> {
  bool? _shouldRender;
  int? _currentUserID;
  late StreamSubscription<ClearSelectionsEvent> _clearSelectionsEvent;

  @override
  void initState() {
    _shouldRender = widget.shouldRender;
    _currentUserID = Configuration.instance.getUserID();
    widget.selectedFiles.addListener(_selectedFilesListener);
    _clearSelectionsEvent =
        Bus.instance.on<ClearSelectionsEvent>().listen((event) {
      if (mounted) {
        setState(() {});
      }
    });
    widget.toggleSelectAllFromDay.addListener(_toggleSelectAllFromDayListener);
    super.initState();
  }

  @override
  void dispose() {
    widget.selectedFiles.removeListener(_selectedFilesListener);
    _clearSelectionsEvent.cancel();
    widget.toggleSelectAllFromDay
        .removeListener(_toggleSelectAllFromDayListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(LazyLoadingGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.filesInDay, oldWidget.filesInDay)) {
      _shouldRender = widget.shouldRender;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shouldRecycle) {
      return _getRecyclableView();
    } else {
      return _getNonRecyclableView();
    }
  }

  Widget _getRecyclableView() {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (visibility) {
        final shouldRender = visibility.visibleFraction > 0;
        if (mounted && shouldRender != _shouldRender) {
          setState(() {
            _shouldRender = shouldRender;
          });
        }
      },
      child: _shouldRender!
          ? _getGridView()
          : PlaceHolderWidget(widget.filesInDay.length, widget.photoGridSize!),
    );
  }

  Widget _getNonRecyclableView() {
    if (!_shouldRender!) {
      return VisibilityDetector(
        key: UniqueKey(),
        onVisibilityChanged: (visibility) {
          if (mounted && visibility.visibleFraction > 0 && !_shouldRender!) {
            setState(() {
              _shouldRender = true;
            });
          }
        },
        child:
            PlaceHolderWidget(widget.filesInDay.length, widget.photoGridSize!),
      );
    } else {
      return _getGridView();
    }
  }

  Widget _getGridView() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // to disable GridView's scrolling
      itemBuilder: (context, index) {
        return _buildFile(context, widget.filesInDay[index]);
      },
      itemCount: widget.filesInDay.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        crossAxisCount: widget.photoGridSize!,
      ),
      padding: const EdgeInsets.all(0),
    );
  }

  Widget _buildFile(BuildContext context, File file) {
    final isFileSelected = widget.selectedFiles.isFileSelected(file);
    Color selectionColor = Colors.white;
    if (isFileSelected &&
        file.isUploaded &&
        (file.ownerID != _currentUserID ||
            file.pubMagicMetadata!.uploaderName != null)) {
      final avatarColors = getEnteColorScheme(context).avatarColors;
      final int randomID = file.ownerID != _currentUserID
          ? file.ownerID!
          : file.pubMagicMetadata!.uploaderName.sumAsciiValues;
      selectionColor = avatarColors[(randomID).remainder(avatarColors.length)];
    }
    return GestureDetector(
      onTap: () {
        if (widget.selectedFiles.files.isNotEmpty) {
          _selectFile(file);
        } else {
          _routeToDetailPage(file, context);
        }
      },
      onLongPress: () {
        HapticFeedback.lightImpact();
        _selectFile(file);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: Stack(
          children: [
            Hero(
              tag: widget.tag + file.tag,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(
                    isFileSelected ? 0.4 : 0,
                  ),
                  BlendMode.darken,
                ),
                child: ThumbnailWidget(
                  file,
                  diskLoadDeferDuration: thumbnailDiskLoadDeferDuration,
                  serverLoadDeferDuration: thumbnailServerLoadDeferDuration,
                  shouldShowLivePhotoOverlay: true,
                  key: Key(widget.tag + file.tag),
                  thumbnailSize: widget.photoGridSize! < photoGridSizeDefault
                      ? thumbnailLargeSize
                      : thumbnailSmallSize,
                  shouldShowOwnerAvatar: !isFileSelected,
                ),
              ),
            ),
            Visibility(
              visible: isFileSelected,
              child: Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: selectionColor, //same for both themes
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _selectFile(File file) {
    widget.selectedFiles.toggleSelection(file);
  }

  void _routeToDetailPage(File file, BuildContext context) {
    final page = DetailPage(
      DetailPageConfiguration(
        List.unmodifiable(widget.filesInDay),
        widget.asyncLoader,
        widget.filesInDay.indexOf(file),
        widget.tag,
      ),
    );
    routeToPage(context, page, forceCustomPageRoute: true);
  }

  void _selectedFilesListener() {
    if (widget.selectedFiles.files.containsAll(widget.filesInDay.toSet())) {
      widget.areAllFilesSelected.value = true;
    } else {
      widget.areAllFilesSelected.value = false;
    }
    bool shouldRefresh = false;
    for (final file in widget.filesInDay) {
      if (widget.selectedFiles.isPartOfLastSelected(file)) {
        shouldRefresh = true;
      }
    }
    if (shouldRefresh && mounted) {
      setState(() {});
    }
  }

  void _toggleSelectAllFromDayListener() {
    if (widget.selectedFiles.files.containsAll(widget.filesInDay.toSet())) {
      setState(() {
        widget.selectedFiles
            .unSelectAll(widget.filesInDay.toSet() as Set<File>);
      });
    } else {
      widget.selectedFiles.selectAll(widget.filesInDay.toSet() as Set<File>);
    }
  }
}
