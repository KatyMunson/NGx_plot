# NGx_plot

An R script for visualizing genome assembly contiguity as an NG(x) plot. Given a manifest of FASTA index files, it produces a step plot of cumulative contig length (as a percentage of a reference genome size), styled by sample, haplotype, and assembly grade.

Originally developed for comparing SMaHT DSA assemblies against HPRC references and standard reference genomes (T2T-CHM13, hg38).

## Dependencies

R packages (install once via `install.packages`):

```r
install.packages(c("ggplot2", "dplyr", "scales"))
```

## Usage

```bash
Rscript NGx_plot.R manifest.csv
```

The script writes `NGx_plot.pdf` (or the filename set in `NGx_plot.conf`) to the current working directory.

## Input files

### `manifest.csv`

A comma-separated file where each row describes one assembly. The `fai_path` column replaces the need to list `.fai` files on the command line.

| Column | Required | Description |
|--------|----------|-------------|
| `sample` | ✅ | Sample identifier used for legend grouping and color lookup |
| `haplotype` | ✅ | Haplotype identifier (e.g. `hap1`, `hap2`); controls line type |
| `grade` | ✅ | Assembly quality tier; controls line width and alpha. See `NGx_plot.conf` for defined grades |
| `fai_path` | ✅* | Path to the `.fai` file. Relative paths are resolved from the directory containing `manifest.csv`. *Leave blank in the committed file; fill in locally before running |
| `label` | ➖ | Legend label for this assembly. Empty → auto-built as `"<sample> <haplotype>"` |
| `color` | ➖ | Hex color override for this specific row. Empty → look up `sample.<name>` in `NGx_plot.conf`, then the grade's default color |

**Color priority (highest → lowest):**
1. `color` column in `manifest.csv` (non-empty)
2. `sample.<name>` entry in `NGx_plot.conf`
3. `grade.<name>` color in `NGx_plot.conf`

See `manifest.csv` for a worked example covering reference genomes, benchmarking assemblies, production SMaHT assemblies, and HPRC samples.

### FAI files

Standard FASTA index files produced by `samtools faidx`:

```bash
samtools faidx my_assembly.fasta   # produces my_assembly.fasta.fai
```

The script expects at least 5 tab-delimited columns, with contig length in column 2.

### `NGx_plot.conf` (optional)

A key = value configuration file. Automatically discovered in the script's directory, then the working directory. If absent, built-in defaults are used silently.

| Key | Default | Description |
|-----|---------|-------------|
| `genome_size` | `3100000000` | Reference genome size in base pairs |
| `output_file` | `NGx_plot.pdf` | Output filename |
| `plot_width` | `10` | Output width in inches |
| `plot_height` | `6` | Output height in inches |
| `plot_title` | `Assembly contiguity NG(x) plot` | Plot title |
| `grade.<name>` | *(see below)* | Visual traits for a grade: `linewidth, color, alpha`. Legend order follows the order of `grade.*` entries in the file |
| `sample.<name>` | — | Per-sample color override (takes precedence over grade color) |
| `haplotype.<name>` | `hap1=solid, hap2=dashed` | ggplot2 linetype for a haplotype value |

**Built-in grade defaults** (used when `NGx_plot.conf` is absent):

| Grade | Linewidth | Color | Alpha |
|-------|-----------|-------|-------|
| `ref` | 1.2 | `#1b9e77` | 1.0 |
| `A+` | 0.8 | `#888888` | 0.9 |
| `B-` | 0.5 | `#888888` | 0.9 |
| `hprc_r1` | 0.2 | `#9E7D2C` | 0.15 |
| `hprc_r2` | 0.2 | `#d197c7` | 0.15 |

## Output

A PDF (default `NGx_plot.pdf`, 10 × 6 inches). Each line represents one assembly; the x-axis shows the percentage of the reference genome size, and the y-axis shows contig length in Mbp.

Visual encoding:

| Aesthetic | Controlled by |
|-----------|---------------|
| Color | `label` (per-sample, three-level priority above) |
| Line type | `haplotype` (configured in `NGx_plot.conf`) |
| Line width | `grade` (configured in `NGx_plot.conf`) |
| Alpha | `grade` (configured in `NGx_plot.conf`) |

## Repository contents

| File | Description |
|------|-------------|
| `NGx_plot.R` | Main script |
| `NGx_plot.conf` | Visual and output configuration (edit to customise) |
| `manifest.csv` | Assembly manifest for SMaHT DSA + HPRC + reference genomes (`fai_path` column is blank; fill in locally) |
