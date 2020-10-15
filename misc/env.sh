echo 'Make sure you run this script using `source ...`.'

WINEPATH="$(realpath "$(dirname "$BASH_SOURCE")"/../root/mingw64/bin)"
echo 'Your WINEPATH is now equal to `'"$WINEPATH"'`.'
test -z "$WINEPATH" && return
export WINEPATH

PATH="$(make -f "$(dirname "$BASH_SOURCE")/helpers/AddToPath.mk" "dir=$WINEPATH")"
test -z "$PATH" && return
export PATH
echo 'Your PATH is now equal to `'"$PATH"'`.'
