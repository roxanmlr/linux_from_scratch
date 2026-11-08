_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FT_LINUX=/mnt/ft_linux
export LFS=$FT_LINUX
export LOOP=$(cat "$_DIR/.loopdev" 2>/dev/null || true)
umask 022

need_loop(){
	[ -n "$LOOP" ] && [ -b "$LOOP" ] || { echo "Loop non attaché, lance 01_loop_disk.sh"; exit 1; }
}
