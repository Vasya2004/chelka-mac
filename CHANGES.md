# Changes relative to Boring Notch

Chelka is a modified version of [Boring Notch](https://github.com/TheBoredTeam/boring.notch) v2.7.3 (GPL-3.0). This file lists the modifications, as required by GPL-3.0 §5(a). The full history is in git.

## Rebrand
- App renamed to **Chelka**, bundle ids `com.vasya2004.chelka` (app) and `com.vasya2004.chelka.XPCHelper` (helper).
- Sparkle auto-update disabled (feed URL and key removed, updater not started, update UI hidden).
- Upstream CI/release workflows and funding files removed from `.github`.
- Welcome screen credits the original project.
- Project, source folder and helper renamed (`Chelka.xcodeproj`, `Chelka/`, `ChelkaXPCHelper/`) via `git mv`, history kept.
- Upstream-only files removed: update feed (`updater/appcast.xml`), `CONTRIBUTING.md`, `crowdin.yml`, the upstream team logo asset; `SECURITY.md` rewritten for this repository. License and credits are kept.
- New app icon: a friendly face whose monobrow is the notch, with a vinyl record and an agent sparkle as eyes. Drawn from scratch.

## AI agents
- `AgentActivityManager`: local HTTP server (`127.0.0.1:48217`) with `/agent`, `/permission`, `/usage`; session state, completion banner, sounds.
- Closed-notch indicator (ring, equalizer), expanded banner, "Agents" tab, permission cards (Allow/Deny), jump-to-window.
- `CodexActivityWatcher`: detects Codex work from `~/.codex/sessions` logs.
- `agent-hook/`: hook scripts for Claude Code, Codex, Cursor, Kimi, a status-line script and a token-usage script.

## Usage limits
- `UsageManager` + `UsageStripView`: Codex 5h/weekly limits from logs, Claude limits/estimate, pace marker, colors by remaining percentage.

## Music and lock screen
- `SpinningAlbumDisc`: vinyl-style spinning cover in the closed notch, combined layout with the agent indicator.
- Lock/unlock animation and sound (`UnlockAnimationView`, `LockSoundPlayer`), shown over the lock screen.
- "Now Playing" media source is always selectable.

## HUD
- Redesigned inline volume/brightness HUD (`InlineHUD`), enabled by default.

## Animations
- Settings → Animations, each option with a live preview:
  - agent working indicator: Comet, Pulse, Orbit, Aurora, Radar, Galaxy, Heartbeat;
  - right-hand element when only an agent is active: Timer, Equalizer, Typing dots, Current tool, Wave, Rain, Typewriter, Shimmer;
  - album cover: Spinning disc, Square cover, Glowing cover, Beat, Radial bars, Rainbow disc;
  - completion effect: Check, Confetti, Starburst.

## Settings
- New toggles under Settings → Advanced: lock animation and sound, AI agent activity, completion banner and sound, permission prompts in the notch, usage limits on the home screen.
