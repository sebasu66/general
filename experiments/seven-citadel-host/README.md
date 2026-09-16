# Seven Citadel — hosted tabletop prototype

Static interactive tabletop controlled by a narrative host.

## Architecture

- `sc-character-card`: reusable character sheet. Stats are rendered as d8 markers.
- `sc-event-card`: reusable narrative/event card. Only its data and optional `art` change.
- `sc-check-card`: reusable ability-check card with attribute, dice pool and difficulty.
- `sc-die`: reusable d8 Web Component. `await die.roll()` returns a value from 1 to 8.
- `sc-game-table`: board surface and slots. It never owns campaign narrative rules.
- `data/cards.json`: reusable card definitions.
- `data/state.json`: authoritative host state currently shown to the player.
- `.herenow/data.json`: Here.now Site Data schema for player actions.

## Host loop

1. Host publishes `state.json` and any new card/art asset.
2. Browser polls the host state every 3 seconds.
3. Player chooses an option or rolls an enabled check.
4. Browser POSTs the action to `./.herenow/data/actions`.
5. Host reads the latest action, resolves consequences and commits the next state/card.
6. Here.now is updated and the already-open table changes automatically.

The player browser never advances the canonical narrative by itself.
