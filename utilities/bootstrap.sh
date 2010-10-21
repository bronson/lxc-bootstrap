# Includes utilities.sh and then converts the command line args into variables.
#   --network=dhcp turns into $network with a value of "dhcp"
# This file is meant to be sourced by top-level bootstrap commands, i.e. lxc-lucid.
# Also includes functions only useful to top-level commands.

. utilities/utilities.sh


# Creates the rootfs directory and sets up logging for the run command.
# Pass name of the VM as a parameter, it sets the path and rootfs vars.
# Make sure to call stop_bootstrap when you're done.
start_bootstrap()
{
  name="$1"
  [ -z "$name" ] && die "You must pass a name to start_bootstrap!"

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


# Finalizes the machine image and turns off logging.
# Requires the path and name variables to be set
stop_bootstrap()
{
  run mv "$path" "$name"
  rm "$name/log.fifo"

  echo "done.  new machine is in $name"
  exec 1>&-   # doesn't seem to sort buffering issues, not sure why
  sleep 0.1   # quick pause to let the tee process flush before returning to the console
}


# copy values from cmdline to environment vars
for arg in "$@"; do
  arg="${arg##--}"    # leading dashes are irrelevant
  name="${arg%%=*}"
  name="$(echo "$name" | tr - _)"
  value="${arg#*=}"
  export "$name=$value"
  variables="$variables$name "
done
# echo "variables: $variables"
