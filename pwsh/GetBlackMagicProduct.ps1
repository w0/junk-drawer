<#
.SYNOPSIS
    Query Blackmagic api to get product information and download links.
.DESCRIPTION
    Use this to get product information and valid download links for Blackmagic Products. You can use this as a helper function with other automation to help keep your software up to date.
.NOTES
    If a Blackmagic product requires registration you must provide the registration information using the `-Registration` parameter. 

    $product_reg = @{ 
        firstname = "John" 
        lastname = "Doe"
        email = "jdoe@example.com" 
        phone="555555555"
        city="New York" 
        street="Wall St" 
        country="us" 
        product="davinci resolve"
    }

        
    Thank you to https://github.com/autopkg/timsutton-recipes/blob/master/Blackmagic/BlackMagicURLProvider.py for documenting the usage of these apis.
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Get-BlackMagicProduct -ProductName 'DaVinci Resolve Studio (?<version>[0-9\.]+)( Update)'
    Returns the latest version of DaVinci Resolve Studioa and its downloadUrl

.EXAMPLE
    $product_reg = @{ 
        firstname = "John" 
        lastname = "Doe"
        email = "jdoe@example.com" 
        phone="555555555"
        city="New York" 
        street="Wall St" 
        country="us" 
        product="davinci resolve"
    }
    Get-BlackMagicProduct 'DaVinci Resolve (?<version>[0-9\.]+)( Update)' -Registration $product_reg
    Returns the latest version of DaVinci Resolve and its downloadUrl. Product registration is required.
    If when downloading a product from Blackmagics website doesn't provide a download only option. You know the product requires registration.
#>

function Get-BlackMagicProduct {
    [CmdletBinding()]
    param (
        # BlackMagic Download API
        [Parameter()]
        [string]
        $Uri = 'https://www.blackmagicdesign.com/api/support/us/downloads.json',

        # Name of the product to get download info for. Regex is expected, you must include a matching group for version
        [Parameter(Mandatory)]
        [string]
        $ProductName,

        # A hashtable containing product registration information. Only needed if product requires registration.
        [Parameter()]
        [hashtable]
        $Registration
    )

    function getDownloadURL {
        param (
            # DownloadId for the BlackMagic Product
            [Parameter(Mandatory)]
            [string]
            $DownloadId,

            # Request body to be submiteed to the download api
            [Parameter(Mandatory)]
            [hashtable]
            $RequestBody
        )

        $apiURL = 'https://www.blackmagicdesign.com/api/register/us/download/' + $DownloadId

        $WRequest = @{
            Uri = $apiURL
            Method = 'Post'
            Headers = @{
                'User-Agent' = 'Mozilla/5.0'
                'Accept' = 'application/json'
            }
        }

        Write-Output (Invoke-WebRequest @WRequest -Body $RequestBody -UseBasicParsing).Content
        
    }

    try {
        $request = Invoke-WebRequest -Uri $Uri -UseBasicParsing
    } catch {
        $StatusCode = $_.Exception.Response.StatusCode
        $ErrorMsg = $_.ErrorDetails.Message

        throw "$([int]$StatusCode) $StatusCode - $ErrorMsg"
    }

    $Content = $request.Content | ConvertFrom-Json

    $Products = $Content.downloads | Where-Object name -Match $ProductName | % {
        if ($Matches.version) {
            $_ | Add-Member -MemberType NoteProperty -Name 'version' -Value $Matches.version -PassThru
        } else {
            throw 'Unable to find regex group version'
        }
    }

    $Latest = $Products | Sort-Object -Property { [version]$_.version } | Select-Object -Last 1

    $RequestBody = @{
        platform = 'Windows'
    }

    if ($Latest.requiresRegistration) {
        if ($Registration -eq $null) {
            throw 'This product requires registration. Please set all registration information'
        }
        
        $RequestBody += $Registration
    } else {
        $RequestBody += @{ country = 'us' }
    }

    $latestUrl = getDownloadURL -DownloadId $Latest.urls.Windows.downloadId -RequestBody $RequestBody

    Write-Output $Latest | Add-Member -MemberType NoteProperty -Name 'downloadUrl' -Value $latestUrl -PassThru
    
}