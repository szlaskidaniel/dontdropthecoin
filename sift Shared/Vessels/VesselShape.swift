//
//  VesselShape.swift
//  sift Shared
//

import CoreGraphics

/// Holds all computed measurements for a vessel shape at a specific frame size.
struct VesselGeometry {
    /// The open-top CGPath used for physics edge chain and visual layers.
    let path: CGMutablePath

    /// Bounding box of the vessel body.
    let minX: CGFloat
    let maxX: CGFloat
    let bottomY: CGFloat
    let topY: CGFloat

    /// Y coordinate where the body starts narrowing into the neck.
    /// For shapes without a distinct neck (e.g., beaker), this is near topY.
    let shoulderY: CGFloat

    /// Left and right edges of the neck opening.
    let neckMinX: CGFloat
    let neckMaxX: CGFloat

    /// Height of the neck region (topY - shoulderY).
    let neckHeight: CGFloat

    /// Corner radius at the bottom of the body.
    let bodyCornerRadius: CGFloat

    var bodyWidth: CGFloat { maxX - minX }
    var neckWidth: CGFloat { neckMaxX - neckMinX }
    var height: CGFloat { topY - bottomY }
    var centerX: CGFloat { (minX + maxX) / 2 }
}

/// Protocol that all vessel shapes conform to.
protocol VesselShape {
    /// A human-readable name (e.g., "Bottle", "Beaker").
    var name: String { get }

    /// Builds the vessel geometry for the given scene frame dimensions.
    func buildGeometry(frameWidth: CGFloat, frameHeight: CGFloat) -> VesselGeometry

    /// Returns the horizontal half-width of the vessel interior at a given Y coordinate.
    /// Used for containment checks, random point generation, and dirt placement.
    func halfWidthAt(y: CGFloat, geometry: VesselGeometry) -> CGFloat

    /// Returns the path for the left inner rim light, or nil if not applicable.
    func leftInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath?

    /// Returns the path for the right inner rim light, or nil if not applicable.
    func rightInnerRimPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath?

    /// Returns the path for the left-side highlight reflection.
    func leftHighlightPath(geometry: VesselGeometry, offset: CGFloat) -> CGMutablePath?
}

/// Maps stage numbers to vessel shapes.
enum VesselShapeRegistry {
    /// Number of stages each shape is used before switching.
    /// Change to 5 for production; 2 for testing.
    static let stagesPerShape = 2

    /// All vessel shapes in order of appearance (cycles after the last).
    static let shapes: [VesselShape] = [
        BottleVessel(),
        BeakerVessel(),
        ErlenmeyerVessel(),
        RoundFlaskVessel(),
        TallFlaskVessel(),
    ]

    /// Returns the vessel shape for the given stage (1-based).
    static func shape(forStage stage: Int) -> VesselShape {
        let index = ((stage - 1) / stagesPerShape) % shapes.count
        return shapes[index]
    }

    /// Returns true if the vessel shape changes between two stages.
    static func shapeChanges(from oldStage: Int, to newStage: Int) -> Bool {
        let oldIndex = ((oldStage - 1) / stagesPerShape) % shapes.count
        let newIndex = ((newStage - 1) / stagesPerShape) % shapes.count
        return oldIndex != newIndex
    }
}
