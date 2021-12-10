const clip = require('simple-mac-clipboard')
const robot = require('robotjs')
const jimp = require('jimp')
const detectWithOpencv = require('./qrcode/index')
const createPlugin = require('./core/plugin')

const readQrcodeFromClipboard = () => {
  const pngBuffer = clip.readBuffer('public.png')
  if (pngBuffer.byteLength === 0) {
    console.log('clipboard no image')
    return []
  } else {
    return jimp.read(pngBuffer)
    .then(image => {
      const { width, height, data } = image.bitmap
      console.log({ width, height })
      const result = detectWithOpencv({ width, height, data: data })
      console.log(result)
      return result
    })
  }
}

const plugin = createPlugin('qrcode', {
  title: '二维码',
  subtitle: '生成、识别二维码',
  icon: 'https://img.icons8.com/pastel-glyph/64/4a90e2/qr-code--v1.png'
})

plugin.onKeywordChange(async ({ keyword }) => {
  const results = await readQrcodeFromClipboard();
  const list = results.map(result => {
    return {
      id: `clipboard_${result}`,
      title: result,
      subtitle: '剪切板中的二维码，点击复制',
      icon: 'https://img.icons8.com/pastel-glyph/64/4a90e2/qr-code--v1.png'
    }
  })
  list.push({
    id: 'screen',
    title: '自动识别',
    subtitle: '自动识别当前屏幕中的二维码',
    icon: 'https://img.icons8.com/pastel-glyph/64/4a90e2/qr-code--v1.png'
  })
  plugin.updateList(keyword, list)
})
plugin.onTap(async (item) => {
  if (item.id === 'screen') {
    plugin.hideApp();
    await new Promise(resolve => setTimeout(resolve, 50))
    const bitmap = robot.screen.capture();
    const results = detectWithOpencv({ data: bitmap.image, width: bitmap.width, height: bitmap.height })
    if (!results.length) {
      plugin.showApp();
      return plugin.toast({ content: '未在当前屏幕检测到二维码' })
    } else {
      plugin.toast({ content: `已在当前屏幕检测到${results.length}个二维码` })
    }
    const list = results.map(result => {
      return {
        id: `clipboard_${result}`,
        title: result,
        subtitle: '当前屏幕中的二维码，点击复制',
        icon: 'https://img.icons8.com/pastel-glyph/64/4a90e2/qr-code--v1.png'
      }
    })
    list.push({
      id: 'screen',
      title: '自动识别',
      subtitle: '自动识别当前屏幕中的二维码',
      icon: 'https://img.icons8.com/pastel-glyph/64/4a90e2/qr-code--v1.png'
    })
    plugin.showApp()
    plugin.updateList('', list)
    return;
  }

  clip.writeText('public.utf8-plain-text', item.title)
  plugin.toast({ content: '已复制' })
  setTimeout(() => {
    plugin.hideApp()
  }, 500)
})

module.exports = plugin

