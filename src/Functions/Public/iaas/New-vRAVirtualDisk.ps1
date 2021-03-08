function New-vRAVirtualDisk {
    <#
        .SYNOPSIS
        Retrieve a vRA Machine's Disks

        .DESCRIPTION
        Retrieve the disks for a vRA Machine

        .PARAMETER Name
        The Name you would like to give the new disk/volume

        .PARAMETER Encrypted
        Switch indicating if the device will be encrypted during build

        .PARAMETER CapacityInGB
        Integer value indicating capacity of the disk in GB

        .PARAMETER DeviceDescription
        A description we can associate with the disk after creating it

        .PARAMETER Persistent
        Another switch indicating the disk to be a persistent disk

        .PARAMETER ProjectId
        The id of the project in which to build the disk/volume in

        .PARAMETER ProjectName
        As an alternate, a project name can be given for this operation

        .PARAMETER WaitForCompletion
        If this flag is added, this function will wait for the request to complete and will reutnr the created Virtual Disk

        .PARAMETER CompletionTimeout
        The default of this paramter is 2 minutes (120 seconds), but this parameter can be overriden here

        .PARAMETER Force
        Force the creation

        .OUTPUTS
        System.Management.Automation.PSObject.

        .EXAMPLE
        New-vRAVirtualDisk -Name 'test_disk_1' -CapacityInGB 10 -ProjectId 'b1dd48e71d74267559bb930934470'

        .EXAMPLE
        New-vRAVirtualDisk -Name 'test_disk_1' -CapacityInGB 10 -ProjectName 'GOLD'

        .EXAMPLE
        New-vRAVirtualDisk -Name 'test_disk_1' -CapacityInGB 10 -ProjectName 'GOLD' -WaitForCompletion

        .EXAMPLE
        New-vRAVirtualDisk -Name 'test_disk_1' -CapacityInGB 10 -ProjectName 'GOLD' -WaitForCompletion -CompletionTimeout 300

        .EXAMPLE
        New-vRAVirtualDisk -Name 'test_disk_1' -CapacityInGB 10 -ProjectId 'b1dd48e71d74267559bb930934470' -Persistent -Encrypted

    #>
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High",DefaultParameterSetName="ByName")][OutputType('System.Management.Automation.PSObject')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WaitForCompletion',Justification = 'False positive as rule does not scan child scopes')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'CompletionTimeout',Justification = 'False positive as rule does not scan child scopes')]

        Param (

            [Parameter(Mandatory=$true,ParameterSetName="ByName")]
            [Parameter(Mandatory=$true,ParameterSetName="ById")]
            [ValidateNotNullOrEmpty()]
            [String]$Name,

            [Parameter(Mandatory=$true,ParameterSetName="ByName")]
            [Parameter(Mandatory=$true,ParameterSetName="ById")]
            [ValidateNotNullOrEmpty()]
            [int]$CapacityInGB,

            [Parameter(Mandatory=$true,ParameterSetName="ById")]
            [ValidateNotNullOrEmpty()]
            [String[]]$ProjectId,

            [Parameter(Mandatory=$true,ParameterSetName="ByName")]
            [ValidateNotNullOrEmpty()]
            [String[]]$ProjectName,

            [Parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [String[]]$DeviceDescription,

            [Parameter()]
            [switch]$Persistent,

            [Parameter()]
            [switch]$Encrypted,

            [Parameter()]
            [switch]$WaitForCompletion,

            [Parameter()]
            [int]$CompletionTimeout = 120,

            [Parameter()]
            [switch]$Force

        )
        Begin {

            $APIUrl = "/iaas/api/block-devices"

            function CalculateOutput([int]$CompletionTimeout,[switch]$WaitForCompletion,[PSCustomObject]$RestResponse) {

                if ($WaitForCompletion.IsPresent) {
                    # if the wait for completion flag is given, the output will be different, we will wait here
                    # we will use the built-in function to check status
                    $ElapsedTime = 0
                    do {
                        $RequestResponse = Get-vRARequest -RequestId $RestResponse.id
                        if ($RequestResponse.Status -eq "FINISHED") {
                            foreach ($Resource in $RequestResponse.Resources) {
                                $Response = Invoke-vRARestMethod -URI "$Resource" -Method GET
                                [PSCustomObject]@{
                                    Name = $Response.name
                                    Status = $Response.status
                                    Owner = $Response.owner
                                    ExternalRegionId = $Response.externalRegionId
                                    ExternalZoneId = $Response.externalZoneId
                                    Description = $Response.description
                                    Tags = $Response.tags
                                    CapacityInGB = $Response.capacityInGB
                                    CloudAccountIDs = $Response.cloudAccountIds
                                    ExternalId = $Response.externalId
                                    Id = $Response.id
                                    DateCreated = $Response.createdAt
                                    LastUpdated = $Response.updatedAt
                                    OrganizationId = $Response.orgId
                                    Properties = $Response.customProperties
                                    ProjectId = $Response.projectId
                                    Persistent = $Response.persistent
                                }
                            }
                            break # leave loop as we are done here
                        }
                        $ElapsedTime += 5
                        Start-Sleep -Seconds 5
                    } while ($ElapsedTime -lt $CompletionTimeout)
                } else {
                    [PSCustomObject]@{
                        Name = $RestResponse.name
                        Progress = $RestResponse.progress
                        Id = $RestResponse.id
                        Status = $RestResponse.status
                    }
                }

            }
        }
        Process {

            try {


                switch ($PsCmdlet.ParameterSetName) {

                    # --- Create Virtual Disk by the Project ID
                    'ById' {
                        if ($Force.IsPresent -or $PsCmdlet.ShouldProcess($ProjectId)){
                            $Body = @"
                                {
                                    "capacityInGB": $($CapacityInGB),
                                    "encrypted": $($Encrypted.IsPresent),
                                    "name": "$($Name)",
                                    "description": "$($DeviceDescription)",
                                    "persistent": $($Persistent.IsPresent),
                                    "projectId": "$($ProjectId)"
                                }
"@
                            $RestResponse = Invoke-vRARestMethod -URI "$APIUrl" -Method POST -Body $Body

                            CalculateOutput $CompletionTimeout $WaitForCompletion $RestResponse
                        }
                        break
                    }

                    # --- Get Project by its name
                    # --- Will need to retrieve the Project first, then use ID to get final output
                    'ByName' {
                        if ($Force.IsPresent -or $PsCmdlet.ShouldProcess($ProjectName)){
                            $ProjResponse = Invoke-vRARestMethod -URI "/iaas/api/projects`?`$filter=name eq '$ProjectName'`&`$select=id" -Method GET
                            $ProjId = $ProjResponse.content[0].id

                            $Body = @"
                                {
                                    "capacityInGB": $($CapacityInGB),
                                    "encrypted": $($Encrypted.IsPresent),
                                    "name": "$($Name)",
                                    "description": "$($DeviceDescription)",
                                    "persistent": $($Persistent.IsPresent),
                                    "projectId": "$($ProjId)"
                                }
"@
                            Write-Verbose $Body
                            $RestResponse = Invoke-vRARestMethod -URI "$APIUrl" -Method POST -Body $Body

                            CalculateOutput $CompletionTimeout $WaitForCompletion $RestResponse
                        }
                        break
                    }

                }
            }
            catch [Exception]{

                throw
            }
        }
        End {

        }
    }
