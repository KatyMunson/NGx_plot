# NGx_plot

An R script for visualizing genome assembly contiguity as an NG(x) plot. Given one or more FASTA index files and a metadata table, it produces a step plot of cumulative contig length (as a percentage of a reference genome size), styled by sample, haplotype, and assembly grade.

Originally developed for comparing SMaHT DSA assemblies against HPRC references and standard reference genomes (T2T-CHM13, hg38).

## Dependencies

R packages (install once via `install.packages`):

```r
install.packages(c("ggplot2", "dplyr", "scales"))
```

## Usage

```bash
Rscript NGx_plot.R <metadata.csv> <assembly1.fai> [assembly2.fai ...]
```

**Example:**

```bash
Rscript NGx_plot.R metadata.csv \
  SMHT004_hap1.fasta.fai \
  SMHT004_hap2.fasta.fai \
  T2T-CHM13v2.fasta.fai \
  hg38.no_alt.fasta.fai
```

The script writes `NGx_plot.pdf` to the current working directory.

## Input files

### Metadata CSV

A comma-separated file describing each assembly. The `assembly` column must match the base name of each `.fai` file (the filename with its `.fai` / `.fa.fai` / `.fa.gz.fai` / `.fasta.fai` extension stripped).

| Column | Required | Description |
|--------|----------|-------------|
| `assembly` | ✅ | Base name of the assembly, used to join with `.fai` filenames |
| `sample` | ✅ | Display name for the sample (used in the legend) |
| `haplotype` | ✅ | Haplotype identifier (e.g. `hap1`, `hap2`); controls line type |
| `grade` | ✅ | Assembly quality tier; controls line width. Must be one of: `ref`, `A+`, `B-`, `hprc_r1`, `hprc_r2` |
| `color` | ✅ | Hex color code assigned to the sample |
| `group` | ➖ | Grouping label (e.g. `reference`, `benchmarking`, `production`, `hprc`); not used directly by the plot but useful for documentation |
| `alpha` | ➖ | Transparency value; currently read from the CSV but not applied in the plot |

See `metadata.csv` for a worked example covering reference genomes, benchmarking assemblies, production SMaHT assemblies, and HPRC samples.

### FAI files

Standard FASTA index files produced by `samtools faidx`. The script expects at least 5 tab-delimited columns, with contig length in column 2.

```bash
samtools faidx my_assembly.fasta   # produces my_assembly.fasta.fai
```

Supported filename patterns for assembly name extraction:

| Filename pattern | Extracted assembly name |
|-----------------|------------------------|
| `name.fasta.fai` | `name` |
| `name.fa.fai` | `name` |
| `name.fa.gz.fai` | `name` |
| `name.fai` | `name` |

## Output

`NGx_plot.pdf` — a 10 × 6 inch PDF. Each line represents one assembly; the x-axis shows the percentage of the reference genome size (hardcoded to 3.1 Gbp for human), and the y-axis shows contig length in Mbp.

Visual encoding:

| Aesthetic | Mapped to |
|-----------|-----------|
| Color | `sample` |
| Line type | `haplotype` |
| Line width | `grade` (`ref` thickest → `hprc_r2` thinnest) |

## Repository contents

| File | Description |
|------|-------------|
| `NGx_plot.R` | Main script |
| `metadata.csv` | Assembly metadata for SMaHT DSA + HPRC + reference genomes |
