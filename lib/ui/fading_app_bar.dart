import 'dart:io';
import 'dart:io' as io;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:like_button/like_button.dart';
import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/local_photos_updated_event.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/file_type.dart';
import 'package:photos/models/trash_file.dart';
import 'package:photos/services/favorites_service.dart';
import 'package:photos/services/local_sync_service.dart';
import 'package:photos/ui/custom_app_bar.dart';
import 'package:photos/ui/progress_dialog.dart';
import 'package:photos/utils/date_time_util.dart';
import 'package:photos/utils/delete_file_util.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/file_util.dart';
import 'package:photos/utils/magic_util.dart';
import 'package:photos/utils/toast_util.dart';

class FadingAppBar extends StatefulWidget implements PreferredSizeWidget {
  final File file;
  final Function(File) onFileDeleted;
  final double height;
  final bool shouldShowActions;
  final int? userID;

  FadingAppBar(
    this.file,
    this.onFileDeleted,
    this.userID,
    this.height,
    this.shouldShowActions, {
    Key? key,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  FadingAppBarState createState() => FadingAppBarState();
}

class FadingAppBarState extends State<FadingAppBar> {
  final _logger = Logger("FadingAppBar");
  bool _shouldHide = false;

  @override
  Widget build(BuildContext context) {
    return CustomAppBar(
      AnimatedOpacity(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.64),
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
              stops: const [0, 0.2, 1],
            ),
          ),
          child: _buildAppBar(),
        ),
        opacity: _shouldHide ? 0 : 1,
        duration: Duration(milliseconds: 150),
      ),
      height: 100,
    );
  }

  void hide() {
    setState(() {
      _shouldHide = true;
    });
  }

  void show() {
    if (mounted) {
      setState(() {
        _shouldHide = false;
      });
    }
  }

  AppBar _buildAppBar() {
    final List<Widget> actions = [];
    final isTrashedFile = widget.file is TrashFile;
    final shouldShowActions = widget.shouldShowActions && !isTrashedFile;
    // only show fav option for files owned by the user
    if (widget.file.ownerID == null || widget.file.ownerID == widget.userID) {
      actions.add(_getFavoriteButton());
    }
    actions.add(PopupMenuButton(
      itemBuilder: (context) {
        final List<PopupMenuItem> items = [];
        if (widget.file.isRemoteFile()) {
          items.add(
            PopupMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(Platform.isAndroid
                      ? Icons.download
                      : CupertinoIcons.cloud_download),
                  Padding(
                    padding: EdgeInsets.all(8),
                  ),
                  Text("download"),
                ],
              ),
            ),
          );
        }
        // options for files owned by the user
        if (widget.file.ownerID == null ||
            widget.file.ownerID == widget.userID) {
          if (widget.file.uploadedFileID != null) {
            items.add(
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Platform.isAndroid
                        ? Icons.access_time_rounded
                        : CupertinoIcons.time),
                    Padding(
                      padding: EdgeInsets.all(8),
                    ),
                    Text("edit time"),
                  ],
                ),
              ),
            );
          }

          items.add(
            PopupMenuItem(
              value: 3,
              child: Row(
                children: [
                  Icon(Platform.isAndroid
                      ? Icons.delete_outline
                      : CupertinoIcons.delete),
                  Padding(
                    padding: EdgeInsets.all(8),
                  ),
                  Text("delete"),
                ],
              ),
            ),
          );
        }
        return items;
      },
      onSelected: (dynamic value) {
        if (value == 1) {
          _download(widget.file);
        } else if (value == 2) {
          _showDateTimePicker(widget.file);
        } else if (value == 3) {
          _showDeleteSheet(widget.file);
        }
      },
    ));
    return AppBar(
      title: Text(
        getDayTitle(widget.file.creationTime!),
        style: TextStyle(
          fontSize: 14,
        ),
      ),
      actions: shouldShowActions ? actions : [],
      backgroundColor: Color(0x00000000),
      elevation: 0,
    );
  }

  Widget _getFavoriteButton() {
    return FutureBuilder<bool>(
      future: FavoritesService.instance.isFavorite(widget.file),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _getLikeButton(widget.file, snapshot.data);
        } else {
          return _getLikeButton(widget.file, false);
        }
      },
    );
  }

  Widget _getLikeButton(File file, bool? isLiked) {
    return LikeButton(
      isLiked: isLiked,
      onTap: (oldValue) async {
        final isLiked = !oldValue;
        bool hasError = false;
        if (isLiked) {
          final shouldBlockUser = file.uploadedFileID == null;
          late ProgressDialog dialog;
          if (shouldBlockUser) {
            dialog = createProgressDialog(context, "adding to favorites...");
            await dialog.show();
          }
          try {
            await FavoritesService.instance.addToFavorites(file);
          } catch (e, s) {
            _logger.severe(e, s);
            hasError = true;
            showToast("sorry, could not add this to favorites!");
          } finally {
            if (shouldBlockUser) {
              await dialog.hide();
            }
          }
        } else {
          try {
            await FavoritesService.instance.removeFromFavorites(file);
          } catch (e, s) {
            _logger.severe(e, s);
            hasError = true;
            showToast("sorry, could not remove this from favorites!");
          }
        }
        return hasError ? oldValue : isLiked;
      },
      likeBuilder: (isLiked) {
        return Icon(
          Icons.favorite_border,
          color: isLiked ? Colors.pinkAccent : Colors.white,
          size: 24,
        );
      },
    );
  }

  void _showDateTimePicker(File file) async {
    final dateResult = await DatePicker.showDatePicker(
      context,
      minTime: DateTime(1800, 1, 1),
      maxTime: DateTime.now(),
      currentTime: DateTime.fromMicrosecondsSinceEpoch(file.creationTime!),
      locale: LocaleType.en,
      theme: kDatePickerTheme,
    );
    if (dateResult == null) {
      return;
    }
    final dateWithTimeResult = await DatePicker.showTime12hPicker(
      context,
      showTitleActions: true,
      currentTime: dateResult,
      locale: LocaleType.en,
      theme: kDatePickerTheme,
    );
    if (dateWithTimeResult != null) {
      if (await editTime(context, List.of([widget.file]),
          dateWithTimeResult.microsecondsSinceEpoch)) {
        widget.file.creationTime = dateWithTimeResult.microsecondsSinceEpoch;
        setState(() {});
      }
    }
  }

  void _showDeleteSheet(File file) {
    final List<Widget> actions = [];
    if (file.uploadedFileID == null || file.localID == null) {
      actions.add(CupertinoActionSheetAction(
        child: Text("everywhere"),
        isDestructiveAction: true,
        onPressed: () async {
          await deleteFilesFromEverywhere(context, [file]);
          Navigator.of(context, rootNavigator: true).pop();
          widget.onFileDeleted(file);
        },
      ));
    } else {
      // uploaded file which is present locally too
      actions.add(CupertinoActionSheetAction(
        child: Text("device"),
        isDestructiveAction: true,
        onPressed: () async {
          await deleteFilesOnDeviceOnly(context, [file]);
          showToast("file deleted from device");
          Navigator.of(context, rootNavigator: true).pop();
          // TODO: Fix behavior when inside a device folder
        },
      ));

      actions.add(CupertinoActionSheetAction(
        child: Text("ente"),
        isDestructiveAction: true,
        onPressed: () async {
          await deleteFilesFromRemoteOnly(context, [file]);
          showShortToast("moved to trash");
          Navigator.of(context, rootNavigator: true).pop();
          // TODO: Fix behavior when inside a collection
        },
      ));

      actions.add(CupertinoActionSheetAction(
        child: Text("everywhere"),
        isDestructiveAction: true,
        onPressed: () async {
          await deleteFilesFromEverywhere(context, [file]);
          Navigator.of(context, rootNavigator: true).pop();
          widget.onFileDeleted(file);
        },
      ));
    }
    final action = CupertinoActionSheet(
      title: Text("delete file?"),
      actions: actions,
      cancelButton: CupertinoActionSheetAction(
        child: Text("cancel"),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (_) => action);
  }

  Future<void> _download(File file) async {
    final dialog = createProgressDialog(context, "downloading...");
    await dialog.show();
    FileType? type = file.fileType;
    // save and track image for livePhoto/image and video for FileType.video
    io.File? fileToSave = await getFile(file);
    final savedAsset = type == FileType.video
        ? await (PhotoManager.editor.saveVideo(fileToSave!, title: file.title))
        : await PhotoManager.editor
            .saveImageWithPath(fileToSave!.path, title: file.title);
    // immediately track assetID to avoid duplicate upload
    await LocalSyncService.instance.trackDownloadedFile(savedAsset!.id);
    file.localID = savedAsset.id;
    await FilesDB.instance.insert(file);

    if (type == FileType.livePhoto) {
      io.File? liveVideo = await getFileFromServer(file, liveVideo: true);
      if (liveVideo == null) {
        _logger.warning("Failed to find live video" + file.tag());
      } else {
        final savedAsset = await (PhotoManager.editor.saveVideo(liveVideo));
        // in case of livePhoto, file.localID only points the image asset.
        // ignore the saved video asset for live photo from future downloads
        await LocalSyncService.instance.trackDownloadedFile(savedAsset!.id);
      }
    }

    Bus.instance.fire(LocalPhotosUpdatedEvent([file]));
    await dialog.hide();
    if (file.fileType == FileType.livePhoto) {
      showToast("photo and video saved to gallery");
    } else {
      showToast("file saved to gallery");
    }
  }
}

const kDatePickerTheme = DatePickerTheme(
  backgroundColor: Colors.black,
  itemStyle: TextStyle(
    color: Colors.white,
  ),
  cancelStyle: TextStyle(
    color: Colors.white,
  ),
);
