Function Delete-SATPClaimrule {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "VMHost",ParameterSetName='Default')][PSObject]$VMHost,
	[PARAMETER(Mandatory=$True, Position=1,HelpMessage = "Device (3PAR,OceanStor,AERODISK)",ParameterSetName='Default')][string[]]$Device
  )
  $RetVal = Remove-SATPClaimrule -VMHost $VMHost -Device $Device
  Return($RetVal)
}



<#
  Delete-SATPClaimrule -VMHost $VMHost -Device "Aerodisk"
  $esxcli = Get-EsxCli -VMHost $VMHost -V2
  $esxcli.storage.nmp.satp.rule.list.Invoke() | where {$_.Vendor -like "AERO*"}
#>


