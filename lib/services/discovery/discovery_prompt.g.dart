// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_prompt.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDiscoveryPromptCollection on Isar {
  IsarCollection<DiscoveryPrompt> get discoveryPrompts => this.collection();
}

const DiscoveryPromptSchema = CollectionSchema(
  name: r'DiscoveryPrompt',
  id: 4393150729733597781,
  properties: {
    r'minimumScore': PropertySchema(
      id: 0,
      name: r'minimumScore',
      type: IsarType.double,
    ),
    r'minimumSize': PropertySchema(
      id: 1,
      name: r'minimumSize',
      type: IsarType.double,
    ),
    r'prompt': PropertySchema(
      id: 2,
      name: r'prompt',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 3,
      name: r'title',
      type: IsarType.string,
    )
  },
  estimateSize: _discoveryPromptEstimateSize,
  serialize: _discoveryPromptSerialize,
  deserialize: _discoveryPromptDeserialize,
  deserializeProp: _discoveryPromptDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _discoveryPromptGetId,
  getLinks: _discoveryPromptGetLinks,
  attach: _discoveryPromptAttach,
  version: '3.1.0+1',
);

int _discoveryPromptEstimateSize(
  DiscoveryPrompt object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.prompt.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _discoveryPromptSerialize(
  DiscoveryPrompt object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.minimumScore);
  writer.writeDouble(offsets[1], object.minimumSize);
  writer.writeString(offsets[2], object.prompt);
  writer.writeString(offsets[3], object.title);
}

DiscoveryPrompt _discoveryPromptDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DiscoveryPrompt(
    reader.readString(offsets[2]),
    reader.readString(offsets[3]),
    reader.readDouble(offsets[0]),
    reader.readDoubleOrNull(offsets[1]),
  );
  object.id = id;
  return object;
}

P _discoveryPromptDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _discoveryPromptGetId(DiscoveryPrompt object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _discoveryPromptGetLinks(DiscoveryPrompt object) {
  return [];
}

void _discoveryPromptAttach(
    IsarCollection<dynamic> col, Id id, DiscoveryPrompt object) {
  object.id = id;
}

extension DiscoveryPromptQueryWhereSort
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QWhere> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DiscoveryPromptQueryWhere
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QWhereClause> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterWhereClause> idBetween(
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

extension DiscoveryPromptQueryFilter
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QFilterCondition> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumScoreEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minimumScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumScoreGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minimumScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumScoreLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minimumScore',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumScoreBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minimumScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'minimumSize',
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'minimumSize',
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minimumSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minimumSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minimumSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      minimumSizeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minimumSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'prompt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'prompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'prompt',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prompt',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      promptIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'prompt',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }
}

extension DiscoveryPromptQueryObject
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QFilterCondition> {}

extension DiscoveryPromptQueryLinks
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QFilterCondition> {}

extension DiscoveryPromptQuerySortBy
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QSortBy> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByMinimumScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumScore', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByMinimumScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumScore', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByMinimumSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumSize', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByMinimumSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumSize', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> sortByPrompt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prompt', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByPromptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prompt', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension DiscoveryPromptQuerySortThenBy
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QSortThenBy> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByMinimumScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumScore', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByMinimumScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumScore', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByMinimumSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumSize', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByMinimumSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minimumSize', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> thenByPrompt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prompt', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByPromptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prompt', Sort.desc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension DiscoveryPromptQueryWhereDistinct
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QDistinct> {
  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QDistinct>
      distinctByMinimumScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minimumScore');
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QDistinct>
      distinctByMinimumSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minimumSize');
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QDistinct> distinctByPrompt(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prompt', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension DiscoveryPromptQueryProperty
    on QueryBuilder<DiscoveryPrompt, DiscoveryPrompt, QQueryProperty> {
  QueryBuilder<DiscoveryPrompt, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DiscoveryPrompt, double, QQueryOperations>
      minimumScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minimumScore');
    });
  }

  QueryBuilder<DiscoveryPrompt, double?, QQueryOperations>
      minimumSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minimumSize');
    });
  }

  QueryBuilder<DiscoveryPrompt, String, QQueryOperations> promptProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prompt');
    });
  }

  QueryBuilder<DiscoveryPrompt, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
