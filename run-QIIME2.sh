#!/usr/bin/env bash

set -e

# -----------------------------
# Conda activation
# -----------------------------

CONDA_PATH=$(command -v conda || true)

if [ -z "$CONDA_PATH" ]; then
    echo "Conda not found!"
    exit 1
fi

CONDA_ROOT=$(dirname "$(dirname "$CONDA_PATH")")
CONDA_SH="$CONDA_ROOT/etc/profile.d/conda.sh"

if [ ! -f "$CONDA_SH" ]; then
    echo "conda.sh not found at $CONDA_SH"
    exit 1
fi

source "$CONDA_SH"

mapfile -t envs < <(conda env list | awk '{print $1}' | grep '^qiime2-')

if [ ${#envs[@]} -eq 0 ]; then
    echo "No QIIME2 environments found!"
    exit 1
fi

echo "Available QIIME2 environments:"
for i in "${!envs[@]}"; do
    echo "$((i+1))) ${envs[$i]}"
done

echo
read -p "Select environment number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
   [ "$choice" -lt 1 ] || \
   [ "$choice" -gt "${#envs[@]}" ]; then
    echo "Invalid selection"
    exit 1
fi

SELECTED_ENV="${envs[$((choice-1))]}"

conda activate "$SELECTED_ENV"

echo "Activated: $SELECTED_ENV"

# -----------------------------
# Checkpoints
# -----------------------------

CHECKPOINT_FILE="checkpoints.txt"
touch "$CHECKPOINT_FILE"

has_completed() {
    grep -Fxq "$1" "$CHECKPOINT_FILE"
}

# -----------------------------
# FASTQ check/confirmation & Step 1 Import
# -----------------------------
MANIFEST_IMPORT="manifestOld.tsv"
MANIFEST="manifest.tsv"
OUTPUT="demuxUntr.qza"

if grep -Fxq "step1_import" "$CHECKPOINT_FILE"; then
    echo -e "\nStep 1 already completed (from checkpoint). Skipping import stage."
    SKIP_STEP1=true
else
    SKIP_STEP1=false

    shopt -s nullglob
    fastq_files=(*.fastq *.fastq.gz *.fq)
    shopt -u nullglob

    count=${#fastq_files[@]}

    if [ "$count" -eq 0 ]; then
        echo "Error: No FASTQ files found in the current directory."
        echo "Please put FASTQ files in the current directory and try again."
        exit 1
    fi

    echo "Found $count FASTQ file(s)."
    printf '%s\n' "${fastq_files[@]}"

    read -p "Do you want to proceed with QIIME2 import? (y/n): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 1
    fi

    echo "Proceeding with pipeline..."

    # Detect paired-end pattern
    has_r1=false
    has_r2=false
    for f in "${fastq_files[@]}"; do
        [[ "$f" == *R1* || "$f" == *_1* ]] && has_r1=true
        [[ "$f" == *R2* || "$f" == *_2* ]] && has_r2=true
    done

    echo "---- Paired-end detection report ----"
    [ "$has_r1" = true ] && echo "✔ R1 files found" || echo "✖ No R1 files found"
    [ "$has_r2" = true ] && echo "✔ R2 files found" || echo "✖ No R2 files found"

    if [ "$has_r1" = true ] && [ "$has_r2" = true ]; then
        paired=true
    else
        paired=false
    fi
    echo "Final decision: paired = $paired"

    # Manifest creation
    [ -f "$MANIFEST" ] && cp "$MANIFEST" manifest_old.tsv

    if [ "$paired" = true ]; then
        echo "Detected: PAIRED-END"
        echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > "$MANIFEST"
        for f in "${fastq_files[@]}"; do
            if [[ "$f" == *_R1* || "$f" == *_1* ]]; then
                sample=$(basename "$f" | sed 's/_R1.*//;s/_1.*//')
                r1=$(realpath "$f")
                r2="${f/_R1/_R2}"
                r2="${r2/_1/_2}"
                if [ -f "$r2" ]; then
                    r2=$(realpath "$r2")
                    echo -e "${sample}\t${r1}\t${r2}" >> "$MANIFEST"
                else
                    echo "Warning: missing R2 for sample ${sample}"
                fi
            fi
        done
    else
        echo "Detected: SINGLE-END"
        echo -e "sample-id\tabsolute-filepath" > "$MANIFEST"
        for f in "${fastq_files[@]}"; do
            sample=$(basename "$f" | sed 's/\.[^.]*$//')
            abs=$(realpath "$f")
            echo -e "${sample}\t${abs}" >> "$MANIFEST"
        done
    fi

    echo "Manifest created: $MANIFEST"
    cat "$MANIFEST"
    cp "$MANIFEST" manifestOld.tsv
    echo "Backup created: manifestOld.tsv"

    echo "--> Importing FASTQ into QIIME2..."
    if [ "$paired" = true ]; then
        qiime tools import \
          --type 'SampleData[PairedEndSequencesWithQuality]' \
          --input-path "$MANIFEST_IMPORT" \
          --output-path "$OUTPUT" \
          --input-format PairedEndFastqManifestPhred33V2
    else
        qiime tools import \
          --type 'SampleData[SequencesWithQuality]' \
          --input-path "$MANIFEST_IMPORT" \
          --output-path "$OUTPUT" \
          --input-format SingleEndFastqManifestPhred33V2
    fi

    qiime demux summarize \
      --i-data "$OUTPUT" \
      --o-visualization "demuxUntr.qzv"

    echo "step1_import" >> "$CHECKPOINT_FILE"
    echo "Step 1 completed"
fi

if [ "$SKIP_STEP1" = "false" ] || [ ! -f "manifest_edited" ]; then
    echo ""
    echo "=============================="
    echo "MANIFEST EDIT"
    echo "=============================="
    read -p "Do you want to edit the manifest now? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        echo "Saving checkpoint and exiting..."
        echo "manifest_edited" >> "$CHECKPOINT_FILE"
        echo "Please edit this file: $MANIFEST"
        exit 0
    fi
    echo "Continuing with existing manifest..."
fi

# -----------------------------
# Step 2: DADA2
# -----------------------------
MANIFEST=$(realpath manifest.tsv)

    DEMUX="demuxUntr.qza"
    TABLE="table-dada2.qza"
    REPSEQ="rep-seqs-dada2.qza"
    STATS="stats-dada2.qza"

if has_completed "step2_dada2"; then
    echo -e "\nStep 2 already completed. Skipping..."
else
    echo "Step 2: DADA2 denoising interactive setup"


    if head -n 1 manifestOld.tsv | grep -q "forward-absolute-filepath"; then
        paired=true
    else
        paired=false
    fi

    echo "Recovered paired status: $paired"

    if [ ! -f "$DEMUX" ]; then
        echo "Input artifact not found: $DEMUX"
        exit 1
    fi

    echo "Detected demux file: $DEMUX"

    echo "trunc-len:"
    echo "- Truncates reads at a specific position."
    echo "- Lower values remove low-quality tails."
    echo "- 0 = no truncation."
    while true; do
        read -p "Enter trunc-len (0=no truncation): " trunc_len
        if [[ "$trunc_len" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid trunc-len. Must be a non-negative integer."
        fi
    done

    echo "trim-left:"
    echo "- Removes bases from the start of each read."
    while true; do
        read -p "Enter trim-left (default 0): " trim_left
        trim_left=${trim_left:-0}
        if [[ "$trim_left" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid trim-left. Must be a non-negative integer."
        fi
    done

    echo "max-ee:"
    echo "- Maximum expected errors allowed per read."
    while true; do
        read -p "Enter max-ee (default 2): " max_ee
        max_ee=${max_ee:-2}
        if [[ "$max_ee" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            break
        else
            echo "Invalid max-ee. Must be a number."
        fi
    done

    echo "trunc-q:"
    echo "- Truncates reads at first quality score ≤ value."
    while true; do
        read -p "Enter trunc-q (default 2): " trunc_q
        trunc_q=${trunc_q:-2}
        if [[ "$trunc_q" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid trunc-q. Must be a positive integer."
        fi
    done

    echo "max-len:"
    read -p "Enter max-len (leave empty for no limit): " max_len

    while true; do
        echo "Select pooling method:"
        echo "1) pseudo (default)"
        echo "2) independent"
        echo "3) full"
        read -p "Choice [1-3]: " pool_choice
        case $pool_choice in
            1|"") pooling="pseudo"; break ;;
            2) pooling="independent"; break ;;
            3) pooling="full"; break ;;
            *) echo "Invalid choice, try again." ;;
        esac
    done

    while true; do
        echo "Select chimera method:"
        echo "1) consensus (default)"
        echo "2) pooled"
        echo "3) none"
        read -p "Choice [1-3]: " chimera_choice
        case $chimera_choice in
            1|"") chimera="consensus"; break ;;
            2) chimera="pooled"; break ;;
            3) chimera="none"; break ;;
            *) echo "Invalid choice, try again." ;;
        esac
    done

    while true; do
        read -p "Enter n-reads-learn (default 100000): " n_reads
        n_reads=${n_reads:-100000}
        if [[ "$n_reads" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "Invalid value, must be a positive integer."
        fi
    done

    if [ "$paired" = false ]; then
        echo ""
        echo "Select sequencing platform:"
        echo "1) Illumina"
        echo "2) Ion Torrent / 454"

        while true; do
            read -p "Choice [1-2]: " platform_choice
            case $platform_choice in
                1) platform="illumina"; break ;;
                2) platform="pyro"; break ;;
                *) echo "Invalid choice, try again." ;;
            esac
        done
    else
        platform="illumina"
        echo "Paired-end data detected → using Illumina DADA2 mode"
    fi

    if [ "$platform" = "illumina" ]; then
        if [ "$paired" = true ]; then
            CMD="qiime dada2 denoise-paired \
              --i-demultiplexed-seqs $DEMUX \
              --p-trim-left-f $trim_left \
              --p-trim-left-r $trim_left \
              --p-trunc-len-f $trunc_len \
              --p-trunc-len-r $trunc_len \
              --p-max-ee $max_ee \
              --p-trunc-q $trunc_q \
              --p-pooling-method $pooling \
              --p-chimera-method $chimera \
              --p-n-reads-learn $n_reads \
              --o-table $TABLE \
              --o-representative-sequences $REPSEQ \
              --o-denoising-stats $STATS"
        else
            CMD="qiime dada2 denoise-single \
              --i-demultiplexed-seqs $DEMUX \
              --p-trim-left $trim_left \
              --p-trunc-len $trunc_len \
              --p-max-ee $max_ee \
              --p-trunc-q $trunc_q \
              --p-pooling-method $pooling \
              --p-chimera-method $chimera \
              --p-n-reads-learn $n_reads \
              --o-table $TABLE \
              --o-representative-sequences $REPSEQ \
              --o-denoising-stats $STATS"
        fi
    else
        CMD="qiime dada2 denoise-pyro \
          --i-demultiplexed-seqs $DEMUX \
          --p-trunc-len $trunc_len \
          --p-trim-left $trim_left \
          --p-max-ee $max_ee \
          --p-trunc-q $trunc_q \
          --p-pooling-method $pooling \
          --p-chimera-method $chimera \
          --p-n-reads-learn $n_reads \
          --o-table $TABLE \
          --o-representative-sequences $REPSEQ \
          --o-denoising-stats $STATS"
    fi

    if [ -n "$max_len" ]; then
        CMD="$CMD --p-max-len $max_len"
    fi

    echo -e "\nRunning DADA2 with command:\n$CMD\n"
    eval "$CMD"
    echo "step2_dada2" >> "$CHECKPOINT_FILE"
fi

# -----------------------------
# Step 2b: Visualizations
# -----------------------------
if has_completed "step2b_dada2"; then
    echo -e "\nStep 2b already completed. Skipping..."
else
    echo "Step 2b: Summarizing DADA2 outputs..."

    if [ -f "$STATS" ]; then
        qiime metadata tabulate --m-input-file "$STATS" --o-visualization stats-dada2.qzv
    fi

    if [ -f "$TABLE" ]; then
        qiime feature-table summarize --i-table "$TABLE" --o-visualization table-dada2.qzv --m-sample-metadata-file "$MANIFEST"
    fi

    if [ -f "$REPSEQ" ]; then
        qiime feature-table tabulate-seqs --i-data "$REPSEQ" --o-visualization rep-seqs-dada2.qzv
    fi

    echo "step2b_dada2" >> "$CHECKPOINT_FILE"
fi

# -----------------------------
# Step 3: Taxonomy
# -----------------------------
if grep -Fxq "step3_taxonomy" "$CHECKPOINT_FILE"; then
    echo -e "\nStep 3 already completed. Skipping taxonomy assignment..."
else
    echo "STEP 3 — Taxonomic assignment"
    read -p "Do you want to perform taxonomic classification? (y/n): " do_tax

    if [[ "$do_tax" =~ ^[Yy]$ ]]; then
        read -p "Do you have QIIME2 reference artifacts (.qza)? (y/n): " has_qza

        if [[ "$has_qza" =~ ^[Yy]$ ]]; then
            while true; do
                read -p "Reference sequences (.qza): " REF_SEQS
                [[ -f "$REF_SEQS" ]] && break
                echo "File not found."
            done
            while true; do
                read -p "Reference taxonomy (.qza): " REF_TAX
                [[ -f "$REF_TAX" ]] && break
                echo "File not found."
            done
        else
            while true; do
                read -p "Reference sequences FASTA: " RAW_FASTA
                [[ -f "$RAW_FASTA" ]] && break
                echo "File not found."
            done
            while true; do
                read -p "Reference taxonomy TSV: " RAW_TAX
                [[ -f "$RAW_TAX" ]] && break
                echo "File not found."
            done

            REF_SEQS="reference-seqs.qza"
            REF_TAX="reference-tax.qza"

            qiime tools import --type 'FeatureData[Sequence]' --input-path "$RAW_FASTA" --output-path "$REF_SEQS"
            qiime tools import --type 'FeatureData[Taxonomy]' --input-path "$RAW_TAX" --input-format HeaderlessTSVTaxonomyFormat --output-path "$REF_TAX"
        fi

        read -p "Percent identity [0.77]: " PERC_IDENTITY
        PERC_IDENTITY=${PERC_IDENTITY:-0.77}

        read -p "Query coverage [0.95]: " QUERY_COV
        QUERY_COV=${QUERY_COV:-0.95}

        read -p "Maximum accepts [1]: " MAX_ACCEPTS
        MAX_ACCEPTS=${MAX_ACCEPTS:-1}

        TAXONOMY="taxonomy.qza"
        BLAST_RESULTS="blast-results.qza"

        qiime feature-classifier classify-consensus-blast \
          --i-query "$REPSEQ" \
          --i-reference-reads "$REF_SEQS" \
          --i-reference-taxonomy "$REF_TAX" \
          --p-perc-identity "$PERC_IDENTITY" \
          --p-query-cov "$QUERY_COV" \
          --p-maxaccepts "$MAX_ACCEPTS" \
          --o-classification "$TAXONOMY" \
          --o-search-results "$BLAST_RESULTS"

        qiime metadata tabulate --m-input-file "$TAXONOMY" --o-visualization taxonomy.qzv
        qiime taxa barplot --i-table "$TABLE" --i-taxonomy "$TAXONOMY" --m-metadata-file "$MANIFEST" --o-visualization taxa-barplot.qzv

        echo "step3_taxonomy" >> "$CHECKPOINT_FILE"
    else
        echo "Skipping Step 3 — proceeding to Step 4..."
    fi
fi

# -----------------------------
# Step 4: Phylogeny & Diversity
# -----------------------------
if grep -Fxq "step4_core_metrics" "$CHECKPOINT_FILE"; then
    echo -e "\nStep 4 already completed. Skipping..."
else
    echo "STEP 4 — Phylogeny & Diversity"
    if [ ! -f "$REPSEQ" ] || [ ! -f "$TABLE" ]; then
        echo "Required inputs not found."
        exit 1
    fi

    qiime phylogeny align-to-tree-mafft-fasttree \
      --i-sequences "$REPSEQ" \
      --o-alignment aligned-rep-seqs.qza \
      --o-masked-alignment masked-aligned-rep-seqs.qza \
      --o-tree unrooted-tree.qza \
      --o-rooted-tree rooted-tree.qza

    while true; do
        read -p "Enter sampling depth for diversity metrics: " depth
        [[ "$depth" =~ ^[0-9]+$ ]] && break
        echo "Invalid value."
    done

    qiime diversity core-metrics-phylogenetic \
      --i-phylogeny rooted-tree.qza \
      --i-table "$TABLE" \
      --p-sampling-depth "$depth" \
      --m-metadata-file "$MANIFEST" \
      --output-dir core-metrics-results

    qiime diversity alpha-rarefaction \
      --i-table "$TABLE" \
      --i-phylogeny rooted-tree.qza \
      --p-max-depth "$depth" \
      --m-metadata-file "$MANIFEST" \
      --o-visualization alpha-rarefaction.qzv

    echo "step4_core_metrics" >> "$CHECKPOINT_FILE"
fi

# -----------------------------
# Step 5: Alpha Diversity
# -----------------------------
if grep -Fxq "step5_alpha" "$CHECKPOINT_FILE"; then
    echo -e  "\nStep 5 already completed. Skipping..."
else
    echo "STEP 5 — Alpha Diversity"
    ALPHA_DIR="alpha-metrics"
    mkdir -p "$ALPHA_DIR"
    RARE_TABLE="core-metrics-results/rarefied_table.qza"

    METRICS=(observed_features chao1 shannon simpson pielou_e)

    for m in "${METRICS[@]}"; do
        echo "Computing $m..."
        qiime diversity alpha \
          --i-table "$RARE_TABLE" \
          --p-metric "$m" \
          --o-alpha-diversity "$ALPHA_DIR/${m}_vector.qza"
    done

    echo "Computing faith_pd (using phylogenetic tree)..."
    qiime diversity alpha-phylogenetic \
      --i-table "$RARE_TABLE" \
      --i-phylogeny rooted-tree.qza \
      --p-metric faith_pd \
      --o-alpha-diversity "$ALPHA_DIR/faith_pd_vector.qza"
qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/chao1_vector.qza" \
  --o-visualization "$ALPHA_DIR/chao1_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/observed_features_vector.qza" \
  --o-visualization "$ALPHA_DIR/observed_features_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/shannon_vector.qza" \
  --o-visualization "$ALPHA_DIR/shannon_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/faith_pd_vector.qza" \
  --o-visualization "$ALPHA_DIR/faith_pd_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/pielou_e_vector.qza" \
  --o-visualization "$ALPHA_DIR/pielou_e_vector.qzv"

qiime metadata tabulate \
  --m-input-file "$ALPHA_DIR/simpson_vector.qza" \
  --o-visualization "$ALPHA_DIR/simpson_vector.qzv"

    echo "All alpha metrics computed successfully."
    echo "step5_alpha" >> "$CHECKPOINT_FILE"
fi

# -----------------------------
# Step 6: Beta Diversity
# -----------------------------
if grep -Fxq "step6_beta" "$CHECKPOINT_FILE"; then
    echo -e "\nStep 6 already completed. Skipping..."
else
    echo "STEP 6 — Beta Diversity"
    BETA_DIR="core-metrics-results"

    if [ ! -d "$BETA_DIR" ]; then
        echo "Core metrics results not found. Run Step 4 first."
        exit 1
    fi

qiime diversity beta-group-significance \
  --i-distance-matrix "$BETA_DIR/bray_curtis_distance_matrix.qza" \
  --m-metadata-file manifest.tsv \
  --m-metadata-column treatment \
  --o-visualization "$BETA_DIR/bray_curtis_significance.qzv" \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix "$BETA_DIR/jaccard_distance_matrix.qza" \
  --m-metadata-file manifest.tsv \
  --m-metadata-column treatment \
  --o-visualization "$BETA_DIR/jaccard_significance.qzv" \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix "$BETA_DIR/unweighted_unifrac_distance_matrix.qza" \
  --m-metadata-file manifest.tsv \
  --m-metadata-column treatment \
  --o-visualization "$BETA_DIR/unweighted_unifrac_significance.qzv" \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix "$BETA_DIR/weighted_unifrac_distance_matrix.qza" \
  --m-metadata-file manifest.tsv \
  --m-metadata-column treatment \
  --o-visualization "$BETA_DIR/weighted_unifrac_significance.qzv" \
  --p-pairwise

    echo "Beta diversity outputs available in: $BETA_DIR"
    echo "step6_beta" >> "$CHECKPOINT_FILE"
fi
mkdir -p qza qzv

shopt -s nullglob

qza_files=(*.qza)
qzv_files=(*.qzv)

[ ${#qza_files[@]} -gt 0 ] && mv *.qza qza/
[ ${#qzv_files[@]} -gt 0 ] && mv *.qzv qzv/

shopt -u nullglob

echo -e "\nAll done!!\nThank you and enjoy the results!\nIf you have any issues, feel free to contact us anytime."
