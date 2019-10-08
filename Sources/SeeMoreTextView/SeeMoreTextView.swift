//
//  SeeMoreTextView.swift
//  SeeMoreTextView
//
//  Created by Serge Bouts on 05/24/19.
//  Copyright © Serge Bouts 2019
//  MIT license, see LICENSE file for details
//

#if os(iOS)
import UIKit
public typealias TextView = UITextView
public typealias Color = UIColor
public typealias Font = UIFont
#elseif os(macOS)
import AppKit
public typealias TextView = NSTextView
public typealias Color = NSColor
public typealias Font = NSFont
#endif

open class SeeMoreTextView: TextView {
    // MARK: - Constants

    #if os(iOS)
    static let defaultFont = UIFont(name: "Helvetica", size: 12)!
    #elseif os(macOS)
    static let defaultFont = NSFontManager.shared.font(withFamily: "Helvetica",
                                                       traits: [],
                                                       weight: 5,
                                                       size: 12)!
    #endif

    static let bufferLen = 1024

    // MARK: - State

    var txtStorage: NSTextStorage {
        #if os(iOS)
        return textStorage
        #elseif os(macOS)
        return textStorage!
        #endif
    }

    var txtContainer: NSTextContainer {
        #if os(iOS)
        return textContainer
        #elseif os(macOS)
        return textContainer!
        #endif
    }

    var lytManager: NSLayoutManager {
        #if os(iOS)
        return layoutManager
        #elseif os(macOS)
        return layoutManager!
        #endif
    }

    lazy var ellipsisString: NSMutableAttributedString = {
        #if os(iOS)
        let ellipsisFont = Font(descriptor: SeeMoreTextView.defaultFont.fontDescriptor.withSymbolicTraits([.traitBold])!, size: 0)
        #elseif os(macOS)
        let ellipsisFont = NSFontManager.shared.font(
            withFamily: "Helvetica",
            traits: [],
            weight: 5,
            size: 10)!
        #endif

        return NSMutableAttributedString(
            string: "…  ",
            attributes: [.font: ellipsisFont])
    }()

    /// See More label's text.
    public var seeMoreString: NSMutableAttributedString = {
        #if os(iOS)
        let seeMoreFont = Font(descriptor: SeeMoreTextView.defaultFont.fontDescriptor.withSymbolicTraits([.traitBold])!, size: 0)
        #elseif os(macOS)
        let seeMoreFont = NSFontManager.shared.font(
            withFamily: "Helvetica",
            traits: [],
            weight: 5,
            size: 10)!
        #endif

        return NSMutableAttributedString(
            string: "See More",
            attributes: [.font: seeMoreFont])
    }()

    #if os(macOS)
    var seeMoreTextHighlighted: Bool = false {
        didSet {
            updateSeeMoreTextHighlighting()
        }
    }
    #endif

    var isExpanded: Bool = false

    var seeMoreLocation: Int?
    var ellipsisRect: CGRect?
    var seeMoreLabelRect: CGRect?

    /// Text view's height in the current state.
    public var height: CGFloat = 0

    /// See More label's text as attributed string.
    open var contents: NSAttributedString {
        get { txtStorage }
        set {
            txtStorage.setAttributedString(newValue)
            relayout()
        }
    }

    /// Lines to display in collapsed state.
    open var collapsedLineCount: Int = 1 {
        didSet {
            relayout()
        }
    }

    /// Custom handler of text view's height change event.
    public var onHeightChange: ((SeeMoreTextView) -> Void)?

    // MARK: - Initialization

    #if os(iOS)
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    #elseif os(macOS)
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override public init(frame frameRect: CGRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setup()
    }
    #endif

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        lytManager.delegate = self
        lytManager.allowsNonContiguousLayout = true

        txtContainer.maximumNumberOfLines = 0
        txtContainer.lineBreakMode = .byClipping
        txtContainer.lineFragmentPadding = 5

        txtContainer.widthTracksTextView = true

        #if os(iOS)
        contentMode = .redraw

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapRecognized(_:)))
        tapRecognizer.delegate = self
        addGestureRecognizer(tapRecognizer)
        #endif

        backgroundColor = .clear
    }

    // MARK: - Life Cycle

    #if os(iOS)
    open override var bounds: CGRect {
        didSet {
            guard oldValue.size != bounds.size else { return; }
            relayout()
        }
    }
    #elseif os(macOS)
    open override func setFrameSize(_ newSize: CGSize) {
        let changed = bounds.size != newSize

        super.setFrameSize(newSize)

        if changed {
            relayout()
        }
    }
    #endif

    open override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        if let seeMoreLabelRect = self.seeMoreLabelRect {
            ellipsisString.draw(at: ellipsisRect!.origin)
            seeMoreString.draw(at: seeMoreLabelRect.origin)
        }
    }

    open override var intrinsicContentSize: CGSize {
        return CGSize(width: bounds.width, height: height)
    }

    // MARK: - Mouse handling

    #if os(iOS)
    @objc func tapRecognized(_ recognizer: UIGestureRecognizer) {
        if !isExpanded, let seeMoreLabelRect = seeMoreLabelRect {
            let point = recognizer.location(in: self)
            if seeMoreLabelRect.contains(point) {
                isExpanded = true
                relayout()
                return
            }
        }
    }
    #elseif os(macOS)
    open override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        handleMouse(with: event)
    }

    open override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        handleMouse(with: event)
    }

    open override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        handleMouse(with: event)
    }

    func handleMouse(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let seeMoreLabelRect = seeMoreLabelRect {
            if NSPointInRect(point, seeMoreLabelRect) {
                seeMoreTextHighlighted = true
                setNeedsDisplay(bounds)
            } else {
                seeMoreTextHighlighted = false
                setNeedsDisplay(bounds)
            }
        }
    }

    open override func mouseDown(with event: NSEvent) {
        if !isExpanded, let seeMoreLabelRect = seeMoreLabelRect {
            let point = convert(event.locationInWindow, from: nil)
            if NSPointInRect(point, seeMoreLabelRect) {
                isExpanded = true
                relayout()
                return
            }
        }
        super.mouseDown(with: event)
    }
    #endif
}

#if os(iOS)
extension SeeMoreTextView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
#endif

// MARK: - NSLayoutManagerDelegate
extension SeeMoreTextView: NSLayoutManagerDelegate {
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: Font,
        forGlyphRange glyphRange: NSRange) -> Int
    {
        let firstCharIndex = charIndexes[0]
        let lastCharIndex = charIndexes[glyphRange.length - 1]
        let charactersRange = NSRange(location: firstCharIndex, length: lastCharIndex - firstCharIndex + 1)

        guard let seeMoreLocation = self.seeMoreLocation else { return 0 }

        guard NSLocationInRange(seeMoreLocation, charactersRange) else { return 0 }

        let glyphBufferPointer = UnsafeMutablePointer<CGGlyph>.allocate(capacity: SeeMoreTextView.bufferLen)
        defer {
            glyphBufferPointer.deallocate()
        }

        let propBufferPointer = UnsafeMutablePointer<NSLayoutManager.GlyphProperty>.allocate(capacity: SeeMoreTextView.bufferLen)
        defer {
            propBufferPointer.deallocate()
        }

        var runningGlyphRange = NSRange()
        var index = 0
        while index < glyphRange.length {
            if charIndexes[index] >= seeMoreLocation {
                // Inside the truncated range
                if index > 0 && runningGlyphRange.length == 0 {
                    // Flush upto the current index
                    layoutManager.setGlyphs(
                        glyphs,
                        properties: props,
                        characterIndexes: charIndexes,
                        font: aFont,
                        forGlyphRange: NSMakeRange(glyphRange.location, index))
                }
                if runningGlyphRange.length == SeeMoreTextView.bufferLen {
                    layoutManager.setGlyphs(
                        glyphBufferPointer,
                        properties: propBufferPointer,
                        characterIndexes: charIndexes + runningGlyphRange.location,
                        font: aFont,
                        forGlyphRange: NSMakeRange(glyphRange.location + runningGlyphRange.location, runningGlyphRange.length))
                    runningGlyphRange.length = 0
                }

                if runningGlyphRange.length == 0 {
                    runningGlyphRange.location = index
                }

                if charIndexes[index] == seeMoreLocation {
                    propBufferPointer[runningGlyphRange.length] = .controlCharacter
                } else {
                    // Hide current glyph
                    glyphBufferPointer[runningGlyphRange.length] = kCGFontIndexInvalid
                    propBufferPointer[runningGlyphRange.length] = .null
                }
                runningGlyphRange.length += 1
            }
            index += 1
        }

        // Flush the glyphs remainder in buffer
        if runningGlyphRange.length > 0 {
            layoutManager.setGlyphs(
                glyphBufferPointer,
                properties: propBufferPointer,
                characterIndexes: charIndexes + runningGlyphRange.location,
                font: aFont,
                forGlyphRange: NSMakeRange(glyphRange.location + runningGlyphRange.location, runningGlyphRange.length))
        }

        return glyphRange.length
    }

    public func layoutManager(_ layoutManager: NSLayoutManager, shouldUse action: NSLayoutManager.ControlCharacterAction, forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        if let seeMoreLocation = seeMoreLocation,
           charIndex == seeMoreLocation
        {
            return .whitespace
        } else {
            return action
        }
    }

    // Stabilizes line wrapping.
    public func layoutManager(_ layoutManager: NSLayoutManager, boundingBoxForControlGlyphAt glyphIndex: Int, for textContainer: NSTextContainer, proposedLineFragment proposedRect: CGRect, glyphPosition: CGPoint, characterIndex charIndex: Int) -> CGRect {
        if let seeMoreLabelLocation = seeMoreLocation,
           charIndex == seeMoreLabelLocation
        {
            return .init(
                origin: .zero,
                size: ellipsisAndSeeMoreLabelBoundingSize)
        } else {
            return .zero
        }
    }
}

// MARK: - Helpers
extension SeeMoreTextView {
    func relayout() {
        prepare()
        invalidateIntrinsicContentSize()
        #if os(iOS)
        layoutIfNeeded()
        #elseif os(macOS)
        layoutSubtreeIfNeeded()
        #endif
    }

    // Computes seeMoreLocation and height.
    func prepare() {
        seeMoreLocation = nil
        height = 0

        seeMoreLabelRect = nil

        guard txtStorage.length > 0 else { return; }

        // Layout full text representation.

        relayoutText()

        // Determine ellipsis & see more label's line fragment.

        var ellipsisLineFragmentRect: CGRect?
        var ellipsisLineFragmentGlyphRange: NSRange?

        var line: Int = 0
        var firstLineFragmentRect: CGRect?
        var prevLineFragmentRect: CGRect?
        var prevLineFragmentGlyphRange: NSRange?

        let wholeGlyphRange = lytManager.glyphRange(for: txtContainer)

        lytManager.enumerateLineFragments(forGlyphRange: wholeGlyphRange) {
            lineFragmentRect,
            _,
            textContainer,
            glyphRange,
            stop in

            if let prevLineFragmentRect = prevLineFragmentRect {
                if prevLineFragmentRect.maxY <= lineFragmentRect.minY {
                    if !self.isExpanded && (line == self.collapsedLineCount - 1) {
                        ellipsisLineFragmentRect = prevLineFragmentRect
                        ellipsisLineFragmentGlyphRange = prevLineFragmentGlyphRange!

                        stop.pointee = true
                        return;
                    }
                    line += 1
                }
            }
            prevLineFragmentRect = lineFragmentRect
            prevLineFragmentGlyphRange = glyphRange
            if firstLineFragmentRect == nil { firstLineFragmentRect = lineFragmentRect }
            self.height = lineFragmentRect.maxY - firstLineFragmentRect!.minY
        }

        #if os(iOS)
        height += textContainerInset.top + textContainerInset.bottom
        #elseif os(macOS)
        height += textContainerOrigin.y
        #endif

        onHeightChange?(self)

        guard !isExpanded else { return; }

        // Determine `seeMoreLocation` within its line fragment.
        if let ellipsisLineFragmentRect = ellipsisLineFragmentRect,
           let ellipsisLineFragmentGlyphRange = ellipsisLineFragmentGlyphRange
        {
            let sz = self.ellipsisAndSeeMoreLabelBoundingSize

            let ellipsisAndSeeMoreLabelBoundingRect = CGRect(
                origin: CGPoint(
                    x: max(ellipsisLineFragmentRect.maxX - sz.width - txtContainer.lineFragmentPadding, 0),
                    y: ellipsisLineFragmentRect.origin.y),
                size: sz)

            var runningSeeMoreLocation: Int?
            for index in ellipsisLineFragmentGlyphRange.location..<ellipsisLineFragmentGlyphRange.maxLocation {
                let runningRect = self.lytManager.boundingRect(forGlyphRange: NSMakeRange(index, 1), in: txtContainer)

                if ellipsisAndSeeMoreLabelBoundingRect.contains(CGPoint(
                    x: runningRect.maxX,
                    y: runningRect.minY)) {
                    break
                }

                runningSeeMoreLocation = lytManager.characterIndexForGlyph(at: index)
            }
            seeMoreLocation = runningSeeMoreLocation ?? ellipsisLineFragmentGlyphRange.location

            // Ensure ellipsis character & see more label injection
            // and update layout
            relayoutText()
            updateEllipsisAndSeeMoreLabelRects()
        }
    }

    func relayoutText() {
        // Invalidate glyph mappings
        lytManager.invalidateGlyphs(forCharacterRange: txtStorage.wholeRange, changeInLength: 0, actualCharacterRange: nil)
        lytManager.invalidateLayout(forCharacterRange: txtStorage.wholeRange, actualCharacterRange: nil)  // must follow `invalidateGlyphs`
        // Relayout
        lytManager.ensureLayout(forCharacterRange: txtStorage.wholeRange)
    }

    // Having ellipsis char location calculates ellipsis & See More label rects.
    func updateEllipsisAndSeeMoreLabelRects() {
        guard let seeMoreLocation = self.seeMoreLocation else {
            ellipsisRect = nil
            seeMoreLabelRect = nil
            return;
        }

        // Get See More label's line fragment bounding rect.
        let lineFragmentBoundingRect = lytManager.lineFragmentRect(
            forGlyphAt: lytManager.glyphIndexForCharacter(at: seeMoreLocation),
            effectiveRange: nil)

        // Get text attributes.
        let textFont = txtStorage.attribute(.font, at: seeMoreLocation, effectiveRange: nil)
            as! Font// ?? SeeMoreTextView.defaultFont

        // Get SeeMore placement glyph rect.
        let seeMorePlacementGlyphRect = lytManager.boundingRect(
            forGlyphRange: NSMakeRange(lytManager.glyphIndexForCharacter(at: seeMoreLocation), 1),
            in: txtContainer)

        // Get ellipsis font.
        let ellipsisTextFont = ellipsisString.attribute(.font, at: 0, effectiveRange: nil)
            as? Font ?? SeeMoreTextView.defaultFont

        // Get ellipsis rect.
        let ellipsisStringSize = ellipsisString.size()
        #if os(iOS)
        let originX = textContainerInset.left
        let originY = textContainerInset.top
        #elseif os(macOS)
        let originX = textContainerOrigin.x
        let originY = textContainerOrigin.y
        #endif
        ellipsisRect = CGRect(
            origin: CGPoint(
                x: seeMorePlacementGlyphRect.minX + originX,
                y: lineFragmentBoundingRect.minY
                    + lineFragmentBoundingRect.height - ellipsisStringSize.height
                    + textFont.descender - ellipsisTextFont.descender
                    + originY),
            size: ellipsisStringSize
        )

        // Get SeeMore label font.
        let seeMoreTextFont = seeMoreString.attribute(.font, at: 0, effectiveRange: nil)
            as? Font ?? SeeMoreTextView.defaultFont

        // Get SeeMore label rect.
        let seeMoreStringSize = seeMoreString.size()
        seeMoreLabelRect = CGRect(
            origin: CGPoint(
                x: ellipsisRect!.maxX,
                y: lineFragmentBoundingRect.minY
                    + lineFragmentBoundingRect.height - seeMoreStringSize.height
                    + textFont.descender - seeMoreTextFont.descender
                    + originY),
            size: seeMoreStringSize)
    }

    var ellipsisAndSeeMoreLabelBoundingSize: CGSize {
        let ellipsisStringSize = ellipsisString.size()
        let seeMoreStringSize = seeMoreString.size()
        return CGSize(
            width: ellipsisStringSize.width + seeMoreStringSize.width,
            height: max(ellipsisStringSize.height, seeMoreStringSize.height))
    }

    #if os(macOS)
    func updateSeeMoreTextHighlighting() {
        if seeMoreTextHighlighted {
            seeMoreString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: seeMoreString.wholeRange)
            seeMoreString.addAttribute(.backgroundColor, value: Color(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.00), range: seeMoreString.wholeRange)
        } else {
            seeMoreString.removeAttribute(.underlineStyle, range: seeMoreString.wholeRange)
            seeMoreString.removeAttribute(.backgroundColor, range: seeMoreString.wholeRange)
        }
    }
    #endif
}