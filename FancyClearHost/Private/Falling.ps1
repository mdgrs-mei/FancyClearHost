using module .\Common.psm1

class Falling
{
    static $characters = $null
    static $startLine = 0
    static $windowHeight = 0

    static $kStartLineVelocity = 0.2
    static $kStartTime = [RandomDouble]::new(0.0, 0.1)
    static $kMass = [RandomDouble]::new(1.0, 6.0)
    static $kColorAnimDuration = [RandomDouble]::new(0.8, 1.2)
    static $kColorAnimStartTime = 0.6
    static $kGravity = 9.8
    static $kDragCoef = 10.0
    static $kMeterToCellRatio = 20

    static [void] Init([System.Management.Automation.Host.BufferCell[,]]$windowBuffer)
    {
        [Falling]::windowHeight = $windowBuffer.GetUpperBound(0)
        [Falling]::characters = CreateCharacters ([FallingCharacter]) $windowBuffer

        $maxY = 0
        foreach ($character in [Falling]::characters)
        {
            $maxY = [Math]::Max($character.y, $maxY)
        }
        [Falling]::startLine = $maxY
    }

    static [void] Term()
    {
        [Falling]::characters = $null
    }

    static [Boolean] Render([System.Management.Automation.Host.BufferCell[,]]$windowBuffer, [Double]$dt, [Double]$speed)
    {
        [Falling]::startLine -= [Falling]::kMeterToCellRatio * [Falling]::kStartLineVelocity * $speed * $dt
        foreach ($character in [Falling]::characters)
        {
            if ($character.y -gt [Falling]::startLine)
            {
                $character.Start()
            }
            $character.Update($speed * $dt)
        }

        $isAllFinished = $true
        foreach ($character in [Falling]::characters)
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

        foreach ($character in [Falling]::characters)
        {
            $character.Render($windowBuffer)
        }
        return $false
    }
}

class FallingCharacter : RenderItem
{
    $velocity = 0.0
    $mass = 1.0
    $startTime = 0
    $timer = 0
    $colorAnimation = $null
    $colorAnimStartTime = 0
    $isStarted = $false

    FallingCharacter($cell, $cellTrailing, $x, $y)
        : base($cell, $cellTrailing, $x, $y)
    {
        $this.startTime = [Falling]::kStartTime.Get()
        $this.mass = [Falling]::kMass.Get()

        $colorAnimDuration = [Falling]::kColorAnimDuration.Get()

        $this.colorAnimation = [LinearAnimation]::new(@(
            [System.ConsoleColor]::Blue,
            [System.ConsoleColor]::Blue,
            [System.ConsoleColor]::Blue,
            [System.ConsoleColor]::DarkBlue,
            [System.ConsoleColor]::Green
        ), $colorAnimDuration)

        $this.colorAnimStartTime = $this.startTime + [Falling]::kColorAnimStartTime
    }

    [void] Start()
    {
        $this.isStarted = $true
    }

    [void] Update($dt)
    {
        if (-not $this.isStarted)
        {
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

        $a = [Falling]::kGravity - ([Falling]::kDragCoef * $this.velocity / $this.mass)
        $this.velocity += $a * $dt
        $this.y += [Falling]::kMeterToCellRatio * $this.velocity * $dt

        if ($this.y -ge [Falling]::windowHeight)
        {
            $this.Finish()
        }

        if ($this.timer -gt $this.colorAnimStartTime)
        {
            $this.colorAnimation.Update($dt)
            $color = $this.colorAnimation.GetValue()

            $this.SetCell($null, $color, $null)
        }
    }
}
