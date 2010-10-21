# This is a collection of functions to help write bootstrap scripts and
# their utilities.


# Writes its arguments to stderr and exits with an error.
die() {
  echo "$@" >&2
  exit 1
}


# If your script needs information, just ask for it.
#    Example: ask "What is your name?" name David
# This would prompt for your name with David as the default,
# then store the result in $name.  If the user has already supplied
# a value (say, by passing --name=jed), it just returns since there's
# no need to prompt for anything..
ask() {
  local prompt="$1" varname="$2" default="$3"
  if [ -n "$no_prompts" ]; then
    [ -z "$(eval echo "\$$varname")" ] && eval "$varname=$default"
    [ -z "$(eval echo "\$$varname")" ] && die "Need to supply the $varname!"
  else
    [ -n "$default" ] && guess=" [$default]"
    while [ -z "$(eval echo "\$$varname")" ]; do
      echo -n "$prompt$guess "
      read "$varname"
      [ -z "$(eval echo "\$$varname")" ] && eval "$varname=$default"
    done
  fi
}


# Ensures a value is set before you use it.
#    Example: require name address city state zip
require() {
  local i
  for i in "$@"; do
    eval "val=\$$i"
    if [ -z "$val" ]; then
      echo "Need to supply variable $i to $0!"
      exit 10
    fi
  done
}


# scans through its parameters looking for the nth one that is not
# an argument (i.e. does NOT begin with a dash, not '-n' or '--recursive')
#    Example: parameter 2 "$@"  # with '-a abe -n nat zed', returns nat
parameter() {
  local val skip="$1"
  shift

  for val in "$@"; do
    # if this arg doesn't begin with a dash
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


# we use debootstrap (Debian) names internally: i686 and amd64.
# guess_arch returns the correct names even when run on
# different distros like Fedora
guess_arch() {
  case "$(arch)" in
    x86_64 ) echo amd64     ;;
    i386   ) echo i686      ;;
    *      ) echo "$(arch)" ;;
  esac
}


# Creates a file with the contents given on stdin
#    Example: echo "create ./etc/password
# The benefit to using this function over just cat > file is that
# the command gets printed to the logifle along with the file contents.
create() {
  echo "- creating $1:"
  [ -z "$dry_run" ] && cat > "$1"
  cat "$1" | sed -e "s/^/  $INDENT/"
}


# Patches a file with the contents given on stdin.  The patch should use
# absolute paths (i.e. generate the patch when chrooted).
# See utilities/fix-ssh-conf for an example.
patch_file() {
  local ret patch="$(tempfile -p patch)" || die "could not create tempfile"
  echo "- Using this patchfile:"
  if [ -z "$dry_run" ]; then
    cat > "$patch"
    cat "$patch" | sed 's/^/    /'
    run patch -p1 < "$patch"
    ret="$?"
    rm "$patch"
    if [ "$ret" -ne "0" ]; then
      echo "Exiting because patch failed: $ret"
      exit "$ret"
    fi
  else
    cat
  fi
}


# runs the given command, indenting its stdout, and exiting if it returns
# a bad status code.  Logs the command and its results.
#     Example: run echo hi # prints "$ echo hi\n  hi"
# The command won't be run if --dry-run is set.
run() {
  local dir fifo ret

  echo "- \$ $@"
  if [ -z "$dry_run" ]; then
    dir="$(mktemp -d)"
    fifo="$dir/fifo"
    mkfifo -m 600 "$fifo"
    sed --unbuffered -e "s/^/  $INDENT/" < "$fifo" &

    INDENT="  $INDENT" "$@" > "$fifo"
    ret="$?"

    rm -rf "$dir"
    if [ -n "$ret" ] && [ "$ret" -ne "0" ]; then
      echo "Exiting due to nonzero error code: $ret"
      exit "$ret"
    fi
  fi
}


# Creates the rootfs directory and sets up logging for the run command.
# Call this when right when you're ready to start creating the image.
# Make sure to call stop_bootstrap when you're done.
start_bootstrap()
{
  [ -z "$name" ] && die "You must supply a name to start_bootstrap!"

  [ "$(id -u)" != "0" ] && die "You must be root!"

  [ -e "$name" ] && die "$name already exists!"
  [ -e "$name-partial" ] && run rm -rf "$name-partial"

  # set -e   # exit immediately if any of our commands die

  path="$name"-partial

  run mkdir "$path"
  rootfs="$path/rootfs"

  # Log output to a file and to the console
  if [ -z "$dry_run" ]; then
    echo "Creating $name on $(date)" > "$path/create.log"
    mkfifo -m 600 "$path/log.fifo"
    tee -a "$path/create.log" < "$path/log.fifo" &
    exec 1> "$path/log.fifo"
  fi
}


# Finalizes the machine image and turns off logging.
# Requires the path and name variables to be set.
stop_bootstrap()
{
  run mv "$path" "$name"
  [ -z "$dry_run" ] && rm "$name/log.fifo"

  echo "done.  new machine is in $name"
  exec 1>&-   # doesn't seem to sort buffering issues, not sure why
  sleep 0.1   # quick pause to let the tee process flush before returning to the console
}


# Converts the command line args into variables.
# i.e. --network=dhcp turns into $network with a value of "dhcp"
# Don't call this from your bootstrap script, call init_bootstrap.
read_command_line()
{
  local arg name value
  # copy values from cmdline to environment vars
  for arg in "$@"; do
    [ "$arg" = '-P' ] && arg="--no-prompts"  # don't prompt for anything, use defaults
    [ "$arg" = '-n' ] && arg="--dry-run"

    arg="${arg##--}"    # leading dashes are irrelevant
    name="${arg%%=*}"
    name="$(echo "$name" | tr - _)"
    value="${arg#*=}"
    export "$name=$value"
    variables="$variables$name "
  done
}


# Call this from a boostrap script first thing after you include
# utilities.sh.  It reads config files and processes the args.
#    Example: init_bootstrap "$@"
init_bootstrap()
{
  # read configuration files
  [ -f /etc/lxc-bootstrap.conf ] && . /etc/lxc-bootstrap.conf
  [ -f ~/.lxc-bootstrap.conf ] && . ~/.lxc-bootstrap.conf
  [ -f lxc-bootstrap.conf ] && . ./lxc-bootstrap.conf

  [ -n "$apt_cache" ] && apt_cache="/$apt_cache"

  read_command_line "$@"
}

