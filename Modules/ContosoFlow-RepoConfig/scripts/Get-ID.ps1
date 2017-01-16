Function Get-ID {
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $name,
        [switch]$Octopus,
        [switch]$TeamCity
    )
    Begin {
        if ($Octopus -and $TeamCity)
        {
            throw "Unable to use both Octopus and TeamCity switches at the same time. Please specifiy only one"
        }
    }
    Process {
        foreach ($item in $name)
        {
            switch ($item)
            {
                'Lotteries.TaGs.Host' { if($TeamCity){'ContinuousDelivery_LotteriesCore_TaGsHost_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tags-host'}}
                'Lotteries.TaGs.DB' { if($TeamCity){'ContinuousDelivery_LotteriesCore_TaGs_Database_1BuildPackagePublish'}elseif($Octopus){'tags-database'}}
                'Lotteries.TaGs.Reports'{ if($TeamCity){ 'ContinuousDelivery_LotteriesCore_TaGs_Reports_1BuildPackagePublish'}elseif($Octopus){'tags-reports'}}
                'Lotteries.Financial.DB' { if($TeamCity){ 'ContinuousDelivery_LotteriesCore_Financial_Database_LotteriesFinancialDb'}elseif($Octopus){'tags-financials-database'}}
                'Lotteries.Tocis.WebServices' { if($TeamCity){ 'TaGs_Tocis_TocisWebServices_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tocis-webservices'}}
                'Lotteries.Tocis.Client' { if($TeamCity){ 'TaGs_Tocis_TocisClient_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tocis-client'}}
                'Lotteries.ASL' { if($TeamCity){ 'ContinuousDelivery_LotteriesCore_Mosaic_AslModulesLotteries_BuildAslModulesLotte'}elseif($Octopus){'asl-modules-lotteries'}}
                Default {Write-Error "`nThe repo/project name:$item is not a valid option`n" -ErrorAction Continue}
            }
        }
    }
}
