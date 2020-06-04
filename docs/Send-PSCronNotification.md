---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Send-PSCronNotification

## SYNOPSIS
Send a notification email from the output of Invoke-PSCronJob.

## SYNTAX

```
Send-PSCronNotification [-CronResult] <Object> [-To] <String[]> [[-Cc] <String[]>] [[-Bcc] <String[]>]
 [-From] <String> [[-SmtpServer] <String>] [[-Priority] <MailPriority>]
 [[-DeliveryNotificationOption] <DeliveryNotificationOptions>] [[-Subject] <String>]
 [[-Credential] <PSCredential>] [-UseSsl] [[-Port] <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Send a notification email from the output of Invoke-PSCronJob. Uses Send-MailMessage under the hood.
This function is an example for using pipeline output of Invoke-PSCronJob to perform additional steps.

## EXAMPLES

### Example 1
```powershell
PS C:\> Invoke-PSCronJob '* * * * *' 'Test Job' { Write-Information 'Some Text' } -PassThru | Send-PSCronNotification -To 'recipient@domain.com' -From 'noreply@domain.com'
```

Sends a job notification to 'recipient@domain.com' for the job 'Test Job'. The email will include the Result as the message body.

## PARAMETERS

### -CronResult
Output from Invoke-PSCronJob -PassThru

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -To
See Send-MailMessage

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Cc
See Send-MailMessage

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Bcc
See Send-MailMessage

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -From
See Send-MailMessage

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SmtpServer
See Send-MailMessage

```yaml
Type: String
Parameter Sets: (All)
Aliases: ComputerName

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Priority
See Send-MailMessage

```yaml
Type: MailPriority
Parameter Sets: (All)
Aliases:
Accepted values: Normal, Low, High

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DeliveryNotificationOption
See Send-MailMessage

```yaml
Type: DeliveryNotificationOptions
Parameter Sets: (All)
Aliases: DNO
Accepted values: None, OnSuccess, OnFailure, Delay, Never

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Subject
The notification subject. The subject will be parsed with the string formatter and {0}
replaced with the job name.

```yaml
Type: String
Parameter Sets: (All)
Aliases: sub

Required: False
Position: 9
Default value: [CRON] {0}
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
See Send-MailMessage

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseSsl
See Send-MailMessage

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Port
See Send-MailMessage

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Send the CronResult object down the pipeline.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
