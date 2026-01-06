# AmbuKit - Security Rules Tests

Tests de reglas de seguridad de Firestore para AmbuKit.

## 📋 Requisitos

- Node.js >= 18.0.0
- Firebase CLI >= 15.0.0
- Java Runtime (para el emulador de Firestore)

## 🚀 Instalación

```bash
cd SecurityTests
npm install
```

## 🔧 Ejecución

### 1. Iniciar el emulador de Firebase

En una terminal separada, desde la raíz del proyecto:

```bash
cd ..  # Ir a la raíz de AmbuKit
firebase emulators:start
```

Deberías ver:
```
✔  All emulators ready! It is now safe to connect your app.
│ ✔  Firestore │ localhost:8080 │
│ ✔  Auth      │ localhost:9099 │
│ ✔  UI        │ localhost:4000 │
```

### 2. Ejecutar los tests

En otra terminal:

```bash
cd SecurityTests
npm test
```

### 3. Ver resultados detallados

```bash
npm run test:verbose
```

## 📊 Resultado Esperado

```
PASS  firestore.test.js
  Unauthenticated Access
    ✓ usuarios no autenticados NO pueden leer users
    ✓ usuarios no autenticados NO pueden leer roles
    ...
  Users Collection Security
    ✓ todos los autenticados pueden leer users
    ✓ programmer PUEDE crear users
    ✓ logistics NO puede crear users
    ...
  Bases Collection Security
    ✓ logistics PUEDE crear bases
    ✓ sanitary NO puede crear bases
    ...
  AuditLogs Collection Security
    ✓ NI programmer puede crear auditLogs
    ✓ NI programmer puede eliminar auditLogs
    ...

Test Suites: 1 passed, 1 total
Tests:       XX passed, XX total
```

## 🔐 Matriz de Permisos Verificada

| Entidad | Create | Read | Update | Delete |
|---------|--------|------|--------|--------|
| Users | Prog | All | Prog | Prog |
| Roles | - | All | - | - |
| Policies | - | All | - | - |
| Bases | Prog, Log | All | Prog, Log | Prog |
| Vehicles | Prog, Log | All | Prog, Log | Prog |
| Kits | Prog, Log | All | Prog, Log | Prog |
| KitItems | Prog, Log | All | All* | Prog, Log |
| CatalogItems | Prog, Log | All | Prog, Log | Prog |
| AuditLogs | - | All | - | - |

*Sanitarios pueden actualizar `quantity` (stock)

## 🐛 Troubleshooting

### Error: "Could not reach Firestore Emulator"

Asegúrate de que el emulador está corriendo en `localhost:8080`:
```bash
firebase emulators:start
```

### Error: "ECONNREFUSED"

El emulador no está corriendo. Inícialo primero.

### Tests timeout

Aumenta el timeout en `jest.config.js`:
```javascript
testTimeout: 60000
```

## 📝 Añadir Nuevos Tests

1. Añade el test en `firestore.test.js`
2. Sigue el patrón existente de `describe/test`
3. Usa `assertSucceeds` para operaciones que DEBEN funcionar
4. Usa `assertFails` para operaciones que DEBEN ser denegadas

## 📚 Referencias

- [Firebase Rules Unit Testing](https://firebase.google.com/docs/rules/unit-tests)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
