case `tty` in
	/dev/tty1)
		exec tmux new-session -A -s tty1 ;;
	/dev/tty2)
		exec ssh -t slartibartfast "tmux new-session -A -s lys" ;;
	/dev/tty3)
		exec ssh -t hornquist "tmux new-session -A -s srv" ;;
	/dev/tty6)
		startx ;;
esac

function __prompt_command() {
	PS1="`bat -s` [\w] \$ "
}

PS1='[\w] \$ '
