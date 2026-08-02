# FCPCommandConsole

Private local repository for a future Final Cut Pro command-console workflow.

This checkout currently contains only the Stage 1 repository/runtime skeleton and
the Stage 2 machine/reference audit. Product behavior, Final Cut Pro control,
media processing, and model execution are intentionally not implemented or
proven here.

Runtime output is kept outside Git at `~/Movies/FCPCommandConsole/` in the eight
directories listed in [STATUS.md](STATUS.md). The six repositories under
`reference/` are shallow, read-only audit snapshots; their exact commits and
licenses are recorded in [docs/REFERENCE_LOCK.json](docs/REFERENCE_LOCK.json).
