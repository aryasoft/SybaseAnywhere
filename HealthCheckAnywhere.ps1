Set-ExecutionPolicy Unrestricted -Scope CurrentUser
$senderMailAddress = "sender@contoso.com"
[string[]]$reipientMailAddress= "dba@contoso.com","sender@contoso.com"
$PingMachines = @(
("10.0.84.123","2638","username","passwd"),#prod anywhere
("10.0.84.124","2638","username","username") #test anywhere
)


function SendAnEmailToCrew($subject, $body, [bool]$AsHtml)
{
    if($AsHtml -eq $true)
    {
        Send-MailMessage -From $senderMailAddress -To $reipientMailAddress -Subject $subject -Body $body -BodyAsHtml -Priority High -SmtpServer 'smtp.contoso.com'
    }else
    {
        Send-MailMessage -From $senderMailAddress -To $reipientMailAddress -Subject $subject -Body $body -Priority High -SmtpServer 'smtp.contoso.com'
    }
}

function CheckSqlAnyWhere($name)
{
    [void][System.Reflection.Assembly]::LoadWithPartialName("Sap.Data.SQLAnywhere.v4.5")
    # Connection string
    $connectionString = "Host="+$name[0]+":"+$name[1]+";UserID="+$name[2]+";Password="+$name[3]
    # Create SAConnection object
    $conn = New-Object Sap.Data.SQLAnywhere.SAConnection($connectionString)
    $firstStartDate = (GET-DATE) 
    Try
    {
        # Connect to remote IQ server
        $conn.Open()
 
        # simple query
        $Query = 'select now() as NowDate'
 
        # Create a SACommand object and feed it the simple $Query
        $command = New-Object Sap.Data.SQLAnywhere.SACommand($Query, $conn)
 
        # Execute the query on the remote IQ server
        $reader = $command.ExecuteReader()
 
        # create a DataTable object 
        $Datatable = New-Object System.Data.DataTable
 
        # Load the results into the $DataTable object
        $DataTable.Load($reader)
 
        # Send the results to the screen in a formatted table
        #$DataTable | Format-Table -Auto

        $reader.Dispose();
        $conn.Close();
        $StartDate=[datetime]$DataTable.Rows[0].NowDate
        $EndDate=(GET-DATE) 
        $difInMinutes= NEW-TIMESPAN –Start $StartDate –End $EndDate
        #if($difInMinutes.TotalMilliseconds -gt 3000)
        #{
        #    $a = $($difInMinutes.TotalMilliseconds.ToString() +"script duration between open and close connection "+ $(NEW-TIMESPAN –Start $firstStartDate –End $EndDate).TotalMilliseconds.ToString()) 
        #    SendAnEmailToCrew 'There was a latency in milisecond(s)' $a $false 
        #}
        #else
        #{
        #    Write-Host $difInMinutes.TotalMilliseconds  "latency SqlAnyWhere" -ForegroundColor Green
        #}
         
        $DataTable.Dispose();   
    }
    Catch [System.Management.Automation.MethodInvocationException]
    {
       $er= "SQL Anywhere is Down! Query is 'select now() as NowDate'  Check Date is : "+ $(Get-Date).ToString()
       Write-Host $er $DataTable.Rows[0].NowDate.ToString()
       SendAnEmailToCrew 'SqlAnywhere Connectivity Check Services' $er $false
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        SendAnEmailToCrew 'SqlAnywhere Connectivity Check Services' "Failed to read file $FailedItem. The error message was $ErrorMessage"   $false
        Break;
    }
}

function PingCheck()
{
    foreach ($name in $PingMachines)
    {
        if (Test-Connection -ComputerName $name[0] -Count 1 -ErrorAction SilentlyContinue)
        {
            Write-Host $name[0] "machine is up"
            if (Test-NetConnection $name[0] -Port $name[1] -InformationLevel Quiet  -ErrorAction SilentlyContinue)
            {
                Write-Host $name[0] "port" $name[1]" is up"
                if($name[1] -eq 2638)
                {
                    Write-Host $name[0] "checking for SqlAnyWhere" -ForegroundColor Gray
                    CheckSqlAnyWhere $name
                }
            }
            else{
                Write-Host $name[0] $name[1]",down"
                SendAnEmailToCrew  "E-belediye $name port is down!" $name" is down!" $false
            }
        }
        else
        {
            Write-Host $name[0]",down"
            SendAnEmailToCrew  "E-belediye Machine is down!" $name[0]" is down!" $false
        }
    }
}


PingCheck