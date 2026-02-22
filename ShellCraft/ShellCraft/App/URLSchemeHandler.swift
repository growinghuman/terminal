import Foundation
import SwiftUI

/// Handles URL schemes for deep linking
/// Supported formats:
///   shellcraft://connect?host=example.com&port=22&user=root
///   ssh://user@host:port
///   shellcraft://snippet?id=UUID
struct URLSchemeHandler {
    @MainActor
    static func handle(url: URL, terminalViewModel: TerminalViewModel) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        switch url.scheme {
        case "shellcraft":
            await handleShellCraftURL(components: components, viewModel: terminalViewModel)
        case "ssh":
            await handleSSHURL(url: url, viewModel: terminalViewModel)
        default:
            break
        }
    }

    // MARK: - shellcraft:// scheme

    @MainActor
    private static func handleShellCraftURL(
        components: URLComponents,
        viewModel: TerminalViewModel
    ) async {
        guard let host = components.host else { return }

        switch host {
        case "connect":
            await handleConnect(params: components.queryItems ?? [], viewModel: viewModel)
        case "snippet":
            handleSnippet(params: components.queryItems ?? [], viewModel: viewModel)
        default:
            break
        }
    }

    @MainActor
    private static func handleConnect(
        params: [URLQueryItem],
        viewModel: TerminalViewModel
    ) async {
        let hostname = params.first(where: { $0.name == "host" })?.value ?? ""
        let port = Int(params.first(where: { $0.name == "port" })?.value ?? "22") ?? 22
        let username = params.first(where: { $0.name == "user" })?.value ?? "root"
        let password = params.first(where: { $0.name == "password" })?.value

        guard !hostname.isEmpty else { return }

        let host = Host(
            name: "\(username)@\(hostname)",
            hostname: hostname,
            port: port,
            username: username,
            authMethod: password != nil ? .password : .publicKey
        )

        await viewModel.openConnection(host: host, password: password)
    }

    @MainActor
    private static func handleSnippet(params: [URLQueryItem], viewModel: TerminalViewModel) {
        guard let idString = params.first(where: { $0.name == "id" })?.value else { return }
        // Snippet execution would be handled by looking up the snippet by ID
        _ = idString
    }

    // MARK: - ssh:// scheme

    @MainActor
    private static func handleSSHURL(url: URL, viewModel: TerminalViewModel) async {
        // Parse ssh://user@host:port
        let username = url.user ?? "root"
        let hostname = url.host ?? ""
        let port = url.port ?? 22

        guard !hostname.isEmpty else { return }

        let password = url.password
        let host = Host(
            name: "\(username)@\(hostname)",
            hostname: hostname,
            port: port,
            username: username,
            authMethod: password != nil ? .password : .publicKey
        )

        await viewModel.openConnection(host: host, password: password)
    }
}
