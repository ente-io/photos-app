import "dart:convert";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:home_widget/home_widget.dart";
import "package:logging/logging.dart";
import "package:photos/appwidget/circle_painter.dart";
import "package:photos/appwidget/heart_painter.dart";
import "package:photos/appwidget/square_painter.dart";
import "package:photos/db/device_files_db.dart";
import "package:photos/db/files_db.dart";
import "package:photos/models/device_collection.dart";
import "package:photos/models/file.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/utils/file_util.dart";

const shapeKey = 'shape';
const typeKey = 'type';
const recentKey = 'recent';
const collectionKey = 'collection';

/// Called when Doing Background Work initiated from Widget
@pragma("vm:entry-point")
void backgroundCallback(Uri? data) async {
  if (data?.host == 'refresh') {
    Logger('refresh').info('refreshing widget');
    final collectionId = await HomeWidget.getWidgetData<String>(
      collectionKey,
      defaultValue: '-1',
    );

    File? file;

    FilesDB.instance
        .getDeviceCollections(includeCoverThumbnail: true)
        .then((collections) {
      file = collections
          .firstWhere((element) => element.id == collectionId)
          .thumbnail;
    });

    final ioFile = await getFile(file!);
    final bytes = ioFile!.readAsBytesSync();
    final base64 = base64Encode(bytes);

    await HomeWidget.saveWidgetData<String>(
      "thumbnail",
      base64,
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

class _AppWidgetState extends State<AppWidget> {
  int selectedShape = 0;
  int selectedType = 0;
  String collectionId = '-1';
  bool isRecent = false;
  bool isLoading = true;
  List<DeviceCollection> collections = [];
  final _logger = Logger('_APPWIDGET');

  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('YOUR_GROUP_ID');
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future _sendData() async {
    try {
      await HomeWidget.saveWidgetData<String>(collectionKey, collectionId);
      await HomeWidget.saveWidgetData<int>(shapeKey, selectedShape);
      await HomeWidget.saveWidgetData<int>(typeKey, selectedType);
      await HomeWidget.saveWidgetData<bool>(recentKey, isRecent);
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
      await HomeWidget.saveWidgetData<String>("thumbnail", base64);
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
      int shape, type;
      String collection;
      bool recent;

      shape = (await HomeWidget.getWidgetData<int>(shapeKey, defaultValue: 0))!;

      type = (await HomeWidget.getWidgetData<int>(
        typeKey,
        defaultValue: 0,
      ))!;

      recent = (await HomeWidget.getWidgetData<bool>(
        recentKey,
        defaultValue: false,
      ))!;

      collection = (await HomeWidget.getWidgetData<String>(
        collectionKey,
        defaultValue: '-1',
      ))!;
      setState(() {
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
  }

  List<CustomPainter> widgetShapes() {
    return [
      SquarePainter(isSelected: selectedShape == 0),
      CirclePainter(isSelected: selectedShape == 1),
      HeartPainter(isSelected: selectedShape == 2),
    ];
  }

  List<String> onWidgetTapped = [
    'Open Home',
    'Open Collection',
    'Open Viewer',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ente'),
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
                    ElevatedButton(
                      onPressed: _sendAndUpdate,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text('Save'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
