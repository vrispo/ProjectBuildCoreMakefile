Da terminale mi posizione nella cartella dove voglio creare il min_core_name.gz
Eseguo il Makefile così:
    make -f PATH_SOURCE_DIR/Makefile FILE_NAME="min_core_name" S_DIR="PATH_SOURCE_DIR"

con PATH_SOURCE_DIR = path relative or absolute where the project files and directory are (default value: ../Progetto)
    min_core_name   = name wanted per the initramfs generated (default value: minimal_core)

Ad esempio:
    make -f ../SorgentiProgetto/Makefile S_DIR="../SorgentiProgetto" FILE_NAME="min_core_name"
