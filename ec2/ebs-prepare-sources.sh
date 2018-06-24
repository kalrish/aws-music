mke2fs -v -t ext4 -I 128 -b 4096 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -- /dev/xvdf
mount -- /dev/xvdf /mnt
aws s3 cp --recursive "s3://$1" /mnt
umount -- /dev/xvdf
