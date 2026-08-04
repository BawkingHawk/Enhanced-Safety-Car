# Enhanced Safety Car

**v1.0** for Assetto Corsa (offline races) with Custom Shaders Patch

Assetto Corsa never shipped real rolling starts. Races just launch from a frozen grid, and mods that add a safety car usually feel robotic: the field trails behind in a dead-straight line, nobody warms their tires, and one mistake scatters the pack. **Enhanced Safety Car** turns the pre-race moments into the part of the show they're supposed to be: a safety car pulls away, the field snakes and weaves behind it like a real grid keeping heat in the rubber, stragglers hurry back into formation, and the whole train packs up tight before surging across the line at the green. Add the included Mercedes-AMG safety car to your grid, and everything else takes care of itself, on any track, with zero setup.

Built on the *Safety Car - FCY - Yellow Flag - Rolling Start* app by **Nary**, with a heavily reworked AI behaviour layer, fully automatic safety car placement, and an audio spotter that keeps you in position.

---

## Features

- **Zero setup.** The safety car places itself correctly on any track. No spawn points to record, no per-track configuration.
- **A formation lap that feels real.** The AI field warms tires with natural side-to-side weaving, eases off for corners, holds proper spacing in the train, and forms up cleanly before a rolling green flag.
- **Good manners built in.** The field remembers the starting order: anyone who gains a spot by accident gives it back, stragglers catch up progressively, and nobody wipes out doing it.
- **An audio spotter keeps you honest.** Fall too far back or get ahead of your grid slot and the app tells you, then confirms once you've fixed it. Stay in position and it stays quiet.
- **Live tuning.** A Tuning tab in the app window lets you adjust the weaving, spacing, and catch-up behaviour on the fly, and remembers your settings.
- **Race control.** Full Course Yellow and yellow-flag cautions with mid-race safety car deployments, optional penalties for jumping the start, and a diagnostic log if you ever want to know what happened behind the scenes.
- **Everything included.** The safety car, its F1-style livery, and the flashing light setup ship in this package. Nothing extra to download.

## Requirements

- [Custom Shaders Patch](https://acstuff.club/patch/) v0.2.0 or newer (v0.3.x recommended)
- [Content Manager](https://assettocorsa.club/content-manager.html)

## Installation

1. Drop the `apps` and `content` folders into your Assetto Corsa root folder (merge/overwrite when asked):
   `...\steamapps\common\assettocorsa\`
2. Enable the app in Content Manager:
   **Settings → Assetto Corsa → Apps → Safety-Car-FCY-Yellow-Flag-Rolling-Start**
3. First time on each track: open the app window in-session, press **Enable Track Physics**, then restart the session from Content Manager.

## Usage

1. Set up an offline **race** session and include the Mercedes (`F1_Safety_Car` skin) in the grid. It renames itself **SAFETY CAR** and places itself automatically.
2. Keep the app window open during the session. It is the flag panel and the brain of the formation logic.
3. Hold your position, warm your tires, and form up when the field packs together. The race goes green as the leader takes the line; the safety car peels into the pits before the start.

---

## Credits

| Contribution | Author |
|---|---|
| Original *Safety Car - FCY - Yellow Flag - Rolling Start* app | **Nary** - [patreon.com/AssettoCorsaRacingCarsMods](https://www.patreon.com/AssettoCorsaRacingCarsMods) |
| Mercedes-AMG GT Black Series car model | **B. Gili (MNBA Modding Group)** - [gumroad](https://xchxexitus.gumroad.com/) |
| *Safety Car - Mercedes AMG GT Black Series* addon (safety car model additions & code) | **Schwepsou** - overtake.gg |
| F1 Safety Car livery | **shadow118** |
| Enhanced AI formation behaviour, automatic SC placement, position coach, tuning UI, chain following, catch-up logic, swap recovery, restart handling, always-on light configuration | **BawkingHawk** |

## Legal & disclaimer

- **This is a free, non-commercial fan project.** It may not be sold, monetized, or placed behind any paywall, in whole or in part.
- **All original works remain the property of their creators.** The base app belongs to Nary, the car model to B. Gili (MNBA Modding Group), the safety car addon to Schwepsou, and the livery to shadow118. This package only builds on their work and claims no ownership of it.
- **Credits must stay intact.** If you share, mirror, or modify this package, keep the credits table above unchanged and visible.
- **No affiliation.** This project is not affiliated with, endorsed by, or sponsored by Mercedes-Benz AG, the FIA, Formula 1, Kunos Simulazioni, or any of the credited creators. All trademarks and brand names belong to their respective owners and appear only for descriptive purposes.
- **No warranty.** Provided as-is, without warranty of any kind. Use at your own risk.

> **Note before redistributing:** this package contains the full car by B. Gili (MNBA Modding Group) and the safety car addon by Schwepsou, not just a config tweak, on top of Nary's app. Before uploading it anywhere public, ask Nary (app), MNBA (car) and Schwepsou (addon) for permission to redistribute.
