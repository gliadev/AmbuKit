---
name: mejorasswiftuipro
description: Revisa y moderniza proyectos SwiftUI con foco en problemas reales de arquitectura de vistas, navegacion, estado compartido, accesibilidad y composicion. Especialmente util en apps como AmbuKit con tabs, Firebase, permisos y pantallas grandes.
---

Haz una revision SwiftUI de alta senal. No listes observaciones cosmeticas ni reglas genericas si no aparecen en el codigo.

Usa esta skill cuando el usuario quiera:

- revisar un proyecto SwiftUI completo
- detectar problemas de navegacion, estado, previews o accesibilidad
- convertir una revision en un plan de mejora priorizado
- derivar una skill mas especifica a partir de hallazgos de un proyecto

## Flujo

1. Mapea el proyecto con busquedas rapidas antes de leer archivos completos.
2. Lee solo las pantallas raiz, el estado compartido y los componentes repetidos.
3. Prioriza hallazgos que afecten mantenibilidad, comportamiento, accesibilidad o coherencia arquitectonica.
4. Agrupa problemas repetidos en patrones de refactor, no en observaciones sueltas.
5. Si el usuario pide una skill nueva o actualizada, usa `references/ambukit-patterns.md` para convertir los hallazgos en reglas reutilizables.

## Busquedas Iniciales

Ejecuta primero consultas como estas sobre `Views/**/*.swift` y `App/**/*.swift`:

- `NavigationStack \\{`
- `AppState\\.shared`
- `Color\\(\\.system`
- `\\.cornerRadius\\(`
- `struct [A-Za-z0-9_]+: View \\{`

Luego abre solo los archivos que concentren patrones relevantes: vistas raiz, tabs, pantallas de detalle, pantallas administrativas, vistas con formularios y el estado global.

## Que Debes Detectar

### 1. Navegacion mal escalada

Marca `NavigationStack` anidados en tabs, menus o destinos cuando rompan profundidad de navegacion, estado o consistencia.

Busca especialmente:

- una `TabView` donde cada tab vuelve a crear su propio stack sin necesidad
- pantallas destino que envuelven su contenido en un stack adicional
- hojas o flows que reutilizan stacks para esconder problemas de composicion

### 2. Estado compartido y previews fragiles

Marca singletons usados directamente en `@StateObject`, previews o vistas cuando introduzcan side effects, dependencia global o previews no deterministas.

Busca:

- `AppState.shared` en previews
- previews que mutan estado singleton
- vistas que dependen de servicios compartidos en vez de datos de ejemplo

### 3. Vistas demasiado grandes o con multiples responsabilidades

Marca archivos que mezclan demasiadas pantallas, formularios, filas y helpers en un mismo lugar.

Regla practica:

- una vista raiz con multiples pantallas hijas dentro del mismo archivo
- archivos con muchos `struct ...: View` que ya representan features distintas
- mezcla de carga async, permisos, navegacion, layout y celdas en una sola vista

### 4. Logica visual duplicada

Detecta duplicacion de:

- avatar de usuario
- badge de rol o estado
- chips de filtros
- estadisticas/resumenes
- mapeos de tipo -> icono/color

No reportes cada duplicado por separado. Propone una extraccion comun.

### 5. Carga async pegada a la vista

Marca vistas donde `@State` guarda multiples flags y arrays mientras la vista tambien resuelve permisos, relaciones y transformaciones.

Busca:

- varios `@State` para `isLoading`, `errorMessage`, `showSuccess`, `selectedFilter`, `updatingItemId`
- multiples `.task` en la misma pantalla
- recarga repetida al cambiar tabs o reaparecer vistas

Propone separar:

- `LoadableState` o `enum` de estado
- metodos async agrupados
- view models solo si reducen complejidad real

### 6. Errores y presentacion de alertas poco idiomaticos

Marca patrones como:

- `.alert(..., isPresented: .constant(errorMessage != nil))`
- estado espejo como `showingError` derivado de otro estado con `.onChange`

Prefiere estado unico e identificable.

### 7. Stringly typed UI

Marca conversiones visuales basadas en `lowercased().contains(...)`, `uppercased() == ...` o strings dispersos si el dominio ya tiene enums o deberia tenerlos.

Prioriza:

- tipo de kit
- tipo de vehiculo
- estado
- permisos o roles mostrados en UI

### 8. UIKit innecesario y estilos dispersos

Marca uso de UIKit solo para apariencia si SwiftUI puede resolverlo mejor o si el estilo deberia centralizarse.

Tambien marca:

- `Color(.system...)` repetido sin tokens de diseno
- `cornerRadius` repetido en vez de `clipShape` o estilos reutilizables

### 9. Accesibilidad real

No te limites a verificar labels. Revisa:

- botones solo con icono
- chips o badges que comunican informacion solo con color
- cabeceras horizontales de stats que pueden truncarse con texto grande
- filas complejas sin resumen accesible

## Salida

Entrega primero hallazgos, ordenados por severidad.

Para cada hallazgo incluye:

1. archivo y linea aproximada
2. patron o regla violada
3. por que importa en SwiftUI
4. correccion recomendada
5. antes/despues breve si ayuda

Despues cierra con:

- `Prioridades`
- `Refactors transversales`
- `Gaps de validacion`

## Reglas de Calidad

- Reporta solo problemas reales y defendibles.
- Si un problema aparece en muchas vistas, elevalo a patron transversal.
- Prefiere refactors que reduzcan complejidad estructural antes que cambios visuales menores.
- Si el proyecto ya tiene un componente reutilizable, usalo como punto de consolidacion en vez de inventar otro.
- Si necesitas detalles concretos para una app tipo AmbuKit, lee `references/ambukit-patterns.md`.
