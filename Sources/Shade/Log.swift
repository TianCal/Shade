import os

/// View with: log stream --predicate 'subsystem == "com.github.tiancal.shade"' --level debug
enum Log {
    static let overlay = Logger(subsystem: "com.github.tiancal.shade", category: "overlay")
}
