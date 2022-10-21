<div align="center">

# FancyClearHost

[![GitHub license](https://img.shields.io/github/license/mdgrs-mei/FancyClearHost)](https://github.com/mdgrs-mei/FancyClearHost/blob/main/LICENSE)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/p/FancyClearHost)](https://www.powershellgallery.com/packages/FancyClearHost)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/FancyClearHost)](https://www.powershellgallery.com/packages/FancyClearHost)

[![Pester Test](https://github.com/mdgrs-mei/FancyClearHost/actions/workflows/pester-test.yml/badge.svg)](https://github.com/mdgrs-mei/FancyClearHost/actions/workflows/pester-test.yml)

Clears your PowerShell host in a fancy way.

https://user-images.githubusercontent.com/81177095/194883476-fed364b3-a641-4626-8a6a-0743d8b6f5b1.mp4

</div>

*FancyClearHost* provides you with the ability to clear the PowerShell host display with some cool text animations. Unlike any other PowerShell modules, it doesn't give you any useful features but you should be able to surprise your colleagues or audiences when you give a demo! 

## Requirements

This module has been tested on:

- Windows 10 and 11 
- Windows PowerShell 5.1 and PowerShell 7.2

## Installation

*FancyClearHost* is available on the PowerShell Gallery. You can install the module with the following command:

```powershell
Install-Module -Name FancyClearHost -Scope CurrentUser
```

## Usage

Just call `Clear-HostFancily` function to play random animations, and type 'q' to quit.

```powershell
Clear-HostFancily
```

You can play a specific animation by adding `Mode` parameter and control the speed by `Speed` paramerter.

```powershell
Clear-HostFancily -Mode Falling -Speed 0.5
```

## Overwriting `cls` alias

By adding the following code to your PowerShell profile, you can overwrite the `cls` alias with a fancy version.

```powershell
function FancyClear
{
    # You can set whatever parameters you want here
    Clear-HostFancily -Mode Falling -Speed 3.0
}
Set-Alias -Name cls FancyClear -Option AllScope
```
