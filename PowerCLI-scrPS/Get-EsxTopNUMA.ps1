
# Slightly modified version from https://github.com/TheGabeMan/NUMAlocality-esxtop by Gabrie van Zanten


Function Get-EsxTopNUMA {
        param(
            [Parameter(ValueFromPipeline=$true)]
			[PSCustomObject[]]$VMHost
        )
	
	$AllHostsDataSet = @()
	
	foreach ($CurrentVMhost in $VMhost) {
	  $vCenterForServiceManager = $global:DefaultVIServer | where {$_.Name -eq $CurrentVMhost.Uid.Split(":")[0].Split("@")[1]}
      $serviceManager = Get-View ($vCenterForServiceManager.ExtensionData.Content.serviceManager) -property "" -ErrorAction SilentlyContinue
      $locationString = "vmware.host." + $CurrentVMhost.Name
      $services = $serviceManager.QueryServiceList($null,$locationString)

      ## Filter the services on esxtop. Another option would be vscsistat
      $services = $services | Where-Object { $_.ServiceName -eq "Esxtop" } 
      $serviceView = Get-View $services.Service -Property "entity"
    
      ## Read the counters esxtop can provider
      $esxtopCounters = $serviceView.ExecuteSimpleCommand("CounterInfo")

      ## Read the stats from esxtop
      $esxtopStats = $serviceView.ExecuteSimpleCommand("FetchStats")

      ## After collecting stats, you will need to run the "freestats" operation and this will release any server side resources used during the collection.
	  # This command adds weird blank lines to function output if called without Out-Null redirect!
      $serviceView.ExecuteSimpleCommand("freestats") | Out-Null

      ## Counter info comes in as one long string with linefeeds, like this:
      ## |PCPU|NumOfLCPUs,U32|NumOfCores,U32|NumOfPackages,U32|
      ## |LCPU|LCPUID,U32|CPUHz,U64|UsedTimeInUsec,U64|HaltTimeInUsec,U64|CoreHaltTimeInUsec,U64|ElapsedTimeInUsec,U64|BusyWaitTimeInUsec,U64|
      ## |PMem|PhysicalMemInKB,U32|COSMemInKB,U32|KernelManagedInKB,U32|NonkernelUsedInKB,U32|FreeMemInKB,U32|PShareSharedInKB,U32|PShareCommonInKB,U32|SchedManagedInKB,U32|SchedMinFreeInKB,U32|SchedReservedInKB,U32|SchedAvailInKB,U32|SchedState,U32|SchedStateStr,CSTR|MemCtlMaxInKB,U32|MemCtlCurInKB,U32|MemCtlTgtInKB,U32|SwapUsedInKB,U32|SwapTgtInKB,U32|SwapReadInKB,U32|SwapWrtnInKB,U32|ZippedInKB,U32|ZipSavedInKB,U32|MemOvercommitInPct1Min,U32|MemOvercommitInPct5Min,U32|MemOvercommitInPct15Min,U32|NumOfNUMANodes,U32|
      ## |NUMANode|NodeID,U32|TotalInPages,U32|FreeInPages,U32|

      ## We now split the counter info in separate headers
      $HeaderInLines = $esxtopCounters -split "`n" | select-string "|"

      ## The NUMA stats can be found onder 'SchedGroup'
      $HeaderSchedGroup = $HeaderInLines | where-object {$_.Line -match "[|]SchedGroup[|]"}
      $Headers = $HeaderSchedGroup -replace ",.{1,4}[|]","|" 
      $Headers = $Headers.split("|", [StringSplitOptions]::RemoveEmptyEntries) 
 
      ## We now split the stats into separate values
      $DataInLines = $esxtopStats -split "`n" | Select-String "|"
      $DataSchedGroup = $DataInLines | where-object {$_.Line -match "[|]SchedGroup[|]"}

      ## Gebruik van [|] ipv alleen | omdat het een speciaal karakter is in een string
      ## Gebruik van [.] ipv alleen . omdat het een speciaal karakter is in een string
      $DataSchedGroup = $DataSchedGroup | Where-Object {$_.line -match "[|]vm[.]" }

      ## Stats are now filter to just VM entries:
      ## |SchedGroup|13567824|vm.4430541|1|1|VMDC002|10416|0|-1|-3|-1|1|mhz|0|-1|-3|80896|4|kb|1|2|0|0|0|0|3913712|100|0|11|2|2|1|4430541|
      ## |SchedGroup|12883482|vm.4316334|1|1|VMTEST|15260|0|-1|-3|-1|1|mhz|0|-1|-3|93184|4|kb|1|1|0|0|0|0|8179712|100|0|9|3|2|1|4316334|
      ## |SchedGroup|13558449|vm.4429332|1|1|VMDF02|1000|0|-1|-3|-1|1|mhz|0|-1|-3|77824|4|kb|1|2|0|0|0|0|3494260|100|0|11|1|2|1|4429332|

      $DataSetRAW = $DataSchedGroup -replace '^\||\|$'
      $DataSetRAW = $DataSetRAW -replace "[|]", ","
    
      ## Convert to CSV to get headers combined with stats in one object
      $DataSet = $DataSetRAW | ConvertFrom-Csv -Delimiter "," -Header $Headers
      	  
      $DataSet | Add-Member -NotePropertyName 'VMHostName' -NotePropertyValue $($CurrentVMhost.Name)

      [array]$AllHostsDataSet += ( $DataSet | Where-Object {$_ -ne ''} )
	}
	
    return($AllHostsDataSet)
}


