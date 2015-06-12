bzImage_dir=../bzImages
initrd=../initrd/initramfs.cpio.gz

if [ "$1" == "" ]; then 
   echo "No bzImage!"
   exit 
fi

bzImage="$bzImage_dir/$1"

#set the mode of qemu

flags='-append "console=ttyS0" -nographic'

if [ "$2" != "" ]; then 
   flags=""
fi

 
qemu-system-x86_64 -kernel "$bzImage" -initrd "$initrd"  $flags 
