# common

shared cross-host system defaults live here.

- keep this directory host-agnostic
- prefer changes here only when behavior truly belongs to every output
- if a change is linux-only or darwin-only, move it back to the host layer
- verify shared changes against the smallest affected outputs, not just one host
