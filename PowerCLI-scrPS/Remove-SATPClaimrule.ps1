Function Remove-SATPClaimrule {
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
	throw "Remove-SATPClaimrule ($HostName): Can not get ESX CLI for host - skipping SATP claimrule delete"
  }
  else {
	# creating rules list
	$RulesToDelete = @()
	foreach ($CurrentDevice in $Device) {
	  switch ($CurrentDevice) {
	    "3PAR" {
		   $sDel = $esxcli.storage.nmp.satp.rule.remove.CreateArgs()
           $sDel['vendor'] = '3PARdata'
           $sDel['model'] = 'VV'
           $sDel['satp'] = 'VMW_SATP_ALUA'
           $sDel['psp'] = 'VMW_PSP_RR'
           $sDel['claimoption'] = 'tpgs_on'
           $sDel['description'] = 'HP 3PAR Custom ALUA Rule'
           $sDel['pspoption'] = 'iops=1'
		   $RulesToDelete += $sDel
	    }
	    "OCEANSTOR" {
		   $sDel = $esxcli.storage.nmp.satp.rule.remove.CreateArgs()
           $sDel['vendor'] = 'HUAWEI'
           $sDel['model'] = 'XSG1'
           $sDel['satp'] = 'VMW_SATP_ALUA'
           $sDel['psp'] = 'VMW_PSP_RR'
           $sDel['claimoption'] = 'tpgs_on'
           $sDel['description'] = 'HUAWEI OceanStor ALUA Rule'			
		   $RulesToDelete += $sDel
	    }
	    "AERODISK" {
           $sDel = $esxcli.storage.nmp.satp.rule.remove.CreateArgs()
             $sDel['vendor'] = 'AERODISK'
             $sDel['model'] = '^DDP*'
             $sDel['satp'] = 'VMW_SATP_ALUA'
             $sDel['psp'] = 'VMW_PSP_RR'
             $sDel['claimoption'] = 'tpgs_on'
             $sDel['description'] = 'AERODISK ALUA Rule for Dynamic RAID'
		   $RulesToDelete += $sDel
           $sDel = $esxcli.storage.nmp.satp.rule.remove.CreateArgs()
             $sDel['vendor'] = 'AERODISK'
             $sDel['model'] = '^R*'
             $sDel['satp'] = 'VMW_SATP_ALUA'
             $sDel['psp'] = 'VMW_PSP_RR'
             $sDel['claimoption'] = 'tpgs_on'
             $sDel['description'] = 'AERODISK ALUA Rule for Common RAID'
		   $RulesToDelete += $sDel
		   # and third AERODISK rule that does not work due to * in model
           $sDel = $esxcli.storage.nmp.satp.rule.remove.CreateArgs()
             $sDel['vendor'] = 'AERODISK'
             $sDel['model'] = '*'
             $sDel['satp'] = 'VMW_SATP_ALUA'
             $sDel['psp'] = 'VMW_PSP_RR'
             $sDel['claimoption'] = 'tpgs_on'		   
             $sDel['description'] = 'Bad AERODISK ALUA Rule'
		   $RulesToDelete += $sDel		   
	    }
		default {
		  write-host "Remove-SATPClaimrule ($HostName): Specify 3PAR, OceanStor or AERODISK as Device parameter" -Foreground "White"
		}
	  } # switch
	} # setting up $RulesToDelete array
	foreach ($RuleToDelete in $RulesToDelete) {
        $delResult = $null
		#write-host "Remove-SATPClaimrule ($HostName): Trying to delete SATP claimrule $($RuleToDelete['description'])." -Foreground "White"
		try {
		  $delResult = $esxcli.storage.nmp.satp.rule.remove.Invoke($RuleToDelete)
          if ($delResult) {
            write-host "Remove-SATPClaimrule ($HostName): Succesfully deleted SATP claimrule $($RuleToDelete['description'])." -foreground "Green"			
          }
          else {
            write-host "Remove-SATPClaimrule ($HostName): Can not delete SATP claimrule $($RuleToDelete['description']). Why there is no exception thrown!?" -foreground "Yellow"
          }
		}  
        catch {
          if ($delResult) {
            write-host "Remove-SATPClaimrule ($HostName): Could not delete claimrule $($RuleToDelete['description'])" -foreground "Yellow"
          }
          else {
            write-host "Remove-SATPClaimrule ($HostName): Can not delete SATP claimrule $($RuleToDelete['description']). Maybe it does not exist?" -foreground "Yellow"
          }		  
        }
		$RetVal += $delResult	
	} 
  }	
  Return($RetVal)
}




<#
  Remove-SATPClaimrule -VMHost $VMHost -Device "Aerodisk"
  $esxcli = Get-EsxCli -VMHost $VMHost -V2
  $esxcli.storage.nmp.satp.rule.list.Invoke() | where {$_.Vendor -like "AERO*"}
#>


