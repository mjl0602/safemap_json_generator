import 'dart:convert';

class SafeMapFileGenarater {
  static String fileHeader = "import 'package:safemap/safemap.dart';\n\n";

  /// 解析JsonClassInfo，并生成类内容
  static String _oneClassContentFromClass(_JsonClassInfo info) {
    return _oneClassContentBuilder(
      className: info.className,
      property: info.props.map(
        (p) {
          return 'final ${p.className} ${p.propertyName};';
        },
      ).join('\n  '),
      init: info.props.map(
        (p) {
          return 'this.${p.propertyName},';
        },
      ).join('\n    '),
      safeMapBuild: info.props.map(
        (p) {
          if (p.isNotNativeList) {
            return """${p.propertyName}: safeMap['${p.jsonKey}']
              .list
              ?.map<${p.childTClassName}>((json) => ${p.childTClassName}.fromJson(json))
              ?.toList(),""";
          }
          return "${p.propertyName}: safeMap['${p.jsonKey}'].${p.safeMapType},";
        },
      ).join('\n          '),
      jsonContent: info.props.map(
        (p) {
          return "'${p.jsonKey}': ${p.propertyName},";
        },
      ).join('\n        '),
    );
  }

  /// 生成类内容
  static String _oneClassContentBuilder({
    String className,
    String property,
    String init,
    String safeMapBuild,
    String jsonContent,
  }) =>
      """
class $className {
  $property

  $className({
    ${init}
  });

  $className.fromJson(Map<String, dynamic> json) : this.fromSafeMap(SafeMap(json));

  $className.fromSafeMap(SafeMap safeMap)
      : this(
          $safeMapBuild
        );

  Map<String, dynamic> toJson() => <String, dynamic>{
        $jsonContent
      };

  @override
  String toString() {
    return json.encode(this);
  }
}
""";

  generate(
    String jsonString,
  ) {
    var allClassList = _JsonAnalysis.encode(
      json.decode(jsonString),
    );
    var content = fileHeader;
    for (var c in allClassList) {
      var res = _oneClassContentFromClass(c);
      content += '$res\n';
    }
    print(content);
  }
}

enum _JsonValueType {
  any,
  string,
  integer,
  float,
  list,
  map,
}

extension _JsonValueTypeBuilder on _JsonValueType {
  static fromValue(dynamic value) {
    if (value == null) return _JsonValueType.any;
    if (value is String) return _JsonValueType.string;
    if (value is int) return _JsonValueType.integer;
    if (value is double) return _JsonValueType.float;
    if (value is List) return _JsonValueType.list;
    if (value is Map) return _JsonValueType.map;
  }

  String get name {
    switch (this) {
      case _JsonValueType.any:
        return 'dynamic';
        break;
      case _JsonValueType.string:
        return 'String';
        break;
      case _JsonValueType.integer:
        return 'int';
        break;
      case _JsonValueType.float:
        return 'double';
        break;
      case _JsonValueType.list:
        return 'List';
        break;
      case _JsonValueType.map:
        return 'Map';
        break;
    }
    return 'dynamic';
  }

  String get safeMapGetterType {
    switch (this) {
      case _JsonValueType.any:
        return 'value';
        break;
      case _JsonValueType.string:
        return 'string';
        break;
      case _JsonValueType.integer:
        return 'intValue';
        break;
      case _JsonValueType.float:
        return 'doubleValue';
        break;
      case _JsonValueType.list:
        return 'list';
        break;
      case _JsonValueType.map:
        return 'map';
        break;
    }
    return 'value';
  }
}

/// 第一个转大写
extension _FirstToUp on String {
  String get firstToUp => this.replaceRange(
        0,
        1,
        this.split('').first.toUpperCase(),
      );
}

extension _ListTypeString on List {
  String get typeString {
    var f = this.first;
    try {
      if (f is String) {
        this.cast<String>();
        return 'String';
      }
      if (f is int) {
        this.cast<int>();
        return 'int';
      }
      if (f is double) {
        this.cast<double>();
        return 'double';
      }
      if (f is List) {
        this.cast<List>();
        return 'List';
      }
      if (f is Map) {
        this.cast<Map>();
        return 'Map';
      }
    } catch (e) {}
    return 'dynamic';
  }
}

/// 分析结果
class _JsonAnalysis {
  /// 分析
  static List<_JsonClassInfo> encode(Map<String, dynamic> jsonMap) {
    List<_JsonClassInfo> result = [];
    find(jsonMap, 'Root', (name, content) {
      result.add(content);
    });
    return result.reversed.toList();
  }

  /// 递归分析json类型
  static find(
    Map<String, dynamic> jsonMap,
    String rootName,
    void Function(String, _JsonClassInfo) onFind,
  ) {
    rootName ??= "Root";
    var result = _JsonClassInfo(
      rootName,
      <JsonPropertyInfo>[].toSet(),
    );
    var restMapKey = <String>[].toSet();
    for (var key in jsonMap.keys) {
      var value = jsonMap[key];
      var propertyInfo = JsonPropertyInfo(key, value);
      if (propertyInfo.isMap) {
        restMapKey.add(key);
      }
      if (propertyInfo.isList) {
        List list = jsonMap[key];
        Map<String, dynamic> listTypeMap = {};
        // 应当合并List内的Map
        for (var item in list) {
          if (item is Map) {
            listTypeMap.addAll(item);
          }
        }
        // 如果找不到Map，解析为基础类型
        if (listTypeMap.isEmpty) {
          propertyInfo.childT = list.typeString;
        } else {
          propertyInfo.childT = key;
          find(listTypeMap, key, onFind);
        }
      }
      result.props.add(propertyInfo);
    }

    // 分析Map
    for (var mapKey in restMapKey) {
      find(jsonMap[mapKey], mapKey, onFind);
    }

    // 上报然后继续找
    onFind?.call(rootName, result);
  }
}

/// js的一个类
class _JsonClassInfo {
  final String name;
  final Set<JsonPropertyInfo> props;

  String get className => name.firstToUp;

  _JsonClassInfo(this.name, this.props);

  @override
  String toString() {
    return '$name:\n${props.join('\n')}';
  }

  @override
  int get hashCode => '$name'.hashCode;

  operator ==(dynamic other) {
    return (other is _JsonClassInfo) ? other.hashCode == hashCode : false;
  }
}

/// js的单个属性
class JsonPropertyInfo {
  /// 属性的名称，不应当直接用于生成
  final String key;

  /// Json值的类型
  final _JsonValueType valueType;

  /// 范型T，不应当直接用于生成
  String childT;

  bool get isMap => valueType == _JsonValueType.map;
  bool get isList => valueType == _JsonValueType.list;
  bool get isNotNativeList => isList && !isNativeList;
  bool get isNativeList =>
      valueType == _JsonValueType.list &&
      (childT == "int" ||
          childT == 'double' ||
          childT == 'String' ||
          childT == 'Map' ||
          childT == 'List' ||
          childT == null);

  // 用于build的属性
  String get propertyName => key;
  String get jsonKey => key;
  String get childTClassName {
    if (childT == "int" || childT == 'double') {
      return childT;
    }
    return childT.firstToUp;
  }

  String get safeMapType => valueType.safeMapGetterType;

  /// 开头大写的类名
  String get className {
    var name = valueType.name;
    if (isList) {
      return 'List<$childTClassName>';
    }
    if (isMap) {
      return key.firstToUp;
    }
    return name;
  }

  JsonPropertyInfo.type(
    this.key,
    this.valueType, [
    this.childT,
  ]);

  JsonPropertyInfo(
    this.key,
    dynamic value, [
    this.childT,
  ]) : valueType = _JsonValueTypeBuilder.fromValue(value);

  @override
  String toString() {
    if (isList) {
      return '<键:$key 类型:$valueType<$childT>>';
    }
    if (isMap) {
      return '<键:$key 类型:$key>';
    }
    return '<键:$key 类型:$valueType>';
  }

  @override
  int get hashCode => '$key:$valueType'.hashCode;

  operator ==(dynamic other) {
    return (other is JsonPropertyInfo) ? other.hashCode == hashCode : false;
  }
}

/// 模板代码
String _() => """
class Name {
  final String id;
  final String name;
  final String classification;
  final List<CreatedAt> createdAt;

  Name({
    this.id,
    this.name,
    this.classification,
    this.createdAt,
  });

  Name.fromJson(Map<String, dynamic> json) : this.fromSafeMap(SafeMap(json));

  Name.fromSafeMap(SafeMap safeMap)
      : this(
          id: safeMap['id'].string,
          name: safeMap['name'].string,
          classification: safeMap['classification'].string,
          createdAt: safeMap['createdAt']
              .list
              ?.map<CreatedAt>((json) => CreatedAt.fromJson(json))
              ?.toList(),
        );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'classification': classification,
        'createdAt': createdAt,
      };

  @override
  String toString() {
    return json.encode(this);
  }
}
""";
