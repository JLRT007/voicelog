# VoiceLog

VoiceLog is an Android-first Flutter MVP for voice-based work logging.

## Local Environment

Run all Flutter commands through the project environment script so Flutter,
Pub, Gradle, npm, and API configuration stay scoped to this folder.

```powershell
. .\scripts\env.ps1
Invoke-VoiceLogFlutter doctor
Invoke-VoiceLogFlutter run
```

The local DeepSeek key lives in `.env.local`, which is ignored by Git. The app
uses `deepseek-v4-flash` for smart splitting when `DEEPSEEK_API_KEY` is present;
otherwise it falls back to a local heuristic splitter.

## UI Skill

The UI/UX Pro Max skill is installed under `.codex/skills/ui-ux-pro-max` by the
project-local `uipro-cli`. Restart Codex from this project to have it show up as
an active skill automatically.
