# qiime2-moving-pictures-interactive
Interactive QIIME2 amplicon analysis pipeline inspired by the Moving Pictures tutorial.

---

## Overview
This project is an interactive Next-Generation Sequencing (NGS) amplicon analysis pipeline built on top of QIIME2. It is designed to take raw FASTQ sequencing data and guide the user step-by-step through a complete amplicon sequencing data analysis workflow — from raw reads to taxonomic profiling and downstream diversity analysis.

The pipeline is inspired by the QIIME2 "Moving Pictures" tutorial and extends it into a fully interactive, checkpoint-based Bash workflow that can be run locally in a Conda/QIIME2 environment.

---

**What this pipeline does**

This script automates and simplifies the following workflow:

* FASTQ file detection and validation
* Automatic generation of QIIME2 manifest files
* Import of sequencing data into QIIME2
* DADA2 denoising (ASV generation)
* Taxonomic classification
* Alpha and beta diversity analysis
* Generation of QIIME2 visualizations (`.qzv`)
* Checkpoint system 

---

**How to view results (`.qzv` files)**

All QIIME2 visualization files (`.qzv`) can be viewed using the official QIIME2 visualization platform:
 [QIIME2 View](https://view.qiime2.org)

Simply drag and drop your `.qzv` files into the page to explore interactive plots and tables.

---

## Installation

### 1. Install Miniconda
  ```bash
wget [https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh](https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh)
  ```
  ```bash
Miniconda3-latest-Linux-x86_64.sh
  ```
**Note: Restart your terminal after installation.**

2. Download QIIME2 environment file
  ```Bash
wget [https://raw.githubusercontent.com/qiime2/distributions/dev/2024.10/amplicon/released/qiime2-amplicon-ubuntu-latest-conda.yml](https://raw.githubusercontent.com/qiime2/distributions/dev/2024.10/amplicon/released/qiime2-amplicon-ubuntu-latest-conda.yml)
  ```
3. Create QIIME2 environment
  ```Bash
conda env create -n qiime2-amplicon-2024.10 --file qiime2-amplicon-ubuntu-latest-conda.yml
  ```
4. Activate environment
  ```Bash
conda activate qiime2-amplicon-2024.10
  ```



---

### Preprocessing & Metadata

**Data Preprocessing**
If your input data is in BAM format, you can convert or preprocess it using the helper script:
```Bash
./pre-QIIME2.sh
```
This script performs the following critical steps:

   Compatibility: Converts BAM files to FASTQ format.

   Standardization: Renames files for easy identification.

   Quality Assurance: Runs FastQC on your combined dataset to ensure data integrity.

*Note: If you already have your FASTQ files, this script will automatically skip the conversion step but will still run the Quality Control report.*

**Metadata handling** (manifest)

The manifest.tsv file is automatically generated during FASTQ import and is intended to be manually edited by the user if needed.
  
  • After import, the manifest can be modified to include additional sample metadata (e.g., grouping variables, conditions, environmental data).
  
  • This edited manifest is then used as a metadata file in downstream QIIME2 analyses to simplify and enrich statistical interpretation.    
  
  • For safety, a backup of the original manifest is always retained as manifestOld.tsv.

How to use this pipeline
  
1. Clone the repository:
   ```bash
   git clone [https://github.com/2Filippaki/qiime2-moving-pictures-interactive.git](https://github.com/2Filippaki/qiime2-moving-pictures-interactive.git)
     ```
   Move to the repository:
   ```bash
   cd qiime2-moving-pictures-interactive
     ```
2. Make the script executable:
   ```Bash
   chmod +x run-QIIME2.sh
  
3. Run the pipeline:
    ```Bash
    ./run-QIIME2.sh
      ```       

**The script will automatically:**
* Detect FASTQ files
* Build manifest files
* Import data into QIIME2
* Guide you through DADA2 parameters
* Run taxonomy and diversity analysis
* Save checkpoints for resuming runs

---

**Supported sequencing data**
* Illumina (single-end & paired-end)
* Ion Torrent
* 454 pyrosequencing

**Requirements**

- Linux / WSL
- Miniconda
- QIIME2 (2024.10 amplicon distribution)
- Recommended: ≥8 GB RAM 
- Storage: depends on dataset size (FASTQ + QIIME2 artifacts)
  

**Note:** 
This workflow has been primarily tested and validated on Ion Torrent single-end 16S rRNA gene microbiome datasets.

Illumina and paired-end support are implemented, but further validation across diverse datasets is ongoing.

---

**Contact**
For bug reports or suggestions:
 [fragoulafilippaki@gmail.com](mailto:fragoulafilippaki@gmail.com)

