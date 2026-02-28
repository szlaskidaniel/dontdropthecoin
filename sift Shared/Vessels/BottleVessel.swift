//
//  BottleVessel.swift
//  sift Shared
//

import CoreGraphics

/// The original bottle shape: wide body with a narrow neck and S-curve shoulders.
/// Used for stages 1-2 (and cycles back later).
struct BottleVessel: VesselShape {
    let name = "Bottle"

    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry {
        let bodyW   = frameWidth * 0.78
        let neckW   = bodyW * 0.38
        let h       = frameHeight * 0.55
        let neckH   = h * 0.36
        let cx      = frameWidth / 2
        let by: CGFloat = 70

        let minX    = cx - bodyW / 2
        let maxX    = cx + bodyW / 2
        let topY    = by + h
        let shoulderY = topY - neckH
        let neckMinX  = cx - neckW / 2
        let neckMaxX  = cx + neckW / 2
        let bodyCornerR: CGFloat = 28

        let path = CGMutablePath()

        // Start at left neck opening
        path.move(to: CGPoint(x: neckMinX, y: topY))

        // Left side: smooth S-curve from neck down to body
        path.addCurve(
            to: CGPoint(x: minX, y: shoulderY - 30),
            control1: CGPoint(x: neckMinX, y: shoulderY + 20),
            control2: CGPoint(x: minX, y: shoulderY + 10)
        )

        // Left body wall straight down to bottom-left corner
        path.addLine(to: CGPoint(x: minX, y: by + bodyCornerR))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: minX + bodyCornerR, y: by),
            control: CGPoint(x: minX, y: by)
        )

        // Floor
        path.addLine(to: CGPoint(x: maxX - bodyCornerR, y: by))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: by + bodyCornerR),
            control: CGPoint(x: maxX, y: by)
        )

        // Right body wall straight up to shoulder region
        path.addLine(to: CGPoint(x: maxX, y: shoulderY - 30))

        // Right side: smooth S-curve from body up to neck
        path.addCurve(
            to: CGPoint(x: neckMaxX, y: topY),
            control1: CGPoint(x: maxX, y: shoulderY + 10),
            control2: CGPoint(x: neckMaxX, y: shoulderY + 20)
        )

        return VesselGeometry(
            path: path,
            minX: minX, maxX: maxX,
            bottomY: by, topY: topY,
            shoulderY: shoulderY,
            neckMinX: neckMinX, neckMaxX: neckMaxX,
            neckHeight: neckH,
            bodyCornerRadius: bodyCornerR
        )
    }

    func halfWidthAt(y: CGFloat, geometry: VesselGeometry) -> CGFloat {
        guard y >= geometry.bottomY, y <= geometry.topY else { return 0 }
        let bodyHalf = geometry.bodyWidth / 2
        let neckHalf = geometry.neckWidth / 2
        let cornerR = geometry.bodyCornerRadius

        if y <= geometry.shoulderY {
            // Body region — full width (inset for corner radius at very bottom)
            if y < geometry.bottomY + cornerR {
                let t = (y - geometry.bottomY) / cornerR
                return bodyHalf - cornerR * (1.0 - sqrt(max(0, 1.0 - (1.0 - t) * (1.0 - t))))
            }
            return bodyHalf
        } else {
            // Neck/shoulder region — smoothstep from body width to neck width
            let t = (y - geometry.shoulderY) / (geometry.topY - geometry.shoulderY)
            let smooth = t * t * (3.0 - 2.0 * t)
            return bodyHalf + (neckHalf - bodyHalf) * smooth
        }
    }

    func leftInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY - 1))
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY - 30),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + 20),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY + 10)
        )
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: lowerRimY))
        return path
    }

    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.topY - 1))
        path.addCurve(
            to: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY - 30),
            control1: CGPoint(x: geometry.neckMaxX - offset, y: geometry.shoulderY + 20),
            control2: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY + 10)
        )
        path.addLine(to: CGPoint(x: geometry.maxX - offset, y: lowerRimY))
        return path
    }

    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY))
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY - 30),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + 20),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY + 10)
        )
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.bottomY + geometry.bodyCornerRadius))
        return path
    }
}
