//
//  TallFlaskVessel.swift
//  sift Shared
//

import CoreGraphics

/// Tall narrow flask: narrower and taller than the bottle, with a medium neck.
struct TallFlaskVessel: VesselShape {
    let name = "Tall Flask"

    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry {
        let bodyW   = frameWidth * 0.54
        let neckW   = bodyW * 0.42
        let h       = frameHeight * 0.65   // taller than standard
        let neckH   = h * 0.28
        let cx      = frameWidth / 2
        let by: CGFloat = 50               // lower base to accommodate height

        let minX      = cx - bodyW / 2
        let maxX      = cx + bodyW / 2
        let topY      = by + h
        let shoulderY = topY - neckH
        let neckMinX  = cx - neckW / 2
        let neckMaxX  = cx + neckW / 2
        let bodyCornerR: CGFloat = 22

        let path = CGMutablePath()

        // Left neck opening
        path.move(to: CGPoint(x: neckMinX, y: topY))

        // Left side: smooth curve from neck down to body
        path.addCurve(
            to: CGPoint(x: minX, y: shoulderY - 20),
            control1: CGPoint(x: neckMinX, y: shoulderY + 15),
            control2: CGPoint(x: minX, y: shoulderY + 5)
        )

        // Left body wall straight down
        path.addLine(to: CGPoint(x: minX, y: by + bodyCornerR))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: minX + bodyCornerR, y: by),
            control: CGPoint(x: minX, y: by)
        )

        // Floor
        path.addLine(to: CGPoint(x: maxX - bodyCornerR, y: by))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: by + bodyCornerR),
            control: CGPoint(x: maxX, y: by)
        )

        // Right body wall straight up
        path.addLine(to: CGPoint(x: maxX, y: shoulderY - 20))

        // Right side: smooth curve from body up to neck
        path.addCurve(
            to: CGPoint(x: neckMaxX, y: topY),
            control1: CGPoint(x: maxX, y: shoulderY + 5),
            control2: CGPoint(x: neckMaxX, y: shoulderY + 15)
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
            if y < geometry.bottomY + cornerR {
                let t = (y - geometry.bottomY) / cornerR
                return bodyHalf - cornerR * (1.0 - sqrt(max(0, 1.0 - (1.0 - t) * (1.0 - t))))
            }
            return bodyHalf
        } else {
            // Smooth taper from body to neck
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
            to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY - 20),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + 15),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY + 5)
        )
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: lowerRimY))
        return path
    }

    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.topY - 1))
        path.addCurve(
            to: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY - 20),
            control1: CGPoint(x: geometry.neckMaxX - offset, y: geometry.shoulderY + 15),
            control2: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY + 5)
        )
        path.addLine(to: CGPoint(x: geometry.maxX - offset, y: lowerRimY))
        return path
    }

    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY))
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY - 20),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + 15),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY + 5)
        )
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.bottomY + geometry.bodyCornerRadius))
        return path
    }
}
