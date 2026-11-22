# Wallpapers

One wallpaper per bundled theme: `<theme>.jpg`, 2560x1440. `bxrig theme set NAME` switches to the wallpaper of the same name (`~/Pictures/BxRig/NAME.jpg`, written from the binary when missing).

`bxrig.jpg` and `bxrig-light.jpg` carry the name and the one-liner; the others are artwork only. Made with Canva's AI design generator (2026-11-15), exported as PNG and saved as JPEG (quality 84). To replace one, keep the file name; `bootstrap/gen-assets.sh` embeds whatever is here.

| Theme | Canva design |
|---|---|
| bxrig | DAHa_0RuWp0 |
| bxrig-cyan | DAHbAD1t77Q |
| bxrig-dawn | DAHbACA4fIY |
| bxrig-ember | DAHbAA83-cc |
| bxrig-forest | DAHbAA_fneM |
| bxrig-light | DAHbAFitexE |
| bxrig-midnight | DAHbAOkl8fA |
| bxrig-mint | DAHbADiVdzI |
| bxrig-paper | DAHbAA8lrhM |
| bxrig-retro | drawn by `tools/gen-retro-wallpaper.py` (see below) |
| bxrig-sky | DAHbAF7Vljw |
| catppuccin | DAHbAPNK5zQ |
| catppuccin-latte | DAHbAJaCAxM |
| everforest | DAHbAJXboCM |
| flexoki-light | DAHbACj1rZE |
| gruvbox | DAHbAPbesE0 |
| kanagawa | DAHbAGYMKLU |
| matte-black | DAHbACioPvk |
| nord | DAHbAB0DpHU |
| rose-pine | DAHbADGQd2c |
| tokyo-night | DAHbANhqOnE |

## bxrig-retro

`bxrig-retro.jpg` (2560x1440, JPEG quality 84, about 0.8 MB) is not a Canva design: it is original artwork made for BxRig and drawn by `python3 tools/gen-retro-wallpaper.py` (Pillow), so it is reproducible and the licence is the repository's own. It follows the Retro design: a sliced sunset sun, neon mountains, a perspective grid, stars and scanlines, in the palette of `themes/bxrig-retro/colors.toml`. Change the script and run it again, then `bootstrap/gen-assets.sh` to refresh the hash.

## The accessible themes

`bxrig-contrast-dark.jpg`, `bxrig-contrast-light.jpg` and `bxrig-colorblind.jpg` (2560x1440) are drawn by `python3 tools/gen-contrast-wallpapers.py` (Pillow): the theme's background with one short accent line near the bottom. They are plain on purpose, so text and the pointer stay easy to see. Change the script and run it again, then `bootstrap/gen-assets.sh`.
