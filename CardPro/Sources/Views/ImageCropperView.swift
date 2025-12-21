import SwiftUI
import UIKit
import Vision

/// A view for cropping business card images
struct ImageCropperView: View {
    let imageData: Data
    let onCrop: (Data) -> Void
    let onCancel: () -> Void

    @State private var image: UIImage?
    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var lastCropRect: CGRect = .zero
    @State private var isDetecting = false
    @State private var detectedRect: CGRect?

    // Minimum crop size
    private let minCropSize: CGFloat = 80

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                GeometryReader { geometry in
                    let containerSize = CGSize(
                        width: geometry.size.width,
                        height: geometry.size.height - 80 // Account for top bar and instructions
                    )
                    let calculatedFrame = calculateImageFrame(image: image, containerSize: containerSize, offsetY: 60)

                    ZStack {
                        // Main image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: calculatedFrame.width, height: calculatedFrame.height)
                            .position(x: calculatedFrame.midX, y: calculatedFrame.midY)

                        // Dark overlay outside crop area
                        if cropRect != .zero {
                            CropOverlayView(cropRect: cropRect, bounds: geometry.size)

                            // Crop frame with interactive handles
                            InteractiveCropFrame(
                                cropRect: $cropRect,
                                lastCropRect: $lastCropRect,
                                imageFrame: imageFrame,
                                minSize: minCropSize
                            )
                        }
                    }
                    .onAppear {
                        imageFrame = calculatedFrame
                        initializeCropRect()
                        // Auto-detect card edges on first load
                        Task {
                            await detectCardEdges()
                        }
                    }
                }
            } else {
                ProgressView()
                    .tint(.white)
            }

            // Top bar
            VStack {
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding()

                    Spacer()

                    Text("Crop Card")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button("Done") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .padding()
                }
                .background(Color.black.opacity(0.7))

                Spacer()

                // Bottom bar with auto-detect and instructions
                VStack(spacing: 8) {
                    if isDetecting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Detecting card edges...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    } else {
                        Button {
                            Task {
                                await detectCardEdges()
                            }
                        } label: {
                            Label("Auto Detect", systemImage: "viewfinder")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(.white)
                    }

                    Text("Drag corners to resize • Drag center to move")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func calculateImageFrame(image: UIImage, containerSize: CGSize, offsetY: CGFloat) -> CGRect {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        var frameSize: CGSize
        if imageAspect > containerAspect {
            // Image is wider - fit to width
            frameSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
        } else {
            // Image is taller - fit to height
            frameSize = CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        }

        let origin = CGPoint(
            x: (containerSize.width - frameSize.width) / 2,
            y: offsetY + (containerSize.height - frameSize.height) / 2
        )

        return CGRect(origin: origin, size: frameSize)
    }

    private func initializeCropRect() {
        let inset: CGFloat = 16
        cropRect = imageFrame.insetBy(dx: inset, dy: inset)
        lastCropRect = cropRect
    }

    private func loadImage() {
        if let uiImage = UIImage(data: imageData) {
            image = uiImage
        }
    }

    private func cropImage() {
        guard let image, imageFrame.width > 0, imageFrame.height > 0 else {
            onCancel()
            return
        }

        // First normalize the image orientation - CGImage.cropping doesn't respect UIImage orientation
        let normalizedImage = normalizeImageOrientation(image)

        // Convert crop rect from screen coordinates to image coordinates
        let scaleX = normalizedImage.size.width / imageFrame.width
        let scaleY = normalizedImage.size.height / imageFrame.height

        // Calculate crop position relative to image frame
        let relativeX = cropRect.minX - imageFrame.minX
        let relativeY = cropRect.minY - imageFrame.minY

        let cropInImage = CGRect(
            x: max(0, relativeX * scaleX),
            y: max(0, relativeY * scaleY),
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        // Clamp to image bounds
        let imageRect = CGRect(origin: .zero, size: normalizedImage.size)
        let clampedRect = cropInImage.intersection(imageRect)

        guard clampedRect.width > 10, clampedRect.height > 10,
              let cgImage = normalizedImage.cgImage?.cropping(to: clampedRect) else {
            onCancel()
            return
        }

        // No need to pass orientation since we normalized it
        let croppedImage = UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)

        if let data = croppedImage.jpegData(compressionQuality: 0.9) {
            onCrop(data)
        } else {
            onCancel()
        }
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If already upright, no need to redraw
        guard image.imageOrientation != .up else { return image }

        // Draw the image into a new context to flatten the orientation
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    // MARK: - Auto Detection

    @MainActor
    private func detectCardEdges() async {
        guard let image, imageFrame.width > 0 else { return }

        isDetecting = true

        let detected = await performRectangleDetection(on: image)

        if let normalizedRect = detected {
            // Convert from Vision coordinates (normalized, origin bottom-left)
            // to screen coordinates (origin top-left)
            let screenRect = CGRect(
                x: imageFrame.minX + normalizedRect.minX * imageFrame.width,
                y: imageFrame.minY + (1 - normalizedRect.maxY) * imageFrame.height,
                width: normalizedRect.width * imageFrame.width,
                height: normalizedRect.height * imageFrame.height
            )

            // Apply with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                cropRect = screenRect
                lastCropRect = screenRect
            }
            detectedRect = screenRect
        }

        isDetecting = false
    }

    private func performRectangleDetection(on image: UIImage) async -> CGRect? {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: nil)
                return
            }

            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRectangleObservation],
                      let bestRect = results.first else {
                    continuation.resume(returning: nil)
                    return
                }

                // Return the bounding box of the detected rectangle
                continuation.resume(returning: bestRect.boundingBox)
            }

            // Configure for business card detection
            request.minimumAspectRatio = 0.3  // Cards are rectangular
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.1  // At least 10% of image
            request.maximumObservations = 1  // Just find the best one
            request.minimumConfidence = 0.5

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Crop Overlay

struct CropOverlayView: View {
    let cropRect: CGRect
    let bounds: CGSize

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(cropRect)
            context.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Interactive Crop Frame

struct InteractiveCropFrame: View {
    @Binding var cropRect: CGRect
    @Binding var lastCropRect: CGRect
    let imageFrame: CGRect
    let minSize: CGFloat

    private let handleSize: CGFloat = 50
    private let cornerVisualSize: CGFloat = 24

    var body: some View {
        ZStack {
            // Border with grid
            CropBorderView(cropRect: cropRect)

            // Corner handles (for resizing)
            cornerHandle(.topLeft)
            cornerHandle(.topRight)
            cornerHandle(.bottomLeft)
            cornerHandle(.bottomRight)

            // Edge handles (for resizing from edges)
            edgeHandle(.top)
            edgeHandle(.bottom)
            edgeHandle(.left)
            edgeHandle(.right)

            // Center area (for moving)
            centerDragArea
        }
    }

    // MARK: - Corner Handles

    private func cornerHandle(_ corner: Corner) -> some View {
        let position = corner.position(in: cropRect)

        return ZStack {
            // Visual bracket
            CornerBracket(corner: corner)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: cornerVisualSize, height: cornerVisualSize)

            // Larger invisible hit area
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: handleSize, height: handleSize)
        }
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    resizeFromCorner(corner, translation: value.translation)
                }
                .onEnded { _ in
                    lastCropRect = cropRect
                }
        )
    }

    // MARK: - Edge Handles

    private func edgeHandle(_ edge: Edge) -> some View {
        let position = edge.position(in: cropRect)
        let isVertical = edge == .left || edge == .right

        return Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(
                width: isVertical ? handleSize / 2 : cropRect.width * 0.5,
                height: isVertical ? cropRect.height * 0.5 : handleSize / 2
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        resizeFromEdge(edge, translation: value.translation)
                    }
                    .onEnded { _ in
                        lastCropRect = cropRect
                    }
            )
    }

    // MARK: - Center Drag Area

    private var centerDragArea: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(
                width: max(0, cropRect.width - handleSize * 1.5),
                height: max(0, cropRect.height - handleSize * 1.5)
            )
            .position(x: cropRect.midX, y: cropRect.midY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        moveRect(translation: value.translation)
                    }
                    .onEnded { _ in
                        lastCropRect = cropRect
                    }
            )
    }

    // MARK: - Gesture Handlers

    private func moveRect(translation: CGSize) {
        var newRect = lastCropRect
        newRect.origin.x += translation.width
        newRect.origin.y += translation.height

        // Constrain to image bounds
        newRect.origin.x = max(imageFrame.minX, min(imageFrame.maxX - newRect.width, newRect.origin.x))
        newRect.origin.y = max(imageFrame.minY, min(imageFrame.maxY - newRect.height, newRect.origin.y))

        cropRect = newRect
    }

    private func resizeFromCorner(_ corner: Corner, translation: CGSize) {
        var newRect = lastCropRect

        switch corner {
        case .topLeft:
            let newX = lastCropRect.minX + translation.width
            let newY = lastCropRect.minY + translation.height
            let newWidth = lastCropRect.maxX - newX
            let newHeight = lastCropRect.maxY - newY

            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.x = newX
                newRect.origin.y = newY
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }

        case .topRight:
            let newY = lastCropRect.minY + translation.height
            let newWidth = lastCropRect.width + translation.width
            let newHeight = lastCropRect.maxY - newY

            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.y = newY
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }

        case .bottomLeft:
            let newX = lastCropRect.minX + translation.width
            let newWidth = lastCropRect.maxX - newX
            let newHeight = lastCropRect.height + translation.height

            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.x = newX
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }

        case .bottomRight:
            let newWidth = lastCropRect.width + translation.width
            let newHeight = lastCropRect.height + translation.height

            if newWidth >= minSize && newHeight >= minSize {
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
        }

        // Constrain to image bounds
        constrainToImage(&newRect)
        cropRect = newRect
    }

    private func resizeFromEdge(_ edge: Edge, translation: CGSize) {
        var newRect = lastCropRect

        switch edge {
        case .top:
            let newY = lastCropRect.minY + translation.height
            let newHeight = lastCropRect.maxY - newY
            if newHeight >= minSize {
                newRect.origin.y = newY
                newRect.size.height = newHeight
            }

        case .bottom:
            let newHeight = lastCropRect.height + translation.height
            if newHeight >= minSize {
                newRect.size.height = newHeight
            }

        case .left:
            let newX = lastCropRect.minX + translation.width
            let newWidth = lastCropRect.maxX - newX
            if newWidth >= minSize {
                newRect.origin.x = newX
                newRect.size.width = newWidth
            }

        case .right:
            let newWidth = lastCropRect.width + translation.width
            if newWidth >= minSize {
                newRect.size.width = newWidth
            }
        }

        constrainToImage(&newRect)
        cropRect = newRect
    }

    private func constrainToImage(_ rect: inout CGRect) {
        // Constrain origin
        rect.origin.x = max(imageFrame.minX, rect.origin.x)
        rect.origin.y = max(imageFrame.minY, rect.origin.y)

        // Constrain size
        if rect.maxX > imageFrame.maxX {
            rect.size.width = imageFrame.maxX - rect.origin.x
        }
        if rect.maxY > imageFrame.maxY {
            rect.size.height = imageFrame.maxY - rect.origin.y
        }

        // Ensure minimum size
        rect.size.width = max(minSize, rect.size.width)
        rect.size.height = max(minSize, rect.size.height)
    }

    // MARK: - Types

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight

        func position(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
            case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }

    enum Edge {
        case top, bottom, left, right

        func position(in rect: CGRect) -> CGPoint {
            switch self {
            case .top: return CGPoint(x: rect.midX, y: rect.minY)
            case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
            case .left: return CGPoint(x: rect.minX, y: rect.midY)
            case .right: return CGPoint(x: rect.maxX, y: rect.midY)
            }
        }
    }
}

// MARK: - Crop Border View

struct CropBorderView: View {
    let cropRect: CGRect

    var body: some View {
        ZStack {
            // Main border
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Grid lines (rule of thirds)
            Canvas { context, _ in
                let lineColor = Color.white.opacity(0.3)

                // Vertical lines
                for i in 1...2 {
                    let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: cropRect.minY))
                    path.addLine(to: CGPoint(x: x, y: cropRect.maxY))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }

                // Horizontal lines
                for i in 1...2 {
                    let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
                    var path = Path()
                    path.move(to: CGPoint(x: cropRect.minX, y: y))
                    path.addLine(to: CGPoint(x: cropRect.maxX, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Corner Bracket Shape

struct CornerBracket: Shape {
    let corner: InteractiveCropFrame.Corner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(rect.width, rect.height)

        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: rect.width - length, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: length))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: rect.height - length))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: length, y: rect.height))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.width - length, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - length))
        }

        return path
    }
}

#Preview {
    ImageCropperView(
        imageData: UIImage(systemName: "photo")!.pngData()!,
        onCrop: { _ in },
        onCancel: {}
    )
}
