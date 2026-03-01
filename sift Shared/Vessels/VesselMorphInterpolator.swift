//
//  VesselMorphInterpolator.swift
//  sift Shared
//

import CoreGraphics

/// Generates interpolated vessel geometry between two shapes at any blend factor.
/// Uses each shape's `halfWidthAt` mathematical definition to produce smooth intermediate paths.
/// Paths are built with dense line segments (~200 per side) so individual segments are sub-pixel
/// and invisible under the stroke width and glow effects.
struct VesselMorphInterpolator {
    let fromShape: VesselShape
    let toShape: VesselShape
    let fromGeometry: VesselGeometry
    let toGeometry: VesselGeometry

    /// Total number of Y-samples per side. At ~200 samples over ~400pt height,
    /// each segment is ~2pt — well below the 3.5pt stroke width.
    private let sampleCount = 200

    // MARK: - Geometry Interpolation

    /// Generate an interpolated `VesselGeometry` at blend factor `t` (0 = from, 1 = to).
    func interpolatedGeometry(at t: CGFloat) -> VesselGeometry {
        let t = max(0, min(1, t))

        let minX = lerp(fromGeometry.minX, toGeometry.minX, t)
        let maxX = lerp(fromGeometry.maxX, toGeometry.maxX, t)
        let bottomY = lerp(fromGeometry.bottomY, toGeometry.bottomY, t)
        let topY = lerp(fromGeometry.topY, toGeometry.topY, t)
        let shoulderY = lerp(fromGeometry.shoulderY, toGeometry.shoulderY, t)
        let neckMinX = lerp(fromGeometry.neckMinX, toGeometry.neckMinX, t)
        let neckMaxX = lerp(fromGeometry.neckMaxX, toGeometry.neckMaxX, t)
        let neckHeight = lerp(fromGeometry.neckHeight, toGeometry.neckHeight, t)
        let bodyCornerRadius = lerp(fromGeometry.bodyCornerRadius, toGeometry.bodyCornerRadius, t)
        let centerX = (minX + maxX) / 2

        let path = buildPath(
            bottomY: bottomY, topY: topY,
            centerX: centerX, t: t
        )

        return VesselGeometry(
            path: path,
            minX: minX, maxX: maxX,
            bottomY: bottomY, topY: topY,
            shoulderY: shoulderY,
            neckMinX: neckMinX, neckMaxX: neckMaxX,
            neckHeight: neckHeight,
            bodyCornerRadius: bodyCornerRadius
        )
    }

    // MARK: - Interpolated Half-Width

    /// Returns the interpolated half-width at a given normalized Y fraction in the blended coordinate space.
    func interpolatedHalfWidth(atNormalized frac: CGFloat, t: CGFloat) -> CGFloat {
        let yA = fromGeometry.bottomY + frac * (fromGeometry.topY - fromGeometry.bottomY)
        let yB = toGeometry.bottomY + frac * (toGeometry.topY - toGeometry.bottomY)

        let hwA = fromShape.halfWidthAt(y: yA, geometry: fromGeometry)
        let hwB = toShape.halfWidthAt(y: yB, geometry: toGeometry)
        return lerp(hwA, hwB, t)
    }

    // MARK: - Rim & Highlight Paths

    /// Generates an interpolated left inner rim path.
    func interpolatedLeftRimPath(at t: CGFloat, geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        guard lowerRimY < geometry.topY - 1 else { return nil }

        let path = CGMutablePath()
        let n = 80

        // Sample all points first, including the start, so the move-to
        // and line-to points use the same halfWidth source — no jump at the top.
        var points: [CGPoint] = []
        for i in 0...n {
            let frac = CGFloat(i) / CGFloat(n)
            let y = geometry.topY - 1 - frac * (geometry.topY - 1 - lowerRimY)
            let normalizedFrac = (y - geometry.bottomY) / (geometry.topY - geometry.bottomY)
            let hw = interpolatedHalfWidth(atNormalized: normalizedFrac, t: t)
            points.append(CGPoint(x: geometry.centerX - hw + offset, y: y))
        }

        // Enforce monotonic x: the left rim should only move left (x decreasing)
        // as we go down from the neck. Clamp any point that jitters back right.
        for i in 1..<points.count {
            if points[i].x > points[i - 1].x {
                points[i].x = points[i - 1].x
            }
        }

        path.move(to: points[0])
        for i in 1...n { path.addLine(to: points[i]) }
        return path
    }

    /// Generates an interpolated right inner rim path.
    func interpolatedRightRimPath(at t: CGFloat, geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let lowerRimY = geometry.bottomY + geometry.bodyCornerRadius + 20
        guard lowerRimY < geometry.topY - 1 else { return nil }

        let path = CGMutablePath()
        let n = 80

        var points: [CGPoint] = []
        for i in 0...n {
            let frac = CGFloat(i) / CGFloat(n)
            let y = geometry.topY - 1 - frac * (geometry.topY - 1 - lowerRimY)
            let normalizedFrac = (y - geometry.bottomY) / (geometry.topY - geometry.bottomY)
            let hw = interpolatedHalfWidth(atNormalized: normalizedFrac, t: t)
            points.append(CGPoint(x: geometry.centerX + hw - offset, y: y))
        }

        // Enforce monotonic x: the right rim should only move right (x increasing)
        // as we go down from the neck.
        for i in 1..<points.count {
            if points[i].x < points[i - 1].x {
                points[i].x = points[i - 1].x
            }
        }

        path.move(to: points[0])
        for i in 1...n { path.addLine(to: points[i]) }
        return path
    }

    /// Generates an interpolated left highlight path.
    func interpolatedLeftHighlightPath(at t: CGFloat, geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath? {
        let bottomStop = geometry.bottomY + geometry.bodyCornerRadius
        guard bottomStop < geometry.topY else { return nil }

        let path = CGMutablePath()
        let n = 100

        var points: [CGPoint] = []
        for i in 0...n {
            let frac = CGFloat(i) / CGFloat(n)
            let y = geometry.topY - frac * (geometry.topY - bottomStop)
            let normalizedFrac = (y - geometry.bottomY) / (geometry.topY - geometry.bottomY)
            let hw = interpolatedHalfWidth(atNormalized: normalizedFrac, t: t)
            points.append(CGPoint(x: geometry.centerX - hw + offset, y: y))
        }

        // Enforce monotonic x: highlight should only move left as we go down.
        for i in 1..<points.count {
            if points[i].x > points[i - 1].x {
                points[i].x = points[i - 1].x
            }
        }

        path.move(to: points[0])
        for i in 1...n { path.addLine(to: points[i]) }
        return path
    }

    // MARK: - Private Helpers

    /// Builds the open-top edge chain path from densely sampled half-widths.
    /// With ~200 samples per side over ~400pt of height, each line segment is ~2pt —
    /// well below the stroke width (3.5pt) and glow width, making segments invisible.
    private func buildPath(
        bottomY: CGFloat, topY: CGFloat,
        centerX: CGFloat, t: CGFloat
    ) -> CGMutablePath {
        let height = topY - bottomY
        guard height > 0 else {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: centerX, y: bottomY))
            return path
        }

        let n = sampleCount

        // Pre-compute all (y, halfWidth) samples at uniform spacing.
        var ys = [CGFloat](repeating: 0, count: n + 1)
        var hws = [CGFloat](repeating: 0, count: n + 1)
        for i in 0...n {
            let frac = CGFloat(i) / CGFloat(n)
            ys[i] = bottomY + frac * height
            hws[i] = interpolatedHalfWidth(atNormalized: frac, t: t)
        }

        let path = CGMutablePath()

        // Left side: top to bottom (index n down to 0)
        path.move(to: CGPoint(x: centerX - hws[n], y: ys[n]))
        for i in stride(from: n - 1, through: 0, by: -1) {
            path.addLine(to: CGPoint(x: centerX - hws[i], y: ys[i]))
        }

        // Right side: bottom to top (index 0 up to n)
        for i in 0...n {
            path.addLine(to: CGPoint(x: centerX + hws[i], y: ys[i]))
        }

        return path
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
