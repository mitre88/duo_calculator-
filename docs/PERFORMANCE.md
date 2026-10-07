# Fluidez, memoria y peso

## Fluidez (120 Hz en ambas pantallas)

* **Nada de matemáticas en el hilo principal**: `CalculatorWorker` (actor) posee el engine; el main actor
  solo recibe `DisplaySnapshot`s inmutables.
* **Un solo contenedor de vidrio** para el teclado; cada tecla tiene identidad estable → el morph
  básica ↔ científica es una sola animación de spring (`response 0.5, damping 0.82`), sin recrear vistas.
* **Solo el cambio de modo anima**; los frames intermedios del redimensionado no (sin jitter).
* `KeypadView` solo depende de lo que pinta (operador pendiente, 2nd, etiqueta AC/C): el resto del
  snapshot no invalida las teclas.
* Fondo aurora: `MeshGradient` a ≤ 24 fps, **pausado** tras 12 s sin tocar y con *Reduce Motion*.
* Texto del resultado con `contentTransition(.numericText)` y `minimumScaleFactor`, sin relayout de fuente.
* Vidrio solo en controles (display y paneles son contenido): se evita vidrio sobre vidrio y el
  sobredibujado que implica.

## Memoria

* Estado del engine: unos pocos KB (expresión, memoria, 50 resultados como máximo).
* Las cachés globales de BigDecimal están acotadas: π (1 valor), factoriales (100 entradas iniciales,
  no crece), constantes de Spouge (1 juego por precisión). El engine usa `BInt.factorial` (sin caché).
* Peor caso aritmético: `20000!` ≈ 77 000 dígitos ≈ 32 KB transitorios; `99999^99999` se calcula como
  `exp(y·ln x)` (nunca como potencia entera exacta de cientos de miles de dígitos).
* Las evaluaciones en vuelo se contabilizan (`isBusy`) y las entradas rápidas se serializan en el actor;
  no se acumulan tareas duplicadas porque cada tecla produce un único snapshot.
* Objetivo medido con Instruments (Allocations / Memory Graph): < 60 MB de pico con el mesh activo.

## Peso del binario

* Sin imágenes ni fuentes empaquetadas: SF Symbols, SF Pro Rounded del sistema, catálogo de strings.
* Dependencias: BigDecimal + BigInt + UInt128 + swift-numerics (puro Swift, ~1 MB tras *stripping*).
* `DEAD_CODE_STRIPPING = YES`, optimización `-O` en Release, sin recursos bajo demanda.
* Icono: tres PNG de 1024 px (normal / oscuro / teñido, ≈ 260 KB en total) en un único asset catalog; un `.icon` de Icon Composer puede sustituirlos.
* Objetivo: app < 8 MB descargada (App Thinning por dispositivo).

## Cómo verificar en la Mac

1. Instruments → *Animation Hitches* durante el plegado/desplegado repetido (⌥ + slider de bisagra): 0 hitches.
2. Instruments → *Allocations*: teclear `20000!`, `99999^99999`, cambiar de modo 20 veces; el gráfico
   vuelve a la línea base.
3. Product → Archive → *App Thinning Size Report* (iPhone Duo): tamaño instalado y descargado.

## Tests automáticos de rendimiento, memoria y robustez

Viven en `Packages/CalcEngine/Tests/CalcEngineTests/PerformanceTests.swift` y corren en cada push, en el CI de
Linux, **dos veces**: en debug con el resto de la suite y en **release** (`swift test -c release --filter
'PerformanceTests|PerformanceGuardTests'`). Cada test imprime una línea `[perf]` o `[mem]`; el *job summary* de
GitHub Actions las recoge como informe. En la Mac: `swift test -c release --package-path Packages/CalcEngine` o
`swift run -c release calc --bench` para la misma tabla sin la suite.

| Test | Qué mide | Presupuesto (release) |
|---|---|---|
| `keyPressLatency` | `send` + `snapshot` por tecla en un guion de 42 teclas realistas (funciones, `%`, memoria, `=` repetido, error) | p50 < 2 ms · p95 < 16 ms |
| `evaluatorThroughput` | evaluación completa por familia: aritmética, racional exacta, trig en grados y radianes, hiperbólicas, potencias y raíces | 0.3–12 ms p50 según familia |
| `formatterThroughput` | formateo a 16 dígitos con agrupación es‑MX | < 40 µs por valor |
| `memoryStaysBoundedOverALongSession` | RSS antes y después de 4 000 teclas aleatorias (tras 500 de calentamiento; 400 en debug); tamaño del estado persistido; picos de tokens y resultados | crecimiento < 24 MiB · estado < 64 KB · tokens ≤ 512 · resultados ≤ 50 |
| `randomSessionsNeverCrashOrStall` | 5 semillas × 1 500 eventos de todo el alfabeto de teclas (300 en debug), incluidos dominios inválidos, paréntesis, cursor y memoria | ningún crash · ningún evento > 5 s · límite de 10 min por test |
| `parserHandlesMaximumComplexityAndRejectsBeyond` | 511 tokens y 60 paréntesis anidados se evalúan; 513 tokens y 80 niveles devuelven `tooComplex` | sin crash |
| `PerformanceGuardTests` | `99999^99999`, `20000!`, `sin(1e30)`, `100.25!`, `exp(2e6)`, `2^4097`, `1.0000001^1e7` | < 3 s cada uno |

Los presupuestos están pensados para un build release en un iPhone. En debug dentro del contenedor de CI son
un orden de magnitud más lentos, así que **sin** `CALC_PERF_STRICT=1` cada presupuesto se multiplica por 25: los
números estrictos son la meta de producto; los relajados solo cazan regresiones algorítmicas. Para medir en la Mac
con los presupuestos reales: `CALC_PERF_STRICT=1 swift test -c release --package-path Packages/CalcEngine`.

La medición de memoria lee el RSS del proceso (`/proc/self/statm` en Linux, `task_info` en Darwin); es una
cota superior (el *allocator* no siempre devuelve páginas), por eso el umbral es generoso y lo que importa es la
tendencia entre ejecuciones.

### En la app (Xcode)

`App/DuoCalculatorTests/PerformanceTests.swift` usa `measure(metrics:)` con `XCTClockMetric`, `XCTCPUMetric` y
`XCTMemoryMetric`: resolución del layout para las 9 poses (×100), estabilidad del `LayoutPlan` (resolver dos
veces da un plan igual, así SwiftUI no re‑dispone en frames sin cambio), aritmética de la rejilla de teclas y
formateo. La primera ejecución fija la línea base por dispositivo; después, una regresión mayor a la tolerancia
falla el test. La fluidez real a 120 Hz (morph, aurora, hápticos) se verifica con Instruments según la sección
anterior.
