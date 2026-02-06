import Foundation

// MARK: - Settings

/// Application settings for NylServer
public struct NylSettings: Codable, Sendable {
    /// Heartbeat interval in seconds (default: 30 minutes)
    public var heartbeatInterval: TimeInterval
    
    /// Optional fixed weather location (if nil, uses system location)
    public var weatherLocation: String?
    
    public init(
        heartbeatInterval: TimeInterval = 1800, // 30 minutes default
        weatherLocation: String? = nil
    ) {
        self.heartbeatInterval = heartbeatInterval
        self.weatherLocation = weatherLocation
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
