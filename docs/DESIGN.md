# Diseño visual e interacción

Este documento fija las decisiones de diseño de la app (no del motor). Cada regla tiene un "porqué" y
el archivo donde vive, para que un cambio de criterio se haga en un solo lugar.

## Principios

1. **Una sola calculadora, dos tamaños.** Cerrado y abierto son el mismo objeto: cada tecla conserva su
   identidad (`KeyID` → `glassEffectID`) y *viaja* a su nueva celda; las científicas se materializan.
   Nunca hay dos pantallas distintas que se intercambian.
2. **El vidrio flota, el contenido no.** Liquid Glass solo en controles (teclas, barra de modo, chips).
   El display, las tarjetas del conversor y el panel de bits son contenido plano: nada de vidrio sobre vidrio.
3. **El fondo existe para el vidrio.** Negro OLED (opcional) con una aurora de malla al 16 % que se mueve
   muy despacio; se pausa con *Reduce Motion* y tras 12 s sin tocar (`AuroraBackground`).
4. **El movimiento explica.** Cada animación responde a una causa física: plegar (onda desde la bisagra),
   pulsar (brillo + háptico), `=` (pulso), error (sacudida). Sin adornos sin causa.
5. **Accesible por construcción.** *Reduce Transparency* → rellenos opacos; *Increase Contrast* → trazo
   de 1 pt; *Reduce Motion* → fundidos y cero desplazamientos; VoiceOver con etiquetas por tecla.

## Tokens (`Design/ColorTokens.swift`, `Model/AppSettings.swift`)

| Token | Light | Dark | Uso |
|---|---|---|---|
| `canvas` | `#F2F2F7` | `#0B0B10` · `#000` con *true black* | fondo |
| `accent` Duo Amber | `#FFA033` | `#FFA033` | operadores, `=`, cursor, pills activas |
| alternativos | Indigo `#5E5CE6` · Mint `#63E6BE` · Graphite `#8E8E93` | | ajustes → swatches |
| `digitTint` | blanco 35 % | blanco 4 % | dígitos |
| `functionTint` | negro 8 % | blanco 10 % | funciones, memoria, paréntesis |
| `utilityTint` | gris 35 % | gris 45 % | AC ± % |
| `activeTint` | blanco | blanco 92 % | operador pendiente, 2nd, Rad, mr |
| `error` | `#FF453A` | `#FF453A` | resultado en error |

Receta de vidrio por familia (`Design/GlassStyles.swift`): dígitos `.regular.tint(digitTint).interactive()`,
funciones `.regular.tint(functionTint)`, operadores `.regular.tint(accent·0.85).interactive()`, `=` acento
pleno, utilidades `utilityTint`. Estado activo = relleno `activeTint` con glifo en acento (operadores) o
negro (toggles), como la Calculadora de iOS.

## Forma y métrica

* Tecla circular si `|w − h| < 6 pt`; si no, rectángulo continuo de radio `0.36·min(w, h)`.
* `lado = min((W − (n−1)·gap − 2·margen)/n, (H − (filas−1)·gap)/filas)`; mínimo **44 pt** siempre.
* `gap` 12 pt (regular) / 8 pt (compacto); margen 16 / 12 pt. Canal de 80 pt en pose libro
  (ancho de división + márgenes), columnas pares siempre que exista una región de división.

## Tipografía (`Design/Typography.swift`)

| Elemento | Fuente |
|---|---|
| Resultado | SF Rounded **Light**, `min(96, 0.40·alto del display)` pt, dígitos monoespaciados, *tightening* antes de escalar (mín. 0.3) |
| Expresión | SF Rounded Medium 24 / 20 pt, secundaria; operadores terciarios; cursor de 2 pt en acento |
| Vista previa `=` | SF Rounded Regular 20 / 17 pt, terciaria |
| Dígitos de tecla | SF Rounded Regular `0.44·alto` (20–36 pt) |
| Operadores | SF Symbols `plus minus multiply divide equal percent plus.forwardslash.minus`, Medium `0.40·alto` |
| Funciones | SF Rounded `0.30·alto` (13–21 pt); **Semibold por debajo de 17 pt** para que no se "lave" sobre el vidrio |
| Scripts (`x²`, `10ˣ`, `log₁₀`, `ʸ√x`) | Semibold `0.19·alto`, `baselineOffset = 0.12·alto` |

## Movimiento (`Design/Motion.swift`, `Design/Feedback.swift`)

| Causa | Curva | Detalle |
|---|---|---|
| Cambio de `LayoutMode` (plegar / desplegar / modo) | `spring(response 0.5, damping 0.82)` | solo anima el **modo**; los frames crudos del resize siguen sin animación (sin *jitter*) |
| Teclas que se materializan | `spring(0.42, 0.84)` + escala 0.86 → 1 | **onda desde la bisagra**: `retardo = min(0.14, 0.016·|col − origen| + 0.012·fila)`; el origen es la columna del canal (libro) o el eje central |
| Teclas que se van al plegar | `easeOut 0.14` | rápido, para que la básica asiente primero |
| Pulsación | brillo +12 %, `spring(0.22, 0.7)` | el vidrio interactivo ya escala y brilla; no se duplica la escala |
| Dígitos | `snappy 0.22` + `numericText(value:)` | ruedan hacia arriba o abajo según crezca o decrezca el valor |
| `=` | pulso 1.0 → 1.035 → 1.0 anclado al borde trailing | `SpringKeyframe` (0.12 s + 0.32 s con rebote 0.1) |
| Error | sacudida −10, 8, −5, 3, 0 pt en 0.31 s | con háptico `.error`; no se muestra con *Reduce Motion* |
| Bisagra (solo efectos) | `rotation3DEffect ≤ 4°` en pose portátil, háptico `.soft` al cambiar de estado | nunca decide layout |
| Paneles (programador / conversor) | `spring(0.45, 0.86)`, entran desde trailing | |

## Hápticos (`Design/Haptics.swift`)

Dígitos `.light`, operadores y funciones `.medium`, `=` `.heavy` + `.success`, toggles `.selection`, error
`.error`, cambio de pose `.soft`. El deslizamiento ⌫ y el teclado físico usan `.light` para sentirse como una
tecla real. Todo pasa por `.sensoryFeedback` (sin `UIImpactFeedbackGenerator` suelto) y se apaga en Ajustes.

## Estados del display

* **Resultado** (`showsResult`): expresión con `=` terciario, resultado grande, sin cursor.
* **Editando**: cursor parpadeante (560 ms) que se coloca al tocar un token, `◀ ▶` en la barra de modo,
  vista previa `= …` en vivo mientras la expresión sea evaluable.
* **Operando calculado** (tras función, `%`, `mr`): un dígito lo reemplaza; la tecla `C`/`AC` cambia de etiqueta.
* **Error**: texto en `error`, motivo localizado en la línea de expresión, sacudida; solo dígitos, constantes o
  `AC` sacan del estado.
* El resultado es `privacySensitive` (se difumina en el conmutador de apps).

## Ajustes

Apariencia (sistema / claro / oscuro), *true black*, acento con **swatches** (discos de 32 pt con anillo y
check; háptico `.selection`), aurora, hápticos, científica en horizontal plegado, mantener pantalla encendida
(`isIdleTimerDisabled`), separadores de miles, precisión informativa.

## Lista de revisión visual (en la Mac)

1. Ninguna tecla cambia de forma dos veces durante el morph (círculo → rectángulo una sola vez).
2. La onda de materialización parte del centro/canal y termina en < 0.6 s en total.
3. Operador pendiente invertido (relleno claro, glifo en acento) legible en claro y oscuro.
4. `9999999999999999 × 9 =` no provoca salto de tamaño: primero *tightening*, luego escala.
5. *Reduce Transparency* + *Increase Contrast* + AX3: nada se solapa, mínimo 44 pt.
6. Instruments: sin *hitches* a 120 Hz durante el morph y con la aurora activa.
