//
//  LoginView.swift
//  AmbuKit
//
//  Created by Adolfo on 12/11/25.
//

import SwiftUI

struct LoginView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    @State private var email = ""
    @State private var password = ""
    @State private var showingForgotPassword = false
    @State private var showingError = false
    @State private var isPasswordVisible = false
    
    // MARK: - Focus
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case email, password
    }
    
    // MARK: - Computed
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private var isLoading: Bool {
        appState.isLoadingUser
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // MARK: Logo & Title
                    logoSection
                    
                    // MARK: Form
                    formSection
                    
                    // MARK: Login Button
                    loginButton
                    
                    // MARK: Forgot Password
                    forgotPasswordButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingError, presenting: appState.currentError) { _ in
                Button("Aceptar", role: .cancel) { appState.currentError = nil }
            } message: { error in
                Text(error.errorDescription ?? "Error desconocido")
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
            .onChange(of: appState.currentError) { _, newValue in
                showingError = newValue != nil
            }
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo placeholder - reemplaza con tu logo real
            Image(systemName: "cross.case.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
            
            Text("AmbuKit")
                .font(.largeTitle.bold())
            
            Text("Sistema de Gestión de Botiquines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AmbuKit, Sistema de Gestión de Botiquines")
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 16) {
            
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                TextField("ejemplo@ambukit.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .accessibilityLabel("Email")
                    .accessibilityHint("Ingresa tu dirección de correo electrónico")
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Contraseña")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("", text: $password)
                        } else {
                            SecureField("", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if isFormValid { Task { await handleLogin() } } }
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(isPasswordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Contraseña")
                .accessibilityHint("Ingresa tu contraseña")
            }
        }
    }
    
    // MARK: - Login Button
    
    private var loginButton: some View {
        Button {
            Task { await handleLogin() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Iniciar Sesión")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || isLoading)
        .accessibilityLabel("Iniciar Sesión")
        .accessibilityHint(isFormValid ? "Toca para iniciar sesión" : "Completa el formulario para continuar")
    }
    
    // MARK: - Forgot Password Button
    
    private var forgotPasswordButton: some View {
        Button {
            showingForgotPassword = true
        } label: {
            Text("¿Olvidaste tu contraseña?")
                .font(.subheadline)
                .foregroundStyle(.blue)
        }
        .disabled(isLoading)
        .accessibilityLabel("¿Olvidaste tu contraseña?")
        .accessibilityHint("Toca para recuperar tu contraseña")
    }
    
    // MARK: - Actions
    
    private func handleLogin() async {
        // Ocultar teclado
        focusedField = nil
        
        // Limpiar espacios en blanco
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Intentar login
        await appState.signIn(email: cleanEmail, password: password)
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Recuperar contraseña")
                } footer: {
                    Text("Recibirás un email con instrucciones para restablecer tu contraseña")
                }
                
                Section {
                    Button {
                        Task { await handleReset() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Enviar email")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isEmailValid || isLoading)
                }
            }
            .navigationTitle("Recuperar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("Email enviado", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Revisa tu bandeja de entrada para restablecer tu contraseña")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleReset() async {
        isLoading = true
        
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            try await FirebaseAuthService.shared.resetPassword(email: cleanEmail)
            showingSuccess = true
        } catch let error as AuthError {
            errorMessage = error.errorDescription ?? "Error desconocido"
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Login") {
    LoginView()
        .environmentObject(AppState.shared)
}

#Preview("Forgot Password") {
    ForgotPasswordView()
}
