Function Expand-Datastore {
  [CmdletBinding(DefaultParameterSetName="DS")]
  PARAM (
    [PARAMETER(Mandatory=$False,Position=0,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='DS')][switch]$WhatIf,
    [PARAMETER(Mandatory=$True, Position=1,HelpMessage = "Datastore name",ParameterSetName='DS')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )
  
  if ($defaultVIServers.Count -gt 1) {
    Write-Host "ERROR (Expand-Datastore):  Multiple vCenter connection not supported due to possible MoRef/Key/Id mismatch" -foreground "Red"
  }
  else {

    $Datastores = Get-Datastore -Name $Name
    if (-not $Datastores) {
      write-host "ERROR (Expand-Datastore): No datastore(s) found in current vCenter"  -foreground "Red"
    }
    else {
      foreach ($Datastore in $Datastores) {
	    Write-Host "Processing Datastore: $Datastore" -foreground "Green"
	    $OldDatastoreSizeGB = $Datastore.CapacityGB
        #$VMHostKey = $Datastore.ExtensionData.Host | Select-Object -last 1 | Select -ExpandProperty Key
        #$VMHost = Get-VMHost -Id $VMHostKey
		$VMHost = $Datastore | Get-VMHost | Sort-Object -property @{Expression={$_.CpuUsageMhz/$_.CpuTotalMhz}} | Select -First 1
		$VMHostKey = $VMHost.Id
        if ($VMHost) {
          Write-Progress -Activity "Increasing Datastore $Datastore Size" -CurrentOperation "Rescan Host's HBAs (wait few minutes...)" -PercentComplete 0
          Write-Host "  Current Host: $VMHost" -foreground "Green"
          Write-Host "  Current Host: $VMHost - Storage refresh started" -foreground "Green"
		  $VMHost | Get-VMHostStorage -RescanAllHba
          Start-Sleep -s 3
          Write-Progress -Activity "Increasing Datastore $Datastore Size" -CurrentOperation "Refreshing host storage information" -PercentComplete 30
          Get-VmHostStorage -VMHost $VMHost -Refresh
          Write-Progress -Activity "Increasing Datastore $Datastore Size" -CurrentOperation "Getting Free Space on LUN with existing extent" -PercentComplete 50
          Write-Host "  Current Host: $VMHost - Storage refresh completed" -foreground "Green"
          Write-Host "  Current Host: $VMHost - Getting ESXi view" -foreground "Green"
		  $ESXiView = Get-View -Id $VMHostKey  
          Write-Host "  Current Host: $VMHost - Getting ESXi Datastore System" -foreground "Green"
          $DatastoreSystemView = Get-View -Id $ESXiView.ConfigManager.DatastoreSystem
		  Write-Host "  Current Host: $VMHost - Getting ESXi Datastore Expand options" -foreground "Green"
          $ExpandOptions = $DatastoreSystemView.QueryVmfsDatastoreExpandOptions($Datastore.ExtensionData.MoRef)
		  $DiskName = $ExpandOptions.Spec.Extent.DiskName
		  Write-Host "  All preparation done" -foreground "Green" 
          if (-not $ExpandOptions) {
            Write-Host "ERROR (Expand-Datastore): No available space found. If You wish to make a new extent on another LUN please make it manually" -foreground "red"
          }
          else {
            Write-Progress -Activity "Increasing Datastore $Datastore Size" -CurrentOperation "Processing Datastore Expand" -PercentComplete 70
            if ($WhatIf) {
              Write-Host "WhatIf (Expand-Datastore): Processing Datastore Expand on disk/LUN: $($DiskName)" -foreground "Green"        
            }
            else {		  
              $Expanded = $DatastoreSystemView.ExpandVmfsDatastore($Datastore.ExtensionData.MoRef,$ExpandOptions.spec)
			  Start-Sleep -s 3
			  Get-VmHostStorage -VMHost $VMHost -Refresh
			  $NewDatastoreSizeGB = ($VMHost | Get-Datastore -Name $Name).CapacityGB
			  $DatastoreSizeDelta = $NewDatastoreSizeGB - $OldDatastoreSizeGB
			  if ($DatastoreSizeDelta -le 0) {
			    Write-Host "ERROR (Expand-Datastore): Could not expand $Datastore" -foreground "red"
			  }
			  else
			  {
			    Write-Host "  $Datastore expanded, $($DatastoreSizeDelta) GB added. New size: $($NewDatastoreSizeGB) GB" -foreground "green"
			  }			  
            }
          }
        }
        else {
          Write-Host "No available ESXi host found. How this exception is possible at all???!!!" -foreground "Yellow"
        }        
      }
    }
  }
}


