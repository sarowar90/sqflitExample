# UserPromptSubmit hook: dump the hook's stdin JSON payload to a txt file.
# Claude Code pipes the event data (session_id, cwd, prompt, etc.) as JSON on stdin.

$ErrorActionPreference = 'Stop'

# Read everything from stdin
$raw = [Console]::In.ReadToEnd()

# Resolve output path (project dir passed via env, else fall back to script location)
$logDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Split-Path -Parent $PSScriptRoot }
$logFile = Join-Path $logDir 'user_prompts.txt'

$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

Add-Content -Path $logFile -Value "===== $timestamp =====" -Encoding utf8
Add-Content -Path $logFile -Value $raw -Encoding utf8
Add-Content -Path $logFile -Value "" -Encoding utf8

# Exit 0 so the prompt is allowed through unchanged
exit 0
