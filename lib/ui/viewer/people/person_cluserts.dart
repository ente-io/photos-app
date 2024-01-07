import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:logging/logging.dart";
import "package:photos/face/model/person.dart";
import "package:photos/models/file/file.dart";
import "package:photos/services/search_service.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/viewer/file/no_thumbnail_widget.dart";
import "package:photos/ui/viewer/file/thumbnail_widget.dart";
import "package:photos/ui/viewer/people/cluster_page.dart";

class PersonClusters extends StatefulWidget {
  final Person person;

  const PersonClusters(
    this.person, {
    super.key,
  });

  @override
  State<PersonClusters> createState() => _PersonClustersState();
}

class _PersonClustersState extends State<PersonClusters> {
  final Logger _logger = Logger("_PersonClustersState");
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.attr.name),
      ),
      body: FutureBuilder<Map<int, List<EnteFile>>>(
        future: SearchService.instance
            .getClusterFilesForPersonID(widget.person.remoteID),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final List<int> keys = snapshot.data!.keys.toList();
            return ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final List<EnteFile> files = snapshot.data![keys[index]]!;
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ClusterPage(
                          files,
                          personID: widget.person,
                          cluserID: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: files.isNotEmpty
                              ? ClipOval(
                                  child: ThumbnailWidget(
                                    files.first,
                                    shouldShowSyncStatus: false,
                                  ),
                                )
                              : const ClipOval(
                                  child: NoThumbnailWidget(
                                    addBorder: false,
                                  ),
                                ),
                        ),
                        const SizedBox(
                          width: 8.0,
                        ), // Add some spacing between the thumbnail and the text
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  "${snapshot.data![keys[index]]!.length} photos",
                                  style: getEnteTextTheme(context).body,
                                ),
                                // Red - icon

                                const Icon(
                                  CupertinoIcons.minus_circled,
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            _logger.warning("Failed to get cluster", snapshot.error);
            return const Center(child: Text("Error"));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
