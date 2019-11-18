#!/bin/bash -e

VIMRC="$HOME/.vimrc"

BASE_DIR="$HOME/work/zctags"

echo_red()   { printf "\033[1;31m$*\033[m\n"; }
echo_green() { printf "\033[1;32m$*\033[m\n"; }
echo_blue()  { printf "\033[1;34m$*\033[m\n"; }

[ -d "$BASE_DIR" ] || {
	echo_red "'$BASE_DIR' does not exit"
	exit 1
}

#echo "colorscheme torte" > $VIMRC
echo "syntax on" > $VIMRC
echo "set nobackup" >> $VIMRC
echo "set hlsearch" >> $VIMRC
echo "set tabstop=8 softtabstop=8 shiftwidth=8 noexpandtab" >> $VIMRC
echo "filetype indent on" >> $VIMRC

echo >> $VIMRC
echo >> $VIMRC

echo "autocmd BufRead,BufNewFile COMMIT_EDITMSG,*.patch setl textwidth=75" >> $VIMRC
#echo "autocmd BufRead,BufNewFile COMMIT_EDITMSG,*.patch match WhitespaceEOL /\%>75v.\+/" >> $VIMRC
echo "autocmd Filetype gitcommit setlocal spell" >> $VIMRC

echo >> $VIMRC
echo >> $VIMRC

rm -f $BASE_DIR/*-tags
for dir in $BASE_DIR/* ; do
	ctags -R -o "${dir}-tags" "$dir"
	echo "set tags+=${dir}-tags" >> $VIMRC
done

