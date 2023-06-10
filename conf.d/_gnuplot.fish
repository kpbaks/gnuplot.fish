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

set -l font "Fira Code"
set -l fontsize 12

set -g _GNUPLOT_SIXELGD_OPTIONS "truecolor enhanced notransparent size 800,600 rounded font 'Fira Code,12' linewidth 2"


set -g _GNUPLOT_TERM "set term sixelgd $_GNUPLOT_SIXELGD_OPTIONS"

set -g _GNUPLOT_SETTINGS "set grid"

# TODO: <kpbaks 2023-06-09 11:23:18> it should be possible to 'seq 100 | plot sin' and have it work
# When stdin is a pipe, and it has data, then ommit (x) in function calls and substitute with the data.
function plot
    set -l terminal_columns $COLUMNS
    set -l terminal_rows $LINES

    # TODO: <kpbaks 2023-06-10 16:58:23> figure out how to map the terminal size (COLUMNS, LINES) to the plot size. It is not 1 to 1.

    set -l data
    # TODO: <kpbaks 2023-06-10 16:49:55> attempt to predict the shape of the data
    # e.g. how many columns, how many rows, etc.
    if not isatty stdin
        while read -l line
            set --append data $line
        end
    end
    # maybe save to temp file
    set -l f (mktemp)
    echo $data >$f
    # plot $data

    # TODO: <kpbaks 2023-06-09 11:35:53> check if any of the arguments are readable files
    # Assume that each argument is a plot expression.
    # Go through each argument in argv. The first argument should be prepended with 'plot'.
    # The rest should be prepended with 'replot'.

    # use '<cat' to read from stdin

    set -l expr "$_GNUPLOT_TERM; $_GNUPLOT_SETTINGS; plot $argv"
    echo "expr: $expr"
    gnuplot -e $expr
    test -f $f; and rm $f
end
