<h1 align="center">Supply Crate</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=RUQLqKzN1yk"><img src="https://img.youtube.com/vi/RUQLqKzN1yk/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin adds a fully dynamic supply crate system to Counter-Strike 1.6.
Crates can be placed, managed and configured during gameplay with full runtime control over visibility, team access, spawn behavior and activation states.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove crates during gameplay via an in-game menu
- Multiple crate types: Ammo, Grenades, and Market Crates with individual models and features
- Players interact with crates by pressing E (+use) within a configurable distance range
- Configurable per crate: capacity, mode, cooldown, refill delay, team restriction, and weapon lists
- Bitflags-based mode selections for versatile ammo, armor, and grenade combinations
- Delayed and cyclic activation with random ranges and permanent activation support
- Breakable and explosive crates with custom health, damage stats, and debris gib mechanics
- Scaling mechanisms via specific factor settings for ammunition and market interaction limits
- Noclip and intuitive ghost preview tracking for natural alignment with grounds and walls

## 📋 Requirements
- ReGameDLL
- AMX Mod X 1.10+

## 💬 Commands
- `say /sc` - Opens the crates menu.
- `say_team /sc` - Opens the crates menu.
- `say /supplycrate` - Opens the crates menu.
- `say_team /supplycrate` - Opens the crates menu.
- `sc_reload` - Reloads the configuration file.
- `supplycrate_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# [Main Settings]
# SETTING_DEFAULT_MODEL           = Default crate model path
# SETTING_DEFAULT_GIB             = Default metal plate gibs model path
# SETTING_DEFAULT_CLASS           = Default class (0 - Ammo Crate, 1 - Grenades Crate, 2 - Market Crate)
# SETTING_DEFAULT_FLAGS           = Default flags (a - Breaks, b - Explodes, c - Refill, d - Active Delay, e - Active Permanent)
# SETTING_DEFAULT_TEAM            = Default team (0 - Disabled, 1 - Terrorist Only, 2 - CT Only, 3 - Both Teams)
# SETTING_DEFAULT_MODE            = Default bitflag modes (Vest, Vesthelm, Ammo, HE, FB1, FB2, Smoke)
# SETTING_DEFAULT_REFILL          = Default minimum and maximum refill delay (requires flag c)
# SETTING_DEFAULT_COOLDOWN        = Default delay in seconds between each use
# SETTING_DEFAULT_CAPACITY        = Default maximum supply amount a crate can give
# SETTING_DEFAULT_SPAWN_MODE      = Default spawn mode (0 - Never, 1 - Delayed, 2 - Round Start)
# SETTING_DEFAULT_SPAWN           = Default minimum and maximum spawn time
# SETTING_DEFAULT_SPAWN_CHANCE    = Default crate respawn probability (0.0 - 1.0)
# SETTING_DEFAULT_ACTIVE_DELAY    = Default activation delay after round start (min - max)
# SETTING_DEFAULT_ACTIVE_DURATION = Default active state duration (min - max)
# SETTING_DEFAULT_ACTIVE_COOLDOWN = Default cooldown before reactivation (min - max)
# SETTING_DEFAULT_HEALTH          = Default crate health range (min - max)
# SETTING_DEFAULT_ARMOR           = Default crate armor supply range (min - max)
# SETTING_DEFAULT_FACTOR          = Default scaling factor for market selling and ammo/grenades supplying
# SETTING_DEFAULT_FACTOR_MAX      = Default maximum supply factor limit for ammo crates
# SETTING_DEFAULT_EXPLODE_DAMAGE  = Default explosion damage range (min - max)
# SETTING_DEFAULT_EXPLODE_RADIUS  = Default explosion radius range (min - max)
# SETTING_DEFAULT_WEAPON_MODE     = Default weapon filtering (0 - Allow all, 1 - Allow listed, 2 - Block listed)
# Per-crate settings (defined under each [Crate Name] section):
# CRATE_FLAGS        = a - Breaks, b - Explodes, c - Refill, d - Active Delay, e - Active Permanent
# CRATE_CLASS        = 0 - Ammo Crate, 1 - Grenades Crate, 2 - Market Crate
# CRATE_TEAM         = 0 - Disabled, 1 - Terrorist Only, 2 - CT Only, 3 - Both Teams
# CRATE_SPAWN_MODE   = 0 - Never, 1 - Delayed, 2 - Round Start
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v2.0: Reworked for performance, enhanced map-alignment, added refill & damage break mechanics, introduced CRATE_FACTOR for ammo scaling.
* v2.1: Added team-restricted logic, built-in respawn chance mechanics for destroyed crates, and optimized map rendering.
* v2.2: Switched CRATE_MODE to multi-option Bitflags, added CRATE_FACTOR grenade scaling, and built CRATE_FACTOR_MAX limits.
* v2.3: Integrated weapon interaction filter lists, and automated manual precaching for breaking metal sounds and gib models.
* v2.4: Added FLAG_ACTIVE_PERMANENT flag option and improved round-start logic systems.
```

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=RUQLqKzN1yk)
