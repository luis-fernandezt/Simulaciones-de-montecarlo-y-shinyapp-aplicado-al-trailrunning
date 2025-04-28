library(shiny)
library(tidyverse)
library(lubridate)
library(chron)
library(ggplot2)
library(viridis)
library(readr)

# Función para convertir h:m:s a minutos
convertir_tiempo <- function(x) {
  as.numeric(period_to_seconds(hms(x))) / 60
}

# Cargar bases
mundial <- read_csv("data/WMTRC_Innsbruck.csv")
selectivo <- read_csv("data/Selectivo.csv")

mundial <- rename(mundial, rank=Rank, bib=Bib, name=Name, nation=Nation, times=Time, gender=Gender, race=Race)
mundial <- mundial |> select(rank, bib, name, nation, times, gender, race)
selectivo <- selectivo |> select(rank, bib, name, nation, times, gender, race)

mundial$times <- as.times(mundial$times)
selectivo$times <- as.times(selectivo$times)

mundial$time <- as.POSIXct(paste("2025-04-19", mundial$times), format='%Y-%m-%d %H:%M:%OS')
selectivo$time <- as.POSIXct(paste("2025-04-19", selectivo$times), format='%Y-%m-%d %H:%M:%OS')



mundial$rank <- as.numeric(mundial$rank)
mundial$bib <- as.numeric(mundial$bib)
selectivo$bib <- as.numeric(selectivo$bib)
mundial <- na.omit(mundial)

# Unir ambas bases
mundial$times_min <- convertir_tiempo(mundial$times)
selectivo$times_min <- convertir_tiempo(selectivo$times)

mundial <- mundial %>% 
  mutate(tiempo_min = convertir_tiempo(times), origen = "mundial")

selectivo <- selectivo %>%
  mutate(tiempo_min = convertir_tiempo(times), origen = "selectivo")

mundial <- mundial |> mutate(gender = case_when(gender == "Female" ~ "Mujer",
                                     gender == "Male" ~ "Hombre",
                                     TRUE ~ NA_character_))

str(mundial)
str(selectivo)


# App Shiny
ui <- fluidPage(
  titlePanel("Estimación de Desempeño Selectivo 2025 en WMTRC Innsbruck 2023"),
  sidebarLayout(
    sidebarPanel(
      selectInput("race", "Selecciona la carrera:", choices = unique(selectivo$race)),
      selectInput("gender", "Selecciona el género:", choices = unique(selectivo$gender)),
      uiOutput("bib_selector"),
      sliderInput("ajuste", "Porcentaje reducción de ritmo por cansancio (%):", min = 1, max = 2, value = 1, step = 0.01),
      actionButton("aplicar_ajuste", "Aplicar Ajuste")
    ),
    mainPanel(
      plotOutput("boxplot_simulacion"),
      plotOutput("densidad_simulacion")
    )
  )
)

server <- function(input, output, session) {
  
  datos_combinados_react <- reactiveVal(NULL)
  
  observeEvent(input$aplicar_ajuste, {
    selectivo_ajustado <- selectivo %>%
      mutate(
        times_min = convertir_tiempo(times) * input$ajuste,
        time = as.POSIXct("2025-04-19", format='%Y-%m-%d') + times_min * 60
      )
    
    mundial <- mundial %>%
      mutate(
        times_min = convertir_tiempo(times),
        time = as.POSIXct("2025-04-19", format='%Y-%m-%d') + times_min * 60
      )
    
    datos_combinados <- bind_rows(mundial, selectivo_ajustado)
    datos_combinados_react(datos_combinados)
  })
  
  seleccion_filtrada <- reactive({
    selectivo %>% filter(race == input$race, gender == input$gender)
  })
  
  output$bib_selector <- renderUI({
    selectInput("bib", "Selecciona un corredor (bib):", choices = seleccion_filtrada()$bib)
  })
  
  output$bib_selector <- renderUI({
    corredores <- seleccion_filtrada()
    choices <- setNames(corredores$bib, paste0("[", corredores$bib, "] ", corredores$name))
    selectInput("bib", "Selecciona un corredor:", choices = choices)
  })
  
  output$boxplot_simulacion <- renderPlot({
    req(input$bib)
    req(datos_combinados_react())
    
    datos_combinados <- datos_combinados_react()
    
    datos_combinados |> 
      filter(race == input$race) |> 
      ggplot(aes(x = time, y = gender, fill = gender)) +
      geom_boxplot(outlier.size = -1) +
      scale_fill_viridis(discrete = TRUE, alpha = 0.6) +
      geom_jitter(aes(x = time, y = gender), color = "black", size = 1.5, alpha = 0.9) +
      geom_jitter(aes(x = time, y = gender), color = "red", size = 3, alpha = 0.9, 
                  data = datos_combinados |> filter(race == input$race & bib == input$bib)) +
      scale_x_datetime(date_breaks = "hour", date_labels = "%H:%M") +
      labs(title = input$race, x = "Tiempo (HH:MM)", y = "META") +
      theme_minimal() +
      guides(fill = "none", color = "none")
  })
  
  output$densidad_simulacion <- renderPlot({
    req(input$bib)
    req(datos_combinados_react())
    
    datos_combinados <- datos_combinados_react()
    
    datos_filtrados <- datos_combinados %>%
      filter(race == input$race, gender == input$gender)
    
    set.seed(123)
    n_sim <- 10000
    posiciones_simuladas <- replicate(n_sim, {
      tiempos <- datos_filtrados$times_min + rnorm(nrow(datos_filtrados), 0, sd(datos_filtrados$times_min) * 0.1)
      rank(tiempos)
    })
    
    idx <- which(datos_filtrados$bib == input$bib)
    posiciones <- posiciones_simuladas[idx, ]
    
    sim_df_long <- tibble(Posición = posiciones, Atleta = datos_filtrados$name[which(datos_filtrados$bib == input$bib)])
    
    posicion_mas_probable <- as.numeric(names(sort(table(posiciones), decreasing = TRUE))[1])
    intervalo_confianza <- quantile(posiciones, probs = c(0.025, 0.975))
    
    tiempo_corredor <- datos_filtrados %>%
      filter(bib == input$bib) %>%
      pull(time) %>%
      .[1]
    
    ggplot(sim_df_long, aes(Posición, fill = Atleta)) +
      geom_density(alpha = 0.5) +
      geom_vline(xintercept = posicion_mas_probable, color = "red", linetype = "dashed", size = 1) +
      geom_vline(xintercept = intervalo_confianza, color = "blue", linetype = "dotted") +
      annotate("text", x = intervalo_confianza[1], y = 0, label = paste0("LI: ", round(intervalo_confianza[1])), 
               color = "blue", vjust = -1.5, hjust = 1, size = 4) +
      annotate("text", x = intervalo_confianza[2], y = 0, label = paste0("LS: ", round(intervalo_confianza[2])), 
               color = "blue", vjust = -1.5, hjust = 0, size = 4) +
      annotate("text", x = posicion_mas_probable, y = max(density(sim_df_long$Posición)$y),
               label = paste("Posición:", posicion_mas_probable), color = "red", hjust = -0.1, vjust = 30, size = 5) +
      annotate("text", x = max(sim_df_long$Posición), y = max(density(sim_df_long$Posición)$y),
               label = paste("Tiempo:", format(tiempo_corredor, "%H:%M:%S")), hjust = 1, vjust = 1.5, size = 5) +
      theme_minimal() +
      labs(title = "Distribución de Posiciones Simuladas",
           x = "Posición Estimada", y = "Densidad")
  })
}

shinyApp(ui = ui, server = server)