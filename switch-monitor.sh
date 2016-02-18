#!/bin/bash
#
# Aero-snap behaviour
# Verical maximized
# half of the monitor witdh
# forked from:
# https://github.com/ntowbinj/switch-monitor
#
# This is based loosely on a script available here:
#
# http://makandracards.com/makandra/12447-how-to-move-a-window-to-the-next-monitor-on-xfce-xubuntu
#
# Which was in turn based on one available here:
#
# http://icyrock.com/blog/2012/05/xubuntu-moving-windows-between-monitors/
#
# Neither of which worked quite right with fullscreen (distinct from maximized) windows
#
# Unfortunately it *is* necessary to remove the fullscreen property before moving.  For some reason,
# not doing so can lead to a window switching back to its original monitor after alt+tab is pressed.
# Fortunately it can then be restored, but this leads to a visually unappealing move


# since cut indexes from 1, pretty much everything in this script will too
function index {
    echo `echo $1 | cut -d"$2" -f$3`
}


# get monitor dimension information from monitors listed as 'connected' by xrandr
# if for whatever reason this doesn't work, you can manually set widths and offsets.
# if your screens (left to right) have widths W1, W2, W3,
# then you would set widths to "W1 W2 W3" and offsets to "0 W1 W2"
widths=""
heights=""
offsets=""
monitor_count=0
while read -r line
do
    info=`echo $line | sed -n 's/.* \([0-9]*x[0-9]*+[0-9]*+[0-9]*\).*/\1/p'`
    widths="$widths $(index $info 'x' 1)"
    heights="$heights $(index $(index $info 'x' 2) '+' 1)"
    offsets="$offsets $(index $info '+' 2)"
    ((monitor_count++))
done < <(xrandr --current | grep ' connected')


# put them in left-right order--computationally inefficient selection sort, but you probably don't have 100000 monitors
start=0
ordered_widths=""
ordered_heights=""
ordered_offsets=""
for i in $(seq 1 $monitor_count)
do
    for j in $(seq 1 $monitor_count)
    do
        width=$(index "$widths" " " $j)
        height=$(index "$heights" " " $j)
        offset=$(index "$offsets" " " $j)
        if [ $offset -eq $start ]
        then
            ordered_widths="$ordered_widths $width"
            ordered_heights="$ordered_heights $height"
            ordered_offsets="$ordered_offsets $offset"
            start=`expr $start + $width`
        fi
    done
done
widths=$ordered_widths
heights=$ordered_heights
offsets=$ordered_offsets

# store the windows maximized/fullscreen state information and undo all of it
pattern='horz|vert|full'
window_id=`xdotool getactivewindow`
window_states=`xprop -id $window_id _NET_WM_STATE | sed 's/,//g' | cut -d ' ' -f3-`
remember_states=""
for state in $window_states
do
    #remove _NET_WM_STATE_ prefix
    state=`echo $state | sed -r 's/^.{14}//' | awk '{print tolower($0)}'`
    #echo $w
    if [[ $state =~ $pattern ]]
    then
        wmctrl -ir $window_id -b remove,$state
        remember_states="$remember_states $state"
    fi
done


# get position of upper-left corner
specs=`xwininfo -id $window_id`
x=`echo "$specs" | awk '/Absolute upper-left X:/ { print $4 }'`
y=`echo "$specs" | awk '/Absolute upper-left Y:/ { print $4 }'`
window_width=`echo "$specs" | awk '/Width:/ { print $2 }'`
window_height=`echo "$specs" | awk '/Height:/ { print $2 }'`


# get the current monitor of the window, indexed from 1
current_monitor=0
for i in $(seq 1 $monitor_count)
do
    width=$(index "$widths" " " $i)
    start=$(index "$offsets" " " $i)
    end=`expr $start + $width`
    if [ $x -ge $start ] && [ $x -lt $end ]
    then
        current_monitor=$i
    fi
done


# remember, monitors are indexed from 1, not 0, so this works
shift_by=1
numre='^-?[0-9]+$'
if [ $# -gt 0 ] && [[ $1 =~ $nume ]]; then shift_by=$1; fi
next_monitor=`expr $current_monitor + $shift_by`
((next_monitor--))
next_monitor=`expr $next_monitor % $monitor_count`
while [ $next_monitor -lt 0 ] # since expr's modulus can give negative results
do
    next_monitor=`expr $next_monitor + $monitor_count`
done
((next_monitor++))

# Get x of the half of the monitor of the current monitor
half_witdh_current=0
for i in $(seq 1 ${current_monitor}); do
    full_width_monitor=$(index "$widths" " " $i)
    half_width_monitor=$((full_width_monitor/2))
    if [[ $i -eq ${current_monitor} ]]; then
        half_width_current=$((half_width_current+half_width_monitor))
    else
        half_width_current=$((half_width_current+full_width_monitor))
    fi
done

# Get the direction of movemnt
if [[ $1 -ge 0 ]] && [[ -z $1 ]]; then
    direction=right;
    #if you move to right and you are on left side of monitor
    #do not switch the monitor
    if [[ $x -lt $half_width_current ]]; then
        next_monitor=$current_monitor;
    fi
else
    direction=left;
    #if you move to left and you are on right side of monitor
    #do not switch the monitor
    if [[ $x -ge $half_width_current ]]; then
        next_monitor=$current_monitor;
    fi
fi



# compute new absolute x,y position based on relative positions and offsets
current_offset=$(index "$offsets" " " $current_monitor)
next_offset=$(index "$offsets" " " $next_monitor)

current_width=$(index "$widths" " " $current_monitor)
current_height=$(index "$heights" " " $current_monitor)

next_width=$(index "$widths" " " $next_monitor)
next_height=$(index "$heights" " " $next_monitor)

# Change get next x for half of the next monitor
if [[ $next_monitor -eq $current_monitor ]]; then
    #if you move to the right
    # the offset will be the half of the monitor offset
    if [[ $direction == "right" ]]; then
        new_x=$half_width_current
    fi
    # if you move to the left
    # the offset will be monitor offset (0)
    if [[ $direction == "left" ]]; then
        new_x=$next_offset
    fi
else
    # if you change monitors and move to right
    # the offset will ve the new monitor offset (0)
    if [[ $direction == "right" ]]; then
        new_x=$next_offset
    fi
    # if you change monitor and move to left
    # the offset will be the next offset plus
    # and the half of the width of the next monitor
    if [[ $direction == "left" ]]; then
        new_x=$((next_offset+next_width/2))
    fi
fi
# x_rel=`expr $x - $current_offset`
# new_x=`expr $x_rel + $next_offset`
echo "next x: $new_x"
echo "windows prev $x"
echo $current_monitor
echo $next_monitor

#resize=0

if [ $next_width -lt $window_width ]
then
#    resize=1
    window_width=`expr $next_width - 30`
fi
if [ $next_height -lt $window_height ]
then
#    resize=1
    window_height=`expr $next_height - 30`
fi

#Resize as halt of the widht of the monitor
resize=1
next_width=$(index "$widths" " " $next_monitor)
window_width=$((next_width/2))

if [ $resize -eq 1 ]; then xdotool windowsize $window_id $window_width $window_height; fi


# move the window to the same relative x,y position in the other monitor
xdotool windowmove $window_id $new_x $y

#Force vertical max
wmctrl -ir $window_id -b add,maximized_vert

# restore maximized/fullscreen state
exit
# for w in $remember_states
# do
#     if [[ $w != "maximized_horz" ]]; then
#         wmctrl -ir $window_id -b add,$w
#     fi
# done

# exit
