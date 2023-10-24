import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:logging/logging.dart";
import "package:photos/core/event_bus.dart";
import "package:photos/events/tab_changed_event.dart";
import "package:photos/models/search/search_result.dart";
import "package:photos/services/search_service.dart";
import "package:photos/states/search_results_state.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/viewer/search/search_suffix_icon_widget.dart";
import "package:photos/utils/date_time_util.dart";
import "package:photos/utils/debouncer.dart";

bool isSearchQueryEmpty = true;

class SearchWidgetNew extends StatefulWidget {
  const SearchWidgetNew({Key? key}) : super(key: key);

  @override
  State<SearchWidgetNew> createState() => _SearchWidgetNewState();
}

class _SearchWidgetNewState extends State<SearchWidgetNew> {
  String _query = "";
  final _searchService = SearchService.instance;
  final _debouncer = Debouncer(const Duration(milliseconds: 100));
  final Logger _logger = Logger((_SearchWidgetNewState).toString());
  late FocusNode focusNode;
  StreamSubscription<TabDoubleTapEvent>? _tabDoubleTapEvent;
  double _bottomPadding = 0.0;
  double _distanceOfWidgetFromBottom = 0;
  GlobalKey widgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    _tabDoubleTapEvent =
        Bus.instance.on<TabDoubleTapEvent>().listen((event) async {
      debugPrint("Firing now ${event.selectedIndex}");
      if (mounted && event.selectedIndex == 3) {
        focusNode.requestFocus();
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      //This buffer is for doing this operation only after SearchWidget's
      //animation is complete.
      Future.delayed(const Duration(milliseconds: 250), () {
        final RenderBox box =
            widgetKey.currentContext!.findRenderObject() as RenderBox;
        final heightOfWidget = box.size.height;
        final offsetPosition = box.localToGlobal(Offset.zero);
        final y = offsetPosition.dy;
        final heightOfScreen = MediaQuery.sizeOf(context).height;
        _distanceOfWidgetFromBottom = heightOfScreen - (y + heightOfWidget);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _bottomPadding =
        (MediaQuery.viewInsetsOf(context).bottom - _distanceOfWidgetFromBottom);
    if (_bottomPadding < 0) {
      _bottomPadding = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    return RepaintBoundary(
      //Why repaint boundary?
      key: widgetKey,
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomPadding),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: colorScheme.backgroundBase,
                child: Container(
                  height: 44,
                  color: colorScheme.fillFaint,
                  child: TextFormField(
                    style: Theme.of(context).textTheme.titleMedium,
                    // Below parameters are to disable auto-suggestion
                    enableSuggestions: false,
                    autocorrect: false,
                    // Above parameters are to disable auto-suggestion
                    decoration: InputDecoration(
                      // hintText: S.of(context).searchHintText,
                      hintText: "Search",
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        maxHeight: 44,
                        maxWidth: 44,
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        maxHeight: 44,
                        maxWidth: 44,
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      prefixIcon: Hero(
                        tag: "search_icon",
                        child: Icon(
                          Icons.search,
                          color: colorScheme.strokeFaint,
                        ),
                      ),
                      /*Using valueListenableBuilder inside a stateful widget because this widget is only rebuild when
                      setState is called when deboucncing is over and the spinner needs to be shown while debouncing */
                      suffixIcon: ValueListenableBuilder(
                        valueListenable: _debouncer.debounceActiveNotifier,
                        builder: (
                          BuildContext context,
                          bool isDebouncing,
                          Widget? child,
                        ) {
                          return SearchSuffixIcon(
                            isDebouncing,
                          );
                        },
                      ),
                    ),
                    onChanged: (value) async {
                      isSearchQueryEmpty = value.isEmpty;

                      //Why is this required?
                      _query = value;
                      final List<SearchResult> allResults =
                          await getSearchResultsForQuery(context, value);
                      /*checking if _query == value to make sure that the results are from the current query
                      and not from the previous query (race condition).*/
                      if (mounted && _query == value) {
                        final inheritedSearchResults =
                            InheritedSearchResults.of(context);
                        inheritedSearchResults.updateResults(allResults);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debouncer.cancelDebounce();
    focusNode.dispose();
    _tabDoubleTapEvent?.cancel();
    super.dispose();
  }

  Future<List<SearchResult>> getSearchResultsForQuery(
    BuildContext context,
    String query,
  ) async {
    final Completer<List<SearchResult>> completer = Completer();

    _debouncer.run(
      () {
        return _getSearchResultsFromService(context, query, completer);
      },
    );

    return completer.future;
  }

  Future<void> _getSearchResultsFromService(
    BuildContext context,
    String query,
    Completer completer,
  ) async {
    final List<SearchResult> allResults = [];
    if (query.isEmpty) {
      completer.complete(allResults);
      return;
    }
    try {
      if (_isYearValid(query)) {
        final yearResults = await _searchService.getYearSearchResults(query);
        allResults.addAll(yearResults);
      }

      final holidayResults =
          await _searchService.getHolidaySearchResults(context, query);
      allResults.addAll(holidayResults);

      final fileTypeSearchResults =
          await _searchService.getFileTypeResults(query);
      allResults.addAll(fileTypeSearchResults);

      final captionAndDisplayNameResult =
          await _searchService.getCaptionAndNameResults(query);
      allResults.addAll(captionAndDisplayNameResult);

      final fileExtnResult =
          await _searchService.getFileExtensionResults(query);
      allResults.addAll(fileExtnResult);

      final locationResult = await _searchService.getLocationResults(query);
      allResults.addAll(locationResult);

      final collectionResults =
          await _searchService.getCollectionSearchResults(query);
      allResults.addAll(collectionResults);

      final monthResults =
          await _searchService.getMonthSearchResults(context, query);
      allResults.addAll(monthResults);

      final possibleEvents =
          await _searchService.getDateResults(context, query);
      allResults.addAll(possibleEvents);
    } catch (e, s) {
      _logger.severe("error during search", e, s);
    }
    completer.complete(allResults);
  }

  bool _isYearValid(String year) {
    final yearAsInt = int.tryParse(year); //returns null if cannot be parsed
    return yearAsInt != null && yearAsInt <= currentYear;
  }
}