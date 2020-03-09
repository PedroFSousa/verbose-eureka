#
# AUTHOR: INESC TEC <coral@lists.inesctec.pt>
# DESCRIPTION: Installs chocolatey, which is then used to install 
#              docker-for-windows, docker-compose and python.
#              Also installs Python module pyyaml using pip
#

# Install Chocolatey
Set-ExecutionPolicy AllSigned;
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Upgrade and check if Chocolatey is installed
choco upgrade chocolatey

# Install Docker
choco install docker-for-windows -y

# Install Docker Compose
choco install docker-compose -y

# Install Python
choco install python -y

# Install pyyaml
pip install pyyaml

# Enable Hyper-V Replica HTTP and HTTPS for outbound connections to node
Enable-NetFirewallRule -DisplayGroup "Hyper-V Replica HTTP"
Enable-NetFirewallRule -DisplayGroup "Hyper-V Replica HTTPS"

# Prompt User to Restart the Computer
$RestartComputer = Read-Host -Prompt "A reboot is required. Do you want to reboot now? (y/n)"

if($RestartComputer -eq "y")
{
    Restart-Computer
}
