# BGO mobile interaction profile

Status: draft, proposed. Written 2026-10-13. Generic parts (terminal API, `locked`/`fixed`, plugins) live in [engine-terminal-api-y-plugins.md](engine-terminal-api-y-plugins.md). Move this file into the BGO repo when it becomes code.

## Goal and scope

The phone is a controller with a private view, not a copy of the table. The TV or PC shows the whole table; the phone shows your hand, your pieces and the actions you can take now. Everything below exists to make a small screen safe to use on a table with many parts.

- **Scope.** Match mode. The free sandbox stays on tablet, PC and TV.
- **One path.** Every phone interaction ends in a canonical command. The phone never changes state any other way.
- **Tags.** Rules the author described are plain. Rules marked *(proposed)* are suggestions to confirm.

## Camera

The camera floats above the table at a fixed height and angle, and the player only moves it sideways, like a helicopter.

- **C1.** Two-finger drag pans the camera over the table. Height and pitch never change (in the 2D view this is a plain top-down pan).
- **C2.** *(proposed)* Zoom has a few fixed levels (overview, play, close) instead of free pinch.
- **C3.** *(proposed)* Quick jump: tapping a named area or a mini-map moves the camera there. Long panning across a big table is where this will hurt first.
- **C4.** *(proposed)* Optional center reticle: whatever is under the middle of the screen is the target, so a finger never covers it.

## Mobile 2D view

The phone shows the table as a 2D top-down view instead of 3D. It stays fast with hundreds of objects, and layers are easier to read from above.

- **V1.** The phone profile renders a top-down 2D view. The 3D view stays for TV and PC.
- **V2.** Grid cells are rectangles and layers are draw order. A tap resolves by cell lookup, with no 3D ray.
- **V3.** The view reads only semantic state (cell, layer, owner, id), so it stays independent of how things are drawn.
- **V4.** The 2D view is built in Godot (2D nodes, same components, same commands). There is no separate web client.
- **V5.** *(proposed)* The default 2D look can come from an orthographic top-down camera (no perspective) over the same 3D scene.
- **V6.** Things that are hard to tell apart from above, such as miniatures, get a 2D portrait (a round avatar) as their top-down look. A top-down render of a miniature is confusing.
- **V7.** *(proposed)* The portrait is generated per miniature, ideally by the asset pipeline when the model is imported.
- **V8.** Boards, cards and tiles need no second image, because they are already flat images.
- **V9.** *(proposed)* A component's manifest declares how it draws in 2D: its own image, a portrait, or a top-down render.

Godot draws the 2D view itself, so components, sessions and commands carry over unchanged. The 2D view is a second render of the same scene, like a 2D video game.

## Grid rule

Every game declares one grid of fixed size, and each object occupies a cell, so nothing overlaps freely. In a real board game pieces can sit very close or on top of each other, which makes stacks that are hard to touch. The grid removes that mess on purpose.

- **G1.** The game definition declares the grid (columns × rows) and the cell size. It is mandatory in the phone profile.
- **G2.** An object's position is a cell, not free coordinates. Slots, boards and areas align to cells.
- **G3.** No free overlap. Each layer holds one object per cell (see Layers); anything beyond that follows a declared stack rule (open question).
- **G4.** A tap resolves to a cell first, then to an object in that cell.
- **G5.** *(proposed)* The player can focus on one grid region at a time, and only that region responds to taps.

BGO already has a grid component (`bgo.table.grid`). Check whether it can become the mandatory, per-game grid with cell occupancy.

## Layers

The table has three or four depth layers, so things that move at different rates never mix. A card dropped on top of other things sits on a higher layer and stays separate from what is below it.

| Layer | What lives there | How it is used | Examples |
|---|---|---|---|
| Bottom | Things that naturally sit on the table | Placed once, not moved during the game | Boards, tiles |
| Middle | Things that are not moved often | Moved now and then | Miniatures, props, scenography |
| Top | Working items | Put on the table at the start of your turn and picked up at the end | Dice, cards |
| Overlay (optional) | Cosmetic things on top of the rest | Never moved; fades or turns opaque by condition | The roof of a house, lighting |

- **L1.** Each object belongs to one layer, set by its component or by the game definition. A layer follows how an object is used, not only what it is.
- **L2.** Layers work independently: each can be shown, faded or made inactive on its own.
- **L3.** *(proposed)* A cell holds one object per layer, so the grid rule applies per layer.
- **L4.** *(proposed)* On your turn the filter defaults to the top layer and your own objects. Lower layers are dimmed and inactive, but the player can switch one on to inspect or move something.
- **L5.** *(proposed)* Resolution order for a tap: grid cell, then eligible layers, then owner, then object.

- **L6.** The game definition assigns layers. Components carry a default layer (boards on the bottom, scenography in the middle) and a game definition can override it per object type.
- **L7.** An object never changes layer during the game.
- **L8.** The overlay layer is cosmetic and not interactive. It fades or turns opaque under declared conditions, for example when a piece is inside the house.

The current filter code only knows owner and type. I did not check whether anything like layers exists elsewhere.

## Hand: pick and drop modes

The hand has two modes, only one active at a time, so no drag and drop is needed.

- **H1.** Pick mode: tapping a pickable object sends it to the hand.
- **H2.** Drop mode: tapping a valid target moves the top object of the hand there. Keep tapping to place the next one.
- **H3.** The hand is a stack. The player can reorder it at any time, so the order of drops is chosen before dropping. Reordering your own hand already works (`object.reorder_in_hand`).
- **H4.** Targets are slots: conceptual places on boards or other components. Each slot accepts only certain kinds of object, configurable per slot.
- **H5.** *(proposed)* The active mode is always obvious (color, icon, a haptic cue), with a large cancel button. Drop mode ends by itself when the hand is empty.
- **H6.** *(proposed)* Bulk helpers: "drop to next free slot", "drop all into this area", and undo for the last drop.

## Filter: only mine

A view filter makes everything that is not yours semi-transparent and inactive, so a tap can only reach your own things.

- **F1.** The phone profile starts with "only mine" on. One toggle turns it off.
- **F2.** Filtered objects fade (or hide, by setting) and ignore taps and rays.
- **F3.** *(proposed)* The filter covers slots and boards too, not only pieces.
- **F4.** *(proposed)* It follows the hand mode automatically. In pick mode only your pickable objects respond. In drop mode only slots that accept the top object respond, and the rest dim.
- **F5.** The owner and type checkboxes stay available for advanced use.

- **F6.** *(proposed)* The filter also works by layer, combined with owner. The three filters (owner, layer, grid region) are independent and can be mixed.

## Selecting without mistakes

The grid and the filter together make most taps unambiguous. The grid narrows a tap to one cell, the filter removes everything in that cell that is not eligible, and usually zero or one object is left.

1. The tap lands on a cell.
2. The filter removes objects that are not eligible for the current mode.
3. One object left: act on it.
4. Several left: open a list with large tap targets.
5. None left: nothing happens, with a small visual cue.

- **S1.** *(proposed)* A small movement threshold separates a tap from a pan, so panning never selects.

- **S2.** *(proposed)* On your turn only the right pieces respond: your objects on the active layer. Outside your turn nothing is movable; reordering your own hand and inspecting objects stay available.

- **S3. Locked.** Any interactive object has a public `locked` property, switched on and off by a command (for example `object.lock`). A locked object ignores a normal tap but still reacts to a long press, so the player can always unlock it or open its details. The lock command is not protected: the owner of the object can lock and unlock it, and so can anyone on an object marked public. A lock icon marks it, and a haptic cue confirms the change. *(proposed)*

- **S4. Fixed.** A `fixed` object can be interacted with but is never moved or picked up (card decks, dispensers, boards). It is set in the game definition. Only the host can change it, and only through the terminal; players and AI with player permissions cannot. `fixed` is different from `locked`: locked blocks taps and players can toggle it, fixed blocks moving and picking and players cannot toggle it. *(proposed)*

## Profiles by device

Each game and component declares how much freedom it allows on each device. The phone is the strictest.

| Device | Camera | Interaction | Grid | Filter default | Free sandbox |
|---|---|---|---|---|---|
| Phone | 2D top-down view, two-finger pan | Pick and drop modes, tap to select, legal targets only | Mandatory | Only mine, on | No |
| Tablet | Same as phone, free zoom allowed | Phone modes plus free drag | Mandatory | Only mine, on | No |
| PC or TV | Free camera | Free drag and full table view | Mandatory | Off | Optional, for authoring |

## What exists today and what is missing

Most pieces exist in some form; the gaps are the grid rule, the one-tap filter and the link between filter and hand mode. Checked by reading the public `respaldo` branch on 2026-10-13, without running it.

| Item | Status | Note |
|---|---|---|
| FILTER button with owner and type checkboxes | Exists | `src/ui/camera_filter_controller.gd` |
| Fade and deactivate filtered pieces | Exists | Faded material, collision layer set to zero |
| Filter covers slots and boards | Missing | Pieces only |
| One-tap "only mine" | Missing | Owners are ticked by hand |
| Hide option (not only fade) | Missing |  |
| Filter follows the hand mode | Missing |  |
| Filter as a component with manifest and tests | Missing | Lives in `src/ui` |
| Hand with modes | Partial | The vertical hand has a mode switch; check how close it is to pick and drop |
| Reorder own hand at any time | Exists | `object.reorder_in_hand` |
| Move from hand or player area to the table by command | Exists | `object.move` accepts those origins |
| Grid component | Exists | `bgo.table.grid`; not yet mandatory per game, no cell occupancy rule |
| Fixed-height mobile camera | Partial | Mobile render profile uses fixed pitch; the two-finger pan needs checking |

## AI access through MCP

The AI plays and fixes the table through MCP with the same commands and permissions as a person, so every part of this profile needs a command-level form.

- **A1.** Every phone interaction ends in a canonical command, and the AI uses that command directly. Modes, taps and long presses exist only on the phone; the AI never imitates them.
- **A2.** The AI reads semantic state (cells, layers, owners, ids), never screen positions. It sees the same filtered state as a player in the same seat.
- **A3.** *(proposed)* Queries to support: list objects by cell, layer or owner; list the legal targets for an object; read a hand; read lock state.
- **A4.** Each component describes itself for the AI: what it is, its layer, the commands it accepts, and the kinds each slot accepts. The existing component descriptions and the `agent_visible` config are the base.
- **A5.** The AI has owner permissions for its own seat. It acts as host only when it is given the host permission.
- **A6.** *(proposed)* Portraits and 2D images carry readable names, so the AI and the 2D view agree on which miniature is which.

## Privacy and rules enforcement

The filter is a convenience, not security. Commands enforce ownership and turns, so a filtered-out object still cannot be moved illegally.

- **P1.** Private information (other players' hands, hidden objects) is removed from the data before it reaches the phone. Hiding it in the view is never enough.
- **P2.** Filter state is local to the client and never changes the game state.

- **P3.** Only the owner can move or interact with an object. Other players can inspect it but not change it.
- **P4.** The host (the game manager) can touch and modify anything, or fix the table, through commands that require the host permission.

## Tests and success measures

The profile is accepted when a full game is playable on a phone-size window and the headless tests below pass.

- **T1.** Play one real game start to finish in a 390 × 844 window and count the taps per move. Set the target after the first measurement.
- **T2.** Count mis-taps (a tap that reaches an unintended object). With the filter on, this should be near zero.
- **T3.** Headless tests: a filtered object ignores taps and rays; turning the filter off restores look and interaction; drop mode highlights only slots that accept the top object; the grid refuses a second object in a cell unless the stack rule allows it.
- **T4.** A full turn can be played with one thumb.

## Open questions

- [ ] Who sets the grid size and cell size per game, and can a large object span several cells?
- [ ] Stack rule: what happens when several objects must share a cell (a deck, a pile of tokens)?
- [ ] Hand order: is the next object to drop the first one in or the last one in?
- [ ] Is "focus one grid region at a time" a toggle the player controls, or does it follow the camera?
- [ ] Fade or hide as the phone default?
- [ ] Does the tablet profile allow free drag?
- [ ] Should the filter live in a component or in a core service?

- [ ] Lock: it is a public property changed by a command, so it is a shared game state. Decided: the command is unprotected, so the owner can always change it and anyone can on public objects.
- [ ] Overlay: which conditions make it fade or turn opaque, and how are they declared?
- [ ] Portraits: generated automatically by the asset pipeline, or supplied by the game author?
- [ ] AI seat: can the AI play as a regular player with owner permissions only, and when does it act as host?

## Implementation order

Start with the grid rule, because the filter and the selection flow both depend on it.

1. Add the grid declaration to the game definition and check that `bgo.table.grid` fits.
2. Add the one-tap "only mine" toggle and add a layer property to components and games, and extend the filter to layers, slots and boards.
3. Connect the hand modes to the filter (pick mode and drop mode rules).
4. Build the 2D top-down phone view with pan and quick jump, as a spike in Godot 2D first.
5. Extract the filter into a component with a manifest, a `MODULE.md` and tests.
6. Add a phone-size option to the Studio demo button, then measure taps per move.

## BGO-specific addons

| Addon | Role | Use |
|---|---|---|
| `dice_roller` | 3D dice box | Dice component (top layer) |
| `lente` | Photo mode | Table photos, camera effects |
| `ambientcg`, `blendkit`, `asset_placer` | Materials and models, placement in the editor | Luxury table assets |
| `JsonhGd`, `tnowe_extra_controls`, `TexturedGlassMaterialPack-4` | JSONH parser, extra controls, glass materials | Keep as is |
