# 🚑 AmbuKit

<img width="777" height="468" alt="presentacion" src="https://github.com/user-attachments/assets/0e1ebd21-5f67-4e11-a21d-4d9475963d62" />


Aplicación nativa iOS para la gestión integral de material sanitario en servicios de emergencias.

📱 **iPhone & iPad** | ✨ **Liquid Glass** | 📴 **Modo Offline** | 🔐 **Roles y permisos**

---

## 📋 Descripción

AmbuKit es una app iOS diseñada para controlar el inventario de medicamentos y material sanitario en ambulancias, garantizando que el personal de emergencias disponga siempre del equipamiento necesario.

**Característica clave:** Soporte offline completo, fundamental para operaciones en zonas sin cobertura como túneles, áreas rurales o sótanos de hospitales.

---

## 🎯 Problema que resuelve

Los servicios de emergencias se enfrentan a desafíos críticos:

| Desafío | Descripción |
|---------|-------------|
| 📦 **Control de inventario** | Necesidad de conocer en tiempo real qué material hay en cada ambulancia |
| ⏰ **Caducidades** | Medicamentos que expiran y deben ser sustituidos a tiempo |
| 📴 **Desconexión** | Las ambulancias operan frecuentemente en zonas sin cobertura móvil |
| 📝 **Trazabilidad** | Requisito legal de saber quién manipuló cada medicamento |
| 🔐 **Permisos** | No todo el personal puede realizar las mismas operaciones |

---

## 💡 Solución

AmbuKit ofrece:

- ☁️ Centraliza la información de todos los botiquines en la nube (Firebase)
- 📴 Funciona sin conexión guardando operaciones localmente
- 🔄 Sincroniza automáticamente cuando recupera conectividad
- 👥 Controla accesos mediante roles (Programador, Logística, Sanitario)
- 📋 Registra todas las acciones para auditoría y cumplimiento normativo

---

## 📱 Capturas de Pantalla
![ipadPro](https://github.com/user-attachments/assets/9d9dac1b-1a34-48dc-a64d-fee5a520d817)




---

## ✨ Características Principales

### 📦 Gestión de Inventario

| Funcionalidad | Descripción |
|---------------|-------------|
| Catálogo de productos | Material médico organizado por categorías (Farmacia, Curas, Trauma, etc.) |
| Kits configurables | Botiquines personalizables asignables a vehículos |
| Control de stock | Gestión de cantidades con umbrales mínimos y máximos |
| Control de caducidades | Alertas automáticas de productos próximos a caducar |

### 👥 Sistema de Roles

| Rol | Permisos |
|-----|----------|
| **Programador** | Acceso total: gestión de usuarios, kits, vehículos y configuración |
| **Logística** | Gestión de inventario y stock (no puede crear kits ni usuarios) |
| **Sanitario** | Actualización de cantidades (lectura del resto) |

### 📴 Funcionalidad Offline

- **Modo sin conexión:** Operaciones locales cuando no hay cobertura
- **Sincronización automática:** Los datos se sincronizan al recuperar conexión
- **Cola de operaciones:** Las acciones pendientes se guardan hasta poder enviarlas

### 📝 Auditoría y Trazabilidad

- Registro completo de todas las acciones realizadas
- Información de quién, qué y cuándo para cada operación
- Histórico de cambios accesible para consulta

---

## 🛠 Stack Tecnológico

| Capa | Tecnología | Versión |
|------|------------|---------|
| Lenguaje | Swift | 6.0 |
| UI Framework | SwiftUI + Liquid Glass | iOS 26 |
| IDE | Xcode | 26+ |
| Plataforma | iOS (iPhone & iPad) | 26+ |
| Backend | Firebase | 11.0+ |
| Autenticación | Firebase Auth | 11.0+ |
| Base de Datos | Cloud Firestore | 11.0+ |
| Arquitectura | MVVM + Services | - |
| Concurrencia | Swift Concurrency | async/await, @MainActor, Sendable |
| Testing | Swift Testing | 189 tests |
| Control de versiones | Git + GitHub | - |

### ¿Por qué Firebase?

Decisión estratégica como BaaS (Backend as a Service) que proporciona:
- Autenticación lista para usar
- Base de datos en tiempo real
- Sincronización offline nativa
- Security Rules para control de accesos
- Escalabilidad sin gestión de servidores

---

## 🧪 Testing
```
168 tests cubriendo:
├── Unit Tests (lógica de negocio)
├── Integration Tests (Firebase + ViewModels)
└── Security Rules Tests (73 tests de permisos)
```

---

## 🚀 Instalación

### Requisitos Previos

- macOS 15.0+ (Sequoia)
- Xcode 26+
- iOS 26+ (dispositivo o simulador)
- Swift 6.0
- Cuenta de Firebase (plan Spark gratuito suficiente)

### Pasos
```bash
# Clonar el repositorio
git clone https://github.com/gliadev/AmbuKit.git

# Abrir en Xcode
cd AmbuKit
open AmbuKit.xcodeproj

# Configurar Firebase (añadir GoogleService-Info.plist)
# Build & Run
```

---



---

## 📚 Sobre el Proyecto

Este proyecto forma parte del **Trabajo Fin de Grado (TFG)** del Ciclo Superior de Desarrollo de Aplicaciones Multiplataforma (DAM).

| | |
|---|---|
| **Titulación** | CFGS Desarrollo de Aplicaciones Multiplataforma |
| **Módulo** | Proyecto Fin de Grado |
| **Período** | 2022 - 2025 |
| **Centro** | UAX |

---

## 👨‍💻 Autor

**Adolfo Gómez** - *gliadev*

🌐 [Portfolio](https://gliadev.vercel.app)
💼 [LinkedIn](tu-linkedin)
🐙 [GitHub](https://github.com/gliadev)

---

## ⚠️ Licencia

Este código es público con fines educativos y de portfolio. 

**Todos los derechos reservados.**

Para uso comercial o cualquier consulta, contactar con el autor.

---

<p align="center">
  Hecho con ❤️ para aquellos que corren en sentido contrario al que los demás huyen
</p>
