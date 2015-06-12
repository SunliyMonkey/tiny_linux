ramdisk_dir="../ramdisk"
initrd_dir="../initrd"
initrd="$initrd_dir/initramfs.cpio.gz"


cd $ramdisk_dir

find . -print0 | cpio --null -ov --format=newc | gzip -9 > $initrd 

echo "create initrd: $initrd"




