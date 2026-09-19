# Andys Preview

A quality-of-life mod for Balatro that previews the score and money of a hand before you play it.

This is a fork of [Fantoms Preview](https://github.com/Fantom-Balatro/Fantoms-Preview) by Fantom and Divvy. It adds:

- A money preview next to the score preview
- Fixes to the money simulation
- Simulation only when you click the preview button or press `s`
- Crash safety, so a simulation error no longer takes the game down

## Install

1. Install [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector).
2. Download `Andys-Preview.zip` from the [latest release](../../releases/latest).
3. Extract it into your Balatro `Mods` folder.
4. Remove the original Fantoms Preview if you have it. Both mods share the same mod id and cannot run together.

## Releasing

Bump `version` in `FantomsPreview.json`, commit, then push a matching tag:

```
git tag v2.6.0
git push origin v2.6.0
```

The release workflow builds the zip and publishes the release.
