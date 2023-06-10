function _gnuplot_install --on-event gnuplot_install
	# Set universal variables, create bindings, and other initialization logic.
	if not command --query gnuplot
		echo "gnuplot is not installed"
	end
end

function _gnuplot_update --on-event gnuplot_update
	# Migrate resources, print warnings, and other update logic.
	if not command --query gnuplot
		echo "gnuplot is not installed"
	end
end

function _gnuplot_uninstall --on-event gnuplot_uninstall
	# Erase "private" functions, variables, bindings, and other uninstall logic.
end

status is-interactive; or return

set -l reset (set_color normal)
set -l green (set_color green)
set -l yellow (set_color yellow)
set -l blue (set_color blue)


function _gnuplot_fish_get_terminal_dimensions

	# program taken from: https://sw.kovidgoyal.net/kitty/graphics-protocol/#getting-the-window-size
	set -l winsize_program '
	#include <stdio.h>
	#include <sys/ioctl.h>

	int main(int argc, char **argv) {
	struct winsize sz;
	ioctl(0, TIOCGWINSZ, &sz);
	printf("%i %i %i %i\n", sz.ws_row, sz.ws_col, sz.ws_xpixel, sz.ws_ypixel);
	return 0;
	}
	'

	set -l reset (set_color normal)
	set -l green (set_color green)

	if not test -f $__fish_user_data_dir/gnuplot/winsize.c
		mkdir -p $__fish_user_data_dir/gnuplot
		echo $winsize_program > $__fish_user_data_dir/gnuplot/winsize.c
	end

	if not test -f $__fish_user_data_dir/gnuplot/winsize
		printf "%s%s%s\n" $green "Compiling winsize.c" $reset
		gcc -o $__fish_user_data_dir/gnuplot/winsize $__fish_user_data_dir/gnuplot/winsize.c
	end

	# $__fish_user_data_dir/gnuplot/winsize | read -l number_of_rows number_of_columns screen_width_in_pixels screen_height_in_pixels
	$__fish_user_data_dir/gnuplot/winsize
end



# TODO: <kpbaks 2023-06-09 11:23:18> it should be possible to 'seq 100 | plot sin' and have it work
# When stdin is a pipe, and it has data, then ommit (x) in function calls and substitute with the data.
function plot
	# TODO: <kpbaks 2023-06-09 11:35:53> check if any of the arguments are readable files
	# Assume that each argument is a plot expression.
	# Go through each argument in argv. The first argument should be prepended with 'plot'.
	# The rest should be prepended with 'replot'.
	set -l options (fish_opt --short=h --long=help)
	if not argparse $options -- $argv
		return 1
	end
	if set --query _flag_help
		set -l usage "$(set_color --bold)Plot expressions and data files straight in the terminal with `gnuplot`$(set_color normal)

		$(set_color yellow)Usage:$(set_color normal) $(set_color blue)$(status current-command)$(set_color normal) [options]

		$(set_color yellow)Arguments:$(set_color normal)

		$(set_color yellow)Options:$(set_color normal)
		$(set_color green)-h$(set_color normal), $(set_color green)--help$(set_color normal)      Show this help message and exit

		"

		echo $usage
		return 0
	end
	set -l argc (count $argv)

	if test $argc -eq 0
		echo "No arguments given"
		return 1
	end

	set -l plot_commands
	if test -r $argv[1]
		set -a plot_commands "plot '$argv[1]'"
	else
		set -a plot_commands "plot $argv[1]"
	end
	for arg in $argv[2..-1]
		# set -a plot_commands "; replot $arg"
		if test -r $arg
			set -a plot_commands ", '$arg'"
		else
			set -a plot_commands ", $arg"
		end
	end

	set -l data
	# TODO: <kpbaks 2023-06-10 16:49:55> attempt to predict the shape of the data
	# e.g. how many columns, how many rows, etc.
	set -l data_piped_in 0
	# maybe save to temp file
	set -l f (mktemp)
	if not isatty stdin
		# echo "stdin is not a tty"
		set data_piped_in 1
		cat >$f
		# while read -l line
		#     set --append data "$line\n"
		# end
	end
	# echo -e $data >$f
	# plot $data

	_gnuplot_fish_get_terminal_dimensions | read -l number_of_rows number_of_columns screen_width_in_pixels screen_height_in_pixels
    
	set -l max_height 1000
	if test $screen_height_in_pixels -gt $max_height
		set screen_height_in_pixels $max_height
	end


	set -l font "Fira Code"
	set -l fontsize 12

	set -g _GNUPLOT_SIXELGD_OPTIONS "truecolor enhanced notransparent size $screen_width_in_pixels,$screen_height_in_pixels rounded font '$font,$fontsize' linewidth 2"


	set -g _GNUPLOT_TERM "set term sixelgd $_GNUPLOT_SIXELGD_OPTIONS"

	set -g _GNUPLOT_SETTINGS "set grid; unset border"


	# use '<cat' to read from stdin

	set -l expr "$_GNUPLOT_TERM; $_GNUPLOT_SETTINGS; $plot_commands"
	if test $data_piped_in -eq 1
		set -a expr ", '$f'"

	end
	echo "expr: $expr"
	gnuplot -e $expr
	# test -f $f; and rm $f
end
