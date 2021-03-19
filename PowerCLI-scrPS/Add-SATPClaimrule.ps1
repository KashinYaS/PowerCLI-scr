Function Add-SATPClaimrule {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "VMHost",ParameterSetName='Default')][PSObject]$VMHost,
	[PARAMETER(Mandatory=$True, Position=1,HelpMessage = "Device (3PAR,OceanStor,AERODISK)",ParameterSetName='Default')][string[]]$Device
  )
  $RetVal = @()
  
  $Device = $Device.ToUpper()
  
  $HostName = $VMHost.Name
  $esxcli = Get-EsxCli -VMHost $VMHost -V2 -ErrorAction "SilentlyContinue"
  if (-not $esxcli) {
	throw "Add-SATPClaimrule ($HostName): Can not get ESX CLI for host - skipping SATP claimrule creation"
  }
  else {
	# creating rules list
	$RulesToAdd = @()
	foreach ($CurrentDevice in $Device) {
	  switch ($CurrentDevice) {
	    "3PAR" {
		   $sAdd = $esxcli.storage.nmp.satp.rule.add.CreateArgs()
           $sAdd['vendor'] = '3PARdata'
           $sAdd['model'] = 'VV'
           $sAdd['satp'] = 'VMW_SATP_ALUA'
           $sAdd['psp'] = 'VMW_PSP_RR'
           $sAdd['claimoption'] = 'tpgs_on'
           $sAdd['description'] = 'HP 3PAR Custom ALUA Rule'
           $sAdd['pspoption'] = 'iops=1'
		   $RulesToAdd += $sAdd
	    }
	    "OCEANSTOR" {
		   $sAdd = $esxcli.storage.nmp.satp.rule.add.CreateArgs()
           $sAdd['vendor'] = 'HUAWEI'
           $sAdd['model'] = 'XSG1'
           $sAdd['satp'] = 'VMW_SATP_ALUA'
           $sAdd['psp'] = 'VMW_PSP_RR'
           $sAdd['claimoption'] = 'tpgs_on'
           $sAdd['description'] = 'HUAWEI OceanStor ALUA Rule'			
		   $RulesToAdd += $sAdd
	    }
	    "AERODISK" {
           $sAdd = $esxcli.storage.nmp.satp.rule.add.CreateArgs()
           $sAdd['vendor'] = 'AERODISK'
           $sAdd['model'] = '^DDP*'
           $sAdd['satp'] = 'VMW_SATP_ALUA'
           $sAdd['psp'] = 'VMW_PSP_RR'
           $sAdd['claimoption'] = 'tpgs_on'
           $sAdd['description'] = 'AERODISK ALUA Rule for Dynamic RAID'
		   $RulesToAdd += $sAdd
           $sAdd = $esxcli.storage.nmp.satp.rule.add.CreateArgs()
           $sAdd['vendor'] = 'AERODISK'
           $sAdd['model'] = '^R*'
           $sAdd['satp'] = 'VMW_SATP_ALUA'
           $sAdd['psp'] = 'VMW_PSP_RR'
           $sAdd['claimoption'] = 'tpgs_on'
           $sAdd['description'] = 'AERODISK ALUA Rule for Common RAID'
		   $RulesToAdd += $sAdd		   
	    }
		default {
		  write-host "Add-SATPClaimrule ($HostName): Specify 3PAR, OceanStor or AERODISK as Device parameter" -Foreground "White"
		}
	  } # switch
	} # setting up $RulesToAdd array
	foreach ($RuleToAdd in $RulesToAdd) {
        $addResult = $null
		try {
		  $addResult = $esxcli.storage.nmp.satp.rule.add.Invoke($RuleToAdd)
          if ($addResult) {
            write-host "Add-SATPClaimrule ($HostName): Succesfully added SATP claimrule $($RuleToAdd['description'])." -foreground "Green"			
          }
          else {
            write-host "Add-SATPClaimrule ($HostName): Can not add SATP claimrule $($RuleToAdd['description']). Why there is no exception thrown!?" -foreground "Yellow"
          }
		}  
        catch {
          if ($addResult) {
            write-host "Add-SATPClaimrule ($HostName): Could not add Duplicate claimrule $($RuleToAdd['description'])" -foreground "Yellow"
          }
          else {
            write-host "Add-SATPClaimrule ($HostName): Can not add SATP claimrule $($RuleToAdd['description']). Maybe it exists already?" -foreground "Yellow"
          }		  
        }
		$RetVal += $addResult	
	} 
  }	
  Return($RetVal)
}



<#
  Add-SATPClaimrule -VMHost $VMHost -Device "Aerodisk"
  $esxcli = Get-EsxCli -VMHost $VMHost -V2
  $esxcli.storage.nmp.satp.rule.list.Invoke() | where {$_.Vendor -like "AERO*"}
#>


