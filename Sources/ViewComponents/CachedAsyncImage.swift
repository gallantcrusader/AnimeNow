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

    public func onAverageColor(_ callback: ((Color?) -> Void)?) -> Self {
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

        if let cachedImage = ImageDatabase.shared.cachedImage(url) {
            print("Fetching image from memory.")
            phase = .success(.init(cachedImage))
            onAverageColorChanged?(cachedImage.averageColor)
            return
        }

        Task.detached {
            guard !Task.isCancelled else { return }

            do {
                let image = try await ImageDatabase.shared.image(url)

                withTransaction(transaction) {
                    phase = .success(.init(image))
                }
                onAverageColorChanged?(image.averageColor)
            } catch {
                withTransaction(transaction) {
                    phase = .failed(error)
                }
                onAverageColorChanged?(nil)
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
public typealias PlatformImage = NSImage
#else
public typealias PlatformImage = UIImage
#endif

fileprivate extension Image {
    init(_ platform: PlatformImage) {
#if canImport(UIKit)
        self.init(uiImage: platform)
#else
        self.init(nsImage: platform)
#endif
    }
}

@globalActor public actor ImageDatabase {
    public static var shared = ImageDatabase()

    private let cache: URLCache = {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let diskCacheURL = cachesURL.appendingPathComponent("ImageCaches", conformingTo: .directory)
        return .init(
            memoryCapacity: 0,
            diskCapacity: 1024 * 1024 * 1024,
            directory: diskCacheURL
        )
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        return .init(configuration: config)
    }()

    private let cachedImages = NSCache<NSString, PlatformImage>()

    public func image(_ url: URL) async throws -> PlatformImage {
        try await image(.init(url: url))
    }

    public func image(_ request: URLRequest) async throws -> PlatformImage {

        // Check an image is already in memory

        if let cached = cachedImages.object(forKey: request.id as NSString) {
            print("Fetching from cache memory.")
            return cached
        }

        // Check if it's in disk

        if let response = cache.cachedResponse(for: request) {
            print("Fetching from cache disk.")
            if let image = PlatformImage(data: response.data) {
                cachedImages.setObject(image, forKey: request.id as NSString)
                return image
            } else {
                throw "Malformed image data response for: \(request.url?.absoluteString ?? "Unknown") "
            }
        }

        // Download image

        print("Downloading image")

        let (data, response) = try await session.data(for: request)
        guard let image = PlatformImage(data: data) else {
            throw "Image data invalid for \(request.url?.absoluteString ?? "Unknown")"
        }
        cache.storeCachedResponse(.init(response: response, data: data), for: request)
        cachedImages.setObject(image, forKey: request.id as NSString)
        return image
    }

    nonisolated public func cachedImage(_ request: URLRequest) -> PlatformImage? {
        cachedImages.object(forKey: request.id as NSString)
    }

    nonisolated public func cachedImage(_ url: URL) -> PlatformImage? {
        cachedImage(.init(url: url))
    }

    nonisolated public func diskUsage() -> Int {
        cache.currentDiskUsage
    }

    nonisolated public func maxDiskCapacity() -> Int {
        cache.diskCapacity
    }

    public func reset() {
        cache.removeAllCachedResponses()
        cachedImages.removeAllObjects()
    }
}

extension NSCache: @unchecked Sendable {}

extension URLRequest: Identifiable {
    public var id: String { "\(hashValue)" }
}

extension String: Error {}
 
extension PlatformImage {
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
