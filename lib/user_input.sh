#!/bin/bash

##############################################################################
#  user_input.sh - This script performs user input required for auto-detection
#  value failures.
##############################################################################

export KNOWN_MTUNE_MARCH=(
  "core2"
  "nehalem"
  "westmere"
  "sandybridge"
  "ivybridge"
  "haswell"
  "broadwell"
  "bonnell"
  "silvermont"
  "skylake"
  "knl"
  "skylake-avx512"
  "corei7"
  "corei7-avx"
  "core-avx-i"
  "core-avx2"
  "atom"
  "native"
  "armv8-a"
  "armv7-a"
  "cortex-a9"
  "cortex-a15"
  "marvell-pj4"
  "generic-armv8-a"
  "generic-armv7-a"
  "xgene1"
  "thunderx"
  "cortex-a72"
  "cortex-a57"
  "cortex-a53"
  "power8"
  "power7"
  "powerpc"
  "powerpc64"
  "rs64"
  "k6"
  "k6-2"
  "k6-3"
  "athlon"
  "athlon-tbird"
  "athlon-4"
  "athlon-xp"
  "athlon-mp"
  "k8"
  "opteron"
  "athlon64"
  "athlon-fx"
  "k8-sse3"
  "opteron-sse3"
  "athlon64-sse3"
  "amdfam10"
  "barcelona"
  "bdver1"
  "bdver2"
  "bdver3"
  "bdver4"
  "znver1"
  "btver1"
  "btver2"
)


############################################################
# Function to remove leading and trailing whitespace
#
# Usage: trim "$STRING"
############################################################
function trim {
  local input_string="$*"
  # remove leading whitespace characters
  input_string="${input_string#"${input_string%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  input_string="${input_string%"${input_string##*[![:space:]]}"}"
  echo -n "$input_string"
}


############################################################
# Function to check if a variable resides in an array
#
# Usage: containsElement "${ARRAY[@]}" "$STRING"
############################################################
function containsElement() {
  local number_of_parameters=$#
  local value=${!number_of_parameters}
  for ((index=1;index < number_of_parameters;index++)) {
    if [ "${!index}" == "${value}" ]; then
      echo "y"
      return 0
    fi
  }
  echo "n"
  return 1
}


############################################################
# Function get the processor and architecture of an unknown
# chipset from the user
############################################################
function processorArchitecture {
  local PS3="Enter your choice: "
  local cpu_options=( "Intel" "AMD" "ARM" "PowerPC" )
  local arch_options=( "32-bit" "64-bit" )

  if [[ "$CPU_TYPE" == "" ]] || [[ -z "$CPU_TYPE" ]]; then
    echo "Which brand of processor is it? "

    select opt in "${cpu_options[@]}"; do
      case $opt in
        "Intel")
          CPU='Intel'
          CPU_TYPE="Intel"
          break
          ;;
        "AMD")
          CPU='AMD'
          CPU_TYPE="AMD"
          break
          ;;
        "ARM")
          CPU='ARM'
          CPU_TYPE="ARM"
          break
          ;;
        "PowerPC")
          CPU='PowerPC'
          CPU_TYPE="IBM"
          break
          ;;
        *) echo "That's a wrong option. Please try again.";;
      esac
    done

    export CPU
    export CPU_TYPE
  fi

  if [[ "$ARCH" == "" ]] || [[ -z "$ARCH" ]]; then
    echo "Is it 32-bit or 64-bit architecture? "

    select opt in "${arch_options[@]}"; do
      case $opt in
        "32-bit")
          ARCH='32'
          break
          ;;
        "64-bit")
          ARCH='64'
          break
          ;;
        *) echo "That's a wrong option. Please try again.";;
      esac
    done

    export ARCH
  fi

  if [[ "$CPU_TYPE" == "Intel" ]]; then
    if [[ "$ARCH" == "64" ]]; then
      export CONFIG="linux64-intel64-gcc"
    else
      export CONFIG="linux32-intel32-gcc"
    fi
  elif [[ "$CPU_TYPE" == "ARM" ]]; then
    if [[ "$ARCH" == "64" ]]; then
      export CONFIG="linux64-arm64-gcc"
    else
      export CONFIG="linux32-arm32-gcc"
    fi
  elif [[ "$CPU_TYPE" == "IBM" ]]; then
    export CONFIG="linux64-powerpc-gcc"
  elif [[ "$CPU_TYPE" == "AMD" ]]; then
    export CONFIG="linux64-amd64-gcc"
  else
    echo
    echo "That's a wrong option. Please try again."
    echo "Currently, only PowerPC, ARM, AMD, and Intel are supported."
    echo
    processorArchitecture
  fi
}


############################################################
# Function for getting the user desired machine type
############################################################
function machineInput {
  local mtype

  echo -n "Please input your option: "
  read -r mtype

  mtype=$(trim "$mtype")

  if [[ $(containsElement "${KNOWN_MTUNE_MARCH[@]}" "$mtype") == "y" ]]; then
    export MACHINE=$mtype
  else
    echo
    echo "That's a wrong option. Please try again."
    echo
    getMachine
  fi
}


############################################################
# Get user to input their machine information
############################################################
function getMachine {
  local PS3="Please enter manufacturer choice: "
  local options=( "Intel" "AMD" "ARM" "PowerPC" )

  if [[ -z "$CPU_TYPE" ]]; then
    select opt in "${options[@]}"; do
      case $opt in
        "Intel")
          CPU_TYPE='Intel'
          break
          ;;
        "AMD")
          CPU_TYPE='AMD'
          break
          ;;
        "ARM")
          CPU_TYPE='ARM'
          break
          ;;
        "PowerPC")
          CPU_TYPE='IBM'
          break
          ;;
        *) echo "That's a wrong option. Please try again.";;
      esac
    done
  fi

  if [[ "$CPU_TYPE" == "Intel" ]]; then
    intelOptions
  elif [[ "$CPU_TYPE" == "AMD" ]]; then
    amdOptions
  elif [[ "$CPU_TYPE" == "ARM" ]]; then
    armOptions
  elif [[ "$CPU_TYPE" == "IBM" ]]; then
    ppcOptions
  else
    echo
    echo "Currently, only PowerPC, ARM, and Intel are supported."
    echo "Exiting now."
    exit
  fi

  machineInput
}


############################################################
# Function for outputting the current Intel options
############################################################
function intelOptions {
  echo
  echo "*************************************************************************"
  echo "************************ Your Intel options are: ************************"
  echo "*************************************************************************"
  echo
  if [[ $GCC_VER_SHORT -ge "49" ]]; then
    echo "**************************** GCC 4.9 or more ****************************"
    echo "'core2' - Intel Core 2 CPU with 64-bit extensions, MMX, SSE, SSE2, SSE3"
    echo "and SSSE3 instruction set support."
    echo "*************************************************************************"
    echo "'nehalem' - Intel Nehalem CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1, SSE4.2 and POPCNT instruction set support."
    echo "*************************************************************************"
    echo "'westmere' - Intel Westmere CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES and PCLMUL instruction set"
    echo "support."
    echo "*************************************************************************"
    echo "'sandybridge' - Intel Sandy Bridge CPU with 64-bit extensions, MMX, SSE, "
    echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES and PCLMUL instruction"
    echo "set support."
    echo "*************************************************************************"
    echo "'ivybridge' - Intel Ivy Bridge CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AES, PCLMUL, FSGSBASE, RDRND"
    echo "and F16C instruction set support."
    echo "*************************************************************************"
    echo "'haswell' - Intel Haswell CPU with 64-bit extensions, MOVBE, MMX, SSE, "
    echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, "
    echo "FSGSBASE, RDRND, FMA, BMI, BMI2 and F16C instruction set support."
    echo "*************************************************************************"
    echo "'broadwell' - Intel Broadwell CPU with 64-bit extensions, MOVBE, MMX,"
    echo "SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL, "
    echo "FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX and PREFETCHW "
    echo "instruction set support."
    echo "*************************************************************************"
    echo "'bonnell' - Intel Bonnell CPU with 64-bit extensions, MOVBE, MMX, SSE,"
    echo "SSE2, SSE3 and SSSE3 instruction set support."
    echo "*************************************************************************"
    echo "'silvermont' - Intel Silvermont CPU with 64-bit extensions, MOVBE, MMX,"
    echo "SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AES, PCLMUL and RDRND"
    echo "instruction set support."
    echo "*************************************************************************"
    echo "'skylake' - Intel Skylake CPU with 64-bit extensions, MOVBE, MMX, SSE,"
    echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL,"
    echo "FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX, PREFETCHW,"
    echo "CLFLUSHOPT, XSAVEC and XSAVES instruction set support."
    echo "*************************************************************************"
    echo "'knl' - Intel Knight's Landing CPU with 64-bit extensions, MOVBE, MMX,"
    echo "SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, AVX, AVX2, AES, PCLMUL,"
    echo "FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX, PREFETCHW, AVX512F,"
    echo "AVX512PF, AVX512ER and AVX512CD instruction set support. "
    echo "*************************************************************************"
    echo "'skylake-avx512' - Intel Skylake Server CPU with 64-bit extensions,"
    echo "MOVBE, MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, POPCNT, PKU, AVX,"
    echo "AVX2, AES, PCLMUL, FSGSBASE, RDRND, FMA, BMI, BMI2, F16C, RDSEED, ADCX,"
    echo "PREFETCHW, CLFLUSHOPT, XSAVEC, XSAVES, AVX512F, AVX512VL, AVX512BW,"
    echo "AVX512DQ and AVX512CD instruction set support."
  else
    echo "**************************** GCC 4.8 or less ****************************"
    echo "'core2' - Intel Core 2 CPU with 64-bit extensions, MMX, SSE, SSE2, SSE3"
    echo "and SSSE3 instruction set support."
    echo "*************************************************************************"
    echo "'corei7' - Intel Core i7 CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1 and SSE4.2 instruction set support."
    echo "*************************************************************************"
    echo "'corei7-avx' - Intel Core i7 CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES and PCLMUL instruction set support."
    echo "*************************************************************************"
    echo "'core-avx-i' - Intel Core CPU with 64-bit extensions, MMX, SSE, SSE2,"
    echo "SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AES, PCLMUL, FSGSBASE, RDRND and F16C"
    echo "instruction set support."
    echo "*************************************************************************"
    echo "'core-avx2' - Intel Core CPU with 64-bit extensions, MOVBE, MMX, SSE,"
    echo "SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2, AES, PCLMUL, FSGSBASE,"
    echo "RDRND, FMA, BMI, BMI2 and F16C instruction set support."
  fi
  echo "*************************************************************************"
  echo "'atom' - Intel Atom CPU with 64-bit extensions, MOVBE, MMX, SSE, SSE2,"
  echo "SSE3 and SSSE3 instruction set support."
  echo "*************************************************************************"
  echo "'native' - System native Intel CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo
}


############################################################
# Function for outputting the current ARM options
############################################################
function armOptions {
  echo
  echo "*************************************************************************"
  echo "************************* Your ARM options are: *************************"
  echo "*************************************************************************"
  echo
  echo "*************************************************************************"
  echo "'cortex-a9'  - ARM Cortex-A9 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'cortex-a15' - ARM Cortex-A9 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'marvell-pj4' - ARM Marvell-PJ4 CPU with 64-bit extensions."
  echo "*************************************************************************"
  if [[ $GCC_VER_SHORT -ge "50" ]]; then
    echo "'xgene1' - ARM X-Gene1 CPU with 64-bit extensions."
    echo "*************************************************************************"
    echo "'thunderx' - ARM Thunder-X CPU with 64-bit extensions."
    echo "*************************************************************************"
  fi
  echo "'cortex-a72' - ARM Cortex-A72 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'cortex-a57' - ARM Cortex-A57 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'cortex-a53' - ARM Cortex-A53 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'generic' - Generic ARM CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo
}


############################################################
# Function for outputting the current PowerPC options
############################################################
function ppcOptions {
  echo
  echo "*************************************************************************"
  echo "*********************** Your PowerPC options are: ***********************"
  echo "*************************************************************************"
  echo
  echo "*************************************************************************"
  echo "'power8'  - Power 8 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'power7'  - Power 7 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'powerpc' - PowerPC CPU with 32-bit extensions."
  echo "*************************************************************************"
  echo "'powerpc64' - PowerPC CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo "'rs64' - RS 64 CPU with 64-bit extensions."
  echo "*************************************************************************"
  echo
}



############################################################
# Function for outputting the current AMD options
############################################################
function amdOptions {
  echo
  echo "*************************************************************************"
  echo "*********************** Your PowerPC options are: ***********************"
  echo "*************************************************************************"
  echo
  echo "*************************************************************************"
  echo "'k6'  - AMD K6 CPU with MMX instruction set support."
  echo "*************************************************************************"
  echo "'k6-2' or 'k6-3' - Improved versions of AMD K6 CPU with MMX and 3DNow!"
  echo "instruction set support. "
  echo "*************************************************************************"
  echo "'athlon' or 'athlon-tbird' - AMD Athlon CPU with MMX, 3dNOW!, enhanced"
  echo "3DNow! and SSE prefetch instructions support. "
  echo "*************************************************************************"
  echo "'athlon-4', 'athlon-xp', or 'athlon-mp' - Improved AMD Athlon CPU with"
  echo "MMX, 3DNow!, enhanced 3DNow! and full SSE instruction set support. "
  echo "*************************************************************************"
  echo "'k8', 'opteron', 'athlon64', or 'athlon-fx' - Processors based on the AMD"
  echo "K8 core with x86-64 instruction set support, including the AMD Opteron,"
  echo "Athlon 64, and Athlon 64 FX processors. (This supersets MMX, SSE, SSE2,"
  echo "3DNow!, enhanced 3DNow! and 64-bit instruction set extensions.)"
  echo "*************************************************************************"
  echo "'k8-sse3', 'opteron-sse3', or 'athlon64-sse3' - Improved versions of AMD"
  echo "K8 cores with SSE3 instruction set support. "
  echo "*************************************************************************"
  echo "'amdfam10' or 'barcelona' - CPUs based on AMD Family 10h cores with"
  echo "x86-64 instruction set support. (This supersets MMX, SSE, SSE2, SSE3,"
  echo "SSE4A, 3DNow!, enhanced 3DNow!, ABM and 64-bit instruction set"
  echo "extensions.) "
  echo "*************************************************************************"
  echo "'bdver1' - CPUs based on AMD Family 15h cores with x86-64 instruction set"
  echo "support. (This supersets FMA4, AVX, XOP, LWP, AES, PCL_MUL, CX16, MMX,"
  echo "SSE, SSE2, SSE3, SSE4A, SSSE3, SSE4.1, SSE4.2, ABM and 64-bit instruction"
  echo "set extensions.) "
  echo "*************************************************************************"
  echo "'bdver2' - AMD Family 15h core based CPUs with x86-64 instruction set"
  echo "support. (This supersets BMI, TBM, F16C, FMA, FMA4, AVX, XOP, LWP, AES,"
  echo "PCL_MUL, CX16, MMX, SSE, SSE2, SSE3, SSE4A, SSSE3, SSE4.1, SSE4.2, ABM"
  echo "and 64-bit instruction set extensions.) "
  echo "*************************************************************************"
  echo "'bdver3' - AMD Family 15h core based CPUs with x86-64 instruction set"
  echo "support. (This supersets BMI, TBM, F16C, FMA, FMA4, FSGSBASE, AVX, XOP,"
  echo "LWP, AES, PCL_MUL, CX16, MMX, SSE, SSE2, SSE3, SSE4A, SSSE3, SSE4.1,"
  echo "SSE4.2, ABM and 64-bit instruction set extensions.)"
  echo "*************************************************************************"
  echo "'bdver4' - AMD Family 15h core based CPUs with x86-64 instruction set"
  echo "support. (This supersets BMI, BMI2, TBM, F16C, FMA, FMA4, FSGSBASE, AVX,"
  echo "AVX2, XOP, LWP, AES, PCL_MUL, CX16, MOVBE, MMX, SSE, SSE2, SSE3, SSE4A,"
  echo "SSSE3, SSE4.1, SSE4.2, ABM and 64-bit instruction set extensions.)" 
  echo "*************************************************************************"
  echo "'znver1' - AMD Family 17h core based CPUs with x86-64 instruction set"
  echo "support. (This supersets BMI, BMI2, F16C, FMA, FSGSBASE, AVX, AVX2, ADCX,"
  echo "RDSEED, MWAITX, SHA, CLZERO, AES, PCL_MUL, CX16, MOVBE, MMX, SSE, SSE2,"
  echo "SSE3, SSE4A, SSSE3, SSE4.1, SSE4.2, ABM, XSAVEC, XSAVES, CLFLUSHOPT,"
  echo "POPCNT, and 64-bit instruction set extensions.)"
  echo "*************************************************************************"
  echo "'btver1' - CPUs based on AMD Family 14h cores with x86-64 instruction set"
  echo "support. (This supersets MMX, SSE, SSE2, SSE3, SSSE3, SSE4A, CX16, ABM"
  echo "and 64-bit instruction set extensions.) "
  echo "*************************************************************************"
  echo "'btver2' - CPUs based on AMD Family 16h cores with x86-64 instruction set"
  echo "support. This includes MOVBE, F16C, BMI, AVX, PCL_MUL, AES, SSE4.2,"
  echo "SSE4.1, CX16, ABM, SSE4A, SSSE3, SSE3, SSE2, SSE, MMX and 64-bit"
  echo "instruction set extensions. "
  echo "*************************************************************************"
  echo
}
