import Foundation

public struct Meta: Codable {
    public var sdk: MetaSDK?
    public var app: MetaApp?
    public var user: MetaUser?
    public var session: MetaSession?
    public var page: MetaPage?
    public var browser: MetaBrowser?
    public var view: MetaView?
    public var device: MetaDevice?

    public init(
        sdk: MetaSDK? = nil,
        app: MetaApp? = nil,
        user: MetaUser? = nil,
        session: MetaSession? = nil,
        page: MetaPage? = nil,
        browser: MetaBrowser? = nil,
        view: MetaView? = nil,
        device: MetaDevice? = nil
    ) {
        self.sdk = sdk
        self.app = app
        self.user = user
        self.session = session
        self.page = page
        self.browser = browser
        self.view = view
        self.device = device
    }
}

public struct MetaSDK: Codable {
    public let name: String?
    public let version: String?
    public let integrations: [MetaSDKIntegration]?

    public init(name: String? = nil, version: String? = nil, integrations: [MetaSDKIntegration]? = nil) {
        self.name = name
        self.version = version
        self.integrations = integrations
    }
}

public struct MetaSDKIntegration: Codable {
    public let name: String?
    public let version: String?

    public init(name: String? = nil, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

public struct MetaApp: Codable {
    public let name: String?
    public let namespace: String?
    public let release: String?
    public let version: String?
    public let environment: String?
    public let bundleId: String?

    public init(
        name: String? = nil,
        namespace: String? = nil,
        release: String? = nil,
        version: String? = nil,
        environment: String? = nil,
        bundleId: String? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.release = release
        self.version = version
        self.environment = environment
        self.bundleId = bundleId
    }
}

public struct MetaUser: Codable {
    public let email: String?
    public let id: String?
    public let username: String?
    public let fullName: String?
    public let roles: String?
    public let hash: String?
    public let attributes: [String: String]?

    public init(
        email: String? = nil,
        id: String? = nil,
        username: String? = nil,
        fullName: String? = nil,
        roles: String? = nil,
        hash: String? = nil,
        attributes: [String: String]? = nil
    ) {
        self.email = email
        self.id = id
        self.username = username
        self.fullName = fullName
        self.roles = roles
        self.hash = hash
        self.attributes = attributes
    }
}

public struct MetaSession: Codable {
    public let id: String?
    public let attributes: [String: String]?

    public init(id: String? = nil, attributes: [String: String]? = nil) {
        self.id = id
        self.attributes = attributes
    }
}

public struct MetaPage: Codable {
    public let id: String?
    public let url: String?
    public let attributes: [String: String]?

    public init(id: String? = nil, url: String? = nil, attributes: [String: String]? = nil) {
        self.id = id
        self.url = url
        self.attributes = attributes
    }
}

public struct MetaBrowser: Codable {
    public let name: String?
    public let version: String?
    public let os: String?
    public let mobile: Bool?
    public let userAgent: String?
    public let language: String?
    public let viewportWidth: String?
    public let viewportHeight: String?

    public init(
        name: String? = nil, version: String? = nil, os: String? = nil,
        mobile: Bool? = nil, userAgent: String? = nil, language: String? = nil,
        viewportWidth: String? = nil, viewportHeight: String? = nil
    ) {
        self.name = name; self.version = version; self.os = os
        self.mobile = mobile; self.userAgent = userAgent; self.language = language
        self.viewportWidth = viewportWidth; self.viewportHeight = viewportHeight
    }
}

public struct MetaView: Codable {
    public let name: String?

    public init(name: String? = nil) {
        self.name = name
    }
}

public struct MetaDevice: Codable {
    public let platform: String?
    public let osName: String?
    public let osVersion: String?
    public let deviceModel: String?
    public let deviceManufacturer: String?
    public let screenWidth: Int?
    public let screenHeight: Int?
    public let screenDensity: Float?
    public let isEmulator: Bool?
    public let appVersion: String?
    public let appBuildNumber: String?

    public init(
        platform: String? = nil, osName: String? = nil, osVersion: String? = nil,
        deviceModel: String? = nil, deviceManufacturer: String? = nil,
        screenWidth: Int? = nil, screenHeight: Int? = nil, screenDensity: Float? = nil,
        isEmulator: Bool? = nil, appVersion: String? = nil, appBuildNumber: String? = nil
    ) {
        self.platform = platform; self.osName = osName; self.osVersion = osVersion
        self.deviceModel = deviceModel; self.deviceManufacturer = deviceManufacturer
        self.screenWidth = screenWidth; self.screenHeight = screenHeight
        self.screenDensity = screenDensity; self.isEmulator = isEmulator
        self.appVersion = appVersion; self.appBuildNumber = appBuildNumber
    }
}
