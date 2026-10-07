# Lista de verificación por pose (simulador iPhone Duo, Xcode 27.1)

Abre `App/DuoCalculator.xcodeproj`, elige el simulador **iPhone Duo** y usa los botones del Device Hub
(Closed / Open / Laptop / Book / Tent). Con ⌥ pulsado aparece el slider de ángulo de bisagra.

## Closed (vertical) — básica
- [ ] Size class compact/regular → modo `basic`, teclas circulares ≥ 70 pt, 4 columnas.
- [ ] El teclado respeta la barra vertical del sistema (trailing ~84 pt) y los 34 pt inferiores.
- [ ] `200 + 10 % =` → 220; `AC` muestra `C` mientras se teclea; swipe horizontal = ⌫.

## Closed (horizontal) — científica compacta
- [ ] compact/compact → `scientificCompact` (10×5, teclas ≥ 44 pt); con el ajuste apagado → `basicLandscape`.
- [ ] Nada queda bajo la barra vertical.

## Open (vertical y horizontal) — científica
- [ ] regular/regular → `scientific`, 10 columnas, display con 16 dígitos.
- [ ] El texto del display queda bajo la región de la cámara (occlusion) con 12 pt de margen.
- [ ] `2^3^2 = 512`, `sin 30 = 0.5` (Deg), `tan 90 = Error`, `1 ÷ 3 × 3 − 1 = 0`, `2 asin = Error` sin crash.
- [ ] Modo programador y conversor disponibles en la barra superior.

## Laptop / tabletop
- [ ] División horizontal activa → `tabletop`: display arriba del pliegue, teclado completo abajo, sin teclas en el pliegue ± márgenes.
- [ ] Barrido del slider 90°–150°: solo cambia el tilt del display (≤ 4°); el layout no salta.
- [ ] Háptico suave al cambiar de estado de la bisagra.

## Book
- [ ] División vertical → canal central ensanchado (≈ 80 pt); columnas pares; teclas ≥ 44 pt.
- [ ] Dígitos y operadores en la mitad trailing (mano derecha).

## Tent
- [ ] La app sigue usable; cambios rápidos de pose no producen crash ni estados inconsistentes.

## Plegar a mitad de una operación
- [ ] `123 + 45` abierto → plegar → `=` → 168 en la pantalla exterior; también al revés.
- [ ] Las 19 teclas básicas se deslizan a su nueva posición; las científicas se materializan; los dígitos del resultado hacen morph.
- [ ] El cursor y la expresión se conservan; relanzar la app restaura todo.

## Split View (pantalla interior)
- [ ] ½ y ⅓ → `basic`; ⅔ → `basic` o `scientificStacked` según alto; arrastrar el divisor en vivo no produce saltos.

## Transversal
- [ ] Dark / light / negro OLED; Reduce Transparency (relleno sólido), Reduce Motion (crossfade), Increase Contrast (bordes).
- [ ] Dynamic Type AX3 → `basic` con teclas ≥ 44 pt.
- [ ] VoiceOver: display → teclas fila por fila; etiquetas en es‑MX y en.
- [ ] Teclado físico: dígitos, `+ - * / ^ % ! ( ) =`, Enter, Esc, ⌫, flechas.
- [ ] Instruments: 0 hitches a 120 Hz durante el morph; memoria de vuelta a la línea base.
