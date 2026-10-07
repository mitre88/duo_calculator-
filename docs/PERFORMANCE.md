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
* Icono por capas (Icon Composer `.icon`), un único asset catalog.
* Objetivo: app < 8 MB descargada (App Thinning por dispositivo).

## Cómo verificar en la Mac

1. Instruments → *Animation Hitches* durante el plegado/desplegado repetido (⌥ + slider de bisagra): 0 hitches.
2. Instruments → *Allocations*: teclear `20000!`, `99999^99999`, cambiar de modo 20 veces; el gráfico
   vuelve a la línea base.
3. Product → Archive → *App Thinning Size Report* (iPhone Duo): tamaño instalado y descargado.
