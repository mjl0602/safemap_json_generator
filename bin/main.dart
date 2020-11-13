import 'dart:convert';

import 'controller/generator.dart';

main(List<String> args) {
  var jsonString = {
    "id": 1,
    "score": 99.0,
    "c": "12124",
    "list": [[], []],
    "info": {
      'a': 1,
      'name': "jack",
    },
    'record': [
      {
        'id': 1,
        "title": "test1",
        'past': [
          {
            'recordDetail': [
              {
                'id': 1,
                "title": "test1",
                'past': [1, 2, 3, 4]
              },
              {
                'id': 2,
                "title": "test2",
              },
            ],
          },
        ]
      },
      {
        'id': 2,
        "title": "test2",
      },
    ],
  };
  SafeMapFileGenarater().generate(json.encode(jsonString));
}
