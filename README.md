# Andys Preview

A quality-of-life mod for Balatro that previews the score and money of a hand before you play it.

This is a fork of [Fantoms Preview](https://github.com/Fantom-Balatro/Fantoms-Preview) by Fantom and Divvy, based on its v2.5.0 release.

## Changes compared to Fantoms Preview

### Money preview

The original had its money preview disabled in the code. This fork brings it back.

- The money a hand will earn shows on its own line under the score preview.
- It shows a single value like `+$3`, or a `min - max` range when the result depends on chance.
- Gains are coloured gold, losses red, and no change grey.
- The HUD stays the same height. The room comes from trimming empty space around the hand name.
- It can be turned off in the mod settings.

### Faster, on-demand simulation

- The simulation runs only when you click Calculate Score or press `s`.
- The original re-ran the full simulation on every card selection, reorder, consumable use, and joker sale. Those actions now only hide the outdated preview.
- The 5 second wait after clicking Calculate Score is gone. The result shows immediately.
- A per-discard reset that caused noticeable lag is removed.

### Simulation fixes

- **Matador** now pays out on scoring hands when the boss blind triggered, such as The Arm, The Ox, The Flint, or debuffed scoring cards. It no longer pays out for The Hook or The Tooth.
- **The Hook** now simulates exactly the discards the game makes. Mail-In Rebate, Trading Card, and Green Joker react to those discards, and state no longer leaks between simulated discards.
- **Mail-In Rebate** and **Hit the Road** compared a card field that does not exist, so they never matched. They now check the rank correctly.
- The simulation no longer changes the real blind's triggered flag.

### Crash safety

- Every entry point runs through an error guard: the simulation, preview texts, HUD setup, the button, the keybind, and the per-frame hooks.
- An error is logged once with an `[AndysPreview]` prefix instead of crashing the game.
- A failed simulation restores the game state and shows an unknown preview.
- If the HUD setup fails, you get the regular game HUD without the preview.

### Project

- Renamed to Andys Preview. The internal mod id is still `FantomsPreview`, so existing settings carry over.
- Releases are automated with a release script and a GitHub Actions workflow.
## Install

1. Install [Steamodded](https://github.com/Steamodded/smods) and [Lovely](https://github.com/ethangreen-dev/lovely-injector).
2. Download `Andys-Preview.zip` from the [latest release](../../releases/latest).
3. Extract it into your Balatro `Mods` folder.
4. Remove the original Fantoms Preview if you have it. Both mods share the same mod id and cannot run together.

## Releasing

Run the release script from the repo root on a clean, up to date `main`:

```
bash release.sh patch
```

Use `minor`, `major`, or an explicit version like `3.0.0` instead of `patch`. Add `--dry-run` to see the new version without changing anything.

The script bumps `version` in `FantomsPreview.json`, commits, tags, and pushes. The release workflow then builds the zip and publishes the release.
