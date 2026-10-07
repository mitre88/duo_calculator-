# Duo Calculator 🧮📱

Calculadora nativa para **iPhone Duo** (el plegable de Apple, iOS 27.1): **cerrada es una calculadora
básica; abierta, una científica completa**, con Liquid Glass, dark mode de primera, transición fluida
entre las dos pantallas y un motor matemático exacto.

| Cerrado (exterior 5.4") | Abierto (interior 7.6") | Pose mesa |
|---|---|---|
| básica 4×5, teclas circulares | científica 10×5 + programador + unidades | display sobre el pliegue, teclado debajo |

## Qué hay aquí

```
Packages/CalcEngine/   motor matemático (SwiftPM, sin UI, se prueba en Linux y en la Mac)
App/                   app SwiftUI (iOS 27.1) generada con XcodeGen
Tools/                 generadores de fixtures (mpmath + modelo de referencia en Python)
docs/                  semántica normativa, arquitectura, rendimiento, checklist por pose
```

### Motor (`CalcEngine`)
* **Dos carriles numéricos**: racionales exactos (`1 ÷ 3 × 3 − 1 = 0`) y BigDecimal a 60 dígitos para
  funciones trascendentes; la pantalla muestra 16 (o 12 en ancho compacto).
* Parser Pratt con precedencias de iOS, multiplicación implícita, `%` estilo iOS, `=` repetido,
  edición con cursor, memoria, 2nd, Deg/Rad.
* Validación de dominio antes de cada función (`asin 2`, `tan 90°`, `√−1` → Error, nunca crash).
* Modo programador (8–64 bits, BIN/OCT/DEC/HEX, bit a bit) y conversor de unidades exacto.
* 900+ casos de prueba generados por un oráculo independiente (Python + mpmath).

### App
* Layout decidido **solo** por size classes, espacio medido y regiones reservadas (pliegue y cámara),
  como pide Apple para el iPhone Duo; la bisagra solo alimenta efectos.
* Un único `GlassEffectContainer`: al desplegar, las 19 teclas básicas se deslizan a su celda
  científica y las 30 nuevas se materializan; al plegar, al revés. Solo el cambio de modo anima.
* Toda la matemática corre en un actor fuera del hilo principal; fondo aurora a ≤ 24 fps que se pausa en reposo.
* Accesibilidad completa (VoiceOver es‑MX/en, Dynamic Type, Reduce Transparency/Motion, Increase Contrast),
  teclado físico, copiar/pegar, persistencia del estado al plegar o relanzar.

## Compilar

### Motor (Linux, macOS)
```bash
swift test --package-path Packages/CalcEngine
swift run --package-path Packages/CalcEngine calc "2^3^2"            # 512
swift run --package-path Packages/CalcEngine calc --rad "sin(pi/2)"  # 1
swift run --package-path Packages/CalcEngine calc --keys "2,0,0,add,1,0,pct,eq"   # 220
```
CI ejecuta lo mismo en un contenedor `swift:6.2-noble` y comprueba que los fixtures estén al día.

### App (Mac con Xcode 27.1)
```bash
Scripts/bootstrap.sh          # brew install xcodegen · xcodegen generate · swift test del motor
open App/DuoCalculator.xcodeproj
```
Elige el simulador **iPhone Duo** (Device Hub) y usa Closed / Open / Laptop / Book / Tent; con ⌥ aparece
el slider de ángulo de bisagra. La lista de verificación por pose está en `docs/DUO_POSE_CHECKLIST.md`.

> Las dos APIs específicas del Duo (`reservedRegions` y `onHingeChange`) están aisladas en
> `App/DuoCalculator/Layout/FoldGeometry.swift`. Si el SDK final cambia una firma, se corrige ahí.

### Regenerar fixtures
```bash
pip install -r Tools/requirements.txt
python3 -I Tools/reference_model.py && python3 -I Tools/gen_fixtures.py
```

## Documentación
* `docs/CALCULATOR_SEMANTICS.md` — reglas normativas (precedencias, `%`, `=`, dominios, redondeo).
* `docs/ARCHITECTURE.md` — módulos y flujos (tecla, plegado).
* `docs/PERFORMANCE.md` — fluidez, memoria y peso: decisiones y cómo medir.
* `docs/DUO_POSE_CHECKLIST.md` — verificación manual por pose.

## Licencia
MIT (ver `LICENSE`). Dependencias: [BigDecimal](https://github.com/mgriebling/BigDecimal) y
[BigInt](https://github.com/mgriebling/BigInt) (MIT).
