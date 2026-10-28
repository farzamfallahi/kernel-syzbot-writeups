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
| patched | no lockdep splat | `logs/patched-*.log` |

## Caveat

On the patched kernel the ioctl never returns. A diagnostic run shows the task
self-deadlocked on one chunk-tree extent buffer while inserting the dev item.
The syzbot reproducer builds its btrfs image by hand, and my working
hypothesis is that the image does not account for its own chunk-tree block in
the extent tree, so the allocator hands that block out again. I have not
confirmed this, and I have not yet checked whether the unpatched kernel hangs
at the same point. Until I do, I am only claiming that the patch removes the
lockdep splat.

## Not done yet

- Control run of the hang on the unpatched kernel.
- Check lore and the btrfs/block trees for an existing fix.
- Submit to linux-btrfs.
