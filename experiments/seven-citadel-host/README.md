# Seven Citadel — hosted tabletop prototype

Static interactive tabletop controlled by a narrative host.

## Current goal

Keep the prototype deliberately simple while validating the interaction loop. Here.now hosts the complete playable static site, including bitmap assets, HTML Web Components and JSON state. GitHub is the recoverable source of truth for code, documentation and manifests.

## Architecture

- `sc-character-card`: reusable character sheet. Stats are rendered as d8 markers.
- `sc-event-card`: reusable narrative/event card. Layout, text and options are HTML; only `art` changes between cards.
- `sc-check-card`: reusable ability-check card with attribute, dice pool and difficulty.
- `sc-die`: reusable d8 Web Component backed by a bitmap sprite sheet. `await die.roll()` returns a value from 1 to 8.
- `sc-game-table`: board surface and slots. It never owns campaign narrative rules.
- `data/cards.json`: reusable card definitions and asset URLs.
- `data/state.json`: authoritative host state currently shown to the player.
- `.herenow/data.json`: Here.now Site Data schema for player actions.

## Asset strategy

Visual game art is bitmap (`.webp`/`.png`), not CSS/SVG illustration. HTML/CSS is responsible only for layout, typography, slots, overlays and interaction. For now assets live directly in Here.now because that is the fastest prototype path. The `art` fields accept normal relative paths or absolute URLs, so large-scale asset hosting can move later to object storage without changing the components.

Current expected assets:

- `assets/table.webp`
- `assets/mara_art.webp`
- `assets/refugio_art.webp`
- `assets/event_back.webp`
- `assets/d8_sprite.webp`

## Host loop

1. Host generates any new narrative bitmap in the agent environment.
2. Host updates `cards.json` / `state.json` and publishes the changed files to Here.now.
3. Browser polls host state every 3 seconds.
4. Player chooses an option or rolls an enabled check.
5. Browser POSTs the action to `./.herenow/data/actions` when Site Data is available.
6. Host resolves consequences and publishes the next state/card.

The player browser never advances the canonical narrative by itself.

## Scaling later

Do not build storage infrastructure until the prototype needs it. If asset volume becomes large, move only heavy immutable bitmaps to object storage/CDN and keep the same `art` URL contract. Components, schemas and game-state format should remain unchanged.
