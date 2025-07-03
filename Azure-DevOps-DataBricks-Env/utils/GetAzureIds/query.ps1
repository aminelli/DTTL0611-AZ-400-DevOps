param(
    $file = "query_data.csv"
)

$data = Get-Content $file | ConvertFrom-Csv

$userIds = $data.User | Get-Unique

$body = @{
    ids = $userIds
} | ConvertTo-Json -Compress;
$body = $body -replace '"', '\"';

az rest `
--method POST `
--url 'https://graph.microsoft.com/v1.0/directoryObjects/getByIds' `
--headers 'Content-Type=application/json'  `
--body $body `
> results.json