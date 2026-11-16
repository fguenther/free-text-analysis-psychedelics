## ---------------------------------------------------------------------------
## figures.R
##
## Sweep figure (Supplementary Material): cross-validated R^2 against the
## number of text PCs, one panel per dataset/outcome, one figure per
## embedding model. Writes tex/generated/fig_sweeps_<embedding>.pdf.
## ---------------------------------------------------------------------------

library(ggplot2)
library(cowplot)

PANEL_TITLES <- c(
  "APEQ/WHO"    = "APEQ - WHO-5",
  "APEQ/AAQ"    = "APEQ - AAQ-II",
  "GCMQ/WEMWBS" = "GCMQ - WEMWBS",
  "PTSD/PCL"    = "PTSD - PCL-5",
  "PTSD/PTGI"   = "PTSD - PTGI"
)

## Colours are assigned by role, so the baseline is the same grey in every
## panel and a panel looks the same in the e5 and the bge-m3 figure.
MODEL_COLOURS <- c(
  "none"              = "#999999",  # other predictors only
  "text"              = "#0072B2",  # APEQ: the single free-text response
  "events"            = "#E69F00",
  "health"            = "#009E73",
  "events+health"     = "#0072B2",
  "acute"             = "#E69F00",
  "post"              = "#009E73",
  "treat"             = "#CC79A7",
  "acute+post"        = "#56B4E9",
  "acute+treat"       = "#8B5A00",
  "post+treat"        = "#7570B3",
  "acute+post+treat"  = "#0072B2",
  "text_only"         = "#D55E00"   # text PCs only, no other predictors
)

## Synthetic data (SYNTHETIC = TRUE in config_data.R): the same roles in
## purple shades, so the figures are marked as synthetic like the numbers in
## the manuscript (export_tex.R). Within one panel the shades stay distinct.
if (isTRUE(SYNTHETIC)) {
  MODEL_COLOURS[] <- c(
    "none"              = "#A99DB5",  # grey-purple
    "text"              = "#6A1B9A",
    "events"            = "#C9A0DC",
    "health"            = "#8E24AA",
    "events+health"     = "#4A148C",
    "acute"             = "#D7B4EA",
    "post"              = "#9C27B0",
    "treat"             = "#C2185B",
    "acute+post"        = "#7E57C2",
    "acute+treat"       = "#E57FC4",
    "post+treat"        = "#5E35B1",
    "acute+post+treat"  = "#311B92",
    "text_only"         = "#E040FB"
  )[names(MODEL_COLOURS)]
}

model_label <- function(id) {
  ifelse(id == "none", "other predictors only (no text)",
  ifelse(id == "text_only", "text only (no other predictors)",
         paste("other predictors +", gsub("+", " + ", id, fixed = TRUE))))
}

## The sweep grid is geometric, so on a linear axis the middle values
## collide. Label only those far enough apart to stay readable; every swept
## value still gets a plotted point.
thin_breaks <- function(x, min_frac = 0.06) {
  rng  <- diff(range(x))
  keep <- x[1]
  for (v in x[-1]) {
    if (v - keep[length(keep)] >= min_frac * rng) keep <- c(keep, v)
  }
  keep
}

sweep_panel <- function(sweep, title) {
  grid <- sort(unique(na.omit(sweep$nprin)))
  base <- sweep[is.na(sweep$nprin), ]
  ## the baseline does not depend on nprin: draw it as a flat line
  plot_df <- rbind(
    data.frame(nprin = grid, model = "none", r2 = base$r2),
    sweep[!is.na(sweep$nprin), c("nprin", "model", "r2")]
  )
  ids <- unique(sweep$model)
  plot_df$model <- factor(plot_df$model, levels = ids)

  ggplot(plot_df, aes(x = nprin, y = r2, colour = model)) +
    geom_line(linewidth = 0.6) +
    geom_point(size = 1.4) +
    scale_x_continuous(breaks = thin_breaks(grid)) +
    scale_colour_manual(values = MODEL_COLOURS[ids], labels = model_label(ids),
                        name = NULL) +
    labs(x = "number of PCA components", y = expression(R^2), title = title) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title        = element_text(face = "bold", hjust = 0.5, size = 12),
      axis.text.x       = element_text(angle = 45, hjust = 1, size = 7.5),
      legend.position   = "bottom",
      legend.text       = element_text(size = 8),
      legend.key.height = unit(9, "pt"),
      panel.grid.minor  = element_blank()
    ) +
    guides(colour = guide_legend(ncol = 2, byrow = TRUE))
}

make_sweep_figure <- function(emb) {
  panels <- lapply(names(PANEL_TITLES), function(key) {
    parts <- strsplit(key, "/")[[1]]
    res <- readRDS(result_file(emb, parts[1], parts[2]))
    sweep_panel(res$sweep, PANEL_TITLES[[key]])
  })
  out <- file.path(GENERATED_DIR, paste0("fig_sweeps_", emb, ".pdf"))
  ggsave(out, plot_grid(plotlist = panels, ncol = 2),
         width = 12, height = 14, units = "in", device = grDevices::pdf)
  invisible(out)
}
