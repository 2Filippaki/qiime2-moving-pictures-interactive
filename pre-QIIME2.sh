#!/bin/bash
set -e

# -----------------------------
# Pre-QIIME2 Pipeline: BAM -> FASTQ -> FastQC
# -----------------------------

# Function to check and install dependencies automatically
check_dep() {
    if ! command -v "$1" &> /dev/null; then
        echo " $1 is NOT installed."
        read -p "Would you like to install $1 via conda? (y/n): " choice

        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "Installing $1..."
            conda install -c bioconda "$1" -y
        else
            echo "$1 is required. Exiting."
            exit 1
        fi
    else
        echo -e "\n> $1 is already installed..."
    fi
}

# -----------------------------
# 1. Dependency Checks
# -----------------------------
check_dep samtools
check_dep fastqc
check_dep realpath

# -----------------------------
# 2. Setup Directories
# -----------------------------
BAM_DIR="${1:-.}"
BAM_DIR=$(realpath "$BAM_DIR")

FASTQ_DIR="$BAM_DIR/fastq"
FASTQC_DIR="$BAM_DIR/fastqc_reports"

COMBINED_FASTQ="$BAM_DIR/Combined_FASTQ.fastq.gz"

echo -e "\n ~~~~~~~~~~~~~~~~~"
echo -e "|Working directory|: $BAM_DIR"
echo -e " ~~~~~~~~~~~~~~~~~\n"

mkdir -p "$FASTQ_DIR"
mkdir -p "$FASTQC_DIR"

# -----------------------------
# 3. BAM -> FASTQ Conversion
# -----------------------------
if compgen -G "$FASTQ_DIR/*.fastq.gz" > /dev/null; then
    echo "1. FASTQ files already exist. Skipping conversion."

else
    echo " Converting BAM -> FASTQ..."

    for bam in "$BAM_DIR"/*.bam; do
        [ -e "$bam" ] || continue

        sample=$(basename "$bam" .bam)

        echo "Converting $sample..."

        samtools fastq "$bam" 2> /dev/null | gzip > "$FASTQ_DIR/$sample.fastq.gz"
    done
fi

# -----------------------------
# 4. Reproducible File Renaming
# -----------------------------
MAPPING_FILE="$BAM_DIR/sample_mapping.txt"

if [ -f "$MAPPING_FILE" ]; then
    echo "2. Sample mapping already exists. Skipping renaming step."

else
    echo -e "Original_File\tRenamed_Sample" > "$MAPPING_FILE"

    counter=1

    for f in $(find "$FASTQ_DIR" -name "*.fastq.gz" | sort); do

        num=$(printf "%03d" "$counter")

        original=$(basename "$f")

        if [[ "$f" == *_R1* ]]; then
            new_name="S${num}_R1.fastq.gz"

        elif [[ "$f" == *_R2* ]]; then
            new_name="S${num}_R2.fastq.gz"

        else
            new_name="S${num}.fastq.gz"
        fi

        echo " $original  →  $new_name"

        mv "$f" "$FASTQ_DIR/$new_name"

        echo -e "${original}\t${new_name}" >> "$MAPPING_FILE"

        ((counter++))
    done
fi
# -----------------------------
# 5. Create Combined FASTQ
# -----------------------------
if [ -f "$COMBINED_FASTQ" ]; then
    echo "3. Combined FASTQ already exists. Skipping creation."

else
    echo "Creating combined FASTQ for QC..."

    find "$FASTQ_DIR" \
        -name "*.fastq.gz" \
        -exec cat {} + > "$COMBINED_FASTQ"

    echo " Combined FASTQ created."
fi
# -----------------------------
# 6. FastQC
# -----------------------------
FASTQC_HTML="$FASTQC_DIR/Combined_FASTQ_fastqc.html"

if [ -f "$FASTQC_HTML" ]; then
    echo -e "4. FastQC report already exists. Skipping FastQC.\n"

else
    echo "Running FastQC..."

    fastqc -o "$FASTQC_DIR" "$COMBINED_FASTQ"
fi

echo "===================="
echo "Convertion complete!"
echo -e "====================\n"

echo "FASTQ files: $FASTQ_DIR"
echo "FastQC reports: $FASTQC_DIR"
