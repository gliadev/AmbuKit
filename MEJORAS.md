# MEJORAS — AmbuKit

Revisado: 2026-05-03 | Herramientas: swiftui-pro + swift-concurrency-pro

**Estado:** 🔴 pendiente · 🟡 en progreso · ✅ hecho · ⏸️ postpuesto

---

## Prioridad ALTA

### ✅ M1 — NavigationStack anidados en AdminView y ProfileView
- **Archivos:** `Views/Admin/AdminView.swift:40`, `Views/Profile/ProfileView.swift:28`
- **Problema:** Ambas vistas crean su propio `NavigationStack` pero se presentan como destino de `NavigationLink` dentro del stack de `MoreMenuView`. Esto produce stacks anidados que rompen el gesture-back y la profundidad de navegación.
- **Fix:** Eliminar el `NavigationStack` de `AdminView` y `ProfileView`. El stack de `MoreMenuView` ya lo provee. Reemplazar por `Group { ... }.navigationTitle(...)`.

### ✅ M2 — `.tabItem {}` deprecated → `Tab` API
- **Archivo:** `Views/Components/MainTabView.swift:74–115`
- **Problema:** Usa el API `tabItem` deprecado. La selección también usa `Int` en lugar de un enum tipado.
- **Fix:** Migrar a `Tab("Label", systemImage:, value:) { ... }` con `@State private var selectedTab: AppTab = .inventory` donde `AppTab` es un enum `CaseIterable`.

### ✅ M3 — `.alert(isPresented: .constant(errorMessage != nil))` roto
- **Archivo:** `Views/Inventory/KitDetailView.swift:66`
- **Problema:** `Binding.constant(true/false)` hace que el alert no se pueda dismissar correctamente; el sistema no puede escribir de vuelta el estado.
- **Fix:** Usar un `Binding` real o `alert(item:)` con un tipo `Identifiable`.

---

## Prioridad MEDIA

### ✅ M4 — Stringly typed: tipo de kit y tipo de vehículo
- **Archivos:** `Views/Inventory/InventoryView.swift:330`, `Views/Vehicles/VehiclesView.swift:318,446`
- **Problema:** Los mapeos tipo→icono y tipo→color se hacen con `.lowercased().contains("sva")` o `.uppercased() == "SVA"` dispersos en 4+ vistas. El dominio ya tiene `KitType` y `VehicleFS.VehicleType`.
- **Fix:** Añadir extensiones `var color: Color` y `var systemImage: String` al enum existente. Mover allí toda la lógica visual del dominio. Eliminar switch duplicado en `VehicleRowView` y `VehicleDetailScreen`.

### ✅ M5 — Búsqueda con API incorrecta
- **Archivos:** `Views/Inventory/InventoryView.swift:57`, `Views/Vehicles/VehiclesView.swift:84`, `Views/Admin/ManagementViews.swift:30`
- **Problema:** Usan `localizedCaseInsensitiveContains` o `.lowercased().contains()`. La regla del proyecto exige `localizedStandardContains()` para input del usuario.
- **Fix:** Reemplazar globalmente con `localizedStandardContains`.

### ✅ M6 — `showsIndicators: false` deprecated en ScrollView
- **Archivo:** `Views/Vehicles/VehiclesView.swift:159,205`
- **Problema:** `ScrollView(.horizontal, showsIndicators: false)` es el inicializador antiguo.
- **Fix:** Quitar el parámetro del init y añadir `.scrollIndicators(.hidden)` como modificador.

### ✅ M7 — Computed properties devolviendo vistas (extraer a structs)
- **Archivos:** `MainTabView.swift` (loadingView, mainTabView), `RootView.swift` (splashScreen, loadingScreen), `InventoryView.swift` (loadingView, emptyStateView, kitsList, statsHeader), `VehiclesView.swift` (loadingView, emptyView, statsHeader, filterMenu), `AdminView.swift` (loadingView, adminContent), `KitDetailView.swift` (loadingView, emptyStateView, contentView)
- **Problema:** Usar `private var xxx: some View` penaliza performance y no es el patrón SwiftUI recomendado; SwiftUI no puede optimizarlos como nodos del árbol independientes.
- **Fix:** Convertir cada computed view property en un `View` struct dedicado, en su propio archivo cuando sea reutilizable.

### ✅ M8 — Múltiples structs por archivo
- **Archivos:** `AdminView.swift` (5 tipos), `VehiclesView.swift` (5 tipos), `InventoryView.swift` (4 tipos), `MainTabView.swift` (3 tipos)
- **Problema:** Viola la regla del proyecto: un tipo = un archivo.
- **Fix:** Separar cada struct en su propio archivo dentro del feature folder correspondiente.

### ✅ M9 — Estado espejo `showingError` en LoginView
- **Archivo:** `Views/Auth/LoginView.swift:19,73`
- **Problema:** `showingError: Bool` es un mirror de `appState.currentError != nil`, sincronizado con `onChange`. Doble fuente de verdad.
- **Fix:** Eliminar `showingError` y usar un `Binding` directo al optional o `alert(item:)`.

### ✅ M10 — `@EnvironmentObject` no utilizado en MainTabView
- **Archivo:** `Views/Components/MainTabView.swift:24`
- **Problema:** `@EnvironmentObject private var appState` declarado pero nunca referenciado en body ni en métodos de instancia.
- **Fix:** Eliminar la declaración.

### ✅ M11 — `UITabBarAppearance` innecesario
- **Archivo:** `Views/Components/MainTabView.swift:141–146`
- **Problema:** Llama a `UITabBarAppearance` via UIKit solo para configurar apariencia por defecto. No añade comportamiento exclusivo.
- **Fix:** Eliminar `configureTabBarAppearance()`. En iOS 26 la apariencia por defecto es correcta.

### ✅ M12 — Stats de VehiclesView: cinco pasadas sobre el mismo array
- **Archivo:** `Views/Vehicles/VehiclesView.swift:97–101`
- **Problema:** `svaCount`, `svbCount`, `withBaseCount`, `withKitsCount`, `totalCount` iteran el array cinco veces en cinco computed properties separadas.
- **Fix:** Calcular todo en una sola pasada dentro de `loadData()` o con una struct `VehicleStats`.

### ✅ M13 — `filter { $0 }.count` → `count(where:)`
- **Archivo:** `Views/Admin/AdminView.swift:142`
- **Fix:** `[...].count(where: { $0 })`

---

## Concurrencia — Prioridad MEDIA

### ✅ C1 — `DispatchQueue.main.asyncAfter` en vista `@MainActor`
- **Archivo:** `Views/Components/AnimatedSaveButton.swift:146,154`
- **Problema:** Captura `state` (un `@Binding` de `@MainActor`) desde una closure GCD. Bajo Swift 6 strict concurrency esto produce advertencia de data race; además mezcla GCD con el modelo de aislamiento de Swift Concurrency.
- **Fix:** Reemplazar ambas llamadas con `Task { try? await Task.sleep(for: .seconds(N)); if ... }`.

### ✅ C2 — `Task.sleep(nanoseconds:)` — API obsoleta
- **Archivos:** `Core/Services/Firebase/Sync/SyncServices.swift:192,295,333`, `Views/Components/AnimatedSaveButton.swift:226`
- **Problema:** `Task.sleep(nanoseconds:)` está deprecado. Usar `Task.sleep(for:)`.
- **Fix:** Reemplazar todas las ocurrencias con `Task.sleep(for: .seconds(N))` o `.milliseconds(N)`.

### ✅ C3 — `try?` silencia `CancellationError` en sleeps de SyncService
- **Archivo:** `Core/Services/Firebase/Sync/SyncServices.swift:192,295`
- **Problema:** `try? await Task.sleep(...)` dentro del `syncTask` traga el `CancellationError`. Si el task es cancelado externamente, el bucle de sincronización no se interrumpe; continúa procesando operaciones con un task ya cancelado.
- **Fix:** Propagar la cancelación. `guard !Task.isCancelled else { break }` antes de cada sleep, o cambiar el sleep a `try await` y gestionar `CancellationError` en el caller.

### ✅ C4 — Orphan reset task en `syncPendingOperations()`
- **Archivo:** `Core/Services/Firebase/Sync/SyncServices.swift:332`
- **Problema:** `Task { try? await Task.sleep(for: .seconds(3)); if state == .completed { state = .idle } }` se crea sin guardar su handle. Si sync se invoca dos veces rápidamente, el primer reset puede ejecutarse cuando el estado ya cambió por el segundo ciclo.
- **Fix:** Añadir `private var resetTask: Task<Void, Never>?`, cancelar antes de recrear, igual que ya se hace con `syncTask`.

---

## Tests — Prioridad ALTA

### ✅ T1 — Migrar todas las suites de XCTest a Swift Testing
- **Archivos:** `AmbuKitTests/Firebase/Services/*.swift`, `AmbuKitTests/IntegrationTest/*.swift`, `AmbuKitTests/Utilities/ValidatorsTests.swift`
- **Problema:** Todos los tests (salvo el placeholder) usan `XCTestCase`, `XCTAssert*`, `setUp()`/`tearDown()`, `XCTSkip` y `XCTFail`. Swift Testing es el estándar moderno, soporta ejecución paralela por defecto y macros más expresivas.
- **Fix:** Convertir cada `final class … : XCTestCase` en `struct`. Reemplazar `setUp`/`tearDown` por `init()`. Sustituir `XCTAssert*` por `#expect`/`#require`, `XCTFail` por `Issue.record()`, y `XCTSkip` por el trait `.enabled(if:)` o `#require`.
- **Nota:** No migrar `AmbuKitUITests/` — UI tests requieren XCTest.

### ✅ T2 — `XCTAssertTrue(true)` / aserciones no-op que dan falsa cobertura
- **Archivos:**
  - `UserServiceTests.swift:499,514` — catch de `testDeleteUser_WithoutPermissions_Fails` y `testDeleteUser_Self_Fails`
  - `VehicleServiceTests.swift:168,191,220,244` — varios catch con `XCTAssertTrue(true)`
  - `SyncFlowTests.swift:354` — `testCrossServiceConsistency` cierra con `XCTAssertTrue(true, "...")`
  - `ModelEncodingTests.swift:208` — `testAllModelsSendable`
- **Problema:** `XCTAssertTrue(true)` siempre pasa. En catch blocks hace que el test sea verde incluso si se lanza el error equivocado. En `testCrossServiceConsistency` la aserción `XCTAssertNotNil(vehicle)` solo se ejecuta si `vehicle != nil`, exactamente la condición inversa.
- **Fix:** En catch: `#expect(error is VehicleServiceError)`. En `testAllModelsSendable`: eliminar (verificación en tiempo de compilación). En `testCrossServiceConsistency`: invertir lógica con `#expect(vehicle != nil, "...")` dentro del `for`.

### ✅ T3 — `Task.sleep(nanoseconds:)` deprecated en tests
- **Archivos:** `VehicleServiceTests.swift:400`, `InventoryFlowTests.swift:169`
- **Fix:** `Task.sleep(for: .seconds(1))` y `Task.sleep(for: .milliseconds(500))`.

---

## Tests — Prioridad MEDIA

### ✅ T4 — Tests repetitivos que deberían ser parametrizados
- **Archivos:**
  - `PolicyServiceTests.swift` — `testGetRoleProgrammerExists`, `testGetRoleLogisticsExists`, `testGetRoleSanitaryExists` (3 tests idénticos variando solo el `RoleKind`)
  - `PolicyServiceTests.swift` — `testIsProgrammerHelper`, `testIsLogisticsHelper`, `testIsSanitaryHelper`
  - `VehicleServiceTests.swift:482` — `testCreateVehicle_AllTypes` usa `for vehicleType in types` dentro del test
  - `ModelEncodingTests.swift` — `testRoleKindCodable`, `testEntityKindCodable`, `testActionKindCodable`, `testKitTypeCodable`
- **Fix:** Usar `@Test(arguments:)`:
  ```swift
  @Test(arguments: [RoleKind.programmer, .logistics, .sanitary])
  func roleExists(_ kind: RoleKind) async throws { … }

  @Test(arguments: VehicleFS.VehicleType.allCases)
  func createVehicle_AllTypes(_ type: VehicleFS.VehicleType) async throws { … }
  ```

### ✅ T5 — Force unwraps en tests deberían usar `try #require`
- **Archivos:** `VehicleServiceTests.swift:139,311`, `SyncFlowTests.swift:135`, `InventoryFlowTests.swift:134,197,248,293,374`, `AuthFlowTests.swift:74,215`
- **Problema:** `vehicle.id!`, `kit.id!`, `initialUsers.first!.id!` crashean el proceso completo en lugar de fallar el test limpiamente.
- **Fix:** `try #require(vehicle.id)`. Se aplica de forma natural al migrar a Swift Testing (T1).

### ✅ T6 — Falta de tags para categorizar y filtrar tests
- **Archivos:** Todos los archivos de test
- **Fix:** Declarar tags en `AmbuKitTests/Tags.swift`:
  ```swift
  extension Tag {
      @Tag static var firebase: Self
      @Tag static var integration: Self
      @Tag static var slow: Self
      @Tag static var unit: Self
  }
  ```
  Aplicar `@Suite(.tags(.firebase, .slow))` a suites Firebase y `@Test(.tags(.unit))` a `ValidatorsTests` y `ModelEncodingTests`.

### ⏸️ T7 — `@MainActor` innecesario en suites de tests puros
- **Archivos:** `ValidatorsTests.swift:14`, `ModelEncodingTests.swift:19`
- **Problema:** `Validators` y los modelos FS son tipos de valor puros. `@MainActor` en la suite fuerza todos los tests al hilo principal innecesariamente.
- **Fix:** Eliminar `@MainActor` de `ValidatorsTests` y `ModelEncodingTests`.

### ✅ T8 — Comprobación de errores demasiado permisiva (string matching)
- **Archivos:** `UserServiceTests.swift:202-208,244-250,386-390,444-447`
- **Problema:** `error.localizedDescription.lowercased().contains("autoriz")` pasa con cualquier error que contenga esa substring.
- **Fix:** `#expect(error is UserServiceError)` o `#expect(throws: UserServiceError.unauthorized) { … }`.

### ✅ T9 — Tests de integración sin límite de tiempo
- **Archivos:** `AuthFlowTests.swift`, `SyncFlowTests.swift`, `InventoryFlowTests.swift`
- **Problema:** Tests contra Firebase real pueden colgar indefinidamente si hay problemas de red.
- **Fix:**
  ```swift
  @Suite(.tags(.integration, .slow), .timeLimit(.minutes(2)))
  struct AuthFlowTests { … }
  ```

### ✅ T10 — Aserciones trivialmente verdaderas sobre no-opcionales
- **Archivos:** `AuthFlowTests.swift:116-118`
- **Problema:** `XCTAssertNotNil(users)` donde `users: [UserFS]` (array, nunca nil).
- **Fix:** `#expect(users.isEmpty == false)`.

---

## Tests — Prioridad BAJA

### ✅ T11 — Placeholder de test vacío
- **Archivo:** `AmbuKitTests/AmbuKitTests.swift`
- **Fix:** Eliminar o reemplazar con un smoke test real (p. ej., verificar que los enums básicos son codificables).

### ✅ T12 — Trailing whitespace excesivo en varios archivos
- **Archivos:** `UserServiceTests.swift` (lines 581–619), `InventoryFlowTests.swift` (lines 433–476), `SyncFlowTests.swift`
- **Fix:** Eliminar las 30–40 líneas en blanco al final de cada archivo.

---

## Concurrencia — Prioridad BAJA

### ✅ C5 — Error silenciado en sign-out de usuario inactivo
- **Archivo:** `Core/Services/Firebase/Auth/FirebaseAuthService.swift:237`
- **Problema:** `Task { try? await signOut() }` — si el sign-out falla el usuario queda en estado inconsistente sin ninguna señal.
- **Fix:** `do { try await signOut() } catch { print("⚠️ Sign-out fallido: \(error)") }`.

---

## Prioridad BAJA

### ✅ M14 — `roleColor` duplicado en tres vistas
- **Archivos:** `MainTabView.swift:301`, `AdminView.swift:460`, `ProfileView.swift:202`
- **Fix:** Añadir `var color: Color` como extensión de `RoleKind`.

### ✅ M15 — Icon-only buttons sin label de texto
- **Archivos:** `Views/Inventory/InventoryView.swift:108`, `ManagementViews.swift:82`, `KitDetailView.swift:82`
- **Problema:** VoiceOver no puede describir la acción correctamente.
- **Fix:** `Button("Filtrar", systemImage: "line.3.horizontal.decrease.circle") { ... }` con `.labelStyle(.iconOnly)` si hace falta mantener el aspecto visual.

### ✅ M16 — Estado de filtros comunicado solo por color
- **Archivo:** `Views/Vehicles/VehiclesView.swift:283–305` (VehicleFilterChip)
- **Problema:** Chip seleccionado = fondo azul; sin indicador para usuarios con daltonismo.
- **Fix:** Añadir checkmark o borde, o respetar `.accessibilityDifferentiateWithoutColor`.

### ✅ M17 — `caption2` usado en múltiples vistas
- **Archivos:** `MainTabView.swift:319,322`, `InventoryView.swift:237`, `VehiclesView.swift:270,295,411`
- **Problema:** `.caption2` es extremadamente pequeño; el design guide lo marca como "generally best avoided".
- **Fix:** Evaluar si `.caption` es suficiente en cada caso.

### ⏸️ M18 — `AppState` con patrón ObservableObject (deuda arquitectural)
- **Archivo:** `App/AppState.swift`
- **Problema:** Usa `ObservableObject` / `@Published` / `@EnvironmentObject`. El patrón moderno es `@Observable` + `@Environment`.
- **Nota:** Migración compleja por integración con Firebase y Combine. **Postpuesta para después de la entrega del TFG.**
