

## vim常用配置
```
" ----------------------------Vundle配置开始----------------------------
set nocompatible              " Vundle必须
filetype off                  " Vundle必须
" 设置运行时路径包含Vundle并且初始化
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Vundle管理vim插件配置，管理的插件必须在这里配置

" Vundle管理vim插件
Plugin 'VundleVim/Vundle.vim'

" NERDTree目录树工具
Plugin 'https://github.com/scrooloose/nerdtree.git'

" vim中的git插件
Plugin 'tpope/vim-fugitive'

call vundle#end()            " Vundle必须
filetype plugin indent on    " Vundle必须
" ----------------------------Vundle配置结束----------------------------


" ----------------------------普通配置开始，大部分不依赖任何插件----------------------------
" 设置行号
set number
" 突出显示当前行
set cursorline
" vim默认不启用鼠标，启用鼠标
set mouse=a
" 鼠标可以选中文本，并使用y复制、d剪切、p粘贴
set selection=exclusive
" 选中模式，鼠标和按键
set selectmode=mouse,key
" 设置自动缩进，每行的缩进与上一行相同
set autoindent
" 设置tab键宽4个空格
set tabstop=4
" 开启语法高亮
syntax enable
" vim命令使用tab自动补全
set wildmenu
" 文件自动更新
set autoread
" 自动打开NERDTree（目录树），该命令依赖于NERDTree插件
autocmd vimenter * NERDTree
" 使用9跳转到行尾，默认0跳转到行首
map 9 $
" ----------------------------普通配置结束，大部分不依赖任何插件----------------------------
```
