import Foundation

// MARK: - Settings

/// Type of AI provider
public enum AIProviderType: String, Codable, Sendable {
    case ollama
    case claude
    case disabled
}

/// Application settings for NylServer
public struct NylSettings: Codable, Sendable {
    // MARK: - General Settings
    
    /// Heartbeat interval in seconds (default: 30 minutes)
    public var heartbeatInterval: TimeInterval
    
    /// Optional fixed weather location (if nil, uses system location)
    public var weatherLocation: String?
    
    // MARK: - AI Configuration
    
    /// Currently selected AI provider
    public var aiProvider: AIProviderType
    
    /// Whether AI features are enabled
    public var aiEnabled: Bool
    
    /// Base URL for Ollama instance
    public var ollamaBaseURL: String
    
    /// Selected Ollama model name
    public var ollamaModel: String?
    
    /// Selected Claude model ID
    public var claudeModel: String
    
    /// System prompt for AI assistant
    public var systemPrompt: String
    
    public init(
        heartbeatInterval: TimeInterval = 1800, // 30 minutes default
        weatherLocation: String? = nil,
        aiProvider: AIProviderType = .disabled,
        aiEnabled: Bool = false,
        ollamaBaseURL: String = "http://ollama.local",
        ollamaModel: String? = nil,
        claudeModel: String = "claude-3-5-sonnet-20241022",
        systemPrompt: String = "You are Nyl, a helpful assistant with access to weather and system status."
    ) {
        self.heartbeatInterval = heartbeatInterval
        self.weatherLocation = weatherLocation
        self.aiProvider = aiProvider
        self.aiEnabled = aiEnabled
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
        self.claudeModel = claudeModel
        self.systemPrompt = systemPrompt
    }
}

// MARK: - Weather

/// Snapshot of weather data at a point in time
public struct WeatherSnapshot: Codable, Sendable {
    /// Temperature in Celsius
    public let temperature: Double
    
    /// Weather condition description (e.g., "Partly Cloudy")
    public let condition: String
    
    /// Location name
    public let location: String
    
    /// When this snapshot was taken
    public let timestamp: Date
    
    public init(
        temperature: Double,
        condition: String,
        location: String,
        timestamp: Date = Date()
    ) {
        self.temperature = temperature
        self.condition = condition
        self.location = location
        self.timestamp = timestamp
    }
}

// MARK: - Heartbeat

/// Current status of the heartbeat service
public struct HeartbeatStatus: Sendable {
    /// When the heartbeat last ran
    public var lastRun: Date?
    
    /// When the heartbeat will run next
    public var nextRun: Date?
    
    /// Whether the heartbeat service is currently running
    public var isRunning: Bool
    
    public init(
        lastRun: Date? = nil,
        nextRun: Date? = nil,
        isRunning: Bool = false
    ) {
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.isRunning = isRunning
    }
}

// MARK: - API Response Models

/// Response for GET /v1/status endpoint
public struct StatusResponse: Codable, Sendable {
    /// Server information
    public let server: ServerInfo
    
    /// Current heartbeat status
    public let heartbeat: HeartbeatInfo
    
    /// Current weather data
    public let weather: WeatherInfo?
    
    public init(server: ServerInfo, heartbeat: HeartbeatInfo, weather: WeatherInfo?) {
        self.server = server
        self.heartbeat = heartbeat
        self.weather = weather
    }
}

/// Server information
public struct ServerInfo: Codable, Sendable {
    /// Server version
    public let version: String
    
    /// Server uptime in seconds
    public let uptime: TimeInterval
    
    /// Port the server is running on
    public let port: Int
    
    public init(version: String, uptime: TimeInterval, port: Int) {
        self.version = version
        self.uptime = uptime
        self.port = port
    }
}

/// Heartbeat information for API responses
public struct HeartbeatInfo: Codable, Sendable {
    /// Heartbeat interval in seconds
    public let interval: TimeInterval
    
    /// Last run timestamp
    public let lastRun: Date?
    
    /// Next run timestamp
    public let nextRun: Date?
    
    /// Whether heartbeat is running
    public let isRunning: Bool
    
    public init(interval: TimeInterval, lastRun: Date?, nextRun: Date?, isRunning: Bool) {
        self.interval = interval
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.isRunning = isRunning
    }
}

/// Weather information for API responses
public struct WeatherInfo: Codable, Sendable {
    /// Temperature in Fahrenheit
    public let temperature: Double
    
    /// Weather condition description
    public let condition: String
    
    /// Location name
    public let location: String
    
    /// Last update timestamp
    public let lastUpdated: Date
    
    public init(temperature: Double, condition: String, location: String, lastUpdated: Date) {
        self.temperature = temperature
        self.condition = condition
        self.location = location
        self.lastUpdated = lastUpdated
    }
}

// MARK: - WebSocket

/// Type of WebSocket event (server → client)
public enum WebSocketEventType: String, Codable, Sendable {
    case statusUpdate    // Full status snapshot
    case heartbeatFired  // Heartbeat completed
    case weatherUpdated  // Weather data changed
    case connected       // Initial connection confirmation
}

/// WebSocket event message
public struct WebSocketEvent: Codable, Sendable {
    /// Type of event
    public let type: WebSocketEventType

    /// When the event occurred
    public let timestamp: Date

    /// Optional status payload
    public let payload: StatusResponse?

    public init(type: WebSocketEventType, timestamp: Date, payload: StatusResponse?) {
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }
}

// MARK: - Chat

public enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct ChatMessage: Codable, Sendable {
    public let role: ChatRole
    public let content: String

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatRequest: Codable, Sendable {
    public let messages: [ChatMessage]
    public let model: String?
    public let temperature: Double?

    public init(messages: [ChatMessage], model: String? = nil, temperature: Double? = nil) {
        self.messages = messages
        self.model = model
        self.temperature = temperature
    }
}

public struct ChatResponse: Codable, Sendable {
    public let id: String
    public let message: ChatMessage
    public let model: String
    public let createdAt: Date

    public init(id: String, message: ChatMessage, model: String, createdAt: Date) {
        self.id = id
        self.message = message
        self.model = model
        self.createdAt = createdAt
    }
}

public enum ChatStreamEventType: String, Codable, Sendable {
    case delta
    case done
    case error
}

public struct ChatStreamEvent: Codable, Sendable {
    public let type: ChatStreamEventType
    public let delta: String?
    public let message: ChatMessage?
    public let error: String?

    public init(type: ChatStreamEventType, delta: String? = nil, message: ChatMessage? = nil, error: String? = nil) {
        self.type = type
        self.delta = delta
        self.message = message
        self.error = error
    }
}

// MARK: - Models

public struct ModelInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let provider: AIProviderType
    public let sizeBytes: Int64?
    public let modifiedAt: Date?

    public init(id: String, name: String, provider: AIProviderType, sizeBytes: Int64? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.provider = provider
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
    }
}

public struct ModelsResponse: Codable, Sendable {
    public let provider: AIProviderType
    public let selectedModel: String?
    public let models: [ModelInfo]

    public init(provider: AIProviderType, selectedModel: String?, models: [ModelInfo]) {
        self.provider = provider
        self.selectedModel = selectedModel
        self.models = models
    }
}

public struct SelectModelRequest: Codable, Sendable {
    public let model: String

    public init(model: String) {
        self.model = model
    }
}
