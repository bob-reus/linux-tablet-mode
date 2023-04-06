#!/bin/bash
# Auto rotate screen based on device orientation

# Screen orientation and launcher location is set based upon accelerometer position
# This script should be added to startup applications for the user

if [ -n "${DEBUG+set}" ]; then echo debug on; DEBUG=1; fi

### configuration
# find your Touchscreen and Touchpad device with `xinput`
TouchscreenDevice='ELAN9008:00 04F3:2E36'
TouchpadDevice='ASUE140D:00 04F3:31B9 Touchpad'
KeyboardDevice='AT Translated Set 2 keyboard'

# Virtual keyboard cmd command here. Suggestions:
# Cinnamon: "dbus-send --print-reply --dest=org.Cinnamon /org/Cinnamon org.Cinnamon.ToggleKeyboard"
# Onboard (dependency, install first): onboard
VirtualKeyboard='dbus-send --print-reply --dest=org.Cinnamon /org/Cinnamon org.Cinnamon.ToggleKeyboard'

### arguments
if [ "$1" == '-nosd' ]; then NOSD="true" ; fi

### functions
rotatescreen() {
  # Contributors: Ruben Barkow: https://gist.github.com/rubo77/daa262e0229f6e398766

  touchpadEnabled=$(xinput --list-props "$TouchpadDevice" | awk '/Device Enabled/{print $NF}')
  screenMatrix=$(xinput --list-props "$TouchscreenDevice" | awk '/Coordinate Transformation Matrix/{print $5$6$7$8$9$10$11$12$NF}')

  # Matrix for rotation
  # ⎡ 1 0 0 ⎤
  # ⎜ 0 1 0 ⎥
  # ⎣ 0 0 1 ⎦
  normal='1 0 0 0 1 0 0 0 1'
  normal_float='1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000'

  #⎡ -1  0 1 ⎤
  #⎜  0 -1 1 ⎥
  #⎣  0  0 1 ⎦
  inverted='-1 0 1 0 -1 1 0 0 1'
  inverted_float='-1.000000,0.000000,1.000000,0.000000,-1.000000,1.000000,0.000000,0.000000,1.000000'

  # 90° to the left
  # ⎡ 0 -1 1 ⎤
  # ⎜ 1  0 0 ⎥
  # ⎣ 0  0 1 ⎦
  left='0 -1 1 1 0 0 0 0 1'
  left_float='0.000000,-1.000000,1.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000'

  # 90° to the right
  #⎡  0 1 0 ⎤
  #⎜ -1 0 1 ⎥
  #⎣  0 0 1 ⎦
  right='0 1 0 -1 0 1 0 0 1'

  if [ "$1" == "-u" ]; then
    echo "Upside down"
    xrandr -o inverted
    xinput set-prop "$TouchscreenDevice" 'Coordinate Transformation Matrix' $inverted
    xinput disable "$TouchpadDevice"
    xinput disable "$KeyboardDevice"
    # if VirtualKeyboard isn't running and NOSD != true, start it
    if [[ "$NOSD" != "true" ]]; then
        [[ `pgrep $VirtualKeyboard` ]] || $VirtualKeyboard 2>/dev/null &
    fi
  elif [ "$1" == "-l" ]; then
    echo "90° to the left"
    xrandr -o left
    xinput set-prop "$TouchscreenDevice" 'Coordinate Transformation Matrix' $left
    xinput disable "$TouchpadDevice"
    xinput disable "$KeyboardDevice"
    if [[ "$NOSD" != "true" ]]; then
        [[ `pgrep $VirtualKeyboard` ]] || $VirtualKeyboard 2>/dev/null &
    fi
  elif [ "$1" == "-r" ]; then
    echo "90° right up"
    xrandr -o right
    xinput set-prop "$TouchscreenDevice" 'Coordinate Transformation Matrix' $right
    xinput disable "$TouchpadDevice"
    xinput disable "$KeyboardDevice"
    if [[ "$NOSD" != "true" ]]; then
        [[ `pgrep $VirtualKeyboard` ]] || $VirtualKeyboard 2>/dev/null &
    fi
  elif [ "$1" == "-n" ]; then
    echo "Back to normal"
    xrandr -o normal
    xinput set-prop "$TouchscreenDevice" 'Coordinate Transformation Matrix' $normal
    xinput enable "$TouchpadDevice"
    xinput enable "$KeyboardDevice"
    killall -q $VirtualKeyboard
  fi
}

### dependencies
( command -v monitor-sensor >/dev/null 2>&1 ) || { echo >&2 "$0 requires monitor-sensor but it's not installed.  Please install iio-sensor-proxy (https://github.com/hadess/iio-sensor-proxy)."; exit 1; }
( command -v xrandr >/dev/null 2>&1 ) || { echo >&2 "$0 requires xrandr but it's not installed. Aborting."; exit 1; }
# transparently disable onboard support if it's not installed
( command -v $VirtualKeyboard >/dev/null 2>&1 ) || { echo >&2 "Not using Virtual keyboard"; NOSD="true"; }

### main script

# check for running instance exit if exists
myname=$(basename $0)
runningPID=$(ps -ef | grep ".*bash.*$myname" | grep -v "grep \| $$" | awk '{print $2}')
if [[ $runningPID != "" ]] ; then
    echo $myname is already running with PID $runningPID
    exit
fi

killall -q -v monitor-sensor

LOG=/tmp/sensor.log
mkfifo $LOG
monitor-sensor > $LOG &

PID=$!
# kill monitor-sensor and rm log if this script exits
trap "[ ! -e /proc/$PID ] || kill $PID && rm -v $LOG" SIGHUP SIGINT SIGQUIT SIGTERM SIGPIPE
LASTORIENT='unset'

echo 'monitoring for screen rotation...'
while read -r; do
    line=$(echo "$REPLY" | sed -E  '/orient/!d;s/.*orient.*: ([a-z\-]*)\)??/\1/;' )
    # read a line from the pipe, set var if not whitespace
    [[ $line == *[^[:space:]]* ]] ||  continue
    ORIENT=$line
    if [[ "$ORIENT" != "$LASTORIENT" ]]; then
        echo "$LASTORIENT > $ORIENT"
        LASTORIENT=$ORIENT
        # Set the actions to be taken for each possible orientation
        case "$ORIENT" in
        normal)
          #rotatescreen -n;;
          if [ $DEBUG ]; then echo "normal" ;else rotatescreen -n; fi ;;
        bottom-up)
          if [ $DEBUG ]; then echo "up" ;else rotatescreen -u; fi ;;
          #rotatescreen -u;;
        right-up)
          if [ $DEBUG ]; then echo "right" ;else rotatescreen -r; fi ;;
          #rotatescreen -r;;
        left-up)
          if [ $DEBUG ]; then echo "left" ;else rotatescreen -l; fi ;;
          #rotatescreen -l;;
        esac
    fi
done < $LOG
