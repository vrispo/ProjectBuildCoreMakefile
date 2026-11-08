# ProjectBuildCoreMakefile

A Makefile-based tool to generate a minimal initramfs (`core.gz`) for booting
Linux virtual machines under QEMU/KVM. The initramfs is built on BusyBox and
includes automated shared library resolution and cross-compilation support for
x86/x86_64 targets.

Developed as part of the Component-Based Software Design course (M.Sc. in
Embedded Computing Systems, University of Pisa / Scuola Superiore Sant'Anna).

## Usage

From the directory where you want to generate the initramfs, run:

    make -f PATH_SOURCE_DIR/Makefile FILE_NAME="min_core_name" S_DIR="PATH_SOURCE_DIR"

where:
- `PATH_SOURCE_DIR`: relative or absolute path to the project source directory (default: `../Progetto`)
- `min_core_name`: name for the generated initramfs file (default: `minimal_core`)

**Example:**

    make -f ../SourcesDir/Makefile S_DIR="../SourcesDir" FILE_NAME="min_core_name"
