#!/bin/bash

##############################################################################
#  test_invalid_machine.sh - Unit testing for gathering system information
##############################################################################


############################################################
# Make sure we are working in the this script's source
# directory
############################################################
AUTO_CPU_TESTING_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
cd "$AUTO_CPU_TESTING_DIR" || exit
AUTO_CPU_DIR=$(cd .. && pwd)
export AUTO_CPU_DIR

############################################################
# Import libraries
############################################################
# shellcheck disable=SC1091,SC1090
source "$AUTO_CPU_DIR/lib/user_input.sh"
# shellcheck disable=SC1091,SC1090
source "$AUTO_CPU_DIR/lib/system_info.sh"

MTUNE=""
MARCH=""
MACHINE=""

# needed for correct machine flag dialog
getArch
getGCCVersion

############################################################
# Select the proper machine flag for the config file
#
# This limits the system to only machines defined in the
# configuration file
############################################################
if [[ -z "$MACHINE" ]]; then
  if [[ $(containsElement "${KNOWN_MTUNE_MARCH[@]}" "$MTUNE") == 'y' ]]; then
    if [[ ( $CPU != *'Intel'* || $CPU != *'AMD'* ) && "$MTUNE" != "generic" ]]; then
      MACHINE=$MTUNE
    else
      if [[ $(containsElement "${KNOWN_MTUNE_MARCH[@]}" "$MARCH") == 'y' ]]; then
        MACHINE=$MARCH
      else
        echo
        echo 'We cannot determine your machine architecture.'
        echo
        getMachine
      fi
    fi
  else
    if [[ $(containsElement "${KNOWN_MTUNE_MARCH[@]}" "$MARCH") == 'y' ]]; then
      MACHINE=$MARCH
    else
      echo
      echo 'We cannot determine your machine architecture.'
      echo
      getMachine
    fi
  fi
fi

echo
echo
echo "You chose: $MACHINE"
echo
exit
