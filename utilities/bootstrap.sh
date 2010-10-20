# Includes utilities.sh and then converts the command line args into variables.
# This is meant to be included by top-level bootstrap commands, i.e. lxc-lucid.

. utilities/utilities.sh

# copy values from cmdline to environment vars
for arg in "$@"; do
  arg=${arg##--}    # leading dashes are irrelevant
  name=${arg%%=*}
  value=${arg#*=}
  export "$name=$value"
  variables="$variables$name "
done
# echo "variables: $variables"
