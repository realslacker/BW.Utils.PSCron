class PSCronDateTime : System.IComparable {

    [datetime]$Local
    [datetime]$Utc

    PSCronDateTime ( [datetime]$Date ) {

        $this.__Init( $Date, [PSCronTicks]::Minute )

    }

    PSCronDateTime ( [datetime]$Date, [PSCronTicks]$Ticks ) {

        $this.__Init( $Date, $Ticks )

    }

    hidden __Init ( [datetime]$Date, [PSCronTicks]$Ticks ) {

        $Date = [datetime]::new( $Date.Ticks - ( $Date.Ticks % [timespan]::"TicksPer$Ticks" ), $Date.Kind )

        if ( $Date.Kind -eq 'Utc' ) {

            $this.Utc       = $Date
            $this.Local     = $Date.ToLocalTime()

        } else {

            $this.Utc       = $Date.ToUniversalTime()
            $this.Local     = $Date

        }

    }

    # default conversion to string uses local time
    [string] ToString () {

        return $this.Local.ToString() + ' (local)'

    }
    
    [string] ToString ( [string]$Format ) {

        return $this.Local.ToString( $Format ) + ' (local)'

    }

    [string] ToString ( [System.DateTimeKind]$Kind ) {

        return $this."$Kind".ToString() + ' (' + $Kind.ToString().ToLower() + ')'
        
    }

    [string] ToString ( [System.DateTimeKind]$Kind, [string]$Format ) {

        return $this."$Kind".ToString( $Format ) + ' (' + $Kind.ToString().ToLower() + ')'
        
    }

    [bool] Equals ( $that ) {

        [PSCronDateTime]$that = $that

        return ( $this.Utc -eq $that.Utc )
    
    }

    [int] CompareTo ( $that ) {

        [PSCronDateTime]$that = $that

        if ( $this.Utc -lt $that.Utc ) { return -1 }
        if ( $this.Utc -eq $that.Utc ) { return 0  }
        return 1
    
    }

    # always cast to local time
    static [datetime] op_Implicit( [PSCronDateTime]$Instance ) {
        
        return $Instance.Local
    
    }

    static [PSCronDateTime] op_Addition ( [PSCronDateTime]$Instance, [timespan]$Timespan ) {

        return [PSCronDateTime]( $Instance.Utc + $Timespan )
    
    }

    static [timespan] op_Subtraction ( [PSCronDateTime]$First, [PSCronDateTime]$Second ) {

        return [timespan]( $First.Utc - $Second.Utc )
    
    }

    static [PSCronDateTime] op_Subtraction ( [PSCronDateTime]$Instance, [timespan]$Timespan ) {

        return [PSCronDateTime]( $Instance.Utc - $Timespan )
    
    }

}
