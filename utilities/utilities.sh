die() {
  echo "$@"
  exit 1
}


ask() {
  prompt="$1"
  varname="$2"
  default="$3"

  if [ -n "$non_interactive" ]; then
    [ -z "$(eval echo "\$$varname")" ] && eval "$varname=$default"
    [ -z "$(eval echo "\$$varname")" ] && die "Need to supply $varname!"
  else
    [ -n "$default" ] && guess=" [$default]"
    while [ -z "$(eval echo "\$$varname")" ]; do
      echo -n "$prompt$guess "
      read "$varname"
      [ -z "$(eval echo "\$$varname")" ] && eval "$varname=$default"
    done
  fi
}


require() {
  for i in "$@"; do
    eval "val=\$$i"
    if [ -z "$val" ]; then
      echo "Need to supply variable $i to $0!"
      exit 10
    fi
  done
}


# digs through its parameters looking for the nth one that isn't
# an argument (i.e. not '-r' or '--recursive')
parameter() {
  skip="$1"
  shift

  for val in "$@"; do
    # if this arg doesn't being with a dash
    if [ "${val#-}" = "$val" ]; then
      # and we've skipped the right number of non-dashes
      if [ "$((skip -= 1))" -le 0 ]; then
        # then this is the arg we're looking for
        echo "$val"
        return
      fi
    fi
  done
}


# we use debian names internally: i686 and amd64.
# guess_arch returns the correct names even when run on Fedora.
guess_arch() {
  case "$(arch)" in
    x86_64 ) echo amd64     ;;
    i386   ) echo i686      ;;
    *      ) echo "$(arch)" ;;
  esac
}


# Creates a file with the contents given on stdin
create() {
  echo "- creating $1:"
  cat > "$1"
  cat "$1" | sed -e "s/^/  $INDENT/"
}


# Patches a file with the contents given on stdin.
# The patch should use absolute paths.

patch_file() {
  patch="$(tempfile -p patch)" || die "could not create tempfile"
  cat > "$patch"
  echo "- Using this patchfile:"
  cat "$patch" | sed 's/^/    /'
  run patch --directory="$1" -p1 < "$patch"
  ret="$?"
  rm "$patch"
  if [ "$ret" -ne "0" ]; then
    echo "Exiting because patch failed: $ret"
    exit "$ret"
  fi
}


# runs the given command, indenting its stdout,
# and exiting if it returns a bad status code.
# example: run echo hi -> "  hi"

run() {
  echo "- \$ $@"
  dir="$(mktemp -d)"
  fifo="$dir/fifo"
  mkfifo -m 600 "$fifo"
  sed --unbuffered -e "s/^/  $INDENT/" < "$fifo" &
  INDENT="  $INDENT" "$@" > "$fifo"
  ret="$?"
  rm -rf "$dir"
  if [ "$ret" -ne "0" ]; then
    echo "Exiting due to nonzero error code: $ret"
    exit "$ret"
  fi
}

