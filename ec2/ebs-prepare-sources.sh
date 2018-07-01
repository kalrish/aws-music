declare -r SOURCES_BUCKET="$1" VOLUME_NAME="$2" MOUNT_POINT='/mnt'
mke2fs -v -t ext4 -I 128 -b 4096 -m 0 -E lazy_itable_init=0,lazy_journal_init=0 -- "${VOLUME_NAME}"
mount -- "${VOLUME_NAME}" "${MOUNT_POINT}"
aws s3 cp --recursive --exclude '*' "s3://${SOURCES_BUCKET}" "${MOUNT_POINT}"
umount -- "${VOLUME_NAME}"
