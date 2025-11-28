📚 Sobre el Proyecto
Este proyecto forma parte del Trabajo Fin de Grado (TFG) del Ciclo Superior de Desarrollo de Aplicaciones Multiplataforma (DAM), curso 2024-2025.
Titulación CFGS Desarrollo de Aplicaciones Multiplataforma. MóduloProyecto Fin de GradoCurso 2022-2025

📋 Descripción
AmbuKit es una aplicación iOS nativa diseñada para la gestión integral de botiquines médicos en servicios de emergencias sanitarias.
El sistema permite controlar el inventario de medicamentos y material sanitario en ambulancias, garantizando que el personal de emergencias disponga siempre del equipamiento necesario. Una de sus características principales es el soporte offline, fundamental para operaciones en zonas sin cobertura como túneles, áreas rurales o sótanos de hospitales.
🎯 Problema que resuelve
Los servicios de emergencias se enfrentan a desafíos críticos en la gestión de su material:

Control de inventario: Necesidad de conocer en tiempo real qué material hay en cada ambulancia
Caducidades: Medicamentos que expiran y deben ser sustituidos a tiempo
Desconexión: Las ambulancias operan frecuentemente en zonas sin cobertura móvil
Trazabilidad: Requisito legal de saber quién manipuló cada medicamento
Permisos: No todo el personal puede realizar las mismas operaciones

💡 Solución propuesta
AmbuKit ofrece una solución completa que:

Centraliza la información de todos los botiquines en la nube (Firebase)
Funciona sin conexión guardando operaciones localmente
Sincroniza automáticamente cuando recupera conectividad
Controla accesos mediante un sistema de roles (Programador, Logística, Sanitario)
Registra todas las acciones para auditoría y cumplimiento normativo


📱 Capturas de Pantalla
<img width="1421" height="1319" alt="Captura de pantalla 28 11 2025 a 01 28 51 a  m" src="https://github.com/user-attachments/assets/32cc49c1-4760-4404-98e5-cf8e4a8e5881" />


✨ Características Principales
📦 Gestión de Inventario
FuncionalidadDescripciónCatálogo de productosMaterial médico organizado por categorías (Farmacia, Curas, Trauma, etc.)Kits configurablesBotiquines personalizables asignables a vehículosControl de stockGestión de cantidades con umbrales mínimos y máximosControl de caducidadesAlertas automáticas de productos próximos a caducar
👥 Sistema de Usuarios y Permisos
RolPermisosProgramadorAcceso total: gestión de usuarios, kits, vehículos y configuraciónLogísticaGestión de inventario y stock (no puede crear kits ni usuarios)SanitarioActualización de cantidades (lectura del resto)
📴 Funcionalidad Offline

Modo sin conexión: Operaciones locales cuando no hay cobertura
Sincronización automática: Los datos se sincronizan al recuperar conexión
Cola de operaciones: Las acciones pendientes se guardan hasta poder enviarlas

📝 Auditoría y Trazabilidad

Registro completo de todas las acciones realizadas
Información de quién, qué y cuándo para cada operación
Histórico de cambios accesible para consulta


Stack Tecnológico
CapaTecnologíaVersiónLenguajeSwift6.0UI FrameworkSwiftUI6.0IDEXcode16.0+PlataformaiOS17.0+BackendFirebase11.0+AutenticaciónFirebase Auth11.0+Base de DatosCloud Firestore11.0+ArquitecturaMVVM + Services-ConcurrenciaSwift Concurrencyasync/await, @MainActor, SendableTestingXCTestIntegradoControl de versionesGit + GitHub-

🚀 Instalación
Requisitos Previos

macOS 15.0+ (Sequoia) o macOS 14.0+ (Sonoma)
Xcode 16.0+
iOS 17.0+ (dispositivo o simulador)
Swift 6.0
Cuenta de Firebase (plan Spark gratuito suficiente)

Diagrama de Relaciones
<img width="1100" height="830" alt="5d405da8-15eb-413e-a3e1-35de002952b2" src="https://github.com/user-attachments/assets/c6c408fd-474f-4747-8aff-a433493806c9" />


🔐 Sistema de Permisos
<img width="1050" height="714" alt="85c79282-6a30-4fd9-a82f-8ab8d8b83764" src="https://github.com/user-attachments/assets/db85e4bb-3762-4763-b271-b8a38b0d3062" />


👨‍💻 Autor
Adolfo Gómez

Proyecto desarrollado como Trabajo Fin de Grado del Ciclo Superior de Desarrollo de Aplicaciones Multiplataforma (DAM), curso 2024-2025.
Hecho con ❤️ para aquellos que corren en sentido contrario al que los demas huyen
