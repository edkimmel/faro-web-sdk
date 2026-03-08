import Foundation

public protocol Transport {
    var name: String { get }
    func send(body: TransportBody) throws
    func shutdown()
}
