#!/bin/bash

##############################################################################
#  test_system_info.sh - Unit testing for gathering system information
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

getCPU
getOS
getArch
getMachineRAM
getMemoryInformation
getHWDate
getThreads
getCPUFreq
getGCCVersion
getCompilerInfo
getCache


echo
echo "*********** HARDWARE INFO ***********"
echo
echo "CPU: $CPU"
echo "CPU Sockets: $PHYSICAL_PROCESSORS"
echo "CPU Threads Per Core: $THREADS_PER_CORE"
echo "CPU Cores Per Socket: $CORES"
echo "CPU Total Cores: $TOTAL_CORES"
echo "CPU Total Threads: $LOGICAL_CORES"
echo "CPU Frequency: $CPU_FREQ"
echo "CPU L1 Data Cache: $L1D_CACHE"
echo "CPU L1 Instruction Cache: $L1I_CACHE"
echo "CPU L2 Cache: $L2_CACHE"
echo "CPU L3 Cache: $L3_CACHE"
echo
echo "Amount Of RAM: $RAM_GB GB / $RAM_KB KB / $RAM_B B"
echo "Number Of Active DIMMs: $NUM_OF_ACTIVE_DIMMS"
echo "DIMM Speed: $DIMM_SPEED_MHZ MHz"
echo "DIMM Size: $DIMM_SIZE_MB MB / $DIMM_SIZE_GB GB"
echo "DIMM Manufacturer: $DIMM_MANUFACTURER"
echo "DIMM Type: $DIMM_TYPE"
echo
echo "Estimated Hardware Date: $HW_DATE"
echo
echo "*********** SOFTWARE INFO ***********"
echo
echo "OS: $OS $VER"
echo "Architecture: $ARCH bit"
echo
echo "GCC Version: $GCC_VER"
echo "GCC -march Flag: $MARCH"
echo "GCC -mtune Flag: $MTUNE"
echo


exit
