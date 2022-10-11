using module .\Common.psm1

class Flipping
{
    static $characters = $null
    static $backgroundColor = $null

    static $kWaitTimeLineInterval = 0.1
    static $kWaitTimeXInterval = 0.01
    static $kStartTime = [RandomDouble]::new(0.0, 0.02)
    static $kTextAnimDuration = [RandomDouble]::new(1.2, 1.3)

    static [void] Init([System.Management.Automation.Host.BufferCell[,]]$windowBuffer)
    {
        [Flipping]::backgroundColor = (Get-Host).UI.RawUI.BackgroundColor
        [Flipping]::characters = CreateCharacters ([FlippingCharacter]) $windowBuffer

        $maxY = 0
        foreach ($character in [Flipping]::characters)
        {
            $maxY = [Math]::Max($character.y, $maxY)
        }
        $lineWaitTimeMax = ($maxY+1) * [Flipping]::kWaitTimeLineInterval

        $lineWaitTimes = @{}
        foreach ($character in [Flipping]::characters)
        {
            if (-not $lineWaitTimes.ContainsKey($character.y))
            {
                $lineWaitTimes[$character.y] = Get-Random -Minimum 0 -Maximum $lineWaitTimeMax
            }

            $character.waitTime = $lineWaitTimes[$character.y] + $character.x * [Flipping]::kWaitTimeXInterval
        }
    }

    static [void] Term()
    {
        [Flipping]::characters = $null
    }

    static [Boolean] Render([System.Management.Automation.Host.BufferCell[,]]$windowBuffer, [Double]$dt, [Double]$speed)
    {
        foreach ($character in [Flipping]::characters)
        {
            $character.Update($speed * $dt)
        }

        $isAllFinished = $true
        foreach ($character in [Flipping]::characters)
        {
            if (-not $character.isFinished)
            {
                $isAllFinished = $false
                break
            }
        }
        if ($isAllFinished)
        {
            return $true
        }

        foreach ($character in [Flipping]::characters)
        {
            $character.Render($windowBuffer)
        }
        return $false
    }
}

class FlippingCharacter : RenderItem
{
    $waitTime = 0
    $startTime = 0
    $timer = 0
    $textAnimation = $null
    $isStarted = $false

    FlippingCharacter($cell, $cellTrailing, $x, $y)
        : base($cell, $cellTrailing, $x, $y)
    {
        $this.startTime = [Flipping]::kStartTime.Get()
        $textAnimDuration = [Flipping]::kTextAnimDuration.Get()
        $randChar = [RandomInt]::new(97, 122)
        [Char]$rand1 = $randChar.Get()
        [Char]$rand2 = $randChar.Get()
        [Char]$rand3 = $randChar.Get()

        $this.textAnimation = [LinearAnimation]::new(@(
            $rand2,
            $rand3,
            $rand2,
            $rand1,
            $rand3,
            $rand1,
            $rand1,
            $rand1,
            $rand1,
            $rand1,
            $rand1,
            $rand1,
            $rand1,
            $rand2,
            $rand3
        ), $textAnimDuration)
    }

    [void] Start()
    {
        $this.isStarted = $true
    }

    [void] Update($dt)
    {
        if (-not $this.isStarted)
        {
            $this.waitTime -= $dt
            if ($this.waitTime -lt 0)
            {
                $this.Start()
            }
            return
        }
        if ($this.isFinished)
        {
            return
        }

        $this.timer += $dt
        if ($this.timer -lt $this.startTime)
        {
            return
        }

        if ($this.textAnimation.IsFinished())
        {
            $this.Finish()
        }

        $this.textAnimation.Update($dt)
        $text = $this.textAnimation.GetValue()

        $color = [System.ConsoleColor]::Yellow
        if ($this.textAnimation.GetRatio() -gt 0.1)
        {
            $color = [System.ConsoleColor]::Cyan
        }

        $this.SetCell(
            $text,
            $color,
            [Flipping]::backgroundColor
        )
    }
}
