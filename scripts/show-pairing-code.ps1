param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$LaptopId = "laptop-local-001",
    [int]$RefreshSeconds = 20
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$BaseUrl = $BaseUrl.TrimEnd('/')
if ($RefreshSeconds -lt 5) {
    $RefreshSeconds = 5
}

$script:CurrentCode = "----"
$script:ExpiresAt = $null
$script:LastError = $null
$script:LastAutoStartAttemptUtc = [DateTimeOffset]::MinValue

function Try-StartInstalledTasks {
    $now = [DateTimeOffset]::UtcNow
    if (($now - $script:LastAutoStartAttemptUtc).TotalSeconds -lt 30) {
        return
    }

    $script:LastAutoStartAttemptUtc = $now

    try {
        $startScript = Join-Path $PSScriptRoot 'start-runtime-background.ps1'
        if (Test-Path $startScript) {
            & $startScript -Silent | Out-Null
            return
        }

        $commandTask = Get-ScheduledTask -TaskName "LockMyLaptop.CommandService.Startup" -ErrorAction SilentlyContinue
        $agentTask = Get-ScheduledTask -TaskName "LockMyLaptop.LaptopAgent.Startup" -ErrorAction SilentlyContinue

        if ($null -ne $commandTask) {
            Start-ScheduledTask -TaskName "LockMyLaptop.CommandService.Startup" -ErrorAction SilentlyContinue
        }

        if ($null -ne $agentTask) {
            Start-ScheduledTask -TaskName "LockMyLaptop.LaptopAgent.Startup" -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Ignore task-start failures and keep a clear user-facing status message.
    }
}

function Update-UiState {
    param(
        [System.Windows.Forms.Label]$CodeLabel,
        [System.Windows.Forms.Label]$ExpiryLabel,
        [System.Windows.Forms.Label]$StatusLabel
    )

    $CodeLabel.Text = $script:CurrentCode

    if ($script:ExpiresAt -is [DateTimeOffset]) {
        $remaining = [int][Math]::Ceiling(($script:ExpiresAt - [DateTimeOffset]::UtcNow).TotalSeconds)
        if ($remaining -lt 0) {
            $remaining = 0
        }

        $ExpiryLabel.Text = "Expires in ${remaining}s"
    }
    else {
        $ExpiryLabel.Text = "Waiting for first code..."
    }

    if ([string]::IsNullOrWhiteSpace($script:LastError)) {
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(141, 255, 106)
        $StatusLabel.Text = "Connected to $BaseUrl"
    }
    else {
        $StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 120, 120)
        $StatusLabel.Text = $script:LastError
    }
}

function Request-PairingCode {
    try {
        $payload = @{ laptopId = $LaptopId } | ConvertTo-Json
        $result = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/pair/start-code" -ContentType "application/json" -Body $payload -TimeoutSec 10

        if ($null -eq $result -or [string]::IsNullOrWhiteSpace($result.pairingCode)) {
            throw "Invalid response from command service."
        }

        $script:CurrentCode = [string]$result.pairingCode
        $script:ExpiresAt = [DateTimeOffset]::Parse([string]$result.expiresAt)
        $script:LastError = $null
    }
    catch {
        Try-StartInstalledTasks
        $script:CurrentCode = "----"
        $script:ExpiresAt = $null
        $script:LastError = "Unable to get code. Starting runtime tasks and retrying..."
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "LockMyLaptop Pairing Code"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Size = New-Object System.Drawing.Size(430, 320)
$form.BackColor = [System.Drawing.Color]::FromArgb(5, 8, 5)
$form.ForeColor = [System.Drawing.Color]::FromArgb(232, 252, 229)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.TopMost = $true

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Current Pairing Code"
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(141, 255, 106)
$titleLabel.Location = New-Object System.Drawing.Point(115, 25)
$form.Controls.Add($titleLabel)

$codeLabel = New-Object System.Windows.Forms.Label
$codeLabel.Text = "----"
$codeLabel.AutoSize = $false
$codeLabel.Size = New-Object System.Drawing.Size(360, 90)
$codeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$codeLabel.Font = New-Object System.Drawing.Font("Consolas", 44, [System.Drawing.FontStyle]::Bold)
$codeLabel.ForeColor = [System.Drawing.Color]::FromArgb(52, 203, 96)
$codeLabel.Location = New-Object System.Drawing.Point(25, 65)
$form.Controls.Add($codeLabel)

$expiryLabel = New-Object System.Windows.Forms.Label
$expiryLabel.Text = "Waiting for first code..."
$expiryLabel.AutoSize = $false
$expiryLabel.Size = New-Object System.Drawing.Size(360, 24)
$expiryLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$expiryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$expiryLabel.Location = New-Object System.Drawing.Point(25, 160)
$form.Controls.Add($expiryLabel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.AutoSize = $false
$statusLabel.Size = New-Object System.Drawing.Size(380, 24)
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$statusLabel.Location = New-Object System.Drawing.Point(15, 188)
$form.Controls.Add($statusLabel)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh Now"
$refreshButton.Size = New-Object System.Drawing.Size(120, 34)
$refreshButton.Location = New-Object System.Drawing.Point(90, 225)
$refreshButton.BackColor = [System.Drawing.Color]::FromArgb(10, 16, 10)
$refreshButton.ForeColor = [System.Drawing.Color]::FromArgb(141, 255, 106)
$form.Controls.Add($refreshButton)

$copyButton = New-Object System.Windows.Forms.Button
$copyButton.Text = "Copy Code"
$copyButton.Size = New-Object System.Drawing.Size(120, 34)
$copyButton.Location = New-Object System.Drawing.Point(220, 225)
$copyButton.BackColor = [System.Drawing.Color]::FromArgb(10, 16, 10)
$copyButton.ForeColor = [System.Drawing.Color]::FromArgb(141, 255, 106)
$form.Controls.Add($copyButton)

$refreshButton.Add_Click({
    Request-PairingCode
    Update-UiState -CodeLabel $codeLabel -ExpiryLabel $expiryLabel -StatusLabel $statusLabel
})

$copyButton.Add_Click({
    if ($script:CurrentCode -match '^\d{4}$') {
        [System.Windows.Forms.Clipboard]::SetText($script:CurrentCode)
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(141, 255, 106)
        $statusLabel.Text = "Code copied to clipboard"
    }
})

$refreshTimer = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = $RefreshSeconds * 1000
$refreshTimer.Add_Tick({
    Request-PairingCode
    Update-UiState -CodeLabel $codeLabel -ExpiryLabel $expiryLabel -StatusLabel $statusLabel
})

$countdownTimer = New-Object System.Windows.Forms.Timer
$countdownTimer.Interval = 1000
$countdownTimer.Add_Tick({
    Update-UiState -CodeLabel $codeLabel -ExpiryLabel $expiryLabel -StatusLabel $statusLabel
})

$form.Add_Shown({
    Request-PairingCode
    Update-UiState -CodeLabel $codeLabel -ExpiryLabel $expiryLabel -StatusLabel $statusLabel
    $refreshTimer.Start()
    $countdownTimer.Start()
})

$form.Add_FormClosed({
    $refreshTimer.Stop()
    $countdownTimer.Stop()
})

[void]$form.ShowDialog()