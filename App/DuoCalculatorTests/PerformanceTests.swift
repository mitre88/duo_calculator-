import XCTest
import CalcEngine
@testable import DuoCalculator

/// Metrics-based performance tests for the app layer (run in Xcode with ⌘U or `xcodebuild test`).
/// XCTest records a baseline per device the first time; afterwards a regression above the tolerance
/// fails the test. The engine's own latency / memory suite lives in the CalcEngine package.
@MainActor
final class AppPerformanceTests: XCTestCase {
    private var poses: [LayoutInput] {
        [LayoutResolverTests.outerPortrait, LayoutResolverTests.outerLandscape,
         LayoutResolverTests.innerPortrait, LayoutResolverTests.innerLandscape,
         LayoutResolverTests.tabletop, LayoutResolverTests.book,
         LayoutResolverTests.splitHalf, LayoutResolverTests.splitTwoThirds, LayoutResolverTests.ipad,
         LayoutResolverTests.stacked]
    }

    /// The resolver runs on every size change while the device folds; 9 poses × 100 must stay far below a frame.
    func testLayoutResolverAcrossAllPoses() {
        let poses = poses
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            for _ in 0..<100 {
                for pose in poses { _ = LayoutResolver.resolve(pose) }
            }
        }
    }

    /// Resolving the same input twice yields an equal plan, so SwiftUI does not re-layout on no-op frames.
    func testLayoutPlanIsStableAcrossRepeatedResolution() {
        for pose in poses {
            XCTAssertEqual(LayoutResolver.resolve(pose), LayoutResolver.resolve(pose))
        }
    }

    func testKeyGridPlacementMath() {
        let specs = [KeyGridSpec.basic, KeyGridSpec.functionBlock, KeyGridSpec.scientific]
        measure {
            var checksum = 0
            for _ in 0..<2_000 {
                for spec in specs {
                    for placement in spec.placements { checksum &+= placement.row * spec.columns + placement.column }
                }
            }
            XCTAssertGreaterThan(checksum, 0)
        }
    }

    func testDisplayFormatterThroughput() throws {
        let formatter = DisplayFormatter(profile: .regular, separators: LocaleSeparators(locale: Locale(identifier: "es_MX")), usesGrouping: true)
        var values: [CalcValue] = []
        for i in 1...300 {
            values.append(try XCTUnwrap(CalcValue(literal: "1234567.8901234\(i)")))
            values.append(try MathKernel.divide(CalcValue(i), CalcValue(7)))
        }
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for value in values { _ = formatter.format(value) }
        }
    }
}
