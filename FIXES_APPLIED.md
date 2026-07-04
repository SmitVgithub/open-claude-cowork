# Automated Security Fixes

9 fixes applied:

1. **server/opencode.json** - Replace the hardcoded API key with an environment variable reference. In JSON config files, use a placeholder pattern that your application can resolve at runtime.
2. **preload.js** - Replace hardcoded HTTP URL with environment variable that defaults to HTTPS, allowing secure configuration at deployment time.
3. **clawd/config.js** - Replace wildcard with environment variable for explicit allowlist
4. **clawd/config.js** - Replace wildcard with environment variable for explicit allowlist
5. **clawd/config.js** - Replace wildcard with environment variable for explicit allowlist
6. **clawd/config.js** - Replace with environment variable reference process.env.TELEGRAM_BOT_TOKEN
7. **clawd/config.js** - Replace wildcard with environment variable for explicit allowlist
8. **clawd/config.js** - Replace with environment variable reference process.env.SIGNAL_PHONE_NUMBER
9. **clawd/config.js** - Move allowed tools to environment variable for controlled configuration
