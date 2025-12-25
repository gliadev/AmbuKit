//
//  FirebaseTestHelper.swift
//  AmbuKitTests
//
//  Created by Adolfo on 22/12/25.
//


import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Helper para configurar Firebase en tests
/// Garantiza que Firebase se configure UNA SOLA VEZ para todos los tests
enum FirebaseTestHelper {
    
    // MARK: - State
    
    /// Flag thread-safe para Swift 6
    /// Usamos nonisolated(unsafe) porque los tests se ejecutan secuencialmente
    /// y todos están en @MainActor
    nonisolated(unsafe) private static var isConfigured = false
    
    // MARK: - Configuration
    
    /// Configura Firebase para tests usando el emulador
    /// Es seguro llamar múltiples veces - solo configura la primera vez
    @MainActor
    static func configureIfNeeded() {
        guard !isConfigured else { return }
        
        // Configurar Firebase si no está ya configurado
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Configurar Firestore para usar emulador
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        
        // Configurar Auth para usar emulador
        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        
        isConfigured = true
        
        print("🧪 Firebase configurado para tests (emulador)")
    }
    
    // MARK: - Cleanup
    
    /// Limpia la colección de audit_logs para tests limpios
    static func cleanAuditLogs() async {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("audit_logs").getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.delete()
            }
            
            print("🧹 Audit logs limpiados: \(snapshot.documents.count) documentos")
        } catch {
            print("⚠️ Error limpiando audit logs: \(error)")
        }
    }
    
    /// Limpia una colección específica
    static func cleanCollection(_ name: String) async {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection(name).getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.delete()
            }
        } catch {
            print("⚠️ Error limpiando \(name): \(error)")
        }
    }
}

