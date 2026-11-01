# Artwork attribution and source notes

WordSprout's illustrated English word pack includes:

- **Twemoji SVG artwork:** [jdecked/twemoji](https://github.com/jdecked/twemoji), Copyright Twitter and other contributors, used under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/). Illustrations retain their original SVG markup; `scripts/build_assets.py` retrieves an individually named source SVG for each chosen Unicode emoji.
- **WordSprout original vector illustrations:** A-letter starter assets (`ant.svg`, `apple.svg`, `arm.svg`, `axe.svg`, `arrow.svg`), plus the custom subjects generated in `scripts/build_assets.py`: igloo, iron, queen, quilt, quail, quill, ukulele, xylophone, yak, zipper, zoo, and zigzag.
- **Garden background:** `assets/scene/alphabet_garden.svg`, custom WordSprout illustration.

The script writes `assets/content/artwork_manifest.json` identifying illustration source, path and SHA-256 hash. Bundled SVGs are displayed locally through flutter_svg. Artwork completeness does not establish independent factual or child-development review. The app must retain these credits when distributed.
