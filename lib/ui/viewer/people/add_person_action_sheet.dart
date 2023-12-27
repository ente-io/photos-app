import "dart:async";
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import "package:photos/face/model/person.dart";
import "package:photos/generated/l10n.dart";
import 'package:photos/theme/colors.dart';
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/components/bottom_of_title_bar_widget.dart';
import 'package:photos/ui/components/buttons/button_widget.dart';
import 'package:photos/ui/components/models/button_type.dart';
import "package:photos/ui/components/text_input_widget.dart";
import 'package:photos/ui/components/title_bar_title_widget.dart';
import "package:photos/ui/viewer/people/new_person_item_widget.dart";
import "package:photos/ui/viewer/people/person_row_item.dart";

enum PersonActionType {
  assignPerson,
}

String _actionName(
  BuildContext context,
  PersonActionType type,
) {
  String text = "";
  switch (type) {
    case PersonActionType.assignPerson:
      text = "Add name";
      break;
  }
  return text;
}

void showAssignPersonAction(
  BuildContext context, {
  required int clusterID,
  PersonActionType actionType = PersonActionType.assignPerson,
  bool showOptionToCreateNewAlbum = true,
}) {
  showBarModalBottomSheet(
    context: context,
    builder: (context) {
      return CollectionActionSheet(
        actionType: actionType,
        showOptionToCreateNewAlbum: showOptionToCreateNewAlbum,
      );
    },
    shape: const RoundedRectangleBorder(
      side: BorderSide(width: 0),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(5),
      ),
    ),
    topControl: const SizedBox.shrink(),
    backgroundColor: getEnteColorScheme(context).backgroundElevated,
    barrierColor: backdropFaintDark,
    enableDrag: false,
  );
}

class CollectionActionSheet extends StatefulWidget {
  final PersonActionType actionType;
  final bool showOptionToCreateNewAlbum;
  const CollectionActionSheet({
    required this.actionType,
    required this.showOptionToCreateNewAlbum,
    super.key,
  });

  @override
  State<CollectionActionSheet> createState() => _CollectionActionSheetState();
}

class _CollectionActionSheetState extends State<CollectionActionSheet> {
  static const int cancelButtonSize = 80;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardUp = bottomInset > 100;
    return Padding(
      padding: EdgeInsets.only(
        bottom: isKeyboardUp ? bottomInset - cancelButtonSize : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(428, MediaQuery.of(context).size.width),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        BottomOfTitleBarWidget(
                          title: TitleBarTitleWidget(
                            title: _actionName(context, widget.actionType),
                          ),
                          // caption: 'Select or create a ',
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                          ),
                          child: TextInputWidget(
                            hintText: 'Person name',
                            prefixIcon: Icons.search_rounded,
                            onChange: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            isClearable: true,
                            shouldUnfocusOnClearOrSubmit: true,
                            borderRadius: 2,
                          ),
                        ),
                        _getPersonItems(),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Container(
                      //inner stroke of 1pt + 15 pts of top padding = 16 pts
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: getEnteColorScheme(context).strokeFaint,
                          ),
                        ),
                      ),
                      child: ButtonWidget(
                        buttonType: ButtonType.secondary,
                        buttonAction: ButtonAction.cancel,
                        isInAlert: true,
                        labelText: S.of(context).cancel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Flexible _getPersonItems() {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 4, 0),
        child: FutureBuilder<List<Person>>(
          future: _getPersons(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              //Need to show an error on the UI here
              return const SizedBox.shrink();
            } else if (snapshot.hasData) {
              final persons = snapshot.data as List<Person>;
              final shouldShowCreateAlbum =
                  widget.showOptionToCreateNewAlbum && _searchQuery.isEmpty;
              final searchResults = _searchQuery.isNotEmpty
                  ? persons
                      .where(
                        (element) => element.attr.name
                            .toLowerCase()
                            .contains(_searchQuery),
                      )
                      .toList()
                  : persons;
              return Scrollbar(
                thumbVisibility: true,
                radius: const Radius.circular(2),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ListView.separated(
                    itemCount:
                        searchResults.length + (shouldShowCreateAlbum ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && shouldShowCreateAlbum) {
                        return GestureDetector(
                          child: const NewPersonItemWidget(),
                        );
                      }
                      final person = searchResults[
                          index - (shouldShowCreateAlbum ? 1 : 0)];
                      return PersonRowItem(
                        person: person,
                        onTap: () => {},
                      );
                    },
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 2);
                    },
                  ),
                ),
              );
            } else {
              return const EnteLoadingWidget();
            }
          },
        ),
      ),
    );
  }

  Future<List<Person>> _getPersons() async {
    // return dummy data
    return [
      Person(
        "1",
        PersonAttr(
          name: "Mahesh",
          faces: {},
        ),
      ),
      Person(
        "2",
        PersonAttr(
          name: "Neeraj",
          faces: {},
        ),
      ),
    ];
  }
}
