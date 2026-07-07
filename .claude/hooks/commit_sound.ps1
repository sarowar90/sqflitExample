# PostToolUse hook (Bash / git commit): play a success sound when a commit succeeds.
# Claude Code pipes the event data (tool_name, tool_input, tool_response, ...) as JSON on stdin.

$ErrorActionPreference = 'Stop'

# Read the hook payload from stdin
$raw = [Console]::In.ReadToEnd()

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0   # malformed payload: do nothing, don't block
}

$command = [string]$payload.tool_input.command
if ($command -notmatch 'git\s+commit') { exit 0 }

# Detect a failed commit from the tool response so we only chime on success.
$resp = $payload.tool_response
$respText = ''
if ($resp -is [string]) {
    $respText = $resp
} elseif ($null -ne $resp) {
    $respText = "$($resp.stdout) $($resp.stderr) $($resp.output)"
    if ($resp.isError -eq $true -or $resp.is_error -eq $true) { exit 0 }
}
if ($respText -match 'nothing to commit|no changes added|error:|fatal:') { exit 0 }

# Play the Windows success sound (PlaySync so it finishes before the process exits).
try {
    $wav = Join-Path $env:WINDIR 'Media\tada.wav'
    if (Test-Path $wav) {
        (New-Object System.Media.SoundPlayer $wav).PlaySync()
    } else {
        [System.Media.SystemSounds]::Asterisk.Play()
        Start-Sleep -Milliseconds 700
    }
} catch { }

exit 0
