#!/bin/bash

##############################################################################
#  system_info.sh - This script handles the gathering the system information
#  and setting the appropriate runspec command.
##############################################################################


##############################################################################
# Will display make, type, and model number
# ARM64 X-Gene1 Example: AArch64 Processor rev 0 (aarch64)
# Intel Example: Intel Xeon D-1540
# Power8 Example: ppc64le
##############################################################################
function getCPU {
  local arch

  CPU=$(grep -m 1 'model name' /proc/cpuinfo | sed 's/model name\s*\:\s*//g;s/(R)//g;s/ @.*//g;s/CPU //g;s/Genuine //g')

  if [ -z "$CPU" ]; then
    CPU=$(lscpu | grep -m 1 "Model name:" | sed 's/Model name:\s*//g;s/(R)//g;s/ @.*//g;s/CPU //g;s/Genuine //g')
  fi

  if [ -z "$CPU" ]; then
    CPU=$(lscpu | grep -m 1 "CPU:" | sed 's/CPU:\s*//g;s/(R)//g;s/ @.*//g;s/CPU //g;s/Genuine //g')
  fi

  if [ -z "$CPU" ]; then
    arch=$(lscpu | grep -m 1 "Architecture:" | sed 's/Architecture:\s*//g;s/x86_//;s/i[3-6]86/32/'  | tr '[:upper:]' '[:lower:]')

    if [[ $arch == *'aarch'* || $arch == *'arm'* ]]; then
      CPU='Unknown ARM'
    elif [[ $arch == *'ppc'* ]]; then
      CPU='Unknown PowerPC'
    elif [[ $arch == *'x86_64'* || $arch == *'32'* ]]; then
      CPU='Unknown Intel'
    else
      CPU='Unknown CPU'
    fi
  fi

  export CPU
}


############################################################
# Get OS and version
# Example OS: Ubuntu
# Example VER: 14.04
############################################################
function getOS {
  if [ -f /etc/lsb-release ]; then
    # shellcheck disable=SC1091,SC1090
    source /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS='Debian'
    VER=$(cat /etc/debian_version)
  elif [ -f /etc/redhat-release ]; then
    OS='Redhat'
    VER=$(cat /etc/redhat-release)
  else
    OS=$(uname -s)
    VER=$(uname -r)
  fi

  export OS
  export VER
}


############################################################
# GCC Version
############################################################
function getGCCVersion {
  GCC_VER=$(gcc --version | sed -rn 's/gcc\s\(.*\)\s([0-9]*\.[0-9]*\.[0-9]*).*/\1/p')

  if [ -z "$GCC_VER" ]; then
    echo
    echo "Cannot determine GCC version."
    echo
    echo -n "What version of GCC are you running? "
    read -r GCC_VER
  fi

  GCC_VER_NO_DOTS=${GCC_VER//\./}
  GCC_VER_SHORT=${GCC_VER_NO_DOTS:0:2}

  export GCC_VER
  export GCC_VER_NO_DOTS
  export GCC_VER_SHORT
}


##############################################################################
# Detect OS architecture
# Displays bits, either 64 or 32
##############################################################################
function getArch {
  ARCH=$(lscpu | grep -m 1 "Architecture:" | sed 's/Architecture:\s*//g;s/x86_//;s/i[3-6]86/32/' | tr '[:upper:]' '[:lower:]')

  # If it is an ARM system
  if [[ $ARCH == *'arm'* ]]; then
    # Get the ARM version number
    ARM_V=$(echo -n "$ARCH" | sed 's/armv//g' | head -c1)

    # If ARMv8 or greater, set to 62 bit
    if [[ "$ARM_V" -ge 8 ]]; then
      ARCH='64'
    else
      ARCH='32'
    fi
  fi

  if [[ $ARCH == *'aarch64'* || $ARCH == *'ppc64le'* ]]; then
    ARCH='64'
  fi

  if [ -z "$ARCH" ]; then
    echo
    echo "Unable to detect system architecture."
    echo
    echo -n "How many bits are in your system architecture (64 or 32)? "
    read -r ARCH
  fi

  export ARCH
}


##############################################################################
# Virtual cores / logical cores / threads
##############################################################################
function getThreads {
  if hash lscpu &>/dev/null; then
    PHYSICAL_PROCESSORS=$(lscpu | grep -m 1 "Socket(s):" | sed 's/Socket(s):\s*//g')
    THREADS_PER_CORE=$(lscpu | grep -m 1 "Thread(s) per core:" | sed 's/Thread(s) per core:\s*//g')
    CORES=$(lscpu | grep -m 1 "Core(s) per socket:" | sed 's/Core(s) per socket:\s*//g')
  else
    echo
    echo -n "How many threads per core? "
    read -r THREADS_PER_CORE
    echo
    echo
    echo -n "How many sockets (physical processors)? "
    read -r PHYSICAL_PROCESSORS
    echo
    echo
    echo -n "How many cores per socket? "
    read -r CORES
    echo
  fi

  TOTAL_CORES=$((PHYSICAL_PROCESSORS * CORES))
  LOGICAL_CORES=$((THREADS_PER_CORE * TOTAL_CORES))

  export PHYSICAL_PROCESSORS
  export THREADS_PER_CORE
  export CORES
  export TOTAL_CORES
  export LOGICAL_CORES
}


############################################################
# The amount of RAM needed to run all copies of SPEC
############################################################
function getRequiredRAM {
  REQUIRED_RAM=$((LOGICAL_CORES * 2))

  export REQUIRED_RAM
}


############################################################
# Get the machine's RAM amount
############################################################
function getMachineRAM {
  local all_dimm_sizes
  local convert
  unset RAM_GB
  # Get RAM in KB
  RAM_KB=$(grep -m 1 "MemTotal: " /proc/meminfo | sed "s/MemTotal:\s*//g;s/kB//g" | tr -d "\t\n\r[:space:]")

  if [ ! -z "$RAM_KB" ]; then
    # convert using 1000 instead of 1024 because it's in kilo bits
    RAM_GB=$((RAM_KB / 1000 / 1000))
    RAM_B=$((RAM_KB * 1000))
  else
    if hash lshw &>/dev/null; then
      mapfile -t all_dimm_sizes <  <(lshw -class memory | awk '/bank/ {seen = 1} seen {print}' | grep size | sed 's/\s*size://g;')

      for i in "${all_dimm_sizes[@]}"; do
        if [[ "$i" == *'GiB'* ]]; then
          # shellcheck disable=SC2001
          convert=$(echo "$i" | sed 's/GiB//g')
          let RAM_GB+=convert
        elif [[ "$i" == *'MiB'* ]]; then
          # shellcheck disable=SC2001
          convert=$(echo "$i" | sed 's/MiB//g')
          convert=$((convert * 1024))
          let RAM_GB+=convert
        elif [[ "$i" == *'KiB'* ]]; then
          # shellcheck disable=SC2001
          convert=$(echo "$i" | sed 's/KiB//g')
          convert=$((convert * 1024 * 1024))
          let RAM_GB+=convert
        fi
      done

      if [[ "$RAM_GB" =~ [a-zA-Z]+ ]]; then
        unset RAM_GB
      elif [ ! -z "$RAM_GB" ]; then
        # convert using 1024 instead of 1000 because it's in GigaByte
        RAM_KB=$((RAM_GB * 1024 * 1024))
        RAM_B=$((RAM_GB * 1024 * 1024 * 1024))
      fi
    fi
  fi

  if [[ "$RAM_B" =~ [a-zA-Z]+ ]] || [[ "$RAM_KB" =~ [a-zA-Z]+ ]] || [[ "$RAM_GB" =~ [a-zA-Z]+ ]]; then
    echo
    echo "ERROR: Memory string contains $?"
    echo
    unset RAM_B
  fi

  if [ -z "$RAM_B" ]; then
    echo
    echo -n "What is the total amount of RAM (in GigaBytes [GB])? "
    read -r RAM_GB
    echo
    RAM_KB=$((RAM_GB * 1024 * 1024))
    RAM_B=$((RAM_GB * 1024 * 1024 * 1024))
  fi

  export RAM_KB
  export RAM_GB
  export RAM_B
}


function getMemoryInformation {
  local dimm_speed_mhz
  local dimm_size_mb
  local dimm_manufacturer
  local dimm_type

  cd "$AUTO_CPU_DIR" || exit

  if hash dmidecode &>/dev/null; then
    # --------------------------------------------------------------------------
    # @TODO
    # The following commented code was meant to get the number of active DIMMs.
    # However, it gave back the total number of DIMMs.
    #
    # Leaving here in case it is helpful later on.
    # --------------------------------------------------------------------------
    #
    # b=$(dmidecode -t 16 | grep "Number Of Devices:" | sed 's/\s*Number Of Devices://g' | tr -d "\n")
    # a=0
    #  shellcheck disable=SC2068
    # for i in ${b[@]}; do
    #   narray[a++]=$((i*2))
    # done
    # number_of_active_dimms="${narray[-1]}"
    # --------------------------------------------------------------------------

    dimm_speed_mhz=$(dmidecode -t 17 | grep -m1 "Speed" | sed 's/\s*Speed: //g;s/\sMHz//g;' | tr -d "\t\n\r[:space:]")
    dimm_size_mb=$(dmidecode -t 17 | grep -m1 "Size" | sed 's/\s*Size: //g;s/MB//g' | tr -d "\t\n\r[:space:]")
    dimm_manufacturer=$(dmidecode -t 17 | grep -m1 "Manufacturer:" | sed 's/\s*Manufacturer: //g' | tr -d "\t\n\r[:space:]")
    dimm_type=$(dmidecode -t 17 | grep -m1 "Type:" | sed 's/\s*Type: //g' | tr -d "\t\n\r[:space:]")
  fi

  if [ -z "$dimm_speed_mhz" ]; then
    if [ -f "$AUTO_CPU_DIR/dimm_speed_mhz.txt" ]; then
      dimm_speed_mhz=$(cat dimm_speed_mhz.txt)
    else
      echo
      echo -n "What is the DIMM speed in MHz? "
      read -r dimm_speed_mhz
      echo -n "$dimm_speed_mhz" > dimm_speed_mhz.txt
      echo
    fi
  fi

  if [ -z "$dimm_size_mb" ]; then
    if [ -f "$AUTO_CPU_DIR/dimm_size_mb.txt" ]; then
      dimm_size_mb=$(cat dimm_size_mb.txt)
    else
      echo
      echo -n "How large are the DIMMs in GB? "
      read -r dimm_size_mb
      dimm_size_mb=$((dimm_size_mb * 1024))
      echo -n "$dimm_size_mb" > dimm_size_mb.txt
      echo
    fi
  else
    if [[ "$dimm_size_mb" == *"GB"* ]]; then
      dimm_size_mb=$(echo -n "${dimm_size_mb//GB/}")
      dimm_size_mb=$((dimm_size_mb * 1024))
    else
      echo
      echo -n "How large are the DIMMs in GB? "
      read -r dimm_size_mb
      dimm_size_mb=$((dimm_size_mb * 1024))
      echo -n "$dimm_size_mb" > dimm_size_mb.txt
      echo
    fi
  fi

  if [ -z "$dimm_manufacturer" ] || [[ "$dimm_manufacturer" == *"Array1"* || "$dimm_manufacturer" == *"Manufacturer1"* ]]; then
    if [ -f "$AUTO_CPU_DIR/dimm_manufacturer.txt" ]; then
      dimm_manufacturer=$(cat dimm_manufacturer.txt)
    else
      echo
      echo -n "What is the DIMM Manufacturer? "
      read -r dimm_manufacturer
      echo -n "$dimm_manufacturer" > dimm_manufacturer.txt
      echo
    fi
  fi

  if [[ "$dimm_type" == *"<OUTOFSPEC>"* ]] || [ -z "$dimm_type" ]; then
    if [ -f "$AUTO_CPU_DIR/dimm_type.txt" ]; then
      dimm_type=$(cat dimm_type.txt)
    else
      echo
      echo -n "What type are the DIMMs (e.g., DDR4)? "
      read -r dimm_type
      echo -n "$dimm_type" > dimm_type.txt
      echo
    fi
  fi

  DIMM_SPEED_MHZ="$dimm_speed_mhz"
  DIMM_SIZE_MB="$dimm_size_mb"
  DIMM_MANUFACTURER="$dimm_manufacturer"
  DIMM_TYPE="$dimm_type"

  # in decimal
  DIMM_SIZE_GB=$((DIMM_SIZE_MB / 1024))

  NUM_OF_ACTIVE_DIMMS=$((RAM_GB / DIMM_SIZE_GB))

  export NUM_OF_ACTIVE_DIMMS
  export DIMM_SPEED_MHZ
  export DIMM_SIZE_MB
  export DIMM_SIZE_GB
  export DIMM_MANUFACTURER
  export DIMM_TYPE
}


############################################################
# Set number of copies the hardware can handle
############################################################
function getMaxCopies {
  if [[ $COPY_OVERRIDE == true ]]; then
    if [[ $NO_COPY == true ]]; then
      COPIES='1'
    fi
    # if the copy is set with -c [n] or --copies [n]
    # the number of copies is already set when reading the input arguments
  else
    if [ "$RAM_GB" -ge "$REQUIRED_RAM" ]; then
      COPIES=$LOGICAL_CORES
    else
      COPIES=$((RAM_GB / 2))
    fi
  fi

  export COPIES
}


############################################################
# Get the appropriate GCC flags
############################################################
function getCompilerInfo {
  local march_cpu
  local cpu_lower

  march_cpu='march'
  cpu_lower=$(echo -n "$CPU" | tr '[:upper:]' '[:lower:]')

  if [[ "$cpu_lower" == *'power'* || "$cpu_lower" == *'ppc'* ]]; then
    march_cpu='mcpu'
  fi

  MARCH=$(gcc -"$march_cpu"=native -Q --help=target 2> /dev/null | grep -m 1 '\-march=' | sed "s/-march=//g;s/ARCH//g" | tr -d "\t\n\r[:space:]")
  MTUNE=$(gcc -"$march_cpu"="$MARCH" -mtune=native -Q --help=target 2> /dev/null | grep -m 1 '\-mtune=' | sed "s/-mtune=//g;s/CPU//g" | tr -d "\t\n\r[:space:]")

  # shellcheck disable=SC2181
  if [ $? -ne 0 ] || [[ "$MARCH" == *"native"* ]] || [ -z "$MARCH" ] || [[ "$MTUNE" == *"native"* ]] || [ -z "$MTUNE" ]; then
    echo
    echo "The system couldn't detect the compiler machine tuning."
    echo
    getMachine
  else
    export MARCH
    export MTUNE
  fi
}


############################################################
# Get hardware date for config files
############################################################
function getHWDate {
  local hw_date

  if hash dmidecode &>/dev/null; then
    # assume that the hardware release date is the same as the BIOS release date
    hw_date=$(dmidecode -t bios | grep "Release" | sed "s/Release Date:\s*//g" | tr -d " \t\r\n" | { read -r dt; date -d "$dt" "+%b-%Y"; })
  fi

  if [ -z "$hw_date" ]; then
    echo
    echo -n "Cannot detect the hardware release date. What is the date in MMM-YYYY format (ex. Jun-1993)? "
    read -r hw_date
    echo
  fi

  HW_DATE="$hw_date"

  export HW_DATE
}


############################################################
# Get the CPU frequency for the config files
############################################################
function getCPUFreq {
  local freq
  local mhz_freq

  mhz_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | sed 's/cpu MHz\s*:\s*//g;'  | LC_ALL=C xargs printf "%.*f" 0 | tr -d " \t\r\n")
  freq=$(bc <<< "scale=1; $mhz_freq/1000")

  if [ -z "$freq" ]; then
    freq=$(grep -m1 "model name" /proc/cpuinfo | sed 's/.*@ //g;s/\.//g;s/GHz//g' | LC_ALL=C xargs printf "%d0" | tr -d " \t\r\n")
  fi

  if [ -z "$freq" ]; then
    if hash dmidecode &>/dev/null; then
      freq=$(dmidecode -t processor | grep -m1 "Current Speed" | sed "s/\s*Current Speed:\s*//g;s/\s*MHz//g" | tr -d " \t\r\n")
    fi
  fi

  if [ -z "$freq" ]; then
    if hash lscpu &>/dev/null; then
      freq=$(lscpu | grep "CPU max MHz:" | sed "s/\s*CPU max MHz:\s*//g" | LC_ALL=C xargs printf "%.*f" 0 | tr -d " \t\r\n")
    fi
  fi

  if [ -z "$freq" ]; then
    echo
    echo -n "Cannot detect the CPU frequency. What is the frequency in MHz (ex. 2600 for 2.6GHz)? "
    read -r freq
    echo
  fi

  CPU_FREQ="$freq"

  export CPU_FREQ
}


############################################################
# Get the cache level sizes for the config files
############################################################
function getCache {
  local level_one_instruction
  local level_one_data
  local level_two
  local level_three

  if hash lscpu &>/dev/null; then

    # L1 data cache
    level_one_data=$(lscpu | grep "L1d cache" | sed 's/L1d cache:\s*//g' | tr -d " \t\r\n")

    if [[ "$level_one_data" != "" ]]; then
      # K to KB
      if [[ "$level_one_data" == *"K" ]]; then
        # shellcheck disable=SC2116
        level_one_data=$(echo -n "${level_one_data//K/KB}")
      fi
    else
      level_one_data="N/A"
    fi

    # L1 instruction cache
    level_one_instruction=$(lscpu | grep "L1i cache" | sed 's/L1i cache:\s*//g' | tr -d " \t\r\n")

    if [[ "$level_one_instruction" != "" ]]; then
      # K to KB
      if [[ "$level_one_instruction" == *"K" ]]; then
        level_one_instruction=$(echo -n "${level_one_instruction//K/KB}")
      fi
    else
      level_one_instruction="N/A"
    fi

    # L2 cache
    level_two=$(lscpu | grep "L2 cache" | sed 's/L2 cache:\s*//g' | tr -d " \t\r\n")

    if [[ "$level_two" != "" ]]; then
      # K to KB
      if [[ "$level_two" == *"K" ]]; then
        level_two=$(echo -n "${level_two//K/KB}")
      elif  [[ "$level_two" == *"M" ]]; then
        level_two=$(echo -n "${level_two//M/MB}")
      fi
    else
      level_two="N/A"
    fi

    # L3 cache
    level_three=$(lscpu | grep "L3 cache" | sed 's/L3 cache:\s*//g' | tr -d " \t\r\n")

    if [[ "$level_three" != "" ]]; then
      # K to KB
      if [[ "$level_three" == *"K" ]]; then
        level_three=$(echo -n "${level_three//K/KB}")
      elif  [[ "$level_three" == *"M" ]]; then
        level_three=$(echo -n "${level_three//M/MB}")
      fi
    else
      level_three="N/A"
    fi
  else
    echo
    echo "We cannot determine the cache size."
    echo
    echo -n "What is the Level 1 Instruction cache size (#+unit: e.g., '32KB', or 'N/A' for none)? "
    read -r level_one_instruction
    echo
    echo -n "What is the Level 1 Data cache size (#+unit: e.g., '32KB', or 'N/A' for none)? "
    read -r level_one_data
    echo
    echo -n "What is the Level 2 cache size (#+unit: e.g., '256KB', or 'N/A' for none)? "
    read -r level_two
    echo
    echo -n "What is the Level 3 cache size (#+unit: e.g., '31MB', or 'N/A' for none)? "
    read -r level_three
  fi

  L1I_CACHE="$level_one_instruction"
  L1D_CACHE="$level_one_data"
  L2_CACHE="$level_two"
  L3_CACHE="$level_three"

  export L1D_CACHE
  export L1I_CACHE
  export L2_CACHE
  export L3_CACHE
}


############################################################
# Write system information to the config files
############################################################
function systemInformationToConfig {
  local cpu_lower
  local ram_info
  local pcache_info
  local scache_info
  local tcache_info

  cpu_lower=$(echo -n "$CPU" | tr '[:upper:]' '[:lower:]')

  pcache_info="$L1I_CACHE Instruction + $L1D_CACHE Data per core"

  if [[ "$L2_CACHE" != *"N/A"* ]]; then
    scache_info="$L2_CACHE"" on chip"
  else
    scache_info="N/A"
  fi

  if [[ "$L3_CACHE" != *"N/A"* ]]; then
    tcache_info="$L3_CACHE"" on chip"
  else
    tcache_info="N/A"
  fi

  ram_info="$NUM_OF_ACTIVE_DIMMS x $DIMM_SIZE_GB""GB $DIMM_MANUFACTURER $DIMM_TYPE $DIMM_SPEED_MHZ"

  if [[ "$cpu_lower" == *'intel'* ]]; then
    # hardware date
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # cpu name
    sed -i "s/hw_cpu_name     = Intel/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_cpu_name     = Intel/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # cpu frequency
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # ram
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # number of chips
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # number of total cores
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # number of cores per chip
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # number of threads per core
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # cache level 1
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # cache level 2
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # cache level 3
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # OS
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # GCC
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # G++
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg
    # GFORTRAN
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux32-intel32-gcc.cfg
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux64-intel64-gcc.cfg

  elif [[ "$cpu_lower" == *'arm'* ]]; then
    # hardware date
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # cpu name
    sed -i "s/hw_cpu_name     = ARM/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_cpu_name     = ARM/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # cpu frequency
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # ram
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # number of chips
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # number of total cores
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # number of cores per chip
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # number of threads per core
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # cache level 1
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # cache level 2
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # cache level 3
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # OS
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # GCC
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # G++
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg
    # GFORTRAN
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux32-arm32-gcc.cfg
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux64-arm64-gcc.cfg

  elif [[ "$cpu_lower" == *'power'* || "$cpu_lower" == *'ppc'* ]]; then
    # hardware date
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # cpu name
    sed -i "s/hw_cpu_name     = PowerPC/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # cpu frequency
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # ram
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # number of chips
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # number of total cores
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # number of cores per chip
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # number of threads per core
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # cache level 1
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # cache level 2
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # cache level 3
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # OS
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # GCC
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # G++
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg
    # GFORTRAN
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux64-powerpc-gcc.cfg

  elif [[ "$cpu_lower" == *'amd'* || "$cpu_lower" == *'amd'* ]]; then
    # hardware date
    sed -i "s/hw_avail        = 2014/hw_avail        = $HW_DATE/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # cpu name
    sed -i "s/hw_cpu_name     = AMD/hw_cpu_name     = $CPU/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # cpu frequency
    sed -i "s/hw_cpu_mhz      = 2400/hw_cpu_mhz      = $CPU_FREQ/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # ram
    sed -i "s/hw_memory       = 9999/hw_memory       = $RAM_GB GB \($ram_info\)/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # number of chips
    sed -i "s/hw_nchips       = 1/hw_nchips       = $PHYSICAL_PROCESSORS/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # number of total cores
    sed -i "s/hw_ncores       = 48/hw_ncores       = $TOTAL_CORES/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # number of cores per chip
    sed -i "s/hw_ncoresperchip= 48/hw_ncoresperchip= $CORES/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # number of threads per core
    sed -i "s/hw_nthreadspercore= 1/hw_nthreadspercore= $THREADS_PER_CORE/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # cache level 1
    sed -i "s/hw_pcache       = 78KB Instruction + 32KB Data per core/hw_pcache       = $pcache_info/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # cache level 2
    sed -i "s|hw_scache       = N/A|hw_scache       = $scache_info|" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # cache level 3
    sed -i "s|hw_tcache       = N/A|hw_tcache       = $tcache_info|" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # OS
    sed -i "s/sw_os           = Ubuntu/sw_os           = $OS $VER/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # GCC
    sed -i "s/sw_compiler1 = C: Version <n.n.n> of gcc/sw_compiler1 = C: Version $GCC_VER of gcc/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # G++
    sed -i "s/sw_compiler2 = C++: Version <n.n.n> of g++/sw_compiler2 = C++: Version $GCC_VER of g++/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
    # GFORTRAN
    sed -i "s/sw_compiler3 = Fortran: Version <n.n.n> of gfortran/sw_compiler3 = Fortran: Version $GCC_VER of gfortran/" "$AUTO_CPU_DIR"/config/linux64-amd64-gcc.cfg
  fi
}


############################################################
# Function to get all system information
############################################################
function getSystemInfo {
  getCPU
  getOS
  getGCCVersion
  getArch
  getThreads
  getRequiredRAM
  getMachineRAM
  getMaxCopies
  getCompilerInfo
}
