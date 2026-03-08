import Foundation

public protocol Instrumentation {
    var name: String { get }
    func install(faro: FaroInstance)
    func uninstall()
}
