# Semántica normativa de la calculadora

Este documento es la referencia que implementan **ambos** modelos: `Packages/CalcEngine` (Swift) y
`Tools/reference_model.py` (Python, oráculo de pruebas). Si cambias una regla aquí, cambia los dos.

## 1. Dos carriles numéricos

| Carril | Tipo | Cuándo |
|---|---|---|
| exacto | `BFraction` (racional) | `+ − × ÷`, potencias enteras (`|n| ≤ 4096`), `%`, literales, `x² x³ 1/x`, raíces de potencias perfectas, `n!` con `n ≤ 20 000`, tablas de ángulos |
| aproximado | `BigDecimal` a **60 dígitos** (`toNearestOrEven`) | funciones trascendentes o cualquier operación con un operando aproximado |

Una fracción cuyo numerador + denominador supere **1024 bits** baja al carril aproximado.
Los valores nunca se re‑redondean entre operaciones; **solo la pantalla redondea**
(16 dígitos en ancho regular, 12 en compacto, `toNearestOrAwayFromZero`).

## 2. Política de artefactos

1. **Cancellation snap**: `a ± b` aproximado con `|r| < 10⁻⁵⁵ · max(|a|,|b|)` → `0` exacto.
2. **Zero snap trascendente**: `|r| < 10⁻⁴⁰` y `|arg| ≥ 10⁻²⁰` → `0` exacto (`sin π = 0`, `cos 90° = 0`).
3. **Grados**: el argumento se reduce **exactamente** módulo 360. Tabla cerrada para múltiplos de 30°/45°
   (`0, ±½, ±1` exactos); `tan(90° + 180°k)` → `domain`. Inversas: `asin ½ = 30°`, `acos 0 = 90°`, `atan 1 = 45°` exactos.
4. **tan** = sin / cos con el coseno ya *snapeado*: `tan(π/2)` → `domain`, nunca `2.4e71`.
5. **Dominios** (se validan antes de llamar a BigDecimal): `asin/acos |x| ≤ 1`, `atanh |x| < 1`, `acosh x ≥ 1`,
   `ln/log x > 0`, `√x x ≥ 0`, `ʸ√x` con `y` par exige `x ≥ 0` (raíz impar de negativo permitida),
   `x!` exige `x ≥ 0` (no entero → `Γ(x+1)`, `x ≤ 10 000`), `0^y` con `y < 0` → `divisionByZero`,
   `x^y` con `x < 0` e `y` no entero → `domain`.
6. **Overflow**: exponente decimal `> 1 000 000` → `overflow`; `n!` con `n > 20 000` → `overflow`.
   Potencias con `|n| > 4096` se calculan como `exp(y·ln x)` con dígitos de guarda proporcionales a `|y|`.
7. `0^0 = 1`, `0! = 1`, `-0` se normaliza a `0`.

## 3. Gramática y precedencias (parser Pratt)

| Nivel | Operadores | L / R | Notas |
|---|---|---|---|
| 1 | `+ −` | 10 / 11 | izquierda |
| 2 | `× ÷` e **implícita** (`2π`, `3(4+1)`, `2sin 30`) | 20 / 21 | `6 ÷ 2(1+2) = 9` |
| 3 | `−` prefijo | R 30 | `−2² = −4`, `−2 × 3 = (−2) × 3` |
| 4 | función sin paréntesis (`sin 30`, solo texto) | R 35 | `sin 30² = sin(900)`, `sin 30 × 2 = (sin 30) × 2` |
| 5 | `^`, `ʸ√x`, `logᵧ`, `yˣ` | 50 / 49 | **derecha**: `2^3^2 = 512` |
| 6 | postfijos `! % ² ³` | L 60 | `2^3! = 64` |

* `EE` forma parte del literal (`2EE3 = 2000`); `±` niega el literal (`2 ± x² = 4`).
* Texto: `root(x, n)`, `logb(x, b)`, `rpow(x, y)`; `pi`, `e`; `2e3` es un número, `2e` es `2·e`.
* Límites: 64 niveles de paréntesis, 512 tokens → `tooComplex`.

## 4. Porcentaje (compatible con iOS)

| Expresión | Valor |
|---|---|
| `x %` | `x / 100` |
| `a + b %`, `a − b %` | `a ± a·b/100` |
| `a × b %`, `a ÷ b %`, `a ^ b %` | `a op (b/100)` |
| `b % op a` | `(b/100) op a` |
| `2 + 3 × 10 %` | `2.3` (precedencia primero) |

Al pulsar `%` la pantalla muestra el operando convertido (`200 + 10 %` → `20`); `=` da `220`.

## 5. Documento de expresión y fases

`ExpressionDocument = [Token] + cursor`. Fases: `idle`, `entering`, `operandComputed`, `operatorPending`,
`editing`, `resultShown`, `error`.

* Un dígito **extiende** el número tecleado antes del cursor; tras una función/postfijo/constante
  (`operandComputed`) un dígito **reemplaza** ese operando; tras `=` empieza una expresión nueva.
* Operador tras operador **reemplaza**; `−` tras `× ÷ ^` es signo del siguiente literal.
* Funciones **envuelven** el operando bajo el cursor (`30` → `sin(30)`, `(2+3)` → `sin(2+3)`).
* `=`: cierra paréntesis, resuelve operador colgante duplicando su operando izquierdo
  (`5 × =` → 25, `2 + 3 × =` → 11) y captura la **última operación tecleada** para repetir
  (`2 + 3 = = =` → 5, 8, 11; `2 + 3 = 10 =` → 13).
* `C` borra la entrada mientras se teclea; `AC` borra todo (la memoria se conserva).
* En `error` solo dígitos, constantes, `MR` o `AC` sacan del estado.
* Memoria: `M+`/`M−` usan el valor mostrado; `MR` inserta un operando.
* `2nd` es un conmutador persistente (como iOS).

## 6. Pantalla

* Regular: 16 dígitos significativos, plano si `−7 < E < 16`; compacto: 12 / `E < 12`.
* Científica: `1.219326311e17`, `1e-7`; sin ceros finales; separadores del locale.
* La entrada se muestra tal cual se teclea (`1,234.50`, `2e-`).

## 7. Modo programador

Enteros de 8/16/32/64 bits con o sin signo, bases 2/8/10/16, evaluación **de izquierda a derecha**,
desbordamiento envolvente, división entera con signo, desplazamiento aritmético para valores con signo.
