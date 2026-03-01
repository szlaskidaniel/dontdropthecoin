//
//  RoundFlaskVessel.swift
//  sift Shared
//

import CoreGraphics

/// Round-bottom flask: spherical body with a narrow neck.
struct RoundFlaskVessel: VesselShape {
    let name = "Round Flask"

    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry {
        let bodyW   = frameWidth * 0.76
        let neckW   = bodyW * 0.36
        let h       = frameHeight * 0.55
        let neckH   = h * 0.30
        let cx      = frameWidth / 2
        let by: CGFloat = 70

        let minX      = cx - bodyW / 2
        let maxX      = cx + bodyW / 2
        let topY      = by + h
        let shoulderY = topY - neckH
        let neckMinX  = cx - neckW / 2
        let neckMaxX  = cx + neckW / 2
        // The "corner radius" is effectively the whole bottom half of the sphere.
        let bodyCornerR: CGFloat = bodyW / 2

        // Sphere center and radius        
        let sphereR = bodyW / 2
        let sphereCY = by + sphereR  // center of the spherical region

        let path = CGMutablePath()

        // Left neck opening
        path.move(to: CGPoint(x: neckMinX, y: topY))

        // Left neck: smooth S-curve from neck down to sphere top
        path.addCurve(
            to: CGPoint(x: minX, y: sphereCY + sphereR * 0.30),
            control1: CGPoint(x: neckMinX, y: shoulderY + (topY - shoulderY) * 0.2),
            control2: CGPoint(x: minX, y: shoulderY)
        )

        // Left half of sphere (arc from top to bottom)
        path.addCurve(
            to: CGPoint(x: cx, y: by),
            control1: CGPoint(x: minX, y: sphereCY - sphereR * 0.40),
            control2: CGPoint(x: cx - sphereR * 0.15, y: by)
        )

        // Right half of sphere (arc from bottom to top)
        path.addCurve(
            to: CGPoint(x: maxX, y: sphereCY + sphereR * 0.30),
            control1: CGPoint(x: cx + sphereR * 0.15, y: by),
            control2: CGPoint(x: maxX, y: sphereCY - sphereR * 0.40)
        )

        // Right neck: smooth S-curve from sphere top up to neck
        path.addCurve(
            to: CGPoint(x: neckMaxX, y: topY),
            control1: CGPoint(x: maxX, y: shoulderY),
            control2: CGPoint(x: neckMaxX, y: shoulderY + (topY - shoulderY) * 0.2)
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
        let sphereR  = bodyHalf
        let sphereCY = geometry.bottomY + sphereR

        // The bezier S-curve in buildGeometry starts the sphere-to-neck transition
        // at sphereCY + sphereR * 0.30. Above that Y the path is no longer on the
        // sphere — it follows the S-curve up to the neck. Model this as a smooth
        // blend from the sphere width at the transition point to neckHalf at topY.
        let transitionY = sphereCY + sphereR * 0.30

        if y >= transitionY {
            // Width at the transition point on the sphere
            let transitionWidth = halfWidthAtSphere(
                y: transitionY, sphereCY: sphereCY,
                sphereR: sphereR, bodyHalf: bodyHalf
            )
            // Smooth hermite blend from transitionWidth down to neckHalf
            let t = (y - transitionY) / (geometry.topY - transitionY)
            let smooth = t * t * (3.0 - 2.0 * t)
            return transitionWidth + (neckHalf - transitionWidth) * smooth
        }

        // Spherical body region (below the transition point)
        return halfWidthAtSphere(y: y, sphereCY: sphereCY, sphereR: sphereR, bodyHalf: bodyHalf)
    }

    private func halfWidthAtSphere(y: CGFloat, sphereCY: CGFloat, sphereR: CGFloat, bodyHalf: CGFloat) -> CGFloat {
        let dy = y - sphereCY
        let ratio = dy / sphereR
        if abs(ratio) >= 1.0 { return 0 }
        return bodyHalf * sqrt(1.0 - ratio * ratio)
    }

    func leftInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let sphereR = geometry.bodyWidth / 2
        let sphereCY = geometry.bottomY + sphereR
        let lowerRimY = sphereCY - sphereR * 0.2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY - 1))
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset, y: sphereCY + sphereR * 0.30),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + (geometry.topY - geometry.shoulderY) * 0.2),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY)
        )
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset + 10, y: lowerRimY),
            control1: CGPoint(x: geometry.minX + offset, y: sphereCY),
            control2: CGPoint(x: geometry.minX + offset + 4, y: lowerRimY + 20)
        )
        return path
    }

    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let sphereR = geometry.bodyWidth / 2
        let sphereCY = geometry.bottomY + sphereR
        let lowerRimY = sphereCY - sphereR * 0.2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.topY - 1))
        path.addCurve(
            to: CGPoint(x: geometry.maxX - offset, y: sphereCY + sphereR * 0.30),
            control1: CGPoint(x: geometry.neckMaxX - offset, y: geometry.shoulderY + (geometry.topY - geometry.shoulderY) * 0.2),
            control2: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY)
        )
        path.addCurve(
            to: CGPoint(x: geometry.maxX - offset - 10, y: lowerRimY),
            control1: CGPoint(x: geometry.maxX - offset, y: sphereCY),
            control2: CGPoint(x: geometry.maxX - offset - 4, y: lowerRimY + 20)
        )
        return path
    }

    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let sphereR = geometry.bodyWidth / 2
        let sphereCY = geometry.bottomY + sphereR

        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY))
        path.addCurve(
            to: CGPoint(x: geometry.minX + offset, y: sphereCY + sphereR * 0.30),
            control1: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY + (geometry.topY - geometry.shoulderY) * 0.2),
            control2: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY)
        )
        path.addCurve(
            to: CGPoint(x: geometry.centerX - 10, y: geometry.bottomY + 8),
            control1: CGPoint(x: geometry.minX + offset, y: sphereCY - sphereR * 0.40),
            control2: CGPoint(x: geometry.centerX - sphereR * 0.15, y: geometry.bottomY + 2)
        )
        return path
    }
}
