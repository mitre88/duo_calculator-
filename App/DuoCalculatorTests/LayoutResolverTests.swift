import Testing
import SwiftUI
import CalcEngine
@testable import DuoCalculator

/// Synthetic iPhone Duo poses (points @3x: outer 466×678, inner 626×890).
@MainActor
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
    /// A 500 pt window (iPad Split View, Stage Manager): function block stacked above the basic keypad.
    static let stacked = LayoutInput(size: CGSize(width: 500, height: 890),
                                     safeArea: EdgeInsets(top: 54, leading: 0, bottom: 34, trailing: 0),
                                     sizeClass: .regularRegular)

    /// Inner display, landscape, as the iOS 27.1 simulator reports it: the status bar lives in a trailing column
    /// (safe-area trailing inset + an occlusion in the top-right corner) and the fold is active.
    static let innerBookLandscape = LayoutInput(size: CGSize(width: 951, height: 669),
                                                safeArea: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
                                                sizeClass: .regularRegular,
                                                regions: [ReservedRegionInfo(kind: .division, frame: CGRect(x: 455.5, y: 0, width: 40, height: 669),
                                                                             margins: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20), isActive: true),
                                                          ReservedRegionInfo(kind: .occlusion, frame: CGRect(x: 867, y: 0, width: 84, height: 120),
                                                                             margins: EdgeInsets(), isActive: true)])
    /// Flat inner portrait with a status-bar strip reported as an occlusion over the top of the content.
    static let innerPortraitStatusBar = LayoutInput(size: CGSize(width: 626, height: 890),
                                                    safeArea: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 0),
                                                    sizeClass: .regularRegular,
                                                    regions: [ReservedRegionInfo(kind: .occlusion, frame: CGRect(x: 520, y: 0, width: 106, height: 54),
                                                                                 margins: EdgeInsets(), isActive: true)])

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
        #expect(LayoutResolver.resolve(Self.book).mode == .book)
        #expect(LayoutResolver.resolve(Self.stacked).mode == .scientificStacked)
        #expect(LayoutResolver.resolve(Self.splitHalf).mode == .basic)
        #expect(LayoutResolver.resolve(Self.splitTwoThirds).mode == .basic)
        #expect(LayoutResolver.resolve(Self.ipad).mode == .scientific)
        var accessibility = Self.innerPortrait
        accessibility.isAccessibilitySize = true
        #expect(LayoutResolver.resolve(accessibility).mode == .basic)
    }

    static var allPoses: [LayoutInput] {
        [outerPortrait, outerLandscape, innerPortrait, innerLandscape, tabletop, book, splitHalf, splitTwoThirds, ipad, stacked,
         innerBookLandscape, innerPortraitStatusBar]
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
        if let secondary = plan.secondaryKeypadFrame {
            #expect(content.insetBy(dx: -0.5, dy: -0.5).contains(secondary), "function block escapes content in \(plan.mode)")
            #expect(!secondary.intersects(plan.keypadFrame.insetBy(dx: 1, dy: 1)))
            let size = plan.secondaryKeySize ?? plan.keySize
            #expect(size.width >= KeypadMetrics.minimumKeySide - 0.5 && size.height >= KeypadMetrics.minimumKeySide - 0.5,
                    "function block keys \(size) in \(plan.mode)")
            if let spec = plan.secondaryKeypadSpec {
                let expectedWidth = size.width * CGFloat(spec.columns) + plan.keySpacing * CGFloat(spec.columns - 1)
                #expect(abs(secondary.width - expectedWidth) < 0.5, "function block frame does not match its key size in \(plan.mode)")
            }
        }
        if input.verticalDivision != nil || input.activeHorizontalDivision != nil {
            #expect(plan.keypadSpec.columns.isMultiple(of: 2), "even columns required with a fold")
        }
        for region in input.regions where region.kind == .division && region.isActive {
            if region.axis == .vertical {
                // Each half stays beside the fold and the widened channel covers the fold's expanded frame.
                let leftColumns = CGFloat(plan.keypadSpec.gutterAfterColumn ?? plan.keypadSpec.columns / 2)
                let leftBlockMaxX = plan.keypadFrame.minX + leftColumns * (plan.keySize.width + plan.keySpacing) - plan.keySpacing
                let rightBlockMinX = leftBlockMaxX + plan.keySpacing + plan.centerGutter
                #expect(leftBlockMaxX <= region.expandedFrame.minX + 0.5,
                        "left block ends at \(leftBlockMaxX), on the fold \(region.expandedFrame) in \(plan.mode)")
                #expect(rightBlockMinX >= region.expandedFrame.maxX - 0.5,
                        "right block starts at \(rightBlockMinX), on the fold \(region.expandedFrame) in \(plan.mode)")
                #expect(!plan.panelsAvailable, "panels must give way to the fold-aware keypad in \(plan.mode)")
            } else {
                #expect(!plan.keypadFrame.intersects(region.expandedFrame), "keypad under the active fold in \(plan.mode)")
                #expect(!plan.displayFrame.intersects(region.expandedFrame), "display under the active fold in \(plan.mode)")
                #expect(!plan.panelsAvailable, "panels must give way to the fold-aware keypad in \(plan.mode)")
            }
        }
        if plan.isCompactWidth { #expect(!plan.panelsAvailable) }
        checkDisplay(plan)
    }

    /// The display holds its whole stack (mode bar, expression, preview, result, pills) without touching the keypad,
    /// and its mode bar sits below every active occlusion (status bar, camera).
    func checkDisplay(_ plan: LayoutPlan) {
        let compact = plan.isCompactWidth
        if let block = plan.secondaryKeypadFrame {
            #expect(plan.displayFrame.maxY <= block.minY + 0.5, "display runs into the function block in \(plan.mode)")
        }
        if plan.mode != .basicLandscape {
            #expect(plan.displayFrame.maxY <= plan.keypadFrame.minY + 0.5, "display runs into the keypad in \(plan.mode)")
        }
        // Only a pane already squeezed to minimum-size keys may shave the result line.
        let keysAtMinimum = plan.keySize.height <= KeypadMetrics.minimumKeySide + 0.5
        #expect(plan.primaryLineHeight >= DisplayMetrics.minimumPrimaryLineHeight(compact: compact) - 0.5 || keysAtMinimum,
                "result line \(plan.primaryLineHeight) pt too short in \(plan.mode)")
        let modeBar = CGRect(x: plan.displayFrame.minX, y: plan.displayFrame.minY + plan.displayTopInset,
                             width: plan.displayFrame.width, height: DisplayMetrics.modeBarHeight(compact: compact))
        for obstacle in plan.avoidRects {
            #expect(!modeBar.intersects(obstacle), "mode bar \(modeBar) under \(obstacle) in \(plan.mode)")
        }
    }

    @Test func innerDisplayFitsTheWholeResult() {
        let plan = LayoutResolver.resolve(Self.innerBookLandscape)
        #expect(plan.mode == .book)
        // The status-bar column is outside the content, so the display and keypad stop before it.
        #expect(plan.displayFrame.maxX <= 867 + 0.5 && plan.keypadFrame.maxX <= 867 + 0.5)
        #expect(plan.displayFrame.height >= DisplayMetrics.minimumHeight(topInset: plan.displayTopInset, compact: false) - 0.5)
        #expect(DisplayMetrics.primaryFontSize(lineHeight: plan.primaryLineHeight, compact: false) >= 50)
    }

    @Test func modeBarDropsBelowAStatusBarOcclusion() {
        let plan = LayoutResolver.resolve(Self.innerPortraitStatusBar)
        #expect(plan.displayTopInset >= 54 + DisplayMetrics.obstacleClearance - 0.5)
        #expect(plan.primaryLineHeight >= DisplayMetrics.minimumPrimaryLineHeight(compact: false) - 0.5)
        // Without obstacles the inset stays minimal.
        #expect(LayoutResolver.resolve(Self.ipad).displayTopInset == DisplayMetrics.minimumTopInset)
    }

    @Test func tabletopSplitsAroundTheFold() {
        let plan = LayoutResolver.resolve(Self.tabletop)
        let fold = Self.tabletop.activeHorizontalDivision!.expandedFrame
        #expect(plan.displayFrame.maxY <= fold.minY + 0.5)
        #expect(plan.keypadFrame.minY >= fold.maxY - 0.5)
        #expect(plan.keypadSpec.name == "scientific")
    }

    @Test func bookPoseCentersTheChannelOnTheFold() {
        let plan = LayoutResolver.resolve(Self.book)
        let fold = Self.book.verticalDivision!.expandedFrame
        #expect(plan.mode == .book)
        #expect(plan.keypadSpec.name == "scientificBook" && plan.keypadSpec.gutterAfterColumn == 5)
        #expect(plan.keySpacing + plan.centerGutter >= fold.width - 0.5)
        #expect(plan.keySize.width >= 44)
        // Flat inner display with the (inactive) fold: plain scientific grid, no widened channel.
        let flat = LayoutResolver.resolve(Self.innerPortrait)
        #expect(flat.mode == .scientific && flat.centerGutter == 0 && flat.keypadSpec.gutterAfterColumn == 6)
        #expect(flat.panelsAvailable)
    }

    @Test func stackedFunctionBlockUsesItsOwnKeyWidth() {
        let plan = LayoutResolver.resolve(Self.stacked)
        let block = plan.secondaryKeySize!
        #expect(block.width < plan.keySize.width)
        #expect(block.width >= 44 && block.height >= 44)
        #expect(plan.panelsAvailable)
    }

    @Test func compactProfilesFollowWidth() {
        #expect(LayoutResolver.resolve(Self.outerPortrait).displayProfile == .compact)
        #expect(LayoutResolver.resolve(Self.innerPortrait).displayProfile == .regular)
        #expect(LayoutResolver.resolve(Self.outerPortrait).keyShape == .circle)
    }
}
