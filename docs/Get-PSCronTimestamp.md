---
external help file: BW.Utils.PSCron-help.xml
Module Name: BW.Utils.PSCron
online version:
schema: 2.0.0
---

# Get-PSCronTimestamp

## SYNOPSIS
Return a UTC timestamp rounded to the nearest unit of time.

## SYNTAX

```
Get-PSCronTimestamp [[-Date] <DateTime>] [[-Resolution] <String>] [<CommonParameters>]
```

## DESCRIPTION
Return a UTC timestamp rounded to the nearest unit of time. Defaults to the nearest minute.

## EXAMPLES

### Example 1
```powershell
PS C:\> Get-PSCronTimestamp
```

Returns the current UTC timestamp rounded to the nearest minute.

## PARAMETERS

### -Date
The date to convert and round.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Resolution
The unit of time to round to.

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Accepted values: Second, Minute, Hour, Day

Required: False
Position: 2
Default value: Minute
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.DateTime

## NOTES

## RELATED LINKS
