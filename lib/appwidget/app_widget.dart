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
import "package:photos/models/device_collection.dart";
import "package:photos/theme/text_style.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/utils/file_util.dart";

const shapeKey = 'shape';
const typeKey = 'type';
const recentKey = 'recent';
const collectionKey = 'collection';
const thumbnailKey = 'thumbnail';
const thumbnailIdKey = 'thumbnail_id';
const widgetIdKey = 'widget_id';

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
void backgroundHomeWidgetCallback(Uri? data) async {
  if (data?.host == 'refresh') {
    Logger('refresh').info('refreshing widget');
    final widgetId = await HomeWidget.getWidgetData<int>(
      widgetIdKey,
      defaultValue: 0,
    );
    final collectionId = await HomeWidget.getWidgetData<String>(
      '${widgetId}_$collectionKey',
      defaultValue: '-1',
    );

    final isRecent = await HomeWidget.getWidgetData<bool>(
      '${widgetId}_$recentKey',
      defaultValue: false,
    );

    final collections = await FilesDB.instance.getDeviceCollections();
    DeviceCollection? deviceCollection;
    for (var e in collections) {
      if (e.id == collectionId) {
        deviceCollection = e;
      }
    }
    PhotoManager.setIgnorePermissionCheck(true);
    await Configuration.instance.init();

    final fileloader = await FilesDB.instance.getFilesInDeviceCollection(
      deviceCollection!,
      Configuration.instance.getUserID(),
      galleryLoadStartTime,
      galleryLoadEndTime,
    );
    final files = fileloader.files;
    final file =
        isRecent! ? files.first : files[Random().nextInt(files.length) + 1];
    final ioFile = await getFile(file);
    final bytes = await ioFile!.readAsBytes();
    final base64 = base64Encode(bytes);

    await HomeWidget.saveWidgetData<String>(
      '${widgetId}_$thumbnailKey',
      base64,
    );
    await HomeWidget.saveWidgetData<int>(
      '${widgetId}_$thumbnailIdKey',
      file.generatedID,
    );
    await HomeWidget.updateWidget(
      name: 'HomeScreenWidget',
      iOSName: 'HomeScreenWidget',
      qualifiedAndroidName: 'io.ente.photos.HomeScreenWidget',
    );
  }
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
  String collectionId = '-1';
  bool isRecent = false;
  bool isLoading = true;
  List<DeviceCollection> collections = [];
  final _logger = Logger('_APPWIDGET');

  @override
  void initState() {
    super.initState();
    _logger.info("init State");
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.info("resumed");
      _loadData();
    }
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
    } catch (exception) {
      _logger.info('Error Sending Data. $exception');
    }
  }

  Future setThumbnail() async {
    try {
      final file =
          collections.firstWhere((e) => e.id == collectionId).thumbnail!;
      final bytes = (await getFile(file))!.readAsBytesSync();
      final base64 = base64Encode(bytes);
      await HomeWidget.saveWidgetData<String>(
        '${widgetId}_$thumbnailKey',
        base64,
      );
      await HomeWidget.saveWidgetData<int>(
        '${widgetId}_$thumbnailIdKey',
        file.generatedID,
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

  Future _loadData() async {
    try {
      collections = await FilesDB.instance
          .getDeviceCollections(includeCoverThumbnail: true);
      int shape, type, id;
      String collection;
      bool recent;

      id = (await HomeWidget.getWidgetData<int>(
        widgetIdKey,
        defaultValue: 0,
      ))!;

      shape = (await HomeWidget.getWidgetData<int>(
        '${widgetId}_$shapeKey',
        defaultValue: 0,
      ))!;

      type = (await HomeWidget.getWidgetData<int>(
        '${widgetId}_$typeKey',
        defaultValue: 0,
      ))!;

      recent = (await HomeWidget.getWidgetData<bool>(
        '${widgetId}_$recentKey',
        defaultValue: false,
      ))!;

      collection = (await HomeWidget.getWidgetData<String>(
        '${widgetId}_$collectionKey',
        defaultValue: '-1',
      ))!;
      _logger.info("widgetId: $id");
      setState(() {
        widgetId = id;
        selectedShape = shape;
        selectedType = type;
        isRecent = recent;
        collectionId = collection;
        isLoading = false;
      });
    } catch (exception) {
      debugPrint('Error Getting Data. $exception');
    }
  }

  Future<void> _sendAndUpdate() async {
    await _sendData();
    await setThumbnail();
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ente', style: brandStyleMedium),
          centerTitle: true,
        ),
        body: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.green)
              : Column(
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
                      title: const Text('Choose a Collection'),
                      subtitle: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: collectionId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String>(
                              value: '-1',
                              child: Container(
                                margin: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 10,
                                ),
                                child: Text(
                                  'All',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
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
                                          thumbnailSize: 200,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList()
                          ],
                          onChanged: (value) {
                            setState(() {
                              collectionId = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
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
