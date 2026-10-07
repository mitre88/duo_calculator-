# Arquitectura

```
Packages/CalcEngine  (SwiftPM, sin UIKit/SwiftUI, corre en Linux)
  Numerics/   CalcValue (exacto|aprox) · MathKernel (única puerta a BigDecimal) · tablas · errores
  Parsing/    Token · OperatorTable · ExpressionTokenizer · PrattParser · Evaluator
  Engine/     ExpressionDocument (tokens + cursor) · CalculatorEngine (reducer puro) · CalculatorState (Codable)
  Formatting/ DisplayFormatter · ExpressionRenderer · DisplaySnapshot
  Programmer/ ProgrammerValue · ProgrammerEngine
  Units/      UnitCatalog (factores exactos) · UnitConverter
  calc/       CLI: `swift run calc "2^3^2"` · `--keys "2,0,0,add,1,0,pct,eq"`

App/DuoCalculator  (SwiftUI, iOS 27.1, XcodeGen)
  Model/      CalculatorModel (@MainActor façade) → CalculatorWorker (actor que posee el engine)
  Layout/     LayoutInput → LayoutResolver (puro) → LayoutPlan · FoldGeometry (adaptador SDK Duo) · HingeState
  Keys/       KeyID · KeyCatalog (cada tecla una vez, con cara 2nd) · KeyGridSpec (4×5, 6×5, 10×5) · KeyGridLayout · KeyButton
  Views/      CalculatorRootView · FoldAwareContainer · DisplayView · KeypadView · ModeBar · ProgrammerPanel · UnitConverterPanel · SettingsView
  Design/     Palette · Typography · GlassStyles · Motion · AuroraBackground · Haptics
```

## Flujo de una tecla

1. `KeyButton` → `CalculatorModel.press` (main actor) → `CalculatorWorker.send(event)` (actor propio).
2. El reducer muta `ExpressionDocument`, evalúa lo necesario (vista previa, operando en contexto) y
   devuelve un `DisplaySnapshot` (valor, Sendable).
3. El modelo publica el snapshot; SwiftUI anima dígitos (`numericText`) y resalta el operador pendiente.
4. El estado completo se persiste (debounce 400 ms) para sobrevivir plegado, segundo plano y relanzado.

## Flujo del plegado

1. `GeometryReader` mide la ventana (tamaño, safe area, `reservedRegions` del pliegue y la cámara).
2. `LayoutResolver` decide el `LayoutMode` **solo** por size classes + espacio + regiones.
3. `FoldAwareContainer` coloca display y teclado en los frames del plan dentro de **un**
   `GlassEffectContainer`; cada tecla conserva su `KeyID`/`glassEffectID`, así que al cambiar el plan
   SwiftUI desliza las 19 teclas básicas a su celda científica y materializa las 30 nuevas.
4. Solo un cambio de **modo** anima (`.animation(_, value: plan.mode)`); los frames crudos del
   redimensionado siguen sin animación para evitar jitter.
5. La bisagra (`onHingeChange`) alimenta únicamente efectos: tilt del display en pose mesa y un
   háptico suave al cambiar de estado.

## Puntos de integración con el SDK del iPhone Duo

Todo lo específico del Duo vive en `App/DuoCalculator/Layout/FoldGeometry.swift`:
`GeometryProxy.reservedRegions(kind:options:)` y `View.onHingeChange`. Si una firma difiere en el SDK
final, se corrige ahí y nada más cambia.

## Fixtures y oráculo

`Tools/reference_model.py` reimplementa gramática y semántica en Python (Fraction + mpmath) y genera
`expressions.json`, `ios_sequences.json` y `formatting.json`; `Tools/gen_fixtures.py` genera
`transcendental.json` con mpmath a 70 dígitos. Las pruebas Swift exigen coincidencia a ≥ 28–52
dígitos según la función y cadena idéntica tras el redondeo de pantalla (16 dígitos).
