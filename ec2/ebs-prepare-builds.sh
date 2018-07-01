declare -r VOLUME_NAME="$1" MOUNT_POINT='/mnt'
mke2fs -v -t ext4 -I 128 -b 4096 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -- "${VOLUME_NAME}"
mount -- "${VOLUME_NAME}" "${MOUNT_POINT}"
mkdir "${MOUNT_POINT}"/{.overlayfs,builds}
umount -- "${VOLUME_NAME}"
