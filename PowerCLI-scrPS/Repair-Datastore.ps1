Function Repair-Datastore {
  [CmdletBinding(DefaultParameterSetName="DS")]
  PARAM (
    [PARAMETER(Mandatory=$False,Position=0,HelpMessage = "WhatIf - if mentioned then do nothing, only print message",ParameterSetName='DS')][switch]$WhatIf,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Silent - Print only warnings or errors",ParameterSetName='DS')][switch]$Silent = $false,	
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "RescanUnmounted - Rescan HBA on hosts with unmounted datastores",ParameterSetName='DS')][switch]$RescanUnmounted = $false,	
    [PARAMETER(Mandatory=$False,Position=2,HelpMessage = "ESXi host username, default = root",ParameterSetName='DS')][String]$Username = 'root',
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "ESXi host password",ParameterSetName='DS')][String]$Password = $null,
    [PARAMETER(Mandatory=$True, Position=4,HelpMessage = "Datastore name",ParameterSetName='DS')][Parameter(ValueFromRemainingArguments=$true)][String[]]$Name = $null
  )

  $RescannedHostNames =@()
  
  if ($defaultVIServers.Count -gt 1) {
    Write-Host "ERROR (Repair-Datastore):  Multiple vCenter connection not supported. This Cmdlet connects and disconnects to multiple ESXi hosts directly. So connected vCenter list may vary unpredictably." -foreground "Red"
  }
  else {
    $Datastores = Get-Datastore -Name $Name | Sort Name
    if (-not $Datastores) {
      write-host "ERROR (Repair-Datastore): No datastore(s) found in current vCenter"  -foreground "Red"
    }
    else {
	  #$VMHosts = $Datastores | Get-VMHost | Sort Name
      $VMHosts = (Get-VIObjectByVIView -MORef $Datastores.ExtensionData.Host.key) | Sort Name 
      $HostNames = @()
      foreach ($VMhost in $VMhosts) {
        $HostNames += $VMhost.Name
      }
      $VMhostDatastores = @()
      $ProcessedHosts = 0
      foreach ($HostName in $HostNames) {
        $PercentCompletedHosts = [math]::Floor($ProcessedHosts / $HostNames.Count * 100)
        Write-Progress  -Activity "Processing host (datastore search)" -CurrentOperation $($HostName) -PercentComplete ($PercentCompletedHosts) -Id 1
        $ESXi = Connect-VIserver $HostName -Username $Username -Password $Password -errorAction silentlycontinue
        if (-not $ESXi) {
	      write-host "ERROR (Repair-Datastore): Can not connect to ESXi host $($HostName). Check host credentials and host name DNS A record resolution"  -foreground "Red"  
        }
        else {
          $VMHost = Get-VMhost -Server $ESXi -Name $HostName
	      $VMhostDatastore = $VMHost | Get-Datastore -Server $ESXi | where {$Datastores.Name.Contains($_.Name)}
	      $VMhostDatastore | Add-Member -NotePropertyName 'HostName' -NotePropertyValue "$($HostName)"
	      $VMhostDatastores += $VMhostDatastore
	      Disconnect-VIserver $ESXi -Confirm:$false -errorAction silentlycontinue
        }
        $ProcessedHosts += 1	
      }

	  if ($VMhostDatastores.Count -eq 0) {
	    write-host "ERROR (Repair-Datastore): No datastore(s) at all found in ESXi hosts (check host credentials and host name DNS A record resolution)"  -foreground "Red"
	  }
	  else {
	    #$VMhostDatastores | Select HostName,CapacityGB | Sort CapacityGB
		$HostNames = @()
		foreach ($Datastore in $Datastores) {
		  $CurrentVMhostDatastores =  $VMhostDatastores | where {$_.Name -eq $Datastore.Name}
		  if (-not $CurrentVMhostDatastores) {
		    write-host "WARNING (Repair-Datastore): No datastore $($Datastore.Name) found in ESXi hosts (check host credentials and host name DNS A record resolution)"  -foreground "Yellow"
		  } 
		  else {		   
			$MinimumCapacityGB = $CurrentVMhostDatastores.CapacityGB | Sort -Unique | Select -First 1
		    $MaximumCapacityGB = $CurrentVMhostDatastores.CapacityGB | Sort -Unique -Desc | Select -First 1
            if ($MinimumCapacityGB -eq $MaximumCapacityGB) {
				if ($RescanUnmounted -and  ($MinimumCapacityGB -eq 0)) {
				  # CapacityGB=0 is for unmounted datastores
				  if (-not $Silent) {
				    write-host "INFO (Repair-Datastore): Datastore $($Datastore.Name) is of zero size. Adding hosts seing this to rescan list."  -foreground "Green"
				  }				  
			      foreach ($Datastore in ($CurrentVMhostDatastores | where {$_.CapacityGB -eq 0})) {
	                $HostNames +=  $Datastore.HostName
                  }				  
				} 
				else {
				  if (-not $Silent) {
				    write-host "INFO (Repair-Datastore): Datastore $($Datastore.Name) if of the same size on all available ESXi hosts ($($MinimumCapacityGB) GB). Skipping host HBA rescan for this datastore"  -foreground "Green"
				  }
				}
		    }
			else {
			  foreach ($Datastore in ($CurrentVMhostDatastores | where {$_.CapacityGB -lt $MaximumCapacityGB})) {
	            $HostNames +=  $Datastore.HostName
              }
			}
		  }
		}
	  
	    if ($HostNames.Count -eq 0) {
		  if (-not $Silent) {
		    write-host "INFO (Repair-Datastore): ALL datastores are of the same size on all available ESXi hosts. Skipping host HBA rescan."  -foreground "Green"
		  }
		}
		else {
		  $HostNames = $HostNames | Sort -Unique
          
		  $ProcessedHosts = 0
          foreach ($HostName in $HostNames) {
            $PercentCompletedHosts = [math]::Floor($ProcessedHosts / $HostNames.Count * 100)
            Write-Progress  -Activity "Processing host (rescan HBA and VMFS)" -CurrentOperation $($HostName) -PercentComplete ($PercentCompletedHosts) -Id 1
            $ESXi = Connect-VIserver $HostName -Username $Username -Password $Password -errorAction silentlycontinue
            if (-not $ESXi) {
	          write-host "ERROR (Repair-Datastore): Can not connect to ESXi host $($HostName). Check host credentials and host name DNS A record resolution"  -foreground "Red"    
            }
            else {
			  if (-not $Silent) {
				write-host "INFO (Repair-Datastore): rescan HBA and VMFS on $($HostName)"  -foreground "Green"
			  }
              $VMHost = Get-VMhost -Server $ESXi -Name $HostName
              if ($WhatIf) {
				write-host "WhatIf (Repair-Datastore): rescan HBA and VMFS on $($HostName)"  -foreground "Yellow"
                $RescannedHostNames += $($VMHost.Name)				
			  }
			  else {
			    $VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
				$RescannedHostNames += $($VMHost.Name)
			  }
              Disconnect-VIserver $ESXi -Confirm:$false -errorAction silentlycontinue
            }
            $ProcessedHosts += 1	
          }
		}
		
	  }
	}
  }
  
  return $RescannedHostNames
}

