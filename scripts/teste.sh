
if [ "$1" = "up" ] ; then
	mount /dev/ad0s1a /var/mnt
	mount /dev/ad0s1d /var/mnt/tmp
	mount /dev/ad0s1e /var/mnt/usr
	mount /dev/ad0s1f /var/mnt/var
	mount /dev/ad0s1g /var/mnt/mosman
	mount -t cd9660 /dev/acd0 /var/mnt/cdrom
	mount -t devfs dev /var/mnt/dev
else
	umount /var/mnt/dev
	umount /var/mnt/cdrom
	umount /var/mnt/mosman
	umount /var/mnt/var
	umount /var/mnt/usr
	umount /var/mnt/tmp
	umount /var/mnt
fi


