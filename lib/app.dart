import "dart:async";
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:background_fetch/background_fetch.dart';
import "package:collection/collection.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import "package:home_widget/home_widget.dart" as hw;
import 'package:logging/logging.dart';
import 'package:media_extension/media_extension_action_types.dart';
import "package:photos/appwidget/app_widget.dart";
import "package:photos/core/configuration.dart";
import "package:photos/core/constants.dart";
import "package:photos/db/device_files_db.dart";
import "package:photos/db/files_db.dart";
import 'package:photos/ente_theme_data.dart';
import "package:photos/generated/l10n.dart";
import "package:photos/l10n/l10n.dart";
import "package:photos/models/device_collection.dart";
import "package:photos/models/file_load_result.dart";
import 'package:photos/services/app_lifecycle_service.dart';
import 'package:photos/services/search_service.dart';
import 'package:photos/services/sync_service.dart';
import 'package:photos/ui/tabs/home_widget.dart';
import "package:photos/ui/viewer/actions/file_viewer.dart";
import "package:photos/ui/viewer/file/detail_page.dart";
import "package:photos/ui/viewer/gallery/collection_page.dart";
import "package:photos/utils/intent_util.dart";
import "package:photos/utils/navigation_util.dart";

class EnteApp extends StatefulWidget {
  final Future<void> Function(String) runBackgroundTask;
  final Future<void> Function(String) killBackgroundTask;
  final AdaptiveThemeMode? savedThemeMode;
  final Locale locale;

  const EnteApp(
    this.runBackgroundTask,
    this.killBackgroundTask,
    this.locale,
    this.savedThemeMode, {
    Key? key,
  }) : super(key: key);

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_EnteAppState>()!;
    state.setLocale(newLocale);
  }

  @override
  State<EnteApp> createState() => _EnteAppState();
}

class _EnteAppState extends State<EnteApp> with WidgetsBindingObserver {
  final _logger = Logger("EnteAppState");
  late Locale locale;
  bool isLaunchedByWidget = false;
  final StreamController<bool> isHomeWidgetController =
      StreamController<bool>.broadcast();

  @override
  void initState() {
    _logger.info('init App');
    super.initState();
    locale = widget.locale;
    setupIntentAction();
    WidgetsBinding.instance.addObserver(this);
  }

  setLocale(Locale newLocale) {
    setState(() {
      locale = newLocale;
    });
  }

  void setupIntentAction() async {
    final mediaExtentionAction = Platform.isAndroid
        ? await initIntentAction()
        : MediaExtentionAction(action: IntentAction.main);
    _logger.info(mediaExtentionAction.action);
    _logger.info(mediaExtentionAction.data ?? 'null');
    AppLifecycleService.instance.setMediaExtensionAction(mediaExtentionAction);
    if (mediaExtentionAction.action == IntentAction.main) {
      _configureBackgroundFetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || kDebugMode) {
      return AdaptiveTheme(
        light: lightThemeData,
        dark: darkThemeData,
        initial: widget.savedThemeMode ?? AdaptiveThemeMode.system,
        builder: (lightTheme, dartTheme) => MaterialApp(
          title: "ente",
          themeMode: ThemeMode.system,
          theme: lightTheme,
          darkTheme: dartTheme,
          home: StreamBuilder<bool>(
            stream: isHomeWidgetController.stream,
            builder: (context, snapshot) {
              if (snapshot.data != null && snapshot.data!) {
                return const AppWidget();
              } else {
                return (AppLifecycleService
                            .instance.mediaExtensionAction.action ==
                        IntentAction.view
                    ? const FileViewer()
                    : const HomeWidget());
              }
            },
          ),
          debugShowCheckedModeBanner: false,
          builder: EasyLoading.init(),
          locale: locale,
          supportedLocales: appSupportedLocales,
          localeListResolutionCallback: localResolutionCallBack,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            S.delegate
          ],
        ),
      );
    } else {
      return MaterialApp(
        title: "ente",
        themeMode: ThemeMode.system,
        theme: lightThemeData,
        darkTheme: darkThemeData,
        home: const HomeWidget(),
        debugShowCheckedModeBanner: false,
        builder: EasyLoading.init(),
        locale: locale,
        supportedLocales: appSupportedLocales,
        localeListResolutionCallback: localResolutionCallBack,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          S.delegate
        ],
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForWidgetLaunch();
    hw.HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  void _checkForWidgetLaunch() {
    hw.HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      if (uri.host == "configure") {
        isHomeWidgetController.sink.add(true);
      } else if (uri.host == "view") {
        _onHomeWigetClicked(context, uri);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final String stateChangeReason = 'app -> $state';
    if (state == AppLifecycleState.resumed) {
      AppLifecycleService.instance
          .onAppInForeground(stateChangeReason + ': sync now');
      SyncService.instance.sync();
    } else {
      AppLifecycleService.instance.onAppInBackground(stateChangeReason);
    }
  }

  void _configureBackgroundFetch() {
    BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          forceAlarmManager: false,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.ANY,
        ), (String taskId) async {
      await widget.runBackgroundTask(taskId);
    }, (taskId) {
      _logger.info("BG task timeout taskID: $taskId");
      widget.killBackgroundTask(taskId);
    }).then((int status) {
      _logger.info('[BackgroundFetch] configure success: $status');
    }).catchError((e) {
      _logger.info('[BackgroundFetch] configure ERROR: $e');
    });
  }
}

void _onHomeWigetClicked(BuildContext context, Uri uri) async {
  final params = uri.queryParameters;
  final type = int.parse(params['type']!);
  final thumbnailId = int.parse(params['id']!);
  final collectionId = params['collection'];
  final collections = await FilesDB.instance.getDeviceCollections();
  DeviceCollection? deviceCollection;
  for (var e in collections) {
    if (e.id == collectionId) {
      deviceCollection = e;
    }
  }
  if (type == 0) {
    final collectionName = deviceCollection!.name;
    final allResults =
        await SearchService.instance.getCollectionSearchResults(collectionName);
    routeToPage(
      context,
      CollectionPage(
        allResults[0].collectionWithThumbnail,
      ),
    );
  } else {
    final fileloader = await FilesDB.instance.getFilesInDeviceCollection(
      deviceCollection!,
      Configuration.instance.getUserID(),
      galleryLoadStartTime,
      galleryLoadEndTime,
    );
    int selectedIndex = 0;
    fileloader.files.forEachIndexed((index, element) {
      if (element.generatedID == thumbnailId) {
        selectedIndex = index;
      }
    });
    final page = DetailPage(
      DetailPageConfiguration(
        fileloader.files,
        (creationStartTime, creationEndTime, {asc, limit}) async {
          final result = FileLoadResult(fileloader.files, false);
          return result;
        },
        selectedIndex,
        'HomeWidget',
      ),
    );
    routeToPage(
      context,
      page,
    );
  }
}
