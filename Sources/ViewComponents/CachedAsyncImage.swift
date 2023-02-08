//
//  SwiftUIView.swift
//  
//
//  Created by ErrorErrorError on 2/7/23.
//  
//

import SwiftUI

public enum CachedAsyncImagePhase {
    case empty
    case success(Image)
    case failed(Error)

    public var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    public var error: Error? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
}

public struct CachedAsyncImage<Content: View>: View {
    @State private var phase = CachedAsyncImagePhase.empty
    private let url: URL?
    private let transaction: Transaction
    private let content: (CachedAsyncImagePhase) -> Content
    private var onAverageColorChanged: ((Color?) -> Void)? = nil

    public init(
        url: URL? = nil,
        transaction: Transaction = .init(),
        @ViewBuilder content: @escaping (CachedAsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
        self.transaction = transaction
    }

    public var body: some View {
        content(phase)
            .onAppear {
                fetchImage(url, transaction)
            }
            .onChange(of: url) { newValue in
                fetchImage(newValue, transaction)
            }
    }

    public func onAverageColor(_ callback: @escaping (Color?) -> Void) -> Self {
        var copy = self
        copy.onAverageColorChanged = callback
        return copy
    }

    @MainActor
    private func fetchImage(
        _ url: URL?,
        _ transaction: Transaction
    ) {
        guard let url else {
            phase = .empty
            return
        }

        Task.detached {
            guard !Task.isCancelled else { return }
            if let platform = await ImageCache.shared.get(forKey: url.absoluteString) {
                phase = Image(platform).flatMap({ .success($0) }) ?? .empty
                onAverageColorChanged?(platform.averageColor)
            } else {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let platformImage = ImagePlatform(data: data)
                    if let platformImage {
                        await ImageCache.shared.set(forKey: url.absoluteString, image: platformImage)
                    }

                    let image = Image(platformImage)
                    withTransaction(transaction) {
                        phase = image.flatMap { .success($0) } ?? .empty
                    }
                    onAverageColorChanged?(platformImage?.averageColor)
                } catch {
                    withTransaction(transaction) {
                        phase = .failed(error)
                    }
                    onAverageColorChanged?(nil)
                }
            }
        }
    }
}

extension CachedAsyncImage {
    public init<I: View, P: View>(
        url: URL?,
        transaction: Transaction = .init(),
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(url: url, transaction: transaction) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }
}

#if canImport(AppKit)
typealias ImagePlatform = NSImage
#else
typealias ImagePlatform = UIImage
#endif

fileprivate extension Image {
    init?(_ platform: ImagePlatform?) {
        guard let platform else { return nil }
        #if canImport(UIKit)
        self.init(uiImage: platform)
        #else
        self.init(nsImage: platform)
        #endif
    }
}

@globalActor public actor ImageCache {
    public static var shared = ImageCache()

    var cache = NSCache<NSString, ImagePlatform>()

    func get(forKey: String) -> ImagePlatform? {
        return cache.object(forKey: NSString(string: forKey))
    }

    func set(forKey: String, image: ImagePlatform) {
        cache.setObject(image, forKey: NSString(string: forKey))
    }

    private static func key(from url: URL) -> String {
        return url.absoluteString
    }

    private static func key(from request: URLRequest) -> String {
        return request.url?.description ?? ""
    }

    public func getImage(for url: URL) {
        
    }

    subscript(url: URL) -> Image? {
        return nil
    }
}

extension ImagePlatform {
    var averageColor: Color? {
        #if os(macOS)
        var rect = NSRect(origin: .zero, size: self.size)
        guard let cgImage = self.cgImage(forProposedRect: &rect, context: .current, hints: nil) else { return nil }
        let inputImage = CIImage(cgImage: cgImage)
        #else
        guard let inputImage = CIImage(image: self) else { return nil }
        #endif

        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: extentVector
            ]
        ) else { return nil }

        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: .init(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return .init(
            .sRGB,
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            opacity: CGFloat(bitmap[3]) / 255
        )
    }
}

struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        CachedAsyncImage(url: nil) { phase in
            switch phase {
            case .empty:
                EmptyView()
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failed:
                EmptyView()
            }
        }
    }
}
