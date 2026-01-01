# app.R
# ============================================================
# FRAUD PATTERN ANALYSIS (PUBLIC / SIMULATED) - SHINY APP
# Input: patrones_prueba.xlsx (en la MISMA carpeta que app.R)
# Output: tablas + gráficos + descargas (xlsx / rds)
# ============================================================

library(shiny)
library(shinycssloaders)
library(readxl)
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidyr)
library(openxlsx)

# -----------------------------
# Helpers
# -----------------------------
safe_ymd_hms <- function(x) {
  # intenta parsear timestamps; si falla devuelve NA
  suppressWarnings(ymd_hms(x, quiet = TRUE))
}

# -----------------------------
# UI
# -----------------------------
ui <- fluidPage(
  titlePanel("Fraud Pattern Analysis (PRUEBA)"),
  
  sidebarLayout(
    sidebarPanel(
      helpText("📌 Importante: el archivo debe llamarse 'patrones_prueba.xlsx' y estar en la misma carpeta que app.R (para shinyapps.io)."),
      tags$hr(),
      
      sliderInput("top_n", "Top merchants por volumen:", min = 3, max = 30, value = 12, step = 1),
      numericInput("threshold", "Umbral investigación (risk score):", value = 60, min = 0, max = 100),
      
      checkboxInput("use_cached_rds", "Usar cache .rds si existe (recomendado)", value = TRUE),
      actionButton("recalc", "Recalcular (si cambiaste el Excel)"),
      tags$hr(),
      
      downloadButton("dl_risk_xlsx", "Descargar risk_table (xlsx)"),
      downloadButton("dl_tx_xlsx", "Descargar df_time_risk (xlsx)"),
      downloadButton("dl_risk_rds",  "Descargar risk_table (rds)"),
      downloadButton("dl_tx_rds",    "Descargar df_time_risk (rds)")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Overview",
                 verbatimTextOutput("info"),
                 tableOutput("top_merchants_tbl")
        ),
        
        tabPanel("Avg by Hour (Top N)",
                 withSpinner(plotOutput("p_hourly_avg", height = 650))
        ),
        
        tabPanel("Boxplot by Hour (Top N)",
                 withSpinner(plotOutput("p_box_hour", height = 650))
        ),
        
        tabPanel("Median + IQR (Top N)",
                 withSpinner(plotOutput("p_iqr", height = 650))
        ),
        
        tabPanel("Fast Rate <2s (Top N)",
                 withSpinner(plotOutput("p_fast", height = 650))
        ),
        
        tabPanel("Heatmap Risk (Top N)",
                 withSpinner(plotOutput("p_heat", height = 750))
        ),
        
        tabPanel("Daily (Latency vs Risk) (Top N)",
                 withSpinner(plotOutput("p_daily", height = 750))
        ),
        
        tabPanel("Weekday Risk (Top N)",
                 withSpinner(plotOutput("p_weekday", height = 650))
        ),
        
        tabPanel("Escalation (Top N)",
                 withSpinner(plotOutput("p_escalation", height = 750))
        )
      )
    )
  )
)

# -----------------------------
# SERVER
# -----------------------------
server <- function(input, output, session) {
  
  # permite recalcular a mano
  trigger <- reactiveVal(0)
  observeEvent(input$recalc, {
    trigger(trigger() + 1)
  })
  
  # 1) Cargar data (Excel o cache RDS)
  raw_data <- reactive({
    trigger()
    
    # rutas relativas (críticas para shinyapps)
    xlsx_path <- file.path(getwd(), "patrones_prueba.xlsx")
    rds_path  <- file.path(getwd(), "patrones_prueba_raw_cache.rds")
    
    # si hay cache y user quiere usarlo
    if (isTRUE(input$use_cached_rds) && file.exists(rds_path)) {
      return(readRDS(rds_path))
    }
    
    validate(
      need(file.exists(xlsx_path),
           "No encuentro 'patrones_prueba.xlsx' en la carpeta de la app. Súbelo junto a app.R.")
    )
    
    # lectura
    df <- readxl::read_excel(xlsx_path)
    
    # guardamos cache para siguientes cargas (mejora mucho la estabilidad)
    saveRDS(df, rds_path)
    
    df
  })
  
  # 2) Feature engineering + filtros
  df_time <- reactive({
    df <- raw_data()
    
    required <- c("Landing_Page_Time", "First_Query_Timestamp", "Merchant_Name")
    validate(
      need(all(required %in% names(df)),
           paste0("Faltan columnas: ", paste(setdiff(required, names(df)), collapse = ", ")))
    )
    
    out <- df %>%
      mutate(
        Landing_Page_Time     = safe_ymd_hms(Landing_Page_Time),
        First_Query_Timestamp = safe_ymd_hms(First_Query_Timestamp),
        tx_seconds            = as.numeric(difftime(First_Query_Timestamp, Landing_Page_Time, units = "secs")),
        day                   = as.Date(Landing_Page_Time),
        hour                  = hour(Landing_Page_Time)
      ) %>%
      filter(
        !is.na(tx_seconds),
        tx_seconds >= 0,
        tx_seconds <= 600
      )
    
    validate(need(nrow(out) > 0, "Después de filtrar (0-600s) no quedaron filas. Revisa timestamps."))
    out
  })
  
  # 3) Top N merchants
  top_merchants <- reactive({
    df_time() %>%
      count(Merchant_Name, name = "total_tx") %>%
      arrange(desc(total_tx)) %>%
      slice_head(n = input$top_n)
  })
  
  df_top <- reactive({
    tm <- top_merchants() %>% pull(Merchant_Name)
    df_time() %>% filter(Merchant_Name %in% tm)
  })
  
  # 4) Hourly stats
  hourly_stats <- reactive({
    df_time() %>%
      group_by(Merchant_Name, hour) %>%
      summarise(
        total_tx  = n(),
        median_tx = median(tx_seconds),
        p25       = quantile(tx_seconds, 0.25),
        p75       = quantile(tx_seconds, 0.75),
        fast_rate = mean(tx_seconds < 2),
        .groups = "drop"
      )
  })
  
  hourly_stats_top <- reactive({
    tm <- top_merchants() %>% pull(Merchant_Name)
    hourly_stats() %>% filter(Merchant_Name %in% tm)
  })
  
  # 5) Day-hour stats
  day_hour_stats <- reactive({
    df_time() %>%
      group_by(Merchant_Name, day, hour) %>%
      summarise(
        total_tx  = n(),
        median_tx = median(tx_seconds),
        fast_rate = mean(tx_seconds < 2),
        .groups = "drop"
      )
  })
  
  # 6) Baseline por merchant
  baseline_merchant <- reactive({
    day_hour_stats() %>%
      group_by(Merchant_Name) %>%
      summarise(
        base_median = median(median_tx),
        base_fast   = median(fast_rate),
        sd_median   = sd(median_tx),
        sd_fast     = sd(fast_rate),
        .groups = "drop"
      ) %>%
      mutate(
        sd_median = ifelse(is.na(sd_median) | sd_median == 0, 0.01, sd_median),
        sd_fast   = ifelse(is.na(sd_fast)   | sd_fast == 0,   0.01, sd_fast)
      )
  })
  
  # 7) Risk table
  risk_table <- reactive({
    day_hour_stats() %>%
      left_join(baseline_merchant(), by = "Merchant_Name") %>%
      mutate(
        z_latency = (median_tx - base_median) / sd_median,
        z_fast    = (fast_rate - base_fast)   / sd_fast
      ) %>%
      mutate(
        risk_flag = case_when(
          total_tx >= 30 & z_latency <= -2   & z_fast >= 2   ~ "HIGH_RISK",
          total_tx >= 20 & (z_latency <= -1.5 | z_fast >= 1.5) ~ "MEDIUM_RISK",
          TRUE ~ "NORMAL"
        ),
        risk_score = pmin(100, round(50 * pmax(0, -z_latency) + 50 * pmax(0, z_fast)))
      )
  })
  
  # 8) Unir riesgo a transacciones (Top N)
  df_time_risk <- reactive({
    df_top() %>%
      left_join(
        risk_table() %>% select(Merchant_Name, day, hour, risk_score, risk_flag),
        by = c("Merchant_Name", "day", "hour")
      )
  })
  
  # 9) Daily + weekday
  daily_summary <- reactive({
    df_time_risk() %>%
      group_by(Merchant_Name, day) %>%
      summarise(
        total_tx   = n(),
        median_tx  = median(tx_seconds, na.rm = TRUE),
        risk_score = median(risk_score, na.rm = TRUE),
        .groups = "drop"
      )
  })
  
  weekday_summary <- reactive({
    df_time_risk() %>%
      mutate(wday = wday(day, label = TRUE, week_start = 1)) %>%
      group_by(Merchant_Name, wday) %>%
      summarise(
        median_tx  = median(tx_seconds, na.rm = TRUE),
        risk_score = median(risk_score, na.rm = TRUE),
        .groups = "drop"
      )
  })
  
  # -----------------------------
  # OUTPUTS
  # -----------------------------
  output$info <- renderPrint({
    df <- df_time()
    tm <- top_merchants()
    list(
      rows_after_filter = nrow(df),
      merchants_total   = n_distinct(df$Merchant_Name),
      date_min          = min(df$day, na.rm = TRUE),
      date_max          = max(df$day, na.rm = TRUE),
      top_n             = input$top_n,
      threshold         = input$threshold,
      top_merchants     = tm
    )
  })
  
  output$top_merchants_tbl <- renderTable({
    top_merchants()
  })
  
  output$p_hourly_avg <- renderPlot({
    hs <- hourly_stats_top()
    ggplot(hs, aes(x = hour, y = median_tx, group = Merchant_Name)) +
      geom_line() +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Median transaction time by hour (Top N)",
        x = "Hour of day", y = "Median tx time (s)"
      ) +
      theme_minimal()
  })
  
  output$p_box_hour <- renderPlot({
    df <- df_top()
    ggplot(df, aes(x = factor(hour), y = tx_seconds)) +
      geom_boxplot(outlier.alpha = 0.1) +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Transaction time distribution by hour (Top N)",
        x = "Hour of day", y = "Transaction time (seconds)"
      ) +
      theme_minimal()
  })
  
  output$p_iqr <- renderPlot({
    hs <- hourly_stats_top()
    ggplot(hs, aes(x = hour, group = Merchant_Name)) +
      geom_ribbon(aes(ymin = p25, ymax = p75), alpha = 0.4) +
      geom_line(aes(y = median_tx)) +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Transaction time distribution by hour (IQR) (Top N)",
        x = "Hour of day", y = "Transaction time (seconds)"
      ) +
      theme_minimal()
  })
  
  output$p_fast <- renderPlot({
    hs <- hourly_stats_top()
    ggplot(hs, aes(x = hour, y = fast_rate, group = Merchant_Name)) +
      geom_line() +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Fast transaction rate (<2s) by hour (Top N)",
        x = "Hour of day", y = "Fast rate"
      ) +
      theme_minimal()
  })
  
  output$p_heat <- renderPlot({
    tm <- top_merchants() %>% pull(Merchant_Name)
    rt <- risk_table() %>% filter(Merchant_Name %in% tm)
    
    ggplot(rt, aes(x = hour, y = day, fill = risk_score)) +
      geom_tile() +
      facet_wrap(~ Merchant_Name) +
      labs(
        title = "Fraud risk heatmap by day and hour (Top N)",
        x = "Hour of day", y = "Day", fill = "Risk score"
      ) +
      theme_minimal()
  })
  
  output$p_daily <- renderPlot({
    ds <- daily_summary()
    ggplot(ds, aes(x = day)) +
      geom_line(aes(y = median_tx), linewidth = 1) +
      geom_line(aes(y = risk_score), linewidth = 1) +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Daily evolution of latency and fraud risk (Top N)",
        subtitle = "Two series plotted on different scales (interpret trends, not absolute comparison)",
        x = "Date", y = "Value"
      ) +
      theme_minimal()
  })
  
  output$p_weekday <- renderPlot({
    ws <- weekday_summary()
    ggplot(ws, aes(x = wday, y = risk_score)) +
      geom_col(position = "dodge") +
      facet_wrap(~ Merchant_Name, scales = "free_y") +
      labs(
        title = "Fraud risk by day of week (Top N)",
        x = "Day of week", y = "Median risk score"
      ) +
      theme_minimal()
  })
  
  output$p_escalation <- renderPlot({
    ds <- daily_summary()
    ggplot(ds, aes(x = day, y = risk_score)) +
      geom_line() +
      geom_hline(yintercept = input$threshold, linetype = "dashed") +
      facet_wrap(~ Merchant_Name) +
      labs(
        title = "Fraud risk escalation over time (Top N)",
        subtitle = "Dashed line = investigation threshold",
        x = "Date", y = "Risk score"
      ) +
      theme_minimal()
  })
  
  # -----------------------------
  # DOWNLOADS
  # -----------------------------
  output$dl_risk_xlsx <- downloadHandler(
    filename = function() paste0("risk_table_prueba_", Sys.Date(), ".xlsx"),
    content  = function(file) openxlsx::write.xlsx(risk_table(), file, overwrite = TRUE)
  )
  
  output$dl_tx_xlsx <- downloadHandler(
    filename = function() paste0("df_time_risk_prueba_", Sys.Date(), ".xlsx"),
    content  = function(file) openxlsx::write.xlsx(df_time_risk(), file, overwrite = TRUE)
  )
  
  output$dl_risk_rds <- downloadHandler(
    filename = function() paste0("risk_table_prueba_", Sys.Date(), ".rds"),
    content  = function(file) saveRDS(risk_table(), file)
  )
  
  output$dl_tx_rds <- downloadHandler(
    filename = function() paste0("df_time_risk_prueba_", Sys.Date(), ".rds"),
    content  = function(file) saveRDS(df_time_risk(), file)
  )
}

shinyApp(ui, server)
