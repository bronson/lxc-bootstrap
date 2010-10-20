# Creates the rootfs directory and sets up logging for the run command.
# Pass name of the VM as a parameter, it sets the path and rootfs vars.
# Make sure to call stop_image when you're done.

start_image()
{
  name="$1"
  [ -z "$name" ] && die "You must pass a name to start_image!"

  [ "$(id -u)" != "0" ] && die "You must be root!"

  export PATH="$PWD/utilities:$PATH"

  [ -e "$name" ] && die "$name already exists!"
  [ -e "$name-partial" ] && run rm -rf "$name-partial"

  path="$name"-partial

  run mkdir "$path"
  rootfs="$path/rootfs"

  # Log output to a file and to the console
  echo "Creating $name on $(date)" > "$path/create.log"
  mkfifo -m 600 "$path/log.fifo"
  tee -a "$path/create.log" < "$path/log.fifo" &
  exec 1> "$path/log.fifo"
}


# Renames the machine image and turns off logging.
# Requires the path and name variables to be set
stop_image()
{
  run mv "$path" "$name"
  rm "$name/log.fifo"

  echo "done.  new machine is in $name"
  exec 1>&-   # doesn't seem to sort buffering issues, not sure why
  sleep 0.1   # quick pause to let the tee process flush before returning to the console
}


die() {
  echo "$@"
  exit 1
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


optional() {
  # no need to do anything
  return
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

