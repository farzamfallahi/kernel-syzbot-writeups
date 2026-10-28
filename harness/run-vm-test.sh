#!/bin/sh
exec qemu-system-x86_64 \
  -accel kvm -cpu host -smp 4 -m 2G \
  -kernel ../build/arch/x86/boot/bzImage \
  -append "root=/dev/sda1 rootfstype=ext4 rw console=ttyS0 panic=-1 selinux=0 enforcing=0" \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file=disk.raw,format=raw,if=none,id=hd0,snapshot=on \
  -device scsi-hd,bus=scsi0.0,drive=hd0 \
  -nic none -nographic -no-reboot
