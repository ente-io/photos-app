// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_memory.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCachedMemoryCollection on Isar {
  IsarCollection<CachedMemory> get cachedMemorys => this.collection();
}

const CachedMemorySchema = CollectionSchema(
  name: r'CachedMemory',
  id: -8397291399530360927,
  properties: {
    r'seenTime': PropertySchema(
      id: 0,
      name: r'seenTime',
      type: IsarType.long,
    ),
    r'uploadedID': PropertySchema(
      id: 1,
      name: r'uploadedID',
      type: IsarType.long,
    )
  },
  estimateSize: _cachedMemoryEstimateSize,
  serialize: _cachedMemorySerialize,
  deserialize: _cachedMemoryDeserialize,
  deserializeProp: _cachedMemoryDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _cachedMemoryGetId,
  getLinks: _cachedMemoryGetLinks,
  attach: _cachedMemoryAttach,
  version: '3.1.0+1',
);

int _cachedMemoryEstimateSize(
  CachedMemory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _cachedMemorySerialize(
  CachedMemory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.seenTime);
  writer.writeLong(offsets[1], object.uploadedID);
}

CachedMemory _cachedMemoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CachedMemory(
    reader.readLong(offsets[1]),
    reader.readLong(offsets[0]),
  );
  object.id = id;
  return object;
}

P _cachedMemoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _cachedMemoryGetId(CachedMemory object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _cachedMemoryGetLinks(CachedMemory object) {
  return [];
}

void _cachedMemoryAttach(
    IsarCollection<dynamic> col, Id id, CachedMemory object) {
  object.id = id;
}

extension CachedMemoryQueryWhereSort
    on QueryBuilder<CachedMemory, CachedMemory, QWhere> {
  QueryBuilder<CachedMemory, CachedMemory, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CachedMemoryQueryWhere
    on QueryBuilder<CachedMemory, CachedMemory, QWhereClause> {
  QueryBuilder<CachedMemory, CachedMemory, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CachedMemoryQueryFilter
    on QueryBuilder<CachedMemory, CachedMemory, QFilterCondition> {
  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      seenTimeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'seenTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      seenTimeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'seenTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      seenTimeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'seenTime',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      seenTimeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'seenTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      uploadedIDEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uploadedID',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      uploadedIDGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uploadedID',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      uploadedIDLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uploadedID',
        value: value,
      ));
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterFilterCondition>
      uploadedIDBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uploadedID',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CachedMemoryQueryObject
    on QueryBuilder<CachedMemory, CachedMemory, QFilterCondition> {}

extension CachedMemoryQueryLinks
    on QueryBuilder<CachedMemory, CachedMemory, QFilterCondition> {}

extension CachedMemoryQuerySortBy
    on QueryBuilder<CachedMemory, CachedMemory, QSortBy> {
  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> sortBySeenTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seenTime', Sort.asc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> sortBySeenTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seenTime', Sort.desc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> sortByUploadedID() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadedID', Sort.asc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy>
      sortByUploadedIDDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadedID', Sort.desc);
    });
  }
}

extension CachedMemoryQuerySortThenBy
    on QueryBuilder<CachedMemory, CachedMemory, QSortThenBy> {
  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> thenBySeenTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seenTime', Sort.asc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> thenBySeenTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'seenTime', Sort.desc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy> thenByUploadedID() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadedID', Sort.asc);
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QAfterSortBy>
      thenByUploadedIDDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadedID', Sort.desc);
    });
  }
}

extension CachedMemoryQueryWhereDistinct
    on QueryBuilder<CachedMemory, CachedMemory, QDistinct> {
  QueryBuilder<CachedMemory, CachedMemory, QDistinct> distinctBySeenTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'seenTime');
    });
  }

  QueryBuilder<CachedMemory, CachedMemory, QDistinct> distinctByUploadedID() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uploadedID');
    });
  }
}

extension CachedMemoryQueryProperty
    on QueryBuilder<CachedMemory, CachedMemory, QQueryProperty> {
  QueryBuilder<CachedMemory, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CachedMemory, int, QQueryOperations> seenTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'seenTime');
    });
  }

  QueryBuilder<CachedMemory, int, QQueryOperations> uploadedIDProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uploadedID');
    });
  }
}
