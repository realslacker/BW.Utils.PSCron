---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Get-PSCronNextRun

## SYNOPSIS
Get next run for a given cron schedule.

## SYNTAX

```
Get-PSCronNextRun [-Schedule] <String> [[-ReferenceDate] <DateTime>] [<CommonParameters>]
```

## DESCRIPTION
Get next run for a given cron schedule.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-PSCronNextRun '*/15 * * * *'
```

Returns the next quarter hour.

### Example 2
```powershell
PS C:\> Get-PSCronNextRun '15 1 * * *' -ReferenceDate (Get-Date -Date '1:00 AM')
```

Returns 1:15 AM on the same day.

## PARAMETERS

### -Schedule
The cron schedule to parse.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReferenceDate
A datetime object including from which all operations will be relative to.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: ( Get-PSCronTimestamp )
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object

## OUTPUTS

### System.DateTime

## NOTES

## RELATED LINKS
