const { v4: uuidv4 } = require('uuid')
const ws = require('./ws')
const path = require('path')

let curPlugin = null;
const plugins = new Map();

class MessageData {
  time = Date.now();
  id = uuidv4();
  replyId = uuidv4();
  type = 'event';
  payload = {};

  constructor(data) {
    this.type = data.type;
    this.payload = data.payload;
    this.replyId = data.replyId;
    this.time = data.time;
    this.id = data.id;
  }

  static fromJSON(data) {
    return new MessageData(JSON.parse(data));
  }

  makeReplyMessage(payload = {}) {
    return new MessageData({
      id: this.replyId,
      time: Date.now(),
      replyId: uuidv4(),
      type: 'callback',
      payload
    });
  }

  static makeEventMessage(eventName, payload = {}) {
    return new MessageData({
      id: uuidv4(),
      time: Date.now(),
      replyId: uuidv4(),
      type: 'event',
      payload: {
        ...payload,
        event: eventName
      }
    });
  }
}

const send = (obj) => {
  console.log('send', JSON.stringify(obj, null, 2));
  return ws.send(JSON.stringify(obj))
}

ws.on('message',async  (message) => {
  const messageData = MessageData.fromJSON(message);
  const { type, payload, replyId } = JSON.parse(message)
  console.log('receive Message', JSON.parse(message))

  if (type === 'getCommands') {
    const commands = Array.from(plugins.values()).map(plugin => {
      const { title, subtitle, description, id, icon, mode, keywords } = plugin;
      return {
        id,
        title,
        subtitle,
        description,
        icon,
        mode,
        keywords
      }
    })
    return send(messageData.makeReplyMessage({ commands }))
  }

  if (type === 'onSearch') {
    const plugin = plugins.get(payload.command.id)
    if (!plugin) {
      console.warn(`插件${payload.command.id}不存在`)
    }
    const results = await plugin.onSearch(payload.keyword)
    return send(messageData.makeReplyMessage({ results }))
  }

  if (type === 'onResultSelected') {
    if (!curPlugin) {
      console.warn(`插件不存在`)
    }
    const html = await curPlugin.onResultSelected(payload.result)
    return send(messageData.makeReplyMessage({ html }))
  }

  if (type === 'onEnter') {
    const plugin = plugins.get(payload.command.id)
    if (!plugin) {
      console.warn(`插件${payload.command.id}不存在`)
    }
    curPlugin = plugin;
    plugin.onEnter(payload.command);
  }

  if (type === 'onResultTap') {
    if (!curPlugin) {
      console.warn(`插件不存在`)
    }
    curPlugin.onResultTap(payload.result)
  }

  if (type === 'onExit') {
    if (!curPlugin) {
      console.warn(`插件不存在`)
    }
    let plugin = curPlugin;
    curPlugin = null;
    plugin.onExit(payload.command)
  }

  if (type === 'event') {
    const { event, handlerName, handlerArgs } = payload;
    if (curPlugin && curPlugin[handlerName]) {
      curPlugin[handlerName](handlerArgs);
    } else if (curPlugin && !curPlugin[handlerName]) {
      console.warn('插件中不存在事件处理器', handlerName)
    }
  }

  return send(messageData.makeReplyMessage({}))
})

const createUtils = () => ({
  toast(content) {
    send(MessageData.makeEventMessage('toast', { content }))
  },
  hideApp() {
    send(MessageData.makeEventMessage('hideApp'))
  },
  showApp() {
    send(MessageData.makeEventMessage('showApp'))
  },
  updateResults(results) {
    send(MessageData.makeEventMessage('updateResults', { results, command: curPlugin.command }))
  }
})


const createPlugin = (pluginCreator) => {
  const plugin = pluginCreator(createUtils())
  const { id } = plugin;
  if (plugins.get(id)) {
    console.warn('当前插件已存在');
  }
  plugins.set(id, plugin)
  return plugin
}

const validatePluginConfig = config => {
  const { name, title, subtitle = '', description = '', icon, mode, keywords } = config;
  const required = []
  if (!name) {
    required.push('name')
  }
  if (!title) {
    required.push('title')
  }
  if (!icon) {
    required.push('icon')
  }
  if (!mode) {
    required.push('mode')
  }
  if (!keywords || !keywords.length) {
    required.push('keywords')
  }
  return { pass: required.length <= 0, msg: `${required.join('、')} 为必填项` };
}

const registerPlugin = (pkgPath) => {
  const config = require(pkgPath);
  const { pass, msg } = validatePluginConfig(config);
  if (!pass) {
    return createUtils().toast(msg);
  }
  const pluginCreator = require(path.join(pkgPath, '../'));
  const plugin = pluginCreator(createUtils());

  const { name, title, subtitle = '', description = '', icon, mode, keywords } = config;
  plugins.set(name, { ...plugin, id: name, title, subtitle, description, icon, mode, keywords });
}

module.exports = registerPlugin