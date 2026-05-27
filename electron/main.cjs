const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage, screen } = require('electron')
const path = require('path')
const fs = require('fs')

const os = require('os')
// macOS/Linux 用 /tmp（向后兼容），Windows 用 ~/.claude/（/tmp 不存在）
const TMP          = process.platform === 'win32' ? path.join(os.homedir(), '.claude') : '/tmp'
const STATE_FILE   = path.join(TMP, 'cc_traffic_light_state')
const PID_FILE     = path.join(TMP, 'cc_traffic_light_electron.pid')
const THEME_FILE   = path.join(TMP, 'cc_traffic_light_theme')
const MUTE_FILE    = path.join(TMP, 'cc_traffic_light_mute')
const STYLE_FILE   = path.join(TMP, 'cc_traffic_light_style')
// 统计文件存到 ~/.claude/，跨平台持久化，不放 /tmp 避免重启丢失
const STATS_FILE   = path.join(os.homedir(), '.claude', 'cc_traffic_light_stats.json')
const distPath     = path.join(__dirname, '../dist/index.html')
const isDev        = !fs.existsSync(distPath)

const TRAY_ICON_B64 = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAARklEQVR4nGNgIAD+WxvcIaQGp0Z0TD8DsGmmiiHkeWE+F5kGgDSiYfoZgE0zVQwhywsGFyPIMwCkER3TzwBsmqliCE28AAC/pr8bZBUK/QAAAABJRU5ErkJggg=='

function readTheme() {
  try {
    const t = fs.existsSync(THEME_FILE) ? fs.readFileSync(THEME_FILE, 'utf-8').trim() : ''
    return (t === 'light' || t === 'dark') ? t : 'dark'
  } catch { return 'dark' }
}

function readMute() {
  try {
    return fs.existsSync(MUTE_FILE) && fs.readFileSync(MUTE_FILE, 'utf-8').trim() === 'true'
  } catch { return false }
}

function readStyle() {
  try {
    const s = fs.existsSync(STYLE_FILE) ? fs.readFileSync(STYLE_FILE, 'utf-8').trim() : ''
    return s === 'single' ? 'single' : 'triple'
  } catch { return 'triple' }
}

function getToday() {
  // 用本地时区日期，避免跨时区问题
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

function readStats() {
  try {
    return fs.existsSync(STATS_FILE) ? JSON.parse(fs.readFileSync(STATS_FILE, 'utf-8')) : {}
  } catch { return {} }
}

function saveStats(stats) {
  try {
    fs.mkdirSync(path.dirname(STATS_FILE), { recursive: true })
    fs.writeFileSync(STATS_FILE, JSON.stringify(stats, null, 2))
  } catch {}
}

function recordStateChange(newState, prevState, redStartTime) {
  const today = getToday()
  const stats = readStats()
  if (!stats[today]) stats[today] = { redCount: 0, greenCount: 0, redDuration: 0 }
  if (newState === 'red') {
    stats[today].redCount++
  } else if (newState === 'green') {
    stats[today].greenCount++
    if (prevState === 'red' && redStartTime) {
      stats[today].redDuration += Date.now() - redStartTime
    }
  }
  saveStats(stats)
}

function getClaudeSettingsPath() {
  // 优先检测 CC 实际使用的配置目录，避免因安装方式不同导致路径错误
  const candidates = [
    path.join(os.homedir(), '.claude', 'settings.json'),
  ]
  if (process.platform === 'win32') {
    // 桌面版 / 不同安装方式可能写到 AppData
    const appdata = process.env.APPDATA || ''
    const localappdata = process.env.LOCALAPPDATA || ''
    candidates.push(
      path.join(appdata, 'Claude Code', 'settings.json'),
      path.join(appdata, 'Claude', 'settings.json'),
      path.join(localappdata, 'Claude Code', 'settings.json'),
      path.join(localappdata, 'AnthropicClaude', 'settings.json'),
    )
  }
  // 返回第一个已存在的路径；都不存在则用默认
  for (const p of candidates) {
    if (fs.existsSync(p)) return p
  }
  return candidates[0]
}

function setupClaudeHooks() {
  const settingsPath = getClaudeSettingsPath()
  const settingsDir  = path.dirname(settingsPath)

  const isWin = process.platform === 'win32'
  // Windows 用 %USERPROFILE% 环境变量，避免硬编码绝对路径导致跨机器失效
  const stateCmd = (color) => isWin
    ? `cmd /c "echo ${color}> %USERPROFILE%\\.claude\\cc_traffic_light_state"`
    : `echo ${color} > ${STATE_FILE}`

  // 红绿灯逻辑：
  // 黄灯 = Claude 正在回复/输出 token/思考（Start 事件）
  // 红灯 = 会话中断（需要用户输入、网络问题、异常终止）
  // 绿灯 = Claude 成功完成回复（Stop 事件）
  const HOOKS_TO_ADD = [
    { event: 'Start',            command: stateCmd('yellow') },  // Claude 开始输出 → 黄灯
    { event: 'Stop',             command: stateCmd('green')  },  // Claude 完成 → 绿灯
    { event: 'PreToolUse',       matcher: 'AskUserQuestion', command: stateCmd('red') },  // 需要用户选择 → 红灯
    { event: 'UserPromptSubmit', command: stateCmd('yellow') },  // 用户提交后立即黄灯（Claude 即将开始）
  ]
  // 需要清理的旧事件
  const EVENTS_TO_CLEAN = ['UserPromptSubmit', 'Stop', 'PreToolUse', 'Start', 'Elicitation']

  let settings = {}
  try {
    if (fs.existsSync(settingsPath)) {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'))
    }
  } catch {
    settings = {}
  }

  if (!settings.hooks) settings.hooks = {}

  // 清理所有旧的红绿灯 hook（含绝对路径旧版本、Elicitation 废弃事件）
  let changed = false
  for (const event of EVENTS_TO_CLEAN) {
    if (!Array.isArray(settings.hooks[event])) continue
    const before = settings.hooks[event].length
    settings.hooks[event] = settings.hooks[event].filter(h => {
      if (!Array.isArray(h.hooks)) return true
      return !h.hooks.some(hh =>
        typeof hh.command === 'string' && hh.command.includes('cc_traffic_light_state')
      )
    })
    if (settings.hooks[event].length !== before) changed = true
    // 清空后删除空数组，避免留下空 key
    if (settings.hooks[event].length === 0) delete settings.hooks[event]
  }

  // 写入新 hook（matcher 仅在需要时写入，生命周期事件不加 matcher）
  for (const { event, matcher, command } of HOOKS_TO_ADD) {
    if (!Array.isArray(settings.hooks[event])) settings.hooks[event] = []
    const entry = { hooks: [{ type: 'command', command }] }
    if (matcher) entry.matcher = matcher
    settings.hooks[event].push(entry)
    changed = true
  }

  if (changed) {
    try {
      fs.mkdirSync(settingsDir, { recursive: true })
      fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8')
      lastConfiguredSettingsPath = settingsPath
    } catch (e) {
      const { dialog } = require('electron')
      dialog.showErrorBox('CC 红绿灯', `自动配置失败，请手动添加 hooks：\n${e.message}\n\n配置文件路径：${settingsPath}`)
    }
  } else {
    lastConfiguredSettingsPath = settingsPath
  }
}

let lastConfiguredSettingsPath = ''
let mainWin = null

function needsUpdate(remoteVersion) {
  try {
    const current = require('../package.json').version
    const parse = v => v.split('.').map(Number)
    const [rMaj, rMin, rPat] = parse(remoteVersion)
    const [cMaj, cMin, cPat] = parse(current)
    return rMaj > cMaj || (rMaj === cMaj && rMin > cMin) || (rMaj === cMaj && rMin === cMin && rPat > cPat)
  } catch { return false }
}

function handleRemoteConfig({ version, notes, message }, manual = false) {
  const { dialog, shell } = require('electron')
  const showUpdate = () => {
    if (!version || !needsUpdate(version)) {
      if (manual) {
        const current = require('../package.json').version
        dialog.showMessageBox({
          type: 'info',
          title: 'CC 红绿灯',
          message: `当前已是最新版本 v${current}`,
          buttons: ['好的'],
        })
      }
      return
    }
    dialog.showMessageBox({
      type: 'info',
      title: '发现新版本',
      message: `CC 红绿灯 v${version} 已发布`,
      detail: (notes || '') + '\n\n点击"立即更新"跳转到下载页面。',
      buttons: ['立即更新', '稍后再说'],
      defaultId: 0,
    }).then(({ response }) => {
      if (response === 0) {
        shell.openExternal('https://github.com/freed85-xiaozai/Claude-Code-Traffic-Light-Prompt/releases/latest')
      }
    })
  }

  if (message && message.trim()) {
    dialog.showMessageBox({
      type: 'info',
      title: '来自作者的消息',
      message: message.trim(),
      buttons: ['知道了'],
    }).then(showUpdate)
  } else {
    showUpdate()
  }
}

function checkForUpdates(manual = false) {
  const https = require('https')
  const url = 'https://cdn.jsdelivr.net/gh/freed85-xiaozai/Claude-Code-Traffic-Light-Prompt@main/public/update.json'
  const req = https.get(url, (res) => {
    let data = ''
    res.on('data', chunk => { data += chunk })
    res.on('end', () => {
      try { handleRemoteConfig(JSON.parse(data), manual) } catch {}
    })
  })
  req.on('error', () => {
    if (manual) {
      const { dialog } = require('electron')
      dialog.showErrorBox('CC 红绿灯', '检查更新失败，请检查网络连接。')
    }
  })
  req.setTimeout(8000, () => req.destroy())
}

function buildAppMenu(currentTheme) {
  return Menu.buildFromTemplate([
    {
      label: 'CC 红绿灯',
      submenu: [
        { label: '关于 CC 红绿灯', role: 'about' },
        { type: 'separator' },
        {
          label: currentTheme === 'dark' ? '切换浅色模式' : '切换深色模式',
          click: () => {
            const next = currentTheme === 'dark' ? 'light' : 'dark'
            try { fs.writeFileSync(THEME_FILE, next) } catch {}
            if (mainWin) mainWin.webContents.send('theme-change', next)
            Menu.setApplicationMenu(buildAppMenu(next))
          }
        },
        { type: 'separator' },
        { label: '隐藏', role: 'hide' },
        { label: '退出', accelerator: 'Cmd+Q', click: () => app.quit() }
      ]
    },
    {
      label: '灯色',
      submenu: [
        { label: '🔴  红灯（思考中）', click: () => { try { fs.writeFileSync(STATE_FILE, 'red') } catch {} } },
        { label: '🟡  黄灯（等待中）', click: () => { try { fs.writeFileSync(STATE_FILE, 'yellow') } catch {} } },
        { label: '🟢  绿灯（已完成）', click: () => { try { fs.writeFileSync(STATE_FILE, 'green') } catch {} } },
      ]
    },
    {
      label: '窗口',
      submenu: [
        { label: '最小化', role: 'minimize' },
        { type: 'separator' },
        { label: '退出', accelerator: 'Cmd+Q', click: () => app.quit() }
      ]
    }
  ])
}

function buildTrayMenu(currentTheme, currentStyle) {
  const isSingle = currentStyle === 'single'
  return Menu.buildFromTemplate([
    { label: '切换到红灯', click: () => { try { fs.writeFileSync(STATE_FILE, 'red') } catch {} } },
    { label: '切换到黄灯', click: () => { try { fs.writeFileSync(STATE_FILE, 'yellow') } catch {} } },
    { label: '切换到绿灯', click: () => { try { fs.writeFileSync(STATE_FILE, 'green') } catch {} } },
    { type: 'separator' },
    {
      label: isSingle ? '切换到三灯样式' : '切换到单灯样式',
      click: () => {
        const next = isSingle ? 'triple' : 'single'
        try { fs.writeFileSync(STYLE_FILE, next) } catch {}
        if (mainWin) mainWin.webContents.send('style-change', next)
        tray.setContextMenu(buildTrayMenu(currentTheme, next))
      }
    },
    { type: 'separator' },
    {
      label: '查看配置路径',
      click: () => {
        const { dialog, shell } = require('electron')
        const p = lastConfiguredSettingsPath || getClaudeSettingsPath()
        dialog.showMessageBox({
          type: 'info',
          title: 'CC 红绿灯 — 配置路径',
          message: 'Hooks 已写入以下文件：',
          detail: p + '\n\n如果红绿灯不响应，请确认 Claude Code 读取的是这个文件。\n点击"打开文件"可直接查看内容。',
          buttons: ['打开文件', '关闭'],
          defaultId: 1,
        }).then(({ response }) => { if (response === 0) shell.openPath(p) })
      }
    },
    {
      label: '重新写入配置',
      click: () => {
        setupClaudeHooks()
        const { dialog } = require('electron')
        dialog.showMessageBox({
          type: 'info',
          title: 'CC 红绿灯',
          message: '配置已重新写入',
          detail: lastConfiguredSettingsPath || getClaudeSettingsPath(),
          buttons: ['确定'],
        })
      }
    },
    {
      label: '复制手动配置',
      click: () => {
        const { clipboard, dialog } = require('electron')
        const isWin = process.platform === 'win32'
        const snippet = isWin
          ? `"UserPromptSubmit": [{"hooks": [{"type": "command","command": "cmd /c \\"echo red> %USERPROFILE%\\\\.claude\\\\cc_traffic_light_state\\""}]}],\n  "Stop": [{"hooks": [{"type": "command","command": "cmd /c \\"echo green> %USERPROFILE%\\\\.claude\\\\cc_traffic_light_state\\""}]}],\n  "PreToolUse": [{"matcher": "AskUserQuestion","hooks": [{"type": "command","command": "cmd /c \\"echo yellow> %USERPROFILE%\\\\.claude\\\\cc_traffic_light_state\\""}]}]`
          : `"UserPromptSubmit": [{"hooks": [{"type": "command","command": "echo red > /tmp/cc_traffic_light_state"}]}],\n  "Stop": [{"hooks": [{"type": "command","command": "echo green > /tmp/cc_traffic_light_state"}]}],\n  "PreToolUse": [{"matcher": "AskUserQuestion","hooks": [{"type": "command","command": "echo yellow > /tmp/cc_traffic_light_state"}]}]`
        clipboard.writeText(snippet)
        dialog.showMessageBox({
          type: 'info',
          title: 'CC 红绿灯',
          message: '已复制到剪贴板',
          detail: '请打开 Claude Code 的 settings.json，在 "hooks": { } 内粘贴，保存后重启 Claude Code 即可。\n\n配置文件路径：' + (lastConfiguredSettingsPath || getClaudeSettingsPath()),
          buttons: ['打开配置文件', '关闭'],
          defaultId: 1,
        }).then(({ response }) => {
          if (response === 0) {
            const { shell } = require('electron')
            shell.openPath(lastConfiguredSettingsPath || getClaudeSettingsPath())
          }
        })
      }
    },
    { type: 'separator' },
    {
      label: currentTheme === 'dark' ? '切换浅色模式' : '切换深色模式',
      click: () => {
        const next = currentTheme === 'dark' ? 'light' : 'dark'
        try { fs.writeFileSync(THEME_FILE, next) } catch {}
        if (mainWin) mainWin.webContents.send('theme-change', next)
        tray.setContextMenu(buildTrayMenu(next, currentStyle))
        Menu.setApplicationMenu(buildAppMenu(next))
      }
    },
    { type: 'separator' },
    {
      label: '本周周报',
      click: () => {
        const { dialog } = require('electron')
        const stats = readStats()
        const today = new Date()
        const dow = today.getDay() || 7
        let totalRed = 0, totalGreen = 0, totalDuration = 0
        for (let i = 1; i <= dow; i++) {
          const d = new Date(today)
          d.setDate(today.getDate() - (dow - i))
          const key = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
          const day = stats[key]
          if (day) {
            totalRed      += day.redCount   || 0
            totalGreen    += day.greenCount  || 0
            totalDuration += day.redDuration || 0
          }
        }
        const h = Math.floor(totalDuration / 3600000)
        const m = Math.floor((totalDuration % 3600000) / 60000)
        const durStr = h > 0 ? `${h} 小时 ${m} 分钟` : `${m} 分钟`
        dialog.showMessageBox({
          type: 'info',
          title: '本周周报',
          message: '本周 Claude Code 使用情况',
          detail: `思考次数：${totalRed} 次\n回复次数：${totalGreen} 次\n思考总时长：${durStr}`,
          buttons: ['好的'],
        })
      }
    },
    {
      label: '检查更新',
      click: () => checkForUpdates(true)
    },
    { type: 'separator' },
    { label: '退出', click: () => app.quit() }
  ])
}

function createWindow() {
  const { width: sw, height: sh } = screen.getPrimaryDisplay().workAreaSize

  // 读取上次保存的位置，若超出屏幕则重置到右上角
  const POS_FILE = path.join(require('os').tmpdir(), 'cc_traffic_light_pos')
  let wx = sw - 120, wy = 80
  try {
    if (fs.existsSync(POS_FILE)) {
      const [px, py] = fs.readFileSync(POS_FILE, 'utf-8').split(',').map(Number)
      if (px >= 0 && px < sw - 20 && py >= 0 && py < sh - 20) { wx = px; wy = py }
    }
  } catch {}

  mainWin = new BrowserWindow({
    width: 100,
    height: 220,
    x: wx,
    y: wy,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    hasShadow: false,
    roundedCorners: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      sandbox: false
    }
  })

  mainWin.setAlwaysOnTop(true, 'floating')
  mainWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })

  if (isDev) {
    mainWin.loadURL('http://localhost:5173')
  } else {
    mainWin.loadFile(distPath)
  }

  let lastState = ''
  let lastTheme = readTheme()
  let redStartTime = null

  const poll = setInterval(() => {
    try {
      if (fs.existsSync(STATE_FILE)) {
        const state = fs.readFileSync(STATE_FILE, 'utf-8').trim()
        if (state !== lastState) {
          recordStateChange(state, lastState, redStartTime)
          if (state === 'red') redStartTime = Date.now()
          else redStartTime = null
          lastState = state
          mainWin.webContents.send('state-change', state)
        }
      }
    } catch {}
  }, 300)

  mainWin.on('closed', () => { clearInterval(poll); mainWin = null })
  mainWin.on('moved', () => {
    try {
      const [x, y] = mainWin.getPosition()
      fs.writeFileSync(path.join(require('os').tmpdir(), 'cc_traffic_light_pos'), `${x},${y}`)
    } catch {}
  })

  ipcMain.on('set-state', (_, state) => {
    try { fs.writeFileSync(STATE_FILE, state); lastState = state } catch {}
  })

  ipcMain.on('focus-app', () => {
    app.focus({ steal: true })
    if (mainWin) mainWin.focus()
  })

  ipcMain.on('quit', () => app.quit())

  ipcMain.handle('get-theme', () => readTheme())

  ipcMain.handle('get-mute', () => readMute())

  ipcMain.on('set-mute', (_, muted) => {
    try { fs.writeFileSync(MUTE_FILE, muted ? 'true' : 'false') } catch {}
  })

  ipcMain.on('set-window-height', (_, h) => {
    if (mainWin) mainWin.setSize(100, h)
  })

  ipcMain.on('set-theme', (_, theme) => {
    lastTheme = theme
    try { fs.writeFileSync(THEME_FILE, theme) } catch {}
    if (tray) tray.setContextMenu(buildTrayMenu(theme, readStyle()))
    Menu.setApplicationMenu(buildAppMenu(theme))
  })

  ipcMain.handle('get-style', () => readStyle())

  ipcMain.on('set-style', (_, style) => {
    try { fs.writeFileSync(STYLE_FILE, style) } catch {}
    if (tray) tray.setContextMenu(buildTrayMenu(readTheme(), style))
  })

  ipcMain.handle('get-stats', () => readStats())
}

app.whenReady().then(() => {
  // 确保 ~/.claude 目录存在
  try { fs.mkdirSync(TMP, { recursive: true }) } catch {}

  if (process.platform !== 'win32') {
    // 杀掉旧的 Python 版，防止两个红绿灯同时出现
    require('child_process').exec("pkill -f 'traffic_light.py'")
  }

  setupClaudeHooks()

  try { fs.writeFileSync(PID_FILE, process.pid.toString()) } catch {}

  const theme = readTheme()
  const style = readStyle()

  // macOS 应用菜单栏
  Menu.setApplicationMenu(buildAppMenu(theme))

  // 系统托盘（右上角）
  const icon = nativeImage.createFromDataURL(`data:image/png;base64,${TRAY_ICON_B64}`)
  tray = new Tray(icon)
  tray.setToolTip('CC 红绿灯')
  tray.setContextMenu(buildTrayMenu(theme, style))

  createWindow()

  // 启动 3 秒后静默检查更新和消息
  setTimeout(checkForUpdates, 3000)
})

app.on('will-quit', () => {
  try { fs.unlinkSync(PID_FILE) } catch {}
})

app.on('window-all-closed', () => app.quit())
