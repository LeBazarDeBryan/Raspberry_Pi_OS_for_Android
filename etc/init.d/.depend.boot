TARGETS = hostname.sh mountkernfs.sh mountdevsubfs.sh checkroot.sh checkfs.sh checkroot-bootclean.sh mountall.sh mountall-bootclean.sh bootmisc.sh
INTERACTIVE = checkroot.sh checkfs.sh
mountdevsubfs.sh: mountkernfs.sh
checkroot.sh: mountdevsubfs.sh hostname.sh
checkfs.sh: checkroot.sh
checkroot-bootclean.sh: checkroot.sh
mountall.sh: checkroot-bootclean.sh checkfs.sh
mountall-bootclean.sh: mountall.sh
bootmisc.sh: mountall-bootclean.sh checkroot-bootclean.sh
