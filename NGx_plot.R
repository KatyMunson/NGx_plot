#!/usr/bin/env Rscript

library(ggplot2)
library(dplyr)
library(scales)

# ── command-line args ─────────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript NGx_plot.R <manifest.csv>")
}
manifest_file <- args[1]
cat("Manifest file:", manifest_file, "\n")

# ── config loader ─────────────────────────────────────────────────────────────
load_config <- function(path) {
  if (!file.exists(path)) return(list())
  raw   <- readLines(path)
  raw   <- trimws(raw[!grepl("^\\s*(#|$)", raw)])
  raw   <- raw[nzchar(raw)]
  pairs <- strsplit(raw, "\\s*=\\s*", perl = TRUE)
  setNames(
    lapply(pairs, function(p) trimws(paste(p[-1], collapse = "="))),
    sapply(pairs, `[[`, 1)
  )
}

cfg_get <- function(cfg, key, default) {
  v <- cfg[[key]]
  if (is.null(v) || !nzchar(trimws(v))) default else trimws(v)
}

# auto-discover config: script directory first, then working directory
script_dir <- tryCatch({
  cmd_args  <- commandArgs(trailingOnly = FALSE)
  file_flag <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_flag) > 0) {
    dirname(normalizePath(sub("^--file=", "", file_flag[1]), mustWork = FALSE))
  } else {
    "."
  }
}, error = function(e) ".")

conf_candidates <- unique(c(
  file.path(script_dir, "NGx_plot.conf"),
  "NGx_plot.conf"
))
conf_file <- Filter(file.exists, conf_candidates)[1]

if (length(conf_file) > 0 && !is.na(conf_file)) {
  cat("Config file:", conf_file, "\n")
  cfg <- load_config(conf_file)
} else {
  cat("No NGx_plot.conf found; using built-in defaults.\n")
  cfg <- list()
}

# ── global parameters ─────────────────────────────────────────────────────────
genome_size <- as.numeric(cfg_get(cfg, "genome_size", 3.1e9))
output_file <- cfg_get(cfg, "output_file", "NGx_plot.pdf")
plot_width  <- as.numeric(cfg_get(cfg, "plot_width",  10))
plot_height <- as.numeric(cfg_get(cfg, "plot_height",  6))
plot_title  <- cfg_get(cfg, "plot_title",
                       "Assembly contiguity NG(x) plot")

# ── grade visual traits from config ───────────────────────────────────────────
# File order is preserved by readLines → grade legend order = config file order
grade_keys  <- grep("^grade\\.", names(cfg), value = TRUE)
grade_names <- sub("^grade\\.", "", grade_keys)

if (length(grade_keys) == 0) {
  # built-in fallback palette
  grade_names <- c("ref", "A+", "B-", "hprc_r1", "hprc_r2")
  grade_lw    <- setNames(c(1.2, 0.8, 0.5, 0.2, 0.2),           grade_names)
  grade_col   <- setNames(c("#1b9e77", "#888888", "#888888",
                             "#9E7D2C", "#d197c7"),               grade_names)
  grade_alpha <- setNames(c(1.0, 0.9, 0.9, 0.15, 0.15),         grade_names)
} else {
  grade_parts <- lapply(grade_keys,
                        function(k) trimws(strsplit(cfg[[k]], ",")[[1]]))
  grade_lw    <- setNames(as.numeric(sapply(grade_parts, `[`, 1)), grade_names)
  grade_col   <- setNames(         sapply(grade_parts, `[`, 2),    grade_names)
  grade_alpha <- setNames(as.numeric(sapply(grade_parts, `[`, 3)), grade_names)
}

# ── per-sample color overrides from config ────────────────────────────────────
sample_keys <- grep("^sample\\.", names(cfg), value = TRUE)
sample_cols <- if (length(sample_keys) > 0) {
  setNames(
    sapply(sample_keys, function(k) trimws(cfg[[k]])),
    sub("^sample\\.", "", sample_keys)
  )
} else {
  character(0)
}

# ── haplotype linetypes from config ───────────────────────────────────────────
hap_keys <- grep("^haplotype\\.", names(cfg), value = TRUE)
hap_lt   <- if (length(hap_keys) > 0) {
  setNames(
    sapply(hap_keys, function(k) trimws(cfg[[k]])),
    sub("^haplotype\\.", "", hap_keys)
  )
} else {
  c(hap1 = "solid", hap2 = "dashed")   # sensible built-in default
}

# ── read manifest ─────────────────────────────────────────────────────────────
manifest <- tryCatch({
  read.csv(manifest_file, stringsAsFactors = FALSE)
}, error = function(e) {
  stop(paste("Error reading manifest:", manifest_file, "\n", e$message))
})

required_cols <- c("sample", "haplotype", "grade", "fai_path")
missing_cols  <- setdiff(required_cols, colnames(manifest))
if (length(missing_cols) > 0) {
  stop("manifest is missing required columns: ",
       paste(missing_cols, collapse = ", "))
}

# add optional columns if absent
if (!"label"    %in% colnames(manifest)) manifest$label    <- ""
if (!"color"    %in% colnames(manifest)) manifest$color    <- ""
if (!"fai_path" %in% colnames(manifest)) manifest$fai_path <- ""

# read.csv may return NA for blank character fields depending on R configuration;
# coerce all three optional columns to "" so downstream ifelse() works correctly
manifest$fai_path <- ifelse(is.na(manifest$fai_path), "", manifest$fai_path)
manifest$label    <- ifelse(is.na(manifest$label),    "", manifest$label)
manifest$color    <- ifelse(is.na(manifest$color),    "", manifest$color)

# ── assign per-row visual traits ──────────────────────────────────────────────

# color priority: CSV column > sample config override > grade default
csv_color <- trimws(manifest$color)
manifest$color <- ifelse(
  !is.na(csv_color) & nchar(csv_color) > 0,
  csv_color,
  ifelse(manifest$sample %in% names(sample_cols),
         sample_cols[manifest$sample],
         grade_col[manifest$grade])
)

# alpha from grade (with fallback for unknown grades)
manifest$alpha <- ifelse(
  manifest$grade %in% names(grade_alpha),
  grade_alpha[manifest$grade],
  0.9
)

# linetype from haplotype (with fallback to "solid")
manifest$linetype <- ifelse(
  manifest$haplotype %in% names(hap_lt),
  hap_lt[manifest$haplotype],
  "solid"
)

# label: use CSV value if present, otherwise paste(sample, haplotype)
manifest$label <- ifelse(
  nchar(trimws(manifest$label)) > 0,
  trimws(manifest$label),
  paste(manifest$sample, manifest$haplotype)
)

# ── check for duplicate labels ────────────────────────────────────────────────
dup_labels <- unique(manifest$label[duplicated(manifest$label)])
if (length(dup_labels) > 0) {
  stop("Duplicate labels found in manifest — each row must have a unique label.\n",
       "Duplicated label(s):\n",
       paste0("  ", dup_labels, collapse = "\n"), "\n",
       "Set an explicit 'label' column in the CSV to disambiguate.")
}

cat("Manifest loaded:", nrow(manifest), "rows,",
    sum(nzchar(trimws(manifest$fai_path))), "with fai_path filled in\n")
cat("Unique labels:", length(unique(manifest$label)), "\n")

# ── resolve fai paths ─────────────────────────────────────────────────────────
manifest_dir <- dirname(normalizePath(manifest_file, mustWork = FALSE))

fai_abs <- ifelse(
  startsWith(trimws(manifest$fai_path), "/"),
  trimws(manifest$fai_path),
  file.path(manifest_dir, trimws(manifest$fai_path))
)

# ── process FAI files ─────────────────────────────────────────────────────────
process_fai_ng <- function(fai_file, label, genome_size) {
  if (!file.exists(fai_file)) {
    warning(paste("File not found, skipping:", fai_file))
    return(NULL)
  }
  fai_data <- tryCatch({
    read.table(fai_file, header = FALSE, comment.char = "",
               sep = "\t", stringsAsFactors = FALSE)
  }, error = function(e) {
    warning(paste("Error reading file:", fai_file, "\n", e$message))
    return(NULL)
  })
  if (is.null(fai_data)) return(NULL)
  if (ncol(fai_data) < 5) {
    warning(paste("Unexpected format in:", fai_file,
                  "— found", ncol(fai_data), "columns, expected at least 5. Skipping."))
    return(NULL)
  }
  contig_lengths <- sort(as.numeric(fai_data$V2), decreasing = TRUE)
  cumulative     <- cumsum(contig_lengths)
  percent        <- cumulative / genome_size * 100
  # Prepend a sentinel point at x=0 so geom_step(direction="vh") draws the
  # first horizontal segment from x=0 to the first cumulative percentage.
  rbind(
    data.frame(
      percentage    = 0,
      contig_length = contig_lengths[1],
      label         = label
    ),
    data.frame(
      percentage    = percent,
      contig_length = contig_lengths,
      label         = label
    )
  )
}

all_data_ng <- bind_rows(
  lapply(seq_len(nrow(manifest)), function(i) {
    fp  <- fai_abs[i]
    lbl <- manifest$label[i]
    if (is.na(fp) || !nzchar(trimws(fp))) {
      warning(paste("No fai_path for", lbl, "— skipping."))
      return(NULL)
    }
    cat("Processing:", lbl, "\n")
    process_fai_ng(fp, lbl, genome_size)
  })
)

if (is.null(all_data_ng) || nrow(all_data_ng) == 0) {
  stop("No data loaded. ",
       "Check that fai_path values in the manifest point to valid .fai files.")
}

# ── merge manifest metadata into plot data ────────────────────────────────────
# One visual-trait row per unique label (first occurrence wins)
label_meta <- manifest[!duplicated(manifest$label),
                       c("label", "grade", "color", "alpha", "haplotype")]

plot_data <- merge(all_data_ng, label_meta, by = "label", all.x = TRUE)
# base::merge() does not preserve row order within each label group; sort so
# geom_step connects points in ascending x order instead of drawing backwards.
plot_data <- plot_data[order(plot_data$label, plot_data$percentage), ]

# ── factor levels ─────────────────────────────────────────────────────────────
# Grade: config order first, then any extra grades found in data
present_grades <- intersect(grade_names,        unique(plot_data$grade))
extra_grades   <- setdiff(unique(plot_data$grade), grade_names)
grade_level_ord <- c(present_grades, extra_grades)

# Label: manifest row order, restricted to labels that have data
label_order <- unique(manifest$label[manifest$label %in% unique(plot_data$label)])

plot_data$grade <- factor(plot_data$grade, levels = grade_level_ord)
plot_data$label <- factor(plot_data$label, levels = label_order)

# ── per-label color and alpha maps ────────────────────────────────────────────
label_color_map <- tapply(as.character(plot_data$color),
                          as.character(plot_data$label), `[`, 1)
label_alpha_map <- tapply(as.numeric(plot_data$alpha),
                          as.character(plot_data$label), mean)

# Align to factor levels
alpha_vec       <- label_alpha_map[levels(plot_data$label)]
names(alpha_vec) <- levels(plot_data$label)

# ── grade linewidth and alpha maps (present grades only) ──────────────────────
grade_lw_final <- c(
  grade_lw[present_grades],
  setNames(rep(0.5, length(extra_grades)), extra_grades)
)[grade_level_ord]

grade_alpha_final <- c(
  grade_alpha[present_grades],
  setNames(rep(0.9, length(extra_grades)), extra_grades)
)[grade_level_ord]

# ── haplotype linetype map (observed haplotypes only) ─────────────────────────
obs_hap   <- unique(manifest$haplotype[manifest$label %in% label_order])
hap_lt_extra  <- setNames(rep("solid", length(setdiff(obs_hap, names(hap_lt)))),
                           setdiff(obs_hap, names(hap_lt)))
hap_lt_final  <- c(hap_lt[intersect(names(hap_lt), obs_hap)], hap_lt_extra)

# ── plot ──────────────────────────────────────────────────────────────────────
p <- ggplot(plot_data,
            aes(x        = percentage,
                y        = contig_length,
                group    = label,
                color    = label,
                alpha    = label,
                linetype = haplotype)) +
  geom_step(aes(linewidth = grade), direction = "vh") +
  scale_color_manual(values = label_color_map) +
  scale_alpha_manual(values = alpha_vec, guide = "none") +
  scale_linewidth_manual(values = grade_lw_final, guide = "none") +
  scale_linetype_manual(values = hap_lt_final) +
  scale_x_continuous("Percentage of genome size (%)",
                     breaks = seq(0, ceiling(max(plot_data$percentage) / 10) * 10,
                                  by = 10),
                     limits = c(0, NA)) +
  scale_y_continuous("Contig length (Mbp)",
                     labels = function(x) number(x / 1e6, accuracy = 1)) +
  theme_minimal() +
  ggtitle(plot_title)

ggsave(output_file, p, width = plot_width, height = plot_height, units = "in")
cat("Plot saved to:", output_file, "\n")
