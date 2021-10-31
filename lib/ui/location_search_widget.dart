import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/network.dart';
import 'package:photos/models/location.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/location_search_results_page.dart';

class LocationSearchWidget extends StatefulWidget {
  const LocationSearchWidget({
    Key? key,
  }) : super(key: key);

  @override
  _LocationSearchWidgetState createState() => _LocationSearchWidgetState();
}

class _LocationSearchWidgetState extends State<LocationSearchWidget> {
  String? _searchString;

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        autofocus: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Eg: Rome, Paris, New York',
          contentPadding: const EdgeInsets.all(0.0),
        ),
      ),
      hideOnEmpty: true,
      loadingBuilder: (context) {
        return loadWidget;
      },
      suggestionsCallback: (pattern) {
        return _getSuggestions(pattern);
      },
      itemBuilder: (context, dynamic suggestion) {
        return LocationSearchResultWidget(suggestion['name']);
      },
      onSuggestionSelected: (dynamic suggestion) {
        Navigator.pop(context);
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => LocationSearchResultsPage(
                  ViewPort(
                      Location(
                          suggestion['geometry']['viewport']['northeast']
                              ['lat'],
                          suggestion['geometry']['viewport']['northeast']
                              ['lng']),
                      Location(
                          suggestion['geometry']['viewport']['southwest']
                              ['lat'],
                          suggestion['geometry']['viewport']['southwest']
                              ['lng'])),
                  suggestion['name'],
                )));
      },
    );
  }

  Future<List<String>> _getSuggestions(String pattern) async {
    if (pattern.isEmpty || pattern.length < 2) {
      return List.empty();
    }
    _searchString = pattern;
    return Network.instance
        .getDio()
        .get(
          Configuration.instance.getHttpEndpoint() + "/search/location",
          queryParameters: {
            "query": pattern,
          },
          options: Options(
              headers: {"X-Auth-Token": Configuration.instance.getToken()}),
        )
        .then((response) {
      if (_searchString == pattern) {
        // Query has not changed
        return response.data["results"] as List<String>;
      }
      return List.empty();
    });
  }
}

class LocationSearchResultWidget extends StatelessWidget {
  final String? name;
  const LocationSearchResultWidget(
    this.name, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: new EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
      margin: EdgeInsets.symmetric(vertical: 6.0),
      child: Column(children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.location_on,
            ),
            Padding(padding: EdgeInsets.only(left: 20.0)),
            Flexible(
              child: Container(
                child: Text(
                  name!,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}
