# This file is meant to be sourced by top-level bootstrap commands, i.e. lxc-lucid.
# Includes functions only useful to top-level commands.


# Creates the rootfs directory and sets up logging for the run command.
# Pass name of the VM as a parameter, it sets the path and rootfs vars.
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
# Requires the path and name variables to be set
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
read_command_line()
{
  local arg name value
  # copy values from cmdline to environment vars
  for arg in "$@"; do
    [ "$arg" = '-z' ] && arg="--non-interactive"
    [ "$arg" = '-n' ] && arg="--dry-run"

    arg="${arg##--}"    # leading dashes are irrelevant
    name="${arg%%=*}"
    name="$(echo "$name" | tr - _)"
    value="${arg#*=}"
    export "$name=$value"
    variables="$variables$name "
  done
}


# read configuration files
[ -f /etc/lxc-bootstrap.conf ] && . /etc/lxc-bootstrap.conf
[ -f ~/.lxc-bootstrap.conf ] && . ~/.lxc-bootstrap.conf
[ -f lxc-bootstrap.conf ] && . ./lxc-bootstrap.conf

[ -n "$apt_cache" ] && apt_cache="/$apt_cache"

read_command_line "$@"
