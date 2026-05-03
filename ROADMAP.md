# ROADMAP — AmbuKit

Orden basado en: corrección y estabilidad > mantenibilidad > estética.  
Cada sesión deja el proyecto compilando y funcional.  
Ver descripciones completas y estado de cada tarea en [MEJORAS.md](MEJORAS.md).

---

## Sesión 1 — Concurrencia crítica (~45 min)

**Objetivo:** Eliminar data races y comportamiento indefinido. Cambios quirúrgicos de 1-3 líneas.

| ID | Archivo | Cambio |
|----|---------|--------|
| C1 | `Views/Components/AnimatedSaveButton.swift:146,154` | `DispatchQueue.main.asyncAfter` → `Task { try? await Task.sleep(for: .seconds(N)) }` |
| C2 | `Core/Services/Firebase/Sync/SyncServices.swift:192,295,333` | `Task.sleep(nanoseconds:)` → `Task.sleep(for: .seconds(N))` |
| C2 | `Views/Components/AnimatedSaveButton.swift:226` | Mismo cambio en preview |
| C3 | `Core/Services/Firebase/Sync/SyncServices.swift:192,295` | `guard !Task.isCancelled else { break }` antes de cada sleep |
| C4 | `Core/Services/Firebase/Sync/SyncServices.swift:332` | `private var resetTask: Task<Void, Never>?`; cancelar antes de recrear |
| C5 | `Core/Services/Firebase/Auth/FirebaseAuthService.swift:237` | `try? await signOut()` → `do { try await signOut() } catch { print("⚠️ \(error)") }` |

**Done cuando:** El proyecto compila sin warnings de concurrencia. Las funciones de `SyncServices` respetan cancelación.

---

## Sesión 2 — Navegación y alertas rotas (~1 h)

**Objetivo:** Eliminar comportamiento visible al usuario: gesture-back roto, alert que no se puede dismissar.

| ID | Archivo | Cambio |
|----|---------|--------|
| M1 | `Views/Admin/AdminView.swift:40` | Eliminar `NavigationStack`; `Group { ... }.navigationTitle(...)` |
| M1 | `Views/Profile/ProfileView.swift:28` | Mismo patrón |
| M3 | `Views/Inventory/KitDetailView.swift:66` | `.alert(isPresented: .constant(...))` → `alert(item:)` con tipo `Identifiable` |
| M9 | `Views/Auth/LoginView.swift:19,73` | Eliminar `showingError: Bool`; `alert(item:)` directo sobre `appState.currentError` |

**Done cuando:** Gesture-back funciona desde AdminView y ProfileView. El alert de KitDetailView se puede dismissar. LoginView sin estado espejo.

---

## Sesión 3 — APIs modernas (~30 min)

**Objetivo:** Eliminar deprecaciones que generan warnings de compilación.

| ID | Archivo | Cambio |
|----|---------|--------|
| M2 | `Views/Components/MainTabView.swift:74–115` | `tabItem {}` → `Tab("Label", systemImage:, value:) { }` con `AppTab: CaseIterable` |
| M5 | `Views/Inventory/InventoryView.swift:57` | `localizedCaseInsensitiveContains` → `localizedStandardContains` |
| M5 | `Views/Vehicles/VehiclesView.swift:84` | Mismo cambio |
| M5 | `Views/Admin/ManagementViews.swift:30` | Mismo cambio |
| M6 | `Views/Vehicles/VehiclesView.swift:159,205` | `ScrollView(.horizontal, showsIndicators: false)` → `ScrollView(.horizontal)` + `.scrollIndicators(.hidden)` |
| M10 | `Views/Components/MainTabView.swift:24` | Eliminar `@EnvironmentObject private var appState` no utilizado |
| M11 | `Views/Components/MainTabView.swift:141–146` | Eliminar `configureTabBarAppearance()` |
| M13 | `Views/Admin/AdminView.swift:142` | `.filter { $0 }.count` → `.count(where: { $0 })` |

**Done cuando:** Cero warnings de API deprecada en los archivos modificados.

---

## Sesión 4 — Dominio tipado: extensiones de enum (~45 min)

**Objetivo:** Centralizar la lógica visual del dominio en los enums. Eliminar `switch` / `contains` dispersos.

| ID | Archivos afectados | Cambio |
|----|--------------------|--------|
| M4 | `Core/Utilities/Enums/KitType.swift` | Añadir `var color: Color` y `var systemImage: String` |
| M4 | `VehicleFS+VehicleType` | Mismo patrón |
| M4 | `Views/Inventory/InventoryView.swift:330`, `KitDetailView.swift:294` | Usar `kit.type.color`, `kit.type.systemImage` |
| M4 | `Views/Vehicles/VehiclesView.swift:318,446` | Eliminar `vehicleTypeInfo` switch duplicado en `VehicleRowView` y `VehicleDetailScreen` |
| M14 | `Core/Utilities/Enums/RoleKind.swift` | Añadir `var color: Color` |
| M14 | `MainTabView.swift:301`, `AdminView.swift:460`, `ProfileView.swift:202` | Usar `role.kind.color` |

**Done cuando:** No queda ningún `.lowercased().contains(...)` ni `.uppercased() == "SVA"` en código de UI. El switch de `vehicleTypeInfo` existe en exactamente un lugar.

---

## Sesión 5 — Separar archivos multi-struct (~1.5 h)

**Objetivo:** Cumplir la regla "un tipo = un archivo". Refactor mecánico, no cambia comportamiento.

| ID | Archivo origen | Tipos a extraer |
|----|----------------|-----------------|
| M8 | `Views/Admin/AdminView.swift` | `CreateBaseSheet`, `CreateVehicleSheet`, `CreateKitSheet`, `CreateUserSheet` → `Views/Admin/` |
| M8 | `Views/Vehicles/VehiclesView.swift` | `VehicleRowView`, `VehicleDetailScreen`, `VehicleFilterChip`, `VehicleStatsView` → `Views/Vehicles/` |
| M8 | `Views/Inventory/InventoryView.swift` | `KitRowView`, `StatsHeader`, `EmptyInventoryView` → `Views/Inventory/` |
| M8 | `Views/Components/MainTabView.swift` | `MoreMenuView`, `MenuCard` → `Views/Components/` |

**Done cuando:** Ningún archivo de Views contiene más de un `struct … : View` (excepto extensiones privadas de apoyo).

---

## Sesión 6 — Computed view props → structs (~2 h)

**Objetivo:** Convertir `private var loadingView: some View` y similares en structs propios.

| ID | Archivo | Props a extraer |
|----|---------|-----------------|
| M7 | `MainTabView.swift` | `loadingView`, `mainTabView` |
| M7 | `RootView.swift` | `splashScreen`, `loadingScreen` |
| M7 | `InventoryView.swift` | `loadingView`, `emptyStateView`, `kitsList`, `statsHeader` |
| M7 | `VehiclesView.swift` | `loadingView`, `emptyView`, `statsHeader`, `filterMenu` |
| M7 | `AdminView.swift` | `loadingView`, `adminContent` |
| M7 | `KitDetailView.swift` | `loadingView`, `emptyStateView`, `contentView` |

Estrategia: structs privados al final del mismo archivo; moverlos a archivo propio solo si son reutilizables entre vistas.

**Done cuando:** Ninguna vista de las listadas tiene computed properties que devuelvan `some View`.

---

## Sesión 7 — Stats y estado de carga (~1 h)

**Objetivo:** Reducir trabajo redundante en runtime.

| ID | Archivo | Cambio |
|----|---------|--------|
| M12 | `Views/Vehicles/VehiclesView.swift:97–101` | Calcular `svaCount`, `svbCount`, `withBaseCount`, `withKitsCount`, `totalCount` en una sola pasada con `struct VehicleStats` dentro de `loadData()` |

**Nota:** Si al extraer structs en Sesión 6 se detectan vistas con 4+ `@State` para flags de carga, valorar introducir `enum ViewState<T>`. No obligatorio.

**Done cuando:** `VehiclesView` itera la colección de vehículos una sola vez para calcular estadísticas.

---

## Sesión 8 — Accesibilidad y pulido (~45 min)

**Objetivo:** Fixes de baja complejidad con impacto en accesibilidad.

| ID | Archivo | Cambio |
|----|---------|--------|
| M15 | `Views/Inventory/InventoryView.swift:108` | `Label("Filtrar", systemImage: "line.3.horizontal.decrease.circle")` en el Menu |
| M15 | `Views/Admin/ManagementViews.swift:82` | `Button("Añadir", systemImage: "plus") { ... }` |
| M15 | `Views/Inventory/KitDetailView.swift:82` | `Button("Actualizar", systemImage: "arrow.clockwise") { ... }` |
| M16 | `Views/Vehicles/VehiclesView.swift:283–305` | Añadir checkmark o borde a `VehicleFilterChip` seleccionado |
| M17 | Múltiples | Revisar cada uso de `.caption2`; sustituir por `.caption` donde no sea imprescindible |

**Done cuando:** Ningún botón de los listados es icon-only. El chip seleccionado tiene indicador no cromático.

---

## Sesión 9 — Deuda arquitectural (post-TFG)

| ID | Cambio |
|----|--------|
| M18 | Migrar `AppState` de `ObservableObject`/`@Published`/`@EnvironmentObject` a `@Observable` + `@Environment`. Requiere refactor coordinado con Firebase Combine publishers. |

**Prerequisito:** Entrega del TFG completada.

---

## Sesión 10 — Fixes rápidos en tests (~30 min)

**Objetivo:** Eliminar aserciones no-op, deprecaciones y ruido antes de la migración principal.

| ID | Archivo | Cambio |
|----|---------|--------|
| T2 | `UserServiceTests.swift:499,514` | `XCTAssertTrue(true)` → `#expect(error is UserServiceError)` |
| T2 | `VehicleServiceTests.swift:168,191,220,244` | Mismo patrón |
| T2 | `SyncFlowTests.swift:354` | Eliminar no-op e invertir lógica de `testCrossServiceConsistency` |
| T2 | `ModelEncodingTests.swift:208` | Eliminar `XCTAssertTrue(true)` en `testAllModelsSendable` |
| T3 | `VehicleServiceTests.swift:400` | `Task.sleep(nanoseconds:)` → `Task.sleep(for: .seconds(1))` |
| T3 | `InventoryFlowTests.swift:169` | `Task.sleep(nanoseconds:)` → `Task.sleep(for: .milliseconds(500))` |
| T7 | `ValidatorsTests.swift:14`, `ModelEncodingTests.swift:19` | Eliminar `@MainActor` innecesario |
| T10 | `AuthFlowTests.swift:116–118` | `XCTAssertNotNil(array)` → `#expect(array.isEmpty == false)` |
| T11 | `AmbuKitTests/AmbuKitTests.swift` | Eliminar `example()` placeholder |
| T12 | `UserServiceTests.swift`, `InventoryFlowTests.swift`, `SyncFlowTests.swift` | Eliminar trailing blank lines (30–40 por archivo) |

**Done cuando:** No quedan aserciones no-op ni `Task.sleep(nanoseconds:)` en el target de tests.

---

## Sesión 11 — Migración completa a Swift Testing (~3 h)

**Objetivo:** Convertir todas las suites de XCTest a Swift Testing idiomático. Incluye T1, T4, T5, T6, T8, T9.

**Orden recomendado:**

1. **`ValidatorsTests.swift`** — Más sencillo (tests síncronos puros). Sirve de referencia.
2. **`ModelEncodingTests.swift`** — Tests puros de modelos. `testRoleKindCodable` + 3 similares → un único `@Test(arguments: ...)`.
3. **`AuthorizationServiceFSTests.swift`** — Primera suite Firebase. `setUp` → `init() async throws`.
4. **`PolicyServiceTests.swift`** — `testGetRole*Exists` (3 tests) → `@Test(arguments: RoleKind.allCases)`.
5. **`UserServiceTests.swift`** — Suite más compleja. Mantener limpieza con `deinit`.
6. **`VehicleServiceTests.swift`** — `testCreateVehicle_AllTypes` → `@Test(arguments: VehicleFS.VehicleType.allCases)`.
7. **`AuthFlowTests.swift`**, **`SyncFlowTests.swift`**, **`InventoryFlowTests.swift`** — Suites de integración con `@Suite(.tags(.integration, .slow), .timeLimit(.minutes(2)))`.

**Cambios transversales:**
- `XCTFail("msg")` → `Issue.record("msg")`
- `throw XCTSkip("msg")` → `try #require(condition, "msg")`
- `guard let x = optional else { XCTFail; return }` → `let x = try #require(optional)`
- Declaración de tags en `AmbuKitTests/Tags.swift`

**Done cuando:** Ningún archivo del target `AmbuKitTests` importa `XCTest` (excepto los UI tests en `AmbuKitUITests`).

---

## Resumen de esfuerzo

| Sesión | IDs | Tiempo est. | Riesgo |
|--------|-----|-------------|--------|
| 1 — Concurrencia crítica | C1–C5 | ~45 min | Bajo |
| 2 — Navegación y alertas | M1, M3, M9 | ~1 h | Medio |
| 3 — APIs modernas | M2, M5, M6, M10, M11, M13 | ~30 min | Bajo |
| 4 — Dominio tipado | M4, M14 | ~45 min | Bajo |
| 5 — Separar archivos | M8 | ~1.5 h | Bajo |
| 6 — Computed props → structs | M7 | ~2 h | Bajo |
| 7 — Stats y carga | M12 | ~1 h | Bajo |
| 8 — Accesibilidad | M15, M16, M17 | ~45 min | Bajo |
| 9 — Deuda arquitectural | M18 | TBD (post-TFG) | Alto |
| 10 — Fixes rápidos de tests | T2, T3, T7, T10, T11, T12 | ~30 min | Bajo |
| 11 — Migración Swift Testing | T1, T4, T5, T6, T8, T9 | ~3 h | Bajo |
| **Total** | **35 ítems** | **~12 h** | |
