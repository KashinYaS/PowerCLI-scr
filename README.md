# PowerCLI-scr
Additional comandlets for PowerCLI

Import all functions:
Import-Module c:\Users\User\Documents\GitHub\PowerCLI-scr\PowerCLI-scr

## SATP claimrule comandlets
- Add-SATPClaimrule - Add predefined SATP Claimrule(s) to VMHost
- Remove-SATPClaimrule, Remove-SATPClaimrule - Delete predefined SATP Claimrule(s) to VMHost
- Get-SATPClaimrule - Get VMHost's SATP Claimrules
- Repair-Datastore - Find all hosts, which does not know current datastore size after expansion so it is shown as not expanded in vCenter.

## Datastore comandlet
- Expand-Datastore - Expand Datastore after it's LUN expansion. Does not work with Datastore which resides on two or more LUNs. Works well if Datastore is presented to two or more clusters (and if LUN's ID are different in different clusters).
