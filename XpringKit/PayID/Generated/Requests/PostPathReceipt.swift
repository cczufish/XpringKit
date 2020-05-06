//
// Generated by SwagGen
// https://github.com/yonaskolb/SwagGen
//

import Foundation

extension API {

    public enum PostPathReceipt {

        public static let service = APIService<Response>(id: "post-path-receipt", tag: "", method: "POST", path: "/receipt", hasBody: true)

        public final class Request: APIRequest<Response> {

            public var body: Receipt?

            public init(body: Receipt?, encoder: RequestEncoder? = nil) {
                self.body = body
                super.init(service: PostPathReceipt.service) { defaultEncoder in
                    return try (encoder ?? defaultEncoder).encode(body)
                }
            }
        }

        public enum Response: APIResponseValue, CustomStringConvertible, CustomDebugStringConvertible {
            public typealias SuccessType = Void

            /** OK */
            case status200

            /** Bad Request */
            case status400

            /** Not Found */
            case status404

            /** Unprocessable Entity (WebDAV) */
            case status422

            /** Service Unavailable */
            case status503

            public var success: Void? {
                switch self {
                case .status200: return ()
                default: return nil
                }
            }

            public var response: Any {
                switch self {
                default: return ()
                }
            }

            public var statusCode: Int {
                switch self {
                case .status200: return 200
                case .status400: return 400
                case .status404: return 404
                case .status422: return 422
                case .status503: return 503
                }
            }

            public var successful: Bool {
                switch self {
                case .status200: return true
                case .status400: return false
                case .status404: return false
                case .status422: return false
                case .status503: return false
                }
            }

            public init(statusCode: Int, data: Data, decoder: ResponseDecoder) throws {
                switch statusCode {
                case 200: self = .status200
                case 400: self = .status400
                case 404: self = .status404
                case 422: self = .status422
                case 503: self = .status503
                default: throw APIClientError.unexpectedStatusCode(statusCode: statusCode, data: data)
                }
            }

            public var description: String {
                return "\(statusCode) \(successful ? "success" : "failure")"
            }

            public var debugDescription: String {
                var string = description
                let responseString = "\(response)"
                if responseString != "()" {
                    string += "\n\(responseString)"
                }
                return string
            }
        }
    }
}
