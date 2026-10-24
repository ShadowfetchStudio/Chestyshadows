import AppKit
import SwiftUI

public struct BoardCanvasView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var isDraggingGesture: Bool = false

    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let frameInset: CGFloat = max(22.0, round(side * 0.038))
            let boardSide = side - frameInset * 2.0
            let squareSide = boardSide / 8.0

            ZStack {
                // Outer luxury board frame with coordinate rails
                Canvas { context, size in
                    context.withCGContext { cgCtx in
                        drawOuterFrameAndCoordinates(
                            in: cgCtx,
                            side: side,
                            frameInset: frameInset,
                            squareSide: squareSide,
                            theme: viewModel.theme
                        )
                    }
                }
                .frame(width: side, height: side)
                .shadow(color: Color.black.opacity(0.65), radius: 22, x: 0, y: 12)

                // 120Hz ProMotion Canvas for the 8x8 grid, overlays, and vector Staunton pieces
                TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: viewModel.activeAnimation == nil && viewModel.draggedSquare == nil)) { timeline in
                    let now = CACurrentMediaTime()
                    Canvas(rendersAsynchronously: false) { context, size in
                        context.withCGContext { cgCtx in
                            drawBoardAndPieces(
                                in: cgCtx,
                                size: CGSize(width: boardSide, height: boardSide),
                                squareSide: squareSide,
                                now: now
                            )
                        }
                    }
                    .frame(width: boardSide, height: boardSide)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.0)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handlePointerChanged(
                                    location: value.location,
                                    startLocation: value.startLocation,
                                    squareSide: squareSide
                                )
                            }
                            .onEnded { value in
                                handlePointerEnded(
                                    location: value.location,
                                    startLocation: value.startLocation,
                                    squareSide: squareSide
                                )
                            }
                    )
                }

                // Pawn Promotion Picker Overlay
                if viewModel.pendingPromotionMoves != nil {
                    promotionOverlay(squareSide: squareSide)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
        }
    }

    // MARK: - Pointer & Drag Handling

    private func squareAt(point: CGPoint, squareSide: CGFloat) -> Square? {
        guard squareSide > 0 else { return nil }
        let col = Int(floor(point.x / squareSide))
        let row = Int(floor(point.y / squareSide))
        guard (0..<8).contains(col), (0..<8).contains(row) else { return nil }
        let file = viewModel.isFlipped ? (7 - col) : col
        let rank = viewModel.isFlipped ? row : (7 - row)
        return Square(file: file, rank: rank)
    }

    private func rectFor(square: Square, squareSide: CGFloat) -> CGRect {
        let col = viewModel.isFlipped ? (7 - square.file) : square.file
        let row = viewModel.isFlipped ? square.rank : (7 - square.rank)
        return CGRect(
            x: CGFloat(col) * squareSide,
            y: CGFloat(row) * squareSide,
            width: squareSide,
            height: squareSide
        )
    }

    private func handlePointerChanged(location: CGPoint, startLocation: CGPoint, squareSide: CGFloat) {
        let dist = hypot(location.x - startLocation.x, location.y - startLocation.y)
        if !isDraggingGesture && dist > 5.0 {
            if let startSq = squareAt(point: startLocation, squareSide: squareSide),
               let piece = viewModel.displayedBoard[startSq],
               piece.color == viewModel.displayedBoard.sideToMove {
                isDraggingGesture = true
                viewModel.beginDrag(from: startSq, at: location)
            }
        }
        if isDraggingGesture {
            viewModel.updateDrag(to: location)
        }
    }

    private func handlePointerEnded(location: CGPoint, startLocation: CGPoint, squareSide: CGFloat) {
        if isDraggingGesture {
            isDraggingGesture = false
            let targetSq = squareAt(point: location, squareSide: squareSide)
            viewModel.endDrag(on: targetSq)
        } else {
            if let tappedSq = squareAt(point: location, squareSide: squareSide) {
                viewModel.handleSquareTap(tappedSq)
            }
        }
    }

    // MARK: - CoreGraphics Board & Piece Drawing

    private func drawBoardAndPieces(
        in ctx: CGContext,
        size: CGSize,
        squareSide: CGFloat,
        now: TimeInterval
    ) {
        let board = viewModel.displayedBoard
        let theme = viewModel.theme
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let whiteAttacks = viewModel.showShadowThreatMap ? board.attackedSquares(by: .white) : []
        let blackAttacks = viewModel.showShadowThreatMap ? board.attackedSquares(by: .black) : []

        // 1. Draw 64 squares
        for rank in 0..<8 {
            for file in 0..<8 {
                let sq = Square(file: file, rank: rank)
                let rect = rectFor(square: sq, squareSide: squareSide)

                let topColor = sq.isLightSquare ? theme.lightSquareTop.cgColor : theme.darkSquareTop.cgColor
                let bottomColor = sq.isLightSquare ? theme.lightSquareBottom.cgColor : theme.darkSquareBottom.cgColor

                ctx.saveGState()
                ctx.clip(to: rect)
                if let gradient = CGGradient(
                    colorsSpace: colorSpace,
                    colors: [topColor, bottomColor] as CFArray,
                    locations: [0.0, 1.0]
                ) {
                    ctx.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: rect.minX, y: rect.minY),
                        end: CGPoint(x: rect.maxX, y: rect.maxY),
                        options: []
                    )
                }

                // Subtle top edge highlight for tactile tile separation
                ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: sq.isLightSquare ? 0.07 : 0.035))
                ctx.setLineWidth(1.0)
                ctx.stroke(rect.insetBy(dx: 0.5, dy: 0.5))

                // Optional Shadow Threat Map overlay
                if viewModel.showShadowThreatMap {
                    let wControl = whiteAttacks.contains(sq)
                    let bControl = blackAttacks.contains(sq)
                    if wControl && !bControl {
                        ctx.setFillColor(CGColor(srgbRed: 0.94, green: 0.78, blue: 0.35, alpha: 0.22))
                        ctx.fill(rect)
                    } else if bControl && !wControl {
                        ctx.setFillColor(CGColor(srgbRed: 0.62, green: 0.24, blue: 0.88, alpha: 0.25))
                        ctx.fill(rect)
                    } else if wControl && bControl {
                        ctx.setFillColor(CGColor(srgbRed: 0.92, green: 0.36, blue: 0.44, alpha: 0.24))
                        ctx.fill(rect)
                    }
                }
                ctx.restoreGState()
            }
        }

        // 2. Highlight last move squares
        if let lastMove = board.lastMove {
            for sq in [lastMove.from, lastMove.to] {
                let rect = rectFor(square: sq, squareSide: squareSide)
                ctx.saveGState()
                ctx.setFillColor(theme.lastMoveHighlight.cgColor)
                ctx.fill(rect)
                ctx.setStrokeColor(theme.accentNSColor.withAlphaComponent(0.55).cgColor)
                ctx.setLineWidth(1.5)
                ctx.stroke(rect.insetBy(dx: 1.0, dy: 1.0))
                ctx.restoreGState()
            }
        }

        // 3. Highlight selected square
        if let selected = viewModel.selectedSquare {
            let rect = rectFor(square: selected, squareSide: squareSide)
            ctx.saveGState()
            ctx.setFillColor(theme.selectedSquareHighlight.cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(theme.accentNSColor.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(2.0)
            ctx.stroke(rect.insetBy(dx: 1.2, dy: 1.2))
            ctx.restoreGState()
        }

        // 4. King in check crimson radial glow
        if board.isInCheck(board.sideToMove), let kingSq = board.kingSquare(for: board.sideToMove) {
            let rect = rectFor(square: kingSq, squareSide: squareSide)
            ctx.saveGState()
            ctx.clip(to: rect)
            let colors = [
                CGColor(srgbRed: 0.98, green: 0.18, blue: 0.24, alpha: 0.78),
                CGColor(srgbRed: 0.85, green: 0.08, blue: 0.16, alpha: 0.42),
                CGColor(srgbRed: 0.70, green: 0.04, blue: 0.10, alpha: 0.0)
            ] as CFArray
            if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.65, 1.0]) {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                ctx.drawRadialGradient(
                    grad,
                    startCenter: center,
                    startRadius: 2.0,
                    endCenter: center,
                    endRadius: squareSide * 0.68,
                    options: [.drawsAfterEndLocation]
                )
            }
            ctx.restoreGState()
        }

        // 5. Legal destination markers (dots for quiet moves, corner brackets for captures)
        if !viewModel.isViewingHistory {
            var seenTargets = Set<Square>()
            for move in viewModel.legalMovesForSelected {
                guard seenTargets.insert(move.to).inserted else { continue }
                let rect = rectFor(square: move.to, squareSide: squareSide)
                ctx.saveGState()
                let isCapture = board.capturedPiece(for: move) != nil || board[move.to] != nil
                if isCapture {
                    drawCaptureCornerBrackets(in: ctx, rect: rect, squareSide: squareSide, color: theme.accentNSColor)
                } else {
                    let dotRadius = squareSide * 0.145
                    let dotRect = CGRect(
                        x: rect.midX - dotRadius,
                        y: rect.midY - dotRadius,
                        width: dotRadius * 2.0,
                        height: dotRadius * 2.0
                    )
                    ctx.setFillColor(CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.28))
                    ctx.fillEllipse(in: dotRect.offsetBy(dx: 0, dy: 1.5))
                    ctx.setFillColor(theme.accentNSColor.withAlphaComponent(0.82).cgColor)
                    ctx.fillEllipse(in: dotRect)
                }
                ctx.restoreGState()
            }
        }

        // 7. Hint arrow if active
        if let hint = viewModel.hintMove {
            let fromRect = rectFor(square: hint.from, squareSide: squareSide)
            let toRect = rectFor(square: hint.to, squareSide: squareSide)
            drawHintArrow(
                in: ctx,
                from: CGPoint(x: fromRect.midX, y: fromRect.midY),
                to: CGPoint(x: toRect.midX, y: toRect.midY),
                squareSide: squareSide
            )
        }

        // 8. Draw stationary pieces (excluding dragged square or currently flying square)
        let anim = viewModel.activeAnimation
        let animProgress = anim?.progress(at: now) ?? 1.0
        let isAnimating = anim != nil && animProgress < 0.999

        for sq in Square.all {
            guard let piece = board[sq] else { continue }
            if viewModel.draggedSquare == sq { continue }
            if isAnimating, let anim {
                if sq == anim.to || sq == anim.secondaryTo {
                    continue
                }
            }
            let rect = rectFor(square: sq, squareSide: squareSide)
            PieceVectorRenderer.shared.drawPiece(
                piece,
                in: rect,
                context: ctx,
                shadowIntensity: CGFloat(viewModel.shadowIntensity),
                elevation: 1.0,
                scale: 1.0
            )
        }

        // 9. Draw animated flying piece(s)
        if isAnimating, let anim {
            let liftArc = sin(animProgress * .pi)
            let elevation = 1.0 + 0.85 * liftArc
            let scale = 1.0 + 0.075 * liftArc

            if let secPiece = anim.secondaryPiece,
               let secFrom = anim.secondaryFrom,
               let secTo = anim.secondaryTo {
                let r0 = rectFor(square: secFrom, squareSide: squareSide)
                let r1 = rectFor(square: secTo, squareSide: squareSide)
                let interpRect = CGRect(
                    x: r0.minX + (r1.minX - r0.minX) * animProgress,
                    y: r0.minY + (r1.minY - r0.minY) * animProgress,
                    width: squareSide,
                    height: squareSide
                )
                PieceVectorRenderer.shared.drawPiece(
                    secPiece,
                    in: interpRect,
                    context: ctx,
                    shadowIntensity: CGFloat(viewModel.shadowIntensity),
                    elevation: elevation,
                    scale: scale
                )
            }

            let r0 = rectFor(square: anim.from, squareSide: squareSide)
            let r1 = rectFor(square: anim.to, squareSide: squareSide)
            let interpRect = CGRect(
                x: r0.minX + (r1.minX - r0.minX) * animProgress,
                y: r0.minY + (r1.minY - r0.minY) * animProgress - (liftArc * squareSide * 0.08),
                width: squareSide,
                height: squareSide
            )
            PieceVectorRenderer.shared.drawPiece(
                anim.piece,
                in: interpRect,
                context: ctx,
                shadowIntensity: CGFloat(viewModel.shadowIntensity),
                elevation: elevation,
                scale: scale
            )
        }

        // 10. Draw dragged piece lifted under the pointer
        if let dragSq = viewModel.draggedSquare,
           let dragPt = viewModel.dragCurrentPoint,
           let draggedPiece = board[dragSq] {
            if let hoverSq = squareAt(point: dragPt, squareSide: squareSide) {
                let hoverRect = rectFor(square: hoverSq, squareSide: squareSide)
                ctx.saveGState()
                ctx.setStrokeColor(theme.accentNSColor.withAlphaComponent(0.85).cgColor)
                ctx.setLineWidth(2.5)
                ctx.stroke(hoverRect.insetBy(dx: 2.0, dy: 2.0))
                ctx.restoreGState()
            }

            let dragRect = CGRect(
                x: dragPt.x - squareSide * 0.5,
                y: dragPt.y - squareSide * 0.54,
                width: squareSide,
                height: squareSide
            )
            PieceVectorRenderer.shared.drawPiece(
                draggedPiece,
                in: dragRect,
                context: ctx,
                shadowIntensity: CGFloat(viewModel.shadowIntensity),
                elevation: 1.9,
                scale: 1.10
            )
        }
    }

    private func drawOuterFrameAndCoordinates(
        in ctx: CGContext,
        side: CGFloat,
        frameInset: CGFloat,
        squareSide: CGFloat,
        theme: BoardTheme
    ) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let outerRect = CGRect(x: 0, y: 0, width: side, height: side)
        let framePath = CGPath(roundedRect: outerRect, cornerWidth: 16, cornerHeight: 16, transform: nil)

        ctx.saveGState()
        ctx.addPath(framePath)
        ctx.clip()

        let frameColors = [
            theme.boardFrameColor.cgColor,
            CGColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1.0)
        ] as CFArray
        if let grad = CGGradient(colorsSpace: colorSpace, colors: frameColors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: side, y: side),
                options: []
            )
        }
        ctx.restoreGState()

        // Outer metallic pin-line border
        ctx.saveGState()
        let borderPath = CGPath(
            roundedRect: outerRect.insetBy(dx: 0.75, dy: 0.75),
            cornerWidth: 15.25,
            cornerHeight: 15.25,
            transform: nil
        )
        ctx.addPath(borderPath)
        ctx.setStrokeColor(theme.accentNSColor.withAlphaComponent(0.38).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokePath()
        ctx.restoreGState()

        guard viewModel.showCoordinates else { return }

        let fontSize = max(9.5, round(frameInset * 0.44))
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let labelColor = theme.accentNSColor.withAlphaComponent(0.78)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: labelColor
        ]
        let files = ["a", "b", "c", "d", "e", "f", "g", "h"]

        // Bottom file rail (a-h)
        for col in 0..<8 {
            let fileIndex = viewModel.isFlipped ? (7 - col) : col
            let str = NSAttributedString(string: files[fileIndex], attributes: attrs)
            let sz = str.size()
            let centerX = frameInset + (CGFloat(col) + 0.5) * squareSide
            let centerY = side - frameInset * 0.52
            drawAttributedString(str, at: CGPoint(x: centerX - sz.width * 0.5, y: centerY - sz.height * 0.5), in: ctx)
        }

        // Left rank rail (1-8)
        for row in 0..<8 {
            let rankIndex = viewModel.isFlipped ? row : (7 - row)
            let str = NSAttributedString(string: "\(rankIndex + 1)", attributes: attrs)
            let sz = str.size()
            let centerX = frameInset * 0.50
            let centerY = frameInset + (CGFloat(row) + 0.5) * squareSide
            drawAttributedString(str, at: CGPoint(x: centerX - sz.width * 0.5, y: centerY - sz.height * 0.5), in: ctx)
        }
    }

    private func drawCaptureCornerBrackets(
        in ctx: CGContext,
        rect: CGRect,
        squareSide: CGFloat,
        color: NSColor
    ) {
        let inset = max(3.0, squareSide * 0.055)
        let r = rect.insetBy(dx: inset, dy: inset)
        let len = squareSide * 0.22
        let path = CGMutablePath()

        // Top-left
        path.move(to: CGPoint(x: r.minX, y: r.minY + len))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.minX + len, y: r.minY))

        // Top-right
        path.move(to: CGPoint(x: r.maxX - len, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + len))

        // Bottom-left
        path.move(to: CGPoint(x: r.minX, y: r.maxY - len))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + len, y: r.maxY))

        // Bottom-right
        path.move(to: CGPoint(x: r.maxX - len, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - len))

        ctx.addPath(path)
        ctx.setStrokeColor(color.withAlphaComponent(0.92).cgColor)
        ctx.setLineWidth(max(2.2, squareSide * 0.045))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }

    private func drawAttributedString(_ attrString: NSAttributedString, at point: CGPoint, in ctx: CGContext) {
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        ctx.textPosition = CGPoint(x: point.x, y: point.y + bounds.height * 0.82)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private func drawHintArrow(in ctx: CGContext, from: CGPoint, to: CGPoint, squareSide: CGFloat) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 4.0 else { return }

        let ux = dx / length
        let uy = dy / length
        let px = -uy
        let py = ux

        let startPt = CGPoint(x: from.x + ux * (squareSide * 0.16), y: from.y + uy * (squareSide * 0.16))
        let tipPt = CGPoint(x: to.x - ux * (squareSide * 0.10), y: to.y - uy * (squareSide * 0.10))
        let headLen = squareSide * 0.28
        let headHalfWidth = squareSide * 0.19
        let shaftHalfWidth = squareSide * 0.068

        let neckPt = CGPoint(x: tipPt.x - ux * headLen, y: tipPt.y - uy * headLen)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: startPt.x + px * shaftHalfWidth, y: startPt.y + py * shaftHalfWidth))
        path.addLine(to: CGPoint(x: neckPt.x + px * shaftHalfWidth, y: neckPt.y + py * shaftHalfWidth))
        path.addLine(to: CGPoint(x: neckPt.x + px * headHalfWidth, y: neckPt.y + py * headHalfWidth))
        path.addLine(to: tipPt)
        path.addLine(to: CGPoint(x: neckPt.x - px * headHalfWidth, y: neckPt.y - py * headHalfWidth))
        path.addLine(to: CGPoint(x: neckPt.x - px * shaftHalfWidth, y: neckPt.y - py * shaftHalfWidth))
        path.addLine(to: CGPoint(x: startPt.x - px * shaftHalfWidth, y: startPt.y - py * shaftHalfWidth))
        path.closeSubpath()

        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: 3),
            blur: 8.0,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55)
        )
        ctx.addPath(path)
        ctx.setFillColor(CGColor(srgbRed: 0.28, green: 0.86, blue: 0.58, alpha: 0.86))
        ctx.fillPath()
        ctx.addPath(path)
        ctx.setStrokeColor(CGColor(srgbRed: 0.88, green: 1.0, blue: 0.94, alpha: 0.9))
        ctx.setLineWidth(1.5)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Pawn Promotion Overlay

    @ViewBuilder
    private func promotionOverlay(squareSide: CGFloat) -> some View {
        let color = viewModel.board.sideToMove
        let choices: [PieceKind] = [.queen, .rook, .bishop, .knight]

        ZStack {
            Color.black.opacity(0.55)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    viewModel.cancelPromotion()
                }

            VStack(spacing: 14) {
                Text("PROMOTE PAWN")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(viewModel.theme.accentColor)

                HStack(spacing: 14) {
                    ForEach(choices, id: \.rawValue) { kind in
                        Button {
                            viewModel.completePromotion(with: kind)
                        } label: {
                            VStack(spacing: 6) {
                                Canvas { context, size in
                                    context.withCGContext { cgCtx in
                                        PieceVectorRenderer.shared.drawPiece(
                                            Piece(color, kind),
                                            in: CGRect(origin: .zero, size: size),
                                            context: cgCtx,
                                            shadowIntensity: 0.85
                                        )
                                    }
                                }
                                .frame(width: 58, height: 58)

                                Text(kind.rawValue.capitalized)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(viewModel.theme.accentColor.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: NSColor(srgbRed: 0.08, green: 0.09, blue: 0.13, alpha: 0.96)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(viewModel.theme.accentColor.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.75), radius: 24, x: 0, y: 12)
        }
    }
}
