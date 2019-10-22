#!/bin/sh

function make_key(){
	I=".key-$1.xpm"
	O="textures/eventkeys_key_$1.png"
	if [ "$I" -nt "$O" ]; then
		echo "[build] $O"
		convert $I $O
	fi
}
make_key disc
make_key gem
make_key key
make_key orb
make_key star
