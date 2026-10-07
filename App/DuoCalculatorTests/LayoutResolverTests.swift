import Testing
import SwiftUI
@testable import DuoCalculator

/// Synthetic iPhone Duo poses (points @3x: outer 466×678, inner 626×890).
struct LayoutResolverTests {
    static let outerPortrait = LayoutInput(size: CGSize(width: 466, height: 678),
                                           safeArea: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
                                           sizeClass: .compactRegular)
    static let outerLandscape = LayoutInput(size: CGSize(width: 678, height: 466),
                                            safeArea: EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 84),
                                            sizeClass: .compactCompact)
    static let innerPortrait = LayoutInput(size: CGSize(width: 626, height: 890),
                                           safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                           sizeClass: .regularRegular,
                                           regions: [camera(CGRect(x: 283, y: 12, width: 60, height: 36)),
                                                     fold(CGRect(x: 293, y: 0, width: 40, height: 890), active: false)])
    static let innerLandscape = LayoutInput(size: CGSize(width: 890, height: 626),
                                            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 0),
                                            sizeClass: .regularRegular,
                                            regions: [fold(CGRect(x: 0, y: 293, width: 890, height: 40), active: false)])
    static let tabletop = LayoutInput(size: CGSize(width: 626, height: 890),
                                      safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                      sizeClass: .regularRegular,
                                      regions: [fold(CGRect(x: 0, y: 425, width: 626, height: 40), active: true)])
    static let book = LayoutInput(size: CGSize(width: 626, height: 890),
                                  safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                  sizeClass: .regularRegular,
                                  regions: [fold(CGRect(x: 293, y: 0, width: 40, height: 890), active: true)])
    static let splitHalf = LayoutInput(size: CGSize(width: 303, height: 890),
                                       safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                       sizeClass: .compactRegular)
    static let splitTwoThirds = LayoutInput(size: CGSize(width: 410, height: 890),
                                            safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                            sizeClass: .compactRegular)
    static let ipad = LayoutInput(size: CGSize(width: 1024, height: 1366), sizeClass: .regularRegular)

    static func fold(_ frame: CGRect, active: Bool) -> ReservedRegionInfo {
        ReservedRegionInfo(kind: .division, frame: frame, margins: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20), isActive: active)
    }

    static func camera(_ frame: CGRect) -> ReservedRegionInfo {
        ReservedRegionInfo(kind: .occlusion, frame: frame, margins: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8), isActive: true)
    }

    @Test func modes() {
        #expect(LayoutResolver.resolve(Self.outerPortrait).mode == .basic)
        #expect(LayoutResolver.resolve(Self.outerLandscape).mode == .scientificCompact)
        var landscapeBasic = Self.outerLandscape
        landscapeBasic.prefersScientificInCompactLandscape = false
        #expect(LayoutResolver.resolve(landscapeBasic).mode == .basicLandscape)
        #expect(LayoutResolver.resolve(Self.innerPortrait).mode == .scientific)
        #expect(LayoutResolver.resolve(Self.innerLandscape).mode == .scientific)
        #expect(LayoutResolver.resolve(Self.tabletop).mode == .tabletop)
        #expect(LayoutResolver.resolve(Self.book).mode == .scientific)
        #expect(LayoutResolver.resolve(Self.splitHalf).mode == .basic)
        #expect(LayoutResolver.resolve(Self.splitTwoThirds).mode == .basic)
        #expect(LayoutResolver.resolve(Self.ipad).mode == .scientific)
        var accessibility = Self.innerPortrait
        accessibility.isAccessibilitySize = true
        #expect(LayoutResolver.resolve(accessibility).mode == .basic)
    }

    static var allPoses: [LayoutInput] {
        [outerPortrait, outerLandscape, innerPortrait, innerLandscape, tabletop, book, splitHalf, splitTwoThirds, ipad]
    }

    @Test func invariants() {
        for input in Self.allPoses { check(input) }
    }

    func check(_ input: LayoutInput) {
        let plan = LayoutResolver.resolve(input)
        let content = input.contentRect
        #expect(plan.keySize.width >= KeypadMetrics.minimumKeySide - 0.5, "key width \(plan.keySize.width) in \(plan.mode)")
        #expect(plan.keySize.height >= KeypadMetrics.minimumKeySide - 0.5, "key height \(plan.keySize.height) in \(plan.mode)")
        #expect(content.insetBy(dx: -0.5, dy: -0.5).contains(plan.keypadFrame), "keypad \(plan.keypadFrame) escapes \(content) in \(plan.mode)")
        #expect(content.insetBy(dx: -0.5, dy: -0.5).contains(plan.displayFrame), "display escapes content in \(plan.mode)")
        #expect(plan.displayFrame.height >= LayoutResolver.minimumDisplayHeight - 0.5 || plan.mode == .basicLandscape)
        #expect(!plan.displayFrame.intersects(plan.keypadFrame.insetBy(dx: 1, dy: 1)))
        if input.verticalDivision != nil || input.activeHorizontalDivision != nil {
            #expect(plan.keypadSpec.columns.isMultiple(of: 2), "even columns required with a fold")
        }
        for region in input.regions where region.kind == .division && region.isActive {
            #expect(!plan.keypadFrame.intersects(region.expandedFrame), "keypad under the active fold in \(plan.mode)")
            if region.axis == .vertical {
                // the widened channel keeps keys off the fold
                let channelStart = plan.keypadFrame.minX + CGFloat(plan.keypadSpec.gutterAfterColumn ?? 0) * (plan.keySize.width + plan.keySpacing) - plan.keySpacing
                let channelEnd = channelStart + plan.keySpacing + plan.centerGutter
                #expect(channelStart <= region.expandedFrame.minX + 0.5 && channelEnd >= region.expandedFrame.maxX - 0.5,
                        "fold \(region.expandedFrame) not inside channel \(channelStart)…\(channelEnd)")
            }
        }
    }

    @Test func tabletopSplitsAroundTheFold() {
        let plan = LayoutResolver.resolve(Self.tabletop)
        let fold = Self.tabletop.activeHorizontalDivision!.expandedFrame
        #expect(plan.displayFrame.maxY <= fold.minY + 0.5)
        #expect(plan.keypadFrame.minY >= fold.maxY - 0.5)
        #expect(plan.keypadSpec.name == "scientific")
    }

    @Test func bookPoseWidensTheChannel() {
        let plan = LayoutResolver.resolve(Self.book)
        #expect(plan.centerGutter > 0)
        #expect(plan.keypadSpec.gutterAfterColumn == 6)
        #expect(plan.keySize.width >= 44)
    }

    @Test func compactProfilesFollowWidth() {
        #expect(LayoutResolver.resolve(Self.outerPortrait).displayProfile == .compact)
        #expect(LayoutResolver.resolve(Self.innerPortrait).displayProfile == .regular)
        #expect(LayoutResolver.resolve(Self.outerPortrait).keyShape == .circle)
    }
}
