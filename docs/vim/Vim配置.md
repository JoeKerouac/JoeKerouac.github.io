## vim常用命令
### 窗口相关
| 命令 | 说明 |
| --- | --- |
| ctrl + w + s | 水平切分窗口 |
| ctrl + w + v | 垂直切分窗口 |
| ctrl + w + c | 关闭活动窗口 |
| :q | 关闭活动窗口 |
| ctrl + w + o | 关闭其他窗口 |
| :on | 关闭其他窗口 |
| ctrl + w + h | 向左切换窗口 |
| ctrl + w + l | 向右切换窗口 |
| ctrl + w + j | 向下切换窗口 |
| ctrl + w + k | 向上切换窗口 |
| ctrl + w + _ | 最大化活动窗口高度 |
| ctrl + w + &#124; | 最大化活动窗口宽度 |

### 编辑相关（命令模式）
| 命令 | 说明 |
| --- | --- |
| p | 粘贴，将复制的内容粘贴到当前行下一行 |
| y | 复制选中区域 |
| yy | 复制当前行 |
| [n]yy | 从当前行向下复制n行 |
| y$ | 复制当前光标到行尾内容（包含光标下的内容） |
| y^ | 复制当前光标到行起始内容（不包含光标下的内容） |
| e/E | 移动光标到当前单词结尾，大小写区别是E会忽略标点，例如I'm，e会当成两个单子，E则会认为这是一个单词 |
| w/W | 移动光标到下个单词开头 |
| b/B | 移动光标到当前单词开头 |
| d | 剪切，所有操作和y命令一致 |
| x | 删除当前光标下的一个字符 |
| u | 撤销 |
| v | 开始选中，可以使用上下左右移动选中区域，相当于在普通编辑器中按shift然后按上下左右选中，不同的是这个只需要按一次就可进入选中模式，而普通编辑器要按着shift不放 |
| h | 左移 |
| l | 右移 |
| j | 下移 |
| k | 上移 |


## vim好用的插件
### ctags
可以让vim拥有跳转源码的功能，使用说明：
- 首先在服务器安装ctags，安装命令：`yum install ctags -y`；
- 然后跳转到源码目录，例如Linux内核源码目录，执行`ctags -R`生成索引，这时会在该目录生成一个名叫`tags`的目录，将该目录配置到`~/.vimrc`文
件中，配置方式：`set tags=${刚才那个tags目录}`；

这样就配置好了，可以在vim中使用`ctrl+]`快捷键进入源码，然后使用`ctrl+T`退出；


还可以在vim中使用命令`:ts`列出指定函数的所有定义（应该是不支持只能检测，所以有可能进错），然后可以自己选择合适的源码进入；


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

" ----------------------------插件配置开始，依赖相关插件----------------------------
" 自动打开NERDTree（目录树），该命令依赖于NERDTree插件
autocmd vimenter * NERDTree
" ----------------------------插件配置开始，依赖相关插件----------------------------


" ----------------------------普通配置开始，不依赖任何插件----------------------------
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
" 使用9跳转到行尾，默认0跳转到行首
map 9 $
" 设置在右下角显示输入的命令
set showcmd

" 输入的时候对(进行映射，输入(后会自动补全)并且将光标置于两个括号之间，下同或类似
imap ( ()<Esc>i
imap { {}<Esc>i
imap [ []<Esc>i

" 这里因为前后符号相同会导致递归，需要用inoremap防止递归
inoremap " ""<Esc>i
inoremap ' ''<Esc>i

" Java常用，因为上边定义好了自动补全括号和引号，所以这里不需要输入后括号和引号
imap psvm public static void main(String[<Esc>la args<Esc>la{<CR><CR><Esc>ki<Tab><Tab>
imap sout System.out.println(<Esc>la;<Esc>hi
" ----------------------------普通配置结束，不依赖任何插件----------------------------
```
