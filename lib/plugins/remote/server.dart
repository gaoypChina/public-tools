import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../utils/logger.dart';

Map<String, dynamic> _addToMap(
    String key, dynamic value, Map<String, dynamic> map) {
  map[key] = value;
  return map;
}

class MessageData {
  String? type;
  Map<String, dynamic> payload;
  int time;
  String id;
  String replyId;

  MessageData({
    this.type,
    required this.payload,
    int? time,
    String? id,
    String? replyId,
  })  : time = time ?? DateTime.now().millisecondsSinceEpoch,
        id = id ?? Uuid().v4(),
        replyId = id ?? Uuid().v4();

  MessageData.fromJson(Map<String, dynamic> json)
      : type = json['type'],
        payload = json['payload'],
        time = json['time'],
        id = json['id'],
        replyId = json['replyId'];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['payload'] = this.payload;
    data['id'] = this.id;
    data['replyId'] = this.replyId;
    data['time'] = this.time;
    return data;
  }

  MessageData makeReplyMessage(Map<String, dynamic> payload) {
    return MessageData(
      type: this.type,
      payload: payload,
      id: this.replyId,
    );
  }

  MessageData.makeEventMessage(String eventName, Map<String, dynamic> payload)
      : this.payload = _addToMap('event', eventName, payload),
        this.type = 'event',
        this.id = Uuid().v4(),
        this.replyId = Uuid().v4(),
        this.time = DateTime.now().millisecondsSinceEpoch;
}

String makeMessageData(String? type, Map<String, dynamic> payload) {
  return jsonEncode(MessageData(type: type, payload: payload).toJson());
}

class RemotePluginServer {
  HttpServer? _server;
  WebSocket? _socket;
  Map<String, List<void Function(Map<String, dynamic>)>> _handlers = {};

  final Function onReady;
  final Function onDisconnect;
  Map<String?, StreamController<MessageData>> _messages = {};

  RemotePluginServer({required this.onReady, required this.onDisconnect}) {
    this._init();
  }

  void _init() async {
    this._server = await HttpServer.bind('127.0.0.1', 4040);
    this._server!.listen(
      (HttpRequest req) async {
        logger.i('新的链接: ${req.uri}');
        if (req.uri.path != '/ws' || this._socket != null) {
          return;
        }
        logger.i('新的socket已连接');
        // ignore: close_sinks
        var socket = await WebSocketTransformer.upgrade(req);
        socket.done.then((data) {
          logger.i('socket done');
          this._socket!.close();
          this._socket = null;
          this.onDisconnect();
        });
        socket.handleError((error) {
          logger.i('socket error: $error');
          this._socket!.close();
          this._socket = null;
          this.onDisconnect();
        });
        socket.map((string) => jsonDecode(string)).listen(_onMessage);
        this._socket = socket;
        this.onReady();
      },
    );
  }

  void _onMessage(dynamic data) async {
    final message = MessageData.fromJson(data);
    logger.i('收到消息: ${message.toJson()}');
    if (_messages[message.id] != null) {
      _messages[message.id]!.add(message);
      _messages[message.id]!.close();
      _messages.remove(message.id);
    }
    if (message.type == 'event') {
      if (_handlers[message.payload['event']] != null) {
        _handlers[message.payload['event']]!.forEach((element) {
          element(message.payload);
        });
      }
    }
  }

  Future invoke(String action, Map<String, dynamic> payload) async {
    if (_socket == null) return;
    final message = MessageData(type: action, payload: payload);
    // ignore: close_sinks
    final streamController = StreamController<MessageData>();
    _messages[message.replyId] = streamController;
    Future.delayed(Duration(seconds: 5), () {
      if (_messages[message.replyId] != null) {
        _messages[message.replyId]!
            .add(MessageData(type: 'error', payload: {'message': 'timeout'}));
        _messages[message.replyId]!.close();
        _messages.remove(message.replyId);
      }
    });
    _socket!.add(json.encode(message));
    final result = await streamController.stream.first;
    if (result.type == 'error') {
      throw Exception(result.payload['message']);
    }
    _messages.remove(message.time);
    return result.payload;
  }

  void on(eventName, void Function(Map<String, dynamic>) callback) {
    final eventHandlers = _handlers[eventName] ??= [];
    eventHandlers.add(callback);
    _handlers[eventName] = eventHandlers;
  }

  void off(eventName, void Function(Map<String, dynamic>) callback) {
    final eventHandlers = _handlers[eventName] ??= [];
    eventHandlers.remove(callback);
    _handlers[eventName] = eventHandlers;
  }
}

void _downloadJSFiles() async {
  // @todo 下载地址
  const downloadUrl =
      'https://nodejs.org/dist/v16.13.0/node-v16.13.0-darwin-x64.tar.gz';
  final dir = await getApplicationSupportDirectory();
  final filePath = '${dir.path}/inner-plugins.zip';
  final pluginsDirPath = '${dir.path}/inner-plugins';
  if (File(filePath).existsSync()) {
    File(filePath).deleteSync();
  }
  if (Directory(pluginsDirPath).existsSync()) {
    File(pluginsDirPath).deleteSync(recursive: true);
  }
  final request = await HttpClient().getUrl(Uri.parse(downloadUrl));
  final response = await request.close();
  final file = File(filePath);
  await response.pipe(file.openWrite()).catchError((error) {
    file.deleteSync();
    logger.e('download nodejs error: $error');
    throw error;
  }, test: (error) => false);
  logger.i('download success');
  Process.run("unzip", ['-d', pluginsDirPath]);
}

void runClient(binPath) async {
  if (Platform.environment['REMOTE_PLUGIN_MODE'] == 'debug') {
    return;
  }
  var pluginDir = '/Users/qwertyyb/projects/YPaste-flutter/plugins';
  if (Platform.environment["REMOTE_PLUGIN_MODE"] == 'local') {
    pluginDir = Directory.current.path + '/plugins';
  }
  final newEnv = Map<String, String>.from(Platform.environment);
  newEnv['PATH'] = '$binPath:${newEnv['PATH']}';
  // 安装依赖
  final installProcess = await Process.start(
    '$binPath/npm',
    ['install'],
    environment: newEnv,
    workingDirectory: pluginDir,
  );
  final exitCode = await installProcess.exitCode;
  logger.i(exitCode);
  var args = ['./src/index.js'];
  if (Platform.environment['MODE'] == 'debug') {
    args.insert(0, '--inspect');
  }
  final clientProcess = await Process.start(
    '$binPath/node',
    args,
    workingDirectory: pluginDir,
    environment: newEnv,
    runInShell: true,
  );
  clientProcess.stdout.transform(utf8.decoder).forEach(print);
  clientProcess.stderr.transform(utf8.decoder).forEach(print);
  clientProcess.exitCode.then((code) {
    print('client exit code: $code');
  });
}
