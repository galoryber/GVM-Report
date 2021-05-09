<#
.Synopsis
   Create a nice (..er) looking report from GVM / OpenVAS report data. 
.DESCRIPTION
   GVM / OpenVAS reports are too old looking to feel valuable. This script will take in the OpenVAS report data and format it in a cleaner more modern way. Export OpenVAS / Greenbone data to csv format, and use that as input to this script to get an html based report. 
   The report colors and images can be customized to match company colors or logos. 
.EXAMPLE
   New-GVMReport -InputCSV GVMExport.csv -CustomLogo CompanyLogo.png -ReportName ClientAReport -OutputPDF $true
   Default is to create an HTML report based on the csv input. Additional options for the logo and PDF are TODOs. 
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   Goals: CSS to define custom colors, Custom Logo input, HTML output, but option to export to PDF, 

   Well, here I thought I was going to do something cool. I'll just be copying from here. 
   https://adamtheautomator.com/html-report/

   https://www.w3schools.com/howto/howto_css_skill_bar.asp Severity bars - CSS 

.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
function New-GVMReport
{
    Param
    (
        # 
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $InputCSV,

        # Param2 help description
        [ValidateNotNullOrEmpty()]
        [string]
        $ReportName,

        #Param3 
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputDirectory
    )

    Begin
    {
        $CSVFile = Import-Csv $InputCSV
        $TitleStatement = "This report displays the results of vulnerability scanning that was performed against the client network during GlobeTech LLC's assessment. It aims to identify known vulnerabilities and CVEs throughout the network in a mass scan of networked devices. This report is a snapshot in time, capturing those devices that were online during the scan process."
        $ReportTitle = ConvertTo-Html -Fragment -PreContent "<h1>$ReportName</h1>" -PostContent "<p id='CreationDate'>Report Date: $(Get-Date)</p></br><img id='LogoPlacement' src='https://globetech.biz/wp-content/uploads/2020/11/gt2-e1605662950390.png'> <p id='StandardText'>$TitleStatement</p></br></br>"
        
        # For some reason, reference to -CssUri didn't work, but I wanted a seperate CSS file for easier CSS editing - this did it
        $StyleSheets = Get-Content -Path .\GVM.css -Raw  
        $header = @"
<style>
$StyleSheets    
</style>
"@ # <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>


    }
    Process
    {
        
        # Summary of Criticality
        $CSVFile | Group-Object -Property Severity 
        $VulnSummaryGraphs = $CSVFile | Group-Object -Property Severity | ConvertTo-Html -Property Name,Count -Fragment -PreContent "<h2> Severity Summary </h2>"
        $VulnSummaryGraphs = $VulnSummaryGraphs -replace '<td>High</td>','<td class="HighSeverity">High</td>'
        $VulnSummaryGraphs = $VulnSummaryGraphs -replace '<td>Medium</td>','<td class="MediumSeverity">Medium</td>'
        $VulnSummaryGraphs = $VulnSummaryGraphs -replace '<td>Low</td>','<td class="LowSeverity">Low</td>'
        
        # Chart of Criticality # https://www.w3schools.com/howto/howto_google_charts.asp
        #$TotalVulns = $CSVFile.Severity.Count 
        $HighVulns = $CSVFile.Severity.Contains("High").Count
        $MediumVulns = $CSVFile.Severity.Contains("Medium").Count
        $LowVulns = $CSVFile.Severity.Contains("Low").Count
 <#       $PieChartJS = @"
<script type="text/javascript">
// Load google charts
google.charts.load('current', {'packages':['corechart']});
google.charts.setOnLoadCallback(drawChart);

// Draw the chart and set the chart values
function drawChart() {
    var data = google.visualization.arrayToDataTable([
    ['Severity', 'Quantity'],
    ['High', $HighVulns],
    ['Medium', $MediumVulns],
    ['Low', $LowVulns]
]);

    // Optional; add a title and set the width and height of the chart
    var options = {'title':'My Average Day', 'width':550, 'height':400};

    // Display the chart inside the <div> element with id="piechart"
    var chart = new google.visualization.PieChart(document.getElementById('piechart'));
    chart.draw(data, options);
}
</script>
"@
#>

        # Summary of Vulnerabilities
        $VulnSummary = $CSVFile | ConvertTo-Html -Property IP,CVSS,Severity,"NVT Name" -Fragment -PreContent "<h2>Summary of Vulnerabilities</h2>"
        $VulnSummary = $VulnSummary -replace '<td>High</td>','<td class="HighSeverity">High</td>'
        $VulnSummary = $VulnSummary -replace '<td>Medium</td>','<td class="MediumSeverity">Medium</td>'
        $VulnSummary = $VulnSummary -replace '<td>Low</td>','<td class="LowSeverity">Low</td>'

        # Iterate through all vulnerabilites and provide details results
        # Can have multiple findings for each host, so have to iterate through all objects in the CSVFile
        $CSVFile | ForEach-Object {
            $VulnIP = $_.IP 
            $VulnHostDetails += $_ | ConvertTo-Html -As List -Property Hostname,Port,"Port Protocol",CVSS,Severity,"NVT Name",Summary,TimeStamp,"Specific Result",Impact,Solution,"Affected Software/OS:","Vulnerability Insight","Vulnerability Detection Method:","Product Detection Result:",CVEs,"Other References" -Fragment -PreContent "<h2>$VulnIp</h2>" -PostContent "</br>"
        }
        $VulnHostDetails = $VulnHostDetails -replace '<td>High</td>','<td class="HighSeverity">High</td>'
        $VulnHostDetails = $VulnHostDetails -replace '<td>Medium</td>','<td class="MediumSeverity">Medium</td>'
        $VulnHostDetails = $VulnHostDetails -replace '<td>Low</td>','<td class="LowSeverity">Low</td>'
    }
    End
    {
        $Report = ConvertTo-Html -Body "$ReportTitle`r`n $VulnSummaryGraphs`r`n $PieChartJS`r`n `r`n </br></br> $VulnSummary`r`n </br></br> $VulnHostDetails" -Title $ReportName -Head $header
        
        $OutputFile = $ReportName+".html"
        $OutputLocation = Join-Path $OutputDirectory $OutputFile 
        $FinalOutput = $Report | Out-File $OutputLocation
    }
}