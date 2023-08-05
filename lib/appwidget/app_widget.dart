import "dart:convert";
import "dart:math";

import "package:collection/collection.dart";
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import "package:home_widget/home_widget.dart";
import "package:logging/logging.dart";
import "package:photo_manager/photo_manager.dart";
import "package:photos/appwidget/circle_painter.dart";
import "package:photos/appwidget/heart_painter.dart";
import "package:photos/appwidget/square_painter.dart";
import "package:photos/core/configuration.dart";
import 'package:photos/core/constants.dart';
import "package:photos/db/device_files_db.dart";
import "package:photos/db/files_db.dart";
import "package:photos/models/file.dart";
import "package:photos/services/collections_service.dart";
import "package:photos/theme/text_style.dart";
import "package:photos/ui/collections/flex_grid_view.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/utils/file_util.dart";

const shapeKey = 'shape';
const typeKey = 'type';
const recentKey = 'recent';
const collectionKey = 'collection';
const thumbnailKey = 'thumbnail';
const thumbnailIdKey = 'thumbnail_id';
const widgetIdKey = 'widget_id';
const widgetSizeKey = 'widget_size';

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
Future<void> backgroundHomeWidgetCallback() async {
  final widgetSize = (await HomeWidget.getWidgetData<int>(
    widgetSizeKey,
    defaultValue: 0,
  ))!;

  for (var widgetId = 0; widgetId < widgetSize; ++widgetId) {
    final collectionId = (await HomeWidget.getWidgetData<String>(
      '${widgetId}_$collectionKey',
      defaultValue: "",
    ))!;
    if (collectionId == "") continue;
    final isRecent = (await HomeWidget.getWidgetData<bool>(
      '${widgetId}_$recentKey',
      defaultValue: true,
    ))!;

    final collections = await _AppWidgetState.getAppWidgetCollection();
    PhotoManager.setIgnorePermissionCheck(true);
    File temp;
    final currentCollection =
        collections.firstWhere((col) => col.id == collectionId);
    if (isRecent) {
      temp = currentCollection.thumbnail;
    } else {
      final rand = Random();
      if (!currentCollection.isRemote) {
        final res = await FilesDB.instance.getDeviceCollections();
        final deviceCollection =
            res.firstWhere((col) => col.id == collectionId);
        final fileLoad = await FilesDB.instance.getFilesInDeviceCollection(
          deviceCollection,
          Configuration.instance.getUserID(),
          galleryLoadStartTime,
          galleryLoadEndTime,
        );
        temp = fileLoad.files[rand.nextInt(fileLoad.files.length)];
      } else {
        final fileLoad = await FilesDB.instance.getFilesInCollection(
          int.parse(collectionId),
          galleryLoadStartTime,
          galleryLoadEndTime,
        );
        temp = fileLoad.files[rand.nextInt(fileLoad.files.length)];
      }
    }

    final ioFile = await getFile(temp);
    final bytes = await ioFile!.readAsBytes();
    final base64 = base64Encode(bytes);

    await HomeWidget.saveWidgetData<String>(
      '${widgetId}_$thumbnailKey',
      base64,
    );
    await HomeWidget.saveWidgetData<int>(
      '${widgetId}_$thumbnailIdKey',
      temp.generatedID,
    );
    await HomeWidget.updateWidget(
      name: 'HomeScreenWidget',
      iOSName: 'HomeScreenWidget',
      qualifiedAndroidName: 'io.ente.photos.HomeScreenWidget',
    );
  }
}

class AppWidgetCollection {
  final File thumbnail;
  final String id;
  final String name;
  final bool isRemote;
  AppWidgetCollection(this.thumbnail, this.id, this.name, this.isRemote);
}

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  int selectedShape = 0;
  int selectedType = 0;
  int widgetId = 0;
  String collectionId = "";
  bool isRecent = false;
  bool isLoading = true;
  File thumbnail = File();
  List<AppWidgetCollection> collections = [];

  final _logger = Logger('_APPWIDGET');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future _sendData() async {
    try {
      await HomeWidget.saveWidgetData<String>(
        '${widgetId}_$collectionKey',
        collectionId,
      );
      await HomeWidget.saveWidgetData<int>(
        '${widgetId}_$shapeKey',
        selectedShape,
      );
      await HomeWidget.saveWidgetData<int>(
        '${widgetId}_$typeKey',
        selectedType,
      );
      await HomeWidget.saveWidgetData<bool>('${widgetId}_$recentKey', isRecent);

      await HomeWidget.saveWidgetData<bool>(
        '${widgetId}_remote',
        collections
            .firstWhere((element) => element.id == collectionId)
            .isRemote,
      );
    } catch (exception) {
      _logger.info('Error Sending Data. $exception');
    }
  }

  Future _setThumbnail() async {
    try {
      final bytes = (await getFile(thumbnail))!.readAsBytesSync();
      final base64 = base64Encode(bytes);
      await HomeWidget.saveWidgetData<String>(
        '${widgetId}_$thumbnailKey',
        base64,
      );
      await HomeWidget.saveWidgetData<int>(
        '${widgetId}_$thumbnailIdKey',
        thumbnail.generatedID,
      );
    } catch (exception) {
      _logger.info('Error Setting Thumbnail. $exception');
    }
  }

  Future _updateWidget() async {
    try {
      return HomeWidget.updateWidget(
        name: 'HomeScreenWidget',
        iOSName: 'HomeScreenWidget',
        qualifiedAndroidName: 'io.ente.photos.HomeScreenWidget',
      );
    } catch (exception) {
      _logger.info('Error Updating Widget. $exception');
    }
  }

  static Future<List<AppWidgetCollection>> getAppWidgetCollection() async {
    final List<AppWidgetCollection> collects = [];
    final remote =
        await CollectionsService.instance.getCollectionForOnEnteSection();
    for (var col in remote) {
      final thumbnail = await CollectionsService.instance.getCover(col);
      if (thumbnail != null) {
        final appWidgetCollection = AppWidgetCollection(
          thumbnail,
          col.id.toString(),
          col.displayName,
          true,
        );
        collects.add(appWidgetCollection);
      }
    }
    final device = await FilesDB.instance
        .getDeviceCollections(includeCoverThumbnail: true);
    for (var col in device) {
      if (col.thumbnail != null) {
        final appWidgetCollection = AppWidgetCollection(
          col.thumbnail!,
          col.id.toString(),
          col.name,
          false,
        );
        collects.add(appWidgetCollection);
      }
    }
    return collects;
  }

  Future _loadData() async {
    try {
      collections = await getAppWidgetCollection();
      _logger.info('Collection Size: ${collections.length}');
      int shape, type, id;
      String collection;
      bool recent;

      id = (await HomeWidget.getWidgetData<int>(
        widgetIdKey,
        defaultValue: 0,
      ))!;
      _logger.info(id);
      shape = (await HomeWidget.getWidgetData<int>(
        '${id}_$shapeKey',
        defaultValue: 0,
      ))!;

      type = (await HomeWidget.getWidgetData<int>(
        '${id}_$typeKey',
        defaultValue: 0,
      ))!;

      recent = (await HomeWidget.getWidgetData<bool>(
        '${id}_$recentKey',
        defaultValue: false,
      ))!;

      collection = (await HomeWidget.getWidgetData<String>(
        '${id}_$collectionKey',
        defaultValue: collections.first.id,
      ))!;

      setState(() {
        widgetId = id;
        selectedShape = shape;
        selectedType = type;
        isRecent = recent;
        collectionId = collection;
        isLoading = false;
        thumbnail = collections.firstWhere((e) => e.id == collection).thumbnail;
      });
    } catch (exception, stackTrace) {
      _logger.severe('Error Getting Data. $stackTrace');
    }
  }

  Future<void> _sendAndUpdate() async {
    await _sendData();
    await _setThumbnail();
    await _updateWidget();
    SystemNavigator.pop();
  }

  List<CustomPainter> widgetShapes() {
    return [
      SquarePainter(isSelected: selectedShape == 0),
      CirclePainter(isSelected: selectedShape == 1),
      HeartPainter(isSelected: selectedShape == 2),
    ];
  }

  List<String> onWidgetTapped = [
    'Open Collection',
    'Open Viewer',
  ];

  Future refresh() async {
    File temp;
    final currentCollection =
        collections.firstWhere((col) => col.id == collectionId);
    if (isRecent) {
      temp = currentCollection.thumbnail;
    } else {
      final rand = Random();
      if (!currentCollection.isRemote) {
        final res = await FilesDB.instance.getDeviceCollections();
        final deviceCollection =
            res.firstWhere((col) => col.id == collectionId);
        final fileLoad = await FilesDB.instance.getFilesInDeviceCollection(
          deviceCollection,
          Configuration.instance.getUserID(),
          galleryLoadStartTime,
          galleryLoadEndTime,
        );
        temp = fileLoad.files[rand.nextInt(fileLoad.files.length)];
      } else {
        final fileLoad = await FilesDB.instance.getFilesInCollection(
          int.parse(collectionId),
          galleryLoadStartTime,
          galleryLoadEndTime,
        );
        temp = fileLoad.files[rand.nextInt(fileLoad.files.length)];
      }
    }
    setState(() {
      thumbnail = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final int albumsCountInOneRow = max(
      screenWidth ~/ CollectionsFlexiGridViewWidget.maxThumbnailWidth,
      2,
    );
    final double gapBetweenAlbums = (albumsCountInOneRow - 1) *
        CollectionsFlexiGridViewWidget.fixedGapBetweenAlbum;

    final double gapOnSizeOfAlbums =
        CollectionsFlexiGridViewWidget.minGapForHorizontalPadding +
            (screenWidth -
                    gapBetweenAlbums -
                    (2 *
                        CollectionsFlexiGridViewWidget
                            .minGapForHorizontalPadding)) %
                albumsCountInOneRow;

    final double sideOfThumbnail =
        (screenWidth - gapOnSizeOfAlbums - gapBetweenAlbums) /
            albumsCountInOneRow;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ente', style: brandStyleMedium),
          centerTitle: true,
        ),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.green)
              : ListView(
                  children: [
                    ListTile(
                      title: const Text('Photo Frame'),
                      subtitle: Row(
                        children:
                            widgetShapes().mapIndexed<Widget>((index, paint) {
                          return Container(
                            margin: const EdgeInsets.only(
                              top: 16,
                              right: 16,
                              bottom: 16,
                            ),
                            child: InkWell(
                              onTap: () => setState(() {
                                selectedShape = index;
                              }),
                              child: CustomPaint(
                                size: const Size(100, 100),
                                painter: paint,
                                willChange: true,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    ListTile(
                      title: const Text('On Widget Tapped'),
                      subtitle: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: onWidgetTapped[selectedType],
                          isExpanded: true,
                          items: onWidgetTapped.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedType = onWidgetTapped.indexOf(value!);
                            });
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Choose a Collection'),
                      subtitle: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: collectionId,
                          isExpanded: true,
                          items: [
                            ...collections.map((collection) {
                              return DropdownMenuItem<String>(
                                value: collection.id,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    right: 8,
                                    bottom: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        collection.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 45,
                                        width: 45,
                                        child: ThumbnailWidget(
                                          collection.thumbnail,
                                          shouldShowLivePhotoOverlay: false,
                                          shouldShowSyncStatus: false,
                                          thumbnailSize:
                                              sideOfThumbnail.toInt(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          ],
                          onChanged: (value) async {
                            setState(() {
                              collectionId = value!;
                            });
                            await refresh();
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Displayed Content'),
                      subtitle: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: isRecent ? 'Recent' : 'Random',
                          isExpanded: true,
                          items: ['Recent', 'Random'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              isRecent = value! == 'Recent';
                            });
                          },
                        ),
                      ),
                    ),
                    ListTile(
                      title: Row(
                        children: [
                          const Text('Preview'),
                          const Spacer(),
                          IconButton(
                            onPressed: () async {
                              await refresh();
                            },
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      subtitle: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        width: double.infinity,
                        height: 300,
                        child: ThumbnailWidget(
                          thumbnail,
                          fit: BoxFit.fill,
                          shouldShowSyncStatus: false,
                          thumbnailSize: 500,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(16),
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendAndUpdate,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Save',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
