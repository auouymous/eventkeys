#!/bin/sh

function make_texture(){
	TYPE=$1 ; shift
	NAME=$1 ; shift
	if [[ $1 =~ ^[0-9]+$ ]]; then FRAMES=$1; shift; else FRAMES=''; fi

	[ ! -z "$FRAMES" ] && I=".${TYPE}-${NAME}-0.xpm" || I=".${TYPE}-${NAME}.xpm"
	O="textures/eventkeys_${TYPE}_${NAME}.png"
	echo "[build] $O"
	convert $I -define png:exclude-chunks=date -strip $* $O

	if [ ! -z "$FRAMES" ]; then
		I=".${TYPE}-${NAME}-?.xpm"
		O="textures/eventkeys_${TYPE}_${NAME}_animated.png"
		echo "[build] $O"
		montage $I -define png:exclude-chunks=date -strip -mode concatenate -tile 1x$FRAMES $* $O
	fi
}

make_texture key disc
make_texture key gem
make_texture key key
make_texture key orb
make_texture key star

make_texture node S
make_texture node U-key 4 -blur 1x0.5
make_texture node U-prize 5 -blur 1x0.5
