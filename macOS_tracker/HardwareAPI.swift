import Foundation

public struct HardwareAPI {

    public enum APIError: Error, LocalizedError {
        case invalidURL
        case encodingFailed(Error)
        case network(Error)
        case badStatus(Int, Data?)
        case noData

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"

            case .encodingFailed(let error):
                return "Failed to encode request body: \(error.localizedDescription)"

            case .network(let error):
                return error.localizedDescription

            case .badStatus(let code, let data):
                if let data,
                   let body = String(data: data, encoding: .utf8) {
                    return "Server responded with status \(code): \(body)"
                }
                return "Server responded with status \(code)"

            case .noData:
                return "No data received from server."
            }
        }
    }

    public init() {}

    @discardableResult
    public func postHardware(
        snapshot: InventorySnapshot,
        to baseURL: String,
        bearerToken: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> (statusCode: Int, data: Data?) {

        guard var components = URLComponents(string: baseURL) else {
            throw APIError.invalidURL
        }

        // Append /api/hardware only if missing
        if !components.path.hasSuffix("/api/hardware") {
            if components.path.hasSuffix("/") {
                components.path += "api/hardware"
            } else {
                components.path += "/api/hardware"
            }
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"

        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try InventorySnapshot.encode(snapshot)
        } catch {
            throw APIError.encodingFailed(error)
        }

        // MARK: Request Log

        print("\n================ REQUEST ================")
        print("URL      : \(url.absoluteString)")
        print("METHOD   : \(request.httpMethod ?? "")")

        print("\nHEADERS")
        request.allHTTPHeaderFields?.forEach {
            print("\($0.key): \($0.value)")
        }

        if let body = request.httpBody {
            print("\nBODY (\(body.count) bytes)")
            print(body.prettyJSONString ?? String(data: body, encoding: .utf8) ?? "")
        }

        print("\nCURL")
        print(request.curlString)
        print("=========================================\n")

        do {

            let start = Date()

            let (data, response) = try await URLSession.shared.data(for: request)

            let elapsed = Date().timeIntervalSince(start)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            // MARK: Response Log

            print("\n================ RESPONSE ================")
            print("STATUS   : \(http.statusCode)")
            print(String(format: "TIME     : %.2f sec", elapsed))

            print("\nHEADERS")
            http.allHeaderFields.forEach {
                print("\($0.key): \($0.value)")
            }

            print("\nBODY")
            if data.isEmpty {
                print("<Empty Response>")
            } else {
                print(data.prettyJSONString ?? String(data: data, encoding: .utf8) ?? "")
            }

            print("==========================================\n")

            guard (200...299).contains(http.statusCode) else {
                throw APIError.badStatus(http.statusCode, data)
            }

            print("✅ Hardware data added successfully (status: \(http.statusCode))")

            return (
                statusCode: http.statusCode,
                data: data.isEmpty ? nil : data
            )

        } catch {

            let nsError = error as NSError

            print("\n================ ERROR ==================")
            print("ERROR       : \(error.localizedDescription)")
            print("DOMAIN      : \(nsError.domain)")
            print("CODE        : \(nsError.code)")
            print("USER INFO   : \(nsError.userInfo)")

            if let url = nsError.userInfo[NSURLErrorFailingURLErrorKey] {
                print("FAILING URL : \(url)")
            }

            print("==========================================\n")

            throw APIError.network(error)
        }
    }
}

public extension Data {

    var prettyJSONString: String? {

        guard
            let object = try? JSONSerialization.jsonObject(with: self),
            let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: .prettyPrinted
            )
        else {
            return nil
        }

        return String(data: pretty, encoding: .utf8)
    }
}

import Foundation

extension URLRequest {

    var curlString: String {

        guard let url = url else {
            return ""
        }

        var components = ["curl"]

        // Method
        if let method = httpMethod {
            components.append("-X \(method)")
        }

        // Headers
        allHTTPHeaderFields?.forEach { key, value in
            components.append("-H '\(key): \(value)'")
        }

        // Body
        if let body = httpBody,
           let bodyString = String(data: body, encoding: .utf8) {

            let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            components.append("-d '\(escaped)'")
        }

        // URL
        components.append("'\(url.absoluteString)'")

        return components.joined(separator: " \\\n\t")
    }
}
