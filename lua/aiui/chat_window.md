```mermaid
flowchart TD
    Init[Unmounted] -->|Open| Shown(shown)
    Shown -->|Open| Shown
    Shown -->|Close| Hidden(hidden)
    Hidden -->|Close| Hidden
    Hidden -->|Open| Shown```
