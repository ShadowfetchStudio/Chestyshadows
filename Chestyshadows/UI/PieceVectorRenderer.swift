import AppKit
import CoreGraphics
import CoreText

/// High-precision vector renderer for Staunton chess pieces with dynamic directional shadows
/// and solid 3D shading (outer silhouette separated from inner metallic detail inlays).
public final class PieceVectorRenderer: @unchecked Sendable {
    public static let shared = PieceVectorRenderer()

    private struct NormalizedGlyph {
        let outer: CGPath
        let inner: CGPath
        let aspect: CGFloat // width / height
    }

    private var glyphCache: [PieceKind: NormalizedGlyph] = [:]

    private init() {
        let font = CTFontCreateWithName("Apple Symbols" as CFString, 200.0, nil)
        for kind in PieceKind.allCases {
            glyphCache[kind] = Self.extractNormalizedGlyph(for: kind, font: font)
        }
    }

    /// Draws a chess piece inside `squareRect` (top-left origin coordinates where +Y is down).
    public func drawPiece(
        _ piece: Piece,
        in squareRect: CGRect,
        context ctx: CGContext,
        shadowIntensity: CGFloat = 0.85,
        elevation: CGFloat = 1.0,
        scale: CGFloat = 1.0
    ) {
        guard let glyph = glyphCache[piece.kind] else { return }

        let maxDim = min(squareRect.width, squareRect.height) * 0.78 * scale
        let drawHeight = maxDim
        let drawWidth = maxDim * min(1.06, max(0.72, glyph.aspect))

        let drawRect = CGRect(
            x: squareRect.midX - drawWidth * 0.5,
            y: squareRect.midY - drawHeight * 0.5,
            width: drawWidth,
            height: drawHeight
        )

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: drawRect.minX, y: drawRect.minY)
        transform = transform.scaledBy(x: drawRect.width, y: drawRect.height)

        guard let outerPath = glyph.outer.copy(using: &transform),
              let innerPath = glyph.inner.copy(using: &transform) else {
            return
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // 1. Soft ambient contact shadow under the pedestal base
        if shadowIntensity > 0.01 {
            ctx.saveGState()
            let baseShadowWidth = drawWidth * 0.86
            let baseShadowHeight = squareRect.height * 0.13
            let baseShadowRect = CGRect(
                x: drawRect.midX - baseShadowWidth * 0.5 + (2.5 * elevation),
                y: drawRect.maxY - baseShadowHeight * 0.55 + (2.0 * elevation),
                width: baseShadowWidth,
                height: baseShadowHeight
            )
            ctx.setFillColor(CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.34 * shadowIntensity))
            ctx.fillEllipse(in: baseShadowRect)
            ctx.restoreGState()
        }

        // 2. Outer silhouette with directional dramatic cast shadow
        ctx.saveGState()
        if shadowIntensity > 0.01 {
            let shadowOffset = CGSize(
                width: (3.2 + 4.5 * (elevation - 1.0)) * (0.65 + 0.55 * shadowIntensity),
                height: (5.0 + 6.5 * (elevation - 1.0)) * (0.65 + 0.55 * shadowIntensity)
            )
            let blurRadius = (7.5 + 8.0 * (elevation - 1.0)) * (0.6 + 0.6 * shadowIntensity)
            let shadowAlpha = min(0.82, (0.56 + 0.14 * (elevation - 1.0)) * shadowIntensity)
            ctx.setShadow(
                offset: shadowOffset,
                blur: blurRadius,
                color: CGColor(srgbRed: 0.01, green: 0.02, blue: 0.05, alpha: shadowAlpha)
            )
        }
        // Fill solid backing so the shadow casts from the entire solid silhouette
        ctx.addPath(outerPath)
        if piece.color == .white {
            ctx.setFillColor(CGColor(srgbRed: 0.92, green: 0.89, blue: 0.82, alpha: 1.0))
        } else {
            ctx.setFillColor(CGColor(srgbRed: 0.14, green: 0.16, blue: 0.22, alpha: 1.0))
        }
        ctx.fillPath()
        ctx.restoreGState()

        // 3. 3D sculpted gradient fill clipped to the outer silhouette
        ctx.saveGState()
        ctx.addPath(outerPath)
        ctx.clip()

        let bodyColors: [CGColor]
        if piece.color == .white {
            bodyColors = [
                CGColor(srgbRed: 0.995, green: 0.985, blue: 0.955, alpha: 1.0),
                CGColor(srgbRed: 0.93, green: 0.90, blue: 0.83, alpha: 1.0),
                CGColor(srgbRed: 0.78, green: 0.73, blue: 0.63, alpha: 1.0)
            ]
        } else {
            bodyColors = [
                CGColor(srgbRed: 0.29, green: 0.33, blue: 0.43, alpha: 1.0),
                CGColor(srgbRed: 0.15, green: 0.17, blue: 0.23, alpha: 1.0),
                CGColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
            ]
        }

        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: bodyColors as CFArray,
            locations: [0.0, 0.54, 1.0]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: drawRect.minX + drawRect.width * 0.2, y: drawRect.minY),
                end: CGPoint(x: drawRect.maxX - drawRect.width * 0.15, y: drawRect.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }

        // Subtle top-left rim lighting inside silhouette
        let highlightRect = CGRect(
            x: drawRect.minX - drawRect.width * 0.1,
            y: drawRect.minY - drawRect.height * 0.15,
            width: drawRect.width * 0.75,
            height: drawRect.height * 0.55
        )
        let glossAlpha: CGFloat = piece.color == .white ? 0.35 : 0.18
        ctx.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: glossAlpha))
        ctx.fillEllipse(in: highlightRect)
        ctx.restoreGState()

        // 4. Outer silhouette crisp bevel border
        ctx.saveGState()
        ctx.addPath(outerPath)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.setLineWidth(max(1.35, squareRect.width * 0.022))
        if piece.color == .white {
            ctx.setStrokeColor(CGColor(srgbRed: 0.22, green: 0.19, blue: 0.15, alpha: 0.92))
        } else {
            ctx.setStrokeColor(CGColor(srgbRed: 0.02, green: 0.03, blue: 0.05, alpha: 0.96))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // 5. Inner detail contours (crown jewels, knight mane/eye, base rings)
        if !innerPath.isEmpty {
            ctx.saveGState()
            ctx.addPath(innerPath)
            if piece.color == .white {
                // Warm antique bronze/gold detail inlay on ivory pieces
                ctx.setFillColor(CGColor(srgbRed: 0.44, green: 0.36, blue: 0.25, alpha: 0.85))
                ctx.fillPath(using: .evenOdd)
            } else {
                // Cool silver/gold specular inlay on obsidian pieces
                ctx.setFillColor(CGColor(srgbRed: 0.68, green: 0.74, blue: 0.86, alpha: 0.78))
                ctx.fillPath(using: .evenOdd)
            }
            ctx.restoreGState()
        }
    }

    // MARK: - Glyph Extraction & Normalization

    private static func extractNormalizedGlyph(for kind: PieceKind, font: CTFont) -> NormalizedGlyph {
        // Use the solid black Unicode chess codepoints (U+265A..U+265F) for richest interior detail
        let scalar: UniChar
        switch kind {
        case .king: scalar = 0x265A
        case .queen: scalar = 0x265B
        case .rook: scalar = 0x265C
        case .bishop: scalar = 0x265D
        case .knight: scalar = 0x265E
        case .pawn: scalar = 0x265F
        }

        var chars = [scalar]
        var glyphs = [CGGlyph](repeating: 0, count: 1)
        CTFontGetGlyphsForCharacters(font, &chars, &glyphs, 1)

        guard let rawPath = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
            let fallback = CGPath(ellipseIn: CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7), transform: nil)
            return NormalizedGlyph(outer: fallback, inner: CGMutablePath(), aspect: 1.0)
        }

        let bbox = rawPath.boundingBoxOfPath
        guard bbox.width > 0.001, bbox.height > 0.001 else {
            let fallback = CGPath(ellipseIn: CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7), transform: nil)
            return NormalizedGlyph(outer: fallback, inner: CGMutablePath(), aspect: 1.0)
        }

        // Transform raw glyph coordinates (bottom-left origin) into unit [0, 1] x [0, 1] top-left origin
        var subpaths: [(path: CGPath, bounds: CGRect)] = []
        var currentSubpath = CGMutablePath()

        let mapPoint: (CGPoint) -> CGPoint = { pt in
            let nx = (pt.x - bbox.minX) / bbox.width
            let ny = 1.0 - ((pt.y - bbox.minY) / bbox.height)
            return CGPoint(x: nx, y: ny)
        }

        rawPath.applyWithBlock { elementPtr in
            let el = elementPtr.pointee
            switch el.type {
            case .moveToPoint:
                if !currentSubpath.isEmpty {
                    let copy = currentSubpath.copy()!
                    subpaths.append((copy, copy.boundingBoxOfPath))
                    currentSubpath = CGMutablePath()
                }
                currentSubpath.move(to: mapPoint(el.points[0]))
            case .addLineToPoint:
                currentSubpath.addLine(to: mapPoint(el.points[0]))
            case .addQuadCurveToPoint:
                currentSubpath.addQuadCurve(to: mapPoint(el.points[1]), control: mapPoint(el.points[0]))
            case .addCurveToPoint:
                currentSubpath.addCurve(
                    to: mapPoint(el.points[2]),
                    control1: mapPoint(el.points[0]),
                    control2: mapPoint(el.points[1])
                )
            case .closeSubpath:
                currentSubpath.closeSubpath()
                let copy = currentSubpath.copy()!
                subpaths.append((copy, copy.boundingBoxOfPath))
                currentSubpath = CGMutablePath()
            @unknown default:
                break
            }
        }
        if !currentSubpath.isEmpty {
            let copy = currentSubpath.copy()!
            subpaths.append((copy, copy.boundingBoxOfPath))
        }

        let outer = CGMutablePath()
        let inner = CGMutablePath()

        for i in 0..<subpaths.count {
            let b1 = subpaths[i].bounds.insetBy(dx: 0.002, dy: 0.002)
            let area1 = subpaths[i].bounds.width * subpaths[i].bounds.height
            var isContainedInLarger = false
            for j in 0..<subpaths.count where i != j {
                let b2 = subpaths[j].bounds
                let area2 = b2.width * b2.height
                if area2 > area1 * 1.05 && b2.contains(b1) {
                    isContainedInLarger = true
                    break
                }
            }
            if isContainedInLarger {
                inner.addPath(subpaths[i].path)
            } else {
                outer.addPath(subpaths[i].path)
            }
        }

        return NormalizedGlyph(
            outer: outer,
            inner: inner,
            aspect: bbox.width / bbox.height
        )
    }
}
