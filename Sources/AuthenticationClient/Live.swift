//
//  File.swift
//
//
//  Created by ErrorErrorError on 2/17/23.
//
//

import AuthenticationServices
import Foundation
import SwiftUI

// MARK: - AuthError

private enum AuthError: Error {
    case failedToCreateWindow
    case closedWindow
}

#if canImport(AppKit)
private typealias ViewController = NSViewController
#else
private typealias ViewController = UIViewController
#endif

// MARK: - AuthenticationClientLive

actor AuthenticationClientLive: AuthenticationClient {
    @MainActor
    func authenticate(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = Delegate()

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "anime-now"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                }
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = delegate
            session.start()
        }
    }

    @MainActor
    func logIn<O>(
        title: String,
        image: String,
        description: String,
        validate: @escaping @Sendable (AuthenticationClientModels.LoginInfo) async throws -> O
    ) async throws -> O {
        var viewController: ViewController?
        var continuation: CheckedContinuation<O, Error>?

        #if os(macOS)
        var mainViewController: ViewController?
        #endif

        func dismiss() {
            #if canImport(UIKit)
            viewController?.dismiss(animated: true)
            #else
            if let viewController {
                mainViewController?.dismiss(viewController)
            }
            #endif
        }

        let callback: (Result<AuthenticationClientModels.LoginInfo, Error>) async -> AuthenticationLoginView.Validate = { info in
            switch info {
            case let .success(info):
                do {
                    let obj = try await validate(info)
                    continuation?.resume(returning: obj)
                    dismiss()
                    return .validating
                } catch {
                    return .failed
                }
            case let .failure(error):
                continuation?.resume(throwing: error)
                dismiss()
                return .failed
            }
        }

        let view = AuthenticationLoginView(
            name: title,
            logo: image,
            description: description,
            callback: callback
        )

        #if os(iOS)
        guard let controller = UIApplication.shared.windows.first?.rootViewController else {
            throw AuthError.failedToCreateWindow
        }
        let encapsulated = UIHostingController(rootView: view)
        encapsulated.isModalInPresentation = true
        controller.present(encapsulated, animated: true)
        viewController = encapsulated
        #else
        guard let controller = NSApplication.shared.mainWindow?.contentViewController else {
            throw AuthError.failedToCreateWindow
        }
        let encapsulated = NSHostingController(rootView: view)
        controller.presentAsSheet(encapsulated)
        mainViewController = controller
        viewController = encapsulated
        #endif

        return try await withCheckedThrowingContinuation { `continue` in
            continuation = `continue`
        }
    }
}

// MARK: - AuthenticationLoginView

struct AuthenticationLoginView: View {
    enum Validate {
        case idle
        case validating
        case failed
    }

    let name: String
    let logo: String
    let description: String
    let callback: (Result<AuthenticationClientModels.LoginInfo, Error>) async -> Validate

    @State
    private var validate = Validate.idle
    @State
    private var username: String = ""
    @State
    private var password: String = ""
    @State
    private var secured = true

    var body: some View {
        content
    }

    private var valid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func buttonSubmitted() {
        guard validate != .validating else {
            return
        }
        validate = .validating
        Task.detached {
            let validate = await callback(
                .success(
                    .init(
                        username: username
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            )
            await MainActor.run {
                self.validate = validate
            }
        }
    }

    private func closeButton() {
        Task.detached {
            _ = await callback(.failure(AuthError.closedWindow))
        }
    }

    @ViewBuilder
    var credentialsError: some View {
        if validate == .failed {
            Text("Failed to authenticate with \(name). Verify your credentials are correct and try again.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    func submitButton(_ height: Double) -> some View {
        Button {
            buttonSubmitted()
        } label: {
            Group {
                if validate == .validating {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .foregroundColor(valid ? .blue : .gray.opacity(0.2))
                    .overlay(Text("Login"))
                    .font(.system(size: 13, weight: .semibold))
                }
            }
            .frame(height: height)
        }
        .buttonStyle(.plain)
        .disabled(!valid)
    }

    #if os(macOS)
    @ViewBuilder
    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(name)")
                    .font(.title.weight(.bold))

                Spacer()

                Button {
                    closeButton()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .padding(10)
                        .background(Circle().foregroundColor(.gray.opacity(0.25)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(spacing: 0) {
                let height = 42.0
                VStack(spacing: 8) {
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78)

                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding([.horizontal, .top])

                VStack(spacing: 8) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .padding(.horizontal)
                        .frame(height: height)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                    Group {
                        HStack {
                            if secured {
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                            } else {
                                TextField("Password", text: $password)
                                    .textContentType(.password)
                            }

                            Image(systemName: secured ? "eye.fill" : "eye.slash.fill")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    secured.toggle()
                                }
                        }
                    }
                    .padding(.horizontal)
                    .frame(height: height)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    credentialsError
                }
                .textFieldStyle(.plain)
                .padding()

                Divider()

                submitButton(height)
                    .padding()
            }
        }
        .frame(width: 375)
        .fixedSize()
    }
    #else
    var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("\(name)")
                    .font(.title.weight(.bold))

                Spacer()

                Button {
                    closeButton()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .padding(10)
                        .background(Circle().foregroundColor(.gray.opacity(0.25)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding()

            VStack(spacing: 0) {
                let height = 48.0
                VStack(spacing: 8) {
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96)

                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding([.horizontal, .top])

                VStack(spacing: 8) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .padding(.horizontal)
                        .frame(height: height)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)

                    Group {
                        HStack {
                            if secured {
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                            } else {
                                TextField("Password", text: $password)
                                    .textContentType(.password)
                            }

                            Image(systemName: secured ? "eye.fill" : "eye.slash.fill")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    secured.toggle()
                                }
                        }
                    }
                    .textContentType(.password)
                    .padding(.horizontal)
                    .frame(height: height)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    credentialsError
                }
                .textFieldStyle(.plain)
                .padding()

                submitButton(height)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
    #endif
}

// MARK: - Delegate

private class Delegate: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        .init()
    }
}
