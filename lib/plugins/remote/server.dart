import 'dart:convert';
import 'dart:io';

import 'package:public_tools/core/plugin_result_item.dart';

typedef void ListReceiver(List<PluginListItem<String>> list);
typedef void EnterItemReceiver();

List<WebSocket> sockets = [];
List<ListReceiver> receivers = [];
List<EnterItemReceiver> enterItemReceivers = [];

class MessageData {
  String type;
  Map<String, dynamic> payload;

  MessageData({this.type, this.payload});

  MessageData.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    payload = json['payload'];
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['payload'] = this.payload;
    return data;
  }
}

String makeMessageData(String type, Map<String, dynamic> payload) {
  return jsonEncode(MessageData(type: type, payload: payload).toJson());
}

void Function(dynamic) _createHandler(WebSocket socket) {
  return (dynamic data) {
    final message = MessageData.fromJson(data);
    if (message.type == 'list') {
      List<PluginListItem<String>> list = message.payload["list"]
          .map<PluginListItem<String>>(
              (e) => PluginListItem<String>.fromJson(e))
          .toList();
      receivers.forEach((element) {
        element(list);
      });
    } else if (message.type == 'enter') {
      // final item = PluginListItem<String>.fromJson(message.payload["item"]);
      enterItemReceivers.forEach((element) {
        element();
      });
    }
    // socket.add(jsonEncode(data));
  };
}

void runServer() async {
  var server = await HttpServer.bind('127.0.0.1', 4040);
  server.listen((HttpRequest req) async {
    if (req.uri.path == '/ws') {
      var socket = await WebSocketTransformer.upgrade(req);
      sockets.add(socket);
      socket.map((string) => jsonDecode(string)).listen(_createHandler(socket),
          onDone: () {
        socket.close();
        sockets = sockets.where((element) => element != socket).toList();
      });
    }
  });
}

void send(String type, Map<String, dynamic> payload) {
  sockets.forEach((element) {
    print("sendMessage");
    print(makeMessageData(type, payload));
    element.add(makeMessageData(type, payload));
  });
}

void onUpdateList(ListReceiver receiver) {
  receivers.add(receiver);
}
