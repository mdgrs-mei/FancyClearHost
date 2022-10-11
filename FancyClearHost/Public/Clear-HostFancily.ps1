$players = @{
    Falling = [Falling]
    Flipping = [Flipping]
    Bricks = [Bricks]
}

<#
.SYNOPSIS
Clears the host display with text animations.

.DESCRIPTION
Clears the host display with text animations.

.PARAMETER Mode
Type of the animation. If this is not set, the animation type is randomly selected.

.PARAMETER Speed
Playback speed.

.INPUTS
None.

.OUTPUTS
None.

.EXAMPLE
Clear-HostFancily

.EXAMPLE
Clear-HostFancily -Mode Flipping -Speed 0.8

#>
function Clear-HostFancily
{
    param
    (
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Falling", "Flipping", "Bricks")]
        [String]$Mode,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Double]$Speed = 1.0
    )

    process
    {
        if ($null -eq $host.UI.RawUI.WindowSize)
        {
            # RawUI is not available (e.g. Windows PowerShell ISE).
            Clear-Host
            return
        }

        if (-not $Mode)
        {
            $Mode = $players.Keys | Get-Random
        }

        Play $players[$Mode] $Speed
    }
}
