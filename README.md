# Chelka for Mac

**Chelka** ("чёлка", Russian for the MacBook notch) turns the notch into a live dashboard for your AI agents, music and system events.

Chelka is a fork of [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam and is released under the same license, **GPL-3.0**. See [CHANGES.md](CHANGES.md) for everything added on top of the original.

> macOS 14+ · Apple Silicon or Intel · SwiftUI

## What's new compared to Boring Notch

**AI agents in the notch** (Claude Code, Codex, Cursor, Kimi)
- A thin ring and equalizer show that an agent is working; a banner expands the notch with a sound when it finishes, fails or needs you.
- "Agents" tab in the open notch with every active session, how long it has been in its state, and a click to jump to the right window.
- Approve or deny Claude Code permission requests right in the notch.
- Codex is detected from its session logs, no hooks to approve.

**Usage limits on the home screen**
- Codex: remaining 5-hour and weekly limits, with reset times and pace marker (read from Codex's own logs).
- Claude: real limits when Claude Code runs in a terminal; otherwise an estimate based on your own token usage (clearly marked with `~`).

**Music**
- The album cover becomes a spinning vinyl disc; with an agent running, the disc sits on the left and the agent ring on the right.

**Lock screen and system**
- Lock and unlock animation with a short click sound, shown over the lock screen.
- Redesigned volume and brightness HUD with a living icon, glowing bar and rolling digits.

Everything new can be switched off in **Settings → Advanced / HUDs**.

## Build

Requires Xcode 15+ (developed with Xcode 26).

```bash
git clone https://github.com/Vasya2004/chelka-mac
cd chelka-mac
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual \
  ENABLE_DEBUG_DYLIB=NO ENABLE_HARDENED_RUNTIME=NO build
```

The app is not notarized. For permissions (Accessibility, Camera, Calendar) to survive rebuilds, sign with a stable local certificate instead of ad-hoc `-`, because macOS ties permissions to the code signature.

Auto-update is disabled: Chelka does not publish an update feed.

## Connect your agents

Agents report status to Chelka over a tiny local HTTP server (`127.0.0.1:48217`, loopback only). See [agent-hook/README.md](agent-hook/README.md) for hook setup for each tool.

## Privacy

- No analytics and no network access added by Chelka. The status server listens on loopback only.
- Codex limits are read from `~/.codex/sessions` (only the rate-limit and lifecycle fields).
- Claude token usage is computed by a local script from `~/.claude/projects` (only the `usage` and `timestamp` fields).
- Your Claude/Codex login tokens are never read.
- Any local process can send status events to the local port; they only change what Chelka displays.

## License and credits

GPL-3.0, see [LICENSE](LICENSE). Based on [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam and its contributors; third-party licenses in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES). The app icon and some assets are inherited from Boring Notch.

---

## По-русски

**Chelka** превращает «чёлку» MacBook в живую панель: статус ИИ-агентов (Claude Code, Codex, Cursor, Kimi), остаток лимитов Codex, музыка с вращающимся диском, анимация блокировки и красивая плашка громкости и яркости. Это форк [Boring Notch](https://github.com/TheBoredTeam/boring.notch) под лицензией GPL-3.0. Подробности и список изменений: [CHANGES.md](CHANGES.md). Подключение агентов: [agent-hook/README.md](agent-hook/README.md).
