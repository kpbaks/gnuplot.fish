# inspiration:
# https://www.youtube.com/watch?v=F8tI02CsQ9A

set -g gnuplot_fish_data_dir $__fish_user_data_dir/gnuplot
# https://github.com/Gnuplotting/gnuplot-palettes
set -g gnuplot_fish_color_palettes \
    parula \
    blues \
    viridis

function _gnuplot_install_color_palettes
    set -l green (set_color green)
    set -l reset (set_color normal)

    test -d $__fish_user_data_dir/gnuplot/palettes; or mkdir -p $__fish_user_data_dir/gnuplot/palettes
    for palette in $gnuplot_fish_color_palettes
        set palette "$palette.pal"
        set -l url https://raw.githubusercontent.com/Gnuplotting/gnuplot-palettes/master/$palette
        set -l destination $__fish_user_data_dir/gnuplot/palettes/$palette
        if not test -f $destination
            printf "%s%s%s\n" $green "Downloading $palette" $reset
            curl -s $url >$destination
        end
    end
end

function _gnuplot_install --on-event gnuplot_install
    # Set universal variables, create bindings, and other initialization logic.
    if not command --query gnuplot
        echo "gnuplot is not installed"
    end

    _gnuplot_install_color_palettes
end

function _gnuplot_update --on-event gnuplot_update
    # Migrate resources, print warnings, and other update logic.
    if not command --query gnuplot
        echo "gnuplot is not installed"
    end

    _gnuplot_install_color_palettes
end

function _gnuplot_uninstall --on-event gnuplot_uninstall
    # Erase "private" functions, variables, bindings, and other uninstall logic.
end

status is-interactive; or return

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
    set -l source $__fish_user_data_dir/gnuplot/winsize.c
    set -l exe $__fish_user_data_dir/gnuplot/winsize

    if not test -f $source
        mkdir -p (path dirname $source)
        echo $winsize_program >$source
    end

    if not test -f $exe
        printf "%s%s%s\n" $green "compiling winsize.c" $reset
        command gcc -O3 -o $exe $source
    end

    $exe
end

set --query GNUPLOT_FISH_MAX_WIDTH; or set -g GNUPLOT_FISH_MAX_WIDTH 1600
set --query GNUPLOT_FISH_MAX_HEIGHT; or set -g GNUPLOT_FISH_MAX_HEIGHT 1000
set --query GNUPLOT_FISH_FONT; or set -g GNUPLOT_FISH_FONT sans
set --query GNUPLOT_FISH_FONTSIZE; or set -g GNUPLOT_FISH_FONTSIZE 12
set --query GNUPLOT_FISH_LINEWIDTH; or set -g GNUPLOT_FISH_LINEWIDTH 2
set --query GNUPLOT_FISH_SAMPLES; or set -g GNUPLOT_FISH_SAMPLES 1000

function _gnuplot_get_sixelgd_settings
    _gnuplot_fish_get_terminal_dimensions | read -l number_of_rows number_of_columns screen_width_in_pixels screen_height_in_pixels

    if test $screen_height_in_pixels -gt $GNUPLOT_FISH_MAX_HEIGHT
        set screen_height_in_pixels $GNUPLOT_FISH_MAX_HEIGHT
    end
    if test $screen_width_in_pixels -gt $GNUPLOT_FISH_MAX_WIDTH
        set screen_width_in_pixels $GNUPLOT_FISH_MAX_WIDTH
    end

    set -l sixelgd_settings "truecolor enhanced notransparent size $screen_width_in_pixels,$screen_height_in_pixels rounded font '$GNUPLOT_FISH_FONT,$GNUPLOT_FISH_FONTSIZE' linewidth $GNUPLOT_FISH_LINEWIDTH"

    echo $sixelgd_settings
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

    set -l settings

    for arg in $argv
        if test -r $arg
            if test (path extension $arg) = ".csv"
                set -a settings "set datafile separator ','"
            end
        end
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
    set -l max_width 1600
    if test $screen_height_in_pixels -gt $max_height
        set screen_height_in_pixels $max_height
    end
    if test $screen_width_in_pixels -gt $max_width
        set screen_width_in_pixels $max_width
    end


    set -l samples 10000

    set -l font sans
    set -l fontsize 12

    set -g _GNUPLOT_SIXELGD_OPTIONS "truecolor enhanced notransparent size $screen_width_in_pixels,$screen_height_in_pixels rounded font '$font,$fontsize' linewidth 2"

    set -l sixelgd_settings (_gnuplot_get_sixelgd_settings)


    set -g _GNUPLOT_TERM "set term sixelgd $_GNUPLOT_SIXELGD_OPTIONS"
    # set key spacing 3 font "Helvetica, 14"
    # set key box lt -1 lw 2
    set -l legend_settings "set key spacing 3 font '$font,14' box lt -1 lw 1"
    # set -l legend_settings "set key outside bottom center horizontal box lt -1 lw 1 spacing 2 font '$font,14'"
    set -l legend_settings "set key outside bottom center horizontal spacing 2 font '$font,14'"


    set -g _GNUPLOT_SETTINGS "$settings; set grid; unset border; set samples $samples; $legend_settings"


    # use '<cat' to read from stdin

    set -l expr "$_GNUPLOT_TERM; $_GNUPLOT_SETTINGS; $plot_commands"
    if test $data_piped_in -eq 1
        set -a expr ", '$f'"

    end
    echo "expr: $expr"
    gnuplot -e $expr
    # test -f $f; and rm $f
end

function splot --description "Create a 3D plot in the terminal with gnuplot"
    set -l options (fish_opt --short=h --long=help)
    set -a options (fish_opt --short=n --long=samples --required-val)
    set -a options (fish_opt --short=g --long=grid)
    set -a options (fish_opt --short=b --long=border)
    set -a options (fish_opt --short=l --long=legend)
    set -a options (fish_opt --short=v --long=verbose)

    if not argparse $options -- $argv
        return 1
    end
    set -l argc (count $argv)

    set -l samples $GNUPLOT_FISH_SAMPLES
    if set --query _flag_help
        set -l usage "$(set_color --bold)Create a 3D plot in the terminal with gnuplot$(set_color normal)

$(set_color yellow)Usage:$(set_color normal) $(set_color blue)$(status current-command)$(set_color normal) [options] expression | datafile [expression | datafile ...]

$(set_color yellow)Arguments:$(set_color normal)
	$(set_color blue)expression$(set_color normal)  A gnuplot expression e.g. 'sin(x)' 'x**2 + y**2'
	$(set_color blue)datafile$(set_color normal)    A path to a data file e.g. 'data.csv' 'data.dat'

$(set_color yellow)Options:$(set_color normal)
	$(set_color green)-h$(set_color normal), $(set_color green)--help$(set_color normal)      Show this help message and exit
	$(set_color green)-n$(set_color normal), $(set_color green)--samples$(set_color normal)   Number of samples to use for plotting (default: $samples)
	$(set_color green)-g$(set_color normal), $(set_color green)--grid$(set_color normal)      Show grid
	$(set_color green)-b$(set_color normal), $(set_color green)--border$(set_color normal)    Show border
	$(set_color green)-l$(set_color normal), $(set_color green)--legend$(set_color normal)    Show legend
	$(set_color green)-v$(set_color normal), $(set_color green)--verbose$(set_color normal)   Show verbose output

Part of https://github.com/kpbs5/gnuplot.fish"
        echo $usage
        return 0
    end

    if set --query _flag_samples
        set samples $_flag_samples
    end

    set -l sixelgd_settings (_gnuplot_get_sixelgd_settings)
    set -l settings "
set term sixelgd $sixelgd_settings;
set samples $samples;
set key outside bottom center horizontal spacing 2 font 'sans,14';
load '$gnuplot_fish_data_dir/palettes/parula.pal'
    "

    if set --query _flag_grid
        set -a settings "; set grid"
    end
    if not set --query _flag_border
        set -a settings "; unset border"
    end
    if not set --query _flag_legend
        set -a settings "; unset key"
    end

    set -l plot_commands
    set -l a_csv_file_is_given 0
    for arg in $argv
        if test -r $arg
            if test (path extension $arg) = ".csv" -a $a_csv_file_is_given -eq 0
                set -a settings "; set datafile separator ','"
                set a_csv_file_is_given 1
            end
            set -a plot_commands "'$arg'"
        else
            set -a plot_commands "$arg"
        end
    end

    set plot_commands (string join ", " $plot_commands)
    set -l splot_expr "splot $plot_commands"
    # set -l

    set -l expr "$settings; $splot_expr"
    if set --query _flag_verbose
        if command --query bat
            echo $expr | bat -l gnuplot
        else
            echo "expr: $expr"
        end
    end
    gnuplot -e $expr
end
