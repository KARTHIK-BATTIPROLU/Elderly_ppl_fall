# PowerShell script to add Windows Firewall rule for FastAPI backend
# Run this as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Adding Windows Firewall Rule" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click this file and select 'Run with PowerShell as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Running as Administrator... Good!" -ForegroundColor Green
Write-Host ""

# Check if rule already exists
$existingRule = Get-NetFirewallRule -DisplayName "FastAPI Backend - Fall Prevention" -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "Firewall rule already exists. Removing old rule..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "FastAPI Backend - Fall Prevention"
}

# Add the firewall rule
Write-Host "Adding firewall rule for port 8002..." -ForegroundColor Cyan

try {
    New-NetFirewallRule `
        -DisplayName "FastAPI Backend - Fall Prevention" `
        -Direction Inbound `
        -LocalPort 8002 `
        -Protocol TCP `
        -Action Allow `
        -Profile Any `
        -Description "Allows mobile app to connect to FastAPI backend on port 8002"
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! Firewall rule added." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your mobile phone can now connect to:" -ForegroundColor Cyan
    Write-Host "http://192.168.0.10:8002" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Restart the app on your phone" -ForegroundColor White
    Write-Host "2. Or pull down and tap 'Refresh'" -ForegroundColor White
    Write-Host ""
    
    # Verify the rule was created
    Write-Host "Verifying firewall rule..." -ForegroundColor Cyan
    $rule = Get-NetFirewallRule -DisplayName "FastAPI Backend - Fall Prevention"
    if ($rule) {
        Write-Host "✓ Rule verified: $($rule.DisplayName)" -ForegroundColor Green
        Write-Host "✓ Status: $($rule.Enabled)" -ForegroundColor Green
    }
    
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to add firewall rule" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to exit"
