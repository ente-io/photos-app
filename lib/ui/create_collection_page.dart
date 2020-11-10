import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:page_transition/page_transition.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/models/collection.dart';
import 'package:photos/models/collection_items.dart';
import 'package:photos/models/file.dart';
import 'package:photos/models/selected_files.dart';
import 'package:photos/services/collections_service.dart';
import 'package:photos/ui/collection_page.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/thumbnail_widget.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/file_uploader.dart';
import 'package:photos/utils/toast_util.dart';

class CreateCollectionPage extends StatefulWidget {
  final SelectedFiles selectedFiles;
  const CreateCollectionPage(this.selectedFiles, {Key key}) : super(key: key);

  @override
  _CreateCollectionPageState createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final _logger = Logger("CreateCollectionPage");
  String _albumName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create album"),
      ),
      body: _getBody(context),
    );
  }

  Widget _getBody(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: OutlineButton(
                  child: Text(
                    "Create a new album",
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                  onPressed: () {
                    _showNameAlbumDialog();
                  },
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Add to an existing collection",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColorLight,
              ),
            ),
          ),
        ),
        _getExistingCollectionsWidget(),
      ],
    );
  }

  Widget _getExistingCollectionsWidget() {
    return FutureBuilder<List<CollectionWithThumbnail>>(
      future: _getCollectionsWithThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        } else if (snapshot.hasData) {
          return Flexible(
            child: ListView.builder(
              itemBuilder: (context, index) {
                return _buildCollectionItem(snapshot.data[index]);
              },
              itemCount: snapshot.data.length,
              shrinkWrap: true,
            ),
          );
        } else {
          return loadWidget;
        }
      },
    );
  }

  Widget _buildCollectionItem(CollectionWithThumbnail item) {
    return Container(
      padding: EdgeInsets.all(8),
      child: GestureDetector(
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: Container(
                child: ThumbnailWidget(item.thumbnail),
                height: 64,
                width: 64,
              ),
            ),
            Padding(padding: EdgeInsets.all(8)),
            Expanded(
              child: Text(
                item.collection.name,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        onTap: () async {
          if (await _addToCollection(item.collection.id)) {
            showToast("Added successfully to '" + item.collection.name);
            Navigator.pop(context);
            Navigator.push(
                context,
                PageTransition(
                    type: PageTransitionType.bottomToTop,
                    child: CollectionPage(
                      item.collection,
                    )));
          }
        },
      ),
    );
  }

  Future<List<CollectionWithThumbnail>> _getCollectionsWithThumbnail() async {
    final collectionsWithThumbnail = List<CollectionWithThumbnail>();
    final collections = CollectionsService.instance.getCollections();
    for (final c in collections) {
      if (c.owner.id != Configuration.instance.getUserID()) {
        continue;
      }
      var thumbnail = await FilesDB.instance.getLatestFileInCollection(c.id);
      if (thumbnail == null) {
        continue;
      }
      final lastUpdatedFile =
          await FilesDB.instance.getLastModifiedFileInCollection(c.id);
      collectionsWithThumbnail.add(CollectionWithThumbnail(
        c,
        thumbnail,
        lastUpdatedFile,
      ));
    }
    collectionsWithThumbnail.sort((first, second) {
      return second.lastUpdatedFile.updationTime
          .compareTo(first.lastUpdatedFile.updationTime);
    });
    return collectionsWithThumbnail;
  }

  void _showNameAlbumDialog() async {
    AlertDialog alert = AlertDialog(
      title: Text("Album title"),
      content: TextFormField(
        decoration: InputDecoration(
          hintText: "Christmas 2020 / Dinner at Alice's",
          contentPadding: EdgeInsets.all(8),
        ),
        onChanged: (value) {
          setState(() {
            _albumName = value;
          });
        },
        autofocus: true,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        FlatButton(
          child: Text("OK"),
          onPressed: () async {
            Navigator.pop(context);
            final collection = await _createAlbum(_albumName);
            if (collection != null) {
              if (await _addToCollection(collection.id)) {
                showToast("Album '" + _albumName + "' created.");
                Navigator.pop(context);
                Navigator.push(
                    context,
                    PageTransition(
                        type: PageTransitionType.bottomToTop,
                        child: CollectionPage(
                          collection,
                        )));
              }
            }
          },
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Future<bool> _addToCollection(int collectionID) async {
    final dialog = createProgressDialog(context, "Uploading files to album...");
    await dialog.show();
    final files = List<File>();
    for (final file in widget.selectedFiles.files) {
      if (file.uploadedFileID == null) {
        final uploadedFile =
            (await FileUploader.instance.forceUpload(file, collectionID));
        files.add(uploadedFile);
      } else {
        files.add(file);
      }
    }
    try {
      await CollectionsService.instance.addToCollection(collectionID, files);
      await dialog.hide();
      widget.selectedFiles.clearAll();
      return true;
    } catch (e, s) {
      _logger.severe(e, s);
      await dialog.hide();
      showGenericErrorDialog(context);
    }
    return false;
  }

  Future<Collection> _createAlbum(String albumName) async {
    var collection;
    final dialog = createProgressDialog(context, "Creating album...");
    await dialog.show();
    try {
      collection = await CollectionsService.instance.createAlbum(albumName);
    } catch (e, s) {
      _logger.severe(e, s);
      await dialog.hide();
      showGenericErrorDialog(context);
    } finally {
      await dialog.hide();
    }
    return collection;
  }
}
