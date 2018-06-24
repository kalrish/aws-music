mke2fs -v -t ext4 -I 128 -b 4096 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -- /dev/xvdf
mount /dev/xvdf /mnt
cd /mnt
mkdir {.overlayfs,builds}
cd builds
umount /dev/xvdf
