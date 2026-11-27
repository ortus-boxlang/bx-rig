# Wallpapers

One wallpaper per bundled theme, `<theme>.jpg`, and a collection of extra BxRig ones (`bxrig-tron`, `bxrig-neon`, `bxrig-city`, `bxrig-aurora`, `bxrig-orbit`, `bxrig-circuit`, `bxrig-rain`, `bxrig-waves`). All are 3840x2400 (16:10): a 16:9 screen crops a little off the top and bottom, a smaller one scales down sharply. `bxrig theme set NAME` switches to the wallpaper of the same name (`~/Pictures/BxRig/NAME.jpg`, written from the install bundle when missing); the extras sit in the same folder to pick by hand.

They are **drawn by code**, so they are crisp at any size and reproducible: `python3 tools/gen-wallpapers.py` (numpy and Pillow, a developer tool; the product has no Python). `python3 tools/gen-wallpapers.py bxrig nord` draws only those; `WP_SCALE=0.25 python3 tools/gen-wallpapers.py bxrig` writes a quarter size preview to `/tmp/shots`. Then run `bootstrap/gen-assets.sh`.

Each scene takes the colours of its theme (`themes/<name>/colors.toml`), or its own neon palette for the extras:

| Scene | What it is |
|---|---|
| horizon | a neon grid in perspective running to a sun, mountains, light trails (Tron) |
| city | a skyline in three layers with lit windows, a moon and fog |
| aurora | ridges under curtains of light, a mirror lake |
| orbit | a planet's limb with an atmosphere, stars, a nebula and a thin ring |
| circuit | glowing traces and vias in three depths of focus |
| rain | falling code in three depths |
| waves | stacked ridge lines, one per row |

`bxrig` and `bxrig-light`, and the extras marked with the wordmark, carry the **BxRig** block letters in the DOS Rebel font, the same ones the terminal shows (`bxrig ascii BxRig`), with no tagline.

| Theme | Scene |
|---|---|
| bxrig, bxrig-light | horizon with the wordmark |
| bxrig-cyan, bxrig-sky | horizon |
| bxrig-ember, bxrig-dawn, catppuccin-latte, tokyo-night | city |
| bxrig-forest, everforest, nord | aurora |
| bxrig-midnight | rain with the wordmark |
| bxrig-mint, bxrig-paper, kanagawa, rose-pine | waves |
| catppuccin | orbit |
| flexoki-light, gruvbox, matte-black | circuit |

## bxrig-retro

`bxrig-retro.jpg` (2560x1440) is original artwork drawn by `python3 tools/gen-retro-wallpaper.py` (Pillow): see that script.

## The accessible themes

`bxrig-contrast-dark.jpg`, `bxrig-contrast-light.jpg` and `bxrig-colorblind.jpg` (3840x2400) are drawn by `python3 tools/gen-contrast-wallpapers.py` (Pillow): the theme's background with one short accent line near the bottom, nothing that moves the eye. They stay plain on purpose.
