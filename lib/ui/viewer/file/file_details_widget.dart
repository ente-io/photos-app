import "package:exif/exif.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:photos/core/configuration.dart";
import "package:photos/ente_theme_data.dart";
import "package:photos/models/file.dart";
import "package:photos/models/file_type.dart";
import 'package:photos/services/collections_service.dart';
import "package:photos/services/feature_flag_service.dart";
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/components/buttons/icon_button_widget.dart';
import 'package:photos/ui/components/title_bar_widget.dart';
import 'package:photos/ui/viewer/file/file_caption_widget.dart';
import "package:photos/ui/viewer/file_details/albums_item_widget.dart";
import 'package:photos/ui/viewer/file_details/backed_up_time_item_widget.dart';
import "package:photos/ui/viewer/file_details/creation_time_item_widget.dart";
import 'package:photos/ui/viewer/file_details/exif_item_widgets.dart';
import "package:photos/ui/viewer/file_details/file_details_divider_widget.dart";
import "package:photos/ui/viewer/file_details/file_properties_item_widget.dart";
import "package:photos/ui/viewer/file_details/objects_item_widget.dart";
import "package:photos/utils/exif_util.dart";

class FileDetailsWidget extends StatefulWidget {
  final File file;
  const FileDetailsWidget(
    this.file, {
    Key? key,
  }) : super(key: key);

  @override
  State<FileDetailsWidget> createState() => _FileDetailsWidgetState();
}

class _FileDetailsWidgetState extends State<FileDetailsWidget> {
  final ValueNotifier<Map<String, IfdTag>?> _exifNotifier = ValueNotifier(null);
  final Map<String, dynamic> _exifData = {
    "focalLength": null,
    "fNumber": null,
    "resolution": null,
    "takenOnDevice": null,
    "exposureTime": null,
    "ISO": null,
    "megaPixels": null
  };

  bool _isImage = false;
  late int _currentUserID;
  bool showExifListTile = false;

  @override
  void initState() {
    debugPrint('file_details_sheet initState');
    _currentUserID = Configuration.instance.getUserID()!;
    _isImage = widget.file.fileType == FileType.image ||
        widget.file.fileType == FileType.livePhoto;
    if (_isImage) {
      _exifNotifier.addListener(() {
        if (_exifNotifier.value != null) {
          _generateExifForDetails(_exifNotifier.value!);
        }
        showExifListTile = _exifData["focalLength"] != null ||
            _exifData["fNumber"] != null ||
            _exifData["takenOnDevice"] != null ||
            _exifData["exposureTime"] != null ||
            _exifData["ISO"] != null;
      });
      getExif(widget.file).then((exif) {
        _exifNotifier.value = exif;
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    _exifNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final bool isFileOwner =
        file.ownerID == null || file.ownerID == _currentUserID;

    //Make sure the bottom most tile is always the same one, that is it should
    //not be rendered only if a condition is met.
    final fileDetailsTiles = <Widget>[];
    fileDetailsTiles.add(
      !widget.file.isUploaded ||
              (!isFileOwner && (widget.file.caption?.isEmpty ?? true))
          ? const SizedBox(height: 16)
          : Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: isFileOwner
                  ? FileCaptionWidget(file: widget.file)
                  : FileCaptionReadyOnly(caption: widget.file.caption!),
            ),
    );
    fileDetailsTiles.addAll([
      CreationTimeItem(file, _currentUserID),
      const FileDetialsDividerWidget(),
      ValueListenableBuilder(
        valueListenable: _exifNotifier,
        builder: (context, _, __) => FilePropertiesItemWidget(
          file,
          _isImage,
          _exifData,
          _currentUserID,
        ),
      ),
      const FileDetialsDividerWidget(),
    ]);
    fileDetailsTiles.add(
      ValueListenableBuilder(
        valueListenable: _exifNotifier,
        builder: (context, value, _) {
          return showExifListTile
              ? Column(
                  children: [
                    BasicExifItemWidget(_exifData),
                    const FileDetialsDividerWidget(),
                  ],
                )
              : const SizedBox.shrink();
        },
      ),
    );
    if (_isImage) {
      fileDetailsTiles.addAll([
        ValueListenableBuilder(
          valueListenable: _exifNotifier,
          builder: (context, value, _) {
            return Column(
              children: [
                AllExifItemWidget(file, _exifNotifier.value),
                const FileDetialsDividerWidget()
              ],
            );
          },
        )
      ]);
    }
    if (FeatureFlagService.instance.isInternalUserOrDebugBuild()) {
      fileDetailsTiles
          .addAll([ObjectsItemWidget(file), const FileDetialsDividerWidget()]);
    }
    if (file.uploadedFileID != null && file.updationTime != null) {
      fileDetailsTiles.addAll(
          [BackedUpTimeItemWidget(file), const FileDetialsDividerWidget()]);
    }
    fileDetailsTiles.add(AlbumsItemWidget(file, _currentUserID));

    return SafeArea(
      top: false,
      child: Scrollbar(
        thickness: 4,
        radius: const Radius.circular(2),
        thumbVisibility: true,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            shrinkWrap: true,
            slivers: <Widget>[
              TitleBarWidget(
                isFlexibleSpaceDisabled: true,
                title: "Details",
                isOnTopOfScreen: false,
                backgroundColor: getEnteColorScheme(context).backgroundElevated,
                leading: IconButtonWidget(
                  icon: Icons.expand_more_outlined,
                  iconButtonType: IconButtonType.primary,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(child: addedBy(widget.file)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return fileDetailsTiles[index];
                  },
                  childCount: fileDetailsTiles.length,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget addedBy(File file) {
    if (file.uploadedFileID == null) {
      return const SizedBox.shrink();
    }
    String? addedBy;
    if (file.ownerID == _currentUserID) {
      if (file.pubMagicMetadata!.uploaderName != null) {
        addedBy = file.pubMagicMetadata!.uploaderName;
      }
    } else {
      final fileOwner = CollectionsService.instance
          .getFileOwner(file.ownerID!, file.collectionID);
      addedBy = fileOwner.email;
    }
    if (addedBy == null || addedBy.isEmpty) {
      return const SizedBox.shrink();
    }
    final enteTheme = Theme.of(context).colorScheme.enteTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0, left: 16),
      child: Text(
        "Added by $addedBy",
        style: enteTheme.textTheme.mini
            .copyWith(color: enteTheme.colorScheme.textMuted),
      ),
    );
  }

  _generateExifForDetails(Map<String, IfdTag> exif) {
    if (exif["EXIF FocalLength"] != null) {
      _exifData["focalLength"] =
          (exif["EXIF FocalLength"]!.values.toList()[0] as Ratio).numerator /
              (exif["EXIF FocalLength"]!.values.toList()[0] as Ratio)
                  .denominator;
    }

    if (exif["EXIF FNumber"] != null) {
      _exifData["fNumber"] =
          (exif["EXIF FNumber"]!.values.toList()[0] as Ratio).numerator /
              (exif["EXIF FNumber"]!.values.toList()[0] as Ratio).denominator;
    }
    final imageWidth = exif["EXIF ExifImageWidth"] ?? exif["Image ImageWidth"];
    final imageLength = exif["EXIF ExifImageLength"] ??
        exif["Image "
            "ImageLength"];
    if (imageWidth != null && imageLength != null) {
      _exifData["resolution"] = '$imageWidth x $imageLength';
      _exifData['megaPixels'] =
          ((imageWidth.values.firstAsInt() * imageLength.values.firstAsInt()) /
                  1000000)
              .toStringAsFixed(1);
    } else {
      debugPrint("No image width/height");
    }
    if (exif["Image Make"] != null && exif["Image Model"] != null) {
      _exifData["takenOnDevice"] =
          exif["Image Make"].toString() + " " + exif["Image Model"].toString();
    }

    if (exif["EXIF ExposureTime"] != null) {
      _exifData["exposureTime"] = exif["EXIF ExposureTime"].toString();
    }
    if (exif["EXIF ISOSpeedRatings"] != null) {
      _exifData['ISO'] = exif["EXIF ISOSpeedRatings"].toString();
    }
  }
}
