[mockups_ambukit.html](https://github.com/user-attachments/files/23812059/mockups_ambukit.html)
[Uploadi<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AmbuKit - Mockups de Pantallas</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            padding: 40px 20px;
        }
        
        h1 {
            text-align: center;
            color: white;
            font-size: 32px;
            margin-bottom: 8px;
            font-weight: 700;
        }
        
        .subtitle {
            text-align: center;
            color: rgba(255,255,255,0.6);
            font-size: 16px;
            margin-bottom: 48px;
        }
        
        .phones-container {
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 40px;
            max-width: 1600px;
            margin: 0 auto;
        }
        
        .phone-wrapper {
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        
        .phone-label {
            color: white;
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .iphone {
            width: 280px;
            height: 580px;
            background: #000;
            border-radius: 44px;
            padding: 12px;
            box-shadow: 
                0 0 0 2px #333,
                0 20px 60px rgba(0,0,0,0.5),
                inset 0 0 0 2px #1a1a1a;
            position: relative;
        }
        
        .iphone::before {
            content: '';
            position: absolute;
            top: 12px;
            left: 50%;
            transform: translateX(-50%);
            width: 100px;
            height: 28px;
            background: #000;
            border-radius: 20px;
            z-index: 10;
        }
        
        .screen {
            width: 100%;
            height: 100%;
            background: #f2f2f7;
            border-radius: 34px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        
        /* iOS Status Bar */
        .status-bar {
            height: 44px;
            background: inherit;
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            padding: 0 24px 8px;
            font-size: 14px;
            font-weight: 600;
        }
        
        .status-bar-dark {
            color: white;
        }
        
        .status-bar-light {
            color: black;
        }
        
        .status-icons {
            display: flex;
            gap: 4px;
            align-items: center;
        }
        
        /* Navigation Bar */
        .nav-bar {
            padding: 8px 16px 12px;
            background: inherit;
        }
        
        .nav-bar-large {
            padding: 8px 16px 16px;
        }
        
        .nav-title {
            font-size: 28px;
            font-weight: 700;
            color: #000;
        }
        
        .nav-title-small {
            font-size: 17px;
            font-weight: 600;
            text-align: center;
        }
        
        .nav-bar-inline {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        /* Search Bar */
        .search-bar {
            margin: 0 16px 12px;
            background: rgba(142,142,147,0.12);
            border-radius: 10px;
            padding: 8px 12px;
            display: flex;
            align-items: center;
            gap: 6px;
            color: #8e8e93;
            font-size: 15px;
        }
        
        /* Content Area */
        .content {
            flex: 1;
            overflow: hidden;
        }
        
        /* List Styles */
        .list-section {
            background: white;
            margin: 0 16px 20px;
            border-radius: 12px;
            overflow: hidden;
        }
        
        .list-section-header {
            padding: 8px 16px 4px;
            font-size: 13px;
            color: #8e8e93;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            background: #f2f2f7;
        }
        
        .list-item {
            padding: 12px 16px;
            border-bottom: 0.5px solid rgba(0,0,0,0.1);
            display: flex;
            align-items: center;
            gap: 12px;
            background: white;
        }
        
        .list-item:last-child {
            border-bottom: none;
        }
        
        .list-item-icon {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
        }
        
        .list-item-content {
            flex: 1;
        }
        
        .list-item-title {
            font-size: 15px;
            font-weight: 500;
            color: #000;
        }
        
        .list-item-subtitle {
            font-size: 13px;
            color: #8e8e93;
            margin-top: 2px;
        }
        
        .list-item-badge {
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 10px;
            font-weight: 600;
        }
        
        .badge-red { background: #ffebee; color: #d32f2f; }
        .badge-green { background: #e8f5e9; color: #388e3c; }
        .badge-orange { background: #fff3e0; color: #f57c00; }
        .badge-blue { background: #e3f2fd; color: #1976d2; }
        
        .chevron {
            color: #c7c7cc;
            font-size: 14px;
        }
        
        /* Tab Bar */
        .tab-bar {
            height: 83px;
            background: rgba(249,249,249,0.94);
            backdrop-filter: blur(20px);
            border-top: 0.5px solid rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-around;
            align-items: flex-start;
            padding-top: 8px;
        }
        
        .tab-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 2px;
            font-size: 10px;
            color: #8e8e93;
        }
        
        .tab-item.active {
            color: #007aff;
        }
        
        .tab-icon {
            font-size: 22px;
        }
        
        /* Splash Screen */
        .splash-screen {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            background: linear-gradient(180deg, #f2f2f7 0%, #e5e5ea 100%);
        }
        
        .splash-icon {
            font-size: 72px;
            margin-bottom: 16px;
        }
        
        .splash-title {
            font-size: 32px;
            font-weight: 700;
            color: #000;
            margin-bottom: 24px;
        }
        
        .spinner {
            width: 24px;
            height: 24px;
            border: 3px solid #e5e5ea;
            border-top-color: #007aff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        /* Login Screen */
        .login-screen {
            display: flex;
            flex-direction: column;
            height: 100%;
            background: white;
            padding: 60px 24px 40px;
        }
        
        .login-header {
            text-align: center;
            margin-bottom: 48px;
        }
        
        .login-icon {
            font-size: 64px;
            margin-bottom: 16px;
        }
        
        .login-title {
            font-size: 28px;
            font-weight: 700;
        }
        
        .login-subtitle {
            font-size: 15px;
            color: #8e8e93;
            margin-top: 8px;
        }
        
        .input-field {
            background: #f2f2f7;
            border: none;
            border-radius: 12px;
            padding: 16px;
            font-size: 15px;
            margin-bottom: 12px;
            color: #8e8e93;
        }
        
        .login-button {
            background: #007aff;
            color: white;
            border: none;
            border-radius: 12px;
            padding: 16px;
            font-size: 17px;
            font-weight: 600;
            margin-top: 12px;
        }
        
        .forgot-password {
            text-align: center;
            color: #007aff;
            font-size: 15px;
            margin-top: 16px;
        }
        
        /* Stats Card */
        .stats-row {
            display: flex;
            gap: 12px;
            margin: 0 16px 16px;
        }
        
        .stat-card {
            flex: 1;
            background: white;
            border-radius: 12px;
            padding: 12px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 24px;
            font-weight: 700;
            color: #007aff;
        }
        
        .stat-label {
            font-size: 11px;
            color: #8e8e93;
            margin-top: 4px;
        }
        
        /* Alert Item */
        .alert-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 16px;
            background: white;
            border-bottom: 0.5px solid rgba(0,0,0,0.1);
        }
        
        .alert-icon {
            width: 36px;
            height: 36px;
            border-radius: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
        }
        
        .alert-icon-red { background: #ffebee; }
        .alert-icon-orange { background: #fff3e0; }
        .alert-icon-green { background: #e8f5e9; }
        
        /* Empty State */
        .empty-state {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 48px 24px;
            text-align: center;
        }
        
        .empty-icon {
            font-size: 48px;
            margin-bottom: 16px;
            opacity: 0.5;
        }
        
        .empty-title {
            font-size: 17px;
            font-weight: 600;
            color: #000;
            margin-bottom: 4px;
        }
        
        .empty-subtitle {
            font-size: 15px;
            color: #8e8e93;
        }
        
        /* Footer */
        .footer {
            text-align: center;
            color: rgba(255,255,255,0.4);
            font-size: 12px;
            margin-top: 48px;
        }
    </style>
</head>
<body>
    <h1>📱 AmbuKit - Capturas de Pantalla</h1>
    <p class="subtitle">Sistema de Gestión de Botiquines para Ambulancias</p>
    
    <div class="phones-container">
        
        <!-- PANTALLA 1: Splash Screen -->
        <div class="phone-wrapper">
            <div class="phone-label">Splash Screen</div>
            <div class="iphone">
                <div class="screen">
                    <div class="splash-screen">
                        <div class="splash-icon">🏥</div>
                        <div class="splash-title">AmbuKit</div>
                        <div class="spinner"></div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 2: Login -->
        <div class="phone-wrapper">
            <div class="phone-label">Login</div>
            <div class="iphone">
                <div class="screen" style="background: white;">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="login-screen">
                        <div class="login-header">
                            <div class="login-icon">🏥</div>
                            <div class="login-title">AmbuKit</div>
                            <div class="login-subtitle">Gestión de Botiquines</div>
                        </div>
                        <div class="input-field">📧 Email</div>
                        <div class="input-field">🔒 Contraseña</div>
                        <div class="login-button">Iniciar Sesión</div>
                        <div class="forgot-password">¿Olvidaste tu contraseña?</div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 3: Lista de Kits -->
        <div class="phone-wrapper">
            <div class="phone-label">Gestión de Kits</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-large nav-bar-inline">
                        <div class="nav-title">Kits</div>
                        <span style="color: #007aff; font-size: 28px;">+</span>
                    </div>
                    <div class="search-bar">
                        <span>🔍</span>
                        <span>Buscar kits...</span>
                    </div>
                    <div class="content">
                        <div class="list-section">
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #e3f2fd;">🧰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">KIT-SVA-001</div>
                                    <div class="list-item-subtitle">Kit Principal SVA • Asignado</div>
                                </div>
                                <span class="list-item-badge badge-green">✓ OK</span>
                                <span class="chevron">›</span>
                            </div>
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #fff3e0;">🧰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">AMPULARIO-2401</div>
                                    <div class="list-item-subtitle">Ampulario SVA • Asignado</div>
                                </div>
                                <span class="list-item-badge badge-orange">⚠️ Auditoría</span>
                                <span class="chevron">›</span>
                            </div>
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #ffebee;">🧰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">KIT-SVB-003</div>
                                    <div class="list-item-subtitle">Kit Básico SVB • Sin asignar</div>
                                </div>
                                <span class="list-item-badge badge-red">⚠️ Stock</span>
                                <span class="chevron">›</span>
                            </div>
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #e3f2fd;">🧰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">KIT-SVA-002</div>
                                    <div class="list-item-subtitle">Kit Trauma • Asignado</div>
                                </div>
                                <span class="list-item-badge badge-green">✓ OK</span>
                                <span class="chevron">›</span>
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item active">
                            <span class="tab-icon">🧰</span>
                            <span>Kits</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">⚠️</span>
                            <span>Alertas</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📊</span>
                            <span>Estadísticas</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 4: Detalle de Kit -->
        <div class="phone-wrapper">
            <div class="phone-label">Detalle de Kit</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-inline" style="padding-top: 0;">
                        <span style="color: #007aff; font-size: 15px;">‹ Kits</span>
                        <span class="nav-title-small">Kit Principal SVA</span>
                        <span style="color: #007aff; font-size: 15px;">Editar</span>
                    </div>
                    <div class="content" style="padding-top: 8px;">
                        <div class="list-section">
                            <div class="list-section-header">Información</div>
                            <div class="list-item">
                                <span style="color: #8e8e93; width: 100px;">Código</span>
                                <span>KIT-SVA-001</span>
                            </div>
                            <div class="list-item">
                                <span style="color: #8e8e93; width: 100px;">Tipo</span>
                                <span>SVA Avanzada</span>
                            </div>
                            <div class="list-item">
                                <span style="color: #8e8e93; width: 100px;">Estado</span>
                                <span style="color: #388e3c;">✓ OK</span>
                            </div>
                            <div class="list-item">
                                <span style="color: #8e8e93; width: 100px;">Última auditoría</span>
                                <span>15 Nov 2024</span>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-section-header">Items (5)</div>
                            <div class="list-item">
                                <span style="color: #388e3c;">●</span>
                                <div class="list-item-content">
                                    <div class="list-item-title">Adrenalina 1mg</div>
                                    <div class="list-item-subtitle">Qty: 10 • Min: 5 • Max: 15</div>
                                </div>
                            </div>
                            <div class="list-item">
                                <span style="color: #d32f2f;">●</span>
                                <div class="list-item-content">
                                    <div class="list-item-title">Midazolam 5mg</div>
                                    <div class="list-item-subtitle">Qty: 2 • Min: 5 • Max: 10</div>
                                </div>
                                <span class="list-item-badge badge-red">Bajo</span>
                            </div>
                            <div class="list-item">
                                <span style="color: #388e3c;">●</span>
                                <div class="list-item-content">
                                    <div class="list-item-title">Fentanilo 0.05mg</div>
                                    <div class="list-item-subtitle">Qty: 8 • Min: 4 • Max: 12</div>
                                </div>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-item" style="justify-content: center; color: #007aff;">
                                + Añadir Item
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item active">
                            <span class="tab-icon">🧰</span>
                            <span>Kits</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">⚠️</span>
                            <span>Alertas</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📊</span>
                            <span>Estadísticas</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 5: Vehículos -->
        <div class="phone-wrapper">
            <div class="phone-label">Gestión de Vehículos</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-large nav-bar-inline">
                        <div class="nav-title">Vehículos</div>
                        <span style="color: #007aff; font-size: 28px;">+</span>
                    </div>
                    <div class="content">
                        <div class="list-section">
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #e3f2fd;">🚑</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">SVA-2401</div>
                                    <div class="list-item-subtitle">SVA Avanzada • 1234-ABC</div>
                                    <div style="display: flex; gap: 12px; margin-top: 4px;">
                                        <span style="font-size: 11px; color: #388e3c;">📍 Con base</span>
                                        <span style="font-size: 11px; color: #8e8e93;">2 kits</span>
                                    </div>
                                </div>
                            </div>
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #e8f5e9;">🚑</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">SVB-2333</div>
                                    <div class="list-item-subtitle">SVB Básica • 5678-DEF</div>
                                    <div style="display: flex; gap: 12px; margin-top: 4px;">
                                        <span style="font-size: 11px; color: #388e3c;">📍 Con base</span>
                                        <span style="font-size: 11px; color: #8e8e93;">1 kit</span>
                                    </div>
                                </div>
                            </div>
                            <div class="list-item">
                                <div class="list-item-icon" style="background: #fff3e0;">🚑</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">AMB-RESERVA</div>
                                    <div class="list-item-subtitle">SVAe Enfermerizada</div>
                                    <div style="display: flex; gap: 12px; margin-top: 4px;">
                                        <span style="font-size: 11px; color: #f57c00;">⊘ Sin base</span>
                                        <span style="font-size: 11px; color: #8e8e93;">0 kits</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item">
                            <span class="tab-icon">🧰</span>
                            <span>Kits</span>
                        </div>
                        <div class="tab-item active">
                            <span class="tab-icon">🚑</span>
                            <span>Vehículos</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📦</span>
                            <span>Catálogo</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 6: Alertas -->
        <div class="phone-wrapper">
            <div class="phone-label">Alertas de Stock</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-large">
                        <div class="nav-title">Alertas de Stock</div>
                    </div>
                    <div class="content">
                        <div class="list-section">
                            <div class="list-section-header">Stock Bajo (3)</div>
                            <div class="alert-item">
                                <div class="alert-icon alert-icon-red">⬇️</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">Midazolam 5mg</div>
                                    <div class="list-item-subtitle">Cantidad: 2 / Min: 5</div>
                                </div>
                            </div>
                            <div class="alert-item">
                                <div class="alert-icon alert-icon-red">⬇️</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">Ketamina 50mg</div>
                                    <div class="list-item-subtitle">Cantidad: 1 / Min: 3</div>
                                </div>
                            </div>
                            <div class="alert-item">
                                <div class="alert-icon alert-icon-red">⬇️</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">Morfina 10mg</div>
                                    <div class="list-item-subtitle">Cantidad: 0 / Min: 2</div>
                                </div>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-section-header">Próximos a Caducar (2)</div>
                            <div class="alert-item">
                                <div class="alert-icon alert-icon-orange">⏰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">Adrenalina 1mg</div>
                                    <div class="list-item-subtitle">Caduca en 15 días</div>
                                </div>
                            </div>
                            <div class="alert-item">
                                <div class="alert-icon alert-icon-orange">⏰</div>
                                <div class="list-item-content">
                                    <div class="list-item-title">Fentanilo 0.05mg</div>
                                    <div class="list-item-subtitle">Caduca en 28 días</div>
                                </div>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-section-header">Caducados (0)</div>
                            <div class="empty-state" style="padding: 24px;">
                                <span style="font-size: 24px; opacity: 0.5;">✓</span>
                                <div class="list-item-subtitle">Sin items caducados</div>
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item">
                            <span class="tab-icon">🧰</span>
                            <span>Kits</span>
                        </div>
                        <div class="tab-item active">
                            <span class="tab-icon">⚠️</span>
                            <span>Alertas</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📊</span>
                            <span>Estadísticas</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 7: Catálogo -->
        <div class="phone-wrapper">
            <div class="phone-label">Catálogo</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-large nav-bar-inline">
                        <div class="nav-title">Catálogo</div>
                        <span style="color: #007aff; font-size: 28px;">+</span>
                    </div>
                    <div class="search-bar">
                        <span>🔍</span>
                        <span>Buscar...</span>
                    </div>
                    <div style="display: flex; gap: 8px; padding: 0 16px 12px;">
                        <span style="background: #007aff; color: white; padding: 6px 12px; border-radius: 16px; font-size: 13px;">Todos</span>
                        <span style="background: #e5e5ea; color: #000; padding: 6px 12px; border-radius: 16px; font-size: 13px;">⚠️ Críticos</span>
                    </div>
                    <div class="content">
                        <div class="list-section">
                            <div class="list-item">
                                <div class="list-item-content">
                                    <div style="font-size: 11px; color: #8e8e93;">CAT-001</div>
                                    <div class="list-item-title">Adrenalina 1mg</div>
                                    <div class="list-item-subtitle">Ampolla precargada para emergencias</div>
                                </div>
                                <span class="list-item-badge badge-red">⚠️ CRÍTICO</span>
                            </div>
                            <div class="list-item">
                                <div class="list-item-content">
                                    <div style="font-size: 11px; color: #8e8e93;">CAT-002</div>
                                    <div class="list-item-title">Midazolam 5mg</div>
                                    <div class="list-item-subtitle">Sedante de acción rápida</div>
                                </div>
                                <span class="list-item-badge badge-red">⚠️ CRÍTICO</span>
                            </div>
                            <div class="list-item">
                                <div class="list-item-content">
                                    <div style="font-size: 11px; color: #8e8e93;">CAT-003</div>
                                    <div class="list-item-title">Suero Fisiológico 500ml</div>
                                    <div class="list-item-subtitle">Solución salina 0.9%</div>
                                </div>
                            </div>
                            <div class="list-item">
                                <div class="list-item-content">
                                    <div style="font-size: 11px; color: #8e8e93;">CAT-004</div>
                                    <div class="list-item-title">Vendaje elástico 10cm</div>
                                    <div class="list-item-subtitle">Para inmovilización</div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item active">
                            <span class="tab-icon">📦</span>
                            <span>Items</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📁</span>
                            <span>Categorías</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📏</span>
                            <span>Unidades</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">📊</span>
                            <span>Stats</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- PANTALLA 8: Estadísticas -->
        <div class="phone-wrapper">
            <div class="phone-label">Estadísticas</div>
            <div class="iphone">
                <div class="screen">
                    <div class="status-bar status-bar-light">
                        <span>9:41</span>
                        <div class="status-icons">
                            <span>📶</span>
                            <span>🔋</span>
                        </div>
                    </div>
                    <div class="nav-bar nav-bar-large">
                        <div class="nav-title">Estadísticas</div>
                    </div>
                    <div class="content">
                        <div class="stats-row">
                            <div class="stat-card">
                                <div class="stat-value">12</div>
                                <div class="stat-label">Total Kits</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value" style="color: #388e3c;">9</div>
                                <div class="stat-label">Asignados</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-value" style="color: #f57c00;">3</div>
                                <div class="stat-label">Sin asignar</div>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-section-header">Kits</div>
                            <div class="list-item">
                                <span>Total de Kits</span>
                                <span style="font-weight: 600; margin-left: auto;">12</span>
                            </div>
                            <div class="list-item">
                                <span>Asignados</span>
                                <span style="font-weight: 600; color: #388e3c; margin-left: auto;">9</span>
                            </div>
                            <div class="list-item">
                                <span>Sin asignar</span>
                                <span style="font-weight: 600; color: #f57c00; margin-left: auto;">3</span>
                            </div>
                        </div>
                        <div class="list-section">
                            <div class="list-section-header">Items</div>
                            <div class="list-item">
                                <span>Total de Items</span>
                                <span style="font-weight: 600; margin-left: auto;">48</span>
                            </div>
                            <div class="list-item">
                                <span>Stock Bajo</span>
                                <span style="font-weight: 600; color: #d32f2f; margin-left: auto;">3</span>
                            </div>
                            <div class="list-item">
                                <span>Próximos a caducar</span>
                                <span style="font-weight: 600; color: #f57c00; margin-left: auto;">2</span>
                            </div>
                            <div class="list-item">
                                <span>Caducados</span>
                                <span style="font-weight: 600; color: #d32f2f; margin-left: auto;">0</span>
                            </div>
                        </div>
                    </div>
                    <div class="tab-bar">
                        <div class="tab-item">
                            <span class="tab-icon">🧰</span>
                            <span>Kits</span>
                        </div>
                        <div class="tab-item">
                            <span class="tab-icon">⚠️</span>
                            <span>Alertas</span>
                        </div>
                        <div class="tab-item active">
                            <span class="tab-icon">📊</span>
                            <span>Estadísticas</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
    </div>
    
    <p class="footer">AmbuKit - TFG DAM 2024-2025 | Mockups generados desde código SwiftUI</p>
</body>
</html>
ng mockups_ambukit.html…]()













