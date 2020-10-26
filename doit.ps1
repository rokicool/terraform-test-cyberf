#requires -version 2
<#
.SYNOPSIS
  Checks, switches on and off resources in Azure 
.DESCRIPTION
  You must pay for any resources you use in Azure. But some resources are the most expensive. 
  Such as running VMs or existing WebApps or AppServicePlans. 

  This script is made to switch off running VMs and to remove WebApps from Azure. 

  Since all of the resources are deployed by Terraform it is mostly safe to remove them. The only
  problem is that sometimes (in case of MS SQL VMs) it is nesessary to these VMs to be running
  when you redeploy your infrastructure by Terraform.

  The script can start these machies to allow Terraform to work

.PARAMETER Do
    What to do? "On" or "Off"
.INPUTS
  None
.OUTPUTS
  Names and state of the "touched" services
.NOTES
  Version:        1.1
  Author:         Roki
  Creation Date:  2020.10
  Purpose/Change: Initial script development
  
.EXAMPLE
  doit -what on - to switch on the resources in Azure

.EXAMPLE
  doit -what off - to switch off the resources in Azure

#>

#---------------------------------------------------------[Params]--------------------------------------------------------

Param(
    [Parameter(Mandatory=$true, ParameterSetName="What")]
    [String]
    $WhatToDo
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "Continue"

#Dot Source required Function Libraries
#. "C:\Scripts\Functions\Logging_Functions.ps1"

Import-Module PSLogging

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.1"



#Log File Info
$sLogPath = ".\"    #$env:TEMP
$sLogName = "doit.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

<#
Function <FunctionName>{
  Param()
  
  Begin{
    Write-LogInfo -LogPath $sLogFile -Message "<description of what is going on>..."
  }
  
  Process{
    Try{
      <code goes here>
    }
    
    Catch{
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Write-LogInfo -LogPath $sLogFile -Message "Completed Successfully."
      Write-LogInfo -LogPath $sLogFile -Message " "
    }
  }
}
#>


Function do_show{
  Param($object_list)
  
  Begin{
    Write-LogInfo -LogPath $sLogFile -Message "Showing the state of the objects..."
  }
  
  Process{
    Try{
     foreach ($object in $object_list) {
       if ($object.o_type -eq "vm") {
        $tmp = Get-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name -Status
         
        $vmid = (Get-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name).id
        $ipcf = (get-aznetworkinterface | where {$_.virtualmachine.id -eq $vmid}).IpConfigurations[0]
        $privateIP = $ipcf.PrivateIpAddress

        $publicIP = (Get-AzPublicIpAddress | where {$_.id -eq (get-aznetworkinterface | where {$_.virtualmachine.id -eq $vmid}).IpConfigurations[0].PublicIpAddress.id}).IpAddress

        Write-Host "RG:" $object.o_storagegroup " VM:" $object.o_name " is " $tmp.Statuses[1].DisplayStatus " ip: " $publicIp "(" $privateIP ")"
       }

       if ($object.o_type -eq "webapp") {
        $tmp = Get-AzWebApp -ResourceGroupName $object.o_storagegroup -Name $object.o_name 
        Write-Host "RG:" $object.o_storagegroup " WebApp:" $object.o_name " is " $tmp.State
       }

       if ($object.o_type -eq "appplan") {
        $tmp = Get-AzAppServicePlan -ResourceGroupName $object.o_storagegroup -Name $object.o_name 
        Write-Host "RG:" $object.o_storagegroup " AppPlan:" $object.o_name " is " $tmp.Status
       }

     }
    }
    
    Catch{
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Write-LogInfo -LogPath $sLogFile -Message "Completed Successfully."
      Write-LogInfo -LogPath $sLogFile -Message " "
    }
  }
}

Function do_switch_on{
  Param($object_list)
  
  Begin{
    Write-LogInfo -LogPath $sLogFile -Message "Switching on the objects..."
  }
  
  Process{
    Try{

      if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {Connect-AzAccount}

      foreach ($object in $object_list) {
        if ($object.o_type -eq "vm") {
          # Write-LogInfo -LogPath $sLogFile -Message "Switching on " + $object.o_name
          Write-Host "Starting VM:" $object.o_name " RG:" $object.o_storagegroup
          Start-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name 
          $tmp = Get-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name -Status
          Write-Host "RG:" $object.o_storagegroup " VM:" $object.o_name " is " $tmp.Statuses[1].DisplayStatus
        }
      } 
    }
    
    Catch{
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Write-LogInfo -LogPath $sLogFile -Message "Switching on сompleted Successfully."
      Write-LogInfo -LogPath $sLogFile -Message " "
    }
  }
}

Function do_switch_off{
  Param($object_list)
  
  Begin{
    Write-LogInfo -LogPath $sLogFile -Message "Switching off the objects..."
  }
  
  Process{
    Try{

      if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) {Connect-AzAccount}

      foreach ($object in $object_list) {
        if ($object.o_type -eq "vm") {
          #Write-LogInfo -LogPath $sLogFile -Message "Switching off " $object.o_name
          Write-Host "Stopping VM:" $object.o_name " RG:" $object.o_storagegroup 
          Stop-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name -Force
          $tmp = Get-AzVM -ResourceGroupName $object.o_storagegroup -Name $object.o_name -Status
          Write-Host "RG:" $object.o_storagegroup " VM:" $object.o_name " is " $tmp.Statuses[1].DisplayStatus
        }
      } 
    }
    
    Catch{
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Write-LogInfo -LogPath $sLogFile -Message "Switching off сompleted Successfully."
      Write-LogInfo -LogPath $sLogFile -Message " "
    }
  }
}

#-----------------------------------------------------------[do_clear]------------------------------------------------------------

Function do_clear{
  Param($object_list)
  
  Begin{
    Write-LogInfo -LogPath $sLogFile -Message "Removing Apps and Plans"
  }
  
  Process{
    Try{
     foreach ($object in $object_list) {
    

       if ($object.o_type -eq "webapp") {
        Remove-AzWebApp -ResourceGroupName $object.o_storagegroup -Name $object.o_name -force
        Write-Host "Removing WebApp:" $object.o_name " RG: " $object.o_storagegroup
       }

       if ($object.o_type -eq "appplan") {
        Remove-AzAppServicePlan -ResourceGroupName $object.o_storagegroup -Name $object.o_name -force
        Write-Host "Removing  AppPlan:" $object.o_name " RG:" $object.o_storagegroup 
       }

     }
    }
    
    Catch{
      Write-LogError -LogPath $sLogFile -Message $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Write-LogInfo -LogPath $sLogFile -Message "Completed Successfully."
      Write-LogInfo -LogPath $sLogFile -Message " "
    }
  }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
#Script Execution goes here
$list = @(
  [pscustomobject]@{o_type='vm';o_storagegroup='rgp-eastus2-cyberf-test02';o_name="vm-win-web-left-cyberf-test02"}
  [pscustomobject]@{o_type='vm';o_storagegroup='rgp-eastus2-cyberf-test02';o_name="win-addc-left-vm-cyberf-test02"}
  [pscustomobject]@{o_type='vm';o_storagegroup='rgp-eastus2-cyberf-test02';o_name="win-sql-left-vm-cyberf-test02"}
)

switch ($WhatToDo)
{
  "Show" {
    do_show $list ;  
    Break
  }
  "On" {
    do_switch_on $list;
    do_show $list;
    Break
  }
  "Off" {
    do_switch_off $list;
    do_show $list;
    Break
  }
  "Clear" {
    do_clear $list;
    do_switch_off $list;
    do_show $list;
    Break
  }
  default { 
    Write-Host "The script expects you to provide a parameter: 'Show', 'On', 'Off', 'Clear'"
   }
}



Stop-Log -LogPath $sLogFile