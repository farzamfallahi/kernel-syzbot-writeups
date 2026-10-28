# Bug 1: possible deadlock in `__d_alloc_parallel`

syzbot extid `52aa59fd5e3cd8a19dd7`. Reproduced on unmodified linux-next 20261014
(`d419d682257d`).

## Root cause

A lockdep annotation for `DCACHE_PAR_LOOKUP` dentries uses one shared static lock
class. With stacking filesystems (overlayfs, ecryptfs) a lookup on an upper dentry
can nest inside a lookup on a lower one, so lockdep sees the same class acquired
recursively across layers and reports a false-positive cycle. `s_stack_depth`
(max `FILESYSTEM_MAX_STACK_DEPTH` = 2) bounds the real nesting.

## Candidate fixes tested

- `patches/0001-dcache-per-stack-depth-lock-class.patch` - my change: one lock class
  key per `s_stack_depth` in `fs/dcache.c`.
- `patches/0002-overlayfs-d_init-neil-sep30-diff.patch` - Neil Brown's overlayfs-only
  `d_init` diff from 30 Sep, for comparison.

## Results (same reproducer, same VM)

| Kernel | Result | Log |
|--------|--------|-----|
| unpatched | lockdep splat | `logs/control-unpatched-splat.log` |
| + 0001 | clean | `logs/dcache-patch-clean.log` |
| + 0002 | clean | `logs/neil-sep30-diff-clean.log` |

## Outcome

Neil Brown had already posted a formal 3-patch series on 2026-10-02
(`[PATCH 0/3] Fixes for dentry lockdep tracking on stacking filesystems`), so I did
not send a duplicate patch. The value here is the independent reproduction and
the test matrix above.
