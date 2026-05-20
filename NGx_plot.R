#!/usr/bin/env Rscript

library(ggplot2)
library(dplyr)
library(scales)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Please provide a metadata CSV file followed by one or more .fai files as arguments.")
}

metadata_file <- args[1]
fai_files <- args[-1]

cat("Metadata file:", metadata_file, "\n")
cat("FAI files:\n")
print(fai_files)

genome_size <- 3.1e9

metadata <- tryCatch({
  read.csv(metadata_file, stringsAsFactors = FALSE)
}, error = function(e) {
  stop(paste("Error reading metadata file:", metadata_file, "\n", e$message))
})

if (!"assembly" %in% colnames(metadata)) {
  stop("Metadata CSV must have an 'assembly' column matching assembly names from .fai files.")
}

get_assembly_name <- function(filepath) {
  fname <- basename(filepath)
  sub("\\.fa\\.gz\\.fai$|\\.fasta\\.fai$|\\.fa\\.fai$|\\.fai$", "", fname, ignore.case = TRUE)
}

process_fai_ng <- function(fai_file, assembly_name, genome_size) {
  if (!file.exists(fai_file)) {
    stop(paste("File not found:", fai_file))
  }
  
  fai_data <- tryCatch({
    fai_data <- read.table(fai_file, header = FALSE, comment.char = "", sep = "\t", stringsAsFactors = FALSE)
  }, error = function(e) {
    stop(paste("Error reading file:", fai_file, "\n", e$message))
  })
  
  if(ncol(fai_data) < 5) {
    stop("Unexpected format in file: ", fai_file, 
         " — found ", ncol(fai_data), " columns instead of at least 5.")
  }
  
  # column 2 is contig length (numeric)
  contig_lengths <- as.numeric(fai_data$V2)
  
  # sort contigs descending
  contig_lengths <- sort(contig_lengths, decreasing = TRUE)

  cumulative <- cumsum(contig_lengths)
  
  percent <- cumulative / genome_size * 100
  keep <- percent <= 100
  
  data.frame(
    percentage = percent[keep],
    contig_length = contig_lengths[keep],
    assembly = assembly_name
  )
}

all_data_ng <- bind_rows(
  lapply(fai_files, function(fai_file) {
    asm_name <- get_assembly_name(fai_file)
    cat("Processing assembly:", asm_name, "\n")
    process_fai_ng(fai_file, asm_name, genome_size)
  })
)

plot_data <- merge(all_data_ng, metadata, by = "assembly", all.x = TRUE)

plot_data$sample <- factor(plot_data$sample, levels= c("T2T-CHM13", "hg38", "COLO829BL", "SMHT012", "SMHT004", "ST001", "ST002", "ST003", "ST004", "hprc_r1", "hprc_r2"))
plot_data$grade <- factor(plot_data$grade, levels = c("ref", "A+", "B-", "hprc_r1", "hprc_r2"))

p <- ggplot(plot_data, aes(x = percentage, y = contig_length, group = assembly, color = sample, linetype = haplotype)) +
  geom_step(aes(linewidth = grade), direction = "vh") +
  scale_color_manual(values = setNames(plot_data$color, plot_data$sample)) +  # assign colors manually
  scale_linewidth_manual(values = c(1.2, 0.8, 0.5, 0.2, 0.2)) +
  scale_x_continuous("Percentage of genome size (%)", breaks = seq(0, 100, by = 10), limits = c(0, 100)) +
  scale_y_continuous("Contig length (Mbp)", labels = function(x) number(x / 1e6, accuracy = 1)) +
  theme_minimal() +
  ggtitle("Assembly contiguity NG(x) plot for SMaHT DSAs")

print(p)

ggsave("NGx_plot.pdf", p, width = 10, height = 6, units = "in")
