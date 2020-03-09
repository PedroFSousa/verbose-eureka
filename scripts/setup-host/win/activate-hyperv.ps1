
#
# AUTHOR: INESC TEC <coral@lists.inesctec.pt>
# DESCRIPTION: Enables Hyper-V
#

# Get Hyper-V current state
$hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online

# Check if it's activated. If not, the script will activate it
if ($hyperv.state -eq "Enabled") {
    Write-Host "Hyper-V is already activated. No need to restart the computer."
} else {
    Write-Host "Hyper-V is deactivated. Activating it..."

    # Enable Hyper-V
    Enable-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V -All
}