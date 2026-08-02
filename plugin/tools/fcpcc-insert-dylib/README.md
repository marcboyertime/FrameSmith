# fcpcc-insert-dylib

`fcpcc-insert-dylib <mach-o-path> <load-path>` adds exactly one regular
`LC_LOAD_DYLIB` command to every slice in a thin or universal 64-bit Mach-O
file, only when the existing zero-filled header padding is large enough. It
does not grow, shift, remove, replace, or otherwise rewrite payload data.

The single accepted operation is intentional: the FCPCommandConsole patcher
uses it with a compile-time path to its one embedded framework. The patcher
never downloads or calls a cached helper. `UPSTREAM.json` records a pinned
reference commit for comparison only; this source is product-authored and is
licensed by the adjacent MIT file.
