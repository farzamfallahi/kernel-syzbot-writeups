# Bug 2: possible deadlock in `set_blocksize` (btrfs)

syzbot extid `5c01398781fb51df783a`, reported on mainline `4169c9c90532`.

## Root cause (as I read it)

`set_blocksize()` now takes `inode_lock()` and `filemap_invalidate_lock()` on the
block device inode when the block size changes. `btrfs_init_new_device()` called it
while holding a transaction handle (after `btrfs_start_transaction()`), which puts
the bdev inode lock inside the `btrfs_trans_num_writers` / `extwriters`
pseudo-locks. Other paths (bdev reads under `inode_lock_shared`, then page faults
taking `mmap_lock`, then btrfs writers) establish the opposite order, so lockdep
reports a cycle.

## Candidate fix

`patches/0001-btrfs-set_blocksize-before-transaction.patch` moves the call before
the transaction is started (before the `fs_devices->seeding` block). Behaviour is
otherwise unchanged: the return value is ignored, as before.

## Results

| Kernel | Result | Log |
|--------|--------|-----|
| unpatched | lockdep splat at the ADD_DEV ioctl | `logs/control-unpatched-splat.log` |
| patched | no lockdep splat | `logs/patched-run.log` |

## Caveat

On the patched kernel the ioctl never returns. A diagnostic run
(`logs/patched-vm-patched-diag.log`) shows the task self-deadlocked on one
chunk-tree extent buffer, locked twice, while inserting the dev item.

The unpatched control kernel behaves the same way after printing the splat:
its log shows no output after the splat and a clocksource watchdog timeout at
166 s (`logs/control-unpatched-splat.log`), the same symptom as the patched
run (266 s). I did not capture a stack trace on the unpatched kernel, so I
cannot prove it is stuck at the identical point.

The syzbot reproducer builds its btrfs image by hand. My working hypothesis is
that the image does not account for its own chunk-tree block in the extent
tree, so the allocator hands that block out again. I have not confirmed this.

What I claim: the patch removes the lockdep splat. The hang appears to be
separate behaviour of the reproducer, not something the patch introduced.

## Not done yet

- Capture a stack trace of the hang on the unpatched kernel to confirm it is the same location.
- Check lore and the btrfs/block trees for an existing fix.
- Submit to linux-btrfs.
