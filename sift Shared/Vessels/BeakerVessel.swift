//
//  BeakerVessel.swift
//  sift Shared
//

import CoreGraphics

/// A wide rectangular beaker with a subtle lip at the top.
struct BeakerVessel: VesselShape {
    let name = "Beaker"

    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry {
        let bodyW   = frameWidth * 0.75
        let lipW    = bodyW * 0.90       // opening almost as wide as body
        let h       = frameHeight * 0.55
        let lipH    = h * 0.06           // very short lip region
        let cx      = frameWidth / 2
        let by: CGFloat = 70

        let minX      = cx - bodyW / 2
        let maxX      = cx + bodyW / 2
        let topY      = by + h
        let shoulderY = topY - lipH
        let neckMinX  = cx - lipW / 2
        let neckMaxX  = cx + lipW / 2
        let bodyCornerR: CGFloat = 10

        let path = CGMutablePath()

        // Left lip opening
        path.move(to: CGPoint(x: neckMinX, y: topY))
        // Short diagonal from lip to body wall
        path.addLine(to: CGPoint(x: minX, y: shoulderY))
        // Left wall straight down
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
        // Right wall straight up
        path.addLine(to: CGPoint(x: maxX, y: shoulderY))
        // Short diagonal to lip
        path.addLine(to: CGPoint(x: neckMaxX, y: topY))

        return VesselGeometry(
            path: path,
            minX: minX, maxX: maxX,
            bottomY: by, topY: topY,
            shoulderY: shoulderY,
            neckMinX: neckMinX, neckMaxX: neckMaxX,
            neckHeight: lipH,
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
            // Linear taper in the lip region
            let t = (y - geometry.shoulderY) / (geometry.topY - geometry.shoulderY)
            return bodyHalf + (neckHalf - bodyHalf) * t
        }
    }

    func leftInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY - 1))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: lowerRimY))
        return path
    }

    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMaxX - offset, y: geometry.topY - 1))
        path.addLine(to: CGPoint(x: geometry.maxX - offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.maxX - offset, y: lowerRimY))
        return path
    }

    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geometry.neckMinX + offset, y: geometry.topY))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.shoulderY))
        path.addLine(to: CGPoint(x: geometry.minX + offset, y: geometry.bottomY + geometry.bodyCornerRadius))
        return path
    }
}
