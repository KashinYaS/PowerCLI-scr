Function Get-SATPClaimrule {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "VMHost",ParameterSetName='Default')][PSObject]$VMHost
  )
  $RetVal = $null
  
  $HostName = $VMHost.Name
  $esxcli = Get-EsxCli -VMHost $VMHost -V2 -ErrorAction "SilentlyContinue"
  if (-not $esxcli) {
	throw "Get-SATPClaimrule ($HostName): Can not get ESX CLI for host - skipping SATP claimrule list"
  }
  else {
	try {
	  $RetVal = $esxcli.storage.nmp.satp.rule.list.Invoke()
      if (-not $RetVal) {
        write-host "Get-SATPClaimrule ($HostName): Can not add SATP claimrule $($RuleToAdd['description']). Why there is no exception thrown!?" -foreground "Yellow"
      }
    }  
    catch {
      write-host "Get-SATPClaimrule ($HostName): Can not add SATP claimrule $($RuleToAdd['description']). Maybe it exists already?" -foreground "Yellow"
    }		  
  }
  Return($RetVal)
}



<#
  Get-SATPClaimrule -VMHost $VMHost 
#>


