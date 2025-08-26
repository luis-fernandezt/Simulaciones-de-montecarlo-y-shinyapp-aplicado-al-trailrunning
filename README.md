# Simulaciones montecarlo & shinyapp aplicado al trailrunning

## 1. Introducción
 
**Este estudio busca estimar de forma teórica como le hubiera ido a la selección chilena de trail del año 2025 en el Campeonato Mundial de Trail Running Innsbruck 2023.**

Se diseña una aplicación web Shiny para la simulación por distribución de probabilidad usando el método de montecarlo, aplicado al desempeño de corredores del selectivo de trailrunning Chile Nahuelbuta ALL IN 2025 **como si hubieran participado** en el WMTRC Innsbruck 2023.

## 2. Carga y Preparación de Datos

Las bases de datos con los resultados del selectivo nacional 2025 y mundial de Innsbruck 2023 estan disponibles en:   

- [WMTRC_Innsbruck.csv](https://raw.githubusercontent.com/luis-fernandezt/Simulaciones-de-montecarlo-y-shinyapp-aplicado-al-trailrunning/refs/heads/main/data/WMTRC_Innsbruck.csv) 
- [Selectivo.csv](https://raw.githubusercontent.com/luis-fernandezt/Simulaciones-de-montecarlo-y-shinyapp-aplicado-al-trailrunning/refs/heads/main/data/Selectivo.csv)
- [Matriz de calculos en Excel](https://github.com/luis-fernandezt/Simulaciones-de-montecarlo-y-shinyapp-aplicado-al-trailrunning/raw/refs/heads/main/data/Selectivo_results.xlsx)

## 3. Estandarización por Distancia

Para normalizar la distancia del selectivo primero se estimo el tiempo promedio por cada kilometro del corredor o corredora, dividiendo el tiempo en meta del selectivo por la distancia completada. Luego el tiempo por kilómetro se multiplico por la distancia que hipoteticamente completaría en el mundial.
Se incluyo un ajuste manual en la aplicación shiny, para aumentar el tiempo por kilometro según el porcentaje de cansancio que pudiera ir teniendo la persona y ajustar el resultado de la simulación.

|   **Carrera**   | **Nahuelbuta ALL IN** | **Innsbruck-Stubai** | **% Cansancio aproximado** |
|:---------------:|:---------------------:|:--------------------:|:--------------------------:|
|  **Trail Long** |         65 km         |         87 km        |         >18% (1.18)        |
| **Trail Short** |         43 Km         |        45,2 km       |         >11% (1.11)        |
|   **Classic**   |         16 km         |         15 km        |        >= 1% (1.01)        |
|    **Junior**   |          8 km         |         7 km         |        >= 1% (1.01)        |

## 4. Simulación Monte Carlo

Permite modelar la incertidumbre en el rendimiento de los corredores nacionales frente a los del Campeonato Mundial, se utilizará una simulación de Monte Carlo.

## Fundamento metodológico

La simulación se basa en la suposición de que el tiempo de carrera de cada atleta puede variar aleatoriamente dentro de un rango determinado por la variabilidad observada en los datos. Se perturba el tiempo observado con un término aleatorio siguiendo una distribución normal:

$$
T^*_i = T_i + \epsilon_i \quad \text{donde} \quad \epsilon_i \sim \mathcal{N}(0, \sigma_T^2 \cdot \alpha^2)
$$

Donde:

- $T^*_i$: Tiempo simulado del corredor $i$.
- $T_i$: Tiempo original del corredor $i$ (en minutos).
- $\epsilon_i$: Ruido aleatorio simulado.
- $\sigma_T$: Desviación estándar de los tiempos observados en la base combinada.
- $\alpha = 0.1$: Parámetro de escala que controla la magnitud de la variabilidad (10% de la desviación estándar total).


Esta simulación se repite $n = 10.000$ veces para estimar la distribución empírica de las posiciones alcanzadas por los corredores seleccionados. Esta cantidad de iteraciones busca lograr una estimación estable de las probabilidades de ranking sin ser excesivamente costosa computacionalmente.

## Propósito

La finalidad de esta simulación es estimar probabilísticamente la posición que podrían alcanzar los corredores chilenos al participar en una carrera con el mismo nivel de competencia que el Mundial.

## Explicación Paso a Paso

```r
set.seed(123)
n_sim <- 10000
posiciones_simuladas <- replicate(n_sim, {
  tiempos <- datos_filtrados$times_min + rnorm(nrow(datos_filtrados), 0, sd(datos_filtrados$times_min) * 0.1)
  rank(tiempos)
})
```

### 1. `set.seed(123)`

Esta línea fija la semilla de generación aleatoria en 123.
Esto asegura que los resultados sean **reproducibles**: cada vez que ejecutes el código, obtendrás los mismos números aleatorios.

### 2. `n_sim <- 10000`

Define el número de simulaciones que se van a realizar.
En este caso, **10.000 simulaciones**.

Cada simulación corresponde a un "mundo alternativo" donde los tiempos de carrera cambian ligeramente.

### 3. `replicate(n_sim, {...})`

`replicate` ejecuta el bloque de código que está dentro de las llaves `{}` **10.000 veces**.

Cada ejecución simula una posible carrera.

### 4. Dentro del `replicate`

#### a) `rnorm(nrow(datos_filtrados), 0, sd(datos_filtrados$times_min) * 0.1)`

- `nrow(datos_filtrados)` indica cuántos corredores hay.
- `rnorm` genera un vector de números aleatorios con distribución normal:
  - Media = 0
  - Desviación estándar = 10% de la desviación estándar de los tiempos observados (`times_min`).

Esto simula **pequeñas variaciones aleatorias** en el rendimiento de cada corredor.

#### b) `tiempos <- datos_filtrados$times_min + errores`

Se suman esas perturbaciones aleatorias (`errores`) a los tiempos originales.

Cada "nueva carrera simulada" tiene corredores que corren un poco más rápido o más lento que su tiempo real.

#### c) `rank(tiempos)`

Se calcula el **ranking** de los corredores según estos nuevos tiempos simulados:
- El menor tiempo obtiene el rango 1 (primer lugar).
- El segundo menor tiempo el rango 2, y así sucesivamente.

### 5. Resultado final: `posiciones_simuladas`

El resultado es una **matriz**:
- Cada **columna** corresponde a una simulación.
- Cada **fila** corresponde a un corredor.

La matriz indica en qué posición quedó cada corredor en cada una de las 10.000 simulaciones.

### Conclusión

Este procedimiento permite estimar la **variabilidad de las posiciones finales** debido a pequeñas fluctuaciones aleatorias en los rendimientos, generando un análisis de incertidumbre en los resultados de la competencia.


## 5. Resultados Esperados

Se espera simular el desempeño proyectado para cada corredor o corredora de la selección chilena, basado en 10000 simulaciones que modelan posibles escenarios de competencia internacional.

Cada simulación representa una carrera hipotética, considerando la variabilidad normal que puede ocurrir en el rendimiento (por ejemplo, por clima, altitud o estado físico del día).

El resultado de cada aplicación del ajuste, entrega un gráfico de cajas (boxplot) y distribución normal, visualizando la dispersión de posiciones para cada corredor, tiempo en cruzar la meta, intervalos confianza de posición inferior y superior;  permitiendo comparar de forma intuitiva quiénes tienen mayor regularidad o probabilidad de destacarse.

Este análisis **no predice con certeza el resultado final**, pero entrega una base sólida para estimar el posible desempeño en un contexto competitivo realista.

## 6. Presentación de aplicación Shiny

![](https://www.datascienceportfol.io/static/profile_pics/pr2_4CE0B84ECD459166959B.png)  

Si ejectuta el scrip llamado **shiny_app.R** alojado en este repositorio, estaría en condiciones de correr la aplicación web de shiny en su maquina local a traves del navegador web por defecto. 

Tambien dejo un acceso directo a la aplicación web de prueba, disponible en:

[https://luis-fernandezt.shinyapps.io/Selectivo_Trail/](https://luis-fernandezt.shinyapps.io/Selectivo_Trail/)

## 7. Resultados de Chile en el Campeonato Mundial de Trail Running de Thailand 2021 e Innsbruck 2023

Para ver los resultados historicos de la participación de los seleccionados nacionales revisar el siquiente repositorio:

[https://github.com/luis-fernandezt/Chile_Mundial_TrailRun_Results](https://github.com/luis-fernandezt/Chile_Mundial_TrailRun_Results)

##### 04/11/2022-06/11/2022 | Chiang Mai, Tailandia 
##### 07/06/2023-10/06/2023 | Innsbruck-Stubai, Austria
