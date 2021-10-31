import 'package:photos/events/files_updated_event.dart';

class CollectionUpdatedEvent extends FilesUpdatedEvent {
  final int? collectionID;

  CollectionUpdatedEvent(this.collectionID, updatedFiles, {type})
      : super(updatedFiles, type: type ?? EventType.addedOrUpdated);
}
