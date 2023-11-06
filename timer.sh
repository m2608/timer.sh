#!/bin/sh

# Requirements: 
# figlet - ascii fonts
#
# Optional:
# mpv    - audio player
# lolcat - colors
# dzen2  - notifier

# figlet font, eg: basic, fraktur, jazmine, stampatello, univers
font="fraktur_mono"

# audio file to play at the end
alarm="$HOME/Alarms/Industrial alarm.mp3"

# audio player
player="mpv --no-terminal"

# notifier
notifier="dzen2 -p 5 -bg red -fg black -fn 'Terminus:size=13' -tw 160 -x 0 -y 0"
message="Time is up"

# additional filter
filter=lolcat

# maximum possible terminal width
max_cols=999

if [ "$1" == "--help" ]; then
    echo "Usage: $0 [<time in minutes>]"
    exit 1
fi

# sigterm received (^C): show cursor, clear screen, disable alternative
# buffer and exit
trap "printf '[?25h[2J[?1049l' ; exit 0" INT

# terminal size changed: clear screen
trap "printf '[2J'" WINCH

get_text_cols()
# returns number of columns in text
# usage: get_text_cols "some multiline text"
{
    # count number of cols in figlet output
    text_cols=0
    for line in $1; do
        if test $text_cols -lt ${#line}; then
            text_cols=${#line}
        fi
    done

    echo $text_cols 
}

get_text_rows()
# return number rows in text
# usage: get_text_rows "some multiline text"
{
    text_rows=0
    for line in $1; do
        text_rows=$(( text_rows + 1 ))
    done

    echo $text_rows
}

center_text()
# centers text
# usage: center_text "some multiline text" cols
{
    text=$1
    rows=$2
    cols=$3

    text_cols=`get_text_cols "$text"`
    text_rows=`get_text_rows "$text"`

    output=""

    # fill left of the line with spaces to center numbers and
    # right side of the line to clear screen
    fill_left=$(( (cols - text_cols) / 2 + 1 ))
    fill_right=$(( cols - text_cols - fill_left ))

    for line in $text; do
        output=`printf "%s\n%*s%s%*s" "$output" $fill_left "" "$line" $fill_right ""`
    done

    # count rows to print before (to center text vertically) and
    # after text (to clear screen).
    pref=$(( (rows - text_rows) / 2 ))
    post=$(( rows - text_rows - pref - 1 ))

    output_pref=""
    for i in `seq $pref`; do
        output_pref=`printf "%s%*s\n" "$output_pref" $cols ""`
    done

    output_post=""
    for i in `seq $post`; do
        output_post=`printf "%s%*s\n" "$output_post" $cols ""`
    done

    printf "[H%s%s%s" "$output_pref" "$output" "$output_post"
}

show_time()
# show_time <full|auto> hours minutes seconds
{
    cols=`stty size | cut -d' ' -f2`
    rows=`stty size | cut -d' ' -f1`

    IFS=$'\n'

    if test $1 = "full"; then
        # full mode, always show hours, minutes and seconds
        text_raw=`printf "%02d:%02d:%02d" $2 $3 $4`

        text=`echo "$text_raw" | figlet -m -1 -f $font -w $max_cols`
        text_cols=`get_text_cols "$text"`

        if test $text_cols -gt $cols; then
            text_raw=`printf "%02d:%02d" $2 $3`
            text=`echo "$text_raw" | figlet -m -1 -f $font -w $max_cols`
        fi
    else
        # auto mode, do not show hours if there are none
        if test $2 -eq 0; then
            text_raw=`printf "%02d:%02d"         $3 $4`
        else
            text_raw=`printf "%02d:%02d:%02d" $2 $3 $4`
        fi
        text=`printf "%s" "$text_raw" | figlet -m -1 -f $font -w $max_cols`
    fi

    # count number of cols in figlet output
    text_cols=`get_text_cols "$text"`

    # count number rows in figlet output
    text_rows=`get_text_rows "$text"`

    if test $text_cols -gt $cols -o $text_rows -gt $rows; then
        text="$text_raw"
    fi

    output=`center_text "$text" $rows $cols`

    if test -n "$filter"; then
        printf "%s" "$output" | /bin/sh -c "$filter"
    else
        printf "%s" "$output"
    fi
}

# enable alternative buffer, clear screen, hide cursor
printf "[?1049h[2J[?25l"

if [ "$1" == "" ]; then
    # no arguments, show clock

    while true; do
        # date without leading zeroes 
        rest=`date "+%-H:%-M:%-S"`
        h="${rest%%:*}"
        rest="${rest#*:}"
        m="${rest%%:*}"
        rest="${rest#*:}"
        s="${rest%%:*}"

        show_time "full" $h $m $s

        sleep 0.1
    done
else
    # argument present, show timer

    # convert time to seconds
    period=$1
    period=$(( period * 60 ))
    
    # get current timestamp
    timestamp=`date +%s`
    timefinish=$(( timestamp + period ))
    
    prev_time=0
    while true; do
        time=$(( timefinish - timestamp ))
    
        # redraw screen only if time changed
        if test $prev_time -ne $time; then
            prev_time=$time
    
            h=$(( time / 3600 ))
            m=$(( (time % 3600 ) / 60 ))
            s=$(( time % 60 ))
    
            show_time "auto" $h $m $s
        fi
    
        if test $timestamp -ge $timefinish; then
            break
        fi
    
        sleep 0.1
        timestamp=`date +%s`
    done

    if test -n "$notifier" -a -n "$message"; then
        echo $message | /bin/sh -c "$notifier" &
    fi

    if test -n "$player" -a -n "$alarm"; then
        /bin/sh -c "$player '$alarm'"
    fi
fi

# show cursor, clear screen, disable alternative buffer
printf '[?25h[2J[?1049l'
