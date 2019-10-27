# Automated SPEC CPU2006

This harness performs [SPEC CPU2006](http://spec.org/cpu2006/) benchmarking using GCC 4.8. Capabilities include installing prerequisites, building and installing SPEC CPU2006, and running reportable integer and floating-point runs.

**NOTE**: This does ***not*** include SPEC CPU2006. This is merely a harness to ease the setup and running of the benchmark for GCC. The configuration files provided probably won't give you the maximum possible scores. They are generic configuration files. Some system specific optimizations might be included but min-maxing will be left to you.

## Contents

+ [Setup](#setup)
+ [Usage](#usage)
+ [File Tree](#file-tree)
+ [Errors](#errors)

## Setup

To download these files, first install git:

```bash
sudo yum install git
# Or if you are using a Debian-based distribution:
sudo apt-get install git
```

Clone this repository and setup:

```bash
git clone http://github.com/ryanspoone/autocpu2006.git
cd autocpu2006/
chmod +x autocpu2006
```

## Usage

Switch to root:

```bash
sudo su
```

Change to directory where this automation is located are, then start benchmarking by issuing the following command:

```bash
./autocpu2006 [OPTIONS]
```

Where the options are:

| Option     | GNU long option   | Meaning                                                                                                                                                                                              |
|------------|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -h         | --help            | Show available flags.                                                                                                                                                                                |
| -s         | --speed           | Run runspec speed. Default is rate.                                                                                                                                                                  |
| -g         | --ignore          | Ignore runspec build errors.                                                                                                                                                                         |
| -r         | --rebuild         | Delete the current SPEC CPU2006 installation, then rebuild and install a fresh copy.                                                                                                                 |
| -b         | --build-only      | Only build, if necessary, and install CPU2006 then quit.                                                                                                                                             |
| -o         | --one-copy        | Do a single copy run. This is the equivalent to `-c 1` or `--copies 1`.                                                                                                                              |
| -i         | --integer         | Run integer micro-benchmarks.                                                                                                                                                                        |
| -f         | --floating-point  | Run floating-point micro-benchmarks.                                                                                                                                                                 |
| -m [name]  | --machine [name]  | Manually set the machine setting. This is to try and future proof the harness as much as possible. Read this as the `-march=[name]` flag.                                                            |
| -c [n]     | --copies [n]      | Override the number of copies to use.                                                                                                                                                                |
| -T [n]     | --iterations [n]  | Override the number of iterations to use. This will also force the run to ignore errors. This is for quick, non-reportable runs.                                                                     |
| -t [range] | --taskset [range] | Set the core IDs to test (e.g., 0,2,5,6-10). Note that there are not spaces between the core IDs.                                                                                                    |
| -a         | --no-affinity     | Disable `taskset` and `numactl` for runs. By default, `numactl` is used. If the `numactl` is not installed, `taskset` will be used. If neither are installed, this option will be automatically set. |
| -p         | --prerequisites   | Install prerequisites. This requires an Internet connection.                                                                                                                                         |
| -n         | --info-only       | Display system and configuration information only.                                                                                                                                                   |

## File tree

```text
|-- config
|   |-- linux32-arm32-gcc.cfg
|   |-- linux32-intel32-gcc.cfg
|   |-- linux64-arm64-gcc.cfg
|   |-- linux64-intel64-gcc.cfg
|   |-- linux64-powerpc-gcc.cfg
|    `- flags/
|       |-- linux-arm32-gcc.xml
|       |-- linux-arm64-gcc.xml
|       |-- linux-intel32-gcc.xml
|       |-- linux-intel64-gcc.xml
|        `- linux-powerpc-gcc.xml
|-- src (where all cpu2006 files will be located)
|-- lib
|   |-- setup.sh
|   |-- system_info.sh
|    `- user_input.sh
|-- new_system
|   |-- config.guess
|    `- config.sub
|-- tests
|   |-- test_invalid_machine.sh
|    `- test_system_info.sh
|-- autocpu2006 (main script to call)
|-- cpu2006-1.2.tar.xz (main cpu2006 files, you provide these)
 `- README.md (this file)
```

## Operating Systems

1. Ubuntu 14.04+
    + Heavily tested
1. CentOS 7+
    + Lightly tested
1. RHEL 6.5+
    + Lightly tested
1. OpenSUSE
    + Lightly tested

I mostly tested on Ubuntu because they allowed me to easily install the latest version of the GNU suite, which allowed me to test on next-gen systems, and also, from our tests, had the best performance gains.

## Errors

`copy 0 non-zero return code` or other build errors.

This could be caused by multiple things. I've seen it from overclocking, from wrong optimizations (especially in newer GCC versions), and also portability issues.

For changing the portability options for that benchmark. Here are some options:

+ `-DSPEC_CPU_LP64` - This macro specifies that the target system uses the LP64 data model; specifically, that integers are 32 bits, while longs and pointers are 64 bits.
+ `-DSPEC_CPU_LINUX` - This macro indicates that the benchmark is being compiled on a system running Linux.
+ `-DSPEC_CPU_LINUX_X64` - This macro indicates that the benchmark is being compiled on an AMD64-compatible system running the Linux operating system.
+ `-DSPEC_CPU_LINUX_IA32` - This macro indicates that the benchmark is being compiled on an Intel IA32-compatible system running the Linux operating system.

Some more helpful portability flags are located here: [http://www.spec.org/auto/cpu2006/flags/400.perlbench.flags.html](http://www.spec.org/auto/cpu2006/flags/400.perlbench.flags.html)
