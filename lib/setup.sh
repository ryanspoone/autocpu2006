#!/bin/bash

##############################################################################
#  setup.sh - This script handles the installation of needed prerequisites
#  and SPEC CPU2006
##############################################################################


############################################################
# Install prerequisites if needed
############################################################
function prerequisites {
  # If apt-get is installed
  if hash apt-get &>/dev/null; then
    sudo -E apt-get update

    # make sure that aptitude is installed
    # "aptitude safe-upgrade" will upgrade the kernel
    if hash aptitude &>/dev/null; then
      sudo -E aptitude -r safe-upgrade -y
    else
      sudo -E apt-get aptitude -y
      sudo -E aptitude -r safe-upgrade -y
    fi

    sudo -E apt-get build-dep gcc -y
    sudo -E apt-get install gcc -y
    sudo -E apt-get install g++ -y
    sudo -E apt-get install gfortran -y
    sudo -E apt-get install build-essential -y
    sudo -E apt-get install unzip -y
    sudo -E apt-get install numactl -y
    sudo -E apt-get install gawk -y
    sudo -E apt-get install bc -y
    sudo -E apt-get install automake -y
    sudo -E apt-get install util-linux -y
    sudo -E apt-get install dmidecode -y

  # If yum is installed
  elif hash yum &>/dev/null; then
    sudo -E yum check-update -y
    sudo -E yum update -y
    sudo -E yum update kernel -y
    sudo -E yum groupinstall "Development Tools" "Development Libraries" -y
    sudo -E yum install unzip -y
    sudo -E yum-builddep gcc -y
    sudo -E yum install gcc -y
    sudo -E yum install g++ -y
    sudo -E yum install gfortran -y
    sudo -E yum install numactl -y
    sudo -E yum install automake -y
    sudo -E yum install bc -y
    sudo -E yum install util-linux -y
    sudo -E yum install dmidecode -y

  # If zypper is installed
  elif hash zypper &>/dev/null; then
    sudo -E zypper -n install -t pattern devel_basis
    sudo -E zypper -n install gcc
    sudo -E zypper -n install gcc-c++
    sudo -E zypper -n install gcc-fortran
    sudo -E zypper -n install numactl
    sudo -E zypper -n install automake
    sudo -E zypper -n install unzip
    sudo -E zypper -n install gawk
    sudo -E zypper -n install bc
    sudo -E zypper -n install util-linux
    sudo -E zypper -n install dmidecode

  # If not supported package manager or no package manager
  else
    echo
    echo "*************************************************************************"
    echo "We couldn't find the appropriate package manager for your system. Please"
    echo "try manually installing the following and rerun this program:"
    echo
    echo "gcc"
    echo "g++"
    echo "gfortran"
    echo "numactl"
    echo "automake"
    echo "*************************************************************************"
    echo
    exit
  fi

  # Disable Transparent Huge Pages
  if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo 'never' > /sys/kernel/mm/transparent_hugepage/enabled
  fi

  sysctl -w vm.stat_interval=10
  sysctl -p -e
}


############################################################
# Rebuilding and installing SPEC CPU2006
############################################################
function rebuildSPECCPU {
  cd "$AUTO_CPU_DIR" || exit
  rm -rfR src

  setup
}


############################################################
# Manually building and installing SPEC CPU2006
############################################################
function buildSPECCPU {
  local rc

  # test external connection
  ((count = 3)) # Maximum number to try.
  while [[ $count -ne 0 ]] ; do
    # Try once.
    ping -c 1 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
    rc=$?
    if [[ $rc -eq 0 ]] ; then
      # If okay, flag to exit loop.
      ((count = 1))
    fi
    ((count = count - 1))
  done


  # if successful external connection
  if [[ $rc -eq 0 ]] ; then
    cd "$AUTO_CPU_DIR/new_system" || exit

    # get the latest versions of config.guess and config.sub
    wget -O config.guess 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
    chmod 775 config.guess
    wget -O config.sub 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
    chmod 775 config.sub
  fi

  cd "$AUTO_CPU_DIR/src/tools/src" || exit

  # Update the config.guess files
  while IFS= read -d $'\0' -r guess_file ; do
    printf 'Updating config.guess file: %s\n' "$guess_file"
    cp "$AUTO_CPU_DIR/new_system/config.guess" "$guess_file"
  done < <(find . -type f -iname 'config.guess' -print0)

  # Update the config.sub files
  while IFS= read -d $'\0' -r sub_file ; do
    printf 'Updating config.sub file: %s\n' "$sub_file"
    cp "$AUTO_CPU_DIR/new_system/config.sub" "$sub_file"
  done < <(find . -type f -iname 'config.sub' -print0)


  echo "Patching..."

  # "Perl in SPEC is broken!" fixes

  if grep -Fxq 'O_CREAT|O_TRUNC/tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666' specinvoke/unix.c ; then
    echo "specinvoke/unix.c is already patched."
  else
    sed -i 's/tmpfile, O_RDWR|O_CREAT|O_TRUNC/tmpfile, O_RDWR|O_CREAT|O_TRUNC, 0666/g' specinvoke/unix.c
  fi

  # shellcheck disable=SC2016
  if grep -Fxq '$startsh -x' perl-5.12.3/makedepend.SH ; then
    # shellcheck disable=SC2016
    echo '"$startsh -x" is already patched.'
  else
    sed -i "s/\$startsh/\$startsh -x/g" perl-5.12.3/makedepend.SH
  fi

  if grep -Fxq 'nset -x' perl-5.12.3/makedepend.SH ; then
    echo '"set -x" is already patched.'
  else
    sed -i "s/\$startsh -x/&\nset -x/" perl-5.12.3/makedepend.SH
  fi

  if grep -Fxq '-Uuse5005threads -Dcccdlflags="-fPIC -shared" -Dlddlflags="-shared -fPIC" -Duseshrplib=true ;' buildtools ; then
    echo "buildtools is already patched."
  else
    sed -i 's|-Uuse5005threads ;|-Uuse5005threads -Dcccdlflags="-fPIC -shared" -Dlddlflags="-shared -fPIC" -Duseshrplib=true ;|g' buildtools
  fi

  echo "Done patching."

  PERLFLAGS="-Uplibpth="

  for i in $(cc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' "\\n" | grep -v /cc); do
    PERLFLAGS+=" -Aplibpth=$i"
  done

  MAKEFLAGS=-j6
  BZIP2CFLAGS=-fPIC
  CC='gcc -std=gnu89'
  FORCE_UNSAFE_CONFIGURE=1

  export FORCE_UNSAFE_CONFIGURE
  export CC
  export BZIP2CFLAGS
  export MAKEFLAGS
  export PERLFLAGS

  # try building
  if ! printf "y\n" | ./buildtools; then
    echo
    echo "Eek! There was a problem with building. Let's try a work around..."
    sleep 10

    # Remove build errors
    find . -type f -exec grep -H '_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");' {} + | awk '{print $1;}' | sed 's/:_GL_WARN_ON_USE//g' | while read -r gl_warn_file; do
      printf 'Fixing _GL_WARN_ON_USE errors: %s\n' "$gl_warn_file"
      sed -i 's/_GL_WARN_ON_USE (gets, "gets is a security hole - use fgets instead");//g' "$gl_warn_file"
    done

    # try to build again
    if ! printf "y\n" | ./buildtools; then
      echo
      echo "There was a problem with building. We cannot find any more work arounds."
      echo "Exiting now."
      echo
      exit
    fi
  fi

  cd ../.. || exit
}


function prebuildAndInstall {
  echo "Extracting SPECCPU..."

  cd "$AUTO_CPU_DIR" || exit

  if [ ! -d "$AUTO_CPU_DIR/src" ]; then
    mkdir "$AUTO_CPU_DIR/src"
  fi

  for file in "$AUTO_CPU_DIR/cpu2006-1.2.tar"*; do
    if [ -e "$file" ]; then
      tar xfv 'cpu2006-1.2.tar'* -C src
      break
    fi
  done

  cd "$AUTO_CPU_DIR/src" || exit

  # try to install, if it fails, build and install manually
  if ! printf 'yes\nyes\nyes\n' | ./install.sh; then
    buildSPECCPU
  fi
}


############################################################
# Setup function to build and install SPEC CPU2006
############################################################
function setup {
  cd "$AUTO_CPU_DIR" || exit

  # If SPECCPU is not extracted
  if [ ! -d "$AUTO_CPU_DIR/src" ]; then
    prebuildAndInstall
  fi

  if [ ! -f "$AUTO_CPU_DIR/src/shrc" ]; then
    rebuildSPECCPU
  fi

  if [ ! -f "$AUTO_CPU_DIR/src/config/linux64-intel64-gcc.cfg" ]; then
    # get additional system info then put it in the config file
    getCache
    getCPUFreq
    getHWDate
    getMemoryInformation
    systemInformationToConfig

    # copy over the config files
    cp -R "$AUTO_CPU_DIR"/config "$AUTO_CPU_DIR"/src/
  fi

  # If SPEC CPU2006 is extracted
  cd "$AUTO_CPU_DIR/src" || exit

  # shellcheck disable=SC1091,SC1090
  source shrc

  # update runspec flags
  runspec --newflags --verbose 7
}
