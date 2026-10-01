# Hotel ESP — First Normal Working Prototype

Baseline commit: `029eef2e727b36bf71f056bc0cba690084c929d3`

This is the first normal working Hotel ESP prototype and must remain recoverable as the rollback baseline before later ESP fixes.

Baseline characteristics:
- Event-driven CurrentRooms / room / Drops / Backpack / Character tracking.
- Separate item rendering.
- No `workspace.HighlightModel` proxy system.
- MultiSelect Interactables and Items API preserved.
- Room/drop reconciliation separated so Key/Crucifix instances from different domains do not delete each other.

Do not rewrite or delete this baseline reference when continuing ESP development.
