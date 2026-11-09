import AppKit

let arguments = CommandLine.arguments

func value(after flag: String) -> String? {
    guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
    return arguments[i + 1]
}

if let path = value(after: "--render-icon") {
    exit(MainActor.assumeIsolated { IconRenderer.run(to: path) })
} else if let path = value(after: "--screenshot") {
    MainActor.assumeIsolated { Harness.runScreenshot(to: path) }
} else if let path = value(after: "--self-test") {
    MainActor.assumeIsolated { Harness.runSelfTest(to: path) }
} else {
    if let path = value(after: "--inspect-popover") {
        MainActor.assumeIsolated { PopoverInspector.outputPath = path }
    }
    GlossApp.main()
}
