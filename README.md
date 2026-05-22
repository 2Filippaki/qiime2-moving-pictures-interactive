# qiime2-moving-pictures-interactive
Interactive QIIME2 amplicon analysis pipeline inspired by the Moving Pictures tutorial.

---

## Overview
This project is an interactive Next-Generation Sequencing (NGS) amplicon analysis pipeline built on top of QIIME2. It is designed to take raw FASTQ sequencing data and guide the user step-by-step through a complete amplicon sequencing data analysis workflow — from raw reads to taxonomic profiling and downstream diversity analysis.

The pipeline is inspired by the QIIME2 "Moving Pictures" tutorial and extends it into a fully interactive, checkpoint-based Bash workflow that can be run locally in a Conda/QIIME2 environment.
The official QIIME2 Moving Pictures tutorial: https://amplicon-docs.qiime2.org/en/stable/tutorials/moving-pictures/

---
# Disclaimer

This workflow is intended for research and educational purposes.
Users are responsible for validating parameters, reference databases,
and biological interpretations for their specific datasets.

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

---

# Viewing FastQC Reports

FastQC reports are generated automatically inside:

```text
fastqc_reports/
```

To open a report:

1. Navigate to the `fastqc_reports` directory
2. Open the `.html` file in your web browser
   

The report includes:

- Per-base sequence quality
- GC content
- Sequence length distribution
- Adapter content
- Overrepresented sequences
- General sequencing quality metrics

Here is an external guide that may help you interpret FastQC reports:

https://bioinfo.cd-genomics.com/quality-control-how-do-you-read-your-fastqc-results.html

---
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

---

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

---

**Requirements**

- Linux / WSL
- Miniconda
- QIIME2 (2024.10 amplicon distribution)
- Recommended: ≥8 GB RAM 
- Storage: depends on dataset size (FASTQ + QIIME2 artifacts)
OUTPUT FILES HELPER

---

**GENERAL QIIME2 OUTPUTS**

demuxUntr.qza → raw sequencing reads and quality scores for each sample

table-dada2.qza → abundance of each ASV in every sample (community composition)

rep-seqs-dada2.qza → unique ASV nucleotide sequences detected after denoising

stats-dada2.qza → read retention and filtering performance during DADA2 processing

taxonomy.qza → taxonomic identity of ASVs (Kingdom → Species)

blast-results.qza → closest database matches and sequence similarity for ASVs

aligned-rep-seqs.qza → multiple sequence alignment showing nucleotide similarities among ASVs

masked-aligned-rep-seqs.qza → cleaned alignment excluding highly variable positions

unrooted-tree.qza → evolutionary relationships among ASVs before rooting

rooted-tree.qza → rooted phylogenetic relationships used for phylogenetic diversity metrics

---

**ALPHA DIVERSITY (alpha-metrics/)**

observed_features_vector → number of unique ASVs/features detected per sample (richness)

chao1_vector → estimated species richness including rare/undetected taxa

shannon_vector → diversity considering both richness and evenness

simpson_vector → dominance/diversity metric emphasizing abundant taxa

pielou_e_vector → evenness of taxa distribution within each sample

faith_pd_vector → phylogenetic diversity based on evolutionary distances among ASVs

---

**CORE METRICS / BETA DIVERSITY (core-metrics-results/)**

rarefied_table.qza → rarefied ASV abundance table normalized to equal sequencing depth

bray_curtis_distance_matrix.qza → compositional dissimilarity between samples based on ASV abundance

jaccard_distance_matrix.qza → presence/absence dissimilarity between samples

weighted_unifrac_distance_matrix.qza → phylogenetic beta diversity weighted by ASV abundance

unweighted_unifrac_distance_matrix.qza → phylogenetic beta diversity based on presence/absence

*_pcoa_results.qza → Principal Coordinates Analysis (PCoA) coordinates for sample clustering

*_emperor.qzv → interactive 3D Emperor plots visualizing beta diversity clustering

*_significance.qzv → PERMANOVA statistical tests comparing groups based on beta diversity

observed_features_vector.qza → observed ASV richness per sample

faith_pd_vector.qza → phylogenetic alpha diversity per sample

shannon_vector.qza → alpha diversity considering richness and evenness

evenness_vector.qza → taxa distribution uniformity within samples  

---

**Note:** 
This workflow has been primarily tested and validated on Ion Torrent single-end 16S rRNA gene microbiome datasets.

Illumina and paired-end support are implemented, but further validation across diverse datasets is ongoing.

---

## Learning Resources

A helpful video workshop series for understanding QIIME2 workflows:

https://youtube.com/playlist?list=PLbVDKwGpb3XmkQmoBy1wh3QfWlWdn_pTT&si=bwsxcEY8KHAWRM4g

---

**Contact**
For bug reports or suggestions:
 [fragoulafilippaki@gmail.com](mailto:fragoulafilippaki@gmail.com)

