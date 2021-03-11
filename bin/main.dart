import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:args/args.dart';

import 'controller/generator.dart';

const cookie =
    "_yapi_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjUzLCJpYXQiOjE2MTUxODc5ODYsImV4cCI6MTYxNTc5Mjc4Nn0.fhAkI_6fGJH1HUbK2sbkggrzqpOgsxPiZSGnG5FtEhc; _yapi_uid=53";

var httpClient = HttpClient();

ArgParser get argParser {
  var _parser = ArgParser()
    ..addOption(
      'name',
      help: "类名",
    )
    ..addOption(
      'id',
      help: "接口id",
    );
  return _parser;
}

main(List<String> args) async {
  /// 解析输入
  ArgResults argResults = argParser.parse(args);

  var id = argResults['id'];
  var name = argResults['name'];

  if (id == null && name == null) {
    print('id和name必须指定');
    return -1;
  }

  var resData = await http.get(
    'http://49.232.195.143:3000/api/interface/get?id=$id',
    headers: {
      'Cookie': cookie,
    },
  );
  var jsonString = resData.body;
  var map = json.decode(jsonString);
  var content = map['data']['res_body'];
  var res = json.decode(content);
  var data = res['properties']['data']['properties'] as Map;
  Set<JsonPropertyInfo> props = Set();
  Map<String, String> commentMap = {};
  for (var key in data.keys) {
    props.add(
      JsonPropertyInfo.type(
        key,
        JsonValueTypeBuilder.fromYapiName(data[key]['type']),
      ),
    );
    commentMap[key] = data[key]['description'];
  }
  JsonClassInfo jsonClassInfo = JsonClassInfo(name, props);

  var finalRes = SafeMapFileGenarater(commentMap).oneClassContentFromClass(
    jsonClassInfo,
  );

  // print(finalRes);
  var result = await Process.run('bash', ['-c', 'echo "$finalRes" | pbcopy']);
  print(result.exitCode);
  print(result.stdout);
  print(result.stderr);
  if (result.exitCode == 0) {
    print('代码已经粘贴到剪贴板');
  }
}

// inputCookie() {
//   var input = stdin.readLineSync(retainNewlines: true);
//   print('粘贴cookie');
//   input = input.replaceAll('\n', '').replaceAll('\r', '').toLowerCase();
// }
