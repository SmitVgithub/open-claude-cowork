export default {
  agentId: process.env.CLAWD_AGENT_ID || 'clawd',

  whatsapp: {
    enabled: process.env.WHATSAPP_ENABLED === 'true',
    allowedDMs: process.env.WHATSAPP_ALLOWED_DMS ? process.env.WHATSAPP_ALLOWED_DMS.split(',') : [],
    allowedGroups: process.env.WHATSAPP_ALLOWED_GROUPS ? process.env.WHATSAPP_ALLOWED_GROUPS.split(',') : [],
    respondToMentionsOnly: process.env.WHATSAPP_MENTIONS_ONLY !== 'false'
  },

  imessage: {
    enabled: process.env.IMESSAGE_ENABLED === 'true',
    allowedDMs: process.env.IMESSAGE_ALLOWED_DMS ? process.env.IMESSAGE_ALLOWED_DMS.split(',') : [],
    allowedGroups: process.env.IMESSAGE_ALLOWED_GROUPS ? process.env.IMESSAGE_ALLOWED_GROUPS.split(',') : [],
    respondToMentionsOnly: process.env.IMESSAGE_MENTIONS_ONLY !== 'false'
  },

  telegram: {
    enabled: process.env.TELEGRAM_ENABLED === 'true',
    token: process.env.TELEGRAM_BOT_TOKEN || '',
    allowedDMs: process.env.TELEGRAM_ALLOWED_DMS ? process.env.TELEGRAM_ALLOWED_DMS.split(',') : [],
    allowedGroups: process.env.TELEGRAM_ALLOWED_GROUPS ? process.env.TELEGRAM_ALLOWED_GROUPS.split(',') : [],
    respondToMentionsOnly: process.env.TELEGRAM_MENTIONS_ONLY !== 'false'
  },

  signal: {
    enabled: process.env.SIGNAL_ENABLED === 'true',
    phoneNumber: process.env.SIGNAL_PHONE_NUMBER || '',
    signalCliPath: process.env.SIGNAL_CLI_PATH || 'signal-cli',
    allowedDMs: process.env.SIGNAL_ALLOWED_DMS ? process.env.SIGNAL_ALLOWED_DMS.split(',') : [],
    allowedGroups: process.env.SIGNAL_ALLOWED_GROUPS ? process.env.SIGNAL_ALLOWED_GROUPS.split(',') : [],
    respondToMentionsOnly: process.env.SIGNAL_MENTIONS_ONLY !== 'false'
  },

  // Agent configuration
  agent: {
    workspace: process.env.CLAWD_WORKSPACE || '~/clawd',
    maxTurns: parseInt(process.env.CLAWD_MAX_TURNS, 10) || 50,
    allowedTools: process.env.CLAWD_ALLOWED_TOOLS 
      ? process.env.CLAWD_ALLOWED_TOOLS.split(',') 
      : ['Read', 'Glob', 'Grep']  // Safe defaults - no Write, Edit, or Bash
  },

  browser: {
    enabled: process.env.BROWSER_ENABLED === 'true',
    mode: process.env.BROWSER_MODE || 'clawd',
    clawd: {
      userDataDir: process.env.BROWSER_USER_DATA_DIR || '~/.clawd-browser-profile',
      headless: process.env.BROWSER_HEADLESS === 'true'
    },
    chrome: {
      profilePath: process.env.CHROME_PROFILE_PATH || '',
      cdpPort: parseInt(process.env.CHROME_CDP_PORT, 10) || 9222
    }
  }
}
