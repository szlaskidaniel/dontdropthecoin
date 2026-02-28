//
//  ErlenmeyerVessel.swift
//  sift Shared
//

import CoreGraphics

/// Erlenmeyer (conical) flask: wide flat base tapering to a narrow neck.
struct ErlenmeyerVessel: VesselShape {
    let name = "Erlenmeyer Flask"

    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry {
        let bodyW   = frameWidth * 0.80
        let neckW   = bodyW * 0.38
        let h       = frameHeight * 0.55
        let neckH   = h * 0.18          // short neck before straight taper
        let cx      = frameWidth / 2
        let by: CGFloat = 70

        let minX      = cx - bodyW / 2
        let maxX      = cx + bodyW / 2
        let topY      = by + h
        let shoulderY = topY - neckH
        let neckMinX  = cx - neckW / 2
        let neckMaxX  = cx + neckW / 2
        let bodyCornerR: CGFloat = 14

        let path = CGMutablePath()

        // Left neck opening
        path.move(to: CGPoint(x: neckMinX, y: topY))
        // Short vertical neck
        path.addLine(to: CGPoint(x: neckMinX, y: shoulderY))
        // Straight angled wall from narrow neck to wide base
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
        // Straight angled wall up to neck
        path.addLine(to: CGPoint(x: neckMaxX, y: shoulderY))
        // Short vertical neck
        path.addLine(to: CGPoint(x: neckMaxX, y: topY))

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

        if y > geometry.shoulderY {
            // Inside the vertical neck
            return neckHalf
        }

        // Below shoulder: linear taper from wide base to narrow neck
        let taperBottom = geometry.bottomY + cornerR
        if y < taperBottom {
            // Bottom corner region
            let t = (y - geometry.bottomY) / cornerR
            return bodyHalf - cornerR * (1.0 - sqrt(max(0, 1.0 - (1.0 - t) * (1.0 - t))))
        }

        // Linear interpolation from body width at bottom to neck width at shoulder
        let t = (y - taperBottom) / (geometry.shoulderY - taperBottom)
        return bodyHalf + (neckHalf - bodyHalf) * t
    }

    func leftInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY - 1))
        path.addLine(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: lowerRimY))
        return path
    }

    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.topY - 1))
        path.addLine(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.maxX - offset, y: lowerRimY))
        return path
    }

    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY))
        path.addLine(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.bottomY + geometry.bodyCornerRadius))
        return path
    }
}
