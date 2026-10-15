# Engine: terminal API, object properties and plugins

Status: draft, proposed. Part of the generic modular engine ([design](engine-modular-ai-first-diseno.md)). BGO is the first implementation ([BGO mobile profile](bgo-perfil-movil.md)).

## Terminal API

The terminal exposes the game as one tree called `g`, read like a path and changed with short verbs. It must be simple to type and guess. *(proposed)*

- **T1. Paths, not command names.** `g.match.players.seba.score` reads a value. `g.match.players.seba.score.add(5)` changes it. `g.components.boards.main.fixed.set(true)` sets a property. The space form also works: `g.components.boards.main.fixed.set true`.
- **T2. Reads are queries, verbs are commands.** A path alone never changes anything. Each verb (`set`, `add`, `move`, `lock`) turns into one canonical command, so replays, events, determinism and permissions work as they do for the UI and for AI.
- **T3. Same rules as everyone.** The terminal is not a back door. It runs as the host, so it can change `fixed`, but a player session in the terminal gets the player's permissions.
- **T4. Intellisense.** Tab completion and hints come from the schema, not from hand-written lists: component manifests (`component.jsonh`), the game definition, and the command catalog. Each node shows its type, allowed verbs, and a one-line help (`g.components.boards.main?`).
- **T5. One schema, three users.** The same schema feeds the terminal completion, the MCP tool list for AI, and the Studio cards, so the three never disagree.
- **T6. Stable names.** Paths use the ids from the game definition (`seba`, `main`), lowercase. If an id is ambiguous the terminal says so and lists the options instead of guessing.

Decided: only explicit verbs change state, never plain assignment (not `g.match.players.seba.score = 10`). Verbs are easier to complete, easier to log and map one to one to commands.

## Object properties: locked and fixed

- **P1. Locked.** Any interactive object has a public `locked` property, switched on and off by a command (for example `object.lock`). A locked object ignores a normal tap but still reacts to a long press, so the player can always unlock it or open its details. The lock command is not protected: the owner of the object can lock and unlock it, and so can anyone on an object marked public. A lock icon marks it, and a haptic cue confirms the change. *(proposed)*
- **P2. Fixed.** A `fixed` object can be interacted with but is never moved or picked up (card decks, dispensers, boards). It is set in the game definition. Only the host can change it, and only through the terminal; players and AI with player permissions cannot. `fixed` is different from `locked`: locked blocks taps and players can toggle it, fixed blocks moving and picking and players cannot toggle it. *(proposed)*
## Plugins: what we reuse

BGO already integrates 17 Godot addons (read from the `respaldo` branch). The rule is to reuse an addon before writing the same feature again, and to wrap each one behind a component contract so it can be replaced. *(proposed)*

| Addon | Version | Role in this spec | Use |
|---|---|---|---|
| `console` | 1.5.0 | Terminal (`~`). Base for the `g` tree (T1–T6) | Add schema-driven autocomplete (T4) |
| `G` autoload (own, `game_api.gd`) | n/a | Already exposes reads as deep copies and mutations only through `execute()` | Grow into the `g` tree; no new entry point |
| `godot_ai` | 3.2.4 | MCP server for AI (section on AI access) | Expose the same schema as MCP tools (T5) |
| `reactive_ui` (+ editor, analyzer) | 0.12.1 | React-style UI with hooks | Mobile profile screens: hand, filters, pickers |
| `spark` | 1.0.2 | Reactive state for UI | Bind UI to `locked`, `fixed`, layer and filter state |
| `gdss` | 0.7.0 | CSS-like theming | One theme per device profile |
| `properUI_drawer` | 1.0.0 | Slide-in drawers | Hand and filter panels on a small screen |
| `godotx_toast` | 2.0.0 | Toasts | Feedback for refused moves, lock changes |
| `lucide` | 1.1.0 | Icons | Lock, layer, hand icons |
| `bgo_component_browser` (own) | 0.1.0 | Lists component contracts and previews scenes | Seed of the Studio cards and the demo button |

**Candidates to evaluate (not verified yet):** listed in the Godot Asset Library on 2026-10-15. Compatibility with Godot 4.7 is still to be tested before adopting any of them. Each one is judged by one question: does it remove code we would otherwise write and test ourselves?

| Candidate | Asset Library entry | Fills this gap | Decision |
|---|---|---|---|
| Godot State Charts (derkork) | 0.22.5, updated 2026-06 | Turn and phase flow (FlowState, SessionState) as visual state machines that Studio can draw | Adopt from the start |
| GdUnit4 (NullPointer) | 5.0.3, updated 2025-06, tagged Godot 4.3 | Module validator tests, scene runner, CI reports | Adopt for new module tests; keep the home-made runner until migrated. Check 4.7 first |
| Phantom Camera (ramoks) | 0.11.0.3, updated 2026-07 | Fixed and floating cameras, orthographic top-down view, camera filters per profile | Adopt from the start, behind the camera component contract |
| netfox (elementbound) | 1.35.3, updated 2025-11 | Rollback networking for real-time games | Not now: board games are turn-based and use Firebase transport. Revisit for real-time or physics games |

**Gaps the addons do not cover:** the schema generator for autocomplete and MCP, the layer and grid enforcement, the module validators and the Studio itself.
